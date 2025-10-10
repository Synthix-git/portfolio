-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRPC = Tunnel.getInterface("vRP")
vRP  = Proxy.getInterface("vRP")

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
Creative = {}
Tunnel.bindInterface("boosting",Creative)

-----------------------------------------------------------------------------------------------------------------------------------------
-- STATE
-----------------------------------------------------------------------------------------------------------------------------------------
local Active           = {}
local Pendings         = {}
local Cooldowns        = {}
local ActiveMax        = {}
local MaxContracts     = 0
local TotalContracts   = 0
local SpawnInProgress  = {} -- [Passport] = os.time()

local BoostingPlates   = BoostingPlates   or {} -- [plate] = NetId
local UsedBoostPlates  = UsedBoostPlates  or {} -- [plate] = true

-- gerador de plate fallback
local _plateCharset = {}
do
  local s = "ABCDEFGHJKLMNPQRSTUVWXYZ123456789"
  for i = 1, #s do _plateCharset[i] = s:sub(i,i) end
end
local function _randPlate(n)
  local t = {}
  for i = 1, n do t[i] = _plateCharset[math.random(#_plateCharset)] end
  return table.concat(t)
end
local function BoostGenPlate()
  local tries, plate = 0, ""
  repeat
    plate = ("BX%s"):format(_randPlate(6))
    tries = tries + 1
  until not UsedBoostPlates[plate] or tries > 50
  UsedBoostPlates[plate] = true
  return plate
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONTRACTS / MINIMALS / LEVELS (iguais aos teus)
-----------------------------------------------------------------------------------------------------------------------------------------
local Contracts = {
    [1] = {
        { Vehicle = "gt500",     Timer = 3600, Value = 150, Plate = "", Class = 1, Exp = 5 },
        { Vehicle = "toros",     Timer = 3600, Value = 150, Plate = "", Class = 1, Exp = 5 },
        { Vehicle = "sheava",    Timer = 3600, Value = 150, Plate = "", Class = 1, Exp = 5 },
        { Vehicle = "surano",    Timer = 3600, Value = 150, Plate = "", Class = 1, Exp = 5 },
        { Vehicle = "rapidgt",   Timer = 3600, Value = 150, Plate = "", Class = 1, Exp = 5 },
        { Vehicle = "feltzer2",  Timer = 3600, Value = 150, Plate = "", Class = 1, Exp = 5 },
        { Vehicle = "alpha",     Timer = 3600, Value = 150, Plate = "", Class = 1, Exp = 5 },
        { Vehicle = "gp1",       Timer = 3600, Value = 150, Plate = "", Class = 1, Exp = 5 },
        { Vehicle = "infernus",  Timer = 3600, Value = 150, Plate = "", Class = 1, Exp = 5 },
        { Vehicle = "bullet",    Timer = 3600, Value = 150, Plate = "", Class = 1, Exp = 5 },
        { Vehicle = "freecrawler",Timer=3600, Value = 150, Plate = "", Class = 1, Exp = 5 },
        { Vehicle = "turismo2",  Timer = 3600, Value = 150, Plate = "", Class = 1, Exp = 5 },
        { Vehicle = "zr350",     Timer = 3600, Value = 150, Plate = "", Class = 1, Exp = 5 },
        { Vehicle = "locust",    Timer = 3600, Value = 150, Plate = "", Class = 1, Exp = 5 },
        { Vehicle = "seven70",   Timer = 3600, Value = 150, Plate = "", Class = 1, Exp = 5 },
        { Vehicle = "caracara2", Timer = 3600, Value = 150, Plate = "", Class = 1, Exp = 5 },
        { Vehicle = "ruffian",   Timer = 3600, Value = 150, Plate = "", Class = 1, Exp = 5 },
        { Vehicle = "enduro",    Timer = 3600, Value = 150, Plate = "", Class = 1, Exp = 5 }
    },

    [2] = {
        { Vehicle = "specter",   Timer = 3600, Value = 175, Plate = "", Class = 2, Exp = 4 },
        { Vehicle = "rebla",     Timer = 3600, Value = 175, Plate = "", Class = 2, Exp = 4 },
        { Vehicle = "ruston",    Timer = 3600, Value = 175, Plate = "", Class = 2, Exp = 4 },
        { Vehicle = "jester",    Timer = 3600, Value = 175, Plate = "", Class = 2, Exp = 4 },
        { Vehicle = "banshee",   Timer = 3600, Value = 175, Plate = "", Class = 2, Exp = 4 },
        { Vehicle = "cypher",    Timer = 3600, Value = 175, Plate = "", Class = 2, Exp = 4 },
        { Vehicle = "voltic",    Timer = 3600, Value = 175, Plate = "", Class = 2, Exp = 4 },
        { Vehicle = "rt3000",    Timer = 3600, Value = 175, Plate = "", Class = 2, Exp = 4 },
        { Vehicle = "sc1",       Timer = 3600, Value = 175, Plate = "", Class = 2, Exp = 4 },
        { Vehicle = "carbonizzare",Timer=3600,Value=175, Plate = "", Class = 2, Exp = 4 },
        { Vehicle = "infernus2", Timer = 3600, Value = 175, Plate = "", Class = 2, Exp = 4 },
        { Vehicle = "imorgon",   Timer = 3600, Value = 175, Plate = "", Class = 2, Exp = 4 },
        { Vehicle = "sultan2",   Timer = 3600, Value = 175, Plate = "", Class = 2, Exp = 4 },
        { Vehicle = "elegy2",    Timer = 3600, Value = 175, Plate = "", Class = 2, Exp = 4 },
        { Vehicle = "yosemite2", Timer = 3600, Value = 175, Plate = "", Class = 2, Exp = 4 },
        { Vehicle = "ninef",     Timer = 3600, Value = 175, Plate = "", Class = 2, Exp = 4 },
        { Vehicle = "everon",    Timer = 3600, Value = 175, Plate = "", Class = 2, Exp = 4 },
        { Vehicle = "double",    Timer = 3600, Value = 175, Plate = "", Class = 2, Exp = 4 }
    },

    [3] = {
        { Vehicle = "jackal",    Timer = 3600, Value = 200, Plate = "", Class = 3, Exp = 4 },
        { Vehicle = "sugoi",     Timer = 3600, Value = 200, Plate = "", Class = 3, Exp = 4 },
        { Vehicle = "penumbra",  Timer = 3600, Value = 200, Plate = "", Class = 3, Exp = 4 },
        { Vehicle = "paragon",   Timer = 3600, Value = 200, Plate = "", Class = 3, Exp = 4 },
        { Vehicle = "nero",      Timer = 3600, Value = 200, Plate = "", Class = 3, Exp = 4 },
        { Vehicle = "komoda",    Timer = 3600, Value = 200, Plate = "", Class = 3, Exp = 4 },
        { Vehicle = "ninef2",    Timer = 3600, Value = 200, Plate = "", Class = 3, Exp = 4 },
        { Vehicle = "futo",      Timer = 3600, Value = 200, Plate = "", Class = 3, Exp = 4 },
        { Vehicle = "buffalo3",  Timer = 3600, Value = 200, Plate = "", Class = 3, Exp = 4 },
        { Vehicle = "banshee2",  Timer = 3600, Value = 200, Plate = "", Class = 3, Exp = 4 },
        { Vehicle = "adder",     Timer = 3600, Value = 200, Plate = "", Class = 3, Exp = 4 },
        { Vehicle = "schlagen",  Timer = 3600, Value = 200, Plate = "", Class = 3, Exp = 4 },
        { Vehicle = "bestiagts", Timer = 3600, Value = 200, Plate = "", Class = 3, Exp = 4 },
        { Vehicle = "jester3",   Timer = 3600, Value = 200, Plate = "", Class = 3, Exp = 4 },
        { Vehicle = "elegy",     Timer = 3600, Value = 200, Plate = "", Class = 3, Exp = 4 },
        { Vehicle = "cheetah2",  Timer = 3600, Value = 200, Plate = "", Class = 3, Exp = 4 },
        { Vehicle = "khamelion", Timer = 3600, Value = 200, Plate = "", Class = 3, Exp = 4 },
        { Vehicle = "sanchez",   Timer = 3600, Value = 200, Plate = "", Class = 3, Exp = 4 },
        { Vehicle = "diablous2", Timer = 3600, Value = 200, Plate = "", Class = 3, Exp = 4 }
    },

    [4] = {
        { Vehicle = "omnis",     Timer = 3600, Value = 225, Plate = "", Class = 4, Exp = 3 },
        { Vehicle = "massacro",  Timer = 3600, Value = 225, Plate = "", Class = 4, Exp = 3 },
        { Vehicle = "euros",     Timer = 3600, Value = 225, Plate = "", Class = 4, Exp = 3 },
        { Vehicle = "cheetah",   Timer = 3600, Value = 225, Plate = "", Class = 4, Exp = 3 },
        { Vehicle = "tyrus",     Timer = 3600, Value = 225, Plate = "", Class = 4, Exp = 3 },
        { Vehicle = "kuruma",    Timer = 3600, Value = 225, Plate = "", Class = 4, Exp = 3 },
        { Vehicle = "nero2",     Timer = 3600, Value = 225, Plate = "", Class = 4, Exp = 3 },
        { Vehicle = "ardent",    Timer = 3600, Value = 225, Plate = "", Class = 4, Exp = 3 },
        { Vehicle = "sultan3",   Timer = 3600, Value = 225, Plate = "", Class = 4, Exp = 3 },
        { Vehicle = "autarch",   Timer = 3600, Value = 225, Plate = "", Class = 4, Exp = 3 },
        { Vehicle = "fmj",       Timer = 3600, Value = 225, Plate = "", Class = 4, Exp = 3 },
        { Vehicle = "jester2",   Timer = 3600, Value = 225, Plate = "", Class = 4, Exp = 3 },
        { Vehicle = "carbonrs",  Timer = 3600, Value = 225, Plate = "", Class = 4, Exp = 3 },
        { Vehicle = "reever",    Timer = 3600, Value = 225, Plate = "", Class = 4, Exp = 3 }
    },

    [5] = {
        { Vehicle = "gb200",     Timer = 3600, Value = 250, Plate = "", Class = 5, Exp = 3 },
        { Vehicle = "sultanrs",  Timer = 3600, Value = 250, Plate = "", Class = 5, Exp = 3 },
        { Vehicle = "pariah",    Timer = 3600, Value = 250, Plate = "", Class = 5, Exp = 3 },
        { Vehicle = "vacca",     Timer = 3600, Value = 250, Plate = "", Class = 5, Exp = 3 },
        { Vehicle = "zentorno",  Timer = 3600, Value = 250, Plate = "", Class = 5, Exp = 3 },
        { Vehicle = "t20",       Timer = 3600, Value = 250, Plate = "", Class = 5, Exp = 3 },
        { Vehicle = "issi7",     Timer = 3600, Value = 250, Plate = "", Class = 5, Exp = 3 },
        { Vehicle = "penetrator",Timer = 3600,Value=250, Plate = "", Class = 5, Exp = 3 },
        { Vehicle = "emerus",    Timer = 3600, Value = 250, Plate = "", Class = 5, Exp = 3 },
        { Vehicle = "revolter",  Timer = 3600, Value = 250, Plate = "", Class = 5, Exp = 3 },
        { Vehicle = "sentinel3", Timer = 3600, Value = 250, Plate = "", Class = 5, Exp = 3 },
        { Vehicle = "bati",      Timer = 3600, Value = 250, Plate = "", Class = 5, Exp = 3 },
        { Vehicle = "bf400",     Timer = 3600, Value = 250, Plate = "", Class = 5, Exp = 3 }
    },

    [6] = {
        { Vehicle = "flashgt",   Timer = 3600, Value = 275, Plate = "", Class = 6, Exp = 2 },
        { Vehicle = "dominator7",Timer = 3600, Value = 275, Plate = "", Class = 6, Exp = 2 },
        { Vehicle = "osiris",    Timer = 3600, Value = 275, Plate = "", Class = 6, Exp = 2 },
        { Vehicle = "turismor",  Timer = 3600, Value = 275, Plate = "", Class = 6, Exp = 2 },
        { Vehicle = "jester4",   Timer = 3600, Value = 275, Plate = "", Class = 6, Exp = 2 },
        { Vehicle = "pfister811",Timer = 3600, Value = 275, Plate = "", Class = 6, Exp = 2 },
        { Vehicle = "italigtb2", Timer = 3600, Value = 275, Plate = "", Class = 6, Exp = 2 },
        { Vehicle = "akuma",     Timer = 3600, Value = 275, Plate = "", Class = 6, Exp = 2 }
    }
}

local Minimals = {
	[1]={Min=300, Max=900}, [2]={Min=600, Max=1200}, [3]={Min=900, Max=1500},
	[4]={Min=1200, Max=1800}, [5]={Min=1500, Max=2100}, [6]={Min=1800, Max=2700}
}
local Levels = { 0,1000,2000,3500,5000,7500 }

local function AboutClasses(Experience)
	local ret = 1
	for i=1,#Levels do
		if Experience >= Levels[i] then ret = i end
	end
	return ret
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS
-----------------------------------------------------------------------------------------------------------------------------------------
local function ensurePassportTables(Passport)
	if not Pendings[Passport] then Pendings[Passport] = {} end
	if not Cooldowns[Passport] then
		Cooldowns[Passport] = { [1]=os.time(),[2]=os.time(),[3]=os.time(),[4]=os.time(),[5]=os.time(),[6]=os.time() }
	end
end
local function CountTable(t) local c=0; if t then for _ in pairs(t) do c=c+1 end end; return c end

local function SeedOnePending(Passport)
	ensurePassportTables(Passport)
	local xp  = vRP.GetExperience(Passport,"Boosting") or 0
	local lvl = AboutClasses(xp)
	local cls = math.random(lvl)
	if cls == 6 and (MaxContracts >= 3 or ActiveMax[Passport]) then
		cls = math.min(5,lvl)
	end
	if not Contracts[cls] or #Contracts[cls] == 0 then return false end
	if CountTable(Pendings[Passport]) >= 3 then return false end

	TotalContracts = TotalContracts + 1
	local pick = math.random(#Contracts[cls])
	Pendings[Passport][TotalContracts] = Contracts[cls][pick]
	Cooldowns[Passport][cls] = os.time() + math.random(Minimals[cls].Min, Minimals[cls].Max)

	if cls == 6 then
		MaxContracts = MaxContracts + 1
		ActiveMax[Passport] = true
	end
	return true
end

-- SERVER helper: obter entidade a partir do NetId (retorna handle ou nil)
local function _srvEnt(netId)
	if not netId then return nil end
	local ent = NetworkGetEntityFromNetworkId(netId)
	if ent and DoesEntityExist(ent) then return ent end
	return nil
end


-----------------------------------------------------------------------------------------------------------------------------------------
-- LOOP: GERADOR
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		Wait(60000)
		for Passport,_ in pairs(Pendings) do
			if vRP.Source(Passport) then
				ensurePassportTables(Passport)
				local experience = vRP.GetExperience(Passport,"Boosting") or 0
				local lvl = AboutClasses(experience)
				local cls = math.random(lvl)

				if os.time() >= (Cooldowns[Passport][cls] or 0) and CountTable(Pendings[Passport]) < 3 then
					if not (cls == 6 and (MaxContracts >= 3 or ActiveMax[Passport])) then
						TotalContracts = TotalContracts + 1
						local pick = math.random(#Contracts[cls])
						Pendings[Passport][TotalContracts] = Contracts[cls][pick]
						Cooldowns[Passport][cls] = os.time() + math.random(Minimals[cls].Min, Minimals[cls].Max)
						if cls == 6 then
							MaxContracts = MaxContracts + 1
							ActiveMax[Passport] = true
						end
					end
				end
			end
		end
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- EXPERIENCE / ACTIVES / PENDINGS (iguais aos teus)
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Experience()
	local src = source
	local Passport = vRP.Passport(src)
	if not Passport then return {0,Levels} end
	ensurePassportTables(Passport)
	if CountTable(Pendings[Passport]) == 0 then
		SeedOnePending(Passport)
	end
	local xp = vRP.GetExperience(Passport,"Boosting") or 0
	return { xp, Levels }
end

function Creative.Actives()
	local src = source
	local Passport = vRP.Passport(src)
	if not Passport then return false end

	if Active[Passport] then
		if os.time() >= Active[Passport].Timer then
			local class = Active[Passport].Class
			ensurePassportTables(Passport)
			Cooldowns[Passport][class] = os.time() + math.random(Minimals[class].Min, Minimals[class].Max)
			Active[Passport] = nil
		else
			local a = Active[Passport]
			return {
				Number  = a.Number,
				Vehicle = VehicleName(a.Vehicle),
				Timer   = a.Timer - os.time(),
				Class   = a.Class,
				Value   = a.Value,
				Exp     = a.Exp
			}
		end
	end
	return false
end

function Creative.Pendings()
	local src = source
	local Passport = vRP.Passport(src)
	if not Passport then return {} end
	ensurePassportTables(Passport)
	while CountTable(Pendings[Passport]) < 2 do
		if not SeedOnePending(Passport) then break end
	end
	local results = {}
	for Number,v in pairs(Pendings[Passport]) do
		results[#results+1] = {
			Number  = Number,
			Vehicle = VehicleName(v.Vehicle),
			Timer   = v.Timer,
			Class   = v.Class,
			Value   = v.Value,
			Exp     = v.Exp,
			Scratch = false
		}
	end
	return results
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- ACCEPT (gera plate fixa)
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Accept(Selected)
	local src = source
	local Passport = vRP.Passport(src)
	if not Passport then return false end

	ensurePassportTables(Passport)
	if Active[Passport] then return false end
	if not (Pendings[Passport] and Pendings[Passport][Selected]) then return false end

	local pending = Pendings[Passport][Selected]
	if vRP.TakeItem(Passport, "platinum", pending.Value) then
		local plate = (vRP.GeneratePlate and vRP.GeneratePlate()) or BoostGenPlate()

		Active[Passport] = {
			Vehicle = pending.Vehicle,
			Timer   = os.time() + pending.Timer,
			Number  = Selected,
			Class   = pending.Class,
			Value   = pending.Value,
			Exp     = pending.Exp,
			Plate   = plate,
			NetId   = nil,
			SpawnLock = nil,
			SpawnLockAt = nil,
			Spawned = false
		}

		TriggerClientEvent("boosting:Active", src, Active[Passport].Vehicle, Active[Passport].Class, plate)
		Pendings[Passport][Selected] = nil
		return true
	end
	return false
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- SCRATCH / TRANSFER / DECLINE (iguais aos teus)
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Scratch(_) local src=source; return vRP.Passport(src) and true or false end

function Creative.Transfer(Selected,OtherPassport)
	local src = source
	local Passport = vRP.Passport(src)
	if not Passport then return false end
	if not (Selected and OtherPassport) then return false end

	ensurePassportTables(Passport)
	ensurePassportTables(OtherPassport)

	if not (Pendings[Passport] and Pendings[Passport][Selected]) then return false end
	if CountTable(Pendings[OtherPassport]) >= 3 then return false end

	local Class = Pendings[Passport][Selected].Class
	Cooldowns[Passport][Class] = os.time() + math.random(Minimals[Class].Min, Minimals[Class].Max)

	Pendings[OtherPassport][#Pendings[OtherPassport]+1] = Pendings[Passport][Selected]
	Pendings[Passport][Selected] = nil

	TriggerClientEvent("Notify", src, "Sucesso", "Transferência concluída.", "verde", 5000)
	return true
end

function Creative.Decline(Selected)
	local src = source
	local Passport = vRP.Passport(src)
	if not Passport then return false end

	ensurePassportTables(Passport)
	if not (Pendings[Passport] and Pendings[Passport][Selected]) then return false end

	local Class = Pendings[Passport][Selected].Class
	Cooldowns[Passport][Class] = os.time() + math.random(Minimals[Class].Min, Minimals[Class].Max)
	Pendings[Passport][Selected] = nil
	return true
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- REMOVE (EXPORT)
-----------------------------------------------------------------------------------------------------------------------------------------
exports("Remove", function(Passport, Plate)
	if not Passport or not Plate then return false end
	local act = Active[Passport]
	if not act then return false end
	if (act.Plate or "") ~= tostring(Plate) then return false end

	local class = act.Class or 1
	ensurePassportTables(Passport)
	local range = Minimals[class] or Minimals[1]
	Cooldowns[Passport][class] = os.time() + math.random(range.Min, range.Max)

	do
		local ent = _srvEnt(act.NetId)
		if ent then pcall(DeleteEntity, ent) end
	end


	BoostingPlates[Plate]  = nil
	UsedBoostPlates[Plate] = nil
	act.NetId, act.SpawnLock, act.SpawnLockAt, act.Spawned, act.Plate = nil, nil, nil, nil, nil
	Active[Passport] = nil
	SpawnInProgress[Passport] = nil
	return true
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- CREATE OR ATTACH — anti spawn infinito + idempotência por plate
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.CreateOrAttach(plate, modelName, class, coords4)
	local src      = source
	local Passport = vRP.Passport(src)
	if not Passport then return false end
	if type(coords4) ~= "vector4" then return false end
	if type(plate) ~= "string" or plate == "" then return false end

	local A = Active[Passport]
	if not A or A.Class ~= class then return false end
	if (A.Plate or "") ~= plate then return false end

	-- já existe no índice global?
	do
		local existing = BoostingPlates[plate]
		local ent = existing and _srvEnt(existing) or nil
		if ent then
			A.NetId   = existing
			A.Spawned = true
			return A.NetId
		end
	end

	-- janela de respawn curta: não cria outro
	if A.Spawned and (os.time() - (A.SpawnLockAt or 0)) < 30 then
		return A.NetId or false
	end

	-- anti-flood por passaporte (8s)
	if SpawnInProgress[Passport] and (os.time() - SpawnInProgress[Passport]) < 8 then
		return A.NetId or false
	end
	SpawnInProgress[Passport] = os.time()

	-- lock local (15s)
	if A.SpawnLock and (os.time() - (A.SpawnLockAt or 0)) < 15 then
		return A.NetId or false
	end
	A.SpawnLock   = true
	A.SpawnLockAt = os.time()

	-- cria o veículo
	local mhash = GetHashKey(modelName)
	local veh   = CreateVehicle(mhash, coords4.x, coords4.y, coords4.z, coords4.w, true, true)
	if not DoesEntityExist(veh) then
		A.SpawnLock   = nil
		A.SpawnLockAt = nil
		SetTimeout(1500,function() SpawnInProgress[Passport] = nil end)
		return false
	end

	-- plate fixa
	SetVehicleNumberPlateText(veh, plate)
	SetEntityIgnoreRequestControlFilter(veh, true)

	local state = Entity(veh)["state"]
	if state then
		state:set("Fuel", 100, true)
		state:set("Tower", true, true)
		state:set("Nitro", 2000, true)
	end

	TriggerEvent("inventory:Boosting", plate, {
		Amount   = 0,
		Source   = src,
		Passport = Passport,
		Class    = class
	})

	TriggerClientEvent("NotifyPush", src, {
		code = 31, title = "Informações do Veículo",
		x = coords4.x, y = coords4.y, z = coords4.z,
		vehicle = (VehicleName(modelName).." - "..plate), color = 44
	})

	local netId = NetworkGetNetworkIdFromEntity(veh)
	A.NetId         = netId
	A.Spawned       = true
	A.SpawnLock     = nil
	BoostingPlates[plate] = netId

	SetTimeout(1000,function() SpawnInProgress[Passport] = nil end)
	return netId
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- PAYMENT (EXPORT) — (mantém a tua lógica de recompensa/XP/cooldown)
-----------------------------------------------------------------------------------------------------------------------------------------
exports("Payment", function(src, Passport)
	if not Passport then return false end
	local act = Active[Passport]
	if not act then return false end

	local Class = act.Class or 1
	local range = Minimals[Class] or Minimals[1]
	local Total = math.random(range.Min, range.Max)
	local GainExperience = act.Exp or 0
	local Valuation      = (act.Value or 0) * 3

	if act.Timer and act.Timer >= os.time() then
		if exports["party"] and exports["party"].DoesExist and exports["party"].DoesExist(Passport, 2) then
			local Consult = exports["party"].Room(Passport, src, 25) or {}
			for i = 1, CountTable(Consult) do
				local otherSrc = Consult[i].Source
				local otherPpt = Consult[i].Passport
				if otherSrc and vRP.Passport(otherSrc) and otherPpt then
					vRP.PutExperience(otherPpt, "Boosting", GainExperience)
					vRP.GenerateItem(otherPpt, "platinum", Valuation, true)
					if exports["pause"] and exports["pause"].AddPoints then
						exports["pause"]:AddPoints(otherPpt, GainExperience)
					end
					ensurePassportTables(otherPpt)
					Cooldowns[otherPpt][Class] = os.time() + Total
					Active[otherPpt] = nil
				end
			end

			vRP.PutExperience(Passport, "Boosting", GainExperience)
			vRP.GenerateItem(Passport, "platinum", Valuation, true)
			if exports["pause"] and exports["pause"].AddPoints then
				exports["pause"]:AddPoints(Passport, GainExperience)
			end
			ensurePassportTables(Passport)
			Cooldowns[Passport][Class] = os.time() + Total
		else
			vRP.PutExperience(Passport, "Boosting", GainExperience)
			vRP.GenerateItem(Passport, "platinum", Valuation, true)
			if exports["pause"] and exports["pause"].AddPoints then
				exports["pause"]:AddPoints(Passport, GainExperience)
			end
			ensurePassportTables(Passport)
			Cooldowns[Passport][Class] = os.time() + Total
		end
	end

	if act.Plate then
		BoostingPlates[act.Plate]  = nil
		UsedBoostPlates[act.Plate] = nil
	end
		do
			local ent = _srvEnt(act.NetId)
			if ent then pcall(DeleteEntity, ent) end
		end


	act.NetId, act.SpawnLock, act.SpawnLockAt, act.Spawned, act.Plate = nil, nil, nil, nil, nil
	Active[Passport] = nil
	SpawnInProgress[Passport] = nil
	return true
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- COMPLETE (client envia netId + plate) — valida safado e apaga sempre
-----------------------------------------------------------------------------------------------------------------------------------------
-- Toggle de debug local (true para ver detalhes de plate/model recebidos no momento da entrega)
local DEBUG_DELIVERY = false

-- Helper seguro: devolve o hash de modelo a partir de um NetId (ou nil)
local function _ModelFromNetId(netId)
	local ent = _srvEnt(netId)
	if not ent then return nil end
	return GetEntityModel(ent), ent
end


-- === PATCH: COMPLETE aceita por plate OU por modelo ===
function Creative.Complete(clientNetId, clientPlate)
    local src = source
    local Passport = vRP.Passport(src)
    if not Passport then return false end

    local act = Active[Passport]
    if not act then return false end

    -- Normaliza plates (sem espaços e uppercase)
    local expectedPlate = tostring(act.Plate or ""):gsub("%s+",""):upper()
    local gotPlate      = tostring(clientPlate or ""):gsub("%s+",""):upper()
    local plateOk       = (gotPlate ~= "" and expectedPlate ~= "" and gotPlate == expectedPlate)

    -- Validação por MODELO (fallback)
    local expectedModelHash = GetHashKey(act.Vehicle or "")
    local modelOk = false
    local entFromClient = nil

    do
        local hash, ent = _ModelFromNetId(clientNetId)
        if hash and hash == expectedModelHash then
            modelOk = true
            entFromClient = ent
        end
    end

    if DEBUG_DELIVERY then
        local dbgTxt = ("<b>DEBUG Boosting</b><br>Esperado: Plate=<b>%s</b> | Model=<b>%s</b><br>Recebido: Plate=<b>%s</b> | ModelOk=<b>%s</b>")
            :format(expectedPlate ~= "" and expectedPlate or "—", tostring(act.Vehicle or "—"), gotPlate ~= "" and gotPlate or "—", modelOk and "true" or "false")
        TriggerClientEvent("Notify", src, "Boosting", dbgTxt, "azul", 7000)
    end

    -- Se falhar plate e falhar modelo, recusa
	if not modelOk then
		return false
	end
    -- Escolhe melhor NetId para apagar
	local netId = act.NetId
	local ent = _srvEnt(netId) or _srvEnt(clientNetId) or entFromClient
	if ent then pcall(DeleteEntity, ent) end

    --  Recompensa / cooldown  
    local Class = act.Class or 1
    local range = Minimals[Class] or Minimals[1]
    local Total = math.random(range.Min, range.Max)
    local GainExperience = act.Exp or 0
    local Valuation      = (act.Value or 0) * 3

    if act.Timer and act.Timer >= os.time() then
        if exports["party"] and exports["party"].DoesExist and exports["party"].DoesExist(Passport,2) then
            local Consult = exports["party"].Room(Passport,src,25) or {}
            for i=1,CountTable(Consult) do
                local otherSrc = Consult[i].Source
                local otherPpt = Consult[i].Passport
                if otherSrc and vRP.Passport(otherSrc) and otherPpt then
                    vRP.PutExperience(otherPpt,"Boosting",GainExperience)
                    vRP.GenerateItem(otherPpt,"platinum",Valuation,true)
                    if exports["pause"] and exports["pause"].AddPoints then
                        exports["pause"]:AddPoints(otherPpt,GainExperience)
                    end
                    ensurePassportTables(otherPpt)
                    Cooldowns[otherPpt][Class] = os.time() + Total
                    Active[otherPpt] = nil
                end
            end
            vRP.PutExperience(Passport,"Boosting",GainExperience)
            vRP.GenerateItem(Passport,"platinum",Valuation,true)
            if exports["pause"] and exports["pause"].AddPoints then
                exports["pause"]:AddPoints(Passport,GainExperience)
            end
            ensurePassportTables(Passport)
            Cooldowns[Passport][Class] = os.time() + Total
        else
            vRP.PutExperience(Passport,"Boosting",GainExperience)
            vRP.GenerateItem(Passport,"platinum",Valuation,true)
            if exports["pause"] and exports["pause"].AddPoints then
                exports["pause"]:AddPoints(Passport,GainExperience)
            end
            ensurePassportTables(Passport)
            Cooldowns[Passport][Class] = os.time() + Total
        end
    end

    -- Limpa índices/estado
    if act.Plate then
        BoostingPlates[act.Plate]  = nil
        UsedBoostPlates[act.Plate] = nil
    end

    act.NetId, act.SpawnLock, act.SpawnLockAt, act.Spawned, act.Plate = nil, nil, nil, nil, nil
    Active[Passport] = nil
    SpawnInProgress[Passport] = nil

    -- Feedback
    TriggerClientEvent("Notify", src, "Boosting", "Entrega concluída com sucesso.", "verde", 5000)
    TriggerClientEvent("boosting:Reset", src)
    return true
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Connect",function(Passport)
	ensurePassportTables(Passport)
end)
