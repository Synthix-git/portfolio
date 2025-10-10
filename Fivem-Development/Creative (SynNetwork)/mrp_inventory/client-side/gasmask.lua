-----------------------------------------------------------------------------------------------------------------------------------------
-- GAS MASK (CLIENT) — Syn Network
-----------------------------------------------------------------------------------------------------------------------------------------
local GasMask = nil
local HasGasMask = false
local IsToggling = false
local LastToggle = 0
local GAS_STATE_KEY = "GasMask" -- lido pela smoke

-- modelo / osso / offsets
local GAS_MODEL = "p_s_scuba_mask_s"
local GAS_BONEID = 12844 -- SKEL_Head
local GAS_OFFS = vec3(0.0, 0.0, 0.0)
local GAS_ROTS = vec3(180.0, 90.0, 0.0)

local function SetGasMaskState(on)
	HasGasMask = on and true or false
	if LocalPlayer and LocalPlayer.state then
		LocalPlayer.state:set(GAS_STATE_KEY, HasGasMask, true)
	end
end

local function EnsureModel(hash, timeout)
	timeout = timeout or 2500
	if not HasModelLoaded(hash) then
		RequestModel(hash)
		local dl = GetGameTimer() + timeout
		while not HasModelLoaded(hash) and GetGameTimer() < dl do
			Wait(0)
		end
	end
	return HasModelLoaded(hash)
end

local function AttachMask(ped, obj)
	if not DoesEntityExist(ped) or not DoesEntityExist(obj) then
		return false
	end
	AttachEntityToEntity(
		obj,
		ped,
		GetPedBoneIndex(ped, GAS_BONEID),
		GAS_OFFS.x,
		GAS_OFFS.y,
		GAS_OFFS.z,
		GAS_ROTS.x,
		GAS_ROTS.y,
		GAS_ROTS.z,
		true,
		true,
		false,
		false,
		2,
		true
	)
	SetEntityCollision(obj, false, false)
	SetEntityInvincible(obj, true)
	return true
end

local function CreateAndAttachMask()
	local ped = PlayerPedId()
	local coords = GetEntityCoords(ped)

	local hash = GetHashKey(GAS_MODEL)
	if not EnsureModel(hash, 2500) then
		TriggerEvent("Notify", "Inventário", "Falha ao carregar a <b>máscara de gás</b>.", "vermelho", 5000)
		return false
	end

	-- cria local, instantâneo e mission entity
	local obj = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, false, false, false)
	if not obj or not DoesEntityExist(obj) then
		TriggerEvent("Notify", "Inventário", "Não foi possível criar a <b>máscara de gás</b>.", "vermelho", 5000)
		return false
	end

	SetEntityAsMissionEntity(obj, true, true)
	SetModelAsNoLongerNeeded(hash)

	if not AttachMask(ped, obj) then
		DeleteEntity(obj)
		TriggerEvent("Notify", "Inventário", "Não foi possível equipar a <b>máscara de gás</b>.", "vermelho", 5000)
		return false
	end

	GasMask = obj
	SetGasMaskState(true)
	TriggerEvent("Notify", "Inventário", "<b>Máscara de gás</b> equipada.", "azul", 4000)
	return true
end

local function RemoveMask(silent)
	if GasMask and DoesEntityExist(GasMask) then
		DetachEntity(GasMask, true, true)
		DeleteEntity(GasMask)
	end
	GasMask = nil
	if HasGasMask and not silent then
		TriggerEvent("Notify", "Inventário", "Removeste a <b>máscara de gás</b>.", "amarelo", 3500)
	end
	SetGasMaskState(false)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- EVENTS (PUBLIC)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("inventory:GasMaskRemove", function()
	RemoveMask(false)
end)

RegisterNetEvent("inventory:GasMask", function()
	-- anti-spam: 500ms
	local now = GetGameTimer()
	if IsToggling or (now - LastToggle) < 500 then
		return
	end
	IsToggling = true
	LastToggle = now

	-- toggle
	if GasMask and DoesEntityExist(GasMask) then
		RemoveMask(false)
	else
		CreateAndAttachMask()
	end

	IsToggling = false
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- SAFETY / AUTO-REATTACH & CLEANUP
-----------------------------------------------------------------------------------------------------------------------------------------
-- 1) Se morrer ou objeto desaparecer, limpa
CreateThread(function()
	while true do
		if HasGasMask then
			local ped = PlayerPedId()
			if (not DoesEntityExist(ped)) or IsEntityDead(ped) or not GasMask or (not DoesEntityExist(GasMask)) then
				RemoveMask(true)
			end
		end
		Wait(750)
	end
end)

-- 2) Se por algum motivo o prop se soltar (ragdoll, etc.), tenta re-anexar
CreateThread(function()
	while true do
		if HasGasMask and GasMask and DoesEntityExist(GasMask) then
			local ped = PlayerPedId()
			if not IsEntityAttachedToEntity(GasMask, ped) then
				AttachMask(ped, GasMask)
			end
		end
		Wait(1000)
	end
end)

-- 3) Resource stop: limpa
AddEventHandler("onResourceStop", function(res)
	if res == GetCurrentResourceName() then
		RemoveMask(true)
	end
end)
