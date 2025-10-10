-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP / TUNNEL
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp", "lib/Tunnel")
local Proxy  = module("vrp", "lib/Proxy")
vRP = Proxy.getInterface("vRP")
vSERVER = Tunnel.getInterface("lumberman")

-----------------------------------------------------------------------------------------------------------------------------------------
-- ESTADO
-----------------------------------------------------------------------------------------------------------------------------------------
local emServico = false
local isCutting = false
local cutCooldownUntil = 0
local CUT_TIME = 3000          -- ms
local REARM_COOLDOWN = 500     -- ms
local multiplicadorDrop = 1

-- Só 1 árvore
local locais = {
vec3(-599.40, 5239.56, 71.46),
vec3(-603.28, 5243.51, 71.33),
vec3(-558.03, 5233.48, 72.11),
vec3(-559.56, 5224.15, 76.97),
vec3(-547.62, 5219.83, 78.12),
vec3(-538.60, 5225.71, 78.38),
vec3(-628.36, 5284.94, 64.17),
vec3(-632.60, 5274.15, 69.23),
vec3(-656.14, 5296.26, 69.00),
vec3(-658.09, 5293.41, 70.01),
vec3(-663.70, 5278.99, 73.95),
vec3(-643.44, 5241.30, 75.16),
vec3(-626.71, 5314.98, 59.93),
vec3(-628.15, 5322.48, 59.47),
vec3(-631.13, 5332.14, 57.32),
vec3(-688.96, 5305.32, 69.89),
vec3(-715.10, 5328.58, 70.95),
vec3(-720.10, 5325.22, 71.65),
vec3(-747.51, 5346.63, 61.48),
vec3(-758.76, 5354.83, 57.08),
vec3(-760.59, 5356.81, 56.39),
vec3(-763.46, 5360.42, 55.09),
vec3(-775.40, 5366.11, 50.36),
vec3(-786.60, 5365.38, 51.23),
vec3(-778.51, 5370.80, 47.53),
vec3(-767.46, 5378.97, 48.32),
vec3(-761.44, 5378.50, 51.07),
vec3(-758.52, 5384.58, 49.32),
vec3(-749.66, 5396.80, 45.84),
vec3(-751.68, 5397.06, 44.96),
vec3(-749.25, 5399.57, 45.09),
vec3(-739.09, 5406.94, 48.25),
vec3(-735.81, 5406.51, 49.09),
vec3(-730.91, 5411.60, 50.39),
vec3(-728.45, 5412.40, 50.81),
vec3(-716.15, 5406.83, 51.55),
vec3(-714.71, 5402.55, 51.97),
vec3(-711.28, 5273.11, 74.88),
vec3(-717.24, 5273.89, 76.32),
vec3(-732.11, 5292.40, 75.92),
vec3(-739.90, 5296.31, 75.53),
vec3(-742.71, 5303.59, 74.99),
vec3(-766.60, 5316.35, 75.63),
vec3(-774.94, 5311.39, 78.18),
vec3(-777.20, 5335.78, 72.80),
vec3(-794.47, 5334.58, 73.19),
vec3(-798.80, 5339.26, 71.20),
vec3(-798.78, 5307.45, 79.90),
vec3(-800.76, 5310.37, 78.66),
vec3(-816.91, 5304.12, 81.63),
vec3(-826.07, 5309.90, 78.74),
vec3(-830.48, 5311.41, 77.83),
vec3(-832.36, 5325.51, 77.35),
vec3(-823.29, 5281.78, 85.55),
vec3(-821.27, 5280.33, 86.18),
vec3(-819.99, 5280.05, 86.41),
vec3(-807.32, 5290.49, 85.89),
vec3(-799.04, 5277.43, 88.20),
vec3(-784.27, 5273.83, 89.51),
vec3(-765.51, 5280.19, 87.69),
vec3(-760.61, 5281.92, 85.78),
vec3(-757.63, 5278.41, 86.12),
vec3(-751.07, 5276.24, 86.03),
vec3(-744.41, 5280.18, 82.34),
vec3(-711.65, 5273.45, 74.87),
vec3(-716.84, 5273.49, 76.27),
vec3(-655.26, 5216.01, 84.41),
vec3(-644.11, 5206.77, 86.84),
vec3(-682.20, 5209.83, 97.95),
vec3(-696.51, 5215.29, 96.76),
vec3(-699.32, 5186.82, 104.62),
vec3(-698.11, 5183.46, 105.58),
vec3(-680.58, 5193.97, 102.40),
vec3(-669.06, 5172.14, 108.35),
vec3(-664.74, 5165.67, 109.71),
vec3(-658.50, 5177.40, 105.09),
vec3(-647.36, 5190.46, 96.65),
vec3(-622.01, 5187.39, 93.90),
vec3(-601.69, 5175.77, 98.65),
vec3(-634.40, 5172.26, 102.60),
vec3(-629.15, 5165.56, 104.83),
vec3(-621.89, 5163.58, 104.59),
vec3(-614.51, 5158.79, 105.75),
vec3(-626.51, 5149.10, 110.95),
vec3(-625.91, 5144.85, 112.25),
vec3(-619.27, 5142.41, 112.11),
vec3(-619.56, 5139.10, 113.28),
vec3(-618.54, 5110.21, 124.40),
vec3(-610.85, 5103.26, 125.68),
vec3(-607.85, 5096.17, 129.41),
vec3(-589.76, 5105.80, 122.83),
vec3(-584.73, 5101.73, 123.60),
vec3(-582.61, 5096.87, 125.22),
vec3(-576.55, 5092.89, 125.96),
vec3(-578.22, 5110.38, 119.78),
vec3(-574.87, 5141.01, 108.71),
vec3(-575.46, 5143.22, 108.21),
vec3(-590.05, 5106.44, 122.70),
vec3(-584.68, 5101.96, 123.53),
vec3(-582.51, 5097.35, 125.01),
vec3(-576.03, 5093.37, 125.71),
vec3(-564.40, 5078.40, 127.35),
vec3(-562.54, 5078.04, 126.99),
vec3(-553.56, 5079.96, 124.79),
vec3(-532.92, 5083.07, 121.51),
vec3(-539.15, 5060.57, 127.05),
vec3(-524.18, 5056.93, 130.97),
vec3(-538.12, 5060.70, 127.11),
vec3(-567.19, 5061.13, 131.33),
vec3(-697.65, 5135.42, 122.78),
vec3(-688.50, 5125.80, 127.05),
vec3(-726.18, 5134.21, 119.03),
vec3(-745.60, 5152.23, 121.95),
vec3(-750.83, 5132.28, 132.95),
vec3(-746.68, 5151.76, 122.60),
vec3(-788.56, 5175.11, 126.65),
vec3(-773.85, 5146.04, 131.88),
vec3(-775.89, 5143.08, 133.57),
vec3(-779.66, 5139.17, 136.08),
vec3(-796.61, 5138.29, 139.00),
vec3(-774.89, 5104.98, 143.69),
vec3(-765.19, 5094.51, 144.23),
vec3(-784.00, 5081.34, 154.33),
vec3(-775.10, 5069.06, 149.72),
vec3(-773.94, 5075.84, 149.32),
vec3(-801.65, 5098.41, 153.01),
vec3(-800.17, 5106.27, 148.49),
vec3(-798.91, 5109.52, 146.35),
vec3(-807.79, 5111.27, 147.05),
vec3(-821.27, 5103.34, 152.45),
vec3(-833.81, 5113.63, 153.59),
vec3(-833.65, 5101.45, 157.78),
vec3(-843.50, 5102.31, 159.26)
}

-- Ponto de serviço
local ServicePoint = { -567.57, 5253.09, 70.48 }

-----------------------------------------------------------------------------------------------------------------------------------------
-- TARGET: ENTRAR/SAIR SERVIÇO
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	exports["target"]:AddCircleZone("lumberman:service", vec3(ServicePoint[1],ServicePoint[2],ServicePoint[3]), 1.5, {
		name = "lumberman:service",
		heading = ServicePoint[4] or 0
	}, {
		shop = "lumberman",
		Distance = 1.5,
		options = {
			{ event = "lumberman:enterService", label = "Entrar em Serviço", tunnel = "client" },
			{ event = "lumberman:leaveService", label = "Sair de Serviço",   tunnel = "client" }
		}
	})
end)

RegisterNetEvent("lumberman:enterService")
AddEventHandler("lumberman:enterService", function()
	if emServico then
		TriggerEvent("Notify","Lenhador","Já estás em <b>serviço</b>.","amarelo",3000)
		return
	end
	emServico = true
	TriggerEvent("Notify","Lenhador","Entraste em <b>serviço</b>! Aproxima-te da árvore e prime <b>E</b> para cortar.","verde",3000)
end)

RegisterNetEvent("lumberman:leaveService")
AddEventHandler("lumberman:leaveService", function()
	if not emServico then
		TriggerEvent("Notify","Lenhador","Não estás em <b>serviço</b>.","vermelho",3000)
		return
	end
	emServico = false
	TriggerEvent("Notify","Lenhador","Saíste de <b>serviço</b>.","vermelho",3000)
end)

RegisterNetEvent("lumberman:ForceEndService")
AddEventHandler("lumberman:ForceEndService", function()
	if not emServico then return end
	emServico = false
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- LOOP: MARKER + TECLA E
-----------------------------------------------------------------------------------------------------------------------------------------
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
					if dist <= 1.5 and IsControlJustPressed(0,38) then
						if not isCutting and GetGameTimer() >= cutCooldownUntil then
							TriggerEvent("lumberman:acao", v)
						end
					end
				end
			end
		end

		Wait(sleep)
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- CANCELAMENTO SEGURO
-----------------------------------------------------------------------------------------------------------------------------------------
local function CancelCut(ped)
	-- limpa e desbloqueia
	RemoveWeaponFromPed(ped, `WEAPON_HATCHET`)
	FreezeEntityPosition(ped, false)
	ClearPedTasksImmediately(ped)
	isCutting = false
	cutCooldownUntil = GetGameTimer() + REARM_COOLDOWN
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- AÇÃO: CORTAR (usa WEAPON_HATCHET, animação 1x e para no fim)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("lumberman:acao")
AddEventHandler("lumberman:acao", function(pos)
	if not emServico then
		TriggerEvent("Notify","Lenhador","Precisas de estar em <b>serviço</b>.","amarelo",3000)
		return
	end
	if isCutting or GetGameTimer() < cutCooldownUntil then return end

	local ped = PlayerPedId()
	if IsPedInAnyVehicle(ped) then return end

	isCutting = true
	local startPos = pos or GetEntityCoords(ped)

	-- virar para a árvore
	TaskTurnPedToFaceCoord(ped, startPos.x, startPos.y, startPos.z, 500)
	local myPos = GetEntityCoords(ped)
	local heading = (math.deg(math.atan2(startPos.y - myPos.y, startPos.x - myPos.x)) - 90.0) % 360.0
	SetEntityHeading(ped, heading)

	-- equipa a arma (visual) sem necessidade de estar no inventário
	GiveWeaponToPed(ped, `WEAPON_HATCHET`, 1, false, true)
	SetCurrentPedWeapon(ped, `WEAPON_HATCHET`, true)

	-- travar + progress
	FreezeEntityPosition(ped, true)
	TriggerEvent("Progress","A cortar madeira...", CUT_TIME)

	-- animação: toca UMA vez e não fica a loopar
	local dict, anim = "melee@hatchet@streamed_core","plyr_front_takedown"
	if not HasAnimDictLoaded(dict) then
		RequestAnimDict(dict)
		while not HasAnimDictLoaded(dict) do Wait(0) end
	end
	-- duration = CUT_TIME, flag = 0 (sem loop), blend in/out suaves
	TaskPlayAnim(ped, dict, anim, 4.0, 4.0, CUT_TIME, 0, 0.0, false, false, false)

	-- Espera com checagens de cancelamento
	local elapsed = 0
	while elapsed < CUT_TIME do
		Wait(50)
		elapsed = elapsed + 50

		if #(GetEntityCoords(ped) - startPos) > 2.5 or IsPedInAnyVehicle(ped) or IsEntityDead(ped) then
			TriggerEvent("Notify","Lenhador","Corte <b>cancelado</b>.","amarelo",3000)
			return CancelCut(ped)
		end
		DisableControlAction(0, 38, true)
	end

	-- fim: parar anim e limpar arma
	StopAnimTask(ped, dict, anim, 1.0)
	RemoveWeaponFromPed(ped, `WEAPON_HATCHET`)
	FreezeEntityPosition(ped, false)
	ClearPedTasksImmediately(ped)
	isCutting = false
	cutCooldownUntil = GetGameTimer() + REARM_COOLDOWN

	TriggerEvent("Notify","Lenhador","Madeira cortada com <b>sucesso</b>!","verde",3000)
	TriggerServerEvent("lumberman:recompensa", multiplicadorDrop)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- LIMPEZA AO PARAR O RESOURCE
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("onResourceStop", function(res)
    if res ~= GetCurrentResourceName() then return end
    local ped = PlayerPedId()
	RemoveWeaponFromPed(ped, `WEAPON_HATCHET`)
    FreezeEntityPosition(ped, false)
    ClearPedTasksImmediately(ped)
end)
