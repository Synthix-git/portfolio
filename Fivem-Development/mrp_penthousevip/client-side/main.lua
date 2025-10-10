-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP / TUNNEL / PROXY
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP          = Proxy.getInterface("vRP")

vSERVER   = Tunnel.getInterface("penthouse")
vPROPERTY = Tunnel.getInterface("propertys")
vKEYBOARD = Tunnel.getInterface("keyboard")

-----------------------------------------------------------------------------------------------------------------------------------------
-- STATE
-----------------------------------------------------------------------------------------------------------------------------------------
local Inside, CurrentOwner = false, nil
local IAmOwner = false -- és o dono?
local lastUseE = 0

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS: CONTROLO DE REDE + NETID + ASSENTOS + GHOST
-----------------------------------------------------------------------------------------------------------------------------------------
local function ensureNetworkControl(ent, tries, waitMs)
	if not ent or ent == 0 then return false end
	tries = tries or 30
	waitMs = waitMs or 40
	local netId = NetworkGetNetworkIdFromEntity(ent)
	for i = 1, tries do
		if NetworkHasControlOfEntity(ent) then return true end
		NetworkRequestControlOfEntity(ent)
		if netId and netId ~= 0 then
			SetNetworkIdCanMigrate(netId, true)
			SetNetworkIdExistsOnAllMachines(netId, true)
		end
		Wait(waitMs)
	end
	return NetworkHasControlOfEntity(ent)
end

-- NetID seguro (regista network se preciso, evita warnings)
local function getSafeNetId(ent)
	if not ent or ent == 0 or not DoesEntityExist(ent) then return false end
	SetEntityAsMissionEntity(ent, true, true)

	if not NetworkGetEntityIsNetworked(ent) then
		NetworkRegisterEntityAsNetworked(ent)
		local tries = 0
		while not NetworkGetEntityIsNetworked(ent) and tries < 10 do
			Wait(0)
			NetworkRegisterEntityAsNetworked(ent)
			tries = tries + 1
		end
	end

	local netId = VehToNet(ent)
	if not netId or netId == 0 then
		netId = NetworkGetNetworkIdFromEntity(ent) or 0
	end
	if not netId or netId == 0 then return false end

	SetNetworkIdExistsOnAllMachines(netId, true)
	SetNetworkIdCanMigrate(netId, true)
	return netId
end

local function anyFreePassengerSeat(v)
	local maxSeats = GetVehicleModelNumberOfSeats(GetEntityModel(v)) - 1
	for s = 0, maxSeats do
		if IsVehicleSeatFree(v, s) then return s end
	end
	return nil
end

local function ensurePedInVehicleSeat(ped, veh, targetSeat)
	if veh == 0 then return true end
	if targetSeat == nil then targetSeat = -1 end

	for i=1,3 do
		if IsVehicleSeatFree(veh, targetSeat) then
			ClearPedTasksImmediately(ped)
			TaskWarpPedIntoVehicle(ped, veh, targetSeat)
			Wait(120)
			if GetVehiclePedIsIn(ped,false) == veh then return true end
		end
		Wait(100)
	end

	local free = anyFreePassengerSeat(veh)
	if free ~= nil then
		ClearPedTasksImmediately(ped)
		TaskWarpPedIntoVehicle(ped, veh, free)
		Wait(140)
		if GetVehiclePedIsIn(ped,false) == veh then return true end
	end

	local px,py,pz = table.unpack(GetOffsetFromEntityInWorldCoords(veh, -0.8, -2.2, 0.0))
	SetEntityCoordsNoOffset(ped, px, py, pz, false, false, true)
	TaskEnterVehicle(ped, veh, 5000, targetSeat < 0 and -1 or targetSeat, 2.0, 1, 0)
	Wait(400)
	return GetVehiclePedIsIn(ped,false) == veh
end

local function vehicleGhost(veh, enable)
	if veh == 0 then return end
	if enable then
		SetEntityAlpha(veh,180,false)
		SetEntityInvincible(veh,true)
		SetEntityProofs(veh,true,true,true,true,true,true,true,true)
	else
		SetEntityAlpha(veh,255,false)
		SetEntityInvincible(veh,false)
		SetEntityProofs(veh,false,false,false,false,false,false,false,false)
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- SAFE TELEPORT ROBUSTO (VEÍCULO PRIMEIRO, CONTROLO DE REDE, RE-WARP)
-----------------------------------------------------------------------------------------------------------------------------------------
local function safeTeleportWithStreaming(ped, dest4, veh, ghostMs)
	DoScreenFadeOut(700)
	while not IsScreenFadedOut() do Wait(0) end

	-- revalida handle do veículo
	if veh and veh ~= 0 and not DoesEntityExist(veh) then
		veh = 0
	end

	local wantedSeat = nil
	if veh and veh ~= 0 then
		if GetPedInVehicleSeat(veh,-1) == ped then wantedSeat = -1
		else
			local maxSeats = GetVehicleModelNumberOfSeats(GetEntityModel(veh)) - 1
			for s = 0, maxSeats do
				if GetPedInVehicleSeat(veh, s) == ped then wantedSeat = s break end
			end
			if wantedSeat == nil then wantedSeat = 0 end
		end
	end

	SetPlayerControl(PlayerId(), false, 0)
	SetPedCanRagdoll(ped, false)
	FreezeEntityPosition(ped, true)
	SetEntityCollision(ped, false, false)
	SetEntityInvincible(ped, true)

	if veh and veh ~= 0 then
		-- tenta controlo e aborta ramo do veículo se perdeu handle
		ensureNetworkControl(veh, 30, 40)
		if not DoesEntityExist(veh) then veh = 0 end
	end

	if veh and veh ~= 0 then
		SetEntityAsMissionEntity(veh, true, true)
		FreezeEntityPosition(veh, true)
		SetEntityCollision(veh, false, false)
		SetVehicleEngineOn(veh, false, true, false)
		SetVehicleDoorsLocked(veh, 4)
		if ghostMs and ghostMs > 0 then
			SetEntityAlpha(veh, 180, false)
			SetEntityInvincible(veh, true)
			SetEntityProofs(veh,true,true,true,true,true,true,true,true)
		end
	end

	RequestCollisionAtCoord(dest4.x, dest4.y, dest4.z)

	if veh and veh ~= 0 then
		SetEntityCoordsNoOffset(veh, dest4.x, dest4.y, dest4.z, false, false, true)
		SetEntityHeading(veh, dest4.w or GetEntityHeading(veh))
	else
		SetEntityCoordsNoOffset(ped, dest4.x, dest4.y, dest4.z, false, false, true)
		SetEntityHeading(ped, dest4.w or GetEntityHeading(ped))
	end

	local tries = 0
	while tries < 400 and not HasCollisionLoadedAroundEntity(ped) do
		Wait(10); tries = tries + 1
	end

	if veh and veh ~= 0 then
		SetVehicleOnGroundProperly(veh)
		SetEntityVelocity(veh, 0.0, 0.0, 0.0)
		if GetVehiclePedIsIn(ped,false) ~= veh then
			ensurePedInVehicleSeat(ped, veh, wantedSeat or -1)
		end
		FreezeEntityPosition(veh, false)
		SetEntityCollision(veh, true, true)
		SetVehicleDoorsLocked(veh, 1)
	else
		local ok,gz = GetGroundZFor_3dCoord(dest4.x, dest4.y, dest4.z, true)
		if ok then SetEntityCoordsNoOffset(ped, dest4.x, dest4.y, gz, false, false, true) end
	end

	FreezeEntityPosition(ped, false)
	SetEntityCollision(ped, true, true)
	SetEntityInvincible(ped, false)
	SetPedCanRagdoll(ped, true)
	SetPlayerControl(PlayerId(), true, 0)

	if veh and veh ~= 0 and ghostMs and ghostMs > 0 then
		SetTimeout(ghostMs, function()
			if DoesEntityExist(veh) then
				SetEntityAlpha(veh, 255, false)
				SetEntityInvincible(veh, false)
				SetEntityProofs(veh,false,false,false,false,false,false,false,false)
			end
		end)
	end

	DoScreenFadeIn(700)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- VEHICLE OCCUPANTS (com assentos)
-----------------------------------------------------------------------------------------------------------------------------------------
local function collectVehicleOccupantsWithSeats(veh)
	local list = {}
	if veh == 0 then return list end
	local maxSeats = GetVehicleModelNumberOfSeats(GetEntityModel(veh)) - 1
	for seat = -1, maxSeats do
		local seatPed = GetPedInVehicleSeat(veh, seat)
		if seatPed ~= 0 then
			local idx = NetworkGetPlayerIndexFromPed(seatPed)
			if idx ~= -1 then
				local s = GetPlayerServerId(idx)
				if s and s > 0 then
					list[#list+1] = { src = s, seat = seat }
				end
			end
		end
	end
	return list
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- THREAD PRINCIPAL (entrada/saída + pontos internos)
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		local sleep=750
		local ped=PlayerPedId()
		local p=GetEntityCoords(ped)

		if not Inside then
			if #(p-Config.EntryZone) <= Config.EntryRadius then
				sleep=1
				if IsControlJustPressed(1,38) then
					local ok = vSERVER.TryEnterAsOwner()
					if not ok then vSERVER.TryEnterAsGuest() end
				end
			end
		else
			if #(p-Config.ExitZone) <= Config.ExitRadius then
				sleep=1
				if IsControlJustPressed(1,38) then
					local veh = GetVehiclePedIsIn(ped,false)

					if IAmOwner and veh ~= 0 and GetPedInVehicleSeat(veh,-1) == ped then
						local occupants = collectVehicleOccupantsWithSeats(veh)
						vehicleGhost(veh,false)

						local netVeh = getSafeNetId(veh) or false
						if netVeh then
							TriggerServerEvent("penthouse:ExitVehicleAndPassengers", occupants, netVeh)
						end

						safeTeleportWithStreaming(ped, Config.OutsideExit, veh, 0)

						if netVeh then
							TriggerServerEvent("penthouse:ExitWithVehicle", netVeh)
						else
							TriggerServerEvent("penthouse:ExitWithVehicle", false)
						end

						Inside, CurrentOwner = false, nil
						IAmOwner = false
					else
						safeTeleportWithStreaming(ped, Config.OutsideExit, 0, 0)
						TriggerServerEvent("penthouse:ExitWithVehicle", false)

						Inside, CurrentOwner = false, nil
						IAmOwner = false
					end
				end
			end

			for _,pt in ipairs(Config.Points) do
				if #(p-pt.pos) <= (pt.radius or 1.2) then
					sleep=1
					if IsControlJustPressed(1,38) then
						local nowMs = GetGameTimer()
						if nowMs - lastUseE < 300 then goto cont end
						lastUseE = nowMs

						if not CurrentOwner then
							TriggerEvent("Notify","Penthouse","Ainda a sincronizar o dono, tenta de novo em <b>1s</b>.","amarelo",3000)
							goto cont
						end

						if pt.type=="vault" then
							TriggerEvent("chest:Open", "Penthouse:"..tostring(CurrentOwner), "PenthouseVault")
						elseif pt.type=="fridge" then
							TriggerEvent("chest:Open", "Penthouse:"..tostring(CurrentOwner), "PenthouseFridge")
						elseif pt.type=="wardrobe" then
							if exports["dynamic"] and exports["dynamic"].AddMenu then
								exports["dynamic"]:AddMenu("Armário","Vestimentas guardadas.","wardrobe")
								exports["dynamic"]:AddButton("Shopping","Abrir a loja de vestimentas.","skinshop:Open","", "wardrobe", false)
								exports["dynamic"]:AddButton("Guardar","Salvar roupas atuais.","propertys:Clothes","Save","wardrobe",true)

								local clothes = vPROPERTY and vPROPERTY.Clothes and vPROPERTY.Clothes() or {}
								if parseInt(#clothes) > 0 then
									for idx,name in pairs(clothes) do
										exports["dynamic"]:AddMenu(name,"Vestimenta salva.",idx,"wardrobe")
										exports["dynamic"]:AddButton("Aplicar","Vestir-se.","propertys:Clothes","Apply-"..name,idx,true)
										exports["dynamic"]:AddButton("Remover","Deletar do armário.","propertys:Clothes","Delete-"..name,idx,true,true)
									end
								end
								exports["dynamic"]:Open()
							else
								TriggerEvent("Notify","Penthouse","Sistema de <b>roupas</b> indisponível.","amarelo",4000)
							end
						end
					end
				end
				::cont::
			end
		end

		Wait(sleep)
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- EVENTS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("penthouse:InvitePing", function(owner, ownerName)
	TriggerEvent("Notify","Penthouse","Foste convidado por <b>"..(ownerName or ("#"..owner)).."</b>. Aproxima-te da porta para entrar.","azul",7000)
end)

RegisterNetEvent("penthouse:EnterOwner", function(data)
	local ped = PlayerPedId()
	local veh = GetVehiclePedIsIn(ped,false)

	local netVeh = (veh ~= 0) and (getSafeNetId(veh) or false) or false
	local occupants = {}
	if veh ~= 0 then
		occupants = collectVehicleOccupantsWithSeats(veh)
	end

	-- 1) mete dono/veículo no bucket (server)
	TriggerServerEvent("penthouse:SetBucketForPlayers", data.owner, occupants, netVeh)
	-- 2) puxa passageiros para dentro (server)
	TriggerServerEvent("penthouse:BringPassengersInside", data.owner, occupants, netVeh)

	-- pequeno atraso para sincronizar
	Wait(150)

	-- 3) teleport robusto (mantém assentos / sem ejeção)
	safeTeleportWithStreaming(ped, data.interior, veh, data.ghostMs)

	Inside = true
	CurrentOwner = data.owner
	IAmOwner = true
end)

RegisterNetEvent("penthouse:EnterGuest", function(data)
	local ped=PlayerPedId()
	Wait(50)
	safeTeleportWithStreaming(ped, data.interior, 0, 0)
	Inside=true
	CurrentOwner=data.owner
	IAmOwner = false
end)

-- Passageiro segue o carro do dono mantendo o assento (robusto)
RegisterNetEvent("penthouse:FollowOwnerVehicle", function(netVeh, seat)
	local ped = PlayerPedId()

	DoScreenFadeOut(400)
	while not IsScreenFadedOut() do Wait(0) end
	SetEntityCoordsNoOffset(ped, Config.OutsideExit.x, Config.OutsideExit.y, Config.OutsideExit.z, false, false, true)
	SetEntityHeading(ped, Config.OutsideExit.w or GetEntityHeading(ped))

	local veh, timeoutAt = 0, GetGameTimer() + 5000
	repeat
		veh = NetToVeh(netVeh)
		if veh == 0 or not DoesEntityExist(veh) then Wait(80) end
	until (veh ~= 0 and DoesEntityExist(veh)) or GetGameTimer() >= timeoutAt

	if veh ~= 0 and DoesEntityExist(veh) then
		local targetSeat = seat or 0
		if targetSeat < 0 then targetSeat = 0 end
		ensurePedInVehicleSeat(ped, veh, targetSeat)
	end

	DoScreenFadeIn(400)
	Inside, CurrentOwner = false, nil
	IAmOwner = false
end)

-- Passageiro: entrar com o dono, mantendo o assento, dentro do interior
RegisterNetEvent("penthouse:PassengerEnterWithOwner", function(owner, interior, netVeh, seat, ghostMs)
	local ped = PlayerPedId()

	DoScreenFadeOut(500)
	while not IsScreenFadedOut() do Wait(0) end
	safeTeleportWithStreaming(ped, interior, 0, 0)

	local veh, timeoutAt = 0, GetGameTimer() + 5000
	repeat
		veh = NetToVeh(netVeh)
		if veh == 0 or not DoesEntityExist(veh) then Wait(80) end
	until (veh ~= 0 and DoesEntityExist(veh)) or GetGameTimer() >= timeoutAt

	if veh ~= 0 and DoesEntityExist(veh) then
		local targetSeat = seat or 0
		if targetSeat < 0 then targetSeat = 0 end
		ensurePedInVehicleSeat(ped, veh, targetSeat)
	end

	DoScreenFadeIn(500)
	Inside = true
	CurrentOwner = owner
	IAmOwner = false
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- /CONVIDAR (atalho direto)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("convidar", function(_, args)
	local idArg = tonumber(args and args[1] or nil) or 0
	if idArg > 0 then
		vSERVER.InviteByPassport(idArg)
		return
	end

	if vKEYBOARD and vKEYBOARD.Primary then
		local ok, input = pcall(function()
			return vKEYBOARD.Primary("Passaporte do convidado")
		end)
		if ok and input and input[1] then
			local id = tonumber(input[1]) or 0
			if id > 0 then vSERVER.InviteByPassport(id) return end
		end
		TriggerEvent("Notify","Penthouse","ID <b>inválido</b>. Usa <b>/convidar 123</b>.","amarelo",5000)
	else
		TriggerEvent("Notify","Penthouse","Escreve <b>/convidar 123</b> para enviar convite.","azul",6000)
	end
end, false)
