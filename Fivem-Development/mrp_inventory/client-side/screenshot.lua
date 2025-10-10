-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local FovMin = 10.0
local FovMax = 70.0
local Camera = false          -- armazena o handle da cam ou false
local Binoculars = false
local Total = (FovMax + FovMin) * 0.5
local Scaleform = nil
local openGuard = false       -- evita duplo trigger

-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:CAMERA (toggle)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("inventory:Camera")
AddEventHandler("inventory:Camera", function(Action)
	if openGuard then return end
	openGuard = true
	SetTimeout(300, function() openGuard = false end)

	-- Toggle: se já está aberta, fecha
	if Camera then
		RemoveCamera()
		return
	end

	Binoculars = Action == true -- true = overlay de binóculos

	local ped = PlayerPedId()
	local heading = GetEntityHeading(ped)

	-- Carrega overlay binóculos (opcional)
	if Binoculars then
		Scaleform = RequestScaleformMovie("BINOCULARS")
		while not HasScaleformMovieLoaded(Scaleform) do
			Wait(0)
		end
	else
		Scaleform = nil
	end

	-- Cria câmara
	Camera = CreateCam("DEFAULT_SCRIPTED_FLY_CAMERA", true)
	AttachCamToEntity(Camera, ped, 0.0, 0.0, 1.0, true)
	LocalPlayer.state:set("Camera", true, true)
	RenderScriptCams(true, false, 0, false, false)
	SetCamRot(Camera, 0.0, 0.0, heading, 2)
	SetCamAffectsAiming(Camera, false)
	SetCamActive(Camera, true)
	SetCamFov(Camera, Total)
	SetCinematicModeActive(false)
	InvalidateIdleCam()  -- impede idle cam/cortes cinemáticos
	TriggerEvent("hud:Active", false)

	-- Pequeno delay para evitar fecho imediato por algum frame estranho
	Wait(50)

	-- Loop da câmara
	while Camera do
		Wait(0)

			-- Bloqueios gerais (mantém rotação da tua cam via 220/221)
		DisableControlAction(0, 24, true)  -- Attack
		DisableControlAction(0, 25, true)  -- Aim (RMB)
		DisableControlAction(0, 37, true)  -- Select Weapon
		DisableControlAction(0, 45, true)  -- Reload
		DisableControlAction(0, 140, true)
		DisableControlAction(0, 141, true)
		DisableControlAction(0, 142, true)
		DisableControlAction(0, 257, true)
		DisableControlAction(0, 263, true)
		DisableControlAction(0, 264, true)

		-- Impedir mudar para 3ª pessoa / trocar câmara
		DisableControlAction(0, 0, true)    -- INPUT_NEXT_CAMERA (tecla V)
		DisableControlAction(0, 26, true)   -- Look Behind (pode forçar mudança de cam)

		-- Em veículo (mesmo que estejas dentro, mantém overlay)
		DisableControlAction(0, 68, true)   -- Vehicle Aim
		DisableControlAction(0, 69, true)   -- Vehicle Attack
		DisableControlAction(0, 70, true)   -- Vehicle Attack 2
		DisableControlAction(0, 91, true)   -- Vehicle Mouse Steering (left)
		DisableControlAction(0, 92, true)   -- Vehicle Mouse Steering (right)

		-- Extra: evitar “wheel”/scroll de armas mexer na view
		DisableControlAction(0, 12, true)   -- Weapon Wheel Up
		DisableControlAction(0, 13, true)   -- Weapon Wheel Down
		DisableControlAction(0, 14, true)   -- Weapon Wheel Next
		DisableControlAction(0, 15, true)   -- Weapon Wheel Prev


		-- Saída por tecla (ESC / Backspace)
		if IsControlJustPressed(0, 322) or IsControlJustPressed(0, 177) then
			RemoveCamera()
			break
		end

		-- Failsafe: morte (mantemos), mas NÃO fechamos por estar em veículo nem por ragdoll
		if IsEntityDead(PlayerPedId()) then
			RemoveCamera()
			break
		end

		-- Rotação e zoom
		local zoom = (1.0 / (FovMax - FovMin)) * (Total - FovMin)
		CheckInputRotation(zoom)
		HandleZoom()

		-- Overlay binóculos
		if Binoculars and Scaleform then
			DrawScaleformMovieFullscreen(Scaleform, 255, 255, 255, 255)
		end
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- REMOVECAMERA
-----------------------------------------------------------------------------------------------------------------------------------------
function RemoveCamera()
	Total = (FovMax + FovMin) * 0.5
	Binoculars = false

	LocalPlayer.state:set("Camera", false, true)

	if DoesCamExist(Camera) then
		RenderScriptCams(false, false, 0, false, false)
		SetCamActive(Camera, false)
		DestroyCam(Camera, false)
		Camera = nil
	end

	if Scaleform then
		SetScaleformMovieAsNoLongerNeeded(Scaleform)
		Scaleform = nil
	end

	-- >>> ADICIONA ESTA LINHA: limpa prop/animação no servidor <<<
	TriggerServerEvent("inventory:Camera:stop")

	TriggerEvent("hud:Active", true)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- CHECKINPUTROTATION
-----------------------------------------------------------------------------------------------------------------------------------------
function CheckInputRotation(Zoom)
	if not Camera then return end

	local AxisX = GetDisabledControlNormal(0, 220)
	local AxisY = GetDisabledControlNormal(0, 221)
	local Rotation = GetCamRot(Camera, 2)

	if AxisX ~= 0.0 or AxisY ~= 0.0 then
		local NewZ = Rotation.z + AxisX * -1.0 * 8.0 * (Zoom + 0.1)
		local NewX = math.max(math.min(20.0, Rotation.x + AxisY * -1.0 * 8.0 * (Zoom + 0.1)), -89.5)
		SetCamRot(Camera, NewX, 0.0, NewZ, 2)
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- HANDLEZOOM
-----------------------------------------------------------------------------------------------------------------------------------------
function HandleZoom()
	if not Camera then return end

	-- Scroll up/down
	if IsControlJustPressed(1, 241) then
		Total = math.max(Total - 10.0, FovMin)
	elseif IsControlJustPressed(1, 242) then
		Total = math.min(Total + 10.0, FovMax)
	end

	local Current = GetCamFov(Camera)
	if math.abs(Total - Current) < 0.1 then
		Total = Current
	end

	SetCamFov(Camera, Current + (Total - Current) * 0.05)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- FAILSAFE COMMAND
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("fixcamera", function()
	RemoveCamera()
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- CLEANUP ON RESOURCE STOP
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("onResourceStop", function(res)
	if res == GetCurrentResourceName() then
		if Camera then
			RemoveCamera()
		end
	end
end)


-- EVENTO DE LIMPEZA (chamado pelo client quando fecha a câmara/binóculo)
RegisterNetEvent("inventory:Camera:stop")
AddEventHandler("inventory:Camera:stop", function()
	local src = source
	-- remove props/animações criadas pelo vRPC.CreateObjects
	if vRPC and vRPC.DestroyObjects then
		vRPC.DestroyObjects(src)
	end
	-- (opcional) garantir que limpa anim
	if ClearPedTasks then
		local ped = GetPlayerPed(src)
		if ped and ped ~= 0 then
			ClearPedTasks(ped)
		end
	end
end)
