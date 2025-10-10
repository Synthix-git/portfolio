-----------------------------------------------------------------------------------------------------------------------------------------
-- STOCKADE (SERVER-SIDE ONLY) — robusto com “hard timeout” (ms) + limpeza extra
-- • Crowbar obrigatório
-- • Animação “arrombar” (sem reapply; player “blindado”)
-- • Cancela se mover > 0.35m (tolerância contra jitter)
-- • Progress server-side (usa os teus eventos)
-- • **Alerta aos 25%**: avisa jogador + policia
-- • Alerta / cooldown global só em SUCESSO
-- • Recompensa aleatória [REWARD_MIN, REWARD_MAX]
-- • EXP "Assaltante" com bónus por nível (tempo ↓ e dinheiro ↑)
-- • Failsafes: watchdog, reaper, hard-timeout por GetGameTimer, cancel unificado, playerDropped
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP          = Proxy.getInterface("vRP")
vRPC         = Tunnel.getInterface("vRP")
vINV         = Tunnel.getInterface("inventory")

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONFIG
-----------------------------------------------------------------------------------------------------------------------------------------
local MIN_COPS        = 1
local GLOBAL_COOLDOWN = 120        -- segundos; só em sucesso
local TAKE_TIME_MS    = 60000      -- duração base (ajustada por nível)
local REWARD_ITEM     = "dirtydollar"
local REWARD_MIN      = 72250
local REWARD_MAX      = 300000
local STOCK_PER_TRUCK = 10

-- animação "arrombar"
local ANIM_DICT       = "missheistfbi3b_ig7"
local ANIM_NAME       = "lift_fibagent_loop"

-- progressbar (eventos do teu HUD)
local PROGRESS_EVENT_START   = "Progress"        -- client: (labelHTML, durationMs)
local PROGRESS_EVENT_CANCEL  = "ProgressCancel"  -- client: () fecha/cancela a barra

-- anti-exploit / estabilidade
local MAX_MOVE_DISTANCE     = 0.35   -- metros
local WATCHDOG_TICK         = 150    -- ms
local REAPER_TICK_MS        = 1000   -- ms (limpeza mais frequente)
local EXPIRE_GRACE_MS       = 1500   -- tolerância pós-fim (ms)

-----------------------------------------------------------------------------------------------------------------------------------------
-- SKILL "Assaltante"
-----------------------------------------------------------------------------------------------------------------------------------------
local SKILL_NAME       = "Assaltante"
local EXP_PER_SUCCESS  = 5
local LEVEL_THRESHOLDS = { 0,150,400,800,1300,2000,2800,3700,4700,5800 }
local LEVEL_BONUS = {
    [1] = {1.00,1.00}, [2] = {0.98,1.03}, [3] = {0.96,1.06}, [4] = {0.94,1.09}, [5] = {0.92,1.12},
    [6] = {0.90,1.15}, [7] = {0.88,1.18}, [8] = {0.86,1.21}, [9] = {0.84,1.24}, [10]= {0.82,1.27}
}

-----------------------------------------------------------------------------------------------------------------------------------------
-- STATE
-----------------------------------------------------------------------------------------------------------------------------------------
-- Active[passport] = {
--   token, plate, start(vec3), endsAtSec(os.time), endsAtMs(GetGameTimer+effMs),
--   effMs, src, warned25(boolean)
-- }
local Stockades, Active, Alerted = {}, {}, {}
local NextOpen, Seq = 0, 0

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS
-----------------------------------------------------------------------------------------------------------------------------------------
local function normalizePlate(p)
    if not p or p == "" then return nil end
    return (tostring(p):gsub("%s+","")):upper()
end

local function copsOnline()
    local _, t = vRP.NumPermission("Policia")
    return t or 0
end

local function notify(src, titulo, msg, cor, tempo)
    TriggerClientEvent("Notify", src, titulo, msg, cor or "amarelo", tempo or 5000)
end

local function vecDist(a,b)
    local dx,dy,dz = a.x-b.x, a.y-b.y, a.z-b.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local function getCoordsOrNil(src)
    local ok, coords = pcall(vRP.GetEntityCoords, src)
    if ok and coords then return coords end
    return nil
end

local function hasCrowbar(src)
    if vINV and vINV.CheckWeapon then
        return vINV.CheckWeapon(src,"WEAPON_CROWBAR")
    end
    local passport = vRP.Passport(src)
    return passport and vRP.InventoryItemAmount(passport,"crowbar") > 0 or false
end

local function getLevelFromExp(exp)
    local lvl = 1
    for i = #LEVEL_THRESHOLDS, 1, -1 do
        if exp >= LEVEL_THRESHOLDS[i] then
            lvl = i
            break
        end
    end
    return lvl
end

local function getPlayerSkill(passport)
    local exp = (vRP.GetExperience and vRP.GetExperience(passport,SKILL_NAME)) or 0
    return exp, getLevelFromExp(exp)
end

local function getLevelBonus(level)
    return LEVEL_BONUS[level] or LEVEL_BONUS[#LEVEL_BONUS]
end

-- wrappers de “blindagem” (ajusta nomes se precisares)
local function lockPlayer(src)
    Player(src)["state"]["Buttons"] = true
    if vRPC and vRPC.FreezePosition then vRPC.FreezePosition(src,true) end
    if vRPC and vRPC.BlockTasks then vRPC.BlockTasks(src,true) end
end

local function unlockPlayer(src)
    Player(src)["state"]["Buttons"] = false
    if vRPC and vRPC.BlockTasks then vRPC.BlockTasks(src,false) end
    if vRPC and vRPC.FreezePosition then vRPC.FreezePosition(src,false) end
end

local function startAnim(src) if vRPC and vRPC.playAnim then vRPC.playAnim(src,false,{ANIM_DICT,ANIM_NAME},true) end end
local function stopAnim(src) if vRPC and vRPC.Destroy then vRPC.Destroy(src) end end

-- Fecha progressbar SEMPRE (cancel explícito + fallback + seguro)
local function forceCloseProgress(src)
    TriggerClientEvent(PROGRESS_EVENT_CANCEL, src)         -- 1) tenta fechar
    TriggerClientEvent(PROGRESS_EVENT_START, src, "", 50)  -- 2) fallback 50ms
    SetTimeout(60, function()                              -- 3) seguro
        TriggerClientEvent(PROGRESS_EVENT_CANCEL, src)
    end)
end

local function cancelProgressAndAnim(src)
    stopAnim(src)
    forceCloseProgress(src)
end

local function logAssalto(src, titulo, descricao)
    if exports["discord"] and exports["discord"].Embed then
        local passport = vRP.Passport(src)
        local identity = vRP.Identity(passport)
        local name = identity and (identity.name.." "..identity.name2) or "Indefinido"
        exports["discord"]:Embed("Assaltos",("💰 **%s**\n\n👤 **Suspeito:** %s [#%s]\n%s"):format(titulo,name,passport,descricao),src)
    end
end

-- Cancel unificado anti-stuck
local function cancelAction(passport, reason, doNotify)
    local act = Active[passport]
    if not act then return end
    local src = act.src
    Active[passport] = nil
    if src then
        unlockPlayer(src)
        cancelProgressAndAnim(src)
        if doNotify then
            notify(src,"Atenção",("Assalto <b>cancelado</b>%s."):format(reason and (" ("..reason..")") or ""), "amarelo", 5000)
        end
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- WATCHDOG (sem reapply de animação; cancela por movimento/desync)
-----------------------------------------------------------------------------------------------------------------------------------------
local function startWatchdog(passport, token, startCoords, effMs)
    CreateThread(function()
        local act = Active[passport]
        if not act then return end
        local src = act.src
        local deadlineMs = GetGameTimer() + effMs + 250
        while true do
            Wait(WATCHDOG_TICK)
            act = Active[passport]
            if not act or act.token ~= token then break end
            if GetGameTimer() >= deadlineMs then break end

            local coords = getCoordsOrNil(src)
            if not coords then
                cancelAction(passport, "desconexão do ped", true)
                break
            end

            if vecDist(coords,startCoords) > MAX_MOVE_DISTANCE then
                cancelAction(passport, "movimentação", true)
                break
            end
        end
    end)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- REAPER PERIÓDICO (limpa sessões expiradas/bugadas)
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(REAPER_TICK_MS)
        local nowSec = os.time()
        local nowMs  = GetGameTimer()
        for passport, act in pairs(Active) do
            repeat
                if not act or not act.endsAtSec or not act.endsAtMs then
                    cancelAction(passport, "timeout inválido", false)
                    break
                end
                -- HARD TIMEOUT por milissegundos (cobre qualquer drift de os.time)
                if nowMs >= (act.endsAtMs + EXPIRE_GRACE_MS) then
                    cancelAction(passport, "timeout (ms)", false)
                    break
                end
                -- Segundo fallback por segundos (mantido por compat)
                if nowSec >= (act.endsAtSec + math.ceil(EXPIRE_GRACE_MS/1000)) then
                    cancelAction(passport, "timeout (sec)", false)
                    break
                end
                -- sanity: se o jogador não existir mais, limpa
                local src = act.src
                if not src or not Player(src) then
                    Active[passport] = nil
                    break
                end
            until true
        end
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- CANCEL EXTERNO & PLAYER DROPPED
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("inventory:Stockade:Cancel")
AddEventHandler("inventory:Stockade:Cancel",function()
    local src = source
    local passport = vRP.Passport(src)
    if not passport then return end
    cancelAction(passport, nil, true)
end)

AddEventHandler("playerDropped", function()
    local src = source
    local passport = vRP.Passport(src)
    if passport and Active[passport] then
        cancelAction(passport, "disconnect", false)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- INICIAR
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("inventory:Stockade")
AddEventHandler("inventory:Stockade",function(vehicle)
    local src = source
    local passport = vRP.Passport(src)
    if not passport then return end

    local plate = vehicle and vehicle[1] and normalizePlate(vehicle[1]) or nil
    if not plate then notify(src,"Atenção","Veículo <b>inválido</b>.","amarelo",5000) return end

    local nowSec = os.time()
    local nowMs  = GetGameTimer()

    if NextOpen > 0 and nowSec < NextOpen then
        local mins = math.max(0,math.floor((NextOpen - nowSec)/60))
        notify(src,"Atenção",("Sistema reforçado. Tenta em <b>%d min</b>."):format(mins),"amarelo",6000)
        return
    end

    -- Se existir sessão antiga mas já expirou, limpa e permite recomeçar (anti-stuck)
    if Active[passport] then
        local act = Active[passport]
        if nowMs >= (act.endsAtMs or 0) + EXPIRE_GRACE_MS then
            cancelAction(passport, "reset expirado", false)
        end
    end

    if Active[passport] then
        notify(src,"Atenção","Já estás a abrir um <b>compartimento</b>.","amarelo",4500)
        return
    end

    if copsOnline() < MIN_COPS then
        notify(src,"Atenção",("É necessário pelo menos <b>%d</b> polícia."):format(MIN_COPS),"amarelo",6000)
        return
    end

    if vRP.PassportPlate(plate) then
        notify(src,"Atenção","Este veículo <b>não</b> é um Carro Forte válido.","amarelo",5000)
        return
    end

    if not hasCrowbar(src) then
        notify(src,"Atenção","<b>Pé de Cabra</b> não encontrado.","amarelo",5000)
        return
    end

    -- bónus
    local curExp,curLvl = getPlayerSkill(passport)
    local timeMult,moneyMult = table.unpack(getLevelBonus(curLvl))
    local effMs = math.max(5000,math.floor(TAKE_TIME_MS * timeMult))

    Seq = Seq + 1
    local token = Seq
    local startCoords = getCoordsOrNil(src) or vec3(0.0,0.0,0.0)
    Active[passport] = {
        token     = token,
        plate     = plate,
        start     = startCoords,
        endsAtSec = nowSec + math.floor(effMs/1000),
        endsAtMs  = nowMs  + effMs,
        effMs     = effMs,
        src       = src,
        warned25  = false
    }

    -- lock, progress e animação (uma única vez, sem reapply)
    lockPlayer(src)
    local label = ("Roubando o <b>Carro Forte</b> <span style='opacity:.8'>(Nível %d • %.0f%% tempo • %.0f%% $)</span>"):format(curLvl,timeMult*100,moneyMult*100)
    TriggerClientEvent(PROGRESS_EVENT_START,src,label,effMs)
    startAnim(src)

    -- ALERTA AOS 25% DO PROGRESSO
    SetTimeout(math.floor(effMs * 0.25), function()
        local act = Active[passport]
        if act and act.token == token and not act.warned25 then
            act.warned25 = true

            -- Aviso ao jogador
            notify(src,"Atenção","<b>Uma testemunha viu o assalto, a polícia foi avisada!</b>","amarelo",6000)

            -- Alerta à polícia (apenas uma vez por placa)
            if not Alerted[plate] then
                if exports["vrp"] and exports["vrp"].CallPolice then
                    exports["vrp"]:CallPolice({
                        ["Source"]=src, ["Passport"]=passport,
                        ["Permission"]="Policia", ["Name"]="Roubo a Carro Forte",
                        ["Code"]=31, ["Color"]=44
                    })
                end
                Alerted[plate] = true

                -- Log opcional
                logAssalto(
                    src,
                    "Alerta antecipado (25%) - Carro Forte",
                    ("🔔 **Alerta de testemunha**\n🔢 **Placa:** `%s`"):format(plate)
                )
            end
        end
    end)

    -- watchdog só para cancelar (nunca recomeça a anim)
    startWatchdog(passport,token,startCoords,effMs)

    if vRP.ColdTimer then vRP.ColdTimer(passport,effMs) end
    if vRP.UpgradeStress then vRP.UpgradeStress(passport,2) end

    SetTimeout(effMs,function()
        local act = Active[passport]
        -- Se já foi cancelado pelo watchdog/cancel externo, termina limpo
        if not act or act.token ~= token then
            unlockPlayer(src)
            cancelProgressAndAnim(src)
            return
        end

        -- sucesso
        Active[passport] = nil
        cancelProgressAndAnim(src)
        unlockPlayer(src)

        -- stock init em SUCESSO
        if not Stockades[plate] then
            Stockades[plate] = STOCK_PER_TRUCK
            if Alerted[plate] == nil then Alerted[plate] = false end -- pode já ter alertado nos 25%
        end

        if (Stockades[plate] or 0) <= 0 then
            notify(src,"Atenção","Compartimento <b>vazio</b>.","amarelo",5000)
            return
        end

        Stockades[plate] = Stockades[plate] - 1

        local baseReward  = math.random(REWARD_MIN,REWARD_MAX)
        local finalReward = math.floor(baseReward * moneyMult + 0.5)
        vRP.GenerateItem(passport,REWARD_ITEM,finalReward,true)

        local oldExp = curExp
        local newExp = oldExp + EXP_PER_SUCCESS
        if vRP.PutExperience then vRP.PutExperience(passport,SKILL_NAME,newExp) end
        local newLvl = getLevelFromExp(newExp)

        if newLvl > curLvl then
            local tMult,mMult = table.unpack(getLevelBonus(newLvl))
        else
        end

        -- caso não tenha alertado aos 25%, alerta agora (uma vez por placa)
        if not Alerted[plate] then
            if exports["vrp"] and exports["vrp"].CallPolice then
                exports["vrp"]:CallPolice({
                    ["Source"]=src, ["Passport"]=passport,
                    ["Permission"]="Policia", ["Name"]="Roubo a Carro Forte",
                    ["Code"]=31, ["Color"]=44
                })
            end
            Alerted[plate] = true
        end

        -- cooldown global (só em sucesso)
        NextOpen = os.time() + GLOBAL_COOLDOWN

        -- log
        logAssalto(
            src,
            "Roubo a Carro Forte - Recompensa",
            ("📦 **Restante:** %d/%d\n💵 **Recompensa:** %d %s (bónus nível %d)\n🔢 **Placa:** `%s`")
                :format(Stockades[plate],STOCK_PER_TRUCK,finalReward,REWARD_ITEM,curLvl,plate)
        )

        if Stockades[plate] <= 0 then
            notify(src,"Informação","O Carro Forte foi <b>esvaziado</b>.","azul",5000)
        else
            notify(src,"Sucesso",("Abriste o compartimento. Restam <b>%d</b>."):format(Stockades[plate]),"verde",6000)
        end
    end)
end)
