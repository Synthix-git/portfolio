-----------------------------------------------------------------------------------------------------------------------------------------
-- DISMANTLE (SERVER)
-- Autor: Synthix (Syn Network)
-- Requisitos: vRP, Notify, Progress, exports["discord"]:Embed (canal "Assaltos"), GlobalState["Plates"]
-----------------------------------------

vRP.Prepare("vehicles/arrestByOwnerModel",[[
    UPDATE vehicles
       SET arrest = @arrest
     WHERE Passport = @Passport AND vehicle = @vehicle
]])

------------------------------------------------------------------------------------------------

-- VRP / Tunnel / Proxy
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP          = Proxy.getInterface("vRP")

--  CONFIG
local ZONES = {
    vec4(476.93,  -1278.68, 29.54, 10.0), -- original
    vec4(-27.27,  -1679.36, 29.46, 10.0),
    vec4(-68.99,  -1825.48, 26.94, 10.0),
    vec4(226.29,  -1993.36, 19.57, 10.0)
}

local COOLDOWN_SECONDS   = 120
local PROGRESS_MS        = 30000
local BLOCK_OWNED_SELF   = true

local IMPOUND_HOURS      = 24
local OWNED_BONUS_PERCENT= 0.05
local IMPOUND_FEE_PERCENT= 0.25
local VEHICLE_PRICE_FALLBACK = 10000

local POLICE_MIN_ONLINE  = 0

local REQUEST_TITLE      = "Desmanche"
local REQUEST_TEXT       = "Este veículo pode ser desmanchado.<br>Deseja <b>iniciar o desmanche</b> agora?"
local REQUEST_YES        = "Sim, começar"
local REQUEST_NO         = "Não"

local ALERT_POLICE_BASE          = 0.75
local ALERT_VIP_REDUCTION        = { [1]=0.15, [2]=0.10, ["default"]=0.05 }
local ALERT_PER_LEVEL            = 0.02
local ALERT_LEVEL_REDUCTION_MAX  = 0.20

local CLASS_REWARDS = {
    [0]={900,1100}, [1]={1100,1400}, [2]={1250,1600}, [3]={1300,1700}, [4]={1300,1700},
    [5]={1500,2000}, [6]={1700,2300}, [7]={2100,2800}, [8]={700,1000}, [9]={1000,1400},
    [10]={1000,1400},[11]={1000,1400},[12]={1000,1400}
}

local CLASS_BLACKLIST = { [13]=true,[14]=true,[15]=true,[16]=true,[17]=true,[18]=true,[19]=true,[21]=true }
local MODEL_BLACKLIST = {
    ["police"]=true,["police2"]=true,["police3"]=true,["police4"]=true,
    ["pbus"]=true,["riot"]=true,["prisonbus"]=true,["ambulance"]=true,["firetruk"]=true,
    ["polheli"]=true,["maverick"]=true,["riot2"]=true,["stockade"]=true
}

local DEXTERITY_BONUS = 0.10
local PREMIUM_BONUS   = { [1]=0.10, [2]=0.075, ["default"]=0.05 }

local XP_BASE           = 3
local XP_PREMIUM_EXTRA  = 2

local DISCORD_CHANNEL = "Assaltos"

-- SQL
vRP.Prepare("vehicles/arrestByPlate","UPDATE vehicles SET arrest = @arrest WHERE plate = @plate")
vRP.Prepare("vehicles/arrestByPlateLike",[[
    UPDATE vehicles
       SET arrest = @arrest
     WHERE REPLACE(UPPER(plate),' ','') = @plate_norm
]])

-- Helpers
local function inAnyZone(x,y,z)
    for i=1,#ZONES do
        local c = ZONES[i]
        local dx,dy,dz = x - c.x, y - c.y, z - c.z
        if (dx*dx + dy*dy + dz*dz) <= (c.w * c.w) then return true,i end
    end
    return false,nil
end

local function dotted(n)
    local l,num,r = tostring(n):match('^([^%d]*%d)(%d*)(.-)$')
    return l..(num:reverse():gsub('(%d%d%d)','%1.'):reverse())..r
end

local function rewardRange(class) return CLASS_REWARDS[class] end

local function fullNameOr(pass)
    local ok,n = pcall(vRP.FullName, pass)
    return (ok and n and n ~= "") and n or ("#"..tostring(pass))
end

local function VehiclePrice(model)
    if _G.VehiclePrice and type(_G.VehiclePrice)=="function" then
        local ok,price = pcall(_G.VehiclePrice, model)
        if ok and type(price)=="number" and price>0 then return price end
    end
    return VEHICLE_PRICE_FALLBACK
end

local function LevelFromExperience(passport)
    local exp = vRP.GetExperience(passport, "Dismantle") or 0
    return math.min(10, math.floor(exp / 100))
end

local function computePoliceChance(passport, src)
    local chance = ALERT_POLICE_BASE
    if vRP.UserPremium(passport) then
        local lv = (vRP.LevelPremium and vRP.LevelPremium(src)) or 1
        chance = chance - (ALERT_VIP_REDUCTION[lv] or ALERT_VIP_REDUCTION["default"])
    end
    chance = chance - math.min(ALERT_LEVEL_REDUCTION_MAX, LevelFromExperience(passport) * ALERT_PER_LEVEL)
    return math.max(0.0, math.min(1.0, chance))
end

local function computeReward(passport, minv, maxv, src)
    local amount = math.random(minv, maxv)
    local valuation = amount + (amount * 0.05)
    if exports["inventory"] and exports["inventory"].Buffs and exports["inventory"]:Buffs("Dexterity", passport) then
        valuation = valuation + (valuation * DEXTERITY_BONUS)
    end
    if vRP.UserPremium(passport) then
        local lv = (vRP.LevelPremium and vRP.LevelPremium(src)) or 1
        valuation = valuation + (valuation * (PREMIUM_BONUS[lv] or PREMIUM_BONUS["default"]))
    end
    return math.floor(valuation + 0.5)
end

local function xpGain(passport) return (vRP.UserPremium(passport) and (XP_BASE+XP_PREMIUM_EXTRA) or XP_BASE) end

-- Normalização de plate para cruzar com GlobalState["Plates"]
local function plateUpper(s) return (tostring(s or "")):upper() end
local function plateUpperNoSpace(s) return plateUpper(s):gsub("%s+","") end
local function plateNormalize(s) return plateUpper(s):gsub("[^%w]","") end

local function getOwnerPassportByPlate(rawPlate)
    local Plates = GlobalState["Plates"] or {}
    if type(Plates) ~= "table" then return nil end
    local up = plateUpper(rawPlate)
    if Plates[up] then return Plates[up] end
    local noSpace = plateUpperNoSpace(rawPlate)
    if Plates[noSpace] then return Plates[noSpace] end
    local norm = plateNormalize(rawPlate)
    for k,v in pairs(Plates) do
        if plateNormalize(k) == norm then return v end
    end
    return nil
end

-- Estados
local Cooldown       = {}
local Ongoing        = {}
local PendingConfirm = {}

-- CONFIRM
RegisterServerEvent("dismantle:Confirm")
AddEventHandler("dismantle:Confirm", function(payload)
    local src = source
    local passport = vRP.Passport(src)
    if not passport or not payload then return end
    if PendingConfirm[passport] or Ongoing[passport] then return end

    if POLICE_MIN_ONLINE > 0 and vRP.AmountService("Policia") < POLICE_MIN_ONLINE then
        TriggerClientEvent("Notify", src, "Atenção", "Contingente policial indisponível.", "amarelo", 5000)
        return
    end

    if Cooldown[passport] and os.time() < Cooldown[passport] then
        local left = Cooldown[passport] - os.time()
        TriggerClientEvent("Notify", src, "Aviso", "Aguarde <b>"..left.."s</b> para desmanchar novamente.", "amarelo", 5000)
        return
    end

    local netId = tonumber(payload.netId or 0)
    local plate = tostring(payload.plate or "")
    local model = tostring(payload.model or ""):lower()
    local vclass= tonumber(payload.class or -1)
    if netId == 0 or plate == "" or vclass < 0 then return end

    -- valida entidade do veículo
    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) or GetEntityType(ent) ~= 2 then
        TriggerClientEvent("Notify", src, "Erro", "Veículo inválido.", "vermelho", 5000)
        return
    end

    -- usa SEMPRE as coords reais do veículo (não as do payload)
    local vpos = GetEntityCoords(ent)
    local okZone = inAnyZone(vpos.x, vpos.y, vpos.z)
    if not okZone then
        TriggerClientEvent("Notify", src, "Erro", "O veículo não está numa zona de desmanche.", "vermelho", 5000)
        return
    end

    if CLASS_BLACKLIST[vclass] or MODEL_BLACKLIST[model] then
        TriggerClientEvent("Notify", src, "Erro", "Este tipo de veículo não pode ser desmanchado.", "vermelho", 6000)
        return
    end
    local range = rewardRange(vclass)
    if not range then
        TriggerClientEvent("Notify", src, "Erro", "Classe de veículo inválida para desmanche.", "vermelho", 6000)
        return
    end

    local realPlate = (GetVehicleNumberPlateText(ent) or "")
    local plateRaw  = (realPlate ~= "" and realPlate or plate)
    local plateUp   = plateUpper(plateRaw)
    local ownerPassport = getOwnerPassportByPlate(plateRaw)

    if BLOCK_OWNED_SELF and ownerPassport and ownerPassport == passport then
        TriggerClientEvent("Notify", src, "Erro", "Não podes desmanchar o teu próprio veículo.", "vermelho", 6000)
        return
    end

    -- confirmação do jogador
    PendingConfirm[passport] = true
    local ok = vRP.Request(src, REQUEST_TITLE, REQUEST_TEXT, REQUEST_YES, REQUEST_NO)
    PendingConfirm[passport] = nil
    if not ok then
        TriggerClientEvent("Notify", src, "Desmanche", "Ação <b>cancelada</b>.", "amarelo", 3000)
        return
    end

    -- chance de polícia com coords reais
    local chance = computePoliceChance(passport, src)
    if math.random() < chance then
        local x,y,z = vpos.x, vpos.y, vpos.z
        pcall(function()
            if exports["vrp"] and exports["vrp"].CallPolice then
                exports["vrp"]:CallPolice({
                    ["Source"]=src, ["Passport"]=passport, ["Permission"]="Policia",
                    ["Name"]="Desmanche em curso", ["Percentage"]=math.floor(chance*100),
                    ["Wanted"]=60, ["Code"]=31, ["Color"]=22,
                    ["Coords"]=vector3(x,y,z), ["x"]=x,["y"]=y,["z"]=z,
                    ["Vehicle"]=(model or "veiculo").." - "..plateUp
                })
            end
        end)
        TriggerClientEvent("Notify", src, "Polícia", ("Testemunhas chamaram a polícia (%.0f%%)."):format(chance*100), "azul", 6500)
    end

    Ongoing[passport] = {
        plateUp  = plateUp,
        plateRaw = plateRaw,
        netId    = netId,
        class    = vclass,
        rewardMin= range[1],
        rewardMax= range[2],
        model    = model,
        ownedBy  = ownerPassport
    }
    TriggerClientEvent("dismantle:Begin", src, { progress = PROGRESS_MS, forceExit = true })
end)

-- FINALIZAÇÃO
RegisterServerEvent("dismantle:Finish")
AddEventHandler("dismantle:Finish", function()
    local src = source
    local passport = vRP.Passport(src)
    if not passport then return end

    local st = Ongoing[passport]; if not st then return end
    local ent = NetworkGetEntityFromNetworkId(st.netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) or GetEntityType(ent) ~= 2 then
        Ongoing[passport] = nil
        TriggerClientEvent("Notify", src, "Erro", "Veículo inválido.", "vermelho", 5000)
        return
    end

    local pos = GetEntityCoords(ent)
    if not inAnyZone(pos.x, pos.y, pos.z) then
        Ongoing[passport] = nil
        TriggerClientEvent("Notify", src, "Erro", "O veículo saiu da zona de desmanche.", "vermelho", 5000)
        return
    end

    -- Dono apurado no :Confirm
    local ownerPassport = st.ownedBy

    -- Marca A-P-R-E-E-N-S-Ã-O
    local untilTime = os.time() + (IMPOUND_HOURS * 3600)

    -- (1) Por PLACA normalizada (garante que há sempre uma linha atualizada)
    vRP.Query("vehicles/arrestByPlateLike", {
        plate_norm = plateUpperNoSpace(st.plateUp),
        arrest     = untilTime
    })

    -- (2) Reforço por Passport+modelo (o que a garagem usa no select)
    if ownerPassport and ownerPassport ~= passport then
        vRP.Query("vehicles/arrestByOwnerModel", {
            Passport = ownerPassport,
            vehicle  = st.model,  -- já em lowercase
            arrest   = untilTime
        })
    end

    -- Limpezas e remoção
    do
        local Plates = GlobalState["Plates"] or {}
        if Plates[st.plateUp] then
            Plates[st.plateUp] = nil
            GlobalState.Plates = Plates
        end
        if Spawn and Spawn[st.plateUp] then
            Spawn[st.plateUp] = nil
        end

        TriggerClientEvent("garages:ForceDelete", -1, st.netId)
        TriggerEvent("SignalRemove", (st.plateRaw or st.plateUp):upper())
        TriggerEvent("garages:Delete", st.netId, st.plateRaw or st.plateUp)
    end

    DeleteEntity(ent)

    -- Recompensas / XP
    local baseReward  = computeReward(passport, st.rewardMin, st.rewardMax, src)
    local ownedBonus, impoundFeeBase = 0, 0
    if ownerPassport and ownerPassport ~= passport then
        local price = VehiclePrice(st.model)
        ownedBonus     = math.floor(price * OWNED_BONUS_PERCENT + 0.5)
        impoundFeeBase = math.floor(price * IMPOUND_FEE_PERCENT + 0.5)
    end
    local totalReward = baseReward + ownedBonus

    vRP.GenerateItem(passport, "dirtydollar", totalReward, true)
    vRP.PutExperience(passport, "Dismantle", xpGain(passport))
    if exports["pause"] and exports["pause"].AddPoints then
        exports["pause"]:AddPoints(passport, XP_BASE)
    end

    if ownerPassport and ownerPassport ~= passport then
        TriggerClientEvent("Notify", src, "Desmanche",
            ("Recebeste <b>$%s</b> sujo. (Base: $%s + Bónus Jogador: $%s)")
                :format(dotted(totalReward), dotted(baseReward), dotted(ownedBonus)),
            "verde", 8000)
    else
        TriggerClientEvent("Notify", src, "Desmanche",
            ("Recebeste <b>$%s</b> sujo. (Base NPC)"):format(dotted(totalReward)), "verde", 6000)
    end

    -- Logs
    local function log(msg)
        pcall(function()
            if exports["discord"] and exports["discord"].Embed then
                exports["discord"]:Embed(DISCORD_CHANNEL, msg, src)
            end
        end)
    end

    if ownerPassport and ownerPassport ~= passport then
        local msg = table.concat({
            "💥 **DESMANCHE – Veículo de Jogador**",
            "• Executor: **"..fullNameOr(passport).." (#"..passport..")**",
            "• Dono do veículo: **"..fullNameOr(ownerPassport).." (#"..ownerPassport..")**",
            "• Plate: **"..(st.plateRaw or st.plateUp).."**",
            "• Modelo: **"..(st.model or "desconhecido").."**",
            "• Classe: **"..tostring(st.class).."**",
            "• Preço estimado: $"..dotted(VehiclePrice(st.model)),
            "• Bónus Jogador: **"..math.floor(OWNED_BONUS_PERCENT*100).."%** → $**"..dotted(ownedBonus).."**",
            "• Taxa base apreensão: **"..math.floor(IMPOUND_FEE_PERCENT*100).."%** → $**"..dotted(impoundFeeBase).."**",
            "• Recompensa base: $**"..dotted(baseReward).."**",
            "• Total ganho: $**"..dotted(totalReward).."**",
            ("• Local: %.2f, %.2f, %.2f"):format(pos.x, pos.y, pos.z),
            "• Data/Hora: "..os.date("%d/%m/%Y %H:%M:%S")
        },"\n")
        log(msg)
    else
        local msg = table.concat({
            "💥 **DESMANCHE – Veículo NPC**",
            "• Executor: **"..fullNameOr(passport).." (#"..passport..")**",
            "• Plate: **"..(st.plateRaw or st.plateUp).."**",
            "• Modelo: **"..(st.model or "desconhecido").."**",
            "• Classe: **"..tostring(st.class).."**",
            "• Valor ganho: $**"..dotted(totalReward).."**",
            ("• Local: %.2f, %.2f, %.2f"):format(pos.x, pos.y, pos.z),
            "• Data/Hora: "..os.date("%d/%m/%Y %H:%M:%S")
        },"\n")
        log(msg)
    end

    Cooldown[passport] = os.time() + COOLDOWN_SECONDS
    Ongoing[passport]  = nil
end)
