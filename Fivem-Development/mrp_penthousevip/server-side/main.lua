-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP / TUNNEL / PROXY
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP          = Proxy.getInterface("vRP")
vRPC         = Tunnel.getInterface("vRP")

Creative = {}
Tunnel.bindInterface("penthouse", Creative)
vCLIENT = Tunnel.getInterface("penthouse")

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS / STATE
-----------------------------------------------------------------------------------------------------------------------------------------
local function now() return os.time() end
local ActiveGuests = {} -- [guestPass] = ownerPass

local function isOwnerEligible(src, pass)
	if not pass then return false end
	if vRP.HasGroup(pass,"Premium") and (vRP.LevelPremium and vRP.LevelPremium(src) == 1) then return true end -- VIP Ouro
	if vRP.HasGroup(pass,"Streamer") or vRP.HasGroup(pass,"Streamers") then return true end
	return false
end

local function isOwnerOnline(ownerPass)
	local sources = vRP.Sources() or {}
	for s,_ in pairs(sources) do
		if vRP.Passport(s) == ownerPass then return true, s end
	end
	return false, nil
end

local function log(msg, src)
	if exports["discord"] and exports["discord"].Embed then
		exports["discord"]:Embed(Config.LogsChannel or "Penthouse", msg, src)
	elseif exports["logs"] and exports["logs"].Embed then
		exports["logs"]:Embed(Config.LogsChannel or "Penthouse", msg, src)
	end
end

-- distância 3D simples
local function dist3(a, b)
	local ax,ay,az = (a.x or a[1]), (a.y or a[2]), (a.z or a[3])
	local bx,by,bz = (b.x or b[1]), (b.y or b[2]), (b.z or b[3])
	if not (ax and ay and az and bx and by and bz) then return 9999 end
	local dx,dy,dz = ax-bx, ay-by, az-bz
	return math.sqrt(dx*dx + dy*dy + dz*dz)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONVITES via SrvData
-----------------------------------------------------------------------------------------------------------------------------------------
local function K_Invites(owner) return "Penthouse:Invites:"..owner end
local function K_Inbox(guest)  return "Penthouse:Inbox:"..guest end

local function addInvite(owner, guest, ttl)
	local inv = vRP.GetSrvData(K_Invites(owner), true) or {}
	inv[tostring(guest)] = now() + ttl
	vRP.SetSrvData(K_Invites(owner), inv, true)

	local inbox = vRP.GetSrvData(K_Inbox(guest), true) or {}
	inbox[tostring(owner)] = now() + ttl
	vRP.SetSrvData(K_Inbox(guest), inbox, true)
end

local function remInvite(owner, guest)
	local inv = vRP.GetSrvData(K_Invites(owner), true) or {}
	inv[tostring(guest)] = nil
	vRP.SetSrvData(K_Invites(owner), inv, true)

	local inbox = vRP.GetSrvData(K_Inbox(guest), true) or {}
	inbox[tostring(owner)] = nil
	vRP.SetSrvData(K_Inbox(guest), inbox, true)
end

local function clearInvites(owner) vRP.RemSrvData(K_Invites(owner)) end
local function clearInbox(guest)   vRP.RemSrvData(K_Inbox(guest)) end

local function fetchValidOwnerFromInbox(guestPass)
	local inbox = vRP.GetSrvData(K_Inbox(guestPass), true) or {}
	local best, expBest = nil, 0
	local t = now()
	for owner, exp in pairs(inbox) do
		local e = tonumber(exp or 0) or 0
		if e > t and e > expBest then best, expBest = tonumber(owner), e end
	end
	return best
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- NORMALIZADOR DE CHEST (defensivo)
-----------------------------------------------------------------------------------------------------------------------------------------
local function normalizeNameMode(Name, Mode)
	local n = tostring(Name or "")
	local m = tostring(Mode or "")

	if n:find("^Vault:") or n:find("^Fridge:") then
		local mm, rest = n:match("^(Vault|Fridge):(.*)$")
		if mm and rest and rest ~= "" then
			n, m = rest, mm
		end
	end

	if m ~= "Vault" and m ~= "Fridge" then
		local mm = m:match("^Penthouse(Vault)$") or m:match("^Penthouse(Fridge)$")
		if mm == "Vault" or mm == "Fridge" then
			m = mm
		end
	end

	return n, m
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- ENTRADA IMEDIATA NA PORTA (pedido ao convidado)
-----------------------------------------------------------------------------------------------------------------------------------------
local function admitGuestDirect(owner, guestSrc, guestPass)
	remInvite(owner, guestPass) -- one-shot
	ActiveGuests[guestPass] = owner

	local bucket = Config.BucketForOwner(owner)
	if exports["vrp"] and exports["vrp"].Bucket then
		exports["vrp"]:Bucket(guestSrc, "Enter", bucket)
	end

	TriggerClientEvent("penthouse:EnterGuest", guestSrc, {
		owner    = owner,
		bucket   = bucket,
		interior = Config.InteriorSpawn
	})

	log(("🚪 Entrada imediata: Convidado #%s entrou na penthouse do #%s na porta."):format(guestPass, owner), guestSrc)
end

local function offerImmediateDoorEnter(owner, targetSrc, targetPass)
	local coord = vRPC.GetEntityCoords(targetSrc)
	if not coord then return end

	local c = {}
	if type(coord) == "table" then
		c.x = coord.x or coord[1]; c.y = coord.y or coord[2]; c.z = coord.z or coord[3]
	else
		return
	end

	local entry = { x = Config.EntryZone.x, y = Config.EntryZone.y, z = Config.EntryZone.z }
	local radius = (Config.EntryRadius or 2.25) + 0.75
	if dist3(c, entry) <= radius then
		local ownerName = vRP.FullName(owner)
		if vRP.Request(targetSrc, "Penthouse", "Queres <b>entrar agora</b> na penthouse de <b>"..ownerName.."</b>?", 15000) then
			admitGuestDirect(owner, targetSrc, targetPass)
		else
			TriggerClientEvent("Notify", targetSrc, "Penthouse", "Entrada <b>cancelada</b>.", "amarelo", 4000)
		end
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- API: CONVIDAR / REVOGAR
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.InviteByPassport(targetPassport)
	local src   = source
	local owner = vRP.Passport(src)
	if not owner then return false end
	if not isOwnerEligible(src, owner) then
		TriggerClientEvent("Notify", src, "Penthouse", "Sem <b>permissão</b>.", "vermelho", 5000)
		return false
	end

	targetPassport = tonumber(targetPassport or 0) or 0
	if targetPassport <= 0 or targetPassport == owner then
		TriggerClientEvent("Notify", src, "Penthouse", "Passaporte <b>inválido</b>.", "amarelo", 5000)
		return false
	end

	local rk = "Penthouse:InviteRate:"..owner..":"..targetPassport
	local last = tonumber(vRP.GetSrvData(rk, true) or 0) or 0
	if (now() - last) < (Config.InviteRatePerTargetSeconds or 8) then
		TriggerClientEvent("Notify", src, "Penthouse", "Aguarda <b>alguns segundos</b>.", "amarelo", 5000)
		return false
	end
	vRP.SetSrvData(rk, now(), true)

	addInvite(owner, targetPassport, Config.InviteTTLSeconds or 300)
	TriggerClientEvent("Notify", src, "Penthouse", "Convite enviado para <b>#"..targetPassport.."</b>.", "verde", 5000)

	local sources = vRP.Sources() or {}
	for tSrc,_ in pairs(sources) do
		if vRP.Passport(tSrc) == targetPassport then
			TriggerClientEvent("penthouse:InvitePing", tSrc, owner, vRP.FullName(owner))
			offerImmediateDoorEnter(owner, tSrc, targetPassport)
			break
		end
	end

	log(("👑 Convite criado — Dono #%s ➜ Convidado #%s"):format(owner, targetPassport), src)
	return true
end

function Creative.RevokeInvites()
	local src   = source
	local owner = vRP.Passport(src)
	if not owner or not isOwnerEligible(src, owner) then return false end
	clearInvites(owner)
	TriggerClientEvent("Notify", src, "Penthouse", "Convites <b>revogados</b>.", "amarelo", 5000)
	log(("🧹 Convites revogados pelo dono #%s"):format(owner), src)
	return true
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- ENTRAR: DONO
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.TryEnterAsOwner()
	local src   = source
	local owner = vRP.Passport(src)
	if not owner then return false end

	if not isOwnerEligible(src, owner) then
		TriggerClientEvent("Notify", src, "Penthouse", "Necessitas de <b>VIP Ouro</b> ou <b>Streamer</b>.", "vermelho", 6000)
		return false
	end

	if not vRP.Request(src, "Penthouse", "Queres <b>entrar</b> na tua penthouse?", 15000) then
		TriggerClientEvent("Notify", src, "Penthouse", "Entrada <b>cancelada</b>.", "amarelo", 4000)
		return false
	end

	-- compat com inventário: dono é “guest” de si próprio
	ActiveGuests[owner] = owner

	-- mete já o dono no bucket (defensivo)
	local bucket = Config.BucketForOwner(owner)
	if exports["vrp"] and exports["vrp"].Bucket then
		exports["vrp"]:Bucket(src, "Enter", bucket)
	end

	TriggerClientEvent("penthouse:EnterOwner", src, {
		owner    = owner,
		bucket   = bucket,
		interior = Config.InteriorSpawn,
		ghostMs  = Config.VehicleGhostMs or 8000
	})
	return true
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- ENTRAR: CONVIDADO
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.TryEnterAsGuest()
	local src   = source
	local guest = vRP.Passport(src)
	if not guest then return false end

	local owner = fetchValidOwnerFromInbox(guest)
	if not owner then
		TriggerClientEvent("Notify", src, "Penthouse", "Precisas de um <b>convite ativo</b>.", "amarelo", 6000)
		return false
	end

	local online, ownerSrc = isOwnerOnline(owner)
	if not online then
		TriggerClientEvent("Notify", src, "Penthouse", "O dono não está <b>online</b>.", "amarelo", 5000)
		return false
	end

	local ownerName = vRP.FullName(owner)
	if not vRP.Request(src, "Penthouse", "Queres <b>entrar</b> na penthouse de <b>"..ownerName.."</b>?", 15000) then
		TriggerClientEvent("Notify", src, "Penthouse", "Entrada <b>cancelada</b>.", "amarelo", 4000)
		return false
	end

	local guestName = vRP.FullName(guest)
	if not vRP.Request(ownerSrc, "Penthouse", "Autorizar a entrada de <b>"..guestName.." (#"..guest..")</b>?", 15000) then
		TriggerClientEvent("Notify", src, "Penthouse", "Pedido <b>recusado</b> pelo dono.", "vermelho", 5000)
		remInvite(owner, guest)
		return false
	end

	remInvite(owner, guest)
	ActiveGuests[guest] = owner

	local bucket = Config.BucketForOwner(owner)
	if exports["vrp"] and exports["vrp"].Bucket then
		exports["vrp"]:Bucket(src, "Enter", bucket)
	end

	TriggerClientEvent("penthouse:EnterGuest", src, {
		owner    = owner,
		bucket   = bucket,
		interior = Config.InteriorSpawn
	})
	log(("✅ Convidado #%s entrou na penthouse do #%s"):format(guest, owner), src)
	return true
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- BUCKET SYNC (dono + veículo)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("penthouse:SetBucketForPlayers")
AddEventHandler("penthouse:SetBucketForPlayers", function(owner, _playersIgnored, netVeh)
	local src = source
	local ownerPass = vRP.Passport(src)
	if not owner or owner ~= ownerPass then return end

	local bucket = Config.BucketForOwner(owner)

	if exports["vrp"] and exports["vrp"].Bucket then
		exports["vrp"]:Bucket(src, "Enter", bucket)
	end

	if netVeh and tonumber(netVeh) then
		local ent = NetworkGetEntityFromNetworkId(netVeh)
		if ent and DoesEntityExist(ent) then
			SetEntityRoutingBucket(ent, bucket)
		end
	end

	log(("🔷 Dono #%s entrou no bucket %s (sync veículo: %s)"):format(owner, bucket, tostring(netVeh or false)), src)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- SAIR (player + carro volta ao bucket 0)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("penthouse:ExitWithVehicle")
AddEventHandler("penthouse:ExitWithVehicle", function(netVeh)
	local src  = source
	local pass = vRP.Passport(src)
	if not pass then return end

	if exports["vrp"] and exports["vrp"].Bucket then
		exports["vrp"]:Bucket(src, "Exit")
	end

	if netVeh and tonumber(netVeh) then
		local ent = NetworkGetEntityFromNetworkId(netVeh)
		if ent and DoesEntityExist(ent) then
			SetEntityRoutingBucket(ent, 0)
		end
	end

	ActiveGuests[pass] = nil
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- Dono a sair com o carro: manter passageiros no mesmo veículo/assentos lá fora
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("penthouse:ExitVehicleAndPassengers")
AddEventHandler("penthouse:ExitVehicleAndPassengers", function(occupants, netVeh)
	local src  = source
	local pass = vRP.Passport(src)
	if not pass then return end

	local isOwner = ActiveGuests[pass] == pass
	if not isOwner then return end

	if type(occupants) == "table" then
		for _,info in ipairs(occupants) do
			local tSrc  = info.src
			local seat  = info.seat
			if tSrc and tSrc ~= src and Player(tSrc) then
				if exports["vrp"] and exports["vrp"].Bucket then
					exports["vrp"]:Bucket(tSrc, "Exit")
				end
				CreateThread(function()
					Wait(350)
					TriggerClientEvent("penthouse:FollowOwnerVehicle", tSrc, netVeh, seat)
				end)
				local gPass = vRP.Passport(tSrc)
				if gPass then ActiveGuests[gPass] = nil end
			end
		end
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- Dono a entrar: puxar passageiros para o interior mantendo assentos
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("penthouse:BringPassengersInside")
AddEventHandler("penthouse:BringPassengersInside", function(owner, occupants, netVeh)
	local src  = source
	local pass = vRP.Passport(src)
	if not pass or owner ~= pass then return end

	local bucket = Config.BucketForOwner(owner)

	if type(occupants) == "table" then
		for _,info in ipairs(occupants) do
			local tSrc = info.src
			local seat = info.seat
			if tSrc and tSrc ~= src and Player(tSrc) then
				if exports["vrp"] and exports["vrp"].Bucket then
					exports["vrp"]:Bucket(tSrc, "Enter", bucket)
				end
				local gPass = vRP.Passport(tSrc)
				if gPass then ActiveGuests[gPass] = owner end
				CreateThread(function()
					Wait(120)
					TriggerClientEvent("penthouse:PassengerEnterWithOwner", tSrc, owner, Config.InteriorSpawn, netVeh, seat, Config.VehicleGhostMs or 8000)
				end)
			end
		end
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Disconnect", function(passport, src)
	ActiveGuests[passport] = nil
	clearInvites(passport or 0)
	clearInbox(passport or 0)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- RESOURCE STOP: repõe todos no bucket 0
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("onResourceStop", function(res)
	if res ~= GetCurrentResourceName() then return end
	for src,_ in pairs(vRP.Sources() or {}) do
		if exports["vrp"] and exports["vrp"].Bucket then
			exports["vrp"]:Bucket(src, "Exit")
		end
	end
	ActiveGuests = {}
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- CHESTS (contrato igual ao propertys)
-----------------------------------------------------------------------------------------------------------------------------------------
local function chestKeyFrom(Name, Mode)
	if Mode ~= "Vault" and Mode ~= "Fridge" then return nil end
	return Mode..":"..tostring(Name) -- Name esperado: "Penthouse:<owner>"
end

local function ownerFromName(Name)
	local s = tostring(Name or "")
	local p = s:match("^Penthouse:(%d+)$")
	return tonumber(p or 0) or 0
end

local function canAccessOwnerKey(src, owner)
	local pass = vRP.Passport(src)
	if not pass then return false end
	if pass == owner then return true end
	if ActiveGuests[pass] == owner then return true end
	return false
end

function Creative.Permissions(Name, Mode)
	local src = source
	Name, Mode = normalizeNameMode(Name, Mode)
	local owner = ownerFromName(Name)
	if owner <= 0 then return false end
	return canAccessOwnerKey(src, owner)
end

function Creative.Mount(Name, Mode)
	local src  = source
	local pass = vRP.Passport(src)
	if not pass then return false end

	Name, Mode = normalizeNameMode(Name, Mode)
	local owner = ownerFromName(Name)
	if owner <= 0 then return false end
	if not canAccessOwnerKey(src, owner) then return false end

	local chestKey = chestKeyFrom(Name, Mode)
	if not chestKey then return false end

	local maxWeight = (Mode == "Vault") and (Config.VaultWeight or 1800) or (Config.FridgeWeight or 400)

	local Primary = {}
	local Inv = vRP.Inventory(pass) or {}
	for idx,v in pairs(Inv) do
		if v.amount > 0 and ItemExist(v.item) then
			v.name = ItemName(v.item); v.weight = ItemWeight(v.item); v.index = ItemIndex(v.item)
			Primary[idx] = v
		end
	end

	local Secondary = {}
	local ChestData = vRP.GetSrvData(chestKey, true) or {}
	for idx,v in pairs(ChestData) do
		if v.amount > 0 and ItemExist(v.item) then
			v.name = ItemName(v.item); v.weight = ItemWeight(v.item); v.index = ItemIndex(v.item)
			Secondary[idx] = v
		else
			vRP.RemoveChest(chestKey, idx, true)
		end
	end

	return Primary, Secondary, vRP.CheckWeight(pass), maxWeight
end

function Creative.Store(Item, Slot, Amount, Target, Name, Mode)
	local src  = source
	local pass = vRP.Passport(src)
	Amount = parseInt(Amount, true)
	if not pass then return end

	Name, Mode = normalizeNameMode(Name, Mode)
	local owner = ownerFromName(Name)
	if owner <= 0 or not canAccessOwnerKey(src, owner) then return end

	local chestKey = chestKeyFrom(Name, Mode)
	if not chestKey then return end

	if (Mode == "Vault" and ItemFridge(Item)) or (Mode == "Fridge" and not ItemFridge(Item)) then
		TriggerClientEvent("inventory:Update", src); return
	end

	local cap = (Mode == "Vault") and (Config.VaultWeight or 1800) or (Config.FridgeWeight or 400)
	if vRP.StoreChest(pass, chestKey, Amount, cap, Slot, Target, true) then
		TriggerClientEvent("inventory:Update", src)
	end
end

function Creative.Take(Slot, Amount, Target, Name, Mode)
	local src  = source
	local pass = vRP.Passport(src)
	Amount = parseInt(Amount, true)
	if not pass then return end

	Name, Mode = normalizeNameMode(Name, Mode)
	local owner = ownerFromName(Name)
	if owner <= 0 or not canAccessOwnerKey(src, owner) then return end

	local chestKey = chestKeyFrom(Name, Mode)
	if not chestKey then return end

	if vRP.TakeChest(pass, chestKey, Amount, Slot, Target, true) then
		TriggerClientEvent("inventory:Update", src)
	end
end

function Creative.Update(Slot, Amount, Target, Name, Mode)
	local src  = source
	local pass = vRP.Passport(src)
	Amount = parseInt(Amount, true)
	if not pass then return end

	Name, Mode = normalizeNameMode(Name, Mode)
	local owner = ownerFromName(Name)
	if owner <= 0 or not canAccessOwnerKey(src, owner) then return end

	local chestKey = chestKeyFrom(Name, Mode)
	if not chestKey then return end

	if vRP.UpdateChest(pass, chestKey, Slot, Target, Amount, true) then
		TriggerClientEvent("inventory:Update", src)
	end
end
