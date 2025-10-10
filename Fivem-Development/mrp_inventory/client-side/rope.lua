------------------------------------------------
-- CARRY | CLIENT-SIDE
------------------------------------------------

local IsCarried = false
local SavedRagdoll = true

-- animação de algemado (mãos atrás)
local CUFF_DICT = "mp_arresting"
local CUFF_ANIM = "idle"

local function RequestDict(dict)
	if not HasAnimDictLoaded(dict) then
		RequestAnimDict(dict)
		local tries = 0
		while not HasAnimDictLoaded(dict) and tries < 100 do
			Wait(10)
			tries = tries + 1
		end
	end
end

local function PlayCuffedIdle(ped)
	RequestDict(CUFF_DICT)
	-- limpar e tocar anim de algemado, loop e sem deslocamento
	ClearPedTasksImmediately(ped)
	TaskPlayAnim(ped, CUFF_DICT, CUFF_ANIM, 8.0, -8.0, -1, 49, 0.0, false, false, false)
	-- “estado” de algemado para o engine (bloqueia várias ações)
	SetEnableHandcuffs(ped, true)
	SetPedCanPlayGestureAnims(ped, false)
	SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
end

local function StopCuffed(ped)
	SetEnableHandcuffs(ped, false)
	SetPedCanPlayGestureAnims(ped, true)
	ClearPedTasksImmediately(ped)
end

-- helper: espera até o ped do alvo existir (stream in)
local function WaitTargetPed(OtherServerId)
	local tries = 0
	while tries < 100 do -- ~10s
		local otherIdx = GetPlayerFromServerId(OtherServerId)
		if otherIdx ~= -1 then
			local tgtPed = GetPlayerPed(otherIdx)
			if tgtPed ~= 0 and DoesEntityExist(tgtPed) then
				return tgtPed
			end
		end
		Wait(100)
	end
	return 0
end

-- loop para desativar controlos quando carregado + manter anim
CreateThread(function()
	while true do
		if IsCarried then
			-- controlo de movimento/combate/veículo/arma
			DisableControlAction(0, 21, true) -- Sprint
			DisableControlAction(0, 22, true) -- Jump
			DisableControlAction(0, 24, true) -- Attack
			DisableControlAction(0, 25, true) -- Aim
			DisableControlAction(0, 44, true) -- Cover
			DisableControlAction(0, 140, true) -- Melee
			DisableControlAction(0, 141, true) -- Melee Alt
			DisableControlAction(0, 142, true) -- Melee Alt
			DisableControlAction(0, 257, true) -- Attack 2
			DisableControlAction(0, 263, true) -- Melee
			DisableControlAction(0, 31, true) -- Move S
			DisableControlAction(0, 30, true) -- Move A
			DisableControlAction(0, 32, true) -- Move W
			DisableControlAction(0, 34, true) -- Move A
			DisableControlAction(0, 33, true) -- Move S
			DisableControlAction(0, 35, true) -- Move D
			DisableControlAction(0, 23, true) -- Enter vehicle
			DisableControlAction(0, 75, true) -- Exit vehicle
			DisableControlAction(0, 37, true) -- Weapon wheel
			DisableControlAction(0, 45, true) -- Reload
			DisableControlAction(0, 199, true) -- Pause
			DisablePlayerFiring(PlayerId(), true)

			-- segurança extra para não “deslizar”
			local ped = PlayerPedId()
			SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
			SetPedMoveRateOverride(ped, 0.0)
			SetEntityVelocity(ped, 0.0, 0.0, 0.0)

			-- manter a animação sempre ativa
			if not IsEntityPlayingAnim(ped, CUFF_DICT, CUFF_ANIM, 3) then
				TaskPlayAnim(ped, CUFF_DICT, CUFF_ANIM, 8.0, -8.0, -1, 49, 0.0, false, false, false)
			end

			Wait(0)
		else
			Wait(250)
		end
	end
end)

RegisterNetEvent("inventory:Carry")
AddEventHandler("inventory:Carry", function(OtherSource, Mode, Handcuff)
	local ped = PlayerPedId()

	if Mode == "Attach" then
		local tgtPed = WaitTargetPed(OtherSource)
		if tgtPed == 0 or tgtPed == ped then
			return
		end

		IsCarried = true
		SavedRagdoll = CanPedRagdoll(ped)
		SetPedCanRagdoll(ped, false)

		-- animação e estado de algemado (mesmo que Handcuff=false queremos “estático”)
		PlayCuffedIdle(ped)

		-- pedir controlo (evita falhas com algemado)
		NetworkRequestControlOfEntity(tgtPed)

		-- offsets (um pouco “atrás” se Handcuff)
		local boneId = 11816 -- SKEL_Pelvis
		local offX, offY, offZ = 0.6, 0.0, 0.0
		if Handcuff then
			offX, offY, offZ = 0.0, -0.2, 0.45
		end

		DetachEntity(ped, true, true)
		AttachEntityToEntity(
			ped,
			tgtPed,
			boneId,
			offX,
			offY,
			offZ,
			0.0,
			0.0,
			0.0,
			true, -- soft pinning
			false, -- collision off (chave p/ algemado/corda)
			false,
			true,
			2,
			true
		)
	elseif Mode == "Detach" then
		if IsCarried then
			IsCarried = false
			DetachEntity(ped, false, false)
			StopCuffed(ped)
			ClearPedTasksImmediately(ped) -- garante que sai da anim
			SetPedCanRagdoll(ped, SavedRagdoll)
		else
			DetachEntity(ped, false, false)
			StopCuffed(ped)
			SetPedCanRagdoll(ped, true)
		end
	end
end)

-- OPTIONAL: export para outros scripts verificarem estado local
exports("IsBeingCarried", function()
	return IsCarried
end)

-- CLIENT-SIDE: Toggle carry na tecla H

-- Comando “mudo” que chama o servidor
RegisterCommand("+carryToggle", function()
	TriggerServerEvent("inventory:Carry")
end)

RegisterCommand("-carryToggle", function()
	-- sem ação no keyup
end)

-- Mapeamento da tecla H
RegisterKeyMapping("+carryToggle", "Carregar jogador (toggle)", "keyboard", "H")

