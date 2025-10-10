-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")
vRP = Proxy.getInterface("vRP")
Creative = {}
Tunnel.bindInterface("bus", Creative)
vCLIENT = Tunnel.getInterface("bus")

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONFIG
-----------------------------------------------------------------------------------------------------------------------------------------
local Buffs = {
	["Dexterity"] = {}
}

-----------------------------------------------------------------------------------------------------------------------------------------
-- FORMAT NUMBER
-----------------------------------------------------------------------------------------------------------------------------------------
local function parseFormat(n)
    n = tonumber(n) or 0
    local s = tostring(math.floor(n + 0.5))
    local formatted, k = s, 0
    repeat
        formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1.%2")
    until k == 0
    return formatted
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- VIP MULTIPLIER
-----------------------------------------------------------------------------------------------------------------------------------------
local function applyVipBonus(src, Passport, base, kind)
	if not Passport then return base end
	if not vRP.HasGroup(Passport, "Premium") then return base end

	local lvl = vRP.LevelPremium(src) or 1
	local mult = 1.0

	if kind == "money" then
		if lvl == 1 then mult = 1.20 -- Ouro
		elseif lvl == 2 then mult = 1.15 -- Prata
		elseif lvl == 3 then mult = 1.10 -- Bronze
		end
	elseif kind == "xp" then
		if lvl == 1 then mult = 1.25
		elseif lvl == 2 then mult = 1.15
		elseif lvl == 3 then mult = 1.10
		end
	end

	return math.floor(base * mult + 0.5)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- PAGAMENTO POR PARAGEM
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Payment(amount)
	local src = source
	local Passport = vRP.Passport(src)
	if Passport then
		local Experience = vRP.GetExperience(Passport, "Bus")
		local Level = ClassCategory(Experience)
		local Valuation = parseInt(amount)

		-- Bônus por level
		if Level == 2 or Level == 3 or Level == 5 then
			Valuation = Valuation + 10
		elseif Level == 6 or Level == 7 or Level == 8 then
			Valuation = Valuation + 15
		elseif Level == 9 or Level == 10 then
			Valuation = Valuation + 20
		end

		-- Bônus por Buff
		if Buffs["Dexterity"][Passport] and Buffs["Dexterity"][Passport] > os.time() then
			Valuation = Valuation + (Valuation * 0.1)
		end

		-- Bônus por VIP
		Valuation = applyVipBonus(src, Passport, Valuation, "money")

		-- XP + Pontos do Pause (com VIP também)
		local xp = 10
		xp = applyVipBonus(src, Passport, xp, "xp")

		vRP.PutExperience(Passport, "Bus", xp)
		exports["pause"]:AddPoints(Passport, xp)

		vRP.GenerateItem(Passport, "dollars", Valuation, true)
		TriggerEvent("inventory:BuffServer", src, Passport, "Dexterity", Valuation)
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- SALÁRIO A CADA 10 MINUTOS
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Salary()
	local src = source
	local Passport = vRP.Passport(src)
	if Passport then
		local Experience = vRP.GetExperience(Passport, "Bus")
		local Level = ClassCategory(Experience)
		local Valuation = 5000

		-- Bônus por level
		if Level == 2 or Level == 3 or Level == 5 then
			Valuation = Valuation + 10
		elseif Level == 6 or Level == 7 or Level == 8 then
			Valuation = Valuation + 15
		elseif Level == 9 or Level == 10 then
			Valuation = Valuation + 20
		end

		-- Bônus por Buff
		if Buffs["Dexterity"][Passport] and Buffs["Dexterity"][Passport] > os.time() then
			Valuation = Valuation + (Valuation * 0.1)
		end

		-- Bônus por VIP
		Valuation = applyVipBonus(src, Passport, Valuation, "money")

		-- Salário + XP + Pontos do Pause (com VIP também)
		vRP.GiveBank(Passport, Valuation)

		local xp = 10
		xp = applyVipBonus(src, Passport, xp, "xp")

		vRP.PutExperience(Passport, "Bus", xp)
		exports["pause"]:AddPoints(Passport, xp)

		TriggerClientEvent("sounds:Private", src, "coins", 0.25)
		TriggerEvent("inventory:BuffServer", src, Passport, "Dexterity", Valuation)
		TriggerClientEvent("Notify", src, "Sistema", "Recebeste <b>$"..parseFormat(Valuation).."</b> na conta bancária.", "verde", 5000)
	end
end
