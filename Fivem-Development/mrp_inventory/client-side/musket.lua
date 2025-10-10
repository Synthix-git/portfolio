-- client-side/syn_musket_block_on_player.lua
if IsDuplicityVersion() then return end -- segurança extra caso alguém meta em server por engano

local MUSKET_A = joaat("WEAPON_MUSKET")
local MUSKET_B = joaat("WEAPON_MUSTKET") -- typo que alguns recursos usam
local SHOW_MSG = true
local MSG_COOLDOWN = 1500
local lastMsg = 0

local function UsingMusket(weap)
    return weap == MUSKET_A or weap == MUSKET_B
end

local function GetAimEntity(maxDist)
    local pid = PlayerId()
    local got, ent = GetEntityPlayerIsFreeAimingAt(pid)
    if got and ent and ent ~= 0 then
        return ent
    end

    -- fallback raycast
    local camX, camY, camZ = table.unpack(GetGameplayCamCoord())
    local rot = GetGameplayCamRot(2)
    local radX, radZ = math.rad(rot.x), math.rad(rot.z)
    local cosX = math.cos(radX)
    local dirX = -math.sin(radZ) * cosX
    local dirY =  math.cos(radZ) * cosX
    local dirZ =  math.sin(radX)
    local destX, destY, destZ = camX + dirX * maxDist, camY + dirY * maxDist, camZ + dirZ * maxDist

    local ped = PlayerPedId()
    local handle = StartShapeTestLosProbe(camX, camY, camZ, destX, destY, destZ, -1, ped, 7)
    local _, hit, _, _, _, entityHit = GetShapeTestResult(handle)
    if hit == 1 and entityHit and entityHit ~= 0 then
        return entityHit
    end
    return nil
end

local function IsAimingAtPlayer()
    local ent = GetAimEntity(85.0)
    if not ent or ent == 0 then return false end
    if GetEntityType(ent) ~= 1 then return false end
    return IsPedAPlayer(ent)
end

CreateThread(function()
    while true do
        local sleep = 25
        local ped = PlayerPedId()

        if IsPedArmed(ped, 4) then
            local weap = GetSelectedPedWeapon(ped)
            if UsingMusket(weap) then
                sleep = 0
                local aiming = IsPlayerFreeAiming(PlayerId()) or IsControlPressed(0, 25)

                if aiming and IsAimingAtPlayer() then
                    -- bloqueia apenas o disparo nesses frames
                    DisableControlAction(0, 24, true)
                    DisableControlAction(0, 257, true)
                    DisableControlAction(0, 69, true)
                    DisableControlAction(0, 92, true)
                    DisableControlAction(0, 114, true)
                    DisablePlayerFiring(PlayerId(), true)

                    if SHOW_MSG and (IsDisabledControlJustPressed(0, 24) or IsDisabledControlJustPressed(0, 257) or IsDisabledControlJustPressed(0, 69)) then
                        local now = GetGameTimer()
                        if now - lastMsg > MSG_COOLDOWN then
                            lastMsg = now
                            TriggerEvent("Notify", "Mosquete", "Não podes disparar o <b>mosquete</b> contra <b>jogadores</b>.", "amarelo", 1200)
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)
