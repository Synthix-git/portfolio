-------------------------------------------------
-- Smoke Grenade Effects (client)
-------------------------------------------------

local ENABLED = true
if not ENABLED then return end

--  Config 
local SMOKE_MODELS        = { "w_ex_smokegrenade", "w_ex_grenadesmoke", "prop_smokegrenade" }
local SCAN_RADIUS         = 85.0
local CLOUD_RADIUS        = 7.5
local CLOUD_LIFETIME_MS   = 20000

-- Anti-dano no ar / “arming”
local ARM_GRACE_MS        = 1200      -- ms mínimos desde que o objeto foi detetado
local SPEED_EPS           = 0.85       -- m/s para considerar parado
local GROUND_EPS          = 1.25       -- distância ao chão
local GROUNDED_FOR_MS     = 400        -- tempo parado no chão para armar

-- Ticks/loop
local TICK_INSIDE_MS      = 1000
local LOOP_SLEEP_MS       = 110

-- Histerese de presença (mantém efeito depois de sair)
local LINGER_AFTER_EXIT_MS = 2600
local EXIT_EXTRA_RADIUS    = 2.25

-- Gasmask (state vindo do script máscara)
local GAS_STATE_KEY       = "GasMask"

-- Sem dano enquanto a seguras (apenas fora de nuvem)
local SMOKE_WEAPON        = GetHashKey("WEAPON_SMOKEGRENADE")

-- Overlay de ecrã (cinza turvo) + fade
local SCREEN_TINT         = { r = 120, g = 120, b = 120 }
local Overlay = {
    alpha = 0,          -- alpha atual (0..255)
    target = 0,         -- alpha desejado (0..255)
    fadeInRate = 540,   -- alpha/seg a entrar
    fadeOutRate = 360,  -- alpha/seg a sair (↓ mais lento)
    tcOn = false
}
-- Timecycle mais pesado para visão turva (NEUTRO)
local TC_NAME     = "NG_filmic01"   -- neutro/filmico, sem verde
local TC_STRENGTH = 0.85            -- ajusta a gosto (0.6–1.0)


--  State 
local _modelHashes = {}
for _, name in ipairs(SMOKE_MODELS) do _modelHashes[GetHashKey(name)] = true end

-- Rastreamento de ENTIDADES para “armar”
-- Entities[ent] = { armAt, lastPos, lastTime, onGroundSince, armed, spawnedCloudId }
local Entities = {}

-- Nuvens independentes do objeto (desacopladas da vida do prop)
-- Clouds[id] = { pos, expires, radius }
local Clouds = {}

local SmokeEffect = {
    inside = false,
    clipset = "move_m@drunk@slightlydrunk",
    lastTick = 0,
    lastCough = 0,
    coughLockUntil = 0,
    lastInsideUntil = 0
}

--  Helpers 
local function dist(a,b) local dx,dy,dz=a.x-b.x,a.y-b.y,a.z-b.z return (dx*dx+dy*dy+dz*dz)^0.5 end

local function HasGasMaskOn()
    local st = LocalPlayer and LocalPlayer.state
    return (st and st[GAS_STATE_KEY]) and true or false
end

local function IsOnGroundCloseTo(pos)
    local success, gz = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 0.5, true)
    if not success then return false end
    return (pos.z - gz) <= GROUND_EPS
end

local function NewCloudIdAt(pos)
    return ("SMK|%.2f|%.2f|%.2f|%d"):format(pos.x, pos.y, pos.z, math.random(1000,999999))
end

local function SpawnCloudSnapshot(pos, now)
    local id = NewCloudIdAt(pos)
    Clouds[id] = {
        pos = pos + vector3(0.0,0.0,0.05),
        expires = now + CLOUD_LIFETIME_MS,
        radius = CLOUD_RADIUS
    }
    return id
end

local function EnsureEntityTracked(ent, now)
    local info = Entities[ent]
    local pos  = GetEntityCoords(ent)

    if not info then
        Entities[ent] = {
            armAt = now + ARM_GRACE_MS,
            lastPos = pos,
            lastTime = now,
            onGroundSince = 0,
            armed = false,
            spawnedCloudId = nil
        }
        return
    end

    -- update movimento/ground
    local dt = math.max(1, now - (info.lastTime or now)) / 1000.0
    local speed = dist(pos, info.lastPos or pos) / dt
    local onGround = IsOnGroundCloseTo(pos)

    if speed <= SPEED_EPS and onGround then
        if info.onGroundSince == 0 then info.onGroundSince = now end
    else
        info.onGroundSince = 0
    end

    -- armar quando: passou grace + parado + no chão por GROUNDED_FOR_MS
    if (not info.armed) and now >= info.armAt and info.onGroundSince > 0 and (now - info.onGroundSince) >= GROUNDED_FOR_MS then
        info.armed = true
        if not info.spawnedCloudId then
            info.spawnedCloudId = SpawnCloudSnapshot(pos, now) -- << cloud independente do objeto
        end
    end

    info.lastPos = pos
    info.lastTime = now
end

-- Som/anim de tosse robusto (sempre com fallback) + lock de tiro
local function PlayCough(ped)
    if not DoesEntityExist(ped) then return end

    local dict, name = "timetable@gardener@smoking_joint", "idle_cough"
    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        local t = GetGameTimer() + 1500
        while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(0) end
    end
    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(ped, dict, name, 2.0, -2.0, 1500, 48, 0, false, false, false)
    end

    -- bloquear disparo enquanto a animação decorre (~1.5s)
    SmokeEffect.coughLockUntil = GetGameTimer() + 1500

    StopCurrentPlayingAmbientSpeech(ped)
    PlayAmbientSpeech1(ped, "COUGH", "SPEECH_PARAMS_FORCE_SHOUTED")
    Wait(10)
    if not IsAmbientSpeechPlaying(ped) then
        PlayPain(ped, 7, 0.0) -- fallback de som
    end
    ShakeGameplayCam("SMALL_EXPLOSION_SHAKE", 0.85)
end

-- Overlay (draw every-frame)
local function DrawScreenTint(alpha)
    DrawRect(0.5, 0.5, 1.0, 1.0, SCREEN_TINT.r, SCREEN_TINT.g, SCREEN_TINT.b, alpha)
end

local function EnableGreyTurbid()
    if Overlay.tcOn then return end
    ClearTimecycleModifier()            -- limpa qualquer TC antigo (evita tonalidades)
    Wait(0)
    SetTimecycleModifier(TC_NAME)
    SetTimecycleModifierStrength(TC_STRENGTH)
    Overlay.tcOn = true
end


local function DisableGreyTurbid()
    if not Overlay.tcOn then return end
    ClearTimecycleModifier()
    Overlay.tcOn = false
end

--  Main 
CreateThread(function()
    while not DoesEntityExist(PlayerPedId()) do Wait(250) end

    -- Scanner de objetos: só para detetar/armar ENTIDADES
    CreateThread(function()
        while true do
            local now = GetGameTimer()

            -- limpa ENTIDADES inválidas; (não apaga Clouds!)
            for ent, info in pairs(Entities) do
                if not DoesEntityExist(ent) then
                    Entities[ent] = nil
                end
            end

            local ped = PlayerPedId()
            if DoesEntityExist(ped) then
                local myPos = GetEntityCoords(ped)

                -- Pool de objetos (usa apenas GetGamePool para evitar duplicação)
                local objs = GetGamePool and GetGamePool("CObject") or {}
                for _, ent in ipairs(objs) do
                    if DoesEntityExist(ent) and _modelHashes[GetEntityModel(ent)] then
                        -- ignora se anexada ao teu ped (na mão)
                        if not IsEntityAttachedToEntity(ent, ped) then
                            local c = GetEntityCoords(ent)
                            -- usar distância ao quadrado para evitar sqrt
                            local dx,dy,dz = myPos.x - c.x, myPos.y - c.y, myPos.z - c.z
                            local d2 = dx*dx + dy*dy + dz*dz
                            if d2 <= (SCAN_RADIUS * SCAN_RADIUS) then
                                EnsureEntityTracked(ent, now)
                            end
                        end
                    end
                end
            end

            -- scan com menor frequência para reduzir CPU (320 -> 700ms)
            Wait(700)
        end
    end)

    -- Limpeza de CLOUDS por tempo (independente do objeto existir)
    CreateThread(function()
        while true do
            local now = GetGameTimer()
            for id, cloud in pairs(Clouds) do
                if not cloud or cloud.expires <= now then
                    Clouds[id] = nil
                end
            end
            Wait(500)
        end
    end)

    -- Efeitos/dano + alvo do overlay/timecycle
    CreateThread(function()
        while true do
            local ped = PlayerPedId()
            local needOverlay = false

            if DoesEntityExist(ped) and not IsEntityDead(ped) then
                local p, now = GetEntityCoords(ped), GetGameTimer()

                -- dentro de alguma cloud ativa (com margem de saída)
                local inCloudRaw = false
                for _, info in pairs(Clouds) do
                    if info and info.expires > now then
                        local r = (info.radius or CLOUD_RADIUS)
                        if dist(p, info.pos) <= (r + EXIT_EXTRA_RADIUS) then
                            inCloudRaw = true
                            break
                        end
                    end
                end

                -- histerese temporal: mantém estado por LINGER_AFTER_EXIT_MS
                if inCloudRaw then
                    SmokeEffect.lastInsideUntil = now + LINGER_AFTER_EXIT_MS
                end
                local inCloud = inCloudRaw or (now < SmokeEffect.lastInsideUntil)

                local hasMask = HasGasMaskOn()
                local holdingSmoke = (GetSelectedPedWeapon(ped) == SMOKE_WEAPON)

                -- >>> ALTERAÇÃO PRINCIPAL <<<
                -- Apenas suprimir efeitos por "holding" quando NÃO está numa nuvem.
                local suppressByHolding = (holdingSmoke and not inCloud)

                if inCloud and (not hasMask) then
                    -- mesmo com granada na mão, mantém efeito se estiver na nuvem
                    needOverlay = true

                    if not SmokeEffect.inside then
                        SmokeEffect.inside = true
                        if not HasAnimSetLoaded(SmokeEffect.clipset) then
                            RequestAnimSet(SmokeEffect.clipset)
                            local t = GetGameTimer() + 1500
                            while not HasAnimSetLoaded(SmokeEffect.clipset) and GetGameTimer() < t do Wait(0) end
                        end
                        if HasAnimSetLoaded(SmokeEffect.clipset) then
                            SetPedMovementClipset(ped, SmokeEffect.clipset, 0.25)
                        end
                        SetPedMotionBlur(ped, true)
                    end

                    -- dano/som só se não estiveres em “holding suppress” (não aplicável aqui porque inCloud == true)
                    if not suppressByHolding and (now - SmokeEffect.lastTick >= TICK_INSIDE_MS) then
                        SmokeEffect.lastTick = now
                        local hp = GetEntityHealth(ped)
                        if hp > 110 then
                            SetEntityHealth(ped, hp - 1)
                        end
                        if now - SmokeEffect.lastCough >= 3800 then
                            SmokeEffect.lastCough = now
                            PlayCough(ped)
                        end
                    end
                else
                    if SmokeEffect.inside then
                        SmokeEffect.inside = false
                        ResetPedMovementClipset(ped, 0.25)
                        SetPedMotionBlur(ped, false)
                        StopGameplayCamShaking(true)
                    end
                end

                -- BLOQUEIO DE DISPARO DURANTE A TOSSE
                if now < SmokeEffect.coughLockUntil then
                    DisablePlayerFiring(PlayerId(), true)
                    DisableControlAction(0, 24, true)   -- Attack
                    DisableControlAction(0, 257, true)  -- Attack2
                    DisableControlAction(0, 25, true)   -- Aim
                    DisableControlAction(0, 263, true)  -- Melee Attack 1
                    DisableControlAction(0, 140, true)  -- Melee Light
                    DisableControlAction(0, 141, true)  -- Melee Heavy
                    DisableControlAction(0, 142, true)  -- Melee Alternate
                    DisableControlAction(0, 106, true)  -- Vehicle Mouse Control Override
                    SetPlayerCanDoDriveBy(PlayerId(), false)
                else
                    SetPlayerCanDoDriveBy(PlayerId(), true)
                end
            end

            -- target de overlay/timecycle
            local newTarget = needOverlay and 249 or 0
            if newTarget ~= Overlay.target then
                Overlay.target = newTarget
                -- ligar/desligar timecycle conforme necessidade
                if Overlay.target > 0 then
                    EnableGreyTurbid()
                else
                    if Overlay.alpha <= 1 then
                        DisableGreyTurbid()
                    end
                end
            end

            Wait(LOOP_SLEEP_MS)
        end
    end)

    -- Loop do overlay: desenha todas as frames com fade suave (sem flicker)
    CreateThread(function()
        local last = GetGameTimer()
        while true do
            local now = GetGameTimer()
            local dt = math.max(1, now - last) / 1000.0
            last = now

            if Overlay.alpha < Overlay.target then
                Overlay.alpha = math.min(Overlay.target, Overlay.alpha + Overlay.fadeInRate * dt)
            elseif Overlay.alpha > Overlay.target then
                Overlay.alpha = math.max(Overlay.target, Overlay.alpha - Overlay.fadeOutRate * dt)
            end

            local a = math.floor(Overlay.alpha + 0.5)
            if a > 0 then
                DrawScreenTint(a) -- every frame -> sem flicker
            end

            Wait(0) -- frame loop
        end
    end)
end)
