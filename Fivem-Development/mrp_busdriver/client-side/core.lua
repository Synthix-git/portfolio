-----------------------------------------------------------------------------------------------------------------------------------------
-- CONFIG
-----------------------------------------------------------------------------------------------------------------------------------------
local PaymentPerStop = 5000
local SalaryTime = 600000
local ServicePoint = { 453.55,-602.41,28.59,283.47 } -- único ponto
local RoutePoints = {
	{ 309.95, -760.52, 30.09 },
	{ 69.59, -974.80, 30.14 },
	{ 95.00, -634.89, 45.02 },
	{ 58.27, -283.32, 48.20 }
}

-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")
vRP = Proxy.getInterface("vRP")
vSERVER = Tunnel.getInterface("bus")

-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIÁVEIS
-----------------------------------------------------------------------------------------------------------------------------------------
local onService = false
local currentStop = 1
local blip = nil
local vehicle = nil

-----------------------------------------------------------------------------------------------------------------------------------------
-- TARGET
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	exports["target"]:AddCircleZone("bus:service", vec3(ServicePoint[1],ServicePoint[2],ServicePoint[3]), 1.5, {
		name = "bus:service",
		heading = 3374176
	}, {
		shop = "bus",
		Distance = 1.5,
		options = {
			{
				event = "bus:startService",
				label = "Entrar em Serviço",
				tunnel = "client"
			},
			{
				event = "bus:endService",
				label = "Sair de Serviço",
				tunnel = "client"
			}
		}
	})
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- ENTRAR EM SERVIÇO
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("bus:startService")
AddEventHandler("bus:startService", function()
	SetNuiFocus(false,false)

	if onService then
		TriggerEvent("Notify", "Sistema", "❌ Já estás em serviço.", "amarelo", 5000)
		return
	end

	onService = true
	currentStop = 1
	vehicle = nil

	TriggerEvent("Notify", "Sistema", "✅ Entraste em serviço de motorista. Vai buscar o autocarro!", "verde", 5000)
	createNextBlip()
	startSalaryTimer()
	runRoute()
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- SAIR DE SERVIÇO
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("bus:endService")
AddEventHandler("bus:endService", function()
	SetNuiFocus(false,false)

	if not onService then
		TriggerEvent("Notify", "Sistema", "❌ Não estás em serviço.", "vermelho", 5000)
		return
	end

	onService = false
	if blip then RemoveBlip(blip) end
	blip = nil
	currentStop = 1
	vehicle = nil

	TriggerEvent("Notify", "Sistema", "❌ Saíste de serviço de motorista.", "amarelo", 5000)
end)


RegisterNetEvent("bus:ForceEndService")
AddEventHandler("bus:ForceEndService", function()
    SetNuiFocus(false,false)

    if blip then RemoveBlip(blip) blip = nil end
    if routeBlip then RemoveBlip(routeBlip) routeBlip = nil end
    if markerId then RemoveBlip(markerId) markerId = nil end

    onService = false
    currentStop = 1
    vehicle = nil

end)


-----------------------------------------------------------------------------------------------------------------------------------------
-- SALÁRIO POR TEMPO
-----------------------------------------------------------------------------------------------------------------------------------------
function startSalaryTimer()
	CreateThread(function()
		while onService do
			Wait(SalaryTime)
			if onService then
				vSERVER.Salary()
			end
		end
	end)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- CRIAR BLIP
-----------------------------------------------------------------------------------------------------------------------------------------
function createNextBlip()
	if blip then RemoveBlip(blip) end
	local pos = RoutePoints[currentStop]
	blip = AddBlipForCoord(pos[1], pos[2], pos[3])
	SetBlipSprite(blip, 1)
	SetBlipColour(blip, 3)
	SetBlipScale(blip, 0.6)
	SetBlipRoute(blip, true)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString("Paragem")
	EndTextCommandSetBlipName(blip)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- ROTA
-----------------------------------------------------------------------------------------------------------------------------------------
function runRoute()
	CreateThread(function()
		while onService do
			local ped = PlayerPedId()

			if not IsPedInAnyVehicle(ped) then
				Wait(1000)
			else
				local veh = GetVehiclePedIsIn(ped)
				if GetPedInVehicleSeat(veh, -1) == ped then
					vehicle = veh
					local coords = GetEntityCoords(ped)
					local stopPos = vec3(table.unpack(RoutePoints[currentStop]))
					local distance = #(coords - stopPos)

					if distance <= 30.0 then
						DrawMarker(2, stopPos.x, stopPos.y, stopPos.z - 1.0, 0, 0, 0, 0, 180, 0, 2.5, 2.5, 1.0, 0, 122, 255, 200, 0, 0, 0, 0)
					end

					if distance <= 5.0 then
						FreezeEntityPosition(vehicle, true)
						openBusDoors()

						TriggerEvent("Notify", "Sistema", "🚌 À espera de passageiros...", "azul", 5000)
						Wait(5000)

						vSERVER.Payment(PaymentPerStop)

						closeBusDoors()
						FreezeEntityPosition(vehicle, false)

						currentStop = currentStop + 1
						if currentStop > #RoutePoints then currentStop = 1 end
						createNextBlip()
					end
				end
			end

			Wait(1)
		end
	end)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- PORTAS
-----------------------------------------------------------------------------------------------------------------------------------------
function openBusDoors()
	for i = 0, 3 do
		SetVehicleDoorOpen(vehicle, i, false, false)
	end
end

function closeBusDoors()
	for i = 0, 3 do
		SetVehicleDoorShut(vehicle, i, false)
	end
end
