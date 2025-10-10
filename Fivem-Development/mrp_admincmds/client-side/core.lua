-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP / TUNNEL
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
Creative = {}
Tunnel.bindInterface("admin", Creative)
vSERVER = Tunnel.getInterface("admin")

-----------------------------------------------------------------------------------------------------------------------------------------
-- TELEPORTWAY
-----------------------------------------------------------------------------------------------------------------------------------------
local WAYPOINT_BLIP = 8

RegisterNetEvent("admin:teleportWay")
AddEventHandler("admin:teleportWay", function()
    if Creative and Creative.teleportWay then
        Creative.teleportWay()
    end
end)

local function FindGroundZ(x, y)
    -- tenta várias alturas até achar o chão
    local tries = {1000.0, 900.0, 800.0, 700.0, 600.0, 500.0, 400.0, 300.0, 200.0, 150.0, 110.0, 90.0, 70.0, 50.0, 40.0, 30.0, 20.0, 10.0}
    for i = 1, #tries do
        local z = tries[i]
        local found, groundZ = GetGroundZFor_3dCoord(x + 0.0, y + 0.0, z + 0.0, true)
        if found then
            return groundZ + 1.0
        end
        RequestCollisionAtCoord(x + 0.0, y + 0.0, z + 0.0)
        Wait(5)
    end


    -- última tentativa: nó de estrada mais próximo (teleporte seguro)
local nodeFound, nodePos = GetClosestVehicleNode(x + 0.0, y + 0.0, 0.0, 1, 3.0, 0.0)
if nodeFound and nodePos then
    return (nodePos.z or 200.0) + 1.0
end


    -- fallback
    return 200.0
end

function Creative.teleportWay()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    -- teleporta o veículo só se fores o condutor; caso contrário, só o ped
    local entity = ped
    if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
        entity = veh
    end

    -- waypoint
    local wayBlip = GetFirstBlipInfoId(WAYPOINT_BLIP)
    if not DoesBlipExist(wayBlip) then
        TriggerEvent("Notify", "Teleporte", "Marca um <b>waypoint</b> no mapa primeiro.", "amarelo", 5000)
        return
    end

    -- coords do waypoint (usar InfoIdCoord é mais estável)
    local wp = GetBlipInfoIdCoord(wayBlip)
    local destX, destY = wp.x + 0.0, wp.y + 0.0
    local finalZ = FindGroundZ(destX, destY)

    local ox, oy, oz = table.unpack(GetEntityCoords(entity))

    -- prepara teleporte
    RequestCollisionAtCoord(destX, destY, finalZ)
    FreezeEntityPosition(entity, true)

    -- aplica teleporte
    SetEntityCoordsNoOffset(entity, destX, destY, finalZ, false, false, false)

    -- aguarda colisão carregar no novo local
    local t0 = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(entity) and (GetGameTimer() - t0) < 1500 do
        RequestCollisionAtCoord(destX, destY, finalZ)
        Wait(1)
    end

    -- se for veículo, assenta no chão
    if entity ~= ped then
        SetVehicleOnGroundProperly(entity)
    end

    FreezeEntityPosition(entity, false)

    -- log para o servidor
    vSERVER.LogTeleport(ox + 0.0, oy + 0.0, oz + 0.0, destX, destY, finalZ)

    -- feedback
    TriggerEvent("Notify", "Teleporte", "Teletransportado para o <b>waypoint</b>.", "verde", 3000)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- TELEPORTWAY
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.teleportLimbo()
	local Ped = PlayerPedId()
	local Coords = GetEntityCoords(Ped)
	local _,Node = GetNthClosestVehicleNode(Coords["x"],Coords["y"],Coords["z"],1,0,0,0)

	SetEntityCoords(Ped,Node["x"],Node["y"],Node["z"] + 1)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- ADMIN:TUNING
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("admin:Tuning")
AddEventHandler("admin:Tuning",function()
	local Ped = PlayerPedId()
	if IsPedInAnyVehicle(Ped) then
		local Vehicle = GetVehiclePedIsUsing(Ped)

		SetVehicleModKit(Vehicle,0)
		ToggleVehicleMod(Vehicle,18,true)
		SetVehicleMod(Vehicle,11,GetNumVehicleMods(Vehicle,11) - 1,false)
		SetVehicleMod(Vehicle,12,GetNumVehicleMods(Vehicle,12) - 1,false)
		SetVehicleMod(Vehicle,13,GetNumVehicleMods(Vehicle,13) - 1,false)
		SetVehicleMod(Vehicle,15,GetNumVehicleMods(Vehicle,15) - 1,false)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- ADMIN:INITSPECTATE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("admin:initSpectate")
AddEventHandler("admin:initSpectate",function(source)
	if not NetworkIsInSpectatorMode() then
		local Pid = GetPlayerFromServerId(source)
		local Ped = GetPlayerPed(Pid)

		LocalPlayer["state"]:set("Spectate",true,false)
		NetworkSetInSpectatorMode(true,Ped)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- ADMIN:RESETSPECTATE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("admin:resetSpectate")
AddEventHandler("admin:resetSpectate",function()
	if NetworkIsInSpectatorMode() then
		NetworkSetInSpectatorMode(false)
		LocalPlayer["state"]:set("Spectate",false,false)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- ADDSTATEBAGCHANGEHANDLER
-----------------------------------------------------------------------------------------------------------------------------------------
AddStateBagChangeHandler("Quake",nil,function(Name,Key,Value)
	ShakeGameplayCam("SKY_DIVING_SHAKE",1.0)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- LIMPAREA
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Limparea(Coords)
	ClearAreaOfPeds(Coords["x"],Coords["y"],Coords["z"],100.0,0)
	ClearAreaOfCops(Coords["x"],Coords["y"],Coords["z"],100.0,0)
	ClearAreaOfObjects(Coords["x"],Coords["y"],Coords["z"],100.0,0)
	ClearAreaOfProjectiles(Coords["x"],Coords["y"],Coords["z"],100.0,0)
	ClearArea(Coords["x"],Coords["y"],Coords["z"],100.0,true,false,false,false)
	ClearAreaOfVehicles(Coords["x"],Coords["y"],Coords["z"],100.0,false,false,false,false,false)
	ClearAreaLeaveVehicleHealth(Coords["x"],Coords["y"],Coords["z"],100.0,false,false,false,false)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- TEMPO
-----------------------------------------------------------------------------------------------------------------------------------------

local horaAtual = nil

RegisterNetEvent("hora:sincronizar")
AddEventHandler("hora:sincronizar", function(hora)
    horaAtual = tonumber(hora)
end)

CreateThread(function()
    while true do
        Wait(1000)
        if horaAtual then
            NetworkOverrideClockTime(horaAtual, 0, 0)
            PauseClock(true)
        end
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- GODSYN
-----------------------------------------------------------------------------------------------------------------------------------------

local godsynActive = false

RegisterNetEvent("godsyn:toggle")
AddEventHandler("godsyn:toggle", function()
    godsynActive = not godsynActive
    local msg = godsynActive and "Modo ativado." or "Modo desativado."
    TriggerEvent("Notify", "GOD Syn", "<b>"..msg.."</b>", "deus", 5000)


    if godsynActive then
        Citizen.CreateThread(function()
            local ped = PlayerPedId()

            while godsynActive do
                SetPedInfiniteAmmoClip(ped, true)

                if IsPedArmed(ped, 6) and not IsPedReloading(ped) then
                    local _, target = GetEntityPlayerIsFreeAimingAt(PlayerId())
                    if DoesEntityExist(target) and IsEntityAPed(target) and not IsPedDeadOrDying(target) then
                        local targetHeadCoords = GetPedBoneCoords(target, 31086, 0.0, 0.0, 0.0)
                        local camCoords = GetGameplayCamCoord()
                        local cameraRotation = GetGameplayCamRot(2)
                        local inVehicle = IsPedInAnyVehicle(ped)

                        if inVehicle then
                            -- Ajuste para veículos
                            local adjustedTargetCoords = targetHeadCoords + vector3(0.0, 0.0, 0.1)
                            local aimCoords = vector3(
                                adjustedTargetCoords.x + math.sin(math.rad(cameraRotation.z)) * 0.5,
                                adjustedTargetCoords.y - math.cos(math.rad(cameraRotation.z)) * 0.5,
                                adjustedTargetCoords.z
                            )

                            SetPedShootsAtCoord(ped, aimCoords.x, aimCoords.y, aimCoords.z, true)
                        else
                            -- Mira direta à cabeça se estiver a pé
                            SetPedShootsAtCoord(ped, targetHeadCoords.x, targetHeadCoords.y, targetHeadCoords.z + 0.02, true)
                        end

                        -- Pequeno delay entre os tiros
                        Wait(50)
                    end
                end

                Wait(1) -- alívio pequeno (antes era Wait(0))
            end
        end)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- COLETE
-----------------------------------------------------------------------------------------------------------------------------------------


local function LoadAnimDict(dict)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

RegisterNetEvent("admin:applyArmour")
AddEventHandler("admin:applyArmour", function(amount)
    local ped = PlayerPedId()
    amount = math.floor(tonumber(amount) or 100)
    if amount < 0 then amount = 0 end
    if amount > 100 then amount = 100 end

    -- animação de vestir
    local dict, anim = "clothingshirt", "try_shirt_positive_d"
    if LoadAnimDict(dict) then
        TaskPlayAnim(ped, dict, anim, 8.0, 8.0, 1600, 48, 0.0, false, false, false)
        Wait(1100) -- deixa “vestir” antes de aplicar
        RemoveAnimDict(dict)
    end

    -- aplica o armor
    SetPedArmour(ped, amount)

    -- (opcional) se quiseres um “click” no HUD
    -- PlaySoundFrontend(-1, "ATM_WINDOW", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
end)


-----------------------------------------------------------------------------------------------------------------------------------------
-- GUARDARCOLETE
-----------------------------------------------------------------------------------------------------------------------------------------

RegisterNetEvent("admin:checkArmourForSave")
AddEventHandler("admin:checkArmourForSave", function(token)
    local ped = PlayerPedId()
    local armour = GetPedArmour(ped) or 0
    TriggerServerEvent("admin:checkArmourForSave:response", token, armour)
end)

-- devolve o armor atual
RegisterNetEvent("admin:checkArmourForSave")
AddEventHandler("admin:checkArmourForSave", function(token)
    local ped = PlayerPedId()
    TriggerServerEvent("admin:checkArmourForSave:response", token, GetPedArmour(ped) or 0)
end)

-- remove armor + visual e toca animação de vestir/retirar
RegisterNetEvent("admin:removeArmour")
AddEventHandler("admin:removeArmour", function(playAnim)
    local ped = PlayerPedId()

    if playAnim then
        -- animação “vestir camisa”
        local dict, name = "clothingshirt", "try_shirt_positive_d"
        RequestAnimDict(dict)
        local tries = 0
        while not HasAnimDictLoaded(dict) and tries < 100 do
            Wait(10); tries = tries + 1
        end
        if HasAnimDictLoaded(dict) then
            TaskPlayAnim(ped, dict, name, 8.0, 8.0, 1600, 48, 0.0, false, false, false)
            Wait(1200)
        end
        RemoveAnimDict(dict)
    end

    -- zera barra de armor
    SetPedArmour(ped, 0)

    -- garante sync do HUD
    Wait(50)
    SetPedArmour(ped, 0)
end)


-----------------------------------------------------------------------------------------------------------------------------------------
-- GODMODE
-----------------------------------------------------------------------------------------------------------------------------------------

local godmode = false

RegisterNetEvent("admin:toggleGodmode")
AddEventHandler("admin:toggleGodmode", function()
    local ped = PlayerPedId()
    godmode = not godmode

    SetEntityInvincible(ped, godmode)
    SetPlayerInvincible(PlayerId(), godmode)
    SetEntityProofs(ped, godmode, godmode, godmode, godmode, godmode, godmode, godmode, godmode)
    SetPedCanRagdoll(ped, not godmode)

    if godmode then
        TriggerEvent("Notify", "ATIVADO", "Godmode ativado.", 5000)
    else
        TriggerEvent("Notify", "DESATIVADO", "Godmode desativado.", 5000)
    end
end)


-----------------------------------------------------------------------------------------------------------------------------------------
-- TAG STAFF
-----------------------------------------------------------------------------------------------------------------------------------------

local playerTags = {}

local function DrawText3D(x, y, z, text, scale)
    local camCoords = GetGameplayCamCoords()
    local dist = #(camCoords - vector3(x, y, z))
    local dynamicScale = (1 / dist) * 2.0
    local fov = (1 / GetGameplayCamFov()) * 100
    dynamicScale = dynamicScale * fov

    SetTextScale(0.0 * dynamicScale, 0.55 * dynamicScale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 255)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(1)

    SetDrawOrigin(x, y, z, 0)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function DrawTag()
    local nameOffset = 1.0
    local infoOffset = 1.14
    local sleep = 1000

    while true do
        sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        for playerId, tagData in pairs(playerTags) do
            sleep = 0
            local pid = GetPlayerFromServerId(playerId)
            local targetPed = GetPlayerPed(pid)
            if DoesEntityExist(targetPed) then
                -- IGNORA SE O PED ESTIVER INVISÍVEL
                if not IsEntityVisible(targetPed) then
                    goto continue
                end

                local targetCoords = GetEntityCoords(targetPed)
                local distance = #(playerCoords - targetCoords)

                if distance <= 50.0 and IsEntityOnScreen(targetPed) then
                    local tagText = "~g~[STAFF]~w~"
                    if tagData.tagType == "license:fc1ad7eead6a44c1102a1b2e18ae20caffd26fb4" then
                        tagText = "~r~[DONO]~w~"
                    elseif tagData.tagType == "license:3a61e278f67c966704a19d070ed45aaec630b3ec" then
                        tagText = "~b~[DEVELOPER]~w~"
                    elseif tagData.tagType == "license:64e4e726d0a1431b1b4028186dc2be0c663bc69b" then
                        tagText = "~b~[DEVELOPER]~w~"
                    end

                    local fullName = tagText .. " " .. tagData.playerName

                    if NetworkIsPlayerActive(pid) then
                        if tagData.infoText and tagData.infoText ~= "" then
                            DrawText3D(targetCoords.x, targetCoords.y, targetCoords.z + infoOffset, tagData.infoText, 0.5)
                        end
                        DrawText3D(targetCoords.x, targetCoords.y, targetCoords.z + nameOffset, fullName, 0.5)
                    end
                end
            end
            ::continue::
        end
        Wait(sleep)
    end
end

RegisterNetEvent('admin:displayStaffTag', function(playerId, playerName, tagType)
    playerTags[playerId] = {playerName = playerName, tagType = tagType, infoText = ""}
end)

RegisterNetEvent('admin:removeStaffTag', function(playerId)
    playerTags[playerId] = nil
end)

RegisterNetEvent('admin:updateTags', function(updatedTags)
    playerTags = updatedTags
end)

CreateThread(DrawTag)

-----------------------------------------------------------------------------------------------------------------------------------------
-- WALL
-----------------------------------------------------------------------------------------------------------------------------------------

local wallEnabled = false
local activeWall = {}

RegisterNetEvent("wall:toggle")
AddEventHandler("wall:toggle", function(state, wallUsers)
    wallEnabled = state
    activeWall = wallUsers or {}
end)

-- função para texto 3D
local function DrawText3D(coords, text, scale)
    local onScreen, _x, _y = World3dToScreen2d(coords.x, coords.y, coords.z + 0.90)
    if onScreen then
        SetTextScale(scale, scale)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextCentre(true)
        SetTextColour(255, 255, 255, 215)
        SetTextOutline()
        SetTextEntry("STRING")
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

-- função para desenhar linha secundária menor logo abaixo
local function DrawText3DSub(coords, text, scale)
    local onScreen, _x, _y = World3dToScreen2d(coords.x, coords.y, coords.z + 0.97) -- ligeiramente mais baixo
    if onScreen then
        SetTextScale(scale, scale)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextCentre(true)
        SetTextColour(255, 255, 255, 200)
        SetTextOutline()
        SetTextEntry("STRING")
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

CreateThread(function()
    local sleep = 1000

    while true do
        if wallEnabled then
            -- por ciclo cacheamos lista de jogadores e a nossa posição
            local myPed = PlayerPedId()
            local myCoords = GetEntityCoords(myPed)
            local players = GetActivePlayers()
            local foundClose = false

            for _, player in ipairs(players) do
                local target = GetPlayerPed(player)
                if DoesEntityExist(target) then
                    local targetSrc = GetPlayerServerId(player)
                    local coords = GetEntityCoords(target)

                    local distance = #(myCoords - coords)
                    if distance < 300.0 then
                        foundClose = true
                        local name = GetPlayerName(player)
                        local passport = activeWall[targetSrc] and activeWall[targetSrc].passport or "?"
                        local fullName = activeWall[targetSrc] and activeWall[targetSrc].name or "Desconhecido"

                        local tag = string.format("%s ~b~[%d]~w~ - %s", fullName, targetSrc, passport)
                        if activeWall[targetSrc] and activeWall[targetSrc].wall then
                            tag = tag .. " ~r~[WALL]"
                        end

                        ----- HP e Colete
                        -- local hpRaw = GetEntityHealth(target)
                        -- local hpMax = GetEntityMaxHealth(target)
                        -- local hp = math.floor(math.max(0, math.min(100, ((hpRaw - 100) / math.max(1, (hpMax - 100))) * 100)) + 0.5)
                        -- local armor = math.floor(math.max(0, math.min(100, GetPedArmour(target))) + 0.5)

                        -- local sub = ("~g~HP~w~: %d - ~b~COLETE~w~: %d"):format(hp, armor)

                        -- desenhar linha principal
                        DrawText3D(coords, tag, 0.30)
                        -- desenhar linha secundária menor
                        -- DrawText3DSub(coords, sub, 0.25)
                    end
                end
            end

            -- se houver pelo menos um jogador próximo fazemos render por frame (sleep 0),
            -- caso contrário aliviamos a carga e verificamos apenas a cada 1s.
            sleep = foundClose and 0 or 1000
        else
            sleep = 1000
        end
        Wait(sleep)
    end
end)

-- 3) SPEED: reduzir frequência de reaplicação para 50ms (suficiente e menos CPU)
local Speed = { enabled = false, mult = 1.0, running = false }

RegisterNetEvent("admin:SpeedApply")
AddEventHandler("admin:SpeedApply", function(enable, mult)
    mult = tonumber(mult) or 1.0
    if mult < 1.0 then mult = 1.0 end
    if mult > 1.49 then mult = 1.49 end

    Speed.enabled = enable and mult > 1.0
    Speed.mult = mult

    if not Speed.enabled then
        -- reset
        SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
        SetPedMoveRateOverride(PlayerPedId(), 1.0)
        return
    end

    if not Speed.running then
        Speed.running = true
        CreateThread(function()
            while Speed.enabled do
                local ped = PlayerPedId()
                -- aplicar continuamente (agora a cada 50ms para reduzir CPU)
                SetRunSprintMultiplierForPlayer(PlayerId(), Speed.mult)
                SetPedMoveRateOverride(ped, Speed.mult)
                RestorePlayerStamina(PlayerId(), 1.0)
                Wait(50)
            end
            -- reset ao sair do loop
            SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
            SetPedMoveRateOverride(PlayerPedId(), 1.0)
            Speed.running = false
        end)
    end
end)

-- 4) invis collision thread: reduzir frequência para 100ms (a colisão não precisa de 0ms)
local invis = false
local collisionThread = nil

RegisterNetEvent("staff:ToggleInvis")
AddEventHandler("staff:ToggleInvis", function()
    local ped = PlayerPedId()
    invis = not invis

    if invis then
        -- Invisibilidade
        SetEntityVisible(ped,false,false)
        SetLocalPlayerVisibleLocally(true)
        SetEntityAlpha(ped,0,false)

        -- Esconder arma visível
        local currentWeapon = GetSelectedPedWeapon(ped)
        if currentWeapon and currentWeapon ~= `WEAPON_UNARMED` then
            local weaponObj = GetCurrentPedWeaponEntityIndex(ped, 0)
            if DoesEntityExist(weaponObj) then
                SetEntityVisible(weaponObj, false, false)
            end
        end

        collisionThread = CreateThread(function()
            while invis do
                local coords = GetEntityCoords(ped)
                -- Jogadores
                for _, player in ipairs(GetActivePlayers()) do
                    local otherPed = GetPlayerPed(player)
                    if otherPed ~= ped then
                        SetEntityNoCollisionEntity(ped, otherPed, true)
                        SetEntityNoCollisionEntity(otherPed, ped, true)
                    end
                end
                -- Veículos
                local veh = GetVehiclePedIsIn(ped, false)
                if veh > 0 then
                    for vehicle in EnumerateVehicles() do
                        if vehicle ~= veh then
                            SetEntityNoCollisionEntity(veh, vehicle, true)
                        end
                    end
                end
                Wait(100) -- reduzir para 100ms para aliviar CPU
            end
        end)

        TriggerEvent("Notify","Staff","Invisibilidade e sem colisão ativadas.", "verde", 5000)
    else
        -- Visibilidade normal
        SetEntityVisible(ped,true,false)
        ResetEntityAlpha(ped)

        local currentWeapon = GetSelectedPedWeapon(ped)
        if currentWeapon and currentWeapon ~= `WEAPON_UNARMED` then
            local weaponObj = GetCurrentPedWeaponEntityIndex(ped, 0)
            if DoesEntityExist(weaponObj) then
                SetEntityVisible(weaponObj, true, false)
            end
        end

        SetEntityCollision(ped, true, true)
        local veh = GetVehiclePedIsIn(ped, false)
        if veh > 0 then
            SetEntityCollision(veh, true, true)
        end

        TriggerEvent("Notify","Staff","Invisibilidade e sem colisão desativadas.", "amarelo", 5000)
    end
end)

-- 5) godsyn: reduzir Wait(0) para Wait(1) no loop principal (mantendo pequenas waits entre tiros)
local godsynActive = false

RegisterNetEvent("godsyn:toggle")
AddEventHandler("godsyn:toggle", function()
    godsynActive = not godsynActive
    local msg = godsynActive and "Modo ativado." or "Modo desativado."
    TriggerEvent("Notify", "GOD Syn", "<b>"..msg.."</b>", "deus", 5000)

    if godsynActive then
        Citizen.CreateThread(function()
            local ped = PlayerPedId()

            while godsynActive do
                SetPedInfiniteAmmoClip(ped, true)

                if IsPedArmed(ped, 6) and not IsPedReloading(ped) then
                    local _, target = GetEntityPlayerIsFreeAimingAt(PlayerId())
                    if DoesEntityExist(target) and IsEntityAPed(target) and not IsPedDeadOrDying(target) then
                        local targetHeadCoords = GetPedBoneCoords(target, 31086, 0.0, 0.0, 0.0)
                        local camCoords = GetGameplayCamCoord()
                        local cameraRotation = GetGameplayCamRot(2)
                        local inVehicle = IsPedInAnyVehicle(ped)

                        if inVehicle then
                            local adjustedTargetCoords = targetHeadCoords + vector3(0.0, 0.0, 0.1)
                            local aimCoords = vector3(
                                adjustedTargetCoords.x + math.sin(math.rad(cameraRotation.z)) * 0.5,
                                adjustedTargetCoords.y - math.cos(math.rad(cameraRotation.z)) * 0.5,
                                adjustedTargetCoords.z
                            )

                            SetPedShootsAtCoord(ped, aimCoords.x, aimCoords.y, aimCoords.z, true)
                        else
                            SetPedShootsAtCoord(ped, targetHeadCoords.x, targetHeadCoords.y, targetHeadCoords.z + 0.02, true)
                        end

                        Wait(50)
                    end
                end

                Wait(1) -- alívio pequeno (antes era Wait(0))
            end
        end)
    end
end)


-----------------------------------------------------------------------------------------------------------------------------------------
-- CLIENT: LIMPAR PEDS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("staff:ClearPeds")
AddEventHandler("staff:ClearPeds", function(tipo)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    for _, entity in ipairs(GetGamePool("CPed")) do
        if not IsPedAPlayer(entity) then
            if tipo == "todos" or #(coords - GetEntityCoords(entity)) <= 50.0 then
                DeleteEntity(entity)
            end
        end
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- CLIENT: LIMPAR OBJETOS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("staff:ClearObjects")
AddEventHandler("staff:ClearObjects", function(tipo)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    for _, entity in ipairs(GetGamePool("CObject")) do
        if tipo == "todos" or #(coords - GetEntityCoords(entity)) <= 65.0 then
            DeleteEntity(entity)
        end
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- DEBUG
-----------------------------------------------------------------------------------------------------------------------------------------

local debugOn = false
local lastNearby = { src = -1, passport = 0, fullname = "", stamp = 0 }
local _ping = 0

RegisterNetEvent("debug:setPing", function(val)
    _ping = tonumber(val) or 0
end)


--  toggler + notif bonita 
RegisterNetEvent("debug:toggle", function()
    debugOn = not debugOn
    if debugOn then
        TriggerEvent("Notify","Debug","<b>Debug ligado</b>. Painel no ecrã.", "verde", 3000)
        CreateThread(function()
            while debugOn do
                TriggerServerEvent("debug:reqPing")
                Wait(2000)
            end
        end)
    else
        TriggerEvent("Notify","Debug","<b>Debug desligado</b>.", "amarelo", 2500)
    end
end)

RegisterNetEvent("debug:replyPlayerInfo", function(data)
    if data and data.targetSrc == lastNearby.src then
        lastNearby.passport = data.passport or 0
        lastNearby.fullname = data.fullname or ""
        lastNearby.stamp = GetGameTimer()
    end
end)

-- helpers universais 
local function SafeZone()
    local safe = GetSafeZoneSize()
    local inv  = 1.0 - safe
    return inv * 0.5, inv * 0.5
end

local function DrawTxt(x, y, scale, text)
    local sx, sy = SafeZone()
    x = x + sx; y = y + sy

    SetTextFont(4)
    SetTextProportional(0)
    SetTextScale(scale, scale)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextDropshadow(1, 0, 0, 0, 255)
    SetTextOutline()
    SetTextColour(255,255,255,255)
    SetTextJustification(1) -- left

    SetTextEntry("STRING")
    AddTextComponentString(text) -- maior compatibilidade
    DrawText(x, y)
end

local function DrawBox(x,y,w,h,a)
    local sx, sy = SafeZone()
    DrawRect(x + sx + w/2, y + sy + h/2, w, h, 0, 0, 0, a)
end

local function round(n, d) return math.floor(n * 10^d + 0.5) / 10^d end

--  data 
local function getCoordsInfo()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    local fwd = GetEntityForwardVector(ped)
    local streetHash, crossHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(streetHash)
    local cross  = crossHash ~= 0 and GetStreetNameFromHashKey(crossHash) or ""
    local zoneName = GetNameOfZone(coords.x, coords.y, coords.z)
    local zone   = GetLabelText(zoneName)
    if zone == "NULL" then zone = zoneName end
    return {
        x=coords.x,y=coords.y,z=coords.z,h=h,
        fx=fwd.x,fy=fwd.y,fz=fwd.z,
        street=street,cross=cross,zone=zone
    }
end

local function RotationToDirection(rotation)
    local z = math.rad(rotation.z)
    local x = math.rad(rotation.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

local function rayCastFromCam(dist)
    local camRot = GetGameplayCamRot(2)
    local camPos = GetGameplayCamCoord()
    local dir    = RotationToDirection(camRot)
    local destX  = camPos.x + dir.x * dist
    local destY  = camPos.y + dir.y * dist
    local destZ  = camPos.z + dir.z * dist
    local ray = StartShapeTestRay(camPos.x, camPos.y, camPos.z, destX, destY, destZ, -1, PlayerPedId(), 0)
    local _, hit, endCoords, _, entityHit = GetShapeTestResult(ray)
    return hit == 1, endCoords, entityHit
end

local function entityInfo(entity)
    -- validações duras para evitar crash
    if not entity or type(entity) ~= "number" then
        return { type = "none" }
    end
    if entity == 0 then
        return { type = "none" }
    end
    -- alguns builds precisam de DoesEntityExist antes de QUALQUER native de entity
    if not DoesEntityExist(entity) then
        return { type = "none" }
    end

    local etype = "object"
    if IsEntityAVehicle(entity) then
        etype = "vehicle"
    elseif IsEntityAPed(entity) then
        etype = "ped"
    end

    local model = 0
    -- protege GetEntityModel com pcall caso algum wrapper esteja a interceptar
    local ok, m = pcall(GetEntityModel, entity)
    if ok and m then model = m end

    local netId = -1
    ok, m = pcall(NetworkGetNetworkIdFromEntity, entity)
    if ok and m then netId = m end

    local cx, cy, cz = table.unpack(GetEntityCoords(entity))
    return { type = etype, model = model, netId = netId, id = entity, x = cx, y = cy, z = cz }
end

local function nearbyPlayer()
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local closest, closestDist, closestServer = -1, 9999.0, -1

    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() then
            local ped = GetPlayerPed(player)
            local dist = #(GetEntityCoords(ped) - myCoords)
            if dist < closestDist then
                closest = player
                closestDist = dist
                closestServer = GetPlayerServerId(player)
            end
        end
    end

    if closest ~= -1 then
        if lastNearby.src ~= closestServer or (GetGameTimer() - lastNearby.stamp) > 3000 then
            lastNearby.src = closestServer
            TriggerServerEvent("debug:requestPlayerInfo", closestServer)
        end
        return { src=closestServer, dist=closestDist, passport=lastNearby.passport or 0, fullname=lastNearby.fullname or "" }
    end

    lastNearby = { src = -1, passport = 0, fullname = "", stamp = 0 }
    return { src=-1, dist=-1, passport=0, fullname="" }
end

local function vehicleInfo()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped,false) then return nil end
    local veh = GetVehiclePedIsIn(ped,false)
    local model = GetEntityModel(veh)
    local display = GetDisplayNameFromVehicleModel(model)
    local name = GetLabelText(display)
    if name == "NULL" then name = display end
    return {
        name=name, model=model, hash=model,
        plate=GetVehicleNumberPlateText(veh),
        health=GetVehicleEngineHealth(veh),
        netId=NetworkGetNetworkIdFromEntity(veh),
        id=veh
    }
end


local function dist3(a, b)
    return Vdist(a.x, a.y, a.z, b.x, b.y, b.z)
end

--  painel 
local function drawAllDebug()
    local ped = PlayerPedId()
    local c = getCoordsInfo()
    local fps = math.floor(1.0 / GetFrameTime())
    local ping = _ping
    local interior = GetInteriorFromEntity(ped)
    local hag = round(GetEntityHeightAboveGround(ped),2)
    local hour, minute = GetClockHours(), GetClockMinutes()
    local hit, hitPos, ent = rayCastFromCam(500.0)
    local e = entityInfo(ent)
    local myPos = GetEntityCoords(ped)
    local dist = hit and dist3(myPos, hitPos) or -1
    local near = nearbyPlayer()
    local veh = vehicleInfo()

    ----- Banner TESTE grande (primeiras 2s após ligar)
    -- if (GetGameTimer() - (lastNearby.stamp or 0)) < 2000 then
    --     DrawBox(0.38, 0.04, 0.24, 0.05, 150)
    --     DrawTxt(0.395, 0.055, 0.5, "~b~DEBUG ATIVO~s~")
    -- end

    local x, y = 0.015, 0.50
    local lineH = 0.020
    local width = 0.40
    local baseLines = 16
    local lines = baseLines + (veh and 2 or 1)
    -- DrawBox(x-0.010, y-0.010, width+0.020, (lines+2)*lineH+0.010, 140)
    --  DrawTxt(x, y - 0.012, 0.90, "~b~DEBUG STAFF~s~  (/debug)")
    local line = 0
    local function L(txt) DrawTxt(x, y + line*lineH, 0.32, txt); line = line + 1 end

    L(("~y~LOCALIZAÇÃO~s~  x: ~b~%.3f~s~  y: ~b~%.3f~s~  z: ~b~%.3f~s~  h: ~b~%.2f"):format(c.x, c.y, c.z, c.h))
    L(("forward: ~b~(%.2f, %.2f, %.2f)"):format(c.fx, c.fy, c.fz))
    L(("rua: ~b~%s~s~  cruz.: ~b~%s~s~  zona: ~b~%s"):format(c.street, (c.cross ~= "" and c.cross or "-"), c.zone))
    L(("fps: ~b~%d~s~  ping: ~b~%d~s~  interior: ~b~%d~s~  HAG: ~b~%.2f~s~  hora: ~b~%02d:%02d"):format(fps, ping, interior, hag, hour, minute))

    L(" ")
    L("~y~MIRA")
    if hit then
        L(("coords: ~b~%.3f, %.3f, %.3f~s~  dist: ~b~%.2f"):format(hitPos.x, hitPos.y, hitPos.z, dist))
    else
        L("coords: ~r~sem hit")
    end
    L(("entity: ~b~%s~s~  model: ~b~%s~s~  netID: ~b~%d~s~  entID: ~b~%d"):format(e.type, (e.model ~= 0 and tostring(e.model) or "-"), e.netId or -1, e.id or -1))

    L(" ")
    L("~y~PRÓXIMO JOGADOR")
    if near.src ~= -1 then
        L(("src: ~b~%d~s~  passaporte: ~b~%d~s~  nome: ~b~%s~s~  dist: ~b~%.2f"):format(near.src, near.passport, (near.fullname ~= "" and near.fullname or "-"), near.dist))
    else
        L("~r~nenhum próximo")
    end

    L(" ")
    L("~y~VEÍCULO ATUAL")
    if veh then
        L(("nome: ~b~%s~s~  modelo/hash: ~b~%s / %d"):format(veh.name, GetDisplayNameFromVehicleModel(veh.model), veh.hash))
        L(("placa: ~b~%s~s~  motor: ~b~%.1f~s~  netID: ~b~%d~s~  entID: ~b~%d"):format(veh.plate, veh.health, veh.netId, veh.id))
    else
        L("~r~Não está em veículo.")
    end
end

--  loop 
CreateThread(function()
    while true do
        if debugOn then
            drawAllDebug()
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- FREEZE LOCAL (apenas o jogador alvo)
-----------------------------------------------------------------------------------------------------------------------------------------
local AdminFrozen = false

RegisterNetEvent("admin:toggleFreeze")
AddEventHandler("admin:toggleFreeze", function(state)
    local ped = PlayerPedId()
    AdminFrozen = state

    -- travar imediatamente
    ClearPedTasksImmediately(ped)
    SetEntityVelocity(ped, 0.0, 0.0, 0.0)
    SetPedCanRagdoll(ped, not state)
    FreezeEntityPosition(ped, state)
    SetPlayerControl(PlayerId(), not state, 0) -- congela input real

    if state then
        -- loop anti-input
        CreateThread(function()
            while AdminFrozen do
                -- movimento a pé
                DisableControlAction(0, 30, true)   -- left/right
                DisableControlAction(0, 31, true)   -- fwd/back
                DisableControlAction(0, 21, true)   -- sprint
                DisableControlAction(0, 22, true)   -- jump
                DisableControlAction(0, 24, true)   -- attack
                DisableControlAction(0, 25, true)   -- aim
                DisableControlAction(0, 32, true)   -- W
                DisableControlAction(0, 33, true)   -- S
                DisableControlAction(0, 34, true)   -- A
                DisableControlAction(0, 35, true)   -- D
                -- em veículo
                DisableControlAction(0, 71, true)   -- acelera
                DisableControlAction(0, 72, true)   -- trava
                DisableControlAction(0, 63, true)   -- virar esq
                DisableControlAction(0, 64, true)   -- virar dir
                DisableControlAction(0, 75, true)   -- sair veículo
                DisableControlAction(0, 23, true)   -- entrar veículo
                Wait(0)
            end
        end)
    else
        -- restaurar
        EnableAllControlActions(0)
        SetPlayerControl(PlayerId(), true, 0)
        SetPedCanRagdoll(ped, true)
        FreezeEntityPosition(ped, false)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- DESBUGAR: Death / Crawl / Handcuff / Tarefas / Colisões
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("admin:clearPlayerStates")
AddEventHandler("admin:clearPlayerStates", function()
    local ped = PlayerPedId()

    -- Death -> revive se necessário
    local isDead = IsEntityDead(ped) or (LocalPlayer and LocalPlayer.state and LocalPlayer.state.Death)
    if isDead then
        local c = GetEntityCoords(ped)
        NetworkResurrectLocalPlayer(c.x + 0.0, c.y + 0.0, c.z + 0.0, GetEntityHeading(ped), true, true, false)
        ClearPedBloodDamage(ped)
        SetEntityHealth(ped, 200)
        if LocalPlayer and LocalPlayer.state then
            LocalPlayer.state:set("Death", false, true)
        end
    end

    -- Crawl -> força off
    if LocalPlayer and LocalPlayer.state and LocalPlayer.state.Crawl then
        LocalPlayer.state:set("Crawl", false, true)
    end

    -- Respeita algemas: só limpa se NÃO estiver algemado
    local cuffed = LocalPlayer and LocalPlayer.state and LocalPlayer.state.Handcuff or false
    if not cuffed then
        SetEnableHandcuffs(ped, false)
        ClearPedTasksImmediately(ped)
        ClearPedSecondaryTask(ped)
        DetachEntity(ped, true, true)
        EnableAllControlActions(0)
    end

    -- Estados gerais
    ResetPedRagdollTimer(ped)
    SetPedCanRagdoll(ped, true)
    FreezeEntityPosition(ped, false)

    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        FreezeEntityPosition(veh, false)
        SetVehicleBrake(veh, false)
        SetVehicleHandbrake(veh, false)
    end
end)


-----------------------------------------------------------------------------------------------------------------------------------------
-- FECHAR PERIMETRO
-----------------------------------------------------------------------------------------------------------------------------------------

local vSERVER = Tunnel.getInterface("perimetro")

-- Interface client para o server chamar
local PERIMETRO_CLIENT = {}
Tunnel.bindInterface("perimetro", PERIMETRO_CLIENT)

function PERIMETRO_CLIENT.GetLocationLabel(coords)
    local x, y, z = coords.x + 0.0, coords.y + 0.0, coords.z + 0.0
    local s1, s2 = GetStreetNameAtCoord(x, y, z)
    local street  = s1 ~= 0 and GetStreetNameFromHashKey(s1) or nil
    local cross   = s2 ~= 0 and GetStreetNameFromHashKey(s2) or nil
    local zoneKey = GetNameOfZone(x, y, z)
    local zone    = (zoneKey and zoneKey ~= "") and GetLabelText(zoneKey) or nil

    local parts = {}
    if street and street ~= "" then table.insert(parts, street) end
    if cross and cross ~= "" then table.insert(parts, "x "..cross) end
    local left = table.concat(parts, " ")
    if left ~= "" and zone and zone ~= "" then
        return left.." — "..zone
    end
    if zone and zone ~= "" then return zone end
    if left ~= "" then return left end
    return ("%.1f, %.1f"):format(x, y) -- fallback
end

-- Estado
local PERIMETRO = {}
local BLIPS = {}
local inside = {}
local lastWarn = {}
local isPolice = false
local lastPoliceCheck = 0

-- Blips
local function createBlips(p)
    local rb = AddBlipForRadius(p.coords.x + 0.0, p.coords.y + 0.0, p.coords.z + 0.0, p.radius + 0.0)
    SetBlipColour(rb, 1)      -- vermelho
    SetBlipAlpha(rb, 120)

    local cb = AddBlipForCoord(p.coords.x, p.coords.y, p.coords.z)
    SetBlipSprite(cb, 60)     -- ícone polícia
    SetBlipColour(cb, 1)      -- vermelho
    SetBlipScale(cb, 0.9)
    SetBlipAsShortRange(cb, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(("🔴 ZONA PERIGOSA — %s"):format(p.name or "Local"))
    EndTextCommandSetBlipName(cb)

    BLIPS[p.id] = { rb, cb }
end

local function removeBlips(id)
    if BLIPS[id] then
        local rb, cb = table.unpack(BLIPS[id])
        if rb and DoesBlipExist(rb) then RemoveBlip(rb) end
        if cb and DoesBlipExist(cb) then RemoveBlip(cb) end
        BLIPS[id] = nil
    end
end

-- Sync
RegisterNetEvent("perimetro:syncAll")
AddEventHandler("perimetro:syncAll", function(list)
    for id,_ in pairs(BLIPS) do removeBlips(id) end
    PERIMETRO, inside, lastWarn = {}, {}, {}
    for id,data in pairs(list or {}) do
        PERIMETRO[id] = data
        createBlips(data)
    end
end)

RegisterNetEvent("perimetro:add")
AddEventHandler("perimetro:add", function(data)
    PERIMETRO[data.id] = data
    createBlips(data)
    TriggerEvent("Notify","🚧 Perímetro",("Ativado: <b>%s</b>. Cautela na área."):format(data.name or ("#"..data.id)),"azul",6000)
end)

RegisterNetEvent("perimetro:remove")
AddEventHandler("perimetro:remove", function(id)
    local old = PERIMETRO[id]
    PERIMETRO[id] = nil
    inside[id] = nil
    lastWarn[id] = nil
    removeBlips(id)
    local nome = old and old.name or ("#"..id)
    TriggerEvent("Notify","🚧 Perímetro",("Desativado: <b>%s</b>."):format(nome),"verde",4500)
end)

-- Pedir sync ao entrar/carregar
CreateThread(function()
    Wait(1500)
    TriggerServerEvent("perimetro:requestSync")
end)

-- Cache de permissão
CreateThread(function()
    while true do
        if GetGameTimer() - lastPoliceCheck > 5000 then
            lastPoliceCheck = GetGameTimer()
            local ok, res = pcall(function() return vSERVER.IsPolice() end)
            if ok then isPolice = res == true end
        end
        Wait(1000)
    end
end)

-- Avisos a civis
CreateThread(function()
    while true do
        local sleep = 750
        if not isPolice then
            local ped = PlayerPedId()
            local pcoords = GetEntityCoords(ped)
            for id, z in pairs(PERIMETRO) do
                local dist = #(pcoords - vector3(z.coords.x, z.coords.y, z.coords.z))
                if dist <= (z.radius + 0.1) then
                    sleep = 200
                    if not inside[id] then
                        inside[id] = true
                        lastWarn[id] = GetGameTimer()
                        TriggerEvent("Notify","🚨 ALERTA",
                            "Entraste numa <b>🔴 ZONA PERIGOSA</b> — <b>Afasta-te imediatamente!</b><br><i>Risco de bala perdida.</i>",
                            "vermelho", 9000)
                    else
                        local now = GetGameTimer()
                        if not lastWarn[id] or (now - lastWarn[id] >= 30000) then
                            lastWarn[id] = now
                            TriggerEvent("Notify","⚠️ Aviso",
                                "Continuas em <b>ZONA PERIGOSA</b>. Recuar da área é recomendado.",
                                "amarelo", 7000)
                        end
                    end
                else
                    if inside[id] then
                        inside[id] = false
                        TriggerEvent("Notify","✅ Seguro","Abandonaste a zona perigosa. Mantém-te atento.","verde",3500)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)


-----------------------------------------------------------------------------------------------------------------------------------------
-- RGB
-----------------------------------------------------------------------------------------------------------------------------------------
local rgbEnabled = false
local rgbThread = nil

local function setSynPlate(veh)
    SetVehicleNumberPlateText(veh, "SYNGOD")
end

local function startRGB(veh)
    if rgbThread then return end
    rgbThread = true
    CreateThread(function()
        local t = 0.0
        while rgbEnabled and DoesEntityExist(veh) do
            local r = math.floor((math.sin(t) * 0.5 + 0.5) * 255)
            local g = math.floor((math.sin(t + 2.094) * 0.5 + 0.5) * 255)
            local b = math.floor((math.sin(t + 4.188) * 0.5 + 0.5) * 255)

            -- Cor do carro
            SetVehicleCustomPrimaryColour(veh, r,g,b)
            SetVehicleCustomSecondaryColour(veh, r,g,b)

            -- Néons
            for i=0,3 do SetVehicleNeonLightEnabled(veh, i, true) end
            SetVehicleNeonLightsColour(veh, r,g,b)

            t = t + 0.05
            Wait(100)
        end
        rgbThread = nil
    end)
end

RegisterNetEvent("rgb:toggle")
AddEventHandler("rgb:toggle", function()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped,false) then
        TriggerEvent("Notify","RGB","Entra num veículo primeiro.", "amarelo", 5000)
        return
    end
    local veh = GetVehiclePedIsIn(ped,false)
    if GetPedInVehicleSeat(veh,-1) ~= ped then
        TriggerEvent("Notify","RGB","Precisas de estar ao volante.", "amarelo", 5000)
        return
    end

    rgbEnabled = not rgbEnabled
    if rgbEnabled then
        setSynPlate(veh)
        startRGB(veh)
        TriggerEvent("Notify","RGB","RGB <b>ATIVADO</b> com matrícula SYNGOD.", "verde", 5000)
    else
        TriggerEvent("Notify","RGB","RGB <b>DESATIVADO</b>.", "azul", 4000)
    end
end)


-----------------------------------------------------------------------------------------------------------------------------------------
-- INVIS
-----------------------------------------------------------------------------------------------------------------------------------------

local invis = false
local collisionThread = nil

RegisterNetEvent("staff:ToggleInvis")
AddEventHandler("staff:ToggleInvis", function()
    local ped = PlayerPedId()
    invis = not invis

    if invis then
        -- Invisibilidade
        SetEntityVisible(ped,false,false)
        SetLocalPlayerVisibleLocally(true)
        SetEntityAlpha(ped,0,false)

        -- Esconder arma visível
        local currentWeapon = GetSelectedPedWeapon(ped)
        if currentWeapon and currentWeapon ~= `WEAPON_UNARMED` then
            local weaponObj = GetCurrentPedWeaponEntityIndex(ped, 0)
            if DoesEntityExist(weaponObj) then
                SetEntityVisible(weaponObj, false, false)
            end
        end

        -- Desativar colisão (loop para manter)
        collisionThread = CreateThread(function()
            while invis do
                local coords = GetEntityCoords(ped)
                -- Jogadores
                for _, player in ipairs(GetActivePlayers()) do
                    local otherPed = GetPlayerPed(player)
                    if otherPed ~= ped then
                        SetEntityNoCollisionEntity(ped, otherPed, true)
                        SetEntityNoCollisionEntity(otherPed, ped, true)
                    end
                end
                -- Veículos
                local veh = GetVehiclePedIsIn(ped, false)
                if veh > 0 then
                    for vehicle in EnumerateVehicles() do
                        if vehicle ~= veh then
                            SetEntityNoCollisionEntity(veh, vehicle, true)
                        end
                    end
                end
                Wait(100) -- reduzir para 100ms para aliviar CPU
            end
        end)

        TriggerEvent("Notify","Staff","Invisibilidade e sem colisão ativadas.", "verde", 5000)
    else
        -- Visibilidade normal
        SetEntityVisible(ped,true,false)
        ResetEntityAlpha(ped)

        -- Mostrar arma de novo
        local currentWeapon = GetSelectedPedWeapon(ped)
        if currentWeapon and currentWeapon ~= `WEAPON_UNARMED` then
            local weaponObj = GetCurrentPedWeaponEntityIndex(ped, 0)
            if DoesEntityExist(weaponObj) then
                SetEntityVisible(weaponObj, true, false)
            end
        end

        -- Restaurar colisão
        SetEntityCollision(ped, true, true)
        local veh = GetVehiclePedIsIn(ped, false)
        if veh > 0 then
            SetEntityCollision(veh, true, true)
        end

        TriggerEvent("Notify","Staff","Invisibilidade e sem colisão desativadas.", "amarelo", 5000)
    end
end)

-- Enumerador de veículos (helper)
function EnumerateVehicles()
    return coroutine.wrap(function()
        local handle, veh = FindFirstVehicle()
        local success
        repeat
            coroutine.yield(veh)
            success, veh = FindNextVehicle(handle)
        until not success
        EndFindVehicle(handle)
    end)
end

-- ====
-- Comandos /vec3 e /vec4 (Syn Network)
-- Requer o resource: syn_clipboard
-- ====
RegisterCommand("vec3", function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local str = string.format("vec3(%.2f, %.2f, %.2f)", coords.x, coords.y, coords.z)

    local ok = pcall(function()
        return exports["syn_clipboard"]:Copy(str)
    end)

    if not ok then
        -- Fallback por evento (se preferires)
        TriggerEvent("syn_clipboard:Copy", str)
    end

    -- Também loga em consola para conferência
    print("[VEC3] "..str)
end)

RegisterCommand("vec4", function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local str = string.format("vec4(%.2f, %.2f, %.2f, %.2f)", coords.x, coords.y, coords.z, heading)

    local ok = pcall(function()
        return exports["syn_clipboard"]:Copy(str)
    end)

    if not ok then
        TriggerEvent("syn_clipboard:Copy", str)
    end

    print("[VEC4] "..str)
end)


-----------------------------------------------------------------------------------------------------------------------------------------
-- APLICAR PED TEMPORÁRIO
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("staff:SetPedModel")
AddEventHandler("staff:SetPedModel", function(modelName)
    local hash = GetHashKey(modelName)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        TriggerEvent("Notify", "Sistema", "Modelo <b>inválido</b>.", "vermelho", 5000)
        return
    end

    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(0) end

    SetPlayerModel(PlayerId(), hash)
    SetModelAsNoLongerNeeded(hash)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- RESETAR PARA FREEMODE (M ou F consoante DB)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("staff:ResetPedModel")
AddEventHandler("staff:ResetPedModel", function(sex, clothes, barber, tattoos)
    local modelName = (sex == "F") and "mp_f_freemode_01" or "mp_m_freemode_01"
    local hash = GetHashKey(modelName)

    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(0) end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    SetPlayerModel(PlayerId(), hash)
    SetModelAsNoLongerNeeded(hash)
    ped = PlayerPedId()

    -- garantir posição/heading inalterados
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(ped, heading)
    SetPedDefaultComponentVariation(ped)

    -- aplica presets da DB (com segurança)
    if clothes and next(clothes) then
        pcall(function() exports["skinshop"]:Apply(clothes, ped) end)
    end
    if barber and next(barber) then
        pcall(function() exports["barbershop"]:Apply(barber, ped) end)
    end
    if tattoos and next(tattoos) then
        pcall(function() exports["tattooshop"]:Apply(tattoos, ped) end)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- DESBUG CURSOR
-----------------------------------------------------------------------------------------------------------------------------------------

-- [RESCUE DO CURSOR] — Syn Network
-- Colocar isto em qualquer recurso client que carregue sempre.

local function ReleaseCursor(spamMs)
    spamMs = tonumber(spamMs) or 300
    local timeout = GetGameTimer() + spamMs

    -- força o clear várias frames (caso outro script esteja a re-setar)
    while GetGameTimer() < timeout do
        SetNuiFocus(false,false)
        SetNuiFocusKeepInput(false)
        -- recentra o cursor (opcional, ajuda a “soltar”)
        SetCursorLocation(0.5,0.5)
        -- garante controlo do jogador
        SetPlayerControl(PlayerId(), true, 0)
        Wait(50)
    end
end

-- Comando + Keybind (F10 por defeito)
RegisterCommand("fixcursor", function() ReleaseCursor(400) end)
RegisterKeyMapping("fixcursor","Libertar cursor preso (RESCUE)","keyboard","F10")

-- Evento público (para outros recursos chamarem)
RegisterNetEvent("cursor:release", function() ReleaseCursor(350) end)

-- Fecha sempre que o recurso do target para (ajusta o nome se precisares)
local TARGET_RESOURCE = "target"      -- <<-- muda para o nome do teu recurso de target, se for diferente
AddEventHandler("onResourceStop", function(res)
    if res == TARGET_RESOURCE or res == GetCurrentResourceName() then
        ReleaseCursor(250)
    end
end)

-- Fallback ao abrir o pause
CreateThread(function()
    local wasPaused = false
    while true do
        local paused = IsPauseMenuActive()
        if paused and not wasPaused then
            ReleaseCursor(200)
        end
        wasPaused = paused
        Wait(250)
    end
end)

-- Fallback no ESC/Backspace do frontend (solta caso algum menu NUI tenha crashado)
CreateThread(function()
    while true do
        -- 200=Pause, 322=ESC, 177=Backspace (frontend)
        if IsControlJustPressed(0,200) or IsControlJustPressed(0,322) or IsControlJustPressed(0,177) then
            ReleaseCursor(150)
        end
        Wait(100)
    end
end)

---------------------------------------------------------------------
-- SPEED BOOST (robusto: reaplica a cada frame)
---------------------------------------------------------------------
local Speed = { enabled = false, mult = 1.0, running = false }

RegisterNetEvent("admin:SpeedApply")
AddEventHandler("admin:SpeedApply", function(enable, mult)
    mult = tonumber(mult) or 1.0
    if mult < 1.0 then mult = 1.0 end
    if mult > 1.49 then mult = 1.49 end

    Speed.enabled = enable and mult > 1.0
    Speed.mult = mult

    if not Speed.enabled then
        -- reset
        SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
        SetPedMoveRateOverride(PlayerPedId(), 1.0)
        return
    end

    if not Speed.running then
        Speed.running = true
        CreateThread(function()
            while Speed.enabled do
                local ped = PlayerPedId()
                -- aplicar continuamente (agora a cada 50ms para reduzir CPU)
                SetRunSprintMultiplierForPlayer(PlayerId(), Speed.mult)
                SetPedMoveRateOverride(ped, Speed.mult)
                RestorePlayerStamina(PlayerId(), 1.0)
                Wait(50)
            end
            -- reset ao sair do loop
            SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
            SetPedMoveRateOverride(PlayerPedId(), 1.0)
            Speed.running = false
        end)
    end
end)

-- segurança ao parar o resource
AddEventHandler("onResourceStop", function(res)
    if res == GetCurrentResourceName() then
        SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
        SetPedMoveRateOverride(PlayerPedId(), 1.0)
    end
end)


---------------------------------------------------------------------
-- SINCRONIZAÇÃO LOCAL (opcional, dá jeito para outros scripts lerem)
-- O teu HUD envia "hud:Wanted" com os segundos restantes.
---------------------------------------------------------------------
RegisterNetEvent("hud:Wanted")
AddEventHandler("hud:Wanted", function(secondsLeft)
    local wanted = (tonumber(secondsLeft) or 0) > 0
    if LocalPlayer and LocalPlayer.state then
        LocalPlayer.state:set("Wanted", wanted, true)
        LocalPlayer.state:set("WantedExpire", wanted and (GetCloudTimeAsInt() + secondsLeft) or nil, true)
    end
end)

------------- DEBUG ERROS ----------------

--
-- client.lua — Guard + Helpers (Syn Network)
-- Detecta "Argument at index 1 was null" com arquivo:linha + traceback.
--

--  Config / Toggle 
local DEBUG_GUARD_ENABLED = GetConvarInt("syn_debug_guard", 1) == 1

RegisterCommand("guardon", function()
    DEBUG_GUARD_ENABLED = true
    print("[GUARD] Ativado por comando.")
end, false)

RegisterCommand("guardoff", function()
    DEBUG_GUARD_ENABLED = false
    print("[GUARD] Desativado por comando.")
end, false)

--  Helpers gerais 
local function _exists(ent)
    return ent and ent ~= 0 and DoesEntityExist(ent)
end

local function _shorttrace(levels)
    levels = levels or 6
    local tb = debug.traceback("", 3)
    return (tb:gsub("\t", "")):gsub("\n", " | "):sub(1, 600)
end

local function _where(depth)
    local info = debug.getinfo(depth or 3, "Sl")
    if not info then return "unknown:0" end
    local src = tostring(info.short_src or info.source or "unknown")
    local line = tostring(info.currentline or 0)
    return ("%s:%s"):format(src, line)
end

local function _fail(nativeName, idx, val, expect, depth)
    local where = _where((depth or 3) + 1)
    print(("[GUARD] %s -> arg #%d inválido (esperado %s) | got=%s | at %s")
        :format(nativeName, idx, expect, tostring(val), where))
    print("[GUARD] Trace:", _shorttrace())
end

local function _checkEnt(nativeName, idx, ent, depth)
    if not ent or ent == 0 then
        _fail(nativeName, idx, ent, "entity handle (~= nil/0)", depth)
        return false
    end
    if not DoesEntityExist(ent) then
        _fail(nativeName, idx, ent, "existing entity (DoesEntityExist)", depth)
        return false
    end
    return true
end

--  Wrapper de natives por nome 
local function wrap(nativeName, spec)
    local original = _G[nativeName]
    if type(original) ~= "function" then
        -- Só avisa uma vez
        if DEBUG_GUARD_ENABLED then
            print(("[GUARD] Aviso: native %s não existe no ambiente atual."):format(nativeName))
        end
        return
    end

    _G[nativeName] = function(...)
        if not DEBUG_GUARD_ENABLED then
            return original(...)
        end

        local depth = 3
        local args = {...}

        if spec and spec.pre then
            local ok, why = spec.pre(table.unpack(args))
            if ok == false then
                _fail(nativeName, -1, why or "precheck", "valid precondition", depth)
                return
            end
        end

        if spec and spec.entArgs then
            for _, idx in ipairs(spec.entArgs) do
                if not _checkEnt(nativeName, idx, args[idx], depth) then
                    return -- bloqueia a chamada problemática e loga
                end
            end
        end

        return original(table.unpack(args))
    end
end

--  Ativa guard para uma lista de natives comuns 
local function activateNamedGuards()
    local list = {
        {"TaskEnterVehicle",                { entArgs = {1,2} }}, -- ped, vehicle
        {"TaskLeaveVehicle",                { entArgs = {1,2} }},
        {"SetPedIntoVehicle",               { entArgs = {1,2} }},
        {"AttachEntityToEntity",            { entArgs = {1,2} }},
        {"DetachEntity",                    { entArgs = {1}   }},
        {"SetEntityCoords",                 { entArgs = {1}   }},
        {"SetEntityCoordsNoOffset",         { entArgs = {1}   }},
        {"SetEntityHeading",                { entArgs = {1}   }},
        {"FreezeEntityPosition",            { entArgs = {1}   }},
        {"SetEntityCollision",              { entArgs = {1}   }},
        {"TaskGoToCoordAnyMeans",           { entArgs = {1}   }},
        {"TaskGoStraightToCoord",           { entArgs = {1}   }},
        {"TaskPlayAnim",                    { entArgs = {1}   }},
        {"ClearPedTasksImmediately",        { entArgs = {1}   }},
        {"ClearPedTasks",                   { entArgs = {1}   }},
        {"SetPedCanRagdoll",                { entArgs = {1}   }},
        {"SetBlockingOfNonTemporaryEvents", { entArgs = {1}   }},
        {"NetworkRequestControlOfEntity",   { entArgs = {1}   }},
        {"DeleteEntity",                    { entArgs = {1}   }},
        {"DeleteVehicle",                   { entArgs = {1}   }},
        {"DeleteObject",                    { entArgs = {1}   }},
        {"SetVehicleDoorOpen",              { entArgs = {1}   }},
        {"SetVehicleDoorsLocked",           { entArgs = {1}   }},
        {"SetVehicleUndriveable",           { entArgs = {1}   }},
        {"SetVehicleEngineOn",              { entArgs = {1}   }},
    }
    for _, item in ipairs(list) do
        wrap(item[1], item[2])
    end
end

--  Guard para Citizen.InvokeNative (quando scripts usam hash direto) 
do
    local _Invoke = Citizen.InvokeNative
    Citizen.InvokeNative = function(hash, ...)
        if DEBUG_GUARD_ENABLED then
            local a1 = ...
            if a1 == nil or a1 == 0 then
                local info = debug.getinfo(2, "Sl")
                local where = (info and (tostring(info.short_src or info.source) .. ":" .. tostring(info.currentline))) or "unknown:0"
                print(("[GUARD:Invoke] hash=0x%X arg#1=nil/0 at %s"):format(tonumber(hash) or 0, where))
                print("[GUARD:Invoke] Trace:", (debug.traceback("", 2):gsub("\n", " | "):sub(1, 600)))
                return -- bloqueia a call problemática
            end
        end
        return _Invoke(hash, ...)
    end
end

activateNamedGuards()
print("[GUARD] Native guard ativo. Chamadas inválidas serão logadas com arquivo:linha.")

-- 
-- Helpers seguros (usa nos teus scripts para evitar null args)
-- 

-- Carrega um modelo com timeout
function LoadModel(hashOrName, timeout)
    local hash = type(hashOrName) == "number" and hashOrName or joaat(hashOrName)
    if not IsModelInCdimage(hash) then
        print(("[DBG] Modelo inválido: %s"):format(tostring(hashOrName)))
        return false
    end
    RequestModel(hash)
    local t = GetGameTimer() + (timeout or 7000)
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(10) end
    if not HasModelLoaded(hash) then
        print(("[DBG] Falha a carregar modelo: %s"):format(tostring(hashOrName)))
        return false
    end
    return hash
end

-- Toma controlo de uma entidade de rede (client)
function TakeControl(ent, tries)
    tries = tries or 40
    if not _exists(ent) then return false end
    while tries > 0 and not NetworkHasControlOfEntity(ent) do
        NetworkRequestControlOfEntity(ent)
        tries = tries - 1
        Wait(10)
    end
    return NetworkHasControlOfEntity(ent)
end

-- Garante que o ped está fora de veículo
function EnsureOnFoot(ped)
    if not ped then ped = PlayerPedId() end
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        TaskLeaveVehicle(ped, veh, 4160)
        local t = GetGameTimer() + 2500
        while IsPedInAnyVehicle(ped, false) and GetGameTimer() < t do
            Wait(50)
        end
        if IsPedInAnyVehicle(ped, false) then
            ClearPedTasksImmediately(ped)
            local x,y,z = table.unpack(GetEntityCoords(veh))
            SetEntityCoordsNoOffset(ped, x + 1.5, y, z + 0.25, false, false, false)
            Wait(50)
        end
    end
end

-- Spawn seguro de ped
function SafeCreatePed(model, coords, heading)
    local hash = LoadModel(model)
    if not hash then return nil end
    local x,y,z = coords.x, coords.y, coords.z
    local ped = CreatePed(4, hash, x, y, z, heading or 0.0, true, true)
    local t = GetGameTimer() + 2000
    while not _exists(ped) and GetGameTimer() < t do Wait(10) end
    if not _exists(ped) then
        print("[DBG] SafeCreatePed falhou: entidade não existe.")
        return nil
    end
    SetModelAsNoLongerNeeded(hash)
    return ped
end

-- Spawn seguro de veículo
function SafeCreateVehicle(model, coords, heading)
    local hash = LoadModel(model)
    if not hash then return nil end
    local x,y,z = coords.x, coords.y, coords.z
    local veh = CreateVehicle(hash, x, y, z, heading or 0.0, true, true)
    local t = GetGameTimer() + 2500
    while not _exists(veh) and GetGameTimer() < t do Wait(10) end
    if not _exists(veh) then
        print("[DBG] SafeCreateVehicle falhou: entidade não existe.")
        return nil
    end
    SetVehicleOnGroundProperly(veh)
    SetModelAsNoLongerNeeded(hash)
    return veh
end

-- Entrar no veículo com validação
function SafeTaskEnterVehicle(ped, veh, seat, speed, flags)
    if not _exists(ped) or not _exists(veh) then
        print("[DBG] SafeTaskEnterVehicle: ped/veh inválidos.")
        return false
    end
    TaskEnterVehicle(ped, veh, -1, seat or -1, speed or 1.0, flags or 1, 0)
    return true
end

----------------------------------------------------------
	---- SELFBOMB
----------------------------------------------------------
local RAGDOLL_TIME = 4000
local BASE_FORCE   = 10.0
local UP_FORCE     = 2.0

local function FxExplosionAt(x,y,z)
    ShakeGameplayCam("EXPLOSION_SHAKE",1.0)
    AddExplosion(x,y,z,0,0.0,true,false,1.0) -- só FX
end

-- suicida: só efeitos visuais
RegisterNetEvent("selfbomb:suicide")
AddEventHandler("selfbomb:suicide",function(center)
    FxExplosionAt(center.x,center.y,center.z)
    -- não mata nem ragdoll
end)

-- blast para todos os outros: ragdoll + impulso + kill manual
RegisterNetEvent("selfbomb:blast")
AddEventHandler("selfbomb:blast",function(center,radius,adminSrc)
    local myId = GetPlayerServerId(PlayerId())
    if myId == adminSrc then return end -- suicida ignora

    FxExplosionAt(center.x,center.y,center.z)

    local ped = PlayerPedId()
    local myCoords = GetEntityCoords(ped)
    local dist = #(myCoords - vector3(center.x,center.y,center.z))
    if dist > radius then return end

    -- normaliza direção
    local dir = vector3(myCoords.x-center.x,myCoords.y-center.y,0.0)
    local len = math.max(0.001,#dir)
    local nx,ny = dir.x/len,dir.y/len

    local proximity = math.max(0.1,(radius-dist)/radius) -- 0.1..1.0
    local force = BASE_FORCE*(1.0+proximity*1.5)

    -- ragdoll + impulso
    ClearPedTasksImmediately(ped)
    SetPedToRagdoll(ped,RAGDOLL_TIME,RAGDOLL_TIME,0,false,false,false)
    SetEntityVelocity(ped,nx*force,ny*force,UP_FORCE+proximity*UP_FORCE)

    -- kill manualmente (AddExplosion tem damage=0)
    SetEntityInvincible(ped,false)
    SetEntityHealth(ped,0)
end)


----------------------------------------------------------
---- TROLL COMMANDS (CLIENT)
----------------------------------------------------------

local INVERT_DURATION_DEFAULT = 12

-- Ajustes rápidos Airstrike
local AIRSTRIKE_BOMBS  = 10       -- quantidade de explosões
local AIRSTRIKE_SPREAD = 10.0     -- dispersão lateral
local AIRSTRIKE_WAIT   = 90       -- ms entre explosões
local RAGDOLL_PUSH     = 60.0     -- força do empurrão no alvo

-- util: OVNI beam (spotlight) durante X ms
local function DrawUfoBeamAt(coord, durationMs)
  local tEnd = GetGameTimer() + (durationMs or 1200)
  CreateThread(function()
    while GetGameTimer() < tEnd do
      local top = vector3(coord.x, coord.y, coord.z + 50.0)
      DrawSpotLight(top, 0.0, 0.0, -1.0, 255, 255, 255, 150.0, 20.0, 0.5, 25.0, 1.0)
      DrawLightWithRange(top.x, top.y, top.z, 255, 255, 255, 40.0, 3.0)
      Wait(0)
    end
  end)
end

-- ABDUCT -------------------------------------------------
RegisterNetEvent("troll:abductCommand")
AddEventHandler("troll:abductCommand", function(withBeam)
  local ped = PlayerPedId()
  if not DoesEntityExist(ped) then return end

  local start = GetEntityCoords(ped)
  local height = 18.0
  local steps = 90
  local delay = 10 -- 90*10 = ~900ms

  if withBeam then
    DrawUfoBeamAt(start, (steps*delay) + 1600)
  end

  SetEntityInvincible(ped, true)
  FreezeEntityPosition(ped, false)

  for i = 1, steps do
    if not DoesEntityExist(ped) then break end
    local frac = i / steps
    local z = start.z + (frac * height)
    SetEntityCoordsNoOffset(ped, start.x, start.y, z, false, false, false)
    Wait(delay)
  end

  Wait(1200)

  local groundZ = start.z
  local found, ground = GetGroundZFor_3dCoord(start.x, start.y, start.z + height + 2.0, 0)
  if found then groundZ = ground end
  local stepsDown = 40
  for i = stepsDown, 1, -1 do
    if not DoesEntityExist(ped) then break end
    local frac = i / stepsDown
    local z = groundZ + (frac * 1.0)
    SetEntityCoordsNoOffset(ped, start.x, start.y, z, false, false, false)
    Wait(10)
  end

  SetEntityInvincible(ped, false)
end)

-- FLIPCAR ------------------------------------------------
RegisterNetEvent("troll:flipcarCommand")
AddEventHandler("troll:flipcarCommand", function()
  local ped = PlayerPedId()
  if DoesEntityExist(ped) and IsPedInAnyVehicle(ped, false) then
    local veh = GetVehiclePedIsIn(ped, false)
    if DoesEntityExist(veh) then
      local rx, ry, rz = table.unpack(GetEntityRotation(veh, 2))
      SetEntityRotation(veh, rx + 180.0, ry, rz, 2, true)
      SetVehicleOnGroundProperly(veh)
    end
  else
    local pos = GetEntityCoords(ped)
    local veh, dist
    for _,v in pairs(GetGamePool("CVehicle")) do
      local c = GetEntityCoords(v)
      local d = #(c - pos)
      if not dist or d < dist then veh = v; dist = d end
    end
    if veh and dist and dist <= 6.0 then
      local rx, ry, rz = table.unpack(GetEntityRotation(veh, 2))
      SetEntityRotation(veh, rx + 180.0, ry, rz, 2, true)
      SetVehicleOnGroundProperly(veh)
    end
  end
end)

-- SPIN ---------------------------------------------------
RegisterNetEvent("troll:spinCommand")
AddEventHandler("troll:spinCommand", function(seconds)
  local ped = PlayerPedId()
  if not DoesEntityExist(ped) then return end
  local t = math.max(1, tonumber(seconds) or 6)
  local interval = 20
  local spinspeed = 12.0
  local loops = math.floor((t * 1000) / interval)

  CreateThread(function()
    for _=1,loops do
      if not DoesEntityExist(ped) then break end
      local h = GetEntityHeading(ped)
      SetEntityHeading(ped, (h + spinspeed) % 360)
      Wait(interval)
    end
  end)
end)

-- LAUNCH -------------------------------------------------
RegisterNetEvent("troll:launchCommand")
AddEventHandler("troll:launchCommand", function()
  local ped = PlayerPedId()
  if not DoesEntityExist(ped) then return end
  if IsPedInAnyVehicle(ped, false) then
    local veh = GetVehiclePedIsIn(ped, false)
    SetEntityVelocity(veh, 0.0, 0.0, 30.0)
  else
    SetEntityVelocity(ped, 0.0, 0.0, 30.0)
  end
end)

-- INVERT -------------------------------------------------
local inverted = false
RegisterNetEvent("troll:invertCommand")
AddEventHandler("troll:invertCommand", function(duration)
  if inverted then return end
  inverted = true
  local ped = PlayerPedId()
  local endTime = GetGameTimer() + ((tonumber(duration) or INVERT_DURATION_DEFAULT) * 1000)

  CreateThread(function()
    while GetGameTimer() < endTime do
      DisableControlAction(0, 30, true)
      DisableControlAction(0, 31, true)
      DisableControlAction(0, 32, true)
      DisableControlAction(0, 33, true)
      DisableControlAction(0, 34, true)
      DisableControlAction(0, 35, true)

      if IsDisabledControlJustPressed(0, 32) then
        local f = GetEntityForwardVector(ped)
        SetEntityVelocity(ped, -f.x * 4.0, -f.y * 4.0, 0.25)
      end
      if IsDisabledControlJustPressed(0, 33) then
        local f = GetEntityForwardVector(ped)
        SetEntityVelocity(ped, f.x * 3.5, f.y * 3.5, 0.10)
      end
      if IsDisabledControlJustPressed(0, 30) then
        SetEntityVelocity(ped, 2.2, 0.0, 0.0)
      end
      if IsDisabledControlJustPressed(0, 31) then
        SetEntityVelocity(ped, -2.2, 0.0, 0.0)
      end
      Wait(0)
    end
    inverted = false
  end)
end)


----------------------------------------------------------
-- TROLL COMMANDS — Syn Network (CLIENT)
----------------------------------------------------------

local SCENE_TIMEOUT_MS = 8000

local function ensureAnimDict(dict)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 8000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(25)
    end
    return HasAnimDictLoaded(dict)
end

local function ensureModel(model)
    RequestModel(model)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(25)
    end
    return HasModelLoaded(model)
end

----------------------------------------------------------
-- TASER REAL (stungun): ped invisível dispara no alvo
----------------------------------------------------------
RegisterNetEvent("troll:client:TaseEffect", function()
    local target = PlayerPedId()
    local tCoords = GetEntityCoords(target)

    -- cria um “agressor” invisível com stungun
    local copModel = joaat("s_m_y_cop_01")
    if not ensureModel(copModel) then return end

    local behind = GetEntityForwardVector(target)
    local spawn = vec3(tCoords.x - behind.x * 2.0, tCoords.y - behind.y * 2.0, tCoords.z)

    local cop = CreatePed(4, copModel, spawn.x, spawn.y, spawn.z, GetEntityHeading(target), true, true)
    if not DoesEntityExist(cop) then return end

    SetEntityAsMissionEntity(cop, true, true)
    SetBlockingOfNonTemporaryEvents(cop, true)
    SetEntityInvincible(cop, true)
    SetEntityVisible(cop, false, false)
    SetPedFleeAttributes(cop, 0, false)
    SetPedCombatAttributes(cop, 46, true)
    GiveWeaponToPed(cop, joaat("WEAPON_STUNGUN"), 1, false, true)
    SetCurrentPedWeapon(cop, joaat("WEAPON_STUNGUN"), true)

    -- virar para o alvo e disparar 1.5s (aplica o stun legítimo do GTA)
    TaskTurnPedToFaceEntity(cop, target, 300)
    Wait(300)
    TaskShootAtEntity(cop, target, 1500, joaat("FIRING_PATTERN_FULL_AUTO"))
    -- garantir mínimo tempo de stun no chão
    SetPedMinGroundTimeForStungun(target, 4000)

    -- efeitos suaves
    StartScreenEffect("Dont_taze_me_bro", 2500, false)
    ShakeGameplayCam("SMALL_EXPLOSION_SHAKE", 0.4)

    Wait(1700)

    -- cleanup
    ClearPedTasksImmediately(cop)
    SetEntityAsNoLongerNeeded(cop)
    DeletePed(cop)
    StopScreenEffect("Dont_taze_me_bro")
end)


