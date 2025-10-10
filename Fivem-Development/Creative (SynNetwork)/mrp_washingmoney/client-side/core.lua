--[[
  washing - Money Wash Standalone
  Author: syn
]]

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONFIG
-----------------------------------------------------------------------------------------------------------------------------------------
local Config = {
	["Active"] = false,
	["Cooldown"] = GetGameTimer(),
	["Init"] = vector4(-25.1,-1490.83,30.36,141.74),
	["Washs"] = {
		vector3(155.33,-1047.89,29.25),
		vector3(335.53,-213.98,54.09),
		vector3(-1549.95,-419.39,41.99),
		vector3(-355.54,32.76,47.80),
		vector3(1198.11,2726.54,38.00),
		vector3(-1245.94,-257.20,39.06),
		vector3(19.28,-1414.08,29.37),
		vector3(1263.22,-364.29,69.05),
		vector3(368.29,338.96,103.26),
		vector3(-3248.30,990.65,12.49),
		vector3(542.10,2651.06,42.31),
		vector3(2659.39,3276.89,55.23),
		vector3(-1814.43,798.06,138.29),
		vector3(-112.81,6483.95,31.46),
		vector3(1562.97,6466.01,23.88)
	}
}

local MIN_WASH = 150000
local MAX_WASH = 400000 -- teto inicial (server ainda limita pelo nº de polícias)

-- estado
local currentIndex = 1
local currentBlip = nil
local lastMarkerThread = nil

-----------------------------------------------------------------------------------------------------------------------------------------
-- TUNNEL
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP     = Proxy.getInterface("vRP")
vSERVER = Tunnel.getInterface("washing")

-----------------------------------------------------------------------------------------------------------------------------------------
-- UTILS
-----------------------------------------------------------------------------------------------------------------------------------------
local function CleanPoint()
	if currentBlip and DoesBlipExist(currentBlip) then
		SetBlipRoute(currentBlip,false)   -- ⬅ desliga a rota do GPS
		RemoveBlip(currentBlip)
	end
	currentBlip = nil
end


local function dist2(a,b) return #(vector2(a.x,a.y) - vector2(b.x,b.y)) end

local function SetRoute(coords)
	currentBlip = AddBlipForCoord(coords)
	SetBlipSprite(currentBlip,434)
	SetBlipDisplay(currentBlip,4)
	SetBlipAsShortRange(currentBlip,true)
	SetBlipColour(currentBlip,2)
	SetBlipScale(currentBlip,0.75)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString("Lavagem de Dinheiro")
	EndTextCommandSetBlipName(currentBlip)

	--  mostra a rota no mapa, sem waypoint do player
	SetBlipRoute(currentBlip,true)
	SetBlipRouteColour(currentBlip,2)

end


-----------------------------------------------------------------------------------------------------------------------------------------
-- FREEZE DO VEÍCULO (para o vRP.Request do informante)
-----------------------------------------------------------------------------------------------------------------------------------------

local WASH_FREEZE = false
local WASH_FROZEN_ENTITY = 0

RegisterNetEvent("washing:FreezeVehicle")
AddEventHandler("washing:FreezeVehicle", function(enable)
    WASH_FREEZE = enable and true or false

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped,false)

    -- Descongela o que estiver guardado de chamadas anteriores
    if not WASH_FREEZE then
        if WASH_FROZEN_ENTITY ~= 0 and DoesEntityExist(WASH_FROZEN_ENTITY) then
            FreezeEntityPosition(WASH_FROZEN_ENTITY,false)
            if IsEntityAVehicle(WASH_FROZEN_ENTITY) then
                SetVehicleDoorsLocked(WASH_FROZEN_ENTITY,1)
            end
        end
        WASH_FROZEN_ENTITY = 0
        return
    end

    -- Congela veículo se estiver dentro, senão congela o ped
    if veh ~= 0 then
        WASH_FROZEN_ENTITY = veh
        FreezeEntityPosition(veh,true)
        SetVehicleDoorsLocked(veh,2)
    else
        WASH_FROZEN_ENTITY = ped
        FreezeEntityPosition(ped,true)
    end

    -- Loop único que respeita o flag global
    CreateThread(function()
        while WASH_FREEZE do
            DisableControlAction(0,75,true)  -- sair do veículo
            DisableControlAction(0,63,true)  -- virar esquerda
            DisableControlAction(0,64,true)  -- virar direita
            DisableControlAction(0,71,true)  -- acelerar
            DisableControlAction(0,72,true)  -- travar
            DisableControlAction(0,21,true)  -- sprint
            DisableControlAction(0,32,true)  -- W
            DisableControlAction(0,33,true)  -- S
            DisableControlAction(0,34,true)  -- A
            DisableControlAction(0,35,true)  -- D
            Wait(0)
        end
        -- segurança extra ao sair do loop
        if WASH_FROZEN_ENTITY ~= 0 and DoesEntityExist(WASH_FROZEN_ENTITY) then
            FreezeEntityPosition(WASH_FROZEN_ENTITY,false)
            if IsEntityAVehicle(WASH_FROZEN_ENTITY) then
                SetVehicleDoorsLocked(WASH_FROZEN_ENTITY,1)
            end
        end
        WASH_FROZEN_ENTITY = 0
    end)
end)

-- Cleanup ao parar recurso (defensivo)
AddEventHandler("onResourceStop", function(res)
    if res == GetCurrentResourceName() then
        TriggerEvent("washing:FreezeVehicle", false)
    end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- MARKER LOOP PARA UM PONTO (drive-thru)
-----------------------------------------------------------------------------------------------------------------------------------------
local function MakeNextPoint()
	CleanPoint()

	if currentIndex > #Config["Washs"] then currentIndex = 1 end
	local coords = Config["Washs"][currentIndex]
	SetRoute(coords)

	lastMarkerThread = true
	CreateThread(function()
		while Config["Active"] and lastMarkerThread do
			local ped = PlayerPedId()
			local pcoords = GetEntityCoords(ped)

			-- marker verde
			DrawMarker(1, coords.x, coords.y, coords.z-1.0, 0.0,0.0,0.0, 0.0,0.0,0.0, 3.5,3.5,1.0, 0,255,0,120, false,true,2, nil,nil,false)

			-- entrou com carro por cima do marker?
			if #(pcoords - coords) <= 4.0 and IsPedInAnyVehicle(ped) then
				local status, finished = vSERVER.StartSpot(MIN_WASH, MAX_WASH)
				-- avança sempre o ponto (o server responde se acabou sujo)
				currentIndex = currentIndex + 1
				if finished then
					StopJob()
				else
					MakeNextPoint()
				end
				break
			end

			Wait(0)
		end
	end)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- START/STOP
-----------------------------------------------------------------------------------------------------------------------------------------
function StopJob()
	lastMarkerThread = nil
	CleanPoint()
	Config["Active"] = false
	TriggerEvent("Notify","Washing Co.","Você finalizou a sua jornada de trabalho.","verde",5000)
end

RegisterNetEvent("washing:ForceEndService")
AddEventHandler("washing:ForceEndService",function()
	if Config["Active"] then StopJob() end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- INIT BUTTON (apenas iniciar)
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	exports["target"]:AddBoxZone("MoneyWash",Config["Init"].xyz,0.75,0.75,{
		name = "MoneyWash",
		heading = Config["Init"].w,
		minZ = Config["Init"].z - 1.0,
		maxZ = Config["Init"].z + 1.0
	},{
		Distance = 1.75,
		options = {
			{ event = "washing:Init", label = "Iniciar",  tunnel = "client" }
		}
	})
end)

AddEventHandler("washing:Init",function()
	if Config["Active"] then
		StopJob()
	else
		if Config["Cooldown"] <= GetGameTimer() then
			Config["Cooldown"] = GetGameTimer() + (30 * 60000) -- 30 min
			Config["Active"] = true
			currentIndex = 1

			-- Ordena rotas por proximidade inicial (2D)
			local p = PlayerPedId()
			local start = GetEntityCoords(p)
			table.sort(Config["Washs"], function(p1,p2)
				local d1 = #(vector2(start.x,start.y) - vector2(p1.x,p1.y))
				local d2 = #(vector2(start.x,start.y) - vector2(p2.x,p2.y))
				return d1 < d2
			end)

			TriggerEvent("Notify","Washing Co.","Jornada iniciada. Boa sorte.","verde",5000)
			MakeNextPoint()
		else
			TriggerEvent("Notify","Aviso","Aguarde seu tempo de descanso.","amarelo",5000)
		end
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- LIMPEZA EM STOP RECURSO
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("onResourceStop",function(res)
	if res == GetCurrentResourceName() then
		CleanPoint()
	end
end)
