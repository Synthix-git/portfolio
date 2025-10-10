-----------------------------------------------------------------------------------------------------------------------------------------
-- DISMANTLE (CLIENT) — 4 zonas + target (exports["target"]) para marcar zonas no mapa
-----------------------------------------------------------------------------------------------------------------------------------------

--  CONFIGS
local ZONES = {
    vec4(476.93,  -1278.68, 29.54, 10.0),
    vec4(-27.27,  -1679.36, 29.46, 10.0),
    vec4(-68.99,  -1825.48, 26.94, 10.0),
    vec4(226.29,  -1993.36, 19.57, 10.0)
}

-- NPC/spot de target para marcar
local MARKER_NPC = vec4(472.49, -1308.91, 29.23, 203.76)
local MARKER_BLIP_SPRITE = 782
local MARKER_BLIP_COLOR  = 1
local MARKER_DURATION_MS = 10 * 60 * 1000 -- 10 min

local SPEED_LIMIT = 2.0
local REQUIRE_ENGINE_OFF = true
local REQUIRE_DRIVER_ONLY = true
local STOP_DELAY_MS = 1500
local HINT_COOLDOWN_MS = 10000
local WALK_TO_FRONT = true
local FRONT_OFFSET = 1.6
local MOVE_TIMEOUT_MS = 4000

local USE_CINEMATIC_SEQUENCE = true
local SCENARIO_WELD = "WORLD_HUMAN_WELDING"
local PTFX_ASSET = "core"
local PTFX_NAME  = "ent_amb_sparks_burst"

-- Estado
local insideZone = false
local currentVeh = 0
local stopStart = 0
local lastHint = 0
local waitingRequest = false
local lastConfirmAt = 0

-- Blips de marcação
local ActiveZoneBlips = {}

-----------------------------------------------------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------------------------------------------------
local function inAnyZone(coord)
    for i=1,#ZONES do
        local z = ZONES[i]
        local dx,dy,dz = coord.x - z.x, coord.y - z.y, coord.z - z.z
        if (dx*dx + dy*dy + dz*dz) <= (z.w * z.w) then return true,i end
    end
    return false,nil
end

local function now() return GetGameTimer() end

local function vehicleInfo(entity)
    if not entity or entity==0 then return nil end
    if GetEntityType(entity) ~= 2 then return nil end
    local netId = NetworkGetNetworkIdFromEntity(entity)
    local plate = (GetVehicleNumberPlateText(entity) or ""):gsub("%s+$","")
    local model = GetEntityModel(entity)
    local name  = string.lower(GetDisplayNameFromVehicleModel(model) or tostring(model))
    local class = GetVehicleClass(entity)
    return { netId=netId, plate=plate, model=name, class=class }
end

local function canDismantle(entity, ped)
    if not entity or entity==0 or GetEntityType(entity)~=2 then return false,"Veículo inválido." end
    if GetEntitySpeed(entity) > SPEED_LIMIT then return false,"Para o veículo antes de desmanchar." end
    if REQUIRE_ENGINE_OFF and GetIsVehicleEngineRunning(entity) then return false,"Desliga o motor." end
    if REQUIRE_DRIVER_ONLY then
        local seats = GetVehicleModelNumberOfSeats(GetEntityModel(entity))
        for i=-1,seats-2 do
            local occ = GetPedInVehicleSeat(entity, i)
            if occ and occ~=0 and i ~= -1 then return false,"O veículo deve estar sem passageiros." end
        end
    end
    return true,nil
end

local function goToFrontAndFace(ped, veh)
    if not WALK_TO_FRONT then return end
    local front = GetOffsetFromEntityInWorldCoords(veh, 0.0, FRONT_OFFSET, 0.0)
    ClearPedTasksImmediately(ped)
    TaskFollowNavMeshToCoord(ped, front.x, front.y, front.z, 1.25, -1, 0.5, false, 0.0)
    local deadline = now() + MOVE_TIMEOUT_MS
    while now() < deadline do
        if #(GetEntityCoords(ped) - front) <= 0.7 then ClearPedTasks(ped); break end
        Wait(0)
    end
    local vpos = GetEntityCoords(veh)
    local ppos = GetEntityCoords(ped)
    local desired = GetHeadingFromVector_2d(vpos.x-ppos.x, vpos.y-ppos.y)
    TaskAchieveHeading(ped, desired, 1000)
    local t2 = now() + 1200
    while now() < t2 do
        local h = GetEntityHeading(ped)
        local diff = math.abs((h - desired + 180.0) % 360.0 - 180.0)
        if diff <= 6.0 then break end
        Wait(0)
    end
end

local function cosmeticallyDismantle(veh)
    SetVehicleDoorOpen(veh, 4, false, false) -- capô
    SetVehicleDoorOpen(veh, 0, false, false) -- porta
    SetVehicleTyreBurst(veh, math.random(0,3), true, 1000.0)
    SmashVehicleWindow(veh, 0)
    SetVehicleEngineHealth(veh, math.random(100.0, 300.0))
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- Marcação de zonas (blips temporários)
-----------------------------------------------------------------------------------------------------------------------------------------
local function clearZoneBlips()
    for _, b in ipairs(ActiveZoneBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    ActiveZoneBlips = {}
end

local function markZonesForDuration(ms)
    clearZoneBlips()
    for i=1,#ZONES do
        local z = ZONES[i]
        local blip = AddBlipForCoord(z.x, z.y, z.z)
        SetBlipSprite(blip, MARKER_BLIP_SPRITE)
        SetBlipColour(blip, MARKER_BLIP_COLOR)
        SetBlipScale(blip, 0.6)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Zona de Desmanche")
        EndTextCommandSetBlipName(blip)
        ActiveZoneBlips[#ActiveZoneBlips+1] = blip
    end
    TriggerEvent("Notify","Desmanche","Zonas de desmanche marcadas no mapa por 10 minutos.", "verde", 6000)
    SetTimeout(ms, function()
        clearZoneBlips()
        TriggerEvent("Notify","Desmanche","Marcações removidas.", "amarelo", 4000)
    end)
end

-----------------------------------------------------------------------------------------------------------------------------------------
--  TARGET (exports["target"]) no NPC/spot indicado
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
    -- Usa o mesmo padrão do teu exemplo de mineração
    exports["target"]:AddCircleZone("dismantle:mark_spot",
        vec3(MARKER_NPC.x, MARKER_NPC.y, MARKER_NPC.z),
        1.5,
        { name = "dismantle:mark_spot", heading = MARKER_NPC.w },
        {
            shop = "dismantle",
            Distance = 1.5,
            options = {
                { event = "dismantle:markZones",  label = "Marcar zonas de desmanche", tunnel = "client" },
                { event = "dismantle:clearMarks", label = "Remover marcações",        tunnel = "client" }
            }
        }
    )
end)

RegisterNetEvent("dismantle:markZones")
AddEventHandler("dismantle:markZones", function()
    markZonesForDuration(MARKER_DURATION_MS)
end)

RegisterNetEvent("dismantle:clearMarks")
AddEventHandler("dismantle:clearMarks", function()
    clearZoneBlips()
    TriggerEvent("Notify","Desmanche","Marcações removidas manualmente.", "amarelo", 3000)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- Monitor da zona/parado + chamada de confirmação ao server
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
    local sleep = 1000
    while true do
        local ped = PlayerPedId()
        local coord = GetEntityCoords(ped)
        local inside = inAnyZone(coord)
        insideZone = inside

        if insideZone and IsPedInAnyVehicle(ped,false) then
            sleep = 250
            local veh = GetVehiclePedIsIn(ped,false)
            if GetPedInVehicleSeat(veh,-1)==ped then
                local ok = canDismantle(veh,ped)
                if ok then
                    if now() - lastHint > HINT_COOLDOWN_MS then
                        TriggerEvent("Notify","Desmanche","Este veículo pode ser desmanchado.", "azul", 2500)
                        lastHint = now()
                    end
                    if stopStart == 0 then stopStart = now() end
                    if (now() - stopStart) >= STOP_DELAY_MS and not waitingRequest and (now() - lastConfirmAt) > 2500 then
                        waitingRequest = true
                        currentVeh = veh
                        lastConfirmAt = now()

                        local info = vehicleInfo(veh)
                        if info then
                            local vc = GetEntityCoords(veh)
                            TriggerServerEvent("dismantle:Confirm", {
                                netId = info.netId, plate = info.plate, model = info.model, class = info.class,
                                coords = vec3(vc.x,vc.y,vc.z)
                            })
                        else
                            waitingRequest = false
                        end
                    end
                else
                    stopStart = 0
                end
            else
                stopStart = 0
            end
        else
            stopStart = 0
        end

        if waitingRequest then
            if not IsPedInAnyVehicle(ped,false) or not insideZone then
                waitingRequest = false
            end
        end

        Wait(sleep)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- Begin (anima/progress) + finalize server
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("dismantle:Begin")
AddEventHandler("dismantle:Begin", function(data)
    waitingRequest = false
    local ped = PlayerPedId()

    if (data and data.forceExit) and IsPedInAnyVehicle(ped, true) then
        local veh = GetVehiclePedIsIn(ped,false)
        TaskLeaveVehicle(ped, veh, 0)
        local t = GetGameTimer() + 3500
        while IsPedInAnyVehicle(ped, true) and GetGameTimer() < t do Wait(0) end
    end

    local ent = currentVeh ~= 0 and currentVeh or 0
    if ent == 0 or not DoesEntityExist(ent) then
        local veh = GetClosestVehicle(GetEntityCoords(ped), 4.0, 0, 70)
        if veh ~= 0 and DoesEntityExist(veh) then ent = veh end
        if ent == 0 then return end
    end

    if WALK_TO_FRONT then goToFrontAndFace(ped, ent) end

    LocalPlayer.state:set("Buttons", true, true)

    if USE_CINEMATIC_SEQUENCE then
        cosmeticallyDismantle(ent)
        RequestAnimDict("mini@repair"); while not HasAnimDictLoaded("mini@repair") do Wait(0) end
        TaskPlayAnim(ped, "mini@repair", "fixing_a_ped", 3.0, 3.0, -1, 1, 0.0, false, false, false)

        RequestNamedPtfxAsset(PTFX_ASSET); while not HasNamedPtfxAssetLoaded(PTFX_ASSET) do Wait(0) end
        UseParticleFxAssetNextCall(PTFX_ASSET)
        local bone = GetEntityBoneIndexByName(ent,"bonnet")
        local pos = (bone ~= -1) and GetWorldPositionOfEntityBone(ent,bone) or GetEntityCoords(ent)
        local fx = StartParticleFxLoopedAtCoord(PTFX_NAME, pos.x, pos.y, pos.z+0.2, 0.0,0.0,0.0, 1.0, false,false,false,false)

        TriggerEvent("Progress","Desmanchando", data and data.progress or 30000)
        Wait(data and data.progress or 30000)

        if fx then StopParticleFxLooped(fx,0) end
        ClearPedTasks(ped)
        SetVehicleDoorShut(ent,4,false)
    else
        TaskStartScenarioInPlace(ped, SCENARIO_WELD, 0, true)
        TriggerEvent("Progress","Desmanchando", data and data.progress or 30000)
        Wait(data and data.progress or 30000)
        ClearPedTasks(ped)
    end

    LocalPlayer.state:set("Buttons", false, true)
    TriggerServerEvent("dismantle:Finish")

    currentVeh = 0
    stopStart  = 0
end)
