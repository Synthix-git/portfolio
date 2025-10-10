-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
cRP = {}
Tunnel.bindInterface("mrp_vroupas",cRP)
vSERVER = Tunnel.getInterface("mrp_vroupas")

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS (ORIGINAIS + SKINSHOPINIT)
-----------------------------------------------------------------------------------------------------------------------------------------
local function getModelKey(ped)
    local model = GetEntityModel(ped)
    if model == GetHashKey("mp_m_freemode_01") then
        return "mp_m_freemode_01"
    elseif model == GetHashKey("mp_f_freemode_01") then
        return "mp_f_freemode_01"
    end
    return "mp_m_freemode_01"
end

local function comp3(ped, compId)
    local draw = GetPedDrawableVariation(ped, compId) or 0
    local tex  = GetPedTextureVariation(ped, compId) or 0
    local pal  = 0
    if DoesEntityExist(ped) then
        pal = GetPedPaletteVariation(ped, compId) or 0
    end
    return { draw or 0, tex or 0, pal or 0 }
end

local function prop2(ped, propId)
    local draw = GetPedPropIndex(ped, propId)
    local tex  = 0
    if draw == -1 then
        tex = 0
    else
        tex = GetPedPropTextureIndex(ped, propId) or 0
    end
    return { draw or -1, tex or 0 }
end

-- Snapshot "original" (para manter a tua NUI a funcionar igual)
local ORDERED_KEYS = {
    "gender","bodyArmors","torsos","accessories","hats","masks","undershirts",
    "shoes","bracelets","tops","bags","ears","decals","legs","watches","glasses"
}

local function getGenderFromModel(ped)
    local model = GetEntityModel(ped)
    if model == GetHashKey("mp_m_freemode_01") then
        return "male"
    elseif model == GetHashKey("mp_f_freemode_01") then
        return "female"
    end
    return "male"
end

local function buildOutfitSnapshot()
    local ped = PlayerPedId()
    local outfit = {
        gender       = getGenderFromModel(ped),
        bodyArmors   = comp3(ped, 9),
        torsos       = comp3(ped, 3),
        accessories  = comp3(ped, 7),
        hats         = prop2(ped, 0),
        masks        = comp3(ped, 1),
        undershirts  = comp3(ped, 8),
        shoes        = comp3(ped, 6),
        bracelets    = prop2(ped, 4),
        tops         = comp3(ped, 11),
        bags         = comp3(ped, 5),
        ears         = prop2(ped, 2),
        decals       = comp3(ped, 10),
        legs         = comp3(ped, 4),
        watches      = prop2(ped, 3),
        glasses      = prop2(ped, 1)
    }
    return outfit
end

-- Snapshot no formato SkinshopInit
local function compSkin(ped, compId)
    local draw = GetPedDrawableVariation(ped, compId) or 0
    local tex  = GetPedTextureVariation(ped, compId) or 0
    return { item = draw, texture = tex }
end

local function propSkin(ped, propId)
    local draw = GetPedPropIndex(ped, propId)
    if draw == -1 then
        return { item = -1, texture = 0 }
    end
    local tex = GetPedPropTextureIndex(ped, propId) or 0
    return { item = draw or -1, texture = tex }
end

local function buildSkinshopInitForCurrentPed()
    local ped = PlayerPedId()
    local modelKey = getModelKey(ped)
    local block = {
        [modelKey] = {
            ["pants"]     = compSkin(ped, 4),
            ["arms"]      = compSkin(ped, 3),
            ["tshirt"]    = compSkin(ped, 8),
            ["torso"]     = compSkin(ped, 11),
            ["vest"]      = compSkin(ped, 9),
            ["shoes"]     = compSkin(ped, 6),
            ["mask"]      = compSkin(ped, 1),
            ["backpack"]  = compSkin(ped, 5),
            ["hat"]       = propSkin(ped, 0),
            ["glass"]     = propSkin(ped, 1),
            ["ear"]       = propSkin(ped, 2),
            ["watch"]     = propSkin(ped, 3),
            ["bracelet"]  = propSkin(ped, 4),
            ["accessory"] = compSkin(ped, 7),
            ["decals"]    = compSkin(ped, 10),
        }
    }
    return block
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- FORMATADORES (mantendo a NUI original: outfit + luaBlock + jsonBlock)
-----------------------------------------------------------------------------------------------------------------------------------------
local function toSkinshopInitLua(block)
    local function pair(k, v)
        return string.format('\t\t["%s"] = { item = %d, texture = %d },', k, tonumber(v.item) or 0, tonumber(v.texture) or 0)
    end

    local lines = {}
    lines[#lines+1] = "Roupas = {"
    for model, data in pairs(block) do
        lines[#lines+1] = string.format('\t["%s"] = {', model)
        lines[#lines+1] = pair("pants",     data["pants"])
        lines[#lines+1] = pair("arms",      data["arms"])
        lines[#lines+1] = pair("tshirt",    data["tshirt"])
        lines[#lines+1] = pair("torso",     data["torso"])
        lines[#lines+1] = pair("vest",      data["vest"])
        lines[#lines+1] = pair("shoes",     data["shoes"])
        lines[#lines+1] = pair("mask",      data["mask"])
        lines[#lines+1] = pair("backpack",  data["backpack"])
        lines[#lines+1] = pair("hat",       data["hat"])
        lines[#lines+1] = pair("glass",     data["glass"])
        lines[#lines+1] = pair("ear",       data["ear"])
        lines[#lines+1] = pair("watch",     data["watch"])
        lines[#lines+1] = pair("bracelet",  data["bracelet"])
        lines[#lines+1] = pair("accessory", data["accessory"])
        lines[#lines+1] = pair("decals",    data["decals"])
        lines[#lines+1] = "\t},"
    end
    lines[#lines+1] = "}"
    return table.concat(lines, "\n")
end

local function toJsonPretty(block)
    return json.encode(block, { indent = true })
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- UI / COMANDO (mantendo a mesma NUI e callbacks)
-----------------------------------------------------------------------------------------------------------------------------------------
local function openWardrobeUI()
    -- Mantém o snapshot "outfit" original para a tua NUI
    local outfit      = buildOutfitSnapshot()

    -- Mas gera o texto no formato SkinshopInit (é isto que vais copiar)
    local skinBlock   = buildSkinshopInitForCurrentPed()
    local luaBlock    = toSkinshopInitLua(skinBlock)
    local jsonBlock   = toJsonPretty(skinBlock)

    -- IMPORTANTE: usar exatamente as mesmas chaves/action da tua UI original
    SendNUIMessage({
        action = "open",
        payload = {
            outfit   = outfit,    -- mantém compat
            luaBlock = luaBlock,  -- agora no formato SkinshopInit
            jsonBlock = jsonBlock -- idem (apenas conveniência)
        }
    })
    SetNuiFocus(true, true)
end

RegisterCommand("vroupas", function()
    openWardrobeUI()
end)

RegisterNUICallback("close", function(_, cb)
    SetNuiFocus(false, false)
    cb("ok")
end)

RegisterNUICallback("requestOutfit", function(_, cb)
    local outfit    = buildOutfitSnapshot()
    local skinBlock = buildSkinshopInitForCurrentPed()
    local luaBlock  = toSkinshopInitLua(skinBlock)
    local jsonBlock = toJsonPretty(skinBlock)
    cb({ outfit = outfit, luaBlock = luaBlock, jsonBlock = jsonBlock })
end)
