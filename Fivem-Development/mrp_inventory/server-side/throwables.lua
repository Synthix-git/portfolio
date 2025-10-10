-------------------------------------------------
-- Throwable -> Consumo por item no SERVER
-- Autor: Synthix (fix: anti-duplo consumo)
-------------------------------------------------

local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP          = Proxy.getInterface("vRP")

-- mapeia NOME DA ARMA -> CHAVE DO ITEM (a CHAVE do teu Items.lua)
local THROWABLE_ITEM = {
    WEAPON_BRICK        = "WEAPON_BRICK",
    WEAPON_SNOWBALL     = "WEAPON_SNOWBALL",
    WEAPON_SHOES        = "WEAPON_SHOES",
    WEAPON_MOLOTOV      = "WEAPON_MOLOTOV",
    WEAPON_SMOKEGRENADE = "WEAPON_SMOKEGRENADE"
}

-- util: normaliza quantidade (bases variam)
local function qty(x)
    if type(x) == "number" then return x end
    if type(x) == "table" then
        return tonumber(x.amount or x.qtd or x.count or x.value or x[1]) or 0
    end
    return tonumber(x) or 0
end

-- adapter: remove 1 item e retorna boolean
local function TakeOne(Passport, itemId)
    if vRP.TakeItem then
        return vRP.TakeItem(Passport, itemId, 1, true) == true
    end
    if vRP.RemoveItem then
        return vRP.RemoveItem(Passport, itemId, 1, true) == true
    end
    if vRP.TryGetItem then
        return vRP.TryGetItem(Passport, itemId, 1, true) == true
    end
    return false
end

--  ANTI-DUPLO: Debounce e Snapshot 
-- por source+arma: ignora eventos dentro da janela (ms)
local _lastConsumeAt = {}   -- [src] = { [weaponName] = gameTimerMs }
local _lastCount     = {}   -- [passport] = { [itemId] = quantidade }

local function debounced(src, weaponName, ms)
    local now = GetGameTimer()
    _lastConsumeAt[src] = _lastConsumeAt[src] or {}
    local last = _lastConsumeAt[src][weaponName] or 0
    if (now - last) < (ms or 500) then
        return true
    end
    _lastConsumeAt[src][weaponName] = now
    return false
end

-- Consumir 1 unidade ao arremessar
RegisterNetEvent("inventory:consumeThrowable")
AddEventHandler("inventory:consumeThrowable", function(weaponName)
    local src = source
    local Passport = vRP.Passport(src); if not Passport then return end
    if type(weaponName) ~= "string" then return end

    local itemId = THROWABLE_ITEM[weaponName]
    if not itemId then
        TriggerClientEvent("inventory:enforceThrowable", src, weaponName, 0, true)
        return
    end

    -- Debounce por fonte+arma
    if debounced(src, weaponName, 500) then
        return
    end

    -- Snapshot: evita segunda remoção se dois eventos chegarem antes do inventário atualizar
    _lastCount[Passport] = _lastCount[Passport] or {}
    local before = qty(vRP.InventoryItemAmount(Passport, itemId))

    if before <= 0 then
        TriggerClientEvent("inventory:enforceThrowable", src, weaponName, 0, true)
        _lastCount[Passport][itemId] = 0
        return
    end

    -- Se já processámos um consumo e o count não mudou, permite um (primeiro) consumo
    -- Se já diminuiu desde o último snapshot, ignora (já foi consumido)
    local lastSnap = tonumber(_lastCount[Passport][itemId] or before)
    if before < lastSnap then
        -- já houve remoção registrada: não consome novamente
        TriggerClientEvent("inventory:setThrowableAmmo", src, weaponName, before)
        return
    end

    -- Remove 1
    local ok = TakeOne(Passport, itemId)
    local after = qty(vRP.InventoryItemAmount(Passport, itemId))

    -- Atualiza snapshot
    _lastCount[Passport][itemId] = after

    if ok then
        TriggerClientEvent("inventory:setThrowableAmmo", src, weaponName, after)
    else
        -- Falhou remover? Força zero para cortar exploit
        TriggerClientEvent("inventory:enforceThrowable", src, weaponName, 0, true)
        _lastCount[Passport][itemId] = 0
    end
end)

-- Sincroniza munição do arremessável ao equipar/entrar no servidor
RegisterNetEvent("inventory:requestThrowableAmmo")
AddEventHandler("inventory:requestThrowableAmmo", function(weaponName)
    local src = source
    local Passport = vRP.Passport(src); if not Passport then return end
    if type(weaponName) ~= "string" then return end

    local itemId = THROWABLE_ITEM[weaponName]
    if not itemId then
        TriggerClientEvent("inventory:enforceThrowable", src, weaponName, 0, true)
        return
    end

    local amount = qty(vRP.InventoryItemAmount(Passport, itemId))
    _lastCount[Passport] = _lastCount[Passport] or {}
    _lastCount[Passport][itemId] = amount

    if amount <= 0 then
        TriggerClientEvent("inventory:enforceThrowable", src, weaponName, 0, true)
    else
        TriggerClientEvent("inventory:setThrowableAmmo", src, weaponName, amount)
    end
end)

-- Limpeza de snapshots em disconnect (boa prática)
AddEventHandler("Disconnect", function(Passport)
    if _lastCount[Passport] then _lastCount[Passport] = nil end
end)
