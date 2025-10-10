local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")
vRP = Proxy.getInterface("vRP")
vSERVER = Tunnel.getInterface("mine")

local emServico = false
local multiplicadorDrop = 1

--  Anti-spam/lock
local isMining = false
local miningCooldownUntil = 0
local MINING_TIME = 10000      -- ms
local REARM_COOLDOWN = 500    -- ms entre cliques

local locais = {
	vec3(2952.52,2767.97,40.05),
	vec3(2937.14,2771.69,39.88),
	vec3(2925.76,2792.31,41.2),
	vec3(2948.05,2820.57,43.49),
	vec3(2972.6,2799.01,42.34),
	vec3(2977.24,2792.47,41.42),
	vec3(2983.22,2763.38,43.67),
	vec3(2999.39,2757.14,44.4),
}

local ServicePoint = { 2949.76,2754.73,43.3 }

--  Target para entrar/sair de serviço
CreateThread(function()
	exports["target"]:AddCircleZone("mine:service", vec3(ServicePoint[1],ServicePoint[2],ServicePoint[3]), 1.5, {
		name = "mine:service",
		heading = 3374176
	}, {
		shop = "mine",
		Distance = 1.5,
		options = {
			{ event = "mineracao:entrarServico", label = "Entrar em Serviço", tunnel = "client" },
			{ event = "mineracao:sairServico",   label = "Sair de Serviço",   tunnel = "client" }
		}
	})
end)

--  Entrar/sair de serviço
RegisterNetEvent("mineracao:entrarServico")
AddEventHandler("mineracao:entrarServico", function()
	if emServico then
		TriggerEvent("Notify","Mineração"," Já estás em serviço.","amarelo",3000)
		return
	end
	emServico = true
	TriggerEvent("Notify","Mineração"," Entraste em serviço!","verde",3000)
end)

RegisterNetEvent("mineracao:sairServico")
AddEventHandler("mineracao:sairServico", function()
	if not emServico then
		TriggerEvent("Notify","Mineração"," Não estás em serviço.","vermelho",3000)
		return
	end
	emServico = false
	TriggerEvent("Notify","Mineração"," Saíste de serviço!","vermelho",3000)
end)

RegisterNetEvent("mineracao:ForceEndService")
AddEventHandler("mineracao:ForceEndService", function()
	if not emServico then return end
	emServico = false
	-- limpar markers/blips/props se precisares
end)

--  Marcar locais com Marker fixo e ação no E
CreateThread(function()
	while true do
		local sleep = 1000
		local ped = PlayerPedId()
		local coords = GetEntityCoords(ped)

		if emServico then
			for _,v in pairs(locais) do
				local dist = #(coords - v)
				if dist <= 10.0 then
					sleep = 1
					DrawMarker(23, v.x, v.y, v.z - 0.5, 0,0,0, 0,0,0, 1.2,1.2,1.2, 0,122,255,120, false,false,2,false,nil,nil,false)

					-- Bloqueia spam no próprio keybind
					if dist <= 1.2 and IsControlJustPressed(0, 38) then
						if not isMining and GetGameTimer() >= miningCooldownUntil then
							TriggerEvent("minerar:acao", v) -- passa coords para validação opcional
						end
					end
				end
			end
		end

		Wait(sleep)
	end
end)

--  Cancelamento/limpeza segura
local function CancelMining(ped)
	vRP.Destroy()
	FreezeEntityPosition(ped, false)
	isMining = false
	miningCooldownUntil = GetGameTimer() + REARM_COOLDOWN
end

-- Parte da função de mineração com broca estilo jackhammer (com lock)
RegisterNetEvent("minerar:acao")
AddEventHandler("minerar:acao", function(pos)
	if not emServico then
		TriggerEvent("Notify","Mineração","Precisas de estar em serviço!","amarelo",3000)
		return
	end

	if isMining or GetGameTimer() < miningCooldownUntil then
		-- já está a minerar ou ainda no cooldown de rearme
		return
	end

	local ped = PlayerPedId()
	if IsPedInAnyVehicle(ped) then return end

	isMining = true
	local startPos = pos or GetEntityCoords(ped)

	-- trava o jogador e mostra barra
	FreezeEntityPosition(ped, true)
	TriggerEvent("Progress"," A minerar metais...", MINING_TIME)
	TriggerEvent("Notify","Mineração"," A minerar metais...","verde", MINING_TIME)

	-- animação + prop (jackhammer grande)
	vRP.CreateObjects("amb@world_human_const_drill@male@drill@base","base","prop_tool_jackham",15,28422)

	-- Espera com checagens simples de cancelamento
	local elapsed = 0
	while elapsed < MINING_TIME do
		Wait(50)
		elapsed = elapsed + 50

		-- cancela se sair do sítio, entrar em veículo ou morrer
		if #(GetEntityCoords(ped) - startPos) > 2.5 or IsPedInAnyVehicle(ped) or IsEntityDead(ped) then
			TriggerEvent("Notify","Mineração"," Mineração cancelada.","amarelo",3000)
			return CancelMining(ped)
		end

		-- opcional: bloquear tecla E enquanto minera
		DisableControlAction(0, 38, true)
	end

	-- fim com sucesso
	vRP.Destroy()
	FreezeEntityPosition(ped, false)
	isMining = false
	miningCooldownUntil = GetGameTimer() + REARM_COOLDOWN

	TriggerEvent("Notify","Mineração"," Terminaste de minerar!","verde",3000)
	TriggerServerEvent("minerar:recompensa", multiplicadorDrop)
end)
