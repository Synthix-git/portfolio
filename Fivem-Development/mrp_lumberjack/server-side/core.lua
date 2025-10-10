-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONFIG
-----------------------------------------------------------------------------------------------------------------------------------------
local XP_TRACK        = "Lumberman"   -- trilha de XP
local XP_PER_ACTION   = 3             -- XP por corte
local LEVEL_QUANTITY  = 0.05          -- +5% quantidade por nível
local MISS_CHANCE     = 0             -- 0 = sem falha

-- Drops possíveis
local drops = {
    { item = "woodlog", min = 2, max = 4 }
}

-----------------------------------------------------------------------------------------------------------------------------------------
-- VIP MULTIPLIER
-----------------------------------------------------------------------------------------------------------------------------------------
local function vipLevelMult(source, passport)
    if not passport then return 1.0 end
    if not vRP.HasGroup(passport,"Premium") then return 1.0 end

    local lvl = vRP.LevelPremium(source) or 1
    if lvl == 1 then
        return 1.25 -- Ouro
    elseif lvl == 2 then
        return 1.15 -- Prata
    elseif lvl == 3 then
        return 1.10 -- Bronze
    end
    return 1.0
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- RECOMPENSA
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("lumberman:recompensa")
AddEventHandler("lumberman:recompensa", function(mult)
    local src = source
    local passport = vRP.Passport(src)
    if not passport then return end

    mult = tonumber(mult) or 1

    -- chance de falha
    if MISS_CHANCE > 0 and math.random(100) <= MISS_CHANCE then
        TriggerClientEvent("Notify", src, "Lenhador", "Não encontraste madeira desta vez.", "amarelo", 3000)
        return
    end

    -- nível atual do jogador
    local exp   = vRP.GetExperience(passport, XP_TRACK) or 0
    local level = (type(ClassCategory) == "function" and ClassCategory(exp)) or math.floor(math.sqrt((exp or 0)/100))
    level = tonumber(level) or 0

    -- multiplicadores
    local vipMult    = vipLevelMult(src, passport)
    local levelQMult = 1.0 + (level * LEVEL_QUANTITY)
    local qtyMult    = mult * levelQMult * vipMult

    -- aplica drops
    for _,d in ipairs(drops) do
        local baseAmount = math.random(d.min, d.max)
        local amount = math.max(1, math.floor(baseAmount * qtyMult + 0.0001))
        vRP.GenerateItem(passport, d.item, amount, true)
    end

    -- XP + Pontos
    if vRP.PutExperience then
        vRP.PutExperience(passport, XP_TRACK, XP_PER_ACTION)
    else
        vRP.AddExperience(passport, XP_TRACK, XP_PER_ACTION)
    end

    if exports["pause"] and exports["pause"].AddPoints then
        exports["pause"]:AddPoints(passport, XP_PER_ACTION)
    end
end)
