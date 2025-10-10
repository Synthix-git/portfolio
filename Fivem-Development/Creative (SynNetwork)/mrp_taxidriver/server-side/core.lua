-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp", "lib/Tunnel")
local Proxy  = module("vrp", "lib/Proxy")
vRP = Proxy.getInterface("vRP")

Creative = {}
Tunnel.bindInterface("taxi", Creative)
vSERVER = Tunnel.getInterface("taxi")

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONFIG
-----------------------------------------------------------------------------------------------------------------------------------------
local DELIVERY_PAYMENT = 500      -- pagamento base por corrida
local BASE_SALARY      = 5000     -- salário base a cada 10 min
local XP_PER_RIDE      = 10       -- XP por corrida concluída
local XP_PER_SALARY    = 5        -- XP por ciclo de salário
local XP_TRACK         = "Taxi"   -- trilha de XP

local BUFF_BONUS       = 0.10     -- buff Dexterity = +10%

-- armazenamento simples de buffs (mesma ideia do bus)
local Buffs = { ["Dexterity"] = {} }

-- devolve pagamento com bónus de nível fixo
local function LevelBonus(level, base)
	if level == 2 or level == 3 or level == 5 then
		return base + 10
	elseif level == 6 or level == 7 or level == 8 then
		return base + 15
	elseif level == 9 or level == 10 then
		return base + 20
	end
	return base
end

-- multiplicador VIP correto
local function VipMultiplier(src, Passport)
	if not Passport then return 1.0 end
	if not vRP.HasGroup(Passport,"Premium") then return 1.0 end

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

-- aplica multiplicadores (buff + VIP)
local function ApplyMultipliers(Passport, source, amount)
	local pay = amount

	-- Buff +10% se ativo
	if Buffs["Dexterity"][Passport] and Buffs["Dexterity"][Passport] > os.time() then
		pay = pay + (pay * BUFF_BONUS)
	end

	-- VIP
	local vipMult = VipMultiplier(source, Passport)
	pay = pay * vipMult

	return math.floor(pay + 0.5)
end

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
-- SALÁRIO AUTOMÁTICO (10 MIN)
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		Wait(600000) -- 10 minutos
		for _, src in pairs(GetPlayers()) do
			local Passport = vRP.Passport(src)
			if Passport and vRP.HasGroup(Passport, "Taxista") then
				local exp  = vRP.GetExperience(Passport, XP_TRACK)
				local lvl  = ClassCategory(exp)
				local base = LevelBonus(lvl, BASE_SALARY)
				local pay  = ApplyMultipliers(Passport, src, base)

				vRP.GenerateItem(Passport, "dollars", pay, true)
				GrantXPAndPause(Passport, XP_PER_SALARY)

				TriggerClientEvent("Notify", src, "Salário", "Recebeste <b>$"..pay.."</b> como salário base.", "verde", 5000)

				-- atualiza/estende buff conforme o valor pago (igual ao bus)
				TriggerEvent("inventory:BuffServer", src, Passport, "Dexterity", pay)
			end
		end
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- CRIAÇÃO DO PED NO CLIENTE
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.CreatePed(coords)
	TriggerClientEvent("taxi:CreatePed", source, coords)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- FINALIZAÇÃO DA CORRIDA
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.FinishRide()
	local src = source
	local Passport = vRP.Passport(src)
	if Passport then
		local exp  = vRP.GetExperience(Passport, XP_TRACK)
		local lvl  = ClassCategory(exp)
		local base = LevelBonus(lvl, DELIVERY_PAYMENT)
		local pay  = ApplyMultipliers(Passport, src, base)

		vRP.GenerateItem(Passport, "dollars", pay, true)
		GrantXPAndPause(Passport, XP_PER_RIDE)

		TriggerClientEvent("Notify", src, "Corrida", "Recebeste <b>$"..pay.."</b> pela corrida.", "verde", 5000)

		-- reforça buff com base no pagamento desta corrida
		TriggerEvent("inventory:BuffServer", src, Passport, "Dexterity", pay)
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- SALÁRIO MANUAL (opcional)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("taxi:paySalary")
AddEventHandler("taxi:paySalary", function()
	local src = source
	local Passport = vRP.Passport(src)
	if Passport then
		local exp  = vRP.GetExperience(Passport, XP_TRACK)
		local lvl  = ClassCategory(exp)
		local base = LevelBonus(lvl, BASE_SALARY)
		local pay  = ApplyMultipliers(Passport, src, base)

		vRP.GenerateItem(Passport, "dollars", pay, true)
		GrantXPAndPause(Passport, XP_PER_SALARY)

		TriggerClientEvent("Notify", src, "Salário", "Recebeste <b>$"..pay.."</b> como salário base.", "verde", 5000)
		TriggerEvent("inventory:BuffServer", src, Passport, "Dexterity", pay)
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- (Opcional) Handler caso tenhas um evento que atualize Buffs localmente
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("inventory:SyncBuff")
AddEventHandler("inventory:SyncBuff", function(passport, buffName, expiresAt)
	Buffs[buffName] = Buffs[buffName] or {}
	Buffs[buffName][passport] = expiresAt
end)
