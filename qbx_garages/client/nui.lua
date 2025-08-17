local previewVehicle = 0
local garageData = {}
local isRotationActive = false

-- Função para rotacionar o holograma
local function StartRotationThread()
    if isRotationActive then return end
    isRotationActive = true
    CreateThread(function()
        while isRotationActive do
            Wait(10)
            if previewVehicle and DoesEntityExist(previewVehicle) then
                SetEntityHeading(previewVehicle, GetEntityHeading(previewVehicle) + 0.4)
            end
        end
    end)
end

local function StopRotationThread()
    isRotationActive = false
    if previewVehicle and DoesEntityExist(previewVehicle) then
        DeleteEntity(previewVehicle)
    end
    previewVehicle = 0
end

RegisterNUICallback('previewVehicle', function(data, cb)
    if previewVehicle and DoesEntityExist(previewVehicle) then
        DeleteEntity(previewVehicle)
    end
    local model = data.model
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(50)
    end
    local playerPed = PlayerPedId()
    local coords = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 5.0, 0.5)
    previewVehicle = CreateVehicle(model, coords.x, coords.y, coords.z, GetEntityHeading(playerPed) + 90.0, false, false)
    SetEntityCollision(previewVehicle, false, false)
    SetEntityAlpha(previewVehicle, 180, false)
    FreezeEntityPosition(previewVehicle, true)
    SetModelAsNoLongerNeeded(model)
    cb('ok')
end)

RegisterNUICallback('takeOutVehicle', function(data, cb)
    StopRotationThread()
    takeOutOfGarage(data.vehicle.id, garageData.name, garageData.accessPoint)
    cb('ok')
end)

RegisterNUICallback('closeMenu', function(data, cb)
    StopRotationThread()
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('parkNearbyVehicle', function(data, cb)
    parkNearbyVehicle(garageData.name)
    cb('ok')
end)

RegisterNUICallback('parkSelectedVehicle', function(data, cb)
    local success = lib.callback.await('qbx_garages:server:parkSelectedVehicle', false, data.plate, garageData.name)
    if success then
        -- Fecha o menu e reabre para atualizar a lista
        SendNUIMessage({ action = 'close' })
        Wait(100)
        openGarageMenu(garageData.name, Garages[garageData.name], garageData.accessPoint)
    end
    cb('ok')
end)


function openGarageUI(vehicles, garageName, accessPoint)
    garageData = {name = garageName, accessPoint = accessPoint}
    SendNUIMessage({
        action = "open",
        vehicles = vehicles
    })
    SetNuiFocus(true, true)
    StartRotationThread()
end