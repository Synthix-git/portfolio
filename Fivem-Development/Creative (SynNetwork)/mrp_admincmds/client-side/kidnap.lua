-- client.lua — cena de rapto com 3 tentativas (Network -> Local -> Fallback)
local SCENE_TIMEOUT_MS = 8000

local function takeControl(ent, tries)
    tries = tries or 40
    if not DoesEntityExist(ent) then return false end
    while tries > 0 and not NetworkHasControlOfEntity(ent) do
        NetworkRequestControlOfEntity(ent)
        Wait(100)
        tries = tries - 1
    end
    return NetworkHasControlOfEntity(ent)
end

local function deleteEntitySafe(ent, isVehicle)
    if not DoesEntityExist(ent) then return end
    takeControl(ent)
    SetEntityAsMissionEntity(ent, true, true)
    if isVehicle then
        -- soltar peds presos e desligar colisoes um frame para evitar soft-lock
        SetVehicleHasBeenOwnedByPlayer(ent, false)
        SetEntityAsNoLongerNeeded(ent)
        DeleteVehicle(ent)
        if DoesEntityExist(ent) then DeleteEntity(ent) end
    else
        DeletePed(ent)
        if DoesEntityExist(ent) then DeleteEntity(ent) end
    end
end

local function ensureOnFootAndDeleteVehicle(ped)
    if not IsPedInAnyVehicle(ped, false) then return end

    local veh = GetVehiclePedIsIn(ped, false)
    -- tentar sair normalmente
    TaskLeaveVehicle(ped, veh, 4160)
    local timeout = GetGameTimer() + 2000
    while IsPedInAnyVehicle(ped, false) and GetGameTimer() < timeout do
        Wait(300)
    end

    -- se ainda estiver dentro, teleporta para o lado e limpa tasks
    if IsPedInAnyVehicle(ped, false) then
        ClearPedTasksImmediately(ped)
        local vx,vy,vz = table.unpack(GetEntityCoords(veh))
        SetEntityCoordsNoOffset(ped, vx + 1.5, vy, vz + 0.25, false, false, false)
        Wait(300)
    end

    -- apagar o veículo (qualquer que seja o lugar do ped)
    if DoesEntityExist(veh) then
        -- garantir que não fica “owned” por outros scripts
        SetVehicleDoorsLocked(veh, 2)
        SetVehicleUndriveable(veh, true)
        deleteEntitySafe(veh, true)
    end
end

local function placePlayerByVanDoor(ped, van)
    local bone = GetEntityBoneIndexByName(van, "door_pside_r")
    local pos
    if bone ~= -1 then
        pos = GetWorldPositionOfEntityBone(van, bone)
    else
        pos = GetOffsetFromEntityInWorldCoords(van, 1.05, -0.35, 0.0)
    end
    local vHeading = GetEntityHeading(van)
    SetEntityCoordsNoOffset(ped, pos.x - 0.25, pos.y - 0.10, pos.z, false, false, false)
    SetEntityHeading(ped, vHeading + 90.0)
    TaskStandStill(ped, 200)
end

local function openVanDoors(van)
    if not DoesEntityExist(van) then return end
    for d=0,7 do
        SetVehicleDoorOpen(van, d, false, false)
    end
end

local function tryNetworkScene(playerPed, guardPed, van, dict)
    local scenePos = GetEntityCoords(van)
    local sceneRot = GetEntityRotation(van)
    local scene = NetworkCreateSynchronisedScene(scenePos, sceneRot, 2, false, false, 1.0, 0, 1.0)
    NetworkAddPedToSynchronisedScene(playerPed, scene, dict, "ig_1_girl_drag_into_van", 8.0, -4.0, 1, 16, 0, 0)
    NetworkAddPedToSynchronisedScene(guardPed,  scene, dict, "ig_1_guy2_drag_into_van",  8.0, -4.0, 1, 16, 0, 0)
    NetworkAddEntityToSynchronisedScene(van,    scene, dict, "drag_into_van_burr",       1.0, 1.0, 1)
    NetworkStartSynchronisedScene(scene)
    Wait(500)
    local running = IsEntityPlayingAnim(playerPed, dict, "ig_1_girl_drag_into_van", 3)
    return running, scene
end

local function tryLocalScene(playerPed, guardPed, van, dict)
    local rot = GetEntityRotation(van, 2)
    local pos = GetEntityCoords(van)
    local scene = CreateSynchronizedScene(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, 2)
    AttachSynchronizedSceneToEntity(scene, van, 0)

    TaskSynchronizedScene(playerPed, scene, dict, "ig_1_girl_drag_into_van", 8.0, -8.0, 0, 0, 0.0, 0)
    TaskSynchronizedScene(guardPed,  scene, dict, "ig_1_guy2_drag_into_van",  8.0, -8.0, 0, 0, 0.0, 0)
    PlaySynchronizedEntityAnim(van, scene, "drag_into_van_burr", dict, 8.0, -8.0, 0, 0.0)

    Wait(500)
    local running = IsEntityPlayingAnim(playerPed, dict, "ig_1_girl_drag_into_van", 3)
    return running, scene
end

local function playFallbackAnim(playerPed, guardPed, van, dict)
    openVanDoors(van)
    TaskPlayAnim(playerPed, dict, "ig_1_girl_drag_into_van", 8.0, -8.0, 6000, 0, 0, false, false, false)
    TaskPlayAnim(guardPed,  dict, "ig_1_guy2_drag_into_van",  8.0, -8.0, 6000, 0, 0, false, false, false)
    Wait(6000)
    ClearPedTasksImmediately(playerPed)
end

RegisterNetEvent("kick:ilv-scripts:KickKidnapScene", function()
    local playerPed = PlayerPedId()

    -- 1) Se estiver num veículo, apaga-o e deixa o ped a pé
    ensureOnFootAndDeleteVehicle(playerPed)

    local pcoords = GetEntityCoords(playerPed)

    -- 2) Spawn do guarda
    local guardModel = joaat("s_m_m_armoured_02")
    RequestModel(guardModel) while not HasModelLoaded(guardModel) do Wait(250) end
    local guardPed = CreatePed(0, guardModel, pcoords.x + 1.0, pcoords.y, pcoords.z, 0.0, true, true)
    SetBlockingOfNonTemporaryEvents(guardPed, true)
    SetPedCanRagdoll(guardPed, false)
    SetEntityAsMissionEntity(guardPed, true, true)

    -- 3) Van (local/mission para evitar ownership remoto)
    local vanModel = joaat("burrito3")
    RequestModel(vanModel) while not HasModelLoaded(vanModel) do Wait(250) end
    local van = CreateVehicle(vanModel, pcoords.x + 3.0, pcoords.y + 1.0, pcoords.z, 0.0, true, false)
    local spawnedVan = true
    SetVehicleOnGroundProperly(van)
    SetVehicleDoorsLocked(van, 1)
    SetEntityAsMissionEntity(van, true, true)

    -- 4) Posicionar atores
    placePlayerByVanDoor(playerPed, van)
    SetEntityCoordsNoOffset(guardPed, pcoords.x + 0.7, pcoords.y - 0.15, pcoords.z, false, false, false)
    SetEntityHeading(guardPed, GetEntityHeading(van) + 90.0)

    -- 5) Dicionário de animação
    local dict = "random@kidnap_girl"
    RequestAnimDict(dict) while not HasAnimDictLoaded(dict) do Wait(250) end

    -- 6) Tenta Network scene
    openVanDoors(van)
    local ok, scene = tryNetworkScene(playerPed, guardPed, van, dict)

    if not ok then
        -- 7) Tenta Local scene
        ok, scene = tryLocalScene(playerPed, guardPed, van, dict)
        if not ok then
            -- 8) Fallback simples
            playFallbackAnim(playerPed, guardPed, van, dict)
        else
            local d1 = GetAnimDuration(dict, "ig_1_girl_drag_into_van") or 0.0
            local d2 = GetAnimDuration(dict, "ig_1_guy2_drag_into_van") or 0.0
            local d3 = GetAnimDuration(dict, "drag_into_van_burr") or 0.0
            local dur = math.max(d1, math.max(d2, d3))
            if dur <= 0.0 then dur = SCENE_TIMEOUT_MS/1000.0 end
            Wait(math.floor(dur * 1000))
            ClearPedTasksImmediately(playerPed)
        end
    else
        local d1 = GetAnimDuration(dict, "ig_1_girl_drag_into_van") or 0.0
        local d2 = GetAnimDuration(dict, "ig_1_guy2_drag_into_van") or 0.0
        local d3 = GetAnimDuration(dict, "drag_into_van_burr") or 0.0
        local dur = math.max(d1, math.max(d2, d3))
        if dur <= 0.0 then dur = SCENE_TIMEOUT_MS/1000.0 end
        Wait(math.floor(dur * 1000))
        if scene then NetworkStopSynchronisedScene(scene) end
        ClearPedTasksImmediately(playerPed)
    end

    -- 9) Cleanup
    if DoesEntityExist(guardPed) then deleteEntitySafe(guardPed, false) end
    if spawnedVan and DoesEntityExist(van) then deleteEntitySafe(van, true) end

    RemoveAnimDict(dict)
    SetModelAsNoLongerNeeded(guardModel)
    if spawnedVan then SetModelAsNoLongerNeeded(vanModel) end
end)
