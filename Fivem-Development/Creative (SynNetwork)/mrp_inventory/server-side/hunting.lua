-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRPC         = Tunnel.getInterface("vRP")
vRP          = Proxy.getInterface("vRP")
vCLIENT      = Tunnel.getInterface("inventory") -- client do inventário

-----------------------------------------------------------------------------------------------------------------------------------------
-- STATE
-----------------------------------------------------------------------------------------------------------------------------------------
local Active = {}         -- [Passport] = os.time()+X
local NetLocks = {}       -- [netId_str] = Passport
local PassportToNet = {}  -- [Passport] = netId_str

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS
-----------------------------------------------------------------------------------------------------------------------------------------
local function ClearNetLockByPassport(passport)
    local net = PassportToNet[passport]
    if net then
        NetLocks[net] = nil
        PassportToNet[passport] = nil
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- CLEANUP ON DROP
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("playerDropped", function()
    local src = source
    local pass = vRP.Passport(src)
    if not pass then return end
    ClearNetLockByPassport(pass)
    Active[pass] = nil
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- CANCEL MANUAL
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("inventory:CancelSkin")
AddEventHandler("inventory:CancelSkin", function(data)
    local src = source
    local Passport = vRP.Passport(src)
    if not Passport then return end
    Active[Passport] = nil
    ClearNetLockByPassport(Passport)
    if type(data) == "table" and data.net then
        NetLocks[tostring(data.net)] = nil
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- ANIMALS (SKIN)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("inventory:Animals")
AddEventHandler("inventory:Animals", function(data)
    local src = source
    local Passport = vRP.Passport(src)
    if not Passport then return end
    if Active[Passport] then
        TriggerClientEvent("Notify", src, "Aviso", "Você já está a esfolar algo.", "amarelo", 4000)
        return
    end

    if type(data) ~= "table" then return end
    local netId = data.net
    if not netId then return end
    local netKey = tostring(netId)

    -- lock por carcaça
    if NetLocks[netKey] then
        TriggerClientEvent("Notify", src, "Aviso", "Esta carcaça já está a ser esfolada por outro jogador.", "amarelo", 4500)
        return
    end

    -- precisa do canivete em mãos
    if not vCLIENT.IsSelectedWeapon(src, "WEAPON_SWITCHBLADE") then
        TriggerClientEvent("Notify", src, "Atenção", "Você precisa do <b>Canivete</b> em mãos.", "amarelo", 5000)
        TriggerClientEvent("inventory:ActionLock", src, false)
        return
    end

    -- peso
    if not vRP.InventoryWeight(Passport, "deer1star") then
        TriggerClientEvent("Notify", src, "Aviso", "Mochila sobrecarregada.", "amarelo", 5000)
        TriggerClientEvent("inventory:ActionLock", src, false)
        return
    end

    -- regista lock
    NetLocks[netKey] = Passport
    PassportToNet[Passport] = netKey
    Active[Passport] = os.time() + 15
    Player(src)["state"]["Buttons"] = true

    -- feedback
    TriggerClientEvent("Notify", src, "Hunting", "A esfolar a carcaça...", "verde", 15000)
    TriggerClientEvent("Progress", src, "Esfolando", 15000)
    vRPC.playAnim(src, false, { "amb@medic@standing@kneel@base", "base" }, true)
    vRPC.playAnim(src, true,  { "anim@gangops@facility@servers@bodysearch@", "player_search" }, true)

    -- thread de conclusão
    CreateThread(function()
        local finished = false
        while Active[Passport] do
            if os.time() >= Active[Passport] then
                finished = true
                break
            end
            Wait(100)
        end

        Active[Passport] = nil
        Player(src)["state"]["Buttons"] = false
        vRPC.Destroy(src)

        if finished then
            local Star = math.random(3)
            vRP.UpgradeStress(Passport, Star)
            exports["pause"]:AddPoints(Passport, 1)
            vRP.PutExperience(Passport, "Hunting", 10)

            local Mode = data.mode or "deer"
            vRP.GenerateItem(Passport, "meatfillet", Star, true)
            vRP.GenerateItem(Passport, (Mode or "deer")..Star.."star", 1, true)

            TriggerClientEvent("Notify", src, "Hunting", ("Carcaça esfolada: %d★."):format(Star), "verde", 5000)
            TriggerClientEvent("inventory:ActionLock", src, false)
            TriggerClientEvent("inventory:DeletePed", src, netId)
        else
            TriggerClientEvent("Notify", src, "Aviso", "Esfolamento cancelado.", "amarelo", 3500)
            TriggerClientEvent("inventory:ActionLock", src, false)
        end

        -- limpa lock
        ClearNetLockByPassport(Passport)
        NetLocks[netKey] = nil
    end)
end)
