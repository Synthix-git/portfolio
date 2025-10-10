----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")

----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
----------------------------------------------------------------------------------------------------------------------------------------
Creative = Creative or {}
Tunnel.bindInterface("inventory", Creative) -- server chama vCLIENT.*

----------------------------------------------------------------------------------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------------------------------------------------------------------------------
local REQUIRE_WRENCH   = true   -- precisa estar com WEAPON_WRENCH equipado para aparecer o prompt
local PROMPT_DIST      = 1.25   -- distância máx até ao osso da roda
local SCAN_RANGE       = 6.0    -- procurar veículo até X metros
local SHOW_HINT        = false   -- desenhar "[E] Retirar pneu"
local HINT_KEY         = 38     -- E

----------------------------------------------------------------------------------------------------------------------------------------
-- LISTA DE RODAS
----------------------------------------------------------------------------------------------------------------------------------------
local TyreList = {
    ["wheel_lf"] = 0, ["wheel_rf"] = 1, -- frente
    ["wheel_lm"] = 2, ["wheel_rm"] = 3, -- meio (camiões)
    ["wheel_lr"] = 4, ["wheel_rr"] = 5  -- traseira
}

----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------------------------------------------------------------------------------
local function isHoldingWrench()
    local ped = PlayerPedId()
    if not HasPedGotWeapon(ped, `WEAPON_WRENCH`, false) then return false end
    return GetSelectedPedWeapon(ped) == `WEAPON_WRENCH`
end

local function DrawText3D(x,y,z, text)
    SetDrawOrigin(x,y,z,0)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(0.32,0.32)
    SetTextColour(255,255,255,215)
    SetTextCentre(1)
    SetTextOutline()
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0,0.0)
    ClearDrawOrigin()
end

local function drawCircle(x,y,z)
    DrawMarker(28, x, y, z + 0.02, 0.0,0.0,0.0, 0.0,0.0,0.0, 0.22,0.22,0.22, 0,153,255,120, false, true, 2, false, nil, nil, false)
end

-- “Intacto” = não furado (ignora desgaste/health < 1000)
local function TyreIsIntact(veh, idx)
    return not IsVehicleTyreBurst(veh, idx, false) and not IsVehicleTyreBurst(veh, idx, true)
end

-- Para compat do teu "uses tyre" antigo: “Danificado” = furado
local function TyreIsDamaged(veh, idx)
    return IsVehicleTyreBurst(veh, idx, false) or IsVehicleTyreBurst(veh, idx, true)
end

-- varredura por plate (fallback extra)
local function FindVehicleByPlateNear(plate, radius)
    local ped = PlayerPedId()
    local my  = GetEntityCoords(ped)
    local vehicles = GetGamePool("CVehicle")
    local best, bestDist
    for _,veh in ipairs(vehicles) do
        if DoesEntityExist(veh) then
            local pos  = GetEntityCoords(veh)
            local dist = #(my - pos)
            if dist <= (radius or 10.0) and GetVehicleNumberPlateText(veh) == plate then
                if not bestDist or dist < bestDist then
                    best, bestDist = veh, dist
                end
            end
        end
    end
    return best
end

----------------------------------------------------------------------------------------------------------------------------------------
-- APIS PARA O SERVER
----------------------------------------------------------------------------------------------------------------------------------------
function Creative.CheckWeapon(weaponName)
    local ped = PlayerPedId()
    return HasPedGotWeapon(ped, GetHashKey(weaponName), false)
end

-- legado
function Creative.tyreHealth(netId, tyreIdx)
    if not NetworkDoesNetworkIdExist(netId) then return nil end
    local veh = NetToEnt(netId)
    if not DoesEntityExist(veh) then return nil end
    return GetTyreHealth(veh, tyreIdx)
end

-- NOVO SUPER ROBUSTO:
-- devolve SEMPRE { health = <number>, burst = <bool> }
function Creative.tyreInfo(plate, netId, tyreIdx, vehHandle)
    local veh

    -- 1) netId
    if netId and netId ~= 0 and NetworkDoesNetworkIdExist(netId) then
        veh = NetToEnt(netId)
    end

    -- 2) handle enviado
    if (not veh or not DoesEntityExist(veh)) and vehHandle and vehHandle ~= 0 then
        if DoesEntityExist(vehHandle) then
            veh = vehHandle
        end
    end

    -- 3) procurar por plate perto (melhor que “qualquer um”)
    if (not veh or not DoesEntityExist(veh)) and type(plate) == "string" and plate ~= "" then
        veh = FindVehicleByPlateNear(plate, 12.0)
    end

    -- 4) fallback final: veículo mais próximo
    if not veh or not DoesEntityExist(veh) then
        local nearVeh = vRP and vRP.ClosestVehicle and vRP.ClosestVehicle(8.0) or nil
        if type(nearVeh) == "table" then
            veh = nearVeh[1]
        elseif type(nearVeh) == "number" then
            veh = nearVeh
        end
    end

    -- se mesmo assim não achar, devolve “não furado” (evita nil no server; validações seguintes tratam)
    if not veh or not DoesEntityExist(veh) then
        return { health = 1000.0, burst = false }
    end

    local health = GetTyreHealth(veh, tyreIdx) or 1000.0
    local burst  = IsVehicleTyreBurst(veh, tyreIdx, false) or IsVehicleTyreBurst(veh, tyreIdx, true)
    return { health = health, burst = burst }
end

-- Compat com “uses tyre” antigo (devolve pneu FURADO e perto)
function Creative.Tyres()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped) then return false end
    local Vehicle, Model = vRP.ClosestVehicle(7)
    if not IsEntityAVehicle(Vehicle) then return false end

    local my = GetEntityCoords(ped)
    for bone, idx in pairs(TyreList) do
        local bid = GetEntityBoneIndexByName(Vehicle, bone)
        if bid ~= -1 then
            local wpos = GetWorldPositionOfEntityBone(Vehicle, bid)
            if #(my - wpos) <= 2.0 and TyreIsDamaged(Vehicle, idx) then
                return Vehicle, idx, VehToNet(Vehicle), GetVehicleNumberPlateText(Vehicle), Model
            end
        end
    end
    return false
end

----------------------------------------------------------------------------------------------------------------------------------------
-- HANDLERS DE SINCRONIZAÇÃO (mantidos)
----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("inventory:explodeTyres")
AddEventHandler("inventory:explodeTyres",function(Network,Plate,Tyre)
	if NetworkDoesNetworkIdExist(Network) then
		local Vehicle = NetToEnt(Network)
		if DoesEntityExist(Vehicle) and GetVehicleNumberPlateText(Vehicle) == Plate then
			SetVehicleTyreBurst(Vehicle,Tyre,true,1000.0)
		end
	end
end)

-- SUBSTITUIR ESTE HANDLER NO CLIENT
RegisterNetEvent("inventory:RepairTyres")
AddEventHandler("inventory:RepairTyres",function(NetId,Tyres,Plate)
    if not NetworkDoesNetworkIdExist(NetId) then return end

    local veh = NetToEnt(NetId)
    if not DoesEntityExist(veh) then return end
    if GetVehicleNumberPlateText(veh) ~= Plate then return end

    -- helper para reparar todos os pneus existentes sem rebentar nada
    local function fixAllTyres(vehicle)
        local wheels = GetVehicleNumberOfWheels and GetVehicleNumberOfWheels(vehicle) or 8
        for i = 0, wheels - 1 do
            -- só chama se estiver mesmo danificado (burst ou health < 1000)
            local burst = IsVehicleTyreBurst(vehicle,i,false) or IsVehicleTyreBurst(vehicle,i,true)
            local health = GetTyreHealth(vehicle,i)
            if burst or (health and health < 1000.0) then
                SetVehicleTyreFixed(vehicle,i)
            end
        end
    end

    if Tyres == "All" then
        fixAllTyres(veh)
    else
        -- Repara apenas o índice pedido (0..7)
        if type(Tyres) == "number" then
            SetVehicleTyreFixed(veh, Tyres)
        end
    end
end)


RegisterNetEvent("inventory:RepairBoosts")
AddEventHandler("inventory:RepairBoosts",function(Index,Plate)
	if NetworkDoesNetworkIdExist(Index) then
		local Vehicle = NetToEnt(Index)
		if DoesEntityExist(Vehicle) and GetVehicleNumberPlateText(Vehicle) == Plate then
			local Tyres = {}
			for i = 0,7 do
				local Status = GetTyreHealth(Vehicle,i) ~= 1000.0
				Tyres[i] = Status
			end
			local Fuel = GetVehicleFuelLevel(Vehicle)
			SetVehicleFixed(Vehicle)
			SetVehicleDeformationFixed(Vehicle)
			SetVehicleFuelLevel(Vehicle,Fuel)
			for Tyre,Burst in pairs(Tyres) do
				if Burst then
					SetVehicleTyreBurst(Vehicle,Tyre,true,1000.0)
				end
			end
		end
	end
end)

RegisterNetEvent("inventory:RepairDefault")
AddEventHandler("inventory:RepairDefault",function(Index,Plate)
	if NetworkDoesNetworkIdExist(Index) then
		local Vehicle = NetToEnt(Index)
		if DoesEntityExist(Vehicle) and GetVehicleNumberPlateText(Vehicle) == Plate then
			SetVehicleEngineHealth(Vehicle,1000.0)
			SetVehicleBodyHealth(Vehicle,1000.0)
			SetEntityHealth(Vehicle,1000)
		end
	end
end)

RegisterNetEvent("inventory:RepairAdmin")
AddEventHandler("inventory:RepairAdmin",function(Index,Plate)
	if NetworkDoesNetworkIdExist(Index) then
		local Vehicle = NetToEnt(Index)
		if DoesEntityExist(Vehicle) and GetVehicleNumberPlateText(Vehicle) == Plate then
			local Fuel = GetVehicleFuelLevel(Vehicle)
			SetVehicleFixed(Vehicle)
			SetVehicleDeformationFixed(Vehicle)
			SetVehicleFuelLevel(Vehicle,Fuel)
		end
	end
end)

----------------------------------------------------------------------------------------------------------------------------------------
-- MINI-TARGET LOCAL NAS RODAS
----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
    local lastPress = 0
    while true do
        local sleep = 600
        repeat
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped) then break end
            if REQUIRE_WRENCH and not isHoldingWrench() then break end

            local veh, _ = vRP.ClosestVehicle(SCAN_RANGE)
            if not veh or not DoesEntityExist(veh) or not IsEntityAVehicle(veh) then break end

            local my = GetEntityCoords(ped)
            local closestIdx, closestPos, closestDist

            for bone, idx in pairs(TyreList) do
                local bid = GetEntityBoneIndexByName(veh, bone)
                if bid ~= -1 then
                    local wpos = GetWorldPositionOfEntityBone(veh, bid)
                    local dist = #(my - wpos)
                    if dist <= PROMPT_DIST and TyreIsIntact(veh, idx) then
                        if not closestDist or dist < closestDist then
                            closestDist, closestIdx, closestPos = dist, idx, wpos
                        end
                    end
                end
            end

            if closestPos then
                sleep = 0
                -- drawCircle(closestPos.x, closestPos.y, closestPos.z)
                if SHOW_HINT then
                    DrawText3D(closestPos.x, closestPos.y, closestPos.z + 0.15, "~b~[E]~s~ Retirar pneu")
                end

                if IsControlJustPressed(0, HINT_KEY) then
                    local now = GetGameTimer()
                    if now - lastPress > 600 then
                        lastPress = now

                        -- Garante network id válido
                        if not NetworkGetEntityIsNetworked(veh) then
                            NetworkRegisterEntityAsNetworked(veh)
                        end
                        local netId = NetworkGetNetworkIdFromEntity(veh)
                        if not netId or netId == 0 then
                            netId = VehToNet(veh)
                        end
                        if netId and netId ~= 0 then
                            SetNetworkIdCanMigrate(netId, true)
                        end

                        local plate     = GetVehicleNumberPlateText(veh)
                        local modelHash = GetEntityModel(veh)
                        local display   = GetDisplayNameFromVehicleModel(modelHash)
                        local payload   = { plate, display or "VEHICLE", veh, netId, modelHash, closestIdx }
                        TriggerServerEvent("inventory:RemoveTyres", payload)
                    end
                end
            end
        until true
        Wait(sleep)
    end
end)
