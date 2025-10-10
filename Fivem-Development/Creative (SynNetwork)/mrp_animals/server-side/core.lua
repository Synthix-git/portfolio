-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRPC         = Tunnel.getInterface("vRP")
vRP          = Proxy.getInterface("vRP")

-----------------------------------------------------------------------------------------------------------------------------------------
-- REGISTRY (1 PET por PASSAPORTE) + PENDING CLONE (arma)
-----------------------------------------------------------------------------------------------------------------------------------------
local Animals = {}      -- [passport] = netId
local PendingClone = {} -- [requesterSrc] = weaponHash

RegisterNetEvent("animals:Animals")
AddEventHandler("animals:Animals", function(netId)
    local src = source
    local passport = vRP.Passport(src)
    if not passport or not netId then return end
    Animals[passport] = tonumber(netId)
end)

RegisterNetEvent("animals:Delete")
AddEventHandler("animals:Delete", function()
    local src = source
    local passport = vRP.Passport(src)
    if not passport then return end

    local netId = Animals[passport]
    if netId then
        TriggerClientEvent("animals:DeleteNet", -1, netId)
    end
    Animals[passport] = nil
end)

AddEventHandler("Disconnect", function(passport)
    local netId = Animals[passport]
    if netId then
        TriggerClientEvent("animals:DeleteNet", -1, netId)
        Animals[passport] = nil
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- BROADCAST APARÊNCIA
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("animals:BroadcastAppearance")
AddEventHandler("animals:BroadcastAppearance", function(netId, data)
    if not netId or not data then return end
    TriggerClientEvent("animals:ApplyAppearanceNet", -1, netId, data)
end)

-- client-side handler compat (não precisa fazer nada aqui, apenas garantir evento existe)
RegisterNetEvent("animals:ApplyAppearanceNet")

-----------------------------------------------------------------------------------------------------------------------------------------
-- ONLINE → alvo envia aparência -> server -> staff (com arma)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("animals:ReturnAppearance")
AddEventHandler("animals:ReturnAppearance", function(requesterSrc, data)
    if not requesterSrc or not data then return end
    local weaponHash = PendingClone[requesterSrc] or 0
    PendingClone[requesterSrc] = nil
    data.weaponHash = weaponHash
    TriggerClientEvent("animals:CloneByAppearance", requesterSrc, data)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS DB (OFFLINE)
-----------------------------------------------------------------------------------------------------------------------------------------
local function safeDecode(val)
    if not val then return nil end
    if type(val) == "table" then return val end
    if type(val) == "string" and val ~= "" then
        local ok, t = pcall(json.decode, val)
        if ok and type(t) == "table" then return t end
    end
    return nil
end

local function readBarberFromDB(passport)
    local ok, data = pcall(vRP.UserData, passport, "Barbershop")
    local t = ok and safeDecode(data) or nil
    if t then return t end

    local rows = vRP.Query("playerdata/GetData", { Passport = passport, Name = "Barbershop" })
    if rows and rows[1] then
        return safeDecode(rows[1].Information)
    end
    return nil
end

local function guessModelFromProfile(profile)
    if profile and profile.model then return profile.model end
    local gender = (profile and (profile.gender or profile.sex)) and tostring(profile.gender or profile.sex):lower() or ""
    if gender:find("f") then return `mp_f_freemode_01` end
    return `mp_m_freemode_01`
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- UTILS
-----------------------------------------------------------------------------------------------------------------------------------------
local function toWeaponHash(arg)
    if not arg or arg == "" then return 0 end
    local w = arg
    if w:lower() ~= "unarmed" and not w:upper():find("^WEAPON_") then
        w = "WEAPON_"..w:upper()
    else
        w = w:upper()
    end
    local hash = GetHashKey(w)
    if hash == 0 then return 0 end
    return hash
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- COMANDOS (ADMIN NÍVEL 1)
-----------------------------------------------------------------------------------------------------------------------------------------
-- /pet MODEL [WEAPON_*]
RegisterCommand("pet", function(source, args)
    local passport = vRP.Passport(source); if not passport then return end
    if not vRP.HasPermission(passport,"Admin",1) then
        TriggerClientEvent("Notify", source, "Animais", "Sem permissão para <b>/pet</b>.", "vermelho", 5000)
        return
    end

    local model = tostring(args[1] or "")
    if model == "" then
        TriggerClientEvent("Notify", source, "Uso", "Uso: <b>/pet MODEL</b> ou <b>/pet MODEL WEAPON_*</b>.", "amarelo", 7000)
        return
    end

    local weaponHash = toWeaponHash(args[2])
    TriggerClientEvent("animals:SpawnAnyPed", source, model, weaponHash)
end)

-- /clonepet PASSAPORTE [WEAPON_*] (ONLINE e OFFLINE)
RegisterCommand("clonepet", function(source, args)
    local passport = vRP.Passport(source); if not passport then return end
    if not vRP.HasPermission(passport, "Admin", 1) then
        TriggerClientEvent("Notify", source, "Admin", "Sem permissão para <b>/clonepet</b>.", "vermelho", 5000)
        return
    end

    local targetPassport = tonumber(args[1] or "")
    if not targetPassport then
        TriggerClientEvent("Notify", source, "Uso", "Uso: <b>/clonepet PASSAPORTE</b> ou <b>/clonepet PASSAPORTE WEAPON_*</b>.", "amarelo", 7000)
        return
    end

    local weaponHash = toWeaponHash(args[2])
    local targetSrc = vRP.Source(targetPassport)

    if targetSrc then
        PendingClone[source] = weaponHash
        TriggerClientEvent("animals:CollectAppearance", targetSrc, source)
        return
    end

    local profile = readBarberFromDB(targetPassport)
    if not profile then
        TriggerClientEvent("Notify", source, "Admin", "Sem dados de aparência guardados (Barbershop).", "amarelo", 6000)
        return
    end

    local data = {
        model         = profile.model or guessModelFromProfile(profile),
        components    = profile.components or profile.Components,
        props         = profile.props or profile.Props,
        hairColor     = profile.hairColor or profile.HairColor,
        hairHighlight = profile.hairHighlight or profile.HairHighlight,
        overlays      = profile.overlays or profile.Overlays,
        headBlend     = profile.headBlend or profile.HeadBlend,
        faceFeatures  = profile.faceFeatures or profile.FaceFeatures,
        weaponHash    = weaponHash
    }
    if not data.components and profile.drawables then
        data.components = {}
        for comp=0,11 do
            data.components[comp] = {
                drawable = (profile.drawables[comp] or 0),
                texture  = (profile.textures  and profile.textures[comp]  or 0),
                palette  = (profile.palettes  and profile.palettes[comp]  or 0)
            }
        end
    end

    TriggerClientEvent("animals:CloneByAppearance", source, data)
end)
