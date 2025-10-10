-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRPC         = Tunnel.getInterface("vRP")
vRP          = Proxy.getInterface("vRP")

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONFIG
-----------------------------------------------------------------------------------------------------------------------------------------
local XP_TRACK        = "Farmer"
local XP_PER_ACTION   = 8
local LEVEL_QUANTITY  = 0.05 -- +5% por nível
local COOLDOWN_POINT  = 25   -- segundos

local FRUITS = { "acerola","banana","tomato","passion","grape","tange","orange","apple","strawberry" }

local Points = {
    vec3(2328.88,5037.48,44.50), vec3(2317.06,5023.74,43.34), vec3(2304.50,4997.42,42.34),
    vec3(2316.42,5008.97,42.55), vec3(2329.84,5022.02,42.93), vec3(2341.58,5035.42,44.35),
    vec3(2343.40,5023.07,43.53), vec3(2330.64,5008.16,42.38), vec3(2316.69,4994.66,42.08),
    vec3(2317.34,4984.96,41.82), vec3(2331.18,4996.83,42.14), vec3(2344.07,5008.24,42.74),
    vec3(2356.67,5021.07,43.89), vec3(2376.12,5017.25,45.43), vec3(2369.10,5011.47,44.35),
    vec3(2360.19,5002.92,43.40), vec3(2349.17,4989.89,43.04), vec3(2335.94,4976.43,42.61),
    vec3(2348.82,4976.08,42.76), vec3(2361.22,4989.10,43.31), vec3(2377.16,5004.32,44.59),
    vec3(2389.36,5004.97,45.74), vec3(2389.64,4992.76,45.17), vec3(2373.69,4989.28,43.99),
    vec3(2361.40,4976.76,43.23)
}

local NextReady = {} -- [idx] = unix time quando volta a estar pronto

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS
-----------------------------------------------------------------------------------------------------------------------------------------
local function vipMult(src, passport)
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

local function nearestPointIndex(coords, maxDist)
    local idx, best = nil, nil
    for i,pt in ipairs(Points) do
        local d = #(coords - pt)
        if d <= maxDist and (not best or d < best) then
            idx, best = i, d
        end
    end
    return idx
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- EVENTO: COLHER
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("farmer:tryPick")
AddEventHandler("farmer:tryPick", function()
    local src = source
    local passport = vRP.Passport(src)
    if not passport then return end

    local coords = vRP.GetEntityCoords(src)
    if not coords then return end

    local idx = nearestPointIndex(coords, 1.6)
    if not idx then return end

    local now = os.time()
    if (NextReady[idx] or 0) > now then return end

    -- fruto + quantidade com multiplicadores de nível/VIP
    local item       = FRUITS[math.random(#FRUITS)]
    local baseAmount = math.random(3,5)

    local exp   = tonumber(vRP.GetExperience(passport, XP_TRACK)) or 0
    local level = (type(ClassCategory) == "function" and tonumber(ClassCategory(exp))) or 0
    if level < 0 then level = 0 end

    local qtyMult = (1.0 + level * LEVEL_QUANTITY) * vipMult(src, passport)
    local amount  = math.max(1, math.floor(baseAmount * qtyMult + 0.0001))

    -- recompensa imediata
    vRP.GenerateItem(passport, item, amount, true)

    -- XP (sem VIP extra no XP, só no item colhido)
    vRP.PutExperience(passport, XP_TRACK, XP_PER_ACTION)
    if exports["pause"] and exports["pause"].AddPoints then
        exports["pause"]:AddPoints(passport, XP_PER_ACTION)
    end

    -- cooldown
    NextReady[idx] = now + COOLDOWN_POINT
    TriggerClientEvent("farmer:setPointCD", -1, idx, NextReady[idx])
end)
