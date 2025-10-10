-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp", "lib/Tunnel")
local Proxy  = module("vrp", "lib/Proxy")
vRP = Proxy.getInterface("vRP")

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONFIG
-----------------------------------------------------------------------------------------------------------------------------------------
local XP_TRACK        = "Mine"   -- trilha de XP
local XP_PER_ACTION   = 10       -- xp por mineração concluída
local LEVEL_WEIGHT    = 0.05     -- +5% de chance em raros por nível
local LEVEL_QUANTITY  = 0.05     -- +5% de quantidade por nível
local MISS_CHANCE     = 0        -- 0 = SEMPRE dropa algo; >0 chance de falhar (ex.: 15)

-- Tabela de drops com pesos base (chance relativa). Só 1 será escolhido.
local drops = {
    { item = "iron_pure",     min = 1, max = 5, weight = 30, rare = false },
    { item = "copper_pure",   min = 1, max = 5, weight = 25, rare = false },
    { item = "lead_pure",     min = 1, max = 5, weight = 20, rare = false },
    { item = "tin_pure",      min = 1, max = 5, weight = 20, rare = false },
    { item = "sapphire_pure", min = 1, max = 2, weight = 5,  rare = true  },
    { item = "emerald_pure",  min = 1, max = 2, weight = 5,  rare = true  },
    { item = "ruby_pure",     min = 1, max = 2, weight = 3,  rare = true  },
    { item = "gold_pure",     min = 1, max = 2, weight = 3,  rare = true  },
    { item = "diamond_pure",  min = 1, max = 2, weight = 1,  rare = true  }
}

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS
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

-- ajusta o peso dos ITENS RAROS com base no nível de mineração + VIP
local function adjustedWeight(entry, levelMult, vipMult)
    if entry.rare then
        return entry.weight * levelMult * vipMult
    end
    return entry.weight
end

local function pickWeightedOne(list, levelMult, vipMult)
    local total = 0
    for _, d in ipairs(list) do
        total = total + adjustedWeight(d, levelMult, vipMult)
    end
    if total <= 0 then return nil end

    local r, acc = math.random() * total, 0
    for _, d in ipairs(list) do
        acc = acc + adjustedWeight(d, levelMult, vipMult)
        if r <= acc then return d end
    end
    return list[#list]
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- EVENTO: recompensa de mineração (apenas 1 item, com boosts)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("minerar:recompensa")
AddEventHandler("minerar:recompensa", function(mult)
    local src = source
    local passport = vRP.Passport(src)
    if not passport then return end

    mult = tonumber(mult) or 1

    -- chance de falhar totalmente
    if MISS_CHANCE > 0 and math.random(100) <= MISS_CHANCE then
        TriggerClientEvent("Notify", src, "Mineração", "Não encontraste nenhum minério desta vez!", "amarelo", 3000)
        return
    end

    -- nível atual do jogador em mineração
    local exp   = vRP.GetExperience(passport, XP_TRACK)
    local level = ClassCategory(exp) or 1

    -- multiplicadores
    local vipMult    = vipLevelMult(src, passport)                           -- VIP Ouro/Prata/Bronze
    local levelWMult = 1.0 + (level * LEVEL_WEIGHT)                          -- afeta chance de raros
    local levelQMult = 1.0 + (level * LEVEL_QUANTITY)                        -- afeta quantidade
    local qtyMult    = mult * levelQMult * vipMult                           -- multiplicador de quantidade final

    -- escolhe UM drop ponderado (pesando mais os raros conforme nível/VIP)
    local choice = pickWeightedOne(drops, levelWMult, vipMult)
    if not choice then
        TriggerClientEvent("Notify", src, "Mineração", "Não encontraste nenhum minério desta vez!", "amarelo", 3000)
        return
    end

    -- quantidade final
    local baseAmount = math.random(choice.min, choice.max)
    local amount = math.max(1, math.floor(baseAmount * qtyMult + 0.0001))

    vRP.GenerateItem(passport, choice.item, amount, true)

    -- XP + Pontos do Pause
    vRP.PutExperience(passport, XP_TRACK, XP_PER_ACTION)
    if exports["pause"] and exports["pause"].AddPoints then
        exports["pause"]:AddPoints(passport, XP_PER_ACTION)
    end
end)
