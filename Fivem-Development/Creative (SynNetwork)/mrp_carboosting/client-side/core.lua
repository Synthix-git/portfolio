-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
vSERVER = Tunnel.getInterface("boosting")

-----------------------------------------------------------------------------------------------------------------------------------------
-- STATE
-----------------------------------------------------------------------------------------------------------------------------------------
local CurrentClass    = 1
local Model           = ""
local Selected        = 1
local SpawnedVeh      = false
local spawning        = false
local Plate           = ""

local lastRequestAt   = 0
local requestCooldown = 8000 -- 8s (igual ao server)
local triedOnce       = false -- só tenta 1x por contrato

-- ENTREGA
local DropBlip      = 0
local InDelivery    = false
local DropPos       = nil
local DropPreShown  = false

-- BLIP STATE
local BoostBlip = 0

local function RemoveBoostBlip()
	if BoostBlip ~= 0 then
		RemoveBlip(BoostBlip)
		BoostBlip = 0
	end
end

-- helper 2D distance (cola perto do topo do ficheiro, com os helpers)
local function dist2D(ax,ay,bx,by)
	return ((ax - bx)^2 + (ay - by)^2) ^ 0.5
end

local function isRightVehicle(veh)
	if veh == 0 or not DoesEntityExist(veh) then return false end

	-- 1) tenta por plate (se existir)
	if Plate ~= "" then
		local p = (GetVehicleNumberPlateText(veh) or ""):gsub("%s+",""):upper()
		if p == (Plate:gsub("%s+",""):upper()) then
			return true
		end
	end

	-- 2) fallback por modelo
	if Model ~= "" then
		return GetEntityModel(veh) == GetHashKey(Model)
	end

	return false
end


local function SetBoostBlipAt(vec4, label)
	RemoveBoostBlip()
	BoostBlip = AddBlipForCoord(vec4.x, vec4.y, vec4.z)
	SetBlipSprite(BoostBlip, 225)
	SetBlipColour(BoostBlip, 5)
	SetBlipScale(BoostBlip, 0.6)
	SetBlipAsShortRange(BoostBlip, false)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString(label or "Veículo para Boosting")
	EndTextCommandSetBlipName(BoostBlip)
	SetBlipRoute(BoostBlip, true)
	SetBlipRouteColour(BoostBlip, 5)
end

local function RemoveDropBlip()
	if DropBlip ~= 0 then
		RemoveBlip(DropBlip)
		DropBlip = 0
	end
end

local function SetDropBlipAt(vec3pos)
	RemoveDropBlip()
	DropBlip = AddBlipForCoord(vec3pos.x, vec3pos.y, vec3pos.z)
	SetBlipSprite(DropBlip, 225)
	SetBlipColour(DropBlip, 2) -- verde
	SetBlipScale(DropBlip, 0.7)
	SetBlipAsShortRange(DropBlip, false)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString("Entrega Boosting")
	EndTextCommandSetBlipName(DropBlip)
	SetBlipRoute(DropBlip, true)
	SetBlipRouteColour(DropBlip, 2)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- PEDS (DISPATCH)
-----------------------------------------------------------------------------------------------------------------------------------------
local Peds = {
	"g_m_y_mexgang_01","g_m_y_lost_01","u_m_o_finguru_01","g_m_y_salvagoon_01","g_f_y_lost_01","a_m_y_business_02","s_m_m_postal_01",
	"g_m_y_korlieut_01","s_m_m_trucker_01","g_m_m_armboss_01","mp_m_shopkeep_01","ig_dale","u_m_y_baygor","cs_gurk","ig_casey",
	"s_m_y_garbage","a_m_o_ktown_01","a_f_y_eastsa_03"
}

-----------------------------------------------------------------------------------------------------------------------------------------
-- LOCATES (spawn do alvo) & DROPS (entrega)
-----------------------------------------------------------------------------------------------------------------------------------------
local Locates = {
	vec4(-625.45,-1657.5,25.63,243.78),
	vec4(-820.02,-1273.31,4.8,167.25),
	vec4(-819.41,-1199.15,6.74,138.9),
	vec4(-1048.27,-864.63,4.8,56.7),
	vec4(-699.77,-988.89,20.2,300.48),
	vec4(-477.73,-764.71,40.02,269.3),
	vec4(-276.35,-771.75,38.59,68.04),
	vec4(-323.24,-945.7,30.89,249.45),
	vec4(-318.42,-1112.96,22.76,340.16),
	vec4(145.06,-1145.18,29.1,184.26),
	vec4(240.51,-1413.74,30.4,328.82),
	vec4(400.88,-1648.56,29.1,320.32),
	vec4(571.65,-1922.32,24.52,119.06),
	vec4(1446.51,-2614.0,48.21,345.83),
	vec4(1278.73,-1796.5,43.64,107.72),
	vec4(862.91,-1383.57,25.95,34.02),
	vec4(156.73,-1451.26,28.95,138.9),
	vec4(88.01,-195.89,54.31,158.75),
	vec4(62.68,260.59,109.22,68.04),
	vec4(-469.97,542.25,120.68,357.17),
	vec4(-669.89,752.33,173.86,0.0),
	vec4(-1535.05,890.15,181.62,201.26),
	vec4(-3150.55,1096.16,20.52,283.47),
	vec4(-3249.57,987.82,12.3,2.84),
	vec4(-3052.24,600.0,7.16,289.14),
	vec4(-2139.52,-380.26,13.01,348.67),
	vec4(-1855.42,-623.86,10.99,48.19),
	vec4(-1703.92,-933.34,7.48,294.81),
	vec4(-1576.25,-1047.58,12.82,73.71),
	vec4(-891.67,-2059.35,9.12,42.52),
	vec4(-621.52,-2152.62,5.8,5.67),
	vec4(-363.52,-2273.8,7.41,14.18),
	vec4(-259.06,-2651.38,5.81,314.65),
	vec4(128.47,-2626.56,5.9,167.25),
	vec4(781.92,-2957.77,5.61,68.04),
	vec4(915.41,-2195.35,30.14,172.92),
	vec4(728.43,-2033.73,29.1,354.34),
	vec4(1145.1,-475.1,66.19,257.96),
	vec4(935.39,-54.52,78.57,56.7),
	vec4(615.57,614.44,128.72,68.04),
	vec4(672.45,245.19,93.75,56.7),
	vec4(446.95,260.66,103.02,68.04),
	vec4(90.35,485.94,147.49,206.93),
	vec4(226.83,680.87,189.31,104.89),
	vec4(320.08,494.93,152.39,286.3),
	vec4(505.98,-1843.29,27.38,124.73),
	vec4(313.21,-1940.86,24.45,48.19),
	vec4(197.28,-2027.34,18.08,345.83),
	vec4(154.9,-1881.0,23.44,65.2),
	vec4(709.92,-1401.71,26.17,286.3)
}

local DropLocs = {
	vec3(-324.36, -1530.85, 27.54),
	vec3(-180.58, -1328.61, 31.20),
	vec3(31.84, -1031.95, 29.47),
	vec3(496.99, -635.37, 24.89),
	vec3(121.87, -129.67, 54.84),
	vec3(-471.82, 72.96, 58.67),
	vec3(-1204.20, -715.69, 21.59),
	vec3(-743.19, -1021.66, 7.86),
	vec3(-576.55, -588.71, 25.31)

}

-----------------------------------------------------------------------------------------------------------------------------------------
-- UI
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("boosting:Open")
AddEventHandler("boosting:Open",function()
	SetNuiFocus(true,true)
	SetCursorLocation(0.5,0.5)
	SendNUIMessage({ Action = "Open", Payload = vSERVER.Experience() })
end)

RegisterNUICallback("Close",function(_,cb)
	SetNuiFocus(false,false)
	SetCursorLocation(0.5,0.5)
	cb("Ok")
end)

RegisterNUICallback("Active",   function(_,cb) cb(vSERVER.Actives()) end)
RegisterNUICallback("Pending",  function(_,cb) cb(vSERVER.Pendings()) end)
RegisterNUICallback("Accept",   function(d,cb) cb(vSERVER.Accept(d["Number"])) end)
RegisterNUICallback("Scratch",  function(d,cb) cb(vSERVER.Scratch(d["Number"])) end)
RegisterNUICallback("Decline",  function(d,cb) cb(vSERVER.Decline(d["Number"])) end)
RegisterNUICallback("Transfer", function(d,cb) cb(vSERVER.Transfer(d["Number"],d["Passport"])) end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- BOOSTING:ACTIVE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("boosting:Active")
AddEventHandler("boosting:Active",function(vehicleModel, receivedClass, fixedPlate)
	CurrentClass = receivedClass or 1
	SpawnedVeh   = false
	spawning     = false
	Model        = vehicleModel or ""
	Selected     = math.random(#Locates)
	Plate        = fixedPlate or ""
	triedOnce    = false

	InDelivery   = false
	DropPos      = nil
	DropPreShown = false

	if Model ~= "" then
		local loc = Locates[Selected]
		TriggerEvent("NotifyPush",{ code = 20, title = "Localização Veículo", x = loc.x, y = loc.y, z = loc.z, vehicle = VehicleName(Model), color = 44 })
		SetBoostBlipAt(loc, ("Alvo: %s (%s)"):format(VehicleName(Model), Plate ~= "" and Plate or "—"))
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- BOOSTING:RESET
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("boosting:Reset")
AddEventHandler("boosting:Reset",function()
	Model      = ""
	Plate      = ""
	SpawnedVeh = false
	spawning   = false
	triedOnce  = false

	InDelivery   = false
	DropPos      = nil
	DropPreShown = false

	SendNUIMessage({ Action = "Close" })
	RemoveBoostBlip()
	RemoveDropBlip()
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- Enumerate Vehicles (fallback para detetar por matrícula)
-----------------------------------------------------------------------------------------------------------------------------------------
local function EnumerateVehicles()
	return coroutine.wrap(function()
		local handle, veh = FindFirstVehicle()
		if not handle or handle == -1 then
			EndFindVehicle(handle)
			return
		end
		local ok
		repeat
			coroutine.yield(veh)
			ok, veh = FindNextVehicle(handle)
		until not ok
		EndFindVehicle(handle)
	end)
end

local function FindVehicleByPlateAround(center, radius, plateText)
	plateText = (plateText or ""):gsub("%s+", ""):upper()
	if plateText == "" then return nil end
	for veh in EnumerateVehicles() do
		if DoesEntityExist(veh) then
			local vpos = GetEntityCoords(veh)
			if #(vpos - center) <= radius then
				local p = GetVehicleNumberPlateText(veh) or ""
				p = p:gsub("%s+",""):upper()
				if p == plateText then
					return veh
				end
			end
		end
	end
	return nil
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- LOAD NETWORK
-----------------------------------------------------------------------------------------------------------------------------------------
local function LoadNetwork(netId, timeoutMs)
	timeoutMs = timeoutMs or 8000
	local endAt = GetGameTimer() + timeoutMs
	local entity = 0

	if netId and NetworkDoesEntityExistWithNetworkId(netId) then
		entity = NetToEnt(netId)
	end

	while (not DoesEntityExist(entity)) and GetGameTimer() < endAt do
		if netId and NetworkDoesEntityExistWithNetworkId(netId) then
			entity = NetToEnt(netId)
		end
		Wait(50)
	end

	return (DoesEntityExist(entity) and entity) or nil
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- DISPATCH PEDS (client-side)
-----------------------------------------------------------------------------------------------------------------------------------------
local function CreateDispatchPed(modelName, x, y, z)
	local mhash = GetHashKey(modelName)
	RequestModel(mhash)
	local tries = 0
	while not HasModelLoaded(mhash) and tries < 100 do
		tries = tries + 1
		Wait(10)
	end
	if not HasModelLoaded(mhash) then return nil end

	local ped = CreatePed(4, mhash, x, y, z, 0.0, true, true)
	SetModelAsNoLongerNeeded(mhash)
	return ped
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- THREAD: SPAWN DO ALVO
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		if not SpawnedVeh and not spawning and Model ~= "" and Plate ~= "" and not triedOnce then
			local ped  = PlayerPedId()
			local pPos = GetEntityCoords(ped)
			local loc  = Locates[Selected]

			if #(pPos - loc.xyz) <= 120.0 then
				spawning = true
				triedOnce = true

				CreateThread(function()
					local netId
					if (GetGameTimer() - lastRequestAt) >= requestCooldown then
						lastRequestAt = GetGameTimer()
						netId = vSERVER.CreateOrAttach(Plate, Model, CurrentClass, loc)
					end

					local veh
					if netId then
						local deadline = GetGameTimer() + 12000
						while GetGameTimer() < deadline do
							if NetworkDoesEntityExistWithNetworkId(netId) then
								veh = NetToEnt(netId)
								if DoesEntityExist(veh) then break end
							end
							Wait(100)
						end
					end

					if veh and DoesEntityExist(veh) then
						SpawnedVeh = veh

						SetVehicleHasBeenOwnedByPlayer(veh, true)
						SetVehicleNeedsToBeHotwired(veh, false)
						pcall(function()
							if DecorIsRegisteredAsType and DecorRegister then DecorRegister("Player_Vehicle",3) end
							DecorSetInt(veh,"Player_Vehicle",-1)
						end)
						SetVehicleOnGroundProperly(veh)
						SetVehRadioStation(veh,"OFF")

						SetVehicleModKit(veh,0)
						ToggleVehicleMod(veh,18,true)
						if GetNumVehicleMods(veh,11) > 0 then SetVehicleMod(veh,11,GetNumVehicleMods(veh,11)-1,false) end
						if GetNumVehicleMods(veh,12) > 0 then SetVehicleMod(veh,12,GetNumVehicleMods(veh,12)-1,false) end
						if GetNumVehicleMods(veh,13) > 0 then SetVehicleMod(veh,13,GetNumVehicleMods(veh,13)-1,false) end
						if GetNumVehicleMods(veh,15) > 0 then SetVehicleMod(veh,15,GetNumVehicleMods(veh,15)-1,false) end
					end

					spawning = false
				end)
			end
		end
		Wait(750)
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- MARKER/3D TEXT
-----------------------------------------------------------------------------------------------------------------------------------------
local function Draw3D(x,y,z,text)
	SetDrawOrigin(x,y,z,0)
	SetTextFont(4)
	SetTextProportional(0)
	SetTextScale(0.32,0.32)
	SetTextColour(255,255,255,215)
	SetTextCentre(true)
	BeginTextCommandDisplayText("STRING")
	AddTextComponentSubstringPlayerName(text)
	EndTextCommandDisplayText(0.0,0.0)
	ClearDrawOrigin()
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- THREAD: ENTREGA (proximidade -> marker -> tecla E -> server Complete)
-----------------------------------------------------------------------------------------------------------------------------------------
-- >>> SUBSTITUI A PARTIR DAQUI: THREAD: ENTREGA (proximidade -> marker -> AUTO COMPLETE)
local deliveringNow   = false
local lastDeliverTry  = 0
local deliverCooldown = 3500 -- ms, anti-spam
local stoppedSince    = 0

CreateThread(function()
	while true do
		local wait = 750

		if Model ~= "" and Plate ~= "" then
			local ped   = PlayerPedId()
			local loc   = Locates[Selected]
			local mePos = GetEntityCoords(ped)

			-- A) Mostrar drop por proximidade do spawn (antes de entrar no carro)
			if not InDelivery and not DropPreShown then
				local distToSpawn = #(mePos - loc.xyz)
				if distToSpawn <= 60.0 then
					local best, bestDist = nil, -1
					for _, p in ipairs(DropLocs) do
						local d = #(p - loc.xyz)
						if d > 800.0 and (bestDist < 0 or d < bestDist) then
							best, bestDist = p, d
						end
					end
					DropPos = best or DropLocs[ math.random(#DropLocs) ]
					SetDropBlipAt(DropPos)
					DropPreShown = true
					TriggerEvent("Notify","Boosting","<b>Entrega disponível</b>. Assim que pegares o carro, leva-o até ao ponto marcado.", "azul", 6000)
					RemoveBoostBlip()
					wait = 250
				end
			end

			-- B) Se não temos handle, tenta encontrar por plate na zona do spawn
			if not SpawnedVeh and Plate ~= "" then
				local maybe = FindVehicleByPlateAround(loc.xyz, 80.0, Plate)
				if maybe and DoesEntityExist(maybe) then
					SpawnedVeh = maybe
				end
			end

			-- C) Se entras no veículo correto, ativa entrega
			if not InDelivery then
				local veh = GetVehiclePedIsIn(ped,false)
				if veh ~= 0 and DoesEntityExist(veh) then
					local p = (GetVehicleNumberPlateText(veh) or ""):gsub("%s+",""):upper()
					if p == (Plate:gsub("%s+",""):upper()) then
						SpawnedVeh = veh
						InDelivery = true
						if not DropPos then
							local best, bestDist = nil, -1
							for _, pPos in ipairs(DropLocs) do
								local d = #(pPos - loc.xyz)
								if d > 800.0 and (bestDist < 0 or d < bestDist) then
									best, bestDist = pPos, d
								end
							end
							DropPos = best or DropLocs[ math.random(#DropLocs) ]
							SetDropBlipAt(DropPos)
						end
						TriggerEvent("Notify","Boosting","<b>Entrega iniciada</b>. Leva o veículo até ao ponto marcado.", "azul", 5000)
						wait = 250
					end
				end
			end
-- D) Marker e AUTO entrega (usa 2D, ignora Z)
if DropPos then
	local v = (SpawnedVeh and DoesEntityExist(SpawnedVeh)) and SpawnedVeh or 0
	local posRef = (v ~= 0) and GetEntityCoords(v) or mePos

	-- distância em 2D (x,y) para evitar erro de desnível/Z
	local d2 = dist2D(posRef.x, posRef.y, DropPos.x, DropPos.y)

	if d2 <= 18.0 then
		wait = 0
		-- marker visual (mantém Z original)
		DrawMarker(1, DropPos.x, DropPos.y, DropPos.z - 1.0, 0.0,0.0,0.0, 0.0,0.0,0.0, 4.5,4.5,1.2, 0,200,30,160, false,false,2,false,nil,nil,false)

		-- Requisitos para auto-entregar:
		-- * Estás no veículo correto
		-- * És o condutor
		-- * Velocidade baixa por ~0.8s
		local canAuto = false
		local veh = GetVehiclePedIsIn(ped,false)

		if veh ~= 0 and DoesEntityExist(veh) then
			if isRightVehicle(veh) then
    		if GetPedInVehicleSeat(veh,-1) == ped then
					local speed = GetEntitySpeed(veh) * 3.6 -- km/h
					if d2 <= 6.5 and speed <= 10.0 then
						-- tempo parado
						if stoppedSince == 0 then
							stoppedSince = GetGameTimer()
						end
						if (GetGameTimer() - stoppedSince) >= 800 then
							canAuto = true
						end
					else
						stoppedSince = 0
					end
				else
					stoppedSince = 0
				end
			else
				stoppedSince = 0
			end
		else
			stoppedSince = 0
		end

		-- AUTO COMPLETE (uma vez, com cooldown anti-spam)
		if canAuto and not deliveringNow and (GetGameTimer() - lastDeliverTry) >= deliverCooldown then
			deliveringNow  = true
			lastDeliverTry = GetGameTimer()

			local netId = NetworkGetNetworkIdFromEntity(GetVehiclePedIsIn(ped,false))
			CreateThread(function()
				local ok = vSERVER.Complete(netId, Plate)
				Wait(800)
				deliveringNow = false
			end)
		end
	else
		-- fora do raio, reset do “parado”
		stoppedSince = 0
	end
end

		end

		Wait(wait)
	end
end)
-- >>> ATÉ AQUI

-----------------------------------------------------------------------------------------------------------------------------------------
-- DISPATCH
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("boosting:Dispatch")
AddEventHandler("boosting:Dispatch",function()
	local me    = PlayerPedId()
	local mPos  = GetEntityCoords(me)

	for _=1,5 do
		local tries = 0
		local spawnX = mPos.x + math.random(-20,20)
		local spawnY = mPos.y + math.random(-20,20)
		local _, groundZ = GetGroundZFor_3dCoord(spawnX, spawnY, mPos.z, true)
		local ok, safe = GetSafeCoordForPed(spawnX, spawnY, groundZ, false, 16)

		while (not ok) and tries < 100 do
			tries = tries + 1
			spawnX = mPos.x + math.random(-20,20)
			spawnY = mPos.y + math.random(-20,20)
			_, groundZ = GetGroundZFor_3dCoord(spawnX, spawnY, mPos.z, true)
			ok, safe = GetSafeCoordForPed(spawnX, spawnY, groundZ, false, 16)
			Wait(0)
		end

		if ok and safe then
			local mdl = Peds[math.random(#Peds)]
			local ped = CreateDispatchPed(mdl, safe.x, safe.y, safe.z)
			if ped and DoesEntityExist(ped) then
				SetPedArmour(ped,100)
				SetPedAccuracy(ped,75)
				SetPedAlertness(ped,3)
				SetPedAsEnemy(ped,true)
				SetPedMaxHealth(ped,500)
				SetEntityHealth(ped,500)
				SetPedKeepTask(ped,true)
				SetPedCombatRange(ped,2)
				StopPedSpeaking(ped,true)
				SetPedCombatMovement(ped,2)
				DisablePedPainAudio(ped,true)
				SetPedPathAvoidFire(ped,true)
				SetPedConfigFlag(ped,208,true)
				SetPedSeeingRange(ped,10000.0)
				SetPedCanEvasiveDive(ped,false)
				SetPedHearingRange(ped,10000.0)
				SetPedDiesWhenInjured(ped,false)
				SetPedPathCanUseLadders(ped,true)
				SetPedFleeAttributes(ped,0,false)
				SetPedCombatAttributes(ped,46,true)
				SetPedFiringPattern(ped,0xC6EE6B4C)
				SetCanAttackFriendly(ped,true,false)
				SetPedSuffersCriticalHits(ped,false)
				SetPedPathCanUseClimbovers(ped,true)
				SetPedDropsWeaponsWhenDead(ped,false)
				SetPedEnableWeaponBlocking(ped,false)
				SetPedPathCanDropFromHeight(ped,false)

				GiveWeaponToPed(ped,GetHashKey("WEAPON_PISTOL_MK2"),-1,false,true)
				SetCurrentPedWeapon(ped,GetHashKey("WEAPON_PISTOL_MK2"),true)
				SetPedInfiniteAmmo(ped,true,GetHashKey("WEAPON_PISTOL_MK2"))

				AddRelationshipGroup("HATES_PLAYER")
				SetPedRelationshipGroupHash(ped,GetHashKey("HATES_PLAYER"))
				SetRelationshipBetweenGroups(5,GetHashKey("HATES_PLAYER"),GetHashKey("PLAYER"))
				SetRelationshipBetweenGroups(5,GetHashKey("PLAYER"),GetHashKey("HATES_PLAYER"))

				TaskCombatPed(ped, me, 0, 16)
				SetTimeout(1000,function()
					TaskWanderInArea(ped, safe.x, safe.y, safe.z, 25.0, 0.0, 0.0)
				end)
			end
		end
	end
end)
