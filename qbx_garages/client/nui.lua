local previewVehicle = 0
local garageData = {}
local isRotationActive = false
local previewCam = nil

-- Calcula as posições da câmera e do veículo com base no ponto de acesso da garagem
local function getPreviewPositions()
    local accessCoords = garageData.accessPointData.coords
    local heading = accessCoords.w
    
    -- Converte o heading para radianos para os cálculos de seno e cosseno
    local angle = math.rad(heading)

    -- Calcula os vetores "para frente" e "para a direita" com base na direção do ponto de acesso
    local forwardVector = vector3(-math.sin(angle), math.cos(angle), 0.0)
    local rightVector = vector3(math.cos(angle), math.sin(angle), 0.0)

    -- Define as posições relativas ao ponto de acesso
    return {
        vehicle = accessCoords.xyz + (forwardVector * 5.0) + (rightVector * 6.5) + vector3(-3.0, 0.0, 0.5),
        camera = accessCoords.xyz + (forwardVector * -1.0) + (rightVector * 4.0) + vector3(0.0, 0.0, 1.5)
    }
end

-- Função para rotacionar o veículo
local function StartRotationThread()
    if isRotationActive then return end
    isRotationActive = true
    CreateThread(function()
        while isRotationActive do
            Wait(10)
            if DoesEntityExist(previewVehicle) then
                SetEntityHeading(previewVehicle, GetEntityHeading(previewVehicle) + 0.4)
            else
                isRotationActive = false
            end
        end
    end)
end

-- Função para limpar tudo relacionado ao preview
local function StopPreview()
    isRotationActive = false
    if DoesEntityExist(previewVehicle) then
        DeleteEntity(previewVehicle)
    end
    previewVehicle = 0

    if previewCam then
        RenderScriptCams(false, true, 800, true, true)
        DestroyCam(previewCam, false)
        previewCam = nil
    end
end

-- Função para criar a câmera e iniciar a transição
local function createPreviewCam()
    if previewCam then return end

    local positions = getPreviewPositions()
    previewCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    
    SetCamCoord(previewCam, positions.camera.x, positions.camera.y, positions.camera.z)
    PointCamAtCoord(previewCam, positions.vehicle.x, positions.vehicle.y, positions.vehicle.z)
    SetCamFov(previewCam, 50.0)

    RenderScriptCams(true, true, 800, true, true)
end

-- Callback que cria e posiciona o veículo de preview
RegisterNUICallback('previewVehicle', function(data, cb)
    if DoesEntityExist(previewVehicle) then
        DeleteEntity(previewVehicle)
    end
    
    local model = data.model
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(50)
    end
    
    local positions = getPreviewPositions()
    local heading = garageData.accessPointData.coords.w + 180.0
    
    local safeCoords = positions.vehicle + vector3(0.0, 0.0, 100.0)
    previewVehicle = CreateVehicle(model, safeCoords.x, safeCoords.y, safeCoords.z, heading, false, false)
    
    FreezeEntityPosition(previewVehicle, true)
    SetEntityCollision(previewVehicle, false, false)
    
    SetEntityCoords(previewVehicle, positions.vehicle.x, positions.vehicle.y, positions.vehicle.z)
    
    SetModelAsNoLongerNeeded(model)
    StartRotationThread()
    cb('ok')
end)

RegisterNUICallback('takeOutVehicle', function(data, cb)
    StopPreview()
    SetNuiFocus(false, false)
    local accessPointIndex = garageData.accessPointData.index
    takeOutOfGarage(data.vehicle.id, garageData.name, accessPointIndex)
    cb('ok')
end)

RegisterNUICallback('closeMenu', function(data, cb)
    StopPreview()
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('parkNearbyVehicle', function(data, cb)
    parkNearbyVehicle(garageData.name)
    cb('ok')
end)

function openGarageUI(vehicles, garageName, accessPointData)
    -- Armazena o nome da garagem e os dados completos do ponto de acesso
    garageData = {
        name = garageName,
        accessPointData = accessPointData,
    }

    SendNUIMessage({
        action = "open",
        vehicles = vehicles
    })
    SetNuiFocus(true, true)
    createPreviewCam()
end