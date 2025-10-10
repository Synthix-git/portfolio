-----------------------------------------------------------------------------------------------------------------------------------------
-- CARRY | SERVER-SIDE 
-- Bloqueia INICIAR carry se o carregador ou o alvo estiverem dentro de veículo.
-- Permite CONTINUAR o carry ao entrar no veículo (ex.: levar ferido ao hospital).
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")
vRP = Proxy.getInterface("vRP")
vRPC = Tunnel.getInterface("vRP")

-----------------------------------------------------------------------------------------------------------------------------------------
-- TABELAS DE ESTADO
-- - CarrierByPassport[carrierPassport] = targetSrc
-- - TargetByPassport[targetPassport]   = carrierSrc
-----------------------------------------------------------------------------------------------------------------------------------------
local CarrierByPassport = CarrierByPassport or {}
local TargetByPassport = TargetByPassport or {}

-----------------------------------------------------------------------------------------------------------------------------------------
-- GRUPOS AUTORIZADOS (força)
-----------------------------------------------------------------------------------------------------------------------------------------
local AllowedCarryGroups = {
	"Policia",
	"Paramedico",
	"Admin",
}

local function HasAnyAllowedGroup(passport)
	for _, g in ipairs(AllowedCarryGroups) do
		if vRP.HasGroup(passport, g) then
			return true
		end
	end
	return false
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS DE ESTADO (MORTE / ALGEMA / VEÍCULO)
-----------------------------------------------------------------------------------------------------------------------------------------
local function IsDead(src)
	-- 1) flags possíveis no state (bases variam o nome)
	local st = Player(src) and Player(src).state or nil
	if st then
		if st["Death"] or st["Dead"] or st["Incapacitated"] or st["Coma"] or st["Down"] then
			return true
		end
	end
	-- 2) fallback robusto: vida do ped no servidor
	local ped = GetPlayerPed(src)
	if ped and ped ~= 0 then
		local hp = GetEntityHealth(ped) or 200
		-- FiveM: morto costuma ser <= 101
		if hp <= 101 then
			return true
		end
	end
	return false
end

local function IsCuffed(src)
	local st = Player(src) and Player(src).state or nil
	if st and (st["Handcuff"] or st["Cuffed"] or st["Algemado"]) then
		return true
	end
	return false
end

-- 👇 Bloqueia APENAS o INÍCIO do carry se o jogador estiver num veículo.
local function IsInVehicle(src)
	local ped = GetPlayerPed(src)
	if ped and ped ~= 0 then
		return GetVehiclePedIsIn(ped, false) ~= 0
	end
	return false
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- UTILS
-----------------------------------------------------------------------------------------------------------------------------------------
local function SafeSetState(src, key, val)
	if src and Player(src) and Player(src).state then
		Player(src).state[key] = val
	end
end

-- Detach total e limpo
local function DetachPair(carrierSrc, carrierPassport)
	if not carrierSrc or not carrierPassport then
		return
	end

	local targetSrc = CarrierByPassport[carrierPassport]
	if targetSrc then
		-- avisa o alvo para desanexar
		TriggerClientEvent("inventory:Carry", targetSrc, carrierSrc, "Detach")
		SafeSetState(targetSrc, "Carry", false)

		local targetPassport = vRP.Passport(targetSrc)
		if targetPassport then
			TargetByPassport[targetPassport] = nil
		end
	end

	-- limpa o carregador
	SafeSetState(carrierSrc, "Carry", false)
	CarrierByPassport[carrierPassport] = nil
end

-- Faz o attach (com ou sem “força”)
local function AttachPair(carrierSrc, targetSrc, handcuff)
	local carrierPassport = vRP.Passport(carrierSrc)
	local targetPassport = vRP.Passport(targetSrc)
	if not carrierPassport or not targetPassport then
		return false
	end

	-- Evita duplicados
	if CarrierByPassport[carrierPassport] then
		return false
	end -- já estou a carregar alguém?
	if TargetByPassport[carrierPassport] then
		return false
	end -- já estou a ser carregado?
	if TargetByPassport[targetPassport] then
		return false
	end -- alvo já está a ser carregado?
	if CarrierByPassport[targetPassport] then
		return false
	end -- alvo está a carregar alguém?

	-- Marca estados
	CarrierByPassport[carrierPassport] = targetSrc
	TargetByPassport[targetPassport] = carrierSrc
	SafeSetState(carrierSrc, "Carry", true)
	SafeSetState(targetSrc, "Carry", true)

	-- Notifica o alvo para se anexar ao carregador
	TriggerClientEvent("inventory:Carry", targetSrc, carrierSrc, "Attach", handcuff and true or false)
	return true
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- TOGGLES (MENU DINÂMICO / COMANDOS)
-----------------------------------------------------------------------------------------------------------------------------------------

-- Evento principal para o botão do dynamic: inventário -> Carry (toggle)
-- Se o player pertence a grupo autorizado, ignora checks (força).
RegisterServerEvent("inventory:Carry")
AddEventHandler("inventory:Carry", function()
	local src = source
	local passport = vRP.Passport(src)
	if not passport then
		return
	end

	local force = HasAnyAllowedGroup(passport)

	-- Bloqueia uso se estiver morto ou algemado (mesmo que tenha grupo)
	if IsDead(src) or IsCuffed(src) then
		-- TriggerClientEvent("Notify", src, "Falhou", "Não podes carregar enquanto estás incapacitado.", "vermelho", 5000)
		return
	end

	-- ❌ Não pode iniciar carry se já estiver num veículo
	if IsInVehicle(src) then
		-- TriggerClientEvent("Notify", src, "Falhou", "Não podes iniciar carry dentro de um veículo.", "amarelo", 5000)
		return
	end

	-- Procura alvo via client (mais fiável)
	local targetSrc = vRPC.ClosestPed(src)
	if not targetSrc or targetSrc == src or not GetPlayerName(targetSrc) then
		-- TriggerClientEvent("Notify", src, "Falhou", "Ninguém por perto para carregar.", "vermelho", 4000)
		return
	end

	-- ❌ Alvo também não pode estar dentro de veículo ao iniciar
	if IsInVehicle(targetSrc) then
		-- TriggerClientEvent("Notify", src, "Falhou", "O jogador está dentro de um veículo.", "amarelo", 5000)
		return
	end

	-- Checks normais (bloqueiam civis), ignorados para staff/LSPD/EMS
	if not force then
		if not vRP.IsEntityVisible(targetSrc) then
			-- TriggerClientEvent("Notify", src, "Falhou", "Não consegues interagir com esse jogador agora.", "vermelho", 4000)
			return
		end
		if
			vRPC.PlayingAnim and vRPC.PlayingAnim(targetSrc, "amb@world_human_sunbathe@female@back@idle_a", "idle_a")
		then
			-- TriggerClientEvent("Notify", src, "Falhou", "O jogador não está em posição para ser carregado.", "vermelho", 4000)
			return
		end
	end

	if CarrierByPassport[passport] then
		-- se já está a carregar, solta (toggle)
		DetachPair(src, passport)
		TriggerClientEvent("Notify", src, "Pronto", "Largaste o cidadão.", "verde", 4000)
		return
	end

	if AttachPair(src, targetSrc, false) then
		TriggerClientEvent("Notify", src, "Ok", "Estás a carregar o jogador.", "verde", 4000)
	else
		-- TriggerClientEvent("Notify", src, "Falhou", "Esse jogador já está envolvido noutra ação.", "vermelho", 4000)
	end
end)

-- Alternativa: forçar via comando /carregar (só grupos permitidos)
RegisterCommand("carregar", function(source)
	local src = source
	local passport = vRP.Passport(src)
	if not passport then
		return
	end

	if not HasAnyAllowedGroup(passport) then
		-- TriggerClientEvent("Notify", src, "Espera!", "Não tens permissão para usar o /carregar.", "amarelo", 5000)
		return
	end

	-- Bloqueia uso se estiver morto ou algemado (mesmo staff)
	if IsDead(src) or IsCuffed(src) then
		-- TriggerClientEvent("Notify", src, "Falhou", "Não podes carregar enquanto estás incapacitado.", "vermelho", 5000)
		return
	end

	-- ❌ Staff também não pode INICIAR carry dentro de veículo
	if IsInVehicle(src) then
		-- TriggerClientEvent("Notify", src, "Falhou", "Não podes iniciar carry dentro de um veículo.", "amarelo", 5000)
		return
	end

	-- toggle (se já estás a carregar alguém, solta)
	if CarrierByPassport[passport] then
		DetachPair(src, passport)
		TriggerClientEvent("Notify", src, "Pronto", "Largaste o cidadão.", "verde", 4000)
		return
	end

	-- alvo mais próximo (lado do cliente)
	local targetSrc = vRPC.ClosestPed(src)
	if not targetSrc or targetSrc == src or not GetPlayerName(targetSrc) then
		-- TriggerClientEvent("Notify", src, "Falhou", "Ninguém por perto para carregar.", "vermelho", 4000)
		return
	end

	-- ❌ Alvo não pode estar dentro de veículo ao iniciar
	if IsInVehicle(targetSrc) then
		-- TriggerClientEvent("Notify", src, "Falhou", "O jogador está dentro de um veículo.", "amarelo", 5000)
		return
	end

	-- limpa alvo se ele já estiver em alguma ação (FORCE)
	local tPass = vRP.Passport(targetSrc)
	if tPass then
		if CarrierByPassport[tPass] then
			DetachPair(targetSrc, tPass)
		end
		if TargetByPassport[tPass] then
			local oldCarrier = TargetByPassport[tPass]
			local oldCarrierPass = vRP.Passport(oldCarrier)
			if oldCarrierPass then
				DetachPair(oldCarrier, oldCarrierPass)
			end
		end
	end

	if AttachPair(src, targetSrc, false) then
		TriggerClientEvent("Notify", src, "Ok", "Estás a carregar o jogador (forçado).", "verde", 4000)
	else
		-- TriggerClientEvent("Notify", src, "Falhou", "Não foi possível iniciar o carry.", "vermelho", 4000)
	end
end)

-- Forçar carry a partir de outro handler (ex.: algemado)
RegisterServerEvent("inventory:ServerCarry")
AddEventHandler("inventory:ServerCarry", function(targetSrc, handcuff)
	local src = source
	local passport = vRP.Passport(src)
	if not passport then
		return
	end

	local force = HasAnyAllowedGroup(passport) or handcuff == true

	-- Mesmo forçado (grupo ou handcuff), se o CARRIER estiver morto/algemado, não pode iniciar
	if IsDead(src) or IsCuffed(src) then
		-- TriggerClientEvent("Notify", src, "Falhou", "Não podes iniciar carry enquanto estás incapacitado.", "vermelho", 5000)
		return
	end

	-- ❌ Mesmo forçado, INICIAR carry dentro de veículo não é permitido
	if IsInVehicle(src) then
		-- TriggerClientEvent("Notify", src, "Falhou", "Não podes iniciar carry dentro de um veículo.", "amarelo", 5000)
		return
	end

	-- toggle: se já estás a carregar alguém, solta
	if CarrierByPassport[passport] then
		DetachPair(src, passport)
		if not targetSrc then
			return
		end
	end

	if not targetSrc or targetSrc == src or not GetPlayerName(targetSrc) then
		return
	end

	-- ❌ Alvo não pode estar em veículo ao iniciar
	if IsInVehicle(targetSrc) then
		-- TriggerClientEvent("Notify", src, "Falhou", "O jogador está dentro de um veículo.", "amarelo", 5000)
		return
	end

	if force then
		-- limpa qualquer estado prévio do ALVO
		local targetPassport = vRP.Passport(targetSrc)
		if targetPassport then
			if CarrierByPassport[targetPassport] then
				DetachPair(targetSrc, targetPassport)
			end
			if TargetByPassport[targetPassport] then
				local oldCarrier = TargetByPassport[targetPassport]
				local oldCarrierPassport = vRP.Passport(oldCarrier)
				if oldCarrierPassport then
					DetachPair(oldCarrier, oldCarrierPassport)
				end
			end
		end
	end

	-- força attach quando forçado; sem checks extra
	AttachPair(src, targetSrc, handcuff and true or false)
end)

-- Soltar via client
RegisterServerEvent("inventory:CarryDetach")
AddEventHandler("inventory:CarryDetach", function()
	local src = source
	local passport = vRP.Passport(src)
	if not passport then
		return
	end
	if CarrierByPassport[passport] then
		DetachPair(src, passport)
	end
end)

-- Staff: forçar soltar por source OU passaporte
RegisterServerEvent("inventory:CarryForceDetach")
AddEventHandler("inventory:CarryForceDetach", function(optSrc, optPassport)
	local src = source
	local staffPassport = vRP.Passport(src)
	if not staffPassport then
		return
	end
	if not HasAnyAllowedGroup(staffPassport) then
		return
	end

	local tgtSrc, tgtPassport

	if optSrc and tonumber(optSrc) and GetPlayerName(tonumber(optSrc)) then
		tgtSrc = tonumber(optSrc)
		tgtPassport = vRP.Passport(tgtSrc)
	elseif optPassport and tonumber(optPassport) then
		tgtPassport = tonumber(optPassport)
		for plySrc, plyPassport in pairs(vRP.Players()) do
			if plyPassport == tgtPassport and GetPlayerName(plySrc) then
				tgtSrc = plySrc
				break
			end
		end
	else
		tgtSrc = src
		tgtPassport = staffPassport
	end

	if not tgtPassport then
		return
	end

	-- Se o alvo é um CARREGADOR, solta pelo carrier
	if CarrierByPassport[tgtPassport] then
		DetachPair(tgtSrc, tgtPassport)
	end

	-- Se o alvo está a SER CARREGADO, solta o carrier correspondente
	if TargetByPassport[tgtPassport] then
		local carrierSrc = TargetByPassport[tgtPassport]
		local carrierPassport = vRP.Passport(carrierSrc)
		if carrierPassport then
			DetachPair(carrierSrc, carrierPassport)
		end
	end
end)

-- Limpeza automática quando alguém cai
AddEventHandler("playerDropped", function()
	local src = source
	local passport = vRP.Passport(src)
	if not passport then
		return
	end

	-- Se era CARREGADOR
	if CarrierByPassport[passport] then
		DetachPair(src, passport)
	end

	-- Se estava a SER CARREGADO
	if TargetByPassport[passport] then
		local carrierSrc = TargetByPassport[passport]
		local carrierPassport = vRP.Passport(carrierSrc)
		if carrierPassport then
			DetachPair(carrierSrc, carrierPassport)
		end
		TargetByPassport[passport] = nil
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- EXPORTS
-----------------------------------------------------------------------------------------------------------------------------------------
exports("IsCarrying", function(passport)
	return CarrierByPassport[passport] ~= nil, CarrierByPassport[passport]
end)

exports("ForceDetach", function(srcOrPassport)
	if type(srcOrPassport) ~= "number" then
		return false
	end

	-- Se veio um source
	if GetPlayerName(srcOrPassport) then
		local pp = vRP.Passport(srcOrPassport)
		if pp and CarrierByPassport[pp] then
			DetachPair(srcOrPassport, pp)
			return true
		end
		-- Se estava a ser carregado, solta o carrier
		if pp and TargetByPassport[pp] then
			local carrierSrc = TargetByPassport[pp]
			local carrierPassport = vRP.Passport(carrierSrc)
			if carrierPassport then
				DetachPair(carrierSrc, carrierPassport)
				return true
			end
		end
		return false
	end

	-- Tratá-lo como passaporte
	local pp = srcOrPassport

	if CarrierByPassport[pp] then
		local carrierSrc
		for s, p in pairs(vRP.Players()) do
			if p == pp then
				carrierSrc = s
				break
			end
		end
		if carrierSrc then
			DetachPair(carrierSrc, pp)
			return true
		else
			CarrierByPassport[pp] = nil
			return true
		end
	end

	if TargetByPassport[pp] then
		local carrierSrc = TargetByPassport[pp]
		local carrierPassport = vRP.Passport(carrierSrc)
		if carrierPassport then
			DetachPair(carrierSrc, carrierPassport)
			TargetByPassport[pp] = nil
			return true
		end
		TargetByPassport[pp] = nil
		return true
	end

	return false
end)
