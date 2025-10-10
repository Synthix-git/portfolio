-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRPC         = Tunnel.getInterface("vRP")
vRP          = Proxy.getInterface("vRP")

-----------------------------------------------------------------------------------------------------------------------------------------
-- STATE
-----------------------------------------------------------------------------------------------------------------------------------------
local Pet, PetNet, PetModel = nil, nil, nil
local Busy, IsFollow, IsStay = false, false, false
local CurrentEnemy = nil

-- arma definida no spawn/clone (mantida SEM recriar)
local _spawnWeaponHash = nil

-- cooldown do "Desbugar (TP)" em ms
local _unstuckCooldown = 30 * 1000
local _lastUnstuck = 0

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS
-----------------------------------------------------------------------------------------------------------------------------------------
local function notify(title, msg, color, time)
    TriggerEvent("Notify", title or "Animais", msg or "", color or "verde", time or 5000)
end

local function nowMs() return GetGameTimer() end

local function loadModel(model)
    if type(model) == "string" then model = GetHashKey(model) end
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) do
        Wait(10)
        if GetGameTimer() > timeout then return false end
    end
    return model
end

local function releaseModel(model)
    if type(model) == "string" then model = GetHashKey(model) end
    SetModelAsNoLongerNeeded(model)
end

local function requestControl(entity)
    if not DoesEntityExist(entity) then return false end
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId == 0 then return false end
    NetworkRequestControlOfNetworkId(netId)
    local timeout = GetGameTimer() + 1500
    while not NetworkHasControlOfNetworkId(netId) and GetGameTimer() < timeout do
        Wait(0)
        NetworkRequestControlOfNetworkId(netId)
    end
    return NetworkHasControlOfNetworkId(netId)
end

local function clearPet()
    IsFollow, IsStay = false, false
    CurrentEnemy = nil
    if DoesEntityExist(Pet) then
        if requestControl(Pet) then
            SetEntityAsMissionEntity(Pet,true,true)
            DeleteEntity(Pet)
        end
    end
    Pet, PetNet, PetModel = nil, nil, nil
    _spawnWeaponHash = nil
end

local function closestFreeSeat(veh)
    local max = GetVehicleMaxNumberOfPassengers(veh) or 0
    for s = 0, max do
        if IsVehicleSeatFree(veh, s) then return s end
    end
    return nil
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- COMBAT / WEAPON SETUP
-----------------------------------------------------------------------------------------------------------------------------------------
local function setupPetCombat(ped)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCanRagdoll(ped, false)

    SetPedCombatAbility(ped, 2)
    SetPedCombatMovement(ped, 2)
    SetPedCombatRange(ped, 2)
    SetPedAlertness(ped, 3)

    SetPedCombatAttributes(ped, 5, true)   -- fight armed
    SetPedCombatAttributes(ped, 17, true)  -- always fight
    SetPedCombatAttributes(ped, 46, true)  -- aggressive

    SetPedHearingRange(ped, 30.0)
    SetPedSeeingRange(ped, 60.0)

    SetPedCanPlayAmbientAnims(ped, false)
    SetPedCanPlayGestureAnims(ped, false)
    if type(SetPedToRagdollBlockingFlags) == "function" then SetPedToRagdollBlockingFlags(ped, 2) end
end

-- Wrapper UpdatePedVariation (compat)
local function PedUpdateVariation(ped)
    if type(UpdatePedVariation) == "function" then
        UpdatePedVariation(ped, true, true)
    else
        local d = GetPedDrawableVariation(ped, 2)
        local t = GetPedTextureVariation(ped, 2)
        local p = GetPedPaletteVariation(ped, 2)
        SetPedComponentVariation(ped, 2, d, t, p)
        if FinalizeHeadBlend then FinalizeHeadBlend(ped) end
    end
end

-- NÃO dá arma nova; só impede trocar. Se ficar unarmed, re-seleciona a do spawn.
local function ensureHasGun(ped)
    if not ped or not DoesEntityExist(ped) or not IsPedHuman(ped) then return false end
    SetPedCanSwitchWeapon(ped, false)

    local UNARMED = GetHashKey("WEAPON_UNARMED")
    local sel = GetSelectedPedWeapon(ped)

    if _spawnWeaponHash and _spawnWeaponHash ~= 0 and _spawnWeaponHash ~= UNARMED then
        if sel == 0 or sel == UNARMED then
            SetCurrentPedWeapon(ped, _spawnWeaponHash, true)
        end
    else
        if sel ~= 0 and sel ~= UNARMED then
            SetCurrentPedWeapon(ped, UNARMED, true)
        end
    end
    return true
end

local function equipPetWeapon(ped, weaponHash)
    RemoveAllPedWeapons(ped, true)

    if not IsPedHuman(ped) then
        GiveWeaponToPed(ped, GetHashKey("WEAPON_ANIMAL"), 200, true, true)
        _spawnWeaponHash = GetHashKey("WEAPON_ANIMAL")
        return
    end

    local give = weaponHash
    if not give or give == 0 then
        give = GetHashKey("WEAPON_UNARMED")
    end

    GiveWeaponToPed(ped, give, 250, true, true)
    SetCurrentPedWeapon(ped, give, true)
    SetPedInfiniteAmmo(ped, true, give)
    SetPedCanSwitchWeapon(ped, false)

    _spawnWeaponHash = (give ~= GetHashKey("WEAPON_UNARMED")) and give or nil
end

local function ensureShootSetup(ped)
    SetPedShootRate(ped, 2000)
    SetPedAccuracy(ped, 99)
    SetPedFiringPattern(ped, 0xC6EE6B4C)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- FRIENDLY-FIRE / RELAÇÕES
-----------------------------------------------------------------------------------------------------------------------------------------
local _petRelGroup = nil
local function setupNoFriendlyFire(ped, owner)
    if not _petRelGroup then
        local name = ("PET_REL_%d"):format(PlayerId())
        local grpHash = AddRelationshipGroup(name)
        _petRelGroup = grpHash

        local PLAYER = GetHashKey("PLAYER")
        SetRelationshipBetweenGroups(3, _petRelGroup, PLAYER)
        SetRelationshipBetweenGroups(3, PLAYER, _petRelGroup)
    end

    SetPedRelationshipGroupHash(ped, _petRelGroup)
    SetCanAttackFriendly(ped, false, false)

    local pg = GetPlayerGroup(PlayerId())
    if pg ~= 0 then
        SetPedAsGroupMember(ped, pg)
        SetPedNeverLeavesGroup(ped, true)
        SetGroupSeparationRange(pg, 999.0)
    end

    SetEntityIsTargetPriority(owner, false, 0.0)
    SetPedConfigFlag(ped, 26, true) -- DisablePotentialToBeTargeted
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- ADOPT AS PET (GLOBAL)
-----------------------------------------------------------------------------------------------------------------------------------------
function adoptAsPet(ped, invincible, weaponHash)
    if not DoesEntityExist(ped) then return false end
    if Pet and DoesEntityExist(Pet) then clearPet() end

    Pet = ped
    PetModel = GetEntityModel(ped)

    SetEntityAsMissionEntity(Pet, true, true)
    SetPedCanRagdoll(Pet, false)
    SetBlockingOfNonTemporaryEvents(Pet, true)
    SetPedFleeAttributes(Pet, 0, false)
    SetPedCombatAttributes(Pet, 46, true)
    SetPedCanPlayAmbientAnims(Pet, false)

    equipPetWeapon(Pet, weaponHash)
    setupPetCombat(Pet)
    setupNoFriendlyFire(Pet, PlayerPedId())

    invincible = (invincible ~= false)
    SetEntityInvincible(Pet, invincible)
    SetPedSuffersCriticalHits(Pet, not invincible)
    SetPedCanBeTargetted(Pet, not invincible)

    SetPedPathPreferToAvoidWater(Pet, true)
    SetPedPathAvoidFire(Pet, true)
    SetPedPathCanUseClimbovers(Pet, false)
    SetPedPathCanUseLadders(Pet, false)
    SetPedPathCanDropFromHeight(Pet, false)

    PetNet = NetworkGetNetworkIdFromEntity(Pet)
    if PetNet and PetNet ~= 0 then
        SetNetworkIdExistsOnAllMachines(PetNet, true)
        SetNetworkIdCanMigrate(PetNet, true)
        NetworkSetNetworkIdDynamic(PetNet, false)
        TriggerServerEvent("animals:Animals", PetNet)
    end

    SetPedDropsWeaponsWhenDead(Pet, false)

    IsStay, IsFollow, CurrentEnemy = false, true, nil

    -- inicia follow suave
    TriggerEvent("animals:__follow_loop_smooth")

    -- garante estado coerente (só seleciona o que já tem)
    ensureHasGun(Pet)

    return true
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- APPLY APPEARANCE VIA NET (SYNC GLOBAL)
-----------------------------------------------------------------------------------------------------------------------------------------
local function applyAppearanceTo(ped, data)
    if not data or not ped or not DoesEntityExist(ped) then return end

    if data.headBlend then
        local hb = data.headBlend
        SetPedHeadBlendData(ped, hb[1] or 0, hb[2] or 0, hb[3] or 0, hb[4] or 0, hb[5] or 0, hb[6] or 0, (hb[7] or 0.0)+0.0, (hb[8] or 0.0)+0.0, (hb[9] or 0.0)+0.0, true)
    end

    if data.faceFeatures then
        for i = 0,19 do local v = data.faceFeatures[i]; if v ~= nil then SetPedFaceFeature(ped, i, v + 0.0) end end
    end

    if data.components then
        for comp = 0,11 do
            local c = data.components[comp]
            if c then SetPedComponentVariation(ped, comp, c.drawable or 0, c.texture or 0, c.palette or 0) end
        end
    end

    if data.hairColor ~= nil and data.hairHighlight ~= nil then
        for i = 1,3 do SetPedHairColor(ped, data.hairColor or 0, data.hairHighlight or 0) Wait(0) end
    end

    if data.overlays then
        for id, o in pairs(data.overlays) do
            local val = math.max(0, o.value or 0)
            local opa = (o.opacity or 1.0) + 0.0
            SetPedHeadOverlay(ped, id, val, opa)
            SetPedHeadOverlayColor(ped, id, o.colorType or 1, o.color1 or (data.hairColor or 0), o.color2 or (data.hairHighlight or 0))
        end
    end

    if data.props then
        for prop = 0,7 do
            local p = data.props[prop]
            if p then
                if p.index and p.index ~= -1 then SetPedPropIndex(ped, prop, p.index, p.texture or 0, true)
                else ClearPedProp(ped, prop) end
            end
        end
    end

    PedUpdateVariation(ped)
    if data.hairColor ~= nil and data.hairHighlight ~= nil then SetPedHairColor(ped, data.hairColor or 0, data.hairHighlight or 0) end
end

-- pedido de snapshot local → server
RegisterNetEvent("animals:CollectAppearance")
AddEventHandler("animals:CollectAppearance", function(requesterSrc)
    local ped = PlayerPedId()
    local data = {
        model         = GetEntityModel(ped),
        components    = {},
        props         = {},
        hairColor     = 0,
        hairHighlight = 0,
        overlays      = {},
        headBlend     = nil,
        faceFeatures  = {}
    }

    for comp = 0,11 do
        data.components[comp] = {
            drawable = GetPedDrawableVariation(ped, comp),
            texture  = GetPedTextureVariation(ped, comp),
            palette  = GetPedPaletteVariation(ped, comp)
        }
    end

    for prop = 0,7 do
        local idx = GetPedPropIndex(ped, prop)
        if idx ~= -1 then
            data.props[prop] = { index = idx, texture = GetPedPropTextureIndex(ped, prop) }
        else
            data.props[prop] = { index = -1 }
        end
    end

    local col, hi = GetPedHairColor(ped)
    data.hairColor     = col or 0
    data.hairHighlight = hi  or 0

    local overlayIds = {1,2,5,8,10}
    for _, id in ipairs(overlayIds) do
        local ok, val, opacity, colorType, c1, c2 = GetPedHeadOverlayData(ped, id)
        if ok then
            data.overlays[id] = { value = val or 0, opacity = opacity or 1.0, colorType = colorType or 1, color1 = c1 or data.hairColor, color2 = c2 or data.hairHighlight }
        else
            data.overlays[id] = { value = GetPedHeadOverlayValue(ped, id) or 0, opacity = 1.0, colorType = 1, color1 = data.hairColor, color2 = data.hairHighlight }
        end
    end

    do
        local ok, s1,s2,s3, sk1,sk2,sk3, mixS, mixK, mix3 = GetPedHeadBlendData(ped)
        if ok then data.headBlend = { s1,s2,s3, sk1,sk2,sk3, mixS, mixK, mix3 } end
    end

    for i = 0,19 do
        data.faceFeatures[i] = GetPedFaceFeature(ped, i) or 0.0
    end

    TriggerServerEvent("animals:ReturnAppearance", requesterSrc, data)
end)

-- staff → cria clone por aparência (server envia com weaponHash)
RegisterNetEvent("animals:CloneByAppearance")
AddEventHandler("animals:CloneByAppearance", function(data)
    if not data or not data.model then
        notify("Admin","Aparência inválida recebida.","amarelo",5000)
        return
    end

    RequestModel(data.model)
    local t = GetGameTimer() + 10000
    while not HasModelLoaded(data.model) and GetGameTimer() < t do Wait(10) end
    if not HasModelLoaded(data.model) then
        notify("Admin","Falha ao carregar o modelo do alvo.","vermelho",6000)
        return
    end

    local me = PlayerPedId()
    local pos = GetOffsetFromEntityInWorldCoords(me, 0.0, 1.6, 0.0)
    local ped = CreatePed(4, data.model, pos.x, pos.y, pos.z, GetEntityHeading(me), true, true)
    SetModelAsNoLongerNeeded(data.model)
    if not ped or not DoesEntityExist(ped) then
        notify("Admin","Falha ao criar o clone.","vermelho",6000)
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(ped)
    if netId and netId ~= 0 then
        SetNetworkIdExistsOnAllMachines(netId, true)
        SetNetworkIdCanMigrate(netId, true)
        NetworkSetNetworkIdDynamic(netId, false)
    end

    applyAppearanceTo(ped, data)

    local weaponHash = data.weaponHash
    if adoptAsPet(ped, true, weaponHash) then
        local snapNet = NetworkGetNetworkIdFromEntity(ped)
        TriggerServerEvent("animals:BroadcastAppearance", snapNet, data)
        notify("Admin","Clone adotado como <b>pet</b>.","verde",5000)
    else
        SetEntityAsMissionEntity(ped,true,true)
        DeleteEntity(ped)
        notify("Admin","Falha ao adotar o clone como pet.","vermelho",6000)
    end
end)

-- aplicar aparência a qualquer entidade via NetID (sync global)
RegisterNetEvent("animals:ApplyAppearanceNet")
AddEventHandler("animals:ApplyAppearanceNet", function(netId, data)
    if not netId or not data then return end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent ~= 0 and DoesEntityExist(ent) then
        applyAppearanceTo(ent, data)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- COMBAT CORE (death check simplificado)
-----------------------------------------------------------------------------------------------------------------------------------------
local OPTIMAL_MIN   = 12.0
local OPTIMAL_MAX   = 22.0
local TOO_CLOSE     = 10.0  -- evita coronhada
local RETREAT_STEP  = 9.0
local CHASE_SPEED   = 3.2

local combat = {
    target = nil,
    zone = "none",
    lastCmd = 0,
    cmdCooldown = 120
}

-- *** ÚNICO CHECK DE MORTE/FERIDO ***
local function isDeadSimple(p)
    if not p or p == 0 or not DoesEntityExist(p) then return true end
    if IsEntityDead(p) then return true end
    if IsPedDeadOrDying(p, true) then return true end
    return false
end

local function currentWeapon(ped)
    local w = GetSelectedPedWeapon(ped)
    if w == 0 then return GetHashKey("WEAPON_UNARMED") end
    return w
end

local function isArmedHuman(ped)
    return IsPedHuman(ped) and currentWeapon(ped) ~= GetHashKey("WEAPON_UNARMED")
end

local function stopCombat()
    combat.target = nil
    CurrentEnemy = nil

    if Pet and DoesEntityExist(Pet) then
        requestControl(Pet)
        SetPedKeepTask(Pet, false)
        ClearPedSecondaryTask(Pet)
        ClearPedTasksImmediately(Pet)
        TaskStandStill(Pet, 150)
        TaskAimGunAtEntity(Pet, 0, 0, false)
    end

    if Pet and DoesEntityExist(Pet) and IsPedHuman(Pet) then
        if _spawnWeaponHash then
            SetCurrentPedWeapon(Pet, _spawnWeaponHash, true)
            SetPedCanSwitchWeapon(Pet, false)
        else
            SetCurrentPedWeapon(Pet, GetHashKey("WEAPON_UNARMED"), true)
        end
    end

    if not IsStay then
        IsFollow = true
        TriggerEvent("animals:__follow_loop_smooth")
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- SHOOT HELPERS (mantidos)
-----------------------------------------------------------------------------------------------------------------------------------------
local SKEL_Spine3 = 24818
local SKEL_Spine0 = 23553

local function lineClear(ped, from, to, ignoreEnt)
    local handle = StartShapeTestRay(from.x, from.y, from.z, to.x, to.y, to.z, 8, ignoreEnt or 0, 7)
    local _, hit, _, _, entHit = GetShapeTestResult(handle)
    return hit == 0 or entHit == 0
end

local function hasLOS(fromPed, toPed)
    if not (DoesEntityExist(fromPed) and DoesEntityExist(toPed)) then return false end
    if HasEntityClearLosToEntity(fromPed, toPed, 17) then return true end
    local f = GetEntityCoords(fromPed) + vector3(0,0,0.6)
    local head  = GetPedBoneCoords(toPed, 31086, 0.0, 0.0, 0.0)
    local chest = GetPedBoneCoords(toPed, 24818, 0.0, 0.0, 0.0)
    local h1 = StartShapeTestRay(f.x, f.y, f.z, head.x, head.y, head.z + 0.02, 8, fromPed, 7)
    local _, hitH = GetShapeTestResult(h1)
    if hitH == 0 then return true end
    local h2 = StartShapeTestRay(f.x, f.y, f.z, chest.x, chest.y, chest.z, 8, fromPed, 7)
    local _, hitC = GetShapeTestResult(h2)
    return hitC == 0
end

local function aimAndShootCenterMass(ped, tgt, burstMs)
    burstMs = burstMs or 700
    if not ped or not DoesEntityExist(ped) or isDeadSimple(tgt) then return end

    local from   = GetEntityCoords(ped) + vector3(0,0,0.6)
    local chest  = GetPedBoneCoords(tgt, SKEL_Spine3, 0.0, 0.0, 0.0)
    local belly  = GetPedBoneCoords(tgt, SKEL_Spine0, 0.0, 0.0, 0.0)
    local pelvis = GetEntityCoords(tgt)

    if isDeadSimple(tgt) then return end

    if lineClear(ped, from, chest + vector3(0,0,0.02), ped) then
        SetPedKeepTask(ped, false)
        TaskShootAtCoord(ped, chest.x, chest.y, chest.z + 0.02, burstMs, 0xC6EE6B4C)
        SetPedKeepTask(ped, true)
        return
    end

    if lineClear(ped, from, belly, ped) then
        SetPedKeepTask(ped, false)
        TaskShootAtCoord(ped, belly.x, belly.y, belly.z, burstMs, 0xC6EE6B4C)
        SetPedKeepTask(ped, true)
        return
    end

    SetPedKeepTask(ped, false)
    TaskShootAtCoord(ped, pelvis.x, pelvis.y, pelvis.z + 0.1, math.floor(burstMs*0.8), 0xC6EE6B4C)
    SetPedKeepTask(ped, true)
end

local function immediateFireBurst(ped, tgt)
    ensureHasGun(ped)
    ensureShootSetup(ped)
    if isDeadSimple(tgt) then return false end
    if not hasLOS(ped, tgt) then return false end

    TaskAimGunAtEntity(ped, tgt, 300, false)
    if isDeadSimple(tgt) then return false end
    aimAndShootCenterMass(ped, tgt, 700)
    return true
end

local function seekLineOfSight(ped, tgt)
    local pT = GetEntityCoords(tgt)
    local pP = GetEntityCoords(ped)
    local toT = pT - pP
    local baseHeading = math.deg(math.atan2(toT.y, toT.x))
    local angles = { -70.0, -40.0, 40.0, 70.0 }
    local radii  = { 4.0, 7.5 }
    for _,r in ipairs(radii) do
        for _,ang in ipairs(angles) do
            local a = math.rad(baseHeading + ang)
            local cand = vector3(pT.x - math.cos(a)*r, pT.y - math.sin(a)*r, pT.z)
            local h = StartShapeTestRay(cand.x, cand.y, cand.z + 0.6, pT.x, pT.y, pT.z + 0.2, 8, ped, 7)
            local _, hit = GetShapeTestResult(h)
            if hit == 0 then
                TaskGoToCoordWhileAimingAtEntity(
                    ped, cand.x, cand.y, cand.z,
                    2.8, true, tgt, GetSelectedPedWeapon(ped),
                    false, 0.0, false, GetEntityCoords(tgt), true, true
                )
                SetPedKeepTask(ped, true)
                return true
            end
        end
    end
    return false
end

local function retreatPointFrom(ped, tgt, step)
    local p = GetEntityCoords(ped)
    local t = GetEntityCoords(tgt)
    local dir = t - p
    local mag = #(dir)
    if mag < 0.001 then return vector3(p.x - step, p.y, p.z) end
    dir = dir / mag
    return p - (dir * step)
end

local function armedTick(ped, tgt, dist)
    if isDeadSimple(tgt) then
        stopCombat()
        return
    end

    ensureHasGun(ped)
    ensureShootSetup(ped)
    local _now = nowMs()

    if dist < TOO_CLOSE then
        if _now - combat.lastCmd >= 60 then
            local rp = retreatPointFrom(ped, tgt, RETREAT_STEP)
            TaskGoToCoordWhileAimingAtEntity(
                ped, rp.x, rp.y, rp.z,
                2.8, true, tgt, currentWeapon(ped),
                false, 0.0, false, GetEntityCoords(tgt), true, true
            )
            aimAndShootCenterMass(ped, tgt, 650)
            SetPedKeepTask(ped, true)
            combat.lastCmd = _now
        end
        return
    end

    if hasLOS(ped, tgt) then
        if _now - combat.lastCmd >= 60 then
            TaskAimGunAtEntity(ped, tgt, 220, false)
            TaskShootAtEntity(ped, tgt, 750, 0xC6EE6B4C)
            aimAndShootCenterMass(ped, tgt, 850)
            SetPedKeepTask(ped, true)
            combat.lastCmd = _now
        end
        return
    end

    if _now - combat.lastCmd >= combat.cmdCooldown then
        if not seekLineOfSight(ped, tgt) then
            local rp = retreatPointFrom(ped, tgt, 3.0)
            TaskGoToCoordWhileAimingAtEntity(ped, rp.x, rp.y, rp.z, 2.6, true, tgt, currentWeapon(ped), false, 0.0, false, GetEntityCoords(tgt), true, true)
            SetPedKeepTask(ped, true)
        end
        combat.lastCmd = _now
    end
end

local function meleeTick(ped, tgt, dist)
    if isDeadSimple(tgt) then
        stopCombat()
        return
    end

    local _now = nowMs()

    if not HasEntityClearLosToEntity(ped, tgt, 17) then
        if _now - combat.lastCmd >= combat.cmdCooldown then
            TaskGoToEntity(ped, tgt, -1, 0.0, 3.0, 0, 0)
            SetPedKeepTask(ped, true)
            combat.lastCmd = _now
        end
        return
    end

    if dist <= 5.0 then
        if _now - combat.lastCmd >= combat.cmdCooldown then
            TaskPutPedDirectlyIntoMelee(ped, tgt, 0.0, -1.0, 0, 0)
            SetPedKeepTask(ped, true)
            combat.lastCmd = _now
        end
    else
        if _now - combat.lastCmd >= combat.cmdCooldown then
            TaskGoToEntity(ped, tgt, -1, 0.0, 3.2, 0, 0)
            SetPedKeepTask(ped, true)
            combat.lastCmd = _now
        end
    end
end

local function engageTarget(tgt)
    if not Pet or not DoesEntityExist(Pet) or not DoesEntityExist(tgt) then return end

    IsFollow = false
    setupPetCombat(Pet)
    setupNoFriendlyFire(Pet, PlayerPedId())
    combat.target = tgt
    combat.lastCmd = 0

    ensureHasGun(Pet)

    if isArmedHuman(Pet) then
        ensureShootSetup(Pet)
        if not immediateFireBurst(Pet, tgt) then
            TaskAimGunAtEntity(Pet, tgt, 300, false)
            TaskShootAtEntity(Pet, tgt, 600, 0xC6EE6B4C)
            TaskGoToEntityWhileAimingAtEntity(Pet, tgt, tgt, 3.0, true, true, currentWeapon(Pet), false, true, 0)
            SetPedKeepTask(Pet, true)
        end
    else
        TaskGoToEntity(Pet, tgt, -1, 0.0, CHASE_SPEED, 0, 0)
        SetPedKeepTask(Pet, true)
    end

    -- watchdog simples de morte
    CreateThread(function()
        while Pet and DoesEntityExist(Pet) and combat and combat.target do
            local t = combat.target
            if isDeadSimple(t) then
                stopCombat()
                break
            end
            Wait(80)
        end
    end)
end

-- loop de combate
CreateThread(function()
    while true do
        if Pet and DoesEntityExist(Pet) and combat.target then
            local tgt = combat.target
            if isDeadSimple(tgt) then
                stopCombat()
            else
                local dist = #(GetEntityCoords(tgt) - GetEntityCoords(Pet))
                if isArmedHuman(Pet) then
                    armedTick(Pet, tgt, dist)
                else
                    meleeTick(Pet, tgt, dist)
                end
            end
            Wait(100)
        else
            Wait(250)
        end
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- AUTO-ATAQUE: SÓ ataca QUEM TU ATACARES (sem retaliação)
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("gameEventTriggered", function(name, args)
    if name ~= "CEventNetworkEntityDamage" then return end
    if not Pet or not DoesEntityExist(Pet) then return end

    local me = PlayerPedId()

    local function pedFromEntity(ent)
        if not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
        if IsEntityAPed(ent) then return ent end
        if IsEntityAVehicle(ent) then
            local drv = GetPedInVehicleSeat(ent, -1)
            if drv ~= 0 then return drv end
            local pass = GetPedInVehicleSeat(ent, 0)
            if pass ~= 0 then return pass end
        end
        return nil
    end

    local victim, attacker = args[1], args[2]
    local attackerPed = pedFromEntity(attacker)
    local victimPed   = pedFromEntity(victim)

    -- bloquear dano do pet em ti
    if victim == me then
        local attPed = attackerPed
        if not attPed and IsEntityAVehicle(attacker) then
            attPed = GetPedInVehicleSeat(attacker, -1)
            if attPed == 0 then attPed = GetPedInVehicleSeat(attacker, 0) end
        end
        if attPed == Pet then CancelEvent(); return end
    end

    -- Se o PET matou alguém → parar já
    if attackerPed == Pet and victimPed and isDeadSimple(victimPed) then
        stopCombat()
        return
    end

    -- ÚNICA regra: se TU atacares alguém, o pet engaja
    if attacker == me and victimPed and victimPed ~= me and victimPed ~= Pet and not isDeadSimple(victimPed) then
        ensureHasGun(Pet)
        CurrentEnemy = victimPed
        engageTarget(victimPed)
        return
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- DYNAMIC (F9)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("animals:Dynamic")
AddEventHandler("animals:Dynamic", function()
    if not Pet then return end
    exports["dynamic"]:AddMenu("Domésticos","Tudo sobre animais domésticos.","animals")
    exports["dynamic"]:AddButton("Seguir","Seguir/parar de seguir o proprietário.","animals:Functions","follow","animals",false)
    exports["dynamic"]:AddButton("Ficar","Ficar parado no sítio.","animals:Functions","stay","animals",false)
    exports["dynamic"]:AddButton("Colocar no Veículo","Colocar o animal no veículo.","animals:Functions","putvehicle","animals",false)
    exports["dynamic"]:AddButton("Remover do Veículo","Remover o animal do veículo.","animals:Functions","removevehicle","animals",false)
    exports["dynamic"]:AddButton("Parar ataque","Faz o pet desistir do alvo atual.","animals:Functions","stopattack","animals",false)
    exports["dynamic"]:AddButton("Desbugar (TP)","Teleporta o pet para perto de mim (30s CD).","animals:Functions","unstuck","animals",false)
    exports["dynamic"]:AddButton("Guardar","Despawn do animal.","animals:Functions","destroy","animals",false)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- SPAWN (server pode mandar weaponHash)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("animals:Spawn")
AddEventHandler("animals:Spawn", function(modelName, weaponHash)
    if Busy then return end
    Busy = true

    if Pet then
        TriggerEvent("animals:Functions","destroy")
        Busy = false
        return
    end

    local me = PlayerPedId()
    local model = loadModel(modelName)
    if not model then
        notify("Animais","Modelo inválido.","amarelo",4000)
        Busy = false
        return
    end

    local forward = GetOffsetFromEntityInWorldCoords(me, 0.0, 1.2, 0.0)
    local ped = CreatePed(28, model, forward.x, forward.y, forward.z, GetEntityHeading(me), true, true)
    if not DoesEntityExist(ped) then
        notify("Animais","Falha ao criar o animal.","vermelho",4000)
        releaseModel(model); Busy=false; return
    end

    adoptAsPet(ped, true, weaponHash)
    releaseModel(model)
    Busy = false
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- SPAWN ANY PED (a_c_ => animal)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("animals:SpawnAnyPed")
AddEventHandler("animals:SpawnAnyPed", function(modelName, weaponHash)
    if Busy then return end
    Busy = true

    local me = PlayerPedId()
    local hash = modelName
    if type(hash) == "string" then hash = tonumber(hash) or GetHashKey(hash) end

    if not hash or hash == 0 then
        notify("Animais","Modelo inválido (hash nulo).","amarelo",5000)
        Busy = false; return
    end

    RequestModel(hash)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(hash) do
        Wait(10)
        if GetGameTimer() > timeout then
            notify("Animais","Falha ao carregar modelo (<b>timeout</b>).","amarelo",6000)
            Busy = false; return
        end
    end

    local pedType = (type(modelName)=="string" and modelName:lower():find("^a_c_")) and 28 or 4
    local pos = GetOffsetFromEntityInWorldCoords(me, 0.0, 1.5, 0.0)
    local ped = CreatePed(pedType, hash, pos.x, pos.y, pos.z, GetEntityHeading(me), true, true)
    SetModelAsNoLongerNeeded(hash)

    if not ped or not DoesEntityExist(ped) then
        notify("Animais","Falha ao criar ped (CreatePed).","vermelho",6000)
        Busy = false; return
    end

    if adoptAsPet(ped, true, weaponHash) then
        notify("Animais","Pet criado com sucesso.","verde",4000)
    else
        SetEntityAsMissionEntity(ped,true,true)
        DeleteEntity(ped)
        notify("Animais","Não foi possível adotar o ped como pet.","vermelho",6000)
    end

    Busy = false
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- FOLLOW SUAVE SEM ZIGUEZAGUES
-----------------------------------------------------------------------------------------------------------------------------------------
-- Offset atrás do dono e reemissão controlada
local FOLLOW_OFFSET_X = -2.6  -- atrás
local FOLLOW_OFFSET_Y =  0.0
local FOLLOW_OFFSET_Z =  0.0

local TELEPORT_DIST   = 35.0
local REISSUE_BASE_MS = 1200  -- não reemitir spam (evita ziguezague)
local _lastFollowIssue, _lastMode = 0, "idle"

-- deteta “modo” do dono (idle/walk/run/sprint)
local function ownerMode(ped)
    if IsPedSprinting(ped) then return "sprint" end
    if IsPedRunning(ped)   then return "run"    end
    if IsPedWalking(ped)   then return "walk"   end
    if GetEntitySpeed(ped) > 4.0 then return "run" end
    if GetEntitySpeed(ped) > 1.2 then return "walk" end
    return "idle"
end

local function modeSpeed(mode)
    if mode == "sprint" then return 3.0 end
    if mode == "run"    then return 2.6 end
    if mode == "walk"   then return 2.0 end
    return 1.4
end

local function issueFollow(owner, mode, force)
    if not Pet or not DoesEntityExist(Pet) or IsPedInAnyVehicle(Pet) then return end
    local now = nowMs()
    if not force and (now - _lastFollowIssue) < REISSUE_BASE_MS then return end
    _lastFollowIssue = now
    _lastMode = mode

    local spd = modeSpeed(mode)
    -- evita limpar tarefas; apenas reprograma o follow
    TaskFollowToOffsetOfEntity(Pet, owner, FOLLOW_OFFSET_X, FOLLOW_OFFSET_Y, FOLLOW_OFFSET_Z, spd, -1, 2.2, true)
    SetPedKeepTask(Pet, true)
    -- ajusta blend para ficar natural
    SetPedDesiredMoveBlendRatio(Pet, spd)
end

RegisterNetEvent("animals:__follow_loop_smooth")
AddEventHandler("animals:__follow_loop_smooth", function()
    CreateThread(function()
        while Pet and DoesEntityExist(Pet) do
            if not IsFollow or IsPedInAnyVehicle(Pet) or (combat and combat.target) then
                Wait(350)
            else
                local owner = PlayerPedId()
                local pCoords = GetEntityCoords(owner)
                local aCoords = GetEntityCoords(Pet)
                local dist    = #(pCoords - aCoords)

                if dist > TELEPORT_DIST then
                    SetEntityCoords(Pet, pCoords.x - 1.8, pCoords.y - 1.4, pCoords.z, false, false, false, true)
                    SetEntityHeading(Pet, GetEntityHeading(owner))
                    ClearPedTasksImmediately(Pet)
                    _lastFollowIssue, _lastMode = 0, "idle"
                    Wait(200)
                else
                    local mode = ownerMode(owner)
                    -- reemite se o modo mudou ou se afastou muito do offset (mantém perto, sem ziguezague)
                    if mode ~= _lastMode or dist > 6.0 then
                        issueFollow(owner, mode, true)
                    else
                        issueFollow(owner, mode, false)
                    end

                    -- se o dono parar e o pet já estiver perto do offset, ficar quieto um pouco
                    if mode == "idle" and dist < 3.0 and GetEntitySpeed(owner) < 0.2 then
                        TaskStandStill(Pet, 800)
                    end
                end
                Wait(250)
            end
        end
    end)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- FUNÇÕES (menu) + DESBUGAR/TP
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("animals:Functions")
AddEventHandler("animals:Functions", function(action)
    if not Pet or not DoesEntityExist(Pet) then return end
    local me = PlayerPedId()

    if action == "follow" then
        if IsPedInAnyVehicle(Pet) then return end
        IsStay = false
        IsFollow = not IsFollow
        if IsFollow then
            TriggerEvent("animals:__follow_loop_smooth")
        else
            TaskStandStill(Pet, -1)
        end

    elseif action == "stay" then
        if IsPedInAnyVehicle(Pet) then return end
        IsFollow, IsStay = false, true
        ClearPedTasksImmediately(Pet)
        TaskStandStill(Pet, -1)

    elseif action == "putvehicle" then
        if not IsPedInAnyVehicle(me) then return end
        local veh = GetVehiclePedIsIn(me, false)
        if veh ~= 0 and not IsPedOnAnyBike(me) then
            local seat = closestFreeSeat(veh)
            if seat then
                ClearPedTasksImmediately(Pet)
                TaskEnterVehicle(Pet, veh, -1, seat, 2.0, 16, 0)
                IsFollow, IsStay = false, false
            else
                notify("Animais","Não há lugar livre no veículo.","amarelo",4000)
            end
        end

    elseif action == "removevehicle" then
        if IsPedInAnyVehicle(Pet) then
            local veh = GetVehiclePedIsIn(Pet,false)
            if veh ~= 0 then
                TaskLeaveVehicle(Pet, veh, 256)
                Wait(800)
                IsFollow, IsStay = true, false
                TriggerEvent("animals:__follow_loop_smooth")
            end
        else
            notify("Animais","O pet não está dentro de nenhum veículo.","amarelo",4000)
        end

    elseif action == "destroy" then
        TriggerServerEvent("animals:Delete")
        clearPet()

    elseif action == "stopattack" then
        stopCombat()
        notify("Animais","Pet deixou de atacar.","azul",3000)

    elseif action == "unstuck" then
        local _now = nowMs()
        local remain = _unstuckCooldown - (_now - _lastUnstuck)
        if remain > 0 then
            notify("Animais",("Aguarda <b>%d</b>s para voltar a usar."):format(math.ceil(remain/1000)),"amarelo",4000)
            return
        end

        local forward = GetOffsetFromEntityInWorldCoords(me, -0.6, -1.0, 0.0)
        if requestControl(Pet) then
            SetEntityCoords(Pet, forward.x, forward.y, forward.z, false, false, false, true)
            SetEntityHeading(Pet, GetEntityHeading(me))
            ClearPedTasksImmediately(Pet)
            IsFollow, IsStay = true, false
            TriggerEvent("animals:__follow_loop_smooth")
            notify("Animais","Pet desbugado e teletransportado.","verde",3000)
            _lastUnstuck = _now
        else
            notify("Animais","Não foi possível controlar a entidade do pet.","vermelho",4000)
        end
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- SERVER → todos: apagar entidade por NetID
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("animals:DeleteNet")
AddEventHandler("animals:DeleteNet", function(netId)
    if not netId then return end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent ~= 0 and DoesEntityExist(ent) then
        if NetworkHasControlOfEntity(ent) or requestControl(ent) then
            SetEntityAsMissionEntity(ent,true,true)
            DeleteEntity(ent)
        end
    end
    if Pet and DoesEntityExist(Pet) and NetworkGetNetworkIdFromEntity(Pet) == netId then
        Pet = nil; PetNet = nil; PetModel = nil
        IsFollow, IsStay, CurrentEnemy = false, false, nil
        _spawnWeaponHash = nil
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- Watchdog leve: mantém a arma DO SPAWN selecionada (sem recriar)
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
    local UNARMED = GetHashKey("WEAPON_UNARMED")
    while true do
        if Pet and DoesEntityExist(Pet) and IsPedHuman(Pet) and _spawnWeaponHash and _spawnWeaponHash ~= UNARMED then
            local sel = GetSelectedPedWeapon(Pet)
            if sel == 0 or sel == UNARMED then
                SetCurrentPedWeapon(Pet, _spawnWeaponHash, true)
            end
            SetPedCanSwitchWeapon(Pet, false)
        end
        Wait(300)
    end
end)
