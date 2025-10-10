------------------------------------------------
-- WATER DETECTION HELPERS
------------------------------------------------
if not HasWaterQuadAt2D then
	function HasWaterQuadAt2D(x, y)
		local idx = Citizen.InvokeNative(0x17321452, x + 0.0, y + 0.0, Citizen.ResultAsInteger())
		return (idx ~= nil and idx ~= -1)
	end
end

if not HasWaterAt then
	function HasWaterAt(x, y, z)
		local hit = TestProbeAgainstWater(x + 0.0, y + 0.0, z + 15.0, x + 0.0, y + 0.0, z - 25.0)
		if hit then
			return true
		end
		return false
	end
end

local function _shoreAccessible(x, y, z)
	local ok, waterZ = GetWaterHeightNoWaves(x + 0.0, y + 0.0, z + 1.0, Citizen.ReturnResultAnyway(), 0.0)
	if not ok then
		return false
	end
	local _, groundZ = GetGroundZFor_3dCoord(x + 0.0, y + 0.0, z + 10.0, 0)
	return (not groundZ) or (groundZ < (waterZ - 0.5))
end

if not IsNearWater then
	function IsNearWater(x, y, z, radius, samples)
		radius = radius or 6.0
		samples = samples or 10
		for i = 1, samples do
			local ang = (i / samples) * 6.2831853
			local px = x + math.cos(ang) * radius
			local py = y + math.sin(ang) * radius
			if HasWaterAt(px, py, z) and _shoreAccessible(px, py, z) then
				return true
			end
		end
		return false
	end
end

if not ForwardHasWater then
	function ForwardHasWater(ent, dist)
		dist = dist or 10.0
		local ahead = GetOffsetFromEntityInWorldCoords(ent, 0.0, dist, 0.0)
		return HasWaterAt(ahead.x, ahead.y, ahead.z)
	end
end

---------------------------------------------------------------------
-- Funções usadas pelo server (pesca)
---------------------------------------------------------------------
function Creative.Fishing()
	local ped = PlayerPedId()
	local p = GetEntityCoords(ped)

	if HasWaterAt(p.x, p.y, p.z) then
		return true
	end
	if IsEntityInWater(ped) or ((GetEntitySubmergedLevel(ped) or 0.0) > 0.02) then
		return true
	end
	if IsNearWater(p.x, p.y, p.z, 6.0, 12) then
		return true
	end
	if IsPedInAnyVehicle(ped) then
		local veh = GetVehiclePedIsIn(ped, false)
		if veh ~= 0 and GetVehicleClass(veh) == 14 then
			if ForwardHasWater(veh, 12.0) or HasWaterQuadAt2D(p.x, p.y) then
				return true
			end
		end
	end
	return false
end

function Creative.FishingAllowed()
	return Creative.Fishing()
end

---------------------------------------------------------------------
-- Debug opcional
---------------------------------------------------------------------
RegisterCommand("fishdebug", function()
	local ped = PlayerPedId()
	local p = GetEntityCoords(ped)
	local quad = HasWaterQuadAt2D(p.x, p.y)
	local ray = HasWaterAt(p.x, p.y, p.z)
	local near = IsNearWater(p.x, p.y, p.z, 8.0, 12)
	local inBoat, boatAhead = false, false
	if IsPedInAnyVehicle(ped) then
		local veh = GetVehiclePedIsIn(ped, false)
		if veh ~= 0 and GetVehicleClass(veh) == 14 then
			inBoat = true
			boatAhead = ForwardHasWater(veh, 12.0)
		end
	end
	TriggerEvent(
		"Notify",
		"Debug",
		string.format(
			"quad=%s | ray=%s | near=%s | boat=%s | boatAhead=%s",
			tostring(quad),
			tostring(ray),
			tostring(near),
			tostring(inBoat),
			tostring(boatAhead)
		),
		"azul",
		8000
	)
end)

---------------------------------------------------------------------
-- Stop pesca (mantido)
---------------------------------------------------------------------
RegisterNetEvent("fishing:stop")
AddEventHandler("fishing:stop", function()
	local ped = PlayerPedId()
	ClearPedTasksImmediately(ped)
	Wait(0)
	ClearPedSecondaryTask(ped)
	local model = GetHashKey("prop_fishing_rod_01")
	local pcoords = GetEntityCoords(ped)
	local obj = GetClosestObjectOfType(pcoords.x, pcoords.y, pcoords.z, 3.0, model, false, false, false)
	if obj and obj ~= 0 then
		SetEntityAsMissionEntity(obj, true, true)
		DetachEntity(obj, true, true)
		DeleteObject(obj)
		DeleteEntity(obj)
	end
end)
