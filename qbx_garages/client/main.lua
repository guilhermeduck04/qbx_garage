local config = require 'config.client'
if not config.enableClient then return end
local VEHICLES = exports.qbx_core:GetVehiclesByName()
local Garages = {}
local garageData = {}

local VehicleCategory = {
    all = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22},
    car = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 17, 18, 19, 20, 22},
    air = {15, 16},
    sea = {14},
}

---@param category VehicleType
---@param vehicle number
---@return boolean
local function isOfType(category, vehicle)
    local classSet = {}

    for _, class in pairs(VehicleCategory[category]) do
        classSet[class] = true
    end

    return classSet[GetVehicleClass(vehicle)] == true
end

---@param vehicle number
local function kickOutPeds(vehicle)
    for i = -1, 5, 1 do
        local seat = GetPedInVehicleSeat(vehicle, i)
        if seat then
            TaskLeaveVehicle(seat, vehicle, 0)
        end
    end
end

local spawnLock = false

---@param vehicleId number
---@param garageName string
---@param accessPoint integer
function takeOutOfGarage(vehicleId, garageName, accessPoint)
    if spawnLock then
        exports.qbx_core:Notify(locale('error.spawn_in_progress'))
    end
    spawnLock = true
    local success, result = pcall(function()
        if cache.vehicle then
            exports.qbx_core:Notify(locale('error.in_vehicle'))
            return
        end

        local netId = lib.callback.await('qbx_garages:server:spawnVehicle', false, vehicleId, garageName, accessPoint)
        if not netId then return end

        local veh = lib.waitFor(function()
            if NetworkDoesEntityExistWithNetworkId(netId) then
                return NetToVeh(netId)
            end
        end)

        if veh == 0 then
            exports.qbx_core:Notify('Something went wrong spawning the vehicle', 'error')
            return
        end

        if config.engineOn then
            SetVehicleEngineOn(veh, true, true, false)
        end
    end)
    spawnLock = false
    assert(success, result)
end

function parkNearbyVehicle(garageName)
    local accessPointCoords = Garages[garageName].accessPoints[garageData.accessPoint].coords
    local vehicles = GetGamePool('CVehicle')
    local vehiclesToPark = {}
    local vehiclesFound = false

    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) and NetworkGetEntityIsNetworked(vehicle) then
            local vehicleCoords = GetEntityCoords(vehicle)
            if #(accessPointCoords.xyz - vehicleCoords) < 15.0 then
                vehiclesFound = true
                if GetVehicleNumberOfPassengers(vehicle, false, true) > 0 then
                    exports.qbx_core:Notify(locale('error.vehicle_occupied'), 'error')
                else
                    table.insert(vehiclesToPark, vehicle)
                end
            end
        end
    end

    if not vehiclesFound then
        exports.qbx_core:Notify("Nenhum veículo por perto para guardar.", "error")
        return
    end

    if #vehiclesToPark == 0 then return end

    local parkedSomething = false
    for _, vehicle in ipairs(vehiclesToPark) do
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        local props = lib.getVehicleProperties(vehicle)
        local success = lib.callback.await('qbx_garages:server:parkNearbyVehicle', false, netId, garageName, props)
        if success then
            parkedSomething = true
        end
    end

    if parkedSomething then
        SendNUIMessage({ action = 'close' })
        Wait(100)
        openGarageMenu(garageData.name, Garages[garageData.name], garageData.accessPoint)
    end
end


---@param garageName string
---@param garageInfo GarageConfig
---@param accessPoint integer
function openGarageMenu(garageName, garageInfo, accessPoint)
    garageData = {name = garageName, accessPoint = accessPoint}
    ---@type PlayerVehicle[]?
    local vehicleEntities = lib.callback.await('qbx_garages:server:getGarageVehicles', false, garageName)

    if not vehicleEntities then
        exports.qbx_core:Notify(locale('error.no_vehicles'), 'error')
        return
    end

    local vehicleData = {}
    for i=1, #vehicleEntities do
        local vehicle = vehicleEntities[i]
        local vehicleInfo = VEHICLES[vehicle.modelName]
        table.insert(vehicleData, {
            id = vehicle.id,
            modelName = vehicle.modelName,
            brand = vehicleInfo.brand,
            name = vehicleInfo.name,
            props = vehicle.props,
            state = vehicle.state
        })
    end

    -- CORREÇÃO AQUI: Prepara os dados do ponto de acesso e adiciona o índice a eles
    local accessPointData = Garages[garageName].accessPoints[accessPoint]
    accessPointData.index = accessPoint
    
    openGarageUI(vehicleData, garageName, accessPointData)
end

---@param vehicle number
---@param garageName string
local function parkVehicle(vehicle, garageName)
    if GetVehicleNumberOfPassengers(vehicle) ~= 1 then
        local isParkable = lib.callback.await('qbx_garages:server:isParkable', false, garageName, NetworkGetNetworkIdFromEntity(vehicle))

        if not isParkable then
            exports.qbx_core:Notify(locale('error.not_owned'), 'error', 5000)
            return
        end

        kickOutPeds(vehicle)
        SetVehicleDoorsLocked(vehicle, 2)
        Wait(1500)
        lib.callback.await('qbx_garages:server:parkVehicle', false, NetworkGetNetworkIdFromEntity(vehicle), lib.getVehicleProperties(vehicle), garageName)
        exports.qbx_core:Notify(locale('success.vehicle_parked'), 'primary', 4500)
    else
        exports.qbx_core:Notify(locale('error.vehicle_occupied'), 'error', 3500)
    end
end

---@param garage GarageConfig
---@return boolean
local function checkCanAccess(garage)
    if garage.groups and not exports.qbx_core:HasPrimaryGroup(garage.groups, QBX.PlayerData) then
        exports.qbx_core:Notify(locale('error.no_access'), 'error')
        return false
    end
    if cache.vehicle and not isOfType(garage.vehicleType, cache.vehicle) then
        exports.qbx_core:Notify(locale('error.not_correct_type'), 'error')
        return false
    end
    return true
end

---@param garageName string
---@param garage GarageConfig
---@param accessPoint AccessPoint
---@param accessPointIndex integer
local function createZones(garageName, garage, accessPoint, accessPointIndex)
    CreateThread(function()
        accessPoint.dropPoint = accessPoint.dropPoint or accessPoint.spawn
        local dropZone, coordsZone
        lib.zones.sphere({
            coords = accessPoint.coords,
            radius = 15,
            onEnter = function()
                if accessPoint.dropPoint and garage.type ~= GarageType.DEPOT then
                    dropZone = lib.zones.sphere({
                        coords = accessPoint.dropPoint,
                        radius = 2.5,
                        onEnter = function()
                            if not cache.vehicle then return end
                            lib.showTextUI(locale('info.park_e'))
                        end,
                        onExit = function()
                            lib.hideTextUI()
                        end,
                        inside = function()
                            if not cache.vehicle then return end
                            if IsControlJustReleased(0, 38) then
                                if not checkCanAccess(garage) then return end
                                parkVehicle(cache.vehicle, garageName)
                            end
                        end,
                        debug = config.debugPoly
                    })
                end
                coordsZone = lib.zones.sphere({
                    coords = accessPoint.coords,
                    radius = 1.5,
                    onEnter = function()
                        if accessPoint.dropPoint and cache.vehicle then return end
                        lib.showTextUI((garage.type == GarageType.DEPOT and locale('info.impound_e')) or (cache.vehicle and locale('info.park_e')) or locale('info.car_e'))
                    end,
                    onExit = function()
                        lib.hideTextUI()
                    end,
                    inside = function()
                        if accessPoint.dropPoint and cache.vehicle then return end
                        if IsControlJustReleased(0, 38) then
                            if not checkCanAccess(garage) then return end
                            if cache.vehicle and garage.type ~= GarageType.DEPOT then
                                parkVehicle(cache.vehicle, garageName)
                            else
                                openGarageMenu(garageName, garage, accessPointIndex)
                            end
                        end
                    end,
                    debug = config.debugPoly
                })
            end,
            onExit = function()
                if dropZone then
                    dropZone:remove()
                end
                if coordsZone then
                    coordsZone:remove()
                end
            end,
            inside = function()
                if accessPoint.dropPoint then
                    config.drawDropOffMarker(accessPoint.dropPoint)
                end
                config.drawGarageMarker(accessPoint.coords.xyz)
            end,
            debug = config.debugPoly,
        })
    end)
end

---@param garageInfo GarageConfig
---@param accessPoint AccessPoint
local function createBlips(garageInfo, accessPoint)
    local blip = AddBlipForCoord(accessPoint.coords.x, accessPoint.coords.y, accessPoint.coords.z)
    SetBlipSprite(blip, accessPoint.blip.sprite or 357)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.60)
    SetBlipAsShortRange(blip, true)
    SetBlipColour(blip, accessPoint.blip.color or 3)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(accessPoint.blip.name or garageInfo.label)
    EndTextCommandSetBlipName(blip)
end

local function createGarage(name, garage)
    Garages[name] = garage
    local accessPoints = garage.accessPoints
    for i = 1, #accessPoints do
        local accessPoint = accessPoints[i]

        if accessPoint.blip then
            createBlips(garage, accessPoint)
        end

        createZones(name, garage, accessPoint, i)
    end
end

local function createGarages()
    local serverGarages = lib.callback.await('qbx_garages:server:getGarages')
    for name, garage in pairs(serverGarages) do
        createGarage(name, garage)
    end
end

RegisterNetEvent('qbx_garages:client:garageRegistered', function(name, garage)
    createGarage(name, garage)
end)

-- Evento para reabrir o menu após guardar um veículo
RegisterNetEvent('qbx_garages:client:reopenMenu', function()
    if garageData and garageData.name then
        openGarageMenu(garageData.name, Garages[garageData.name], garageData.accessPoint)
    end
end)

CreateThread(function()
    createGarages()
end)