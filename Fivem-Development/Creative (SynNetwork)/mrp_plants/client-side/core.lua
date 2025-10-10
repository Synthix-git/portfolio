-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP / TUNNEL
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
vSERVER = Tunnel.getInterface("plants")

-----------------------------------------------------------------------------------------------------------------------------------------
-- STATE
-----------------------------------------------------------------------------------------------------------------------------------------
local Plants = {}
local Objects = {}
local ObjectStage = {}
local Meta = {} -- { baseNow, recvTick }
local GLOBAL_GROWTH_TIME = 300

-----------------------------------------------------------------------------------------------------------------------------------------
-- MODELOS POR ESTÁGIO (canábis)
-----------------------------------------------------------------------------------------------------------------------------------------
local MODEL_SMALL = "bkr_prop_weed_01_small_01a" -- 0–49%
local MODEL_MED   = "bkr_prop_weed_med_01b"     -- 50–99%
local MODEL_LARGE = "bkr_prop_weed_lrg_01a"     -- 100%

local function stageModel(stage)
	if stage == 3 then return MODEL_LARGE
	elseif stage == 2 then return MODEL_MED
	else return MODEL_SMALL end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- LOAD MODEL
-----------------------------------------------------------------------------------------------------------------------------------------
local function LoadModel(model)
	local hash = type(model) == "string" and GetHashKey(model) or model
	if not HasModelLoaded(hash) then
		RequestModel(hash)
		local timeout = GetGameTimer() + 10000
		while not HasModelLoaded(hash) and GetGameTimer() < timeout do
			Wait(0)
		end
	end
	return HasModelLoaded(hash) and hash or nil
end

local function ForceDeleteObject(ent)
	if not ent or not DoesEntityExist(ent) then return end
	SetEntityAsMissionEntity(ent, true, true)
	DetachEntity(ent, true, true)
	FreezeEntityPosition(ent, false)
	for i=1,5 do
		if DoesEntityExist(ent) then DeleteObject(ent) end
		Wait(0)
	end
	if DoesEntityExist(ent) then DeleteEntity(ent) end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- PROGRESSO (sem os.time no client)
-----------------------------------------------------------------------------------------------------------------------------------------
local function growthProgress(id)
	local plant = Plants[id]; if not plant then return 0.0 end
	local meta  = Meta[id];   if not meta  then return 0.0 end
	local elapsed = (GetGameTimer() - meta.recvTick) / 1000.0
	local serverNow = (meta.baseNow or 0) + elapsed
	local remaining = math.max(0.0, (plant["Timer"] or 0) - serverNow)
	local p = 1.0 - (remaining / math.max(1.0, GLOBAL_GROWTH_TIME))
	if p < 0 then p = 0 elseif p > 1 then p = 1 end
	return p
end

local function stageFromProgress(p)
	if p >= 1.0 then return 3 elseif p >= 0.50 then return 2 else return 1 end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- TARGET HELPERS
-----------------------------------------------------------------------------------------------------------------------------------------
local function ClearTargetZone(zoneId)
	if not exports["target"] then return end
	pcall(function() if exports["target"].RemoveZone    then exports["target"]:RemoveZone(zoneId) end end)
	pcall(function() if exports["target"].RemZone       then exports["target"]:RemZone(zoneId) end end)
	pcall(function() if exports["target"].RemCircleZone then exports["target"]:RemCircleZone(zoneId) end end)
	pcall(function() if exports["target"].RemBoxZone    then exports["target"]:RemBoxZone(zoneId) end end)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- MODELOS
-----------------------------------------------------------------------------------------------------------------------------------------
function CreateModels(Number,Model,Coords)
	local hash = LoadModel(Model)
	if not hash then return end

	Objects[Number] = CreateObjectNoOffset(hash,Coords[1],Coords[2],Coords[3],false,false,false)

	local ped = PlayerPedId()
	if IsPedInAnyVehicle(ped) then
		SetEntityNoCollisionEntity(Objects[Number],GetVehiclePedIsUsing(ped),false)
	end

	SetEntityHeading(Objects[Number],Coords[4])
	SetEntityNoCollisionEntity(Objects[Number],ped,false)
	PlaceObjectOnGroundProperly(Objects[Number])
	FreezeEntityPosition(Objects[Number],true)
	SetModelAsNoLongerNeeded(hash)
end

local function SwapModel(Number, NewModel, Coords)
	if Objects[Number] and DoesEntityExist(Objects[Number]) then
		ForceDeleteObject(Objects[Number])
		Objects[Number] = nil
	end
	CreateModels(Number, NewModel, Coords)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- CLEAR
-----------------------------------------------------------------------------------------------------------------------------------------
function ClearObjects(Index)
	if Objects[Index] and DoesEntityExist(Objects[Index]) then
		ForceDeleteObject(Objects[Index])
	end
	ClearTargetZone("Plants:"..Index)
	Objects[Index] = nil
	ObjectStage[Index] = nil
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- LOOP DE STREAM
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		local TimeDistance = 999
		if LocalPlayer["state"]["Active"] then
			local ped = PlayerPedId()
			local Coords = GetEntityCoords(ped)

			for id,v in pairs(Plants) do
				if v["Route"] == LocalPlayer["state"]["Route"] then
					local pos = vec3(v["Coords"][1],v["Coords"][2],v["Coords"][3])
					local dist = #(Coords - pos)
					if dist <= 50.0 then
						local p = growthProgress(id)
						local stage = stageFromProgress(p)

						if not Objects[id] then
							-- Limpa qualquer zone antiga com o mesmo id (defesa pós-restart)
							ClearTargetZone("Plants:"..id)

							exports["target"]:AddBoxZone("Plants:"..id, vec3(pos.x,pos.y,pos.z + 0.25), 0.4, 0.4, {
								name = "Plants:"..id,
								heading = v["Coords"][4],
								minZ = pos.z + 0.50,
								maxZ = pos.z + 1.50
							},{
								shop = id,
								Distance = 3.0,
								options = {
									{ event = "plants:Informations", label = "Verificar", tunnel = "client" }
								}
							})

							CreateModels(id, stageModel(stage), v["Coords"])
							ObjectStage[id] = stage
							TimeDistance = 100
						else
							if ObjectStage[id] ~= stage then
								-- troca só o modelo (não mexe no target)
								SwapModel(id, stageModel(stage), v["Coords"])
								ObjectStage[id] = stage
								TimeDistance = 100
							end
						end
					elseif Objects[id] then
						ClearObjects(id)
					end
				elseif Objects[id] then
					ClearObjects(id)
				end
			end

			-- Sweeper: apaga qualquer objeto que já não tenha entrada em Plants
			do
				local toDelete = {}
				for oid,_ in pairs(Objects) do
					if not Plants[oid] then
						table.insert(toDelete, oid)
					end
				end
				for _, oid in ipairs(toDelete) do
					ClearObjects(oid)
				end
			end
		end
		Wait(TimeDistance)
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- MENU
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("plants:Informations",function(Number)
	local info = vSERVER.Informations(Number)
	if info then
		local fertilTxt = (info[5] == 1) and "Sim (3-9)" or "Não (1-3)"
		local waters    = tostring(info[6] or 0).."/"..tostring(info[8] or 0)
		local ferts     = tostring(info[7] or 0).."/"..tostring(info[9] or 0)
		local lvl       = info[10] or 0
		local chance    = info[11] or 50.0

		exports["dynamic"]:AddButton("Germinação","<b>Agricultor Lv "..lvl.."</b> • Fruto: <rare>"..ItemName(info[3]).."</rare>","","",false,false)
		exports["dynamic"]:AddButton("Fototropismo",info[1].." | Adubo: "..fertilTxt,"plants:Collect",Number,false,true)
		exports["dynamic"]:AddButton("Clones","Chance: "..string.format("%.1f",chance).."%","plants:Cloning",Number,false,true)
		exports["dynamic"]:AddButton("Hidratação","Hidratação: <epic>"..math.floor((info[4] or 0) * 100).."%</epic> • Águas: "..waters,"plants:Water",Number,false,true)
		exports["dynamic"]:AddButton("Adubação","Produção final: "..fertilTxt.." • Adubos: "..ferts,"plants:Fertilizer",Number,false,true)
		exports["dynamic"]:Open()
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- SYNC
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("plants:Table")
AddEventHandler("plants:Table",function(Table,serverNow,growthTime)
	-- limpa zonas antigas que possam ter ficado presas no target após restart
	for k,_ in pairs(Plants) do
		ClearTargetZone("Plants:"..k)
	end

	Plants = Table or {}
	GLOBAL_GROWTH_TIME = growthTime or GLOBAL_GROWTH_TIME

	-- reset objetos/meta
	for k in pairs(Objects) do ClearObjects(k) end
	Meta = {}
	local nowTick = GetGameTimer()
	for id,_ in pairs(Plants) do
		Meta[id] = { baseNow = serverNow or 0, recvTick = nowTick }
	end
end)

RegisterNetEvent("plants:New")
AddEventHandler("plants:New",function(Number,Table,serverNow,growthTime)
	Plants[Number] = Table
	GLOBAL_GROWTH_TIME = growthTime or GLOBAL_GROWTH_TIME
	Meta[Number] = { baseNow = serverNow or 0, recvTick = GetGameTimer() }
end)

RegisterNetEvent("plants:Update")
AddEventHandler("plants:Update",function(Number,Table,serverNow,growthTime)
	if not Plants[Number] then return end
	Plants[Number] = Table
	GLOBAL_GROWTH_TIME = growthTime or GLOBAL_GROWTH_TIME
	Meta[Number] = { baseNow = serverNow or (Meta[Number] and Meta[Number].baseNow or 0), recvTick = GetGameTimer() }
end)

RegisterNetEvent("plants:Remove")
AddEventHandler("plants:Remove",function(Number)
	-- defesa extra: remove a zone se existir
	ClearTargetZone("Plants:"..Number)

	if Plants[Number] then Plants[Number] = nil end
	ClearObjects(Number)
	Meta[Number] = nil
end)

-- remoção imediata para quem colhe (feedback instantâneo)
RegisterNetEvent("plants:LocalRemove")
AddEventHandler("plants:LocalRemove", function(Number)
	ClearObjects(Number)
end)
