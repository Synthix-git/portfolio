-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRPC         = Tunnel.getInterface("vRP")
vRP          = Proxy.getInterface("vRP")

-----------------------------------------------------------------------------------------------------------------------------------------
-- BIND
-----------------------------------------------------------------------------------------------------------------------------------------
Creative = {}
Tunnel.bindInterface("trucker",Creative)
vCLIENT = Tunnel.getInterface("trucker")

-----------------------------------------------------------------------------------------------------------------------------------------
-- VIP
-----------------------------------------------------------------------------------------------------------------------------------------
local VIP_MULT = { [1]=1.25,[2]=1.15,[3]=1.10 }

-----------------------------------------------------------------------------------------------------------------------------------------
-- XP / PAUSE
-----------------------------------------------------------------------------------------------------------------------------------------
local XP_TRACK = "Camionista" -- trilho/skill para XP

-- dar XP e pontos do pause
local function GrantXPAndPause(Passport, amount)
	if amount and amount > 0 then
		vRP.PutExperience(Passport, XP_TRACK, amount)
		if exports["pause"] and exports["pause"].AddPoints then
			exports["pause"]:AddPoints(Passport, amount)
		end
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- UTIL: LOG DISCORD (canal "Jobs")
-----------------------------------------------------------------------------------------------------------------------------------------
local function LogJob(src, title, lines)
    if not exports["discord"] or not exports["discord"].Embed then return end
    local msg = "**"..(title or "Camionista").."**\n" .. table.concat(lines, "\n")
    exports["discord"]:Embed("Jobs", msg, src)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- GORJETA
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("trucker:tip")
AddEventHandler("trucker:tip", function(amount, method)
    local src = source
    local Passport = vRP.Passport(src)
    if not Passport then return end

    amount = tonumber(amount) or 0
    if amount <= 0 then return end

    local tip = amount
    local vipTag, vipMultTxt = "—", "x1.00"
    if vRP.HasGroup(Passport,"Premium") then
        local vLevel = vRP.LevelPremium(src) or 1
        local vipMult = VIP_MULT[vLevel] or 1.0
        tip = math.floor(tip * vipMult + 0.5)
        vipTag = (vLevel == 1 and "Ouro") or (vLevel == 2 and "Prata") or "Bronze"
        vipMultTxt = string.format("x%.2f", vipMult)
    end

    method = tostring(method or ""):lower()
    if method == "bank" then
        vRP.GiveBank(Passport, tip)
    else
        vRP.GenerateItem(Passport,"dollar",tip,true)
    end

    -- XP + Pontos do pause (usa o valor final da gorjeta)
    GrantXPAndPause(Passport, tip)

    -- Notify
    local identity = vRP.Identity(Passport) or {}
    local gender = identity.sex or "M"
    local list = (gender == "F") and Config.TipMessages.female or Config.TipMessages.male
    local msg = (list and list[math.random(#list)]) or "Recebeste uma gorjeta."
    TriggerClientEvent("Notify", src, "Camionista", msg.." Valor: <b>$"..tip.."</b>.", "azul", 6000)

    -- Log Discord
    LogJob(src, "💼 Gorjeta (Camionista)", {
        string.format("👤 **Passaporte:** %s", Passport),
        string.format("💵 **Valor:** $%d", tip),
        string.format("🏷️ **VIP:** %s (%s)", vipTag, vipMultTxt),
        string.format("🏦 **Método:** %s", (method == "bank") and "Banco" or "Cash")
    })
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- PAGAMENTO FIXO POR ENTREGA
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("trucker:pay")
AddEventHandler("trucker:pay", function(amount, method)
    local src = source
    local Passport = vRP.Passport(src)
    if not Passport then return end

    amount = tonumber(amount) or 0
    if amount <= 0 then return end

    local pay = amount
    local vipTag, vipMultTxt = "—", "x1.00"
    if vRP.HasGroup(Passport,"Premium") then
        local vLevel = vRP.LevelPremium(src) or 1
        local vipMult = VIP_MULT[vLevel] or 1.0
        pay = math.floor(pay * vipMult + 0.5)
        vipTag = (vLevel == 1 and "Ouro") or (vLevel == 2 and "Prata") or "Bronze"
        vipMultTxt = string.format("x%.2f", vipMult)
    end

    method = tostring(method or ""):lower()
    if method == "bank" then
        vRP.GiveBank(Passport, pay)
    else
        vRP.GenerateItem(Passport,"dollar",pay,true)
    end

    -- XP + Pontos do pause (usa o valor final pago)
    GrantXPAndPause(Passport, pay)

    TriggerClientEvent("Notify", src, "Camionista", "Entrega concluída! Recebeste <b>$"..pay.."</b>.", "verde", 5000)

    -- Log Discord
    LogJob(src, "🚚 Pagamento de Entrega (Camionista)", {
        string.format("👤 **Passaporte:** %s", Passport),
        string.format("💰 **Valor:** $%d", pay),
        string.format("🏷️ **VIP:** %s (%s)", vipTag, vipMultTxt),
        string.format("🏦 **Método:** %s", (method == "bank") and "Banco" or "Cash")
    })
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- FIRE (despedir)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("trucker:fire")
AddEventHandler("trucker:fire", function()
    local src = source
    TriggerClientEvent("trucker:firedScreen", src)
    -- (Opcional) Log do despedimento:
    -- local Passport = vRP.Passport(src)
    -- if Passport then LogJob(src, "❌ Despedido (Camionista)", { string.format("👤 **Passaporte:** %s", Passport) }) end
end)
