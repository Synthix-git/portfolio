local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")
vRP = Proxy.getInterface("vRP")

Creative = {}
Tunnel.bindInterface("taxi", Creative)
vSERVER = Tunnel.getInterface("taxi")

local inService = false
local vehicle = nil
local pickup = nil
local dropoff = nil
local onDelivery = false
local Blip = nil

local pickUpCoords = {
	{ -1966.18,-500.69,11.83 },{ -1649.93,-451.97,38.89 },{ -1375.14,-966.56,9.01 },{ -1253.14,-1314.72,3.99 },
	{ -1106.17,-1689.41,4.31 },{ -609.65,-1803.2,23.32 },{ -390.55,-1852.9,20.99 },{ -224.98,-2045.15,27.62 },
	{ 82.58,-1917.2,20.88 },{ 496.69,-1875.78,26.25 },{ 280.62,-2106.97,16.09 },{ 784.42,-2132.83,29.28 },
	{ 953.75,-1755.3,31.19 },{ 1307.21,-1718.47,54.31 },{ 502.32,-1725.65,29.27 },{ 789.17,-1392.76,27.04 },
	{ 1225.93,-1345.74,34.96 },{ 817.56,-1083.69,28.46 },{ 33.58,-1520.65,29.27 },{ -70.78,-1084.91,26.74 },
	{ -620.99,-921.48,23.3 },{ -741.52,-687.9,30.25 },{ -1227.9,-573.09,27.45 },{ -1311.16,228.57,58.72 },
	{ -1527.34,440.21,108.95 },{ -1062.61,447.58,74.41 },{ -515.49,423.41,97.09 },{ -755.98,-35.56,37.68 },
	{ -484.83,-386.07,34.22 },{ -48.76,-261.29,45.81 },{ -105.61,-612.03,36.08 },{ 239.69,-370.36,44.28 },
	{ 390.37,-83.02,67.75 },{ 709.88,53.65,83.95 },{ 385.57,312.39,103.14 },{ 317.75,570.27,154.45 },
	{ 247.24,-833.74,29.77 },{ 1150.78,-983.26,46.03 },{ 985.68,-688.99,57.39 },{ 1275.91,-420.3,69.05 },
	{ 1178.63,-286.08,69.0 },{ 917.39,48.98,80.9 }
}

local function startRoute()
	local pickupIndex = math.random(#pickUpCoords)
	pickup = pickUpCoords[pickupIndex]
	local dropoffIndex
	repeat
		dropoffIndex = math.random(#pickUpCoords)
	until dropoffIndex ~= pickupIndex
	dropoff = pickUpCoords[dropoffIndex]

	if DoesBlipExist(Blip) then RemoveBlip(Blip) end

	Blip = AddBlipForCoord(pickup[1], pickup[2], pickup[3])
	SetBlipSprite(Blip, 280)
	SetBlipColour(Blip, 5)
	SetBlipRoute(Blip, true)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString("Cliente")
	EndTextCommandSetBlipName(Blip)
end

RegisterNetEvent("taxi:startService")
AddEventHandler("taxi:startService", function()
	if inService then
		TriggerEvent("Notify", "Sistema", "❗ Já estás em serviço de táxi!", "amarelo", 5000)
		return
	end
	inService = true
	LocalPlayer["state"]:set("taxi", true)
	TriggerEvent("Notify", "Sistema", "✅ Entraste em serviço de táxi. Entra no veículo para começar.", "verde", 5000)
end)

RegisterNetEvent("taxi:endService")
AddEventHandler("taxi:endService", function()
	if not inService then
		TriggerEvent("Notify", "Sistema", "❗ Não estás em serviço de táxi!", "amarelo", 5000)
		return
	end
	inService = false
	LocalPlayer["state"]:set("taxi", false)
	if DoesBlipExist(Blip) then RemoveBlip(Blip) end
	pickup = nil
	dropoff = nil
	onDelivery = false
	if vehicle and DoesEntityExist(vehicle) then
		FreezeEntityPosition(vehicle, false)
	end
	TriggerEvent("Notify", "Sistema", "❌ Saíste do serviço de táxi.", "amarelo", 5000)
end)


RegisterNetEvent("taxi:ForceEndService")
AddEventHandler("taxi:ForceEndService", function()
	if not inService then
		return -- não está em serviço, não faz nada
	end

	inService = false
	LocalPlayer["state"]:set("taxi", false)

	if DoesBlipExist(Blip) then
		RemoveBlip(Blip)
		Blip = nil
	end

	pickup = nil
	dropoff = nil
	onDelivery = false

	if vehicle and DoesEntityExist(vehicle) then
		FreezeEntityPosition(vehicle, false)
	end
end)


-- Gera rotas automaticamente
CreateThread(function()
	while true do
		Wait(2000)
		if inService and not pickup and not onDelivery then
			local ped = PlayerPedId()
			if IsPedInAnyVehicle(ped, false) then
				startRoute()
			end
		end
	end
end)

-- Lógica principal da entrega
CreateThread(function()
	while true do
		local ped = PlayerPedId()
		vehicle = GetVehiclePedIsIn(ped, false)
		local coords = GetEntityCoords(ped)

		local waitTime = 500 -- Default wait time

		if inService and pickup and not onDelivery then
			local distToPickup = #(coords - vec3(pickup[1], pickup[2], pickup[3]))
			if distToPickup <= 50.0 then -- Draw marker only if close
				DrawMarker(1, pickup[1], pickup[2], pickup[3] - 1, 0, 0, 0, 0, 0, 0, 2.5, 2.5, 1.0, 0, 102, 255, 100, false, false, false, false)
				waitTime = 1 -- Reduce wait time when close to pickup
			end

			if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped and distToPickup <= 3.0 then
				FreezeEntityPosition(vehicle, true)
				TriggerEvent("Progress", "A entrar cliente...", 5000)
				Wait(5000)
				TriggerEvent("Notify", "Cliente", "🟢 Passageiro entrou. Leva-o ao destino!", "verde", 5000)
				FreezeEntityPosition(vehicle, false)

				onDelivery = true
				SetNewWaypoint(dropoff[1], dropoff[2])

				if DoesBlipExist(Blip) then RemoveBlip(Blip) end
				Blip = AddBlipForCoord(dropoff[1], dropoff[2], dropoff[3])
				SetBlipSprite(Blip, 280)
				SetBlipColour(Blip, 2)
				SetBlipRoute(Blip, true)
				BeginTextCommandSetBlipName("STRING")
				AddTextComponentString("Destino")
				EndTextCommandSetBlipName(Blip)
			end
		end

		if inService and onDelivery and dropoff then
			local distToDropoff = #(coords - vec3(dropoff[1], dropoff[2], dropoff[3]))
			if distToDropoff <= 50.0 then -- Draw marker only if close
				DrawMarker(1, dropoff[1], dropoff[2], dropoff[3] - 1, 0, 0, 0, 0, 0, 0, 2.5, 2.5, 1.0, 0, 255, 0, 100, false, false, false, false)
				waitTime = 1 -- Reduce wait time when close to dropoff
			end

			if distToDropoff <= 5.0 then
				FreezeEntityPosition(vehicle, true)
				TriggerEvent("Progress", "A sair cliente...", 5000)
				Wait(5000)
				TriggerEvent("Notify", "Cliente", "✅ Cliente chegou ao destino. Aguarda nova chamada!", "verde", 5000)
				FreezeEntityPosition(vehicle, false)

				if DoesBlipExist(Blip) then RemoveBlip(Blip) end
				vSERVER.FinishRide()
				pickup = nil
				dropoff = nil
				onDelivery = false
				Wait(3000)
				startRoute()
			end
		end
		Wait(waitTime)
	end
end)

-- Target de serviço
CreateThread(function()
	exports["target"]:AddCircleZone("taxi:service", vec3(901.92, -167.98, 74.07), 1.5, {
		name = "taxi:service",
		heading = 3374176
	}, {
		shop = "taxi",
		Distance = 1.5,
		options = {
			{ event = "taxi:startService", label = "Entrar em Serviço", tunnel = "client" },
			{ event = "taxi:endService", label = "Sair de Serviço", tunnel = "client" }
		}
	})
end)
