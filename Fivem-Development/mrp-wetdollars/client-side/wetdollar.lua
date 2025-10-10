--[[ 
	wetdollar - client-side/core.lua (MODO ZONAS FIXAS)
	- Sem target, sem props.
	- Mostra mensagem “Sentes calor nesta zona” quando o jogador entra numa HeatZone.
	- Pressiona [E] para iniciar; tem de permanecer dentro do raio até ao fim.
	- Padrão Syn (Notify/Progress). Sem tvRP.
]]

local Config = WETMONEY_CONFIG or {}
local ActiveSession = false
local SessionId = nil
local HairDryerObj = nil

--  Helpers UI 
local function draw3DText(coords, text)
	SetDrawOrigin(coords.x, coords.y, coords.z, 0)
	SetTextFont(4)
	SetTextScale(0.35, 0.35)
	SetTextOutline()
	SetTextCentre(1)
	BeginTextCommandDisplayText("STRING")
	AddTextComponentSubstringPlayerName(text)
	EndTextCommandDisplayText(0.0, 0.0)
	ClearDrawOrigin()
end

local function hintText(msg)
	SetTextComponentFormat("STRING")
	AddTextComponentString(msg)
	DisplayHelpTextFromStringLabel(0, false, true, 1)
end

--  Zonas 
local Zones = {}
for i, z in ipairs(Config.HeatZones or {}) do
	-- normaliza (aceita radius nil)
	Zones[i] = {
		center = z.center,
		radius = z.radius or 3.0,
		name = z.name or ("Zona #%d"):format(i)
	}
end

local function getInsideZone()
	local ped = PlayerPedId()
	local p = GetEntityCoords(ped)
	for i, z in ipairs(Zones) do
		if #(p - z.center) <= z.radius then
			return i, z
		end
	end
	return nil, nil
end

--  Animações 
local function startScenario()
	local ped = PlayerPedId()
	TaskStartScenarioInPlace(ped, "WORLD_HUMAN_STAND_FIRE", 0, true)
end

local function stopScenario()
	ClearPedTasks(PlayerPedId())
end

local function attachHairDryer()
	if not (Config.Active and Config.Active.UseHairDryerProp) then return end
	if DoesEntityExist(HairDryerObj) then return end
	local ped = PlayerPedId()
	local model = GetHashKey("prop_cs_hair_dryer")
	RequestModel(model)
	while not HasModelLoaded(model) do Wait(0) end
	HairDryerObj = CreateObject(model, GetEntityCoords(ped), true, true, false)
	local boneIndex = GetPedBoneIndex(ped, 57005)
	AttachEntityToEntity(HairDryerObj, ped, boneIndex, 0.14, 0.02, -0.02, -90.0, 0.0, 90.0, true, true, false, true, 1, true)
	SetModelAsNoLongerNeeded(model)
end

local function detachHairDryer()
	if HairDryerObj and DoesEntityExist(HairDryerObj) then
		DetachEntity(HairDryerObj, true, true)
		DeleteObject(HairDryerObj)
		HairDryerObj = nil
	end
end

--  Fluxo server -> client 
RegisterNetEvent("wetmoney:ActiveDry:Start")
AddEventHandler("wetmoney:ActiveDry:Start", function(sid, timeMs, zoneIndex)
	if ActiveSession then
		TriggerEvent("wetmoney:ActiveDry:Stop")
		Wait(50)
	end

	ActiveSession = true
	SessionId = sid

	local zone = Zones[zoneIndex]
	if not zone then
		-- zona inválida, aborta
		TriggerServerEvent("wetmoney:ActiveDry:Abort", sid, "invalid_zone")
		ActiveSession, SessionId = false, nil
		return
	end

	startScenario()
	attachHairDryer()

	TriggerEvent("Progress", "Secando dinheiro...", timeMs)

	local startTime = GetGameTimer()
	local cancelled = false

	while GetGameTimer() - startTime < timeMs do
		Wait(100)
		if not ActiveSession or SessionId ~= sid then
			cancelled = true
			break
		end

		local ped = PlayerPedId()
		if IsPedRagdoll(ped) or IsPedSwimming(ped) or IsPedInAnyVehicle(ped,false) then
			cancelled = true
			break
		end

		-- Validação principal: manter-se dentro da zona
		local p = GetEntityCoords(ped)
		if #(p - zone.center) > (zone.radius + 0.05) then
			cancelled = true
			break
		end
	end

	if cancelled then
		TriggerServerEvent("wetmoney:ActiveDry:Abort", sid, "cancelled")
		detachHairDryer()
		stopScenario()
		ActiveSession, SessionId = false, nil
		return
	end

	TriggerServerEvent("wetmoney:ActiveDry:Finish", sid)
end)

RegisterNetEvent("wetmoney:ActiveDry:Stop")
AddEventHandler("wetmoney:ActiveDry:Stop", function()
	detachHairDryer()
	stopScenario()
	ActiveSession, SessionId = false, nil
end)

-- Limpezas extra
AddEventHandler("onClientResourceStop", function(res)
	if res ~= GetCurrentResourceName() then return end
	detachHairDryer()
	stopScenario()
end)

AddEventHandler("baseevents:onPlayerDied", function()
	TriggerEvent("wetmoney:ActiveDry:Stop")
end)

AddEventHandler("baseevents:onPlayerKilled", function()
	TriggerEvent("wetmoney:ActiveDry:Stop")
end)

AddEventHandler("playerSpawned", function()
	TriggerEvent("wetmoney:ActiveDry:Stop")
end)

--  UI/Entrada: SEM TARGET 
CreateThread(function()
	if not (Config.UseZonesOnly and #Zones > 0) then return end

	local shown = false
	while true do
		local sleep = 500
		if not ActiveSession then
			local ped = PlayerPedId()
			local p = GetEntityCoords(ped)
			local idx, z = getInsideZone()

			if idx then
				sleep = 0

                -- DrawMarker(
                -- 1, 
                -- z.center.x, z.center.y, z.center.z - 3,  -- baixei um pouco (-1.2)
                -- 0.0,0.0,0.0, 0.0,0.0,0.0, 
                -- z.radius*2.0, z.radius*2.0, 3,           -- aumentei a altura para 1.5
                -- 255,140,0,80, 
                -- false,false,2,false,nil,nil,false
                -- )

				-- mensagem
				if not shown then
					TriggerEvent("Notify","Conforto","Sentes calor nesta zona.", "amarelo", 15000)
					shown = true
				end

				----- dica + 3D text
				-- hintText("~INPUT_CONTEXT~ Secar dinheiro (~y~1 min~s~)")
				-- draw3DText(z.center + vec3(0.0,0.0,1.0), "~o~Sentes calor nesta zona~s~\n~w~Carrega ~g~E~w~ para secar")

				-- E = 38
				if IsControlJustPressed(0, 38) then
					if IsPedSwimming(ped) or IsPedInAnyVehicle(ped,false) then
						TriggerEvent("Notify","Conforto","Não podes secar <b>a nadar</b> ou <b>dentro do veículo</b>.", "vermelho", 3500)
					else
						-- pede ao server para iniciar pela zona
						TriggerServerEvent("wetmoney:TryActiveDryZone", idx)
					end
				end
			else
				shown = false
			end
		end

		Wait(sleep)
	end
end)
