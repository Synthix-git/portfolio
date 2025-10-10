-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP + BIND
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")
vRP = Proxy.getInterface("vRP")

Creative = Creative or {}
Tunnel.bindInterface("inventory", Creative) -- <- para o server chamar vCLIENT.*

-----------------------------------------------------------------------------------------------------------------------------------------
-- WEAPON HELPERS EXPOSTOS AO SERVER
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.CheckWeapon(weaponName) -- tem a arma (possui)
	local ped = PlayerPedId()
	return HasPedGotWeapon(ped, GetHashKey(weaponName), false)
end

function Creative.IsSelectedWeapon(weaponName) -- tem e ESTÁ equipada (em mãos)
	local ped = PlayerPedId()
	local hash = GetHashKey(weaponName)
	if not HasPedGotWeapon(ped, hash, false) then
		return false
	end
	return GetSelectedPedWeapon(ped) == hash
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- STATE
-----------------------------------------------------------------------------------------------------------------------------------------
local Model, Entity, AnimalBlip = nil, nil, nil

-----------------------------------------------------------------------------------------------------------------------------------------
-- ANIMALS LIST
-----------------------------------------------------------------------------------------------------------------------------------------
local Animals = { "deer", "boar", "mtlion", "coyote" }

-----------------------------------------------------------------------------------------------------------------------------------------
-- PUBLIC: CHECK RATION
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.CheckRation()
	if not Entity or not DoesEntityExist(Entity) then
		return false
	end
	return true
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- PUBLIC: ANIMALS (RETURN HANDLES)
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Animals()
	return Entity, Model
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- TARGET: ESFOLAR (robusto: aceita vários formatos e tem fallback por proximidade)
-----------------------------------------------------------------------------------------------------------------------------------------
local AnimalModesByHash = {
	[GetHashKey("a_c_deer")] = "deer",
	[GetHashKey("a_c_boar")] = "boar",
	[GetHashKey("a_c_mtlion")] = "mtlion",
	[GetHashKey("a_c_coyote")] = "coyote",
}

local function resolveAnimalModeFromEntity(ent)
	if not ent or not DoesEntityExist(ent) then
		return nil
	end
	return AnimalModesByHash[GetEntityModel(ent)]
end

local function extractEntityFromHit(hit)
	-- Alguns targets enviam diretamente o handle (number)
	if type(hit) == "number" then
		return hit
	end
	-- Outros enviam table com vários nomes possíveis
	if type(hit) == "table" then
		return hit.entity or hit.Entity or hit.ped or hit.Ped or hit[1]
	end
	return nil
end

local function findNearestDeadAnimal(radius)
	local ped = PlayerPedId()
	local pCoords = GetEntityCoords(ped)
	local nearest, bestDist = nil, radius + 0.001
	-- Game pool é custoso; apenas executa scans mais espaçados.
	local peds = GetGamePool and GetGamePool("CPed") or {}
	for i = 1, #peds do
		local ent = peds[i]
		if DoesEntityExist(ent) and not IsPedAPlayer(ent) then
			local hash = GetEntityModel(ent)
			if AnimalModesByHash[hash] then
				local epos = GetEntityCoords(ent)
				local d2 = (pCoords.x - epos.x) * (pCoords.x - epos.x) + (pCoords.y - epos.y) * (pCoords.y - epos.y) + (pCoords.z - epos.z) * (pCoords.z - epos.z)
				if d2 <= (radius * radius) then
					local dead = IsPedDeadOrDying(ent, true) or (GetEntityHealth(ent) <= 0)
					if dead and d2 < (bestDist * bestDist) then
						nearest, bestDist = ent, math.sqrt(d2)
					end
				end
			end
		end
	end
	return nearest
end

RegisterNetEvent("hunting:Skin")
AddEventHandler("hunting:Skin", function(hit)
	local ent = extractEntityFromHit(hit) or Entity

	-- Se o target não passou nada, tenta encontrar a carcaça mais próxima (até 5m)
	if not ent or not DoesEntityExist(ent) then
		ent = findNearestDeadAnimal(5.0)
	end

	if not ent or not DoesEntityExist(ent) then
		TriggerEvent("Notify", "Aviso", "Nenhuma carcaça próxima.", "amarelo", 4000)
		return
	end

	local dead = IsPedDeadOrDying(ent, true) or (GetEntityHealth(ent) <= 0)
	if not dead then
		TriggerEvent("Notify", "Aviso", "O animal ainda está vivo.", "amarelo", 4000)
		return
	end

	-- distância segura (aumentei para 4m para ser menos sensível)
	local ped = PlayerPedId()
	if #(GetEntityCoords(ped) - GetEntityCoords(ent)) > 4.0 then
		TriggerEvent("Notify", "Aviso", "Aproxime-se mais da carcaça.", "amarelo", 4000)
		return
	end

	local netId = NetworkGetNetworkIdFromEntity(ent)
	if not netId or netId == 0 then
		TriggerEvent("Notify", "Aviso", "Falha ao identificar a carcaça.", "amarelo", 4000)
		return
	end

	local mode = resolveAnimalModeFromEntity(ent) or select(2, Creative.Animals()) or "deer"

	-- lock opcional
	TriggerEvent("inventory:ActionLock", true)

	-- chama o server com os dados certos
	TriggerServerEvent("inventory:Animals", { net = netId, mode = mode })
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:RATION (SPAWN DO ANIMAL)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("inventory:Ration")
AddEventHandler("inventory:Ration", function()
	-- limpa alvo anterior se existir
	if Entity and DoesEntityExist(Entity) then
		if AnimalBlip then
			RemoveBlip(AnimalBlip)
			AnimalBlip = nil
		end
		DeleteEntity(Entity)
		Entity, Model = nil, nil
	end

	local Ped = PlayerPedId()
	local pCoords = GetEntityCoords(Ped)
	Model = Animals[math.random(#Animals)]

	local cooldown = 0
	local spawnX = pCoords.x + math.random(-75, 75)
	local spawnY = pCoords.y + math.random(-75, 75)
	local hitZ, groundZ = GetGroundZFor_3dCoord(spawnX, spawnY, pCoords.z, true)
	local hitSafe, safeCoords = GetSafeCoordForPed(spawnX, spawnY, groundZ, false, 16)

	repeat
		cooldown = cooldown + 1
		spawnX = pCoords.x + math.random(-75, 75)
		spawnY = pCoords.y + math.random(-75, 75)
		hitZ, groundZ = GetGroundZFor_3dCoord(spawnX, spawnY, pCoords.z, true)
		hitSafe, safeCoords = GetSafeCoordForPed(spawnX, spawnY, groundZ, false, 16)
	until (hitZ and hitSafe) or cooldown >= 100

	if not (hitZ and hitSafe) then
		return
	end

	-- usa o teu helper server-side; se não tiveres, cria via CreatePed client
	local netId = vRPS.CreateModels("a_c_" .. Model, safeCoords.x, safeCoords.y, safeCoords.z)
	if not netId then
		return
	end

	SetTimeout(2500, function()
		Entity = LoadNetwork(netId)
		if not Entity then
			return
		end

		-- AI/flags
		SetPedAlertness(Entity, 3)
		SetPedPathAvoidFire(Entity, true)
		DisablePedPainAudio(Entity, true)
		SetPedFleeAttributes(Entity, 0, false)
		SetPedPathCanUseLadders(Entity, true)
		SetPedSeeingRange(Entity, 10000.0)
		SetPedHearingRange(Entity, 10000.0)
		SetPedDiesWhenInjured(Entity, true)
		SetPedPathCanUseClimbovers(Entity, true)
		SetPedPathCanDropFromHeight(Entity, true)
		SetPedCombatAttributes(Entity, 5, true)
		SetPedCombatAttributes(Entity, 2, true)
		SetPedCombatAttributes(Entity, 1, true)
		SetPedCombatAttributes(Entity, 16, true)
		SetPedCombatAttributes(Entity, 46, true)
		SetPedCombatAttributes(Entity, 26, true)
		SetPedCombatAttributes(Entity, 3, false)
		SetCanAttackFriendly(Entity, false, true)
		SetPedSuffersCriticalHits(Entity, false)
		SetPedEnableWeaponBlocking(Entity, true)
		SetPedDropsWeaponsWhenDead(Entity, false)
		SetBlockingOfNonTemporaryEvents(Entity, true)

		-- soltar o modelo correto (hash!)
		SetModelAsNoLongerNeeded(GetHashKey("a_c_" .. Model))

		-- mover em direção ao player
		TaskGoStraightToCoord(Entity, pCoords.x, pCoords.y, pCoords.z, 2.0, -1, 0.0, 0.0)

		-- blip
		AnimalBlip = AddBlipForEntity(Entity)
		SetBlipSprite(AnimalBlip, 141)
		SetBlipAsShortRange(AnimalBlip, true)
	end)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- DELETE PED (CHAMADO PELO SERVER)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("inventory:DeletePed")
AddEventHandler("inventory:DeletePed", function(netId)
	-- liberta lock (failsafe)
	TriggerEvent("inventory:ActionLock", false)

	if not netId then
		return
	end

	-- tenta casar com o Entity atual
	if Entity and DoesEntityExist(Entity) then
		local currentNet = NetworkGetNetworkIdFromEntity(Entity)
		if currentNet == netId then
			SetEntityAsMissionEntity(Entity, true, true)
			DeleteEntity(Entity)
			Entity, Model = nil, nil
			if AnimalBlip then
				RemoveBlip(AnimalBlip)
				AnimalBlip = nil
			end
			return
		end
	end

	-- fallback: apagar o que veio
	local ent = NetToEnt(netId)
	if DoesEntityExist(ent) then
		SetEntityAsMissionEntity(ent, true, true)
		DeleteEntity(ent)
	end
end)
