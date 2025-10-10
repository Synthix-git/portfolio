
-- === OBJETOS (CAPUZ) ===
RegisterNetEvent("DeleteObject")
AddEventHandler("DeleteObject", function(netId)
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent and ent ~= 0 then
        if DoesEntityExist(ent) then
            DeleteEntity(ent)
        end
    end
end)

-- disponível para o client via Tunnel (vRPS)
function Creative.CreateObject(modelName, x, y, z)
    local src = source
    local model = (type(modelName) == "string") and GetHashKey(modelName) or modelName
    if not IsModelValid(model) then return false end

    RequestModel(model)
    local tries = 0
    while not HasModelLoaded(model) and tries < 100 do
        Wait(10); tries = tries + 1
    end
    if not HasModelLoaded(model) then return false end

    local obj = CreateObject(model, x + 0.0, y + 0.0, z + 0.0, true, true, true)
    if not obj or obj == 0 then return false end

    SetEntityAsMissionEntity(obj, true, true)
    local netId = NetworkGetNetworkIdFromEntity(obj)
    SetNetworkIdExistsOnAllMachines(netId, true)
    SetNetworkIdCanMigrate(netId, true)

    return true, netId
end
