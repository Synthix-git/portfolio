-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP / TUNNEL
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP          = Proxy.getInterface("vRP")

Creative = {}
Tunnel.bindInterface("tractor", Creative)

-----------------------------------------------------------------------------------------------------------------------------------------
-- BUFFS
-----------------------------------------------------------------------------------------------------------------------------------------
Buffs = Buffs or {}
Buffs["Dexterity"] = Buffs["Dexterity"] or {}

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS
-----------------------------------------------------------------------------------------------------------------------------------------
local function getLevel(passport)
    local xp = tonumber(vRP.GetExperience(passport, "Tractor")) or 0
    if ClassCategory then
        local ok, lvl = pcall(ClassCategory, xp)
        if ok and lvl then return tonumber(lvl) or 0 end
    end
    return math.floor(math.sqrt(xp / 120))
end

local function vipMultiplier(src, passport)
    if not passport then return 1.0 end
    if not vRP.HasGroup(passport,"Premium") then return 1.0 end

    local lvl = vRP.LevelPremium(src) or 1
    if lvl == 1 then
        return 1.25 -- Ouro
    elseif lvl == 2 then
        return 1.15 -- Prata
    elseif lvl == 3 then
        return 1.10 -- Bronze
    end
    return 1.0
end

local function applyBuffAndVip(src, passport, amount)
    local final = amount

    -- Buff +10%
    if Buffs["Dexterity"][passport] and Buffs["Dexterity"][passport] > os.time() then
        final = final * 1.10
    end

    -- VIP
    final = final * vipMultiplier(src, passport)

    return math.floor(final + 0.5)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- PAYMENT POR PONTO — 200$ base por marker
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.PaymentPoint()
    local src = source
    local passport = vRP.Passport(src)
    if not passport then return end

    local level = getLevel(passport)

    local base  = 200
    local extra = level * 5
    local total = applyBuffAndVip(src, passport, base + extra)

    vRP.PutExperience(passport, "Tractor", 1)
    vRP.GenerateItem(passport, "dollar", total, true)

    TriggerEvent("inventory:BuffServer", src, passport, "Dexterity", total)
    TriggerClientEvent("Notify", src, "Tratorista", "Recebeste <b>$"..total.."</b> pelo checkpoint.", "verde", 4000)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- PAYMENT FINAL — bónus total por nível (apenas no fim da rota)
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.PaymentFinal()
    local src = source
    local passport = vRP.Passport(src)
    if not passport then return end

    local level = getLevel(passport)

    -- Bónus escalado pelo nível
    local bonus = 400 + (level * 120)
    bonus = applyBuffAndVip(src, passport, bonus)

    vRP.PutExperience(passport, "Tractor", 2)
    vRP.GenerateItem(passport, "dollar", bonus, true)

    TriggerEvent("inventory:BuffServer", src, passport, "Dexterity", bonus)
    TriggerClientEvent("Notify", src, "Tratorista", "Bónus final de rota: <b>$"..bonus.."</b>.", "verde", 5000)

    -- logs opcionais
    -- exports["discord"]:Embed("Trabalhos",
    --     ("**Tratorista**\n👤 Passaporte: **%d**\n💰 Bónus Final: **$%d**\n⭐ Nível: **%d**"):format(passport, bonus, level), src)
end
