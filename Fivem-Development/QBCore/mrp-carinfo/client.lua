-- qb-carinfo/client.lua

local QBCore = exports['qb-core']:GetCoreObject()
local isDisplayingCarInfo = false -- Flag to track if car info is being displayed

local searchRadius = 10.0 -- Radius to search for nearby vehicles

RegisterCommand("carinfo", function()
    isDisplayingCarInfo = not isDisplayingCarInfo -- Toggle display flag

    if isDisplayingCarInfo then
        QBCore.Functions.Notify("Car info display enabled", "success")

        -- Start a thread to continuously display vehicle names
        CreateThread(function()
            while isDisplayingCarInfo do
                local playerPed = PlayerPedId()
                local playerCoords = GetEntityCoords(playerPed)
                local vehicles = GetVehiclesInArea(playerCoords, searchRadius)

                -- Loop through each vehicle and display its spawn name
                for _, vehicle in ipairs(vehicles) do
                    local modelHash = GetEntityModel(vehicle)
                    local spawnName = GetDisplayNameFromVehicleModel(modelHash)
                    DisplayVehicleSpawnName(spawnName, GetEntityCoords(vehicle))
                end

                Wait(0) -- Yield to avoid blocking the main thread
            end
        end)
    else
        QBCore.Functions.Notify("Car info display disabled", "error")
    end
end)

function GetVehiclesInArea(coords, radius)
    local vehicles = {}
    local nearbyVehicles = GetGamePool('CVehicle')

    for _, vehicle in ipairs(nearbyVehicles) do
        if #(coords - GetEntityCoords(vehicle)) < radius then
            table.insert(vehicles, vehicle)
        end
    end

    return vehicles
end

function DisplayVehicleSpawnName(spawnName, vehicleCoords)
    local onScreen, x, y = World3dToScreen2d(vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 1.0)
    if onScreen then
        SetTextFont(4)
        SetTextProportional(1)
        SetTextScale(0.35, 0.35)
        SetTextColour(255, 255, 255, 255)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(1, 0, 0, 0, 255)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        AddTextComponentString(spawnName)
        DrawText(x, y)
    end
end
