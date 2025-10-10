-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")
vRPC = Tunnel.getInterface("vRP")
vRP = Proxy.getInterface("vRP")
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
Creative = {}
Tunnel.bindInterface("inventory", Creative)
vPLAYER = Tunnel.getInterface("player")
vGARAGE = Tunnel.getInterface("garages")
vCLIENT = Tunnel.getInterface("inventory")
vKEYBOARD = Tunnel.getInterface("keyboard") 
vPARAMEDIC = Tunnel.getInterface("paramedic")
vSURVIVAL = Tunnel.getInterface("survival")
vDEVICE = Tunnel.getInterface("device")
vFARMER = Tunnel.getInterface("farmer")
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
Drugs = {}
Drops = {}
Carry = {}
Active = {}
Trashs = {}
Plates = {}
Trunks = {}
Healths = {}
Objects = {}
SaveObjects = {}
RobberyActive = {}

local BootGraceUntil = os.time() + 15 -- 15s de tolerância pós-(re)start
-- guarda o slot do galão quando equipado para renomear o item ao guardar
local PetrolEquippedSlot = {} -- [Passport] = "slotString"
-- cooldown para equipar/guardar arma
local WeaponSwapCooldown = {} -- [Passport] = os.time() + SWAP_SECONDS
local SWAP_SECONDS = 0 -- ajusta aqui (2s)

-----------------------------------------------------------------------------------------------------------------------------------------
-- USERS
-----------------------------------------------------------------------------------------------------------------------------------------
Users = {
	["Ammos"] = {},
	["Attachs"] = {},
	["Skins"] = {},
	["WeaponClips"] = {}, -- << guarda clip por arma: Users["WeaponClips"][Passport][Weapon] = clip
}

local TheftContext = {} -- [victimPassport] = { thief = thiefPassport, thiefSource = source }
-----------------------------------------------------------------------------------------------------------------------------------------
-- BUFFS
-----------------------------------------------------------------------------------------------------------------------------------------
Buffs = {
	["Dexterity"] = {},
	["Luck"] = {},
}

------------------------------
-- LOCKS / VERSÕES PARA AMMO (ANTI-DUPE)
------------------------------
-- cache simples por source -> arma -> munição
local AmmoCache = {} -- [src] = { ["WEAPON_PISTOL"] = 23, ... }
local AttachCache = {} -- se precisares para /gattachs downstream

-- garante tabela
local function ensurePlayerCache(src)
	if not AmmoCache[src] then
		AmmoCache[src] = {}
	end
	if not AttachCache[src] then
		AttachCache[src] = {}
	end
	return AmmoCache[src], AttachCache[src]
end
local ReloadingLock = {} -- [Passport] = os.time() + n  (trava curto pra recarga)
local VerifyLock = {} -- [Passport] = os.time() + n  (trava curto pra verify)
local AmmoVer = AmmoVer or {} -- [Passport] = { [ammoName] = versao }

local function setAmmo(Passport, ammoName, value)
	AmmoVer[Passport] = AmmoVer[Passport] or {}
	local v = (AmmoVer[Passport][ammoName] or 0) + 1
	AmmoVer[Passport][ammoName] = v

	Users["Ammos"][Passport] = Users["Ammos"][Passport] or {}
	Users["Ammos"][Passport][ammoName] = parseInt(value or 0)

	SaveAmmosSoon(Passport)
	return v
end

local function tryUpdateAmmo(Passport, ammoName, value, version)
	AmmoVer[Passport] = AmmoVer[Passport] or {}
	local curV = AmmoVer[Passport][ammoName] or 0
	if (not version) or version >= curV then
		return setAmmo(Passport, ammoName, value)
	end
	return curV
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS (AMMO SAVE/LOOKUP)
-----------------------------------------------------------------------------------------------------------------------------------------
-- fila de saves para não spammar DB
local SaveAmmoQueue = SaveAmmoQueue or {}

local function SaveAmmosNow(Passport)
	if Users["Ammos"][Passport] then
		vRP.Query("playerdata/SetData", {
			Passport = Passport,
			Name = "Ammos",
			Information = json.encode(Users["Ammos"][Passport]),
		})
	end
end

function SaveAmmosSoon(Passport)
	if SaveAmmoQueue[Passport] then
		return
	end
	SaveAmmoQueue[Passport] = true
	SetTimeout(750, function()
		SaveAmmoQueue[Passport] = nil
		SaveAmmosNow(Passport)
	end)
end

-- verifica se o jogador ainda tem alguma arma que usa determinada munição
local function HasAnyWeaponForAmmo(Passport, ammoName)
	if type(ammoName) ~= "string" or ammoName == "" then
		return false
	end
	local inv = vRP.Inventory(Passport) or {}
	for _, data in pairs(inv) do
		local item = data.item
		local qtd = tonumber(data.amount) or 0
		if type(item) == "string" and qtd > 0 and ItemType(item, "Armamento") then
			local wAmmo = WeaponAmmo(item) -- item é string aqui
			if wAmmo and wAmmo == ammoName then
				return true
			end
		end
	end
	return false
end

-----------------------------------------------------------------------------------------------------------------------------------------
--  FORCE SAVE (POR PASSPORT)
-----------------------------------------------------------------------------------------------------------------------------------------
--  SAVE HELPERS (IMEDIATOS) 
local function ForceSavePlayerAmmoByPassport(Passport)
	if not Passport then
		return
	end
	Users["Ammos"] = Users["Ammos"] or {}
	local payload = Users["Ammos"][Passport] or {}
	vRP.Query("playerdata/SetData", {
		Passport = Passport,
		Name = "Ammos",
		Information = json.encode(payload),
	})
end

local function ForceSavePlayerAttachsByPassport(Passport)
	if not Passport then
		return
	end
	Users["Attachs"] = Users["Attachs"] or {}
	local payload = Users["Attachs"][Passport] or {}
	vRP.Query("playerdata/SetData", {
		Passport = Passport,
		Name = "Attachs",
		Information = json.encode(payload),
	})
end

local function ForceSavePlayerSkinsByPassport(Passport)
	if not Passport then
		return
	end
	Users["Skins"] = Users["Skins"] or {}
	local payload = Users["Skins"][Passport] or {}
	vRP.Query("playerdata/SetData", {
		Passport = Passport,
		Name = "Skins",
		Information = json.encode(payload),
	})
end

local function ForceSavePlayerClipsByPassport(Passport)
	if not Passport then
		return
	end
	Users["WeaponClips"] = Users["WeaponClips"] or {}
	local payload = Users["WeaponClips"][Passport] or {}
	vRP.Query("playerdata/SetData", {
		Passport = Passport,
		Name = "WeaponClips",
		Information = json.encode(payload),
	})
end

local SaveAttachsQueue = SaveAttachsQueue or {}
local SaveSkinsQueue = SaveSkinsQueue or {}
local SaveClipsQueue = SaveClipsQueue or {}

-- server-side/core.lua (mesmo local onde já tens as 3 funções)
local function SaveAttachsSoon(Passport)
	Passport = tonumber(Passport)
	if not Passport then
		return
	end -- <== guarda
	if SaveAttachsQueue[Passport] then
		return
	end
	SaveAttachsQueue[Passport] = true
	SetTimeout(750, function()
		SaveAttachsQueue[Passport] = nil
		ForceSavePlayerAttachsByPassport(Passport)
	end)
end

local function SaveSkinsSoon(Passport)
	Passport = tonumber(Passport)
	if not Passport then
		return
	end
	if SaveSkinsQueue[Passport] then
		return
	end
	SaveSkinsQueue[Passport] = true
	SetTimeout(750, function()
		SaveSkinsQueue[Passport] = nil
		ForceSavePlayerSkinsByPassport(Passport)
	end)
end

local function SaveClipsSoon(Passport)
	Passport = tonumber(Passport)
	if not Passport then
		return
	end
	if SaveClipsQueue[Passport] then
		return
	end
	SaveClipsQueue[Passport] = true
	SetTimeout(750, function()
		SaveClipsQueue[Passport] = nil
		ForceSavePlayerClipsByPassport(Passport)
	end)
end

------------------------------
-- DROP WRAPPER COM AUTODETECÇÃO E CACHE
------------------------------

-- cache da assinatura correta descoberta em runtime
local _DropsSig = nil

-- tentativas (todas tratadas com pcall)
local function _try_sig(passport, src, item, amount, sig)
	if sig == 1 then
		return pcall(function()
			exports["inventory"]:Drops(passport, src, item, amount)
		end)
	elseif sig == 2 then
		return pcall(function()
			exports["inventory"]:Drops(src, passport, item, amount)
		end)
	elseif sig == 3 then
		return pcall(function()
			exports["inventory"]:Drops(passport, item, amount)
		end)
	elseif sig == 4 then
		return pcall(function()
			exports["inventory"]:Drops(src, item, amount)
		end)
	elseif sig == 5 then
		return pcall(function()
			exports["inventory"]:Drops(item, amount, passport, src)
		end)
	elseif sig == 6 then
		return pcall(function()
			exports["inventory"]:Drops(item, amount, passport)
		end)
	elseif sig == 7 then
		return pcall(function()
			exports["inventory"]:Drops(item, amount, src)
		end)
	elseif sig == 8 then
		return pcall(function()
			exports["inventory"]:Drops(item, passport, amount)
		end)
	elseif sig == 9 then
		return pcall(function()
			exports["inventory"]:Drops(item, src, amount)
		end)
	elseif sig == 10 then
		return pcall(function()
			exports["inventory"]:Drops(item, amount)
		end)
	end
	return false, "sig inválida"
end

local function SafeDrop(passport, src, item, amount)
	if type(item) ~= "string" then
		return
	end
	item = item:upper()
	amount = tonumber(amount) or 0
	if amount <= 0 then
		return
	end
	if not ItemExist(item) then
		return
	end

	local ok, err

	-- se já descobrimos a assinatura boa, usa direto
	if _DropsSig then
		ok, err = _try_sig(passport, src, item, amount, _DropsSig)
		if not ok then
			-- assinatura quebrou por algum motivo? limpa cache e re-descobre
			_DropsSig = nil
		end
	end

	if not _DropsSig then
		-- ordem de tentativas: primeiro as que costumam passar item POR ÚLTIMO,
		-- depois as que passam item primeiro.
		local order = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
		for _, sig in ipairs(order) do
			ok, err = _try_sig(passport, src, item, amount, sig)
			if ok then
				_DropsSig = sig
				break
			end
		end
	end

	if not ok then
		-- fallback: coloca no inventário do dono do passaporte
		if vRP.InventoryWeight(passport, item, amount) and not vRP.MaxItens(passport, item, amount) then
			vRP.GenerateItem(passport, item, amount, true)
		else
			print(
				("[inventory] SafeDrop: nenhuma assinatura do export 'Drops' funcionou. item=%s amount=%s err=%s"):format(
					item,
					amount,
					tostring(err)
				)
			)
		end
	end
end

------------------------------
-- TRANSFER / DROP AMMO
------------------------------
-- sem usar export Drops (evita crash até alinharmos a assinatura)
local function GiveAmmoOrNotify(passport, source, item, amount, who)
	amount = tonumber(amount) or 0
	if amount <= 0 then
		return
	end
	if type(item) ~= "string" then
		return
	end
	item = item:upper()
	if not ItemExist(item) then
		return
	end

	if not vRP.MaxItens(passport, item, amount) and vRP.InventoryWeight(passport, item, amount) then
		vRP.GenerateItem(passport, item, amount, true)
	else
		local whoTxt = (who == "thief" and "do ladrão") or "da vítima"
		TriggerClientEvent(
			"Notify",
			source,
			"Mochila Sobrecarregada",
			("A munição não coube no inventário %s."):format(whoTxt),
			"amarelo",
			5000
		)
		print(
			("[inventory] WARN: munição %s x%d não coube no passaporte %s (%s)"):format(
				item,
				amount,
				tostring(passport),
				whoTxt
			)
		)
		-- se quiseres mesmo dropar depois, volta aqui quando soubermos a assinatura correta do export.
	end
end

local function TransferOrDropAmmo(victimSource, victimPassport, ammoName, amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then
		return
	end
	if type(ammoName) ~= "string" or ammoName == "" then
		return
	end
	ammoName = ammoName:upper()
	if not ItemExist(ammoName) then
		return
	end

	TheftContext = TheftContext or {}
	local ctx = TheftContext[victimPassport]

	if ctx and ctx.ts and os.time() <= ctx.ts and vRP.Passport(ctx.thiefSource) == ctx.thief then
		-- tenta dar ao ladrão; se não couber, apenas notifica (sem Drop)
		GiveAmmoOrNotify(ctx.thief, ctx.thiefSource, ammoName, amount, "thief")
	else
		-- devolve à vítima; se não couber, apenas notifica (sem Drop)
		GiveAmmoOrNotify(victimPassport, victimSource, ammoName, amount, "victim")
	end
end

function Creative.ReapplyAttachs()
	local src = source
	local Passport = vRP.Passport(src)
	if not Passport then
		return
	end

	local my = Users["Attachs"][Passport] or {}
	local byHash = {} -- [weaponHash] = { compHash, ... }

	for weaponName, tab in pairs(my) do
		if type(weaponName) == "string" and type(tab) == "table" then
			local comps = {}
			for fullItem, _ in pairs(tab) do
				if type(fullItem) == "string" and fullItem ~= "" then
					local base = SplitOne(fullItem) -- seguro porque fullItem é string
					if type(base) == "string" and base ~= "" then
						local comp = WeaponAttach(base, weaponName)
						if comp then
							comps[#comps + 1] = comp
						end
					end
				end
			end
			if #comps > 0 and type(weaponName) == "string" then
				local wHash = GetHashKey(weaponName)
				if wHash and wHash ~= 0 then
					byHash[wHash] = comps
				end
			end
		end
	end

	TriggerClientEvent("inventory:ApplyComponentsBulk", src, { __by = "hash", data = byHash })
end

RegisterServerEvent("inventory:BeginTheft")
AddEventHandler("inventory:BeginTheft", function(victimPassport)
	local thiefSource = source
	local thiefPassport = vRP.Passport(thiefSource)
	if thiefPassport and victimPassport then
		TheftContext[victimPassport] = { thief = thiefPassport, thiefSource = thiefSource, ts = os.time() + 10 }
	end
end)

RegisterServerEvent("inventory:EndTheft")
AddEventHandler("inventory:EndTheft", function(victimPassport)
	if victimPassport then
		TheftContext[victimPassport] = nil
	end
end)

RegisterNetEvent("inventory:ForceStateSavePing")
AddEventHandler("inventory:ForceStateSavePing", function()
	local src = source
	local Passport = vRP.Passport(src)
	if not Passport then
		return
	end
	ForceSavePlayerAmmoByPassport(Passport)
	ForceSavePlayerClipsByPassport(Passport)
	ForceSavePlayerAttachsByPassport(Passport)
	ForceSavePlayerSkinsByPassport(Passport)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- CLIPS POR ARMA (helpers)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CLIPS POR ARMA (helpers)  — VERSÃO À PROVA DE NULOS
local function GetWeaponClip(Passport, Weapon)
	if not Passport or type(Passport) ~= "number" then
		return 0
	end
	if not Weapon or Weapon == "" then
		return 0
	end
	Users["WeaponClips"] = Users["WeaponClips"] or {}
	Users["WeaponClips"][Passport] = Users["WeaponClips"][Passport] or {}
	return parseInt(Users["WeaponClips"][Passport][Weapon] or 0)
end

local function SetWeaponClip(Passport, Weapon, value, saveSoon)
	-- hard guards
	if not Passport or type(Passport) ~= "number" then
		return 0
	end
	if not Weapon or Weapon == "" then
		return 0
	end

	Users["WeaponClips"] = Users["WeaponClips"] or {}
	Users["WeaponClips"][Passport] = Users["WeaponClips"][Passport] or {}

	Users["WeaponClips"][Passport][Weapon] = parseInt(value or 0)

	-- usa fila/queue como no resto do ficheiro (evita spam de DB)
	if saveSoon then
		-- se já tens SaveClipsSoon definido mais abaixo, usa-o:
		if type(SaveClipsSoon) == "function" then
			SaveClipsSoon(Passport)
		else
			-- fallback seguro
			vRP.Query("playerdata/SetData", {
				Passport = Passport,
				Name = "WeaponClips",
				Information = json.encode(Users["WeaponClips"][Passport]),
			})
		end
	end

	return Users["WeaponClips"][Passport][Weapon]
end

-- migração suave: se ainda houver ammos por tipo guardadas, usar como fallback
local function ConsumeLegacyAmmoForWeapon(Passport, Weapon)
	if type(Weapon) ~= "string" or Weapon == "" then
		return 0
	end
	local ammoName = WeaponAmmo(Weapon)
	if not ammoName then
		return 0
	end

	Users["Ammos"][Passport] = Users["Ammos"][Passport] or {}
	local clip = parseInt(Users["Ammos"][Passport][ammoName] or 0)
	if clip > 0 then
		Users["Ammos"][Passport][ammoName] = nil
		SaveAmmosSoon(Passport)
	end
	return clip
end

-- devolve munição do clip como ITENS para um passaporte (ou faz SafeDrop)
local function ConvertClipToItems(passport, source, weapon, clip)
	-- guards fortes: evita chamar WeaponAmmo(nil) e afins
	clip = parseInt(clip or 0)
	if clip <= 0 then
		return 0
	end

	if type(weapon) ~= "string" or weapon == "" then
		-- nada a converter se não sabemos qual arma gerou as balas
		return 0
	end

	-- galão não converte para item de munição
	if weapon == "WEAPON_PETROLCAN" then
		return 0
	end

	local ammoItem = WeaponAmmo(weapon)
	if not ammoItem or not ItemExist(ammoItem) then
		return 0
	end

	if not vRP.MaxItens(passport, ammoItem, clip) and vRP.InventoryWeight(passport, ammoItem, clip) then
		vRP.GenerateItem(passport, ammoItem, clip, true)
	else
		TriggerClientEvent(
			"Notify",
			source,
			"Mochila Sobrecarregada",
			("Sem espaço para %dx %s. Foi deixado no chão."):format(clip, ItemName(ammoItem) or ammoItem),
			"amarelo",
			6000
		)
		SafeDrop(passport, source, ammoItem, clip)
	end

	return clip
end

-- devolve os ATTACHS guardados para a arma como itens (usa a própria key full que foi consumida)
local function ReturnAttachItems(passport, source, weapon)
	Users["Attachs"][passport] = Users["Attachs"][passport] or {}
	local tab = Users["Attachs"][passport][weapon]
	local Passport = vRP.Passport(source)

	-- Se não existir ou não for tabela, retorna 0
	if type(tab) ~= "table" then
		return 0
	end

	local returned = 0
	for fullItem, _ in pairs(tab) do
		if type(fullItem) == "string" and ItemExist(fullItem) then
			if not vRP.MaxItens(passport, fullItem, 1) and vRP.InventoryWeight(passport, fullItem, 1) then
				vRP.GenerateItem(passport, fullItem, 1, true)
			else
				TriggerClientEvent(
					"Notify",
					source,
					"Mochila Sobrecarregada",
					("Sem espaço para 1x %s. Foi deixado no chão."):format(ItemName(fullItem) or fullItem),
					"amarelo",
					6000
				)
				SafeDrop(passport, source, fullItem, 1)
			end
			SaveAttachsSoon(Passport)
			returned = returned + 1
		end
	end

	-- Limpa a lista de attachs dessa arma
	Users["Attachs"][passport][weapon] = nil
	return returned
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- MOUNT
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Mount()
	local source = source
	local Passport = vRP.Passport(source)
	if Passport then
		local Primary = {}
		local Inv = vRP.Inventory(Passport)
		for Index, v in pairs(Inv) do
			if v["amount"] <= 0 or not ItemExist(v["item"]) then
				vRP.RemoveItem(Passport, v["item"], v["amount"], false)
			else
				v["name"] = ItemName(v["item"])
				v["weight"] = ItemWeight(v["item"])
				v["index"] = ItemIndex(v["item"])
				v["amount"] = parseInt(v["amount"])
				v["rarity"] = ItemRarity(v["item"])
				v["economy"] = ItemEconomy(v["item"])
				v["desc"] = ItemDescription(v["item"])
				v["key"] = v["item"]
				v["slot"] = Index

				local Split = splitString(v["item"], "-")

				if not v["desc"] then
					if Split[1] == "vehiclekey" and Split[2] then
						v["desc"] = "Placa do Veículo: <common>" .. Split[2] .. "</common>"
					elseif
						Split[1] == "identity"
						or Split[1] == "fidentity"
						or string.sub(v["item"], 1, 5) == "badge" and Split[2]
					then
						if
							Split[1] == "identity"
							or Split[1] == "fidentity"
							or string.sub(v["item"], 1, 5) == "badge"
						then
							v["desc"] = "Passaporte: <rare>"
								.. Dotted(Split[2])
								.. "</rare><br>Nome: <rare>"
								.. vRP.FullName(Split[2])
								.. "</rare><br>Telefone: <rare>"
								.. vRP.Phone(Passport)
								.. "</rare>"
						else
							v["desc"] = "Propriedade: <common>" .. vRP.FullName(Split[2]) .. "</common>"
						end
					end
				end

				if Split[2] then
					local Loaded = ItemLoads(v["item"])
					if Loaded then
						v["charges"] = parseInt(Split[2] * (100 / Loaded))
					end

					if ItemDurability(v["item"]) then
						v["durability"] = parseInt(os.time() - Split[2])
						v["days"] = ItemDurability(v["item"])
					end
				end

				Primary[Index] = v
			end
		end

		return Primary, vRP.CheckWeight(Passport)
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- SEND
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Send(Slot, Amount)
	local source = source
	local Slot = tostring(Slot)
	local Amount = parseInt(Amount, true)
	local Passport = vRP.Passport(source)
	local ClosestPed = vRPC.ClosestPed(source, 2)
	if Passport and not Active[Passport] and ClosestPed then
		local Inv = vRP.Inventory(Passport)
		if not Inv[Slot] or not Inv[Slot]["item"] then
			return false
		end

		local Item = Inv[Slot]["item"]
		Active[Passport] = os.time() + 100
		local OtherPassport = vRP.Passport(ClosestPed)

		if not vRP.MaxItens(OtherPassport, Item, Amount) then
			if vRP.InventoryWeight(OtherPassport, Item, Amount) then
				Active[Passport] = os.time() + 3
				Player(source)["state"]["Cancel"] = true
				Player(source)["state"]["Buttons"] = true
				Player(ClosestPed)["state"]["Cancel"] = true
				Player(ClosestPed)["state"]["Buttons"] = true
				vRPC.CreateObjects(
					source,
					"mp_safehouselost@",
					"package_dropoff",
					"prop_paper_bag_small",
					16,
					28422,
					0.0,
					-0.05,
					0.05,
					180.0,
					0.0,
					0.0
				)

				repeat
					if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
						vRPC.Destroy(source)
						Active[Passport] = nil
						Player(source)["state"]["Cancel"] = false
						Player(source)["state"]["Buttons"] = false
						Player(ClosestPed)["state"]["Cancel"] = false
						Player(ClosestPed)["state"]["Buttons"] = false

						if
							vRP.TakeItem(Passport, Item, Amount, true, Slot)
							and vRP.GiveItem(OtherPassport, Item, Amount, true)
						then
							TriggerClientEvent("inventory:Update", source)
							TriggerClientEvent("inventory:Update", ClosestPed)
						end
					end

					Wait(100)
				until not Active[Passport]
			else
				TriggerClientEvent("inventory:Notify", source, "Aviso", "Mochila Sobrecarregada.", "amarelo")
			end
		end

		Active[Passport] = nil
	end
end

--------------------------------------------------------------------------------------------------------------------------------------------
----- STATE
--------------------------------------------------------------------------------------------------------------------------------------------
-- local Active = Active or {} -- anti-reentrância por passaporte
-- local function clearSendState(src, tgt)
--     -- Limpa anima/locks em quem iniciou
--     if src then
--         pcall(function() TriggerClientEvent("inventory:ForceCleanAnim", src) end)
--         pcall(function() vRPC.Destroy(src) end)
--         local p = Player(src)
--         if p then
--             p["state"]["Cancel"] = false
--             p["state"]["Buttons"] = false
--         end
--     end
--     -- Limpa locks no alvo
--     if tgt then
--         local p2 = Player(tgt)
--         if p2 then
--             p2["state"]["Cancel"] = false
--             p2["state"]["Buttons"] = false
--         end
--     end
-- end
-----------------------------------------------------------------------------------------------------------------------------------------
-- USE
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Use(Slot, Amount)
	local source = source
	local Slot = tostring(Slot)
	local Amount = parseInt(Amount, true)
	local Passport = vRP.Passport(source)
	if not (Passport and not Active[Passport]) then
		return
	end

	local Inv = vRP.Inventory(Passport)
	if not Inv or not Inv[Slot] or not Inv[Slot]["item"] then
		return
	end

	local Full = Inv[Slot]["item"]
	local Split = splitString(Full)
	local Item = Split[1]

	-- bloqueios de contexto
	local InWater = ItemWater(Item)
	if
		(Player(source)["state"]["Handcuff"] and Item ~= "lockpick")
		or (
			Item ~= "rope"
			and (
				(InWater and InWater == "In" and not vRPC.IsEntityInWater(source))
				or (InWater and InWater == "Swimming" and not vRPC.IsEntityInWater(source))
			)
		)
	then
		return
	end

	-- durabilidade/danificado
	if ItemDurability(Full) and vRP.CheckDamaged(Full) then
		TriggerClientEvent(
			"inventory:Notify",
			source,
			"Atenção",
			"<b>" .. ItemName(Item) .. "</b> danificado.",
			"vermelho"
		)
		return
	end

	---------------------------------------------------------------------
	-- ARMAMENTO (slots 101..103)
	---------------------------------------------------------------------
	if ItemTypeCheck(Full, "Armamento") and (parseInt(Slot) >= 101 and parseInt(Slot) <= 103) then
		-- COOLDOWN anti-spam de equipar/guardar
		local now = os.time()
		if WeaponSwapCooldown[Passport] and now < WeaponSwapCooldown[Passport] then
			local left = WeaponSwapCooldown[Passport] - now
			TriggerClientEvent(
				"Notify",
				source,
				"Informações",
				"Aguarde <b>" .. left .. " segundos</b> antes de trocar de arma.",
				"amarelo",
				5000
			)
			return
		end
		WeaponSwapCooldown[Passport] = now + (SWAP_SECONDS or 0)

		if vRP.InsideVehicle(source) and not ItemVehicle(Full) then
			WeaponSwapCooldown[Passport] = nil
			return
		end

		-- Se já tem arma na mão, guarda
		if vCLIENT.ReturnWeapon(source) then
			local Check, AmmoClip, Weapon = vCLIENT.StoreWeapon(source)
			if Check then
				if type(Weapon) ~= "string" then
					Weapon = tostring(Weapon or "")
				end
				if Weapon ~= "" then
					SetWeaponClip(Passport, Weapon, parseInt(AmmoClip or 0), true)
				end

				-- Galão
				if Weapon == "WEAPON_PETROLCAN" then
					local clip = parseInt(AmmoClip or 0)
					local slot = PetrolEquippedSlot[Passport]

					if
						slot
						and vRP.Inventory(Passport)[slot]
						and vRP.Inventory(Passport)[slot].item
						and vRP.Inventory(Passport)[slot].item:sub(1, 16) == "WEAPON_PETROLCAN"
					then
						if vRP.TakeItem(Passport, "WEAPON_PETROLCAN", 1, true, slot) then
							vRP.GiveItem(Passport, "WEAPON_PETROLCAN-" .. clip, 1, true, slot)
						end
					else
						local inv2 = vRP.Inventory(Passport) or {}
						for s, it in pairs(inv2) do
							if it and it.item and it.item:sub(1, 16) == "WEAPON_PETROLCAN" then
								if vRP.TakeItem(Passport, it.item, 1, true, tostring(s)) then
									vRP.GiveItem(Passport, "WEAPON_PETROLCAN-" .. clip, 1, true, tostring(s))
								end
								break
							end
						end
					end

					PetrolEquippedSlot[Passport] = nil
					TriggerClientEvent("inventory:Update", source)
				end

				-- Notificação só se o item existir (evita “-1 deletado”)
				if ItemExist(Weapon) then
					TriggerClientEvent(
						"NotifyItem",
						source,
						{ "-", ItemIndex(Weapon), 1, ItemName(Weapon), ItemRarity(Weapon) }
					)
				end
			else
				WeaponSwapCooldown[Passport] = nil
			end
			return
		end

		-- Caso contrário, equipa a arma do slot
		local Skin, Attach = nil, {}
		local ammoClip = 0
		if type(Item) == "string" and Item ~= "" then
			ammoClip = GetWeaponClip(Passport, Item) or 0
		end

		if (ammoClip or 0) <= 0 then
			local legacy = ConsumeLegacyAmmoForWeapon(Passport, Item)
			if legacy > 0 then
				ammoClip = legacy
				SetWeaponClip(Passport, Item, legacy, true)
			end
		end

		if Item == "WEAPON_PETROLCAN" then
			local fuelFromItem = Split[2] and parseInt(Split[2]) or nil
			if fuelFromItem ~= nil then
				ammoClip = math.max(0, math.min(4500, fuelFromItem))
				SetWeaponClip(Passport, Item, ammoClip, true)
				SaveClipsSoon(Passport)

				if vRP.TakeItem(Passport, Full, 1, true, Slot) then
					vRP.GiveItem(Passport, Item, 1, true, Slot)
				end
			end
			PetrolEquippedSlot[Passport] = Slot
		end

		if Users["Skins"][Passport] and Users["Skins"][Passport][Item] then
			Skin = Users["Skins"][Passport][Item]
			ForceSavePlayerSkinsByPassport(Passport)
		end
		if Users["Attachs"][Passport] and Users["Attachs"][Passport][Item] then
			Attach = Users["Attachs"][Passport][Item]
			SaveAttachsSoon(Passport)
		end

		if vCLIENT.TakeWeapon(source, Item, ammoClip, Attach, false, Skin) then
			if ItemExist(Full) then
				TriggerClientEvent("NotifyItem", source, { "+", ItemIndex(Full), 1, ItemName(Full), ItemRarity(Full) })
			end
		else
			WeaponSwapCooldown[Passport] = nil
		end
		return
	end

	---------------------------------------------------------------------
	-- MUNIÇÃO
	---------------------------------------------------------------------
	if ItemTypeCheck(Full, "Munição") then
		if ReloadingLock[Passport] and os.time() < ReloadingLock[Passport] then
			return
		end

		local Weapon, ClipNow = vCLIENT.InfoWeapon(source, Item)
		-- ⚠️ GUARDA: só chama WeaponAmmo se Weapon for string válida
		local ammoName = (type(Weapon) == "string" and Weapon ~= "" and WeaponAmmo(Weapon)) or nil

		if type(Weapon) == "string" and Weapon ~= "" and ammoName and Item == ammoName then
			local cap = (Weapon == "WEAPON_PETROLCAN") and 4500 or 250
			local give = Amount

			local curClip = GetWeaponClip(Passport, Weapon) or 0
			if (curClip + give) > cap then
				give = cap - curClip
			end
			if give <= 0 then
				return
			end

			if vRP.TakeItem(Passport, Full, give, false, Slot) then
				
				ReloadingLock[Passport] = os.time() + 2
				TriggerClientEvent(
					"NotifyItem",
					source,
					{ "+", ItemIndex(Full), give, ItemName(Full), ItemRarity(Full) }
				)
				TriggerClientEvent("inventory:Update", source)
				TriggerClientEvent("inventory:Reloading", source, 1500)

				-- Calcular o novo clip corretamente (sem duplicar a munição)
				local NewClip = math.min(cap, curClip + give)
				SetWeaponClip(Passport, Weapon, NewClip, true)
				
				-- Adicionar munição ao jogador
				vCLIENT.Reloading(source, Weapon, give)

				ReloadingLock[Passport] = nil
			end
		end
		return
	end

	---------------------------------------------------------------------
	-- ARREMESSO
	---------------------------------------------------------------------
	if ItemTypeCheck(Full, "Arremesso") then
		if vCLIENT.ReturnWeapon(source) then
			local Check, AmmoClip, Weapon = vCLIENT.StoreWeapon(source)
			if Check then
				-- Arremessáveis não usam munição
				if not ItemTypeCheck(Weapon, "Arremesso") then
					local ammoName = (type(Weapon) == "string" and Weapon ~= "" and WeaponAmmo(Weapon)) or nil
					if ammoName then
						Users["Ammos"][Passport] = Users["Ammos"][Passport] or {}
						if (AmmoClip or 0) > 0 then
							Users["Ammos"][Passport][ammoName] = AmmoClip
						else
							Users["Ammos"][Passport][ammoName] = nil
						end
						SaveAmmosSoon(Passport)
					end
				end

				if ItemExist(Weapon) then
					TriggerClientEvent("NotifyItem", source, {
					"-", ItemIndex(Weapon), 1, ItemName(Weapon), ItemRarity(Weapon)
					})
				end
			end
		else
			if vCLIENT.TakeWeapon(source, Item, 1, nil, Full) then
				if ItemExist(Full) then
					TriggerClientEvent("NotifyItem", source, {
					"+", ItemIndex(Full), 1, ItemName(Full), ItemRarity(Full)
					})
				end
			end
		end
		return
	end

	---------------------------------------------------------------------
	-- ATTACHS
	---------------------------------------------------------------------
	if ItemTypeCheck(Full, "Attachs") then
		local Weapon = vCLIENT.ReturnWeapon(source)
		if type(Weapon) ~= "string" or Weapon == "" then
			return
		end

		local Component = WeaponAttach(Item, Weapon)
		if not Component then
			TriggerClientEvent(
				"inventory:Notify",
				source,
				"Atenção",
				"O armamento não possui suporte ao componente.",
				"vermelho"
			)
			return
		end

		Users["Attachs"][Passport] = Users["Attachs"][Passport] or {}
		Users["Attachs"][Passport][Weapon] = Users["Attachs"][Passport][Weapon] or {}

		-- ⚠️ Guardar: só usar SplitOne em strings válidas
		for Name, _ in pairs(Users["Attachs"][Passport][Weapon]) do
			if type(Name) == "string" and Name ~= "" then
				local base = SplitOne(Name)
				if type(base) == "string" and base == Item then
					TriggerClientEvent(
						"inventory:Notify",
						source,
						"Atenção",
						"O armamento já possui um componente equipado.",
						"vermelho"
					)
					return
				end
			end
		end

		if vRP.TakeItem(Passport, Full, 1, false, Slot) then
			TriggerClientEvent("NotifyItem", source, { "+", ItemIndex(Full), 1, ItemName(Full), ItemRarity(Full) })
			-- garante chave string
			Users["Attachs"][Passport][Weapon][tostring(Full)] = true
			SaveAttachsSoon(Passport)
			TriggerClientEvent("inventory:Update", source)
			vCLIENT.GiveComponent(source, Component)
		end
		return
	end

	---------------------------------------------------------------------
	-- CONSUMÍVEIS
	---------------------------------------------------------------------
	if Use[Item] and ItemTypeCheck(Full, "Consumível") then
		Use[Item](source, Passport, Amount, Slot, Full, Item, Split)
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- CANCEL
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("inventory:Cancel")
AddEventHandler("inventory:Cancel", function()
	local source = source
	local Passport = vRP.Passport(source)
	if Passport then
		if Active[Passport] then
			Active[Passport] = nil
			vGARAGE.UpdateHotwired(source)
			TriggerClientEvent("Progress", source, "Cancelando", 1000)
		end

		if Player(source)["state"]["Buttons"] then
			Player(source)["state"]["Buttons"] = false
		end

		if Carry[Passport] then
			if vRP.Passport(Carry[Passport]) then
				TriggerClientEvent("inventory:Carry", Carry[Passport], nil, "Detach")
				vRPC.Destroy(Carry[Passport])

				if Player(Carry[Passport])["state"]["Carry"] then
					Player(Carry[Passport])["state"]["Carry"] = false
				end
			end

			if Player(source)["state"]["Carry"] then
				Player(source)["state"]["Carry"] = false
			end

			Carry[Passport] = nil
		end

		if Player(source)["state"]["Camera"] then
			TriggerClientEvent("inventory:Camera", source)
		end

		if RobberyActive[Passport] then
			TriggerEvent("inventory:RobberySingleActive", RobberyActive[Passport])
			RobberyActive[Passport] = nil
		end

		vRPC.Destroy(source)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- VERIFYWEAPON
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.VerifyWeapon(Item, Ammo, lenient)
	local source = source
	local Passport = vRP.Passport(source)
	if not Passport or type(Item) ~= "string" or Item == "" then
		return false
	end

	if VerifyLock[Passport] and os.time() < VerifyLock[Passport] then
		return false
	end
	VerifyLock[Passport] = os.time() + 2

	local cap = (Item == "WEAPON_PETROLCAN") and 4500 or 250
	local clipFromClient = math.max(0, math.min(parseInt(Ammo or 0), cap))

	local hasWeaponItem = vRP.ConsultItem(Passport, Item)

	if not hasWeaponItem then
		-- janela de arranque OU chamada leniente? não mexe em attachs
		if (lenient == true) or (os.time() <= BootGraceUntil) then
			if clipFromClient > 0 then
				SetWeaponClip(Passport, Item, clipFromClient)
				SaveClipsSoon(Passport)
			end
			VerifyLock[Passport] = nil
			return true
		end

		-- guarda leitura do cliente (sem erro)
		if clipFromClient > 0 then
			SetWeaponClip(Passport, Item, clipFromClient)
		end

		local carried = GetWeaponClip(Passport, Item)

		if Item == "WEAPON_PETROLCAN" then
			if carried > 0 then
				SetWeaponClip(Passport, Item, 0, true)
				SaveClipsSoon(Passport)
			end
		else
			if carried > 0 then
				ConvertClipToItems(Passport, source, Item, carried)
				SetWeaponClip(Passport, Item, 0, true)
				SaveClipsSoon(Passport)
			end
		end

		ReturnAttachItems(Passport, source, Item)
		SaveAttachsSoon(Passport)

		TriggerClientEvent("inventory:RemoveWeapon", source, Item)
		TriggerClientEvent("inventory:Update", source)

		VerifyLock[Passport] = nil
		return false
	end

	-- tem a arma: salva redução sempre; aumento só em recarga
	local cur = GetWeaponClip(Passport, Item) or 0
	if ReloadingLock[Passport] then
		SetWeaponClip(Passport, Item, clipFromClient)
		SaveClipsSoon(Passport)
	else
		if clipFromClient <= cur then
			SetWeaponClip(Passport, Item, clipFromClient)
			SaveClipsSoon(Passport)
		end
	end

	VerifyLock[Passport] = nil
	return true
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- CHECKEXISTWEAPONS
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.CheckExistWeapons(Item)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and Item ~= "" and Item and not vRP.ConsultItem(Passport, Item) then
		return true
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- REMOVETHROWING
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.RemoveThrowing(Item)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and Item ~= "" and Item ~= nil then
		vRP.TakeItem(Passport, Item)
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PREVENTWEAPONS
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.PreventWeapons(Weapon, Clip, Final)
	local src = source
	local Passport = vRP.Passport(src)
	if not Passport or not Weapon or Weapon == "" then
		return true
	end

	Users["WeaponClips"] = Users["WeaponClips"] or {}
	Users["WeaponClips"][Passport] = Users["WeaponClips"][Passport] or {}

	local cap = (Weapon == "WEAPON_PETROLCAN") and 4500 or 250
	local newClip = tonumber(Clip) or 0
	if newClip < 0 then
		newClip = 0
	end
	if newClip > cap then
		newClip = cap
	end

	local cur = tonumber(Users["WeaponClips"][Passport][Weapon] or 0) or 0
	local reloading = (ReloadingLock and ReloadingLock[Passport] and os.time() < ReloadingLock[Passport]) and true
		or false

	-- Final=true (arma a sair) → persistir mesmo que desça
	if Final == true then
		Users["WeaponClips"][Passport][Weapon] = newClip
		-- Persist soon
		if SaveClipsSoon then
			SaveClipsSoon(Passport)
		end
		return true
	end

	-- SUBIDAS aceitamos SEMPRE (seed/reload)
	if newClip > cur then
		Users["WeaponClips"][Passport][Weapon] = newClip
		if SaveClipsSoon then
			SaveClipsSoon(Passport)
		end
		return true
	end

	-- Durante recarregamento, sincronizamos mesmo se igual/diminuir (tolerância)
	if reloading and newClip ~= cur then
		Users["WeaponClips"][Passport][Weapon] = newClip
		if SaveClipsSoon then
			SaveClipsSoon(Passport)
		end
		return true
	end

	-- Fora disso, ignoramos reduções em runtime (deixa para DRAIN/VerifyWeapon).
	return true
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- STATE / TABELAS
-----------------------------------------------------------------------------------------------------------------------------------------
local Active = Active or {}
local Trashs = Trashs or {}
-- Espera-se que existam:
--  - TrashItens: tabela de loot com campos { Item, Valuation, Addition }
--  - RandPercentage(tbl): retorna um dos itens da lista
--  - CompleteTimers(segundos): formata tempo
--  - vRP, vRPC exports party/inventory/pause definidos na tua base

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS
-----------------------------------------------------------------------------------------------------------------------------------------
local function safeDropGeneric(Passport, src, item, amount)
	if exports["inventory"] and exports["inventory"].Drops then
		exports["inventory"]:Drops(Passport, src, item, amount)
	elseif SafeDrop then
		SafeDrop(Passport, src, item, amount)
	else
		-- fallback simples caso nenhum dos dois exista
		vRP.GenerateItem(Passport, item, amount, true)
		TriggerClientEvent(
			"Notify",
			src,
			"Atenção",
			"Sistema de drop de chão indisponível, item entregue diretamente.",
			"amarelo",
			5000
		)
	end
end

local function canLootThisSpot(Coords)
	local Number = #Trashs + 1
	for i = 1, #Trashs do
		if #(Trashs[i]["Coords"] - Coords) <= 0.5 then
			if Trashs[i]["Timer"] and os.time() <= Trashs[i]["Timer"] then
				return false, i, (Trashs[i]["Timer"] - os.time())
			else
				return true, i, 0
			end
		end
	end
	return true, Number, 0
end

local function finishLoot(Passport, src, Number, ValuationItem)
	if Trashs[Number] and Trashs[Number]["Passport"] == Passport then
		local GainExperience = 1
		local Result = RandPercentage(TrashItens)
		local Valuation = Result["Valuation"] + Result["Valuation"] * (Result["Addition"] or 0)

		-- Buffs
		if exports["inventory"] and exports["inventory"].Buffs and exports["inventory"]:Buffs("Luck", Passport) then
			Valuation = Valuation + (Valuation * 0.10)
		end

		-- Premium
		if vRP.UserPremium(Passport) then
			local Hierarchy = vRP.LevelPremium(src)
			local Bonification = (Hierarchy == 1 and 0.100)
				or (Hierarchy == 2 and 0.075)
				or (Hierarchy >= 3 and 0.050)
				or 0
			Valuation = Valuation + (Valuation * Bonification)
			GainExperience = GainExperience + 10
		end

		-- Party (até 2 membros além do próprio)
		if exports["party"] and exports["party"].DoesExist and exports["party"]:DoesExist(Passport, 2) then
			local Consult = exports["party"]:Room(Passport, src, 10)
			local AmountMembers = (#Consult > 2 and 2 or #Consult)
			for n = 1, AmountMembers do
				local memberSrc = Consult[n] and Consult[n]["Source"]
				local memberPass = Consult[n] and Consult[n]["Passport"]
				if memberSrc and vRP.Passport(memberSrc) and vRPC.LastVehicle(memberSrc, "trash") then
					if
						not vRP.MaxItens(memberPass, Result["Item"], Valuation)
						and vRP.InventoryWeight(memberPass, Result["Item"], Valuation)
					then
						vRP.GenerateItem(memberPass, Result["Item"], Valuation, true)
					else
						TriggerClientEvent(
							"Notify",
							memberSrc,
							"Mochila Sobrecarregada",
							"A recompensa caiu no chão.",
							"roxo",
							5000
						)
						safeDropGeneric(memberPass, memberSrc, Result["Item"], Valuation)
					end
					vRP.PutExperience(memberPass, "Garbageman", GainExperience)
					if exports["pause"] and exports["pause"].AddPoints then
						exports["pause"]:AddPoints(memberPass, GainExperience)
					end
					vRP.UpgradeStress(memberPass, 1)
				end
			end
		else
			-- Solo
			if
				not vRP.MaxItens(Passport, Result["Item"], Valuation)
				and vRP.InventoryWeight(Passport, Result["Item"], Valuation)
			then
				vRP.GenerateItem(Passport, Result["Item"], Valuation, true)
			else
				TriggerClientEvent("Notify", src, "Mochila Sobrecarregada", "A recompensa caiu no chão.", "roxo", 5000)
				safeDropGeneric(Passport, src, Result["Item"], Valuation)
			end
			vRP.PutExperience(Passport, "Garbageman", GainExperience)
			if exports["pause"] and exports["pause"].AddPoints then
				exports["pause"]:AddPoints(Passport, GainExperience)
			end
		end
	end
end

local function startLoot(Entity, requireTrashVehicle)
	local src = source
	local Coords = Entity and Entity[4]
	local Passport = vRP.Passport(src)
	if not (Passport and Coords) then
		return false
	end

	-- Sem veículo (ou com, se flag estiver true)
	if requireTrashVehicle then
		if not vRPC.LastVehicle(src, "trash") then
			TriggerClientEvent(
				"Notify",
				src,
				"Atenção",
				"Necessário utilizar o veículo <b>Trash</b>.",
				"amarelo",
				5000
			)
			return false
		end
	end

	local ok, Number, waitLeft = canLootThisSpot(Coords)
	if not ok then
		TriggerClientEvent("Notify", src, "Atenção", "Aguarde " .. CompleteTimers(waitLeft) .. ".", "amarelo", 5000)
		return false
	end

	-- Marca cooldown do ponto (30 minutos)
	Trashs[Number] = { ["Coords"] = Coords, ["Timer"] = os.time() + 180, ["Passport"] = Passport }

	-- Proteção por 10s de progresso
	Active[Passport] = os.time() + 10
	Player(src)["state"]["Buttons"] = true
	TriggerClientEvent("Progress", src, "Vasculhando", 10000)
	vRPC.playAnim(src, false, { "amb@prop_human_bum_bin@base", "base" }, true)

	repeat
		if Active[Passport] and os.time() >= Active[Passport] then
			vRPC.Destroy(src)
			Active[Passport] = nil
			Player(src)["state"]["Buttons"] = false
			finishLoot(Passport, src, Number)
		end
		Wait(100)
	until not Active[Passport]

	return true
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- EVENTOS (AMBOS NOMES SUPORTADOS)
-----------------------------------------------------------------------------------------------------------------------------------------
-- Versão “livre” (sem exigir veículo). Mantém o nome que o teu target usa.
RegisterServerEvent("inventory:TrasherOpen")
AddEventHandler("inventory:TrasherOpen", function(Entity)
	startLoot(Entity, false) -- FALSE = não precisa do veículo "trash"
end)

-- Compatibilidade com o nome antigo (se algum recurso ainda disparar esse)
RegisterServerEvent("inventory:Trasher")
AddEventHandler("inventory:Trasher", function(Entity)
	startLoot(Entity, false) -- também sem veículo, conforme pediste
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- LOOT
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("inventory:Loot")
AddEventHandler("inventory:Loot", function(Number, Box)
	local Consult = nil
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and Loots[Box] then
		if not Loots[Box]["Players"][Number] then
			Loots[Box]["Players"][Number] = {}
		end

		if Loots[Box]["Item"] then
			Consult = vRP.ConsultItem(Passport, Loots[Box]["Item"])
			if not Consult then
				TriggerClientEvent(
					"Notify",
					source,
					"Atenção",
					"Precisa de <b>1x " .. ItemName(Loots[Box]["Item"]) .. "</b>.",
					"amarelo",
					5000
				)
				return false
			end
		end

		if Loots[Box]["Players"][Number][Passport] then
			if os.time() <= Loots[Box]["Players"][Number][Passport] then
				TriggerClientEvent(
					"Notify",
					source,
					"Atenção",
					"Aguarde " .. CompleteTimers(Loots[Box]["Players"][Number][Passport] - os.time()) .. ".",
					"amarelo",
					5000
				)
				return false
			end
		end

		if Loots[Box]["Code"] then
			local Keyboard = vKEYBOARD.Password(source, "Senha")
			if not Keyboard or (Keyboard[1] and Keyboard[1] ~= Loots[Box]["Code"]) then
				TriggerClientEvent("Notify", source, "Acesso Restrito", "Senha incorreta.", "vermelho", 5000)
				return false
			end
		end

		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("Progress", source, "Vasculhando", 10000)
		Loots[Box]["Players"][Number][Passport] = os.time() + Loots[Box]["Cooldown"]
		vRPC.playAnim(
			source,
			false,
			{ "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", "machinic_loop_mechandplayer" },
			true
		)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				vRPC.Destroy(source)
				Active[Passport] = nil
				Player(source)["state"]["Buttons"] = false

				if not Loots[Box]["Item"] or (Loots[Box]["Item"] and Consult) then
					local Result = RandPercentage(Loots[Box]["List"])
					if
						not vRP.MaxItens(Passport, Result["Item"], Result["Valuation"])
						and vRP.InventoryWeight(Passport, Result["Item"], Result["Valuation"])
					then
						vRP.GenerateItem(Passport, Result["Item"], Result["Valuation"], true)

						if Loots[Box]["Permission"] and vRP.HasService(Passport, Loots[Box]["Permission"]) then
							vRP.GenerateItem(Passport, "dollar", 275, true)
						end
					else
						TriggerClientEvent(
							"Notify",
							source,
							"Mochila Sobrecarregada",
							"Sua recompensa caiu no chão.",
							"roxo",
							5000
						)
						SafeDrop(Passport, source, Result["Item"], Result["Valuation"])

						if Loots[Box]["Permission"] and vRP.HasService(Passport, Loots[Box]["Permission"]) then
							SafeDrop(Passport, source, "dollar", 275)
						end
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- GARAGES:DELETE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("garages:Delete")
AddEventHandler("garages:Delete", function(Network, Plate)
	if Plates[Plate] then
		Plates[Plate] = nil
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:CHANGEPLATE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("inventory:ChangePlate")
AddEventHandler("inventory:ChangePlate", function(Entitys)
	local source = source
	local Plate = Entitys[1]
	local Passport = vRP.Passport(source)
	if Passport and not Active[Passport] and not Plates[Plate] then
		if not vRP.ConsultItem(Passport, "plate") then
			TriggerClientEvent(
				"Notify",
				source,
				"Atenção",
				"Precisa de <b>1x " .. ItemName("plate") .. "</b>.",
				"amarelo",
				5000
			)

			return false
		end

		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("Progress", source, "Trocando", 10000)
		vRPC.playAnim(
			source,
			false,
			{ "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", "machinic_loop_mechandplayer" },
			true
		)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				vRPC.Destroy(source)
				Active[Passport] = nil
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport, "plate", 1, true) then
					local Networked = NetworkGetEntityFromNetworkId(Entitys[4])
					if DoesEntityExist(Networked) and not IsPedAPlayer(Networked) and GetEntityType(Networked) == 2 then
						local NewPlate = vRP.GeneratePlate()
						SetVehicleNumberPlateText(Networked, NewPlate)
						Plates[NewPlate] = true

						TriggerEvent("garages:ChangePlate", Plate, NewPlate)

						if not vRP.PassportPlate(NewPlate) then
							Entity(Networked)["state"]:set("Lockpick", Passport, true)
						else
							Entity(Networked)["state"]:set("Lockpick", true, true)
						end
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- MAKEPRODUCTS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("inventory:Products")
AddEventHandler("inventory:Products", function(Service)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and not Active[Passport] and Products[Service] then
		if Products[Service]["PolyZone"] and not vFARMER.PolyZone(source, Service) then
			exports["discord"]:Embed(
				"Hackers",
				"**[PASSAPORTE]:** "
					.. Passport
					.. "\n**[FUNÇÃO]:** Farmer do "
					.. Service
					.. "\n**[DATA & HORA]:** "
					.. os.date("%d/%m/%Y")
					.. " às "
					.. os.date("%H:%M"),
				source
			)
		end

		if Products[Service]["Item"] and not vRP.ConsultItem(Passport, Products[Service]["Item"]) then
			TriggerClientEvent(
				"Notify",
				source,
				"Atenção",
				"Precisa de <b>1x " .. ItemName(Products[Service]["Item"]) .. "</b>.",
				"amarelo",
				5000
			)

			return false
		end

		if Products[Service]["Police"] and not vRP.Task(source, 5, 5000) then
			exports["vrp"]:CallPolice({
				["Source"] = source,
				["Passport"] = Passport,
				["Permission"] = "Policia",
				["Name"] = "Roubo de Pertences",
				["Wanted"] = 60,
				["Code"] = 31,
				["Color"] = 22,
			})
		end

		Player(source)["state"]["Buttons"] = true
		Active[Passport] = os.time() + Products[Service]["Timer"]
		TriggerClientEvent("Progress", source, "Produzindo", Products[Service]["Timer"] * 1000)

		if Products[Service]["Animation"] then
			vRPC.playAnim(
				source,
				false,
				{ Products[Service]["Animation"]["Dict"], Products[Service]["Animation"]["Anim"] },
				true
			)
		end

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Player(source)["state"]["Buttons"] = false
				Active[Passport] = nil
				vRPC.Destroy(source)

				if
					not Products[Service]["Item"]
					or (Products[Service]["Item"] and vRP.TakeItem(Passport, Products[Service]["Item"]))
				then
					local Result = RandPercentage(Products[Service]["Itens"])
					if
						not vRP.MaxItens(Passport, Result["Item"], Result["Valuation"])
						and vRP.InventoryWeight(Passport, Result["Item"], Result["Valuation"])
					then
						vRP.GenerateItem(Passport, Result["Item"], Result["Valuation"], true)
					else
						TriggerClientEvent(
							"Notify",
							source,
							"Mochila Sobrecarregada",
							"Sua recompensa caiu no chão.",
							"roxo",
							5000
						)
						SafeDrop(Passport, source, Result["Item"], Result["Valuation"])
					end

					if Products[Service]["Residual"] then
						TriggerClientEvent("player:Residual", source, Products[Service]["Residual"])
					end
				end
			end

			Wait(100)
		until not Active[Passport]
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- ITEMDATA:SAVE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("itemdata:Save")
AddEventHandler("itemdata:Save", function(Item, Text)
	vRP.SetSrvData(Item, Text, true)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYER:ROLLVEHICLE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("player:RollVehicle")
AddEventHandler("player:RollVehicle", function(Entity)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and not Active[Passport] then
		vRPC.AnimActive(source)
		Active[Passport] = os.time() + 15
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("Progress", source, "Desvirando", 15000)
		vRPC.playAnim(source, false, { "mini@repair", "fixing_a_player" }, true)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				vRPC.Destroy(source)
				Active[Passport] = nil
				Player(source)["state"]["Buttons"] = false

				local Players = vRPC.Players(source)
				for _, v in pairs(Players) do
					async(function()
						TriggerClientEvent("target:RollVehicle", v, Entity[4])
					end)
				end
			end

			Wait(100)
		until not Active[Passport]
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:BUFFSERVER
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("inventory:BuffServer", function(source, Passport, Name, Amount)
	if not Buffs[Name][Passport] then
		Buffs[Name][Passport] = 0
	end

	if os.time() >= Buffs[Name][Passport] then
		Buffs[Name][Passport] = os.time() + Amount
	else
		Buffs[Name][Passport] = Buffs[Name][Passport] + Amount

		if (Buffs[Name][Passport] - os.time()) >= 3600 then
			Buffs[Name][Passport] = os.time() + 3600
		end
	end

	TriggerClientEvent("hud:" .. Name, source, Buffs[Name][Passport] - os.time())
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- BUFFS
-----------------------------------------------------------------------------------------------------------------------------------------
exports("Buffs", function(Mode, Passport)
	return Buffs[Mode]
			and Buffs[Mode][Passport]
			and Buffs[Mode][Passport] > os.time()
			and (Mode ~= "Luck" or (Mode == "Luck" and math.random(100) >= 50))
			and true
		or false
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CLEANWEAPONS
-----------------------------------------------------------------------------------------------------------------------------------------
exports("CleanWeapons", function(Passport)
	local removed = 0

	if Users and Users["Weapons"] and Users["Weapons"][Passport] then
		for weapon, _ in pairs(Users["Weapons"][Passport]) do
			Users["Weapons"][Passport][weapon] = nil
			removed = removed + 1
		end
	end

	if vRP and vRP.Inventory then
		local inv = vRP.Inventory(Passport) or {}
		for item, data in pairs(inv) do
			if type(item) == "string" and item:sub(1, 7) == "wbody|" then
				local amount = (data.amount or data.quantity or data.qtd or 0)
				if amount > 0 then
					if vRP.TryGetItem(Passport, item, amount, true) then
						removed = removed + amount
					end
				end
			end
		end
	end

	if Users then
		Users["Attachs"] = Users["Attachs"] or {}
		Users["Ammos"] = Users["Ammos"] or {}
		Users["Attachs"][Passport] = {}
		Users["Ammos"][Passport] = {}
	end

	return removed
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- STEALPEDS
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.StealPeds()
	local source = source
	local Passport = vRP.Passport(source)
	if Passport then
		local Result = RandPercentage(IlegalItens)
		if
			not vRP.MaxItens(Passport, Result["Item"], Result["Valuation"])
			and vRP.InventoryWeight(Passport, Result["Item"], Result["Valuation"])
		then
			vRP.GenerateItem(Passport, Result["Item"], Result["Valuation"], true)
		else
			TriggerClientEvent(
				"Notify",
				source,
				"Mochila Sobrecarregada",
				"Sua recompensa caiu no chão.",
				"roxo",
				5000
			)
			SafeDrop(Passport, source, Result["Item"], Result["Valuation"])
		end

		if math.random(100) >= 75 and vRP.DoesEntityExist(source) then
			exports["vrp"]:CallPolice({
				["Source"] = source,
				["Passport"] = Passport,
				["Permission"] = "Policia",
				["Name"] = "Assalto a mão armada",
				["Wanted"] = 60,
				["Code"] = 32,
				["Color"] = 16,
			})
		end
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- SHOTSFIRED
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.ShotsFired(Vehicle)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport then
		if Vehicle then
			Vehicle = "Disparos de um veículo"
		else
			Vehicle = "Disparos com arma de fogo"
		end

		exports["vrp"]:CallPolice({
			["Source"] = source,
			["Passport"] = Passport,
			["Permission"] = "Policia",
			["Name"] = Vehicle,
			["Code"] = 10,
			["Color"] = 6,
		})
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:DRINK
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("inventory:Drink")
AddEventHandler("inventory:Drink", function()
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and not Active[Passport] then
		Active[Passport] = os.time() + 10
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("Progress", source, "Bebendo", 10000)
		vRPC.CreateObjects(
			source,
			"amb@world_human_drinking@coffee@male@idle_a",
			"idle_c",
			"prop_plastic_cup_02",
			49,
			28422
		)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				Active[Passport] = nil
				vRPC.Destroy(source, "one")
				vRP.UpgradeThirst(Passport, 10)
				Player(source)["state"]["Buttons"] = false
			end

			Wait(100)
		until not Active[Passport]
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:REFILLGALLON
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("inventory:RefillGallon")
AddEventHandler("inventory:RefillGallon", function()
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and not Active[Passport] and vRP.ConsultItem(Passport, "emptypurifiedwater") then
		Active[Passport] = os.time() + 30
		Player(source)["state"]["Buttons"] = true
		TriggerClientEvent("Progress", source, "Enchendo", 30000)
		vRPC.playAnim(source, false, { "amb@prop_human_parking_meter@female@idle_a", "idle_a_female" }, true)

		repeat
			if Active[Passport] and os.time() >= parseInt(Active[Passport]) then
				vRPC.Destroy(source)
				Active[Passport] = nil
				Player(source)["state"]["Buttons"] = false

				if vRP.TakeItem(Passport, "emptypurifiedwater") then
					vRP.GenerateItem(Passport, "purifiedwater", 1)
				end
			end

			Wait(100)
		until not Active[Passport]
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- SAVESERVER
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("SaveServer", function(Silenced)
	local List = vRP.Players()
	for Passport, _ in pairs(List) do
		if Users["Ammos"] and Users["Ammos"][Passport] then
			vRP.Query(
				"playerdata/SetData",
				{ Passport = Passport, Name = "Ammos", Information = json.encode(Users["Ammos"][Passport]) }
			)
		end
		if Users["WeaponClips"] and Users["WeaponClips"][Passport] then
			vRP.Query(
				"playerdata/SetData",
				{ Passport = Passport, Name = "WeaponClips", Information = json.encode(Users["WeaponClips"][Passport]) }
			)
		end
		if Users["Attachs"] and Users["Attachs"][Passport] then
			vRP.Query(
				"playerdata/SetData",
				{ Passport = Passport, Name = "Attachs", Information = json.encode(Users["Attachs"][Passport]) }
			)
		end
		if Users["Skins"] and Users["Skins"][Passport] then
			vRP.Query(
				"playerdata/SetData",
				{ Passport = Passport, Name = "Skins", Information = json.encode(Users["Skins"][Passport]) }
			)
		end
	end

	vRP.Query("entitydata/SetData", { Name = "SaveObjects", Information = json.encode(SaveObjects) })

	if not Silenced then
		print("O resource ^2Inventory^7 salvou os dados.")
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Disconnect", function(Passport)
	if Users["Ammos"] and Users["Ammos"][Passport] then
		vRP.Query(
			"playerdata/SetData",
			{ Passport = Passport, Name = "Ammos", Information = json.encode(Users["Ammos"][Passport]) }
		)
		Users["Ammos"][Passport] = nil
	end
	if Users["WeaponClips"] and Users["WeaponClips"][Passport] then
		vRP.Query(
			"playerdata/SetData",
			{ Passport = Passport, Name = "WeaponClips", Information = json.encode(Users["WeaponClips"][Passport]) }
		)
		Users["WeaponClips"][Passport] = nil
	end
	if Users["Attachs"] and Users["Attachs"][Passport] then
		vRP.Query(
			"playerdata/SetData",
			{ Passport = Passport, Name = "Attachs", Information = json.encode(Users["Attachs"][Passport]) }
		)
		Users["Attachs"][Passport] = nil
	end
	if Users["Skins"] and Users["Skins"][Passport] then
		vRP.Query(
			"playerdata/SetData",
			{ Passport = Passport, Name = "Skins", Information = json.encode(Users["Skins"][Passport]) }
		)
		Users["Skins"][Passport] = nil
	end

	if Active[Passport] then
		Active[Passport] = nil
	end
	if Drugs[Passport] then
		Drugs[Passport] = nil
	end

	if Carry[Passport] then
		if vRP.Passport(Carry[Passport]) then
			TriggerClientEvent("inventory:Carry", Carry[Passport], nil, "Detach")
			vRPC.Destroy(Carry[Passport])
			if Player(Carry[Passport])["state"]["Carry"] then
				Player(Carry[Passport])["state"]["Carry"] = false
			end
		end
		Carry[Passport] = nil
	end

	if RobberyActive[Passport] then
		TriggerEvent("inventory:RobberySingleActive", RobberyActive[Passport])
		RobberyActive[Passport] = nil
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- START
-----------------------------------------------------------------------------------------------------------------------------------------

AddEventHandler("onResourceStart", function(res)
	if res ~= GetCurrentResourceName() then
		return
	end

	Users["Ammos"] = Users["Ammos"] or {}
	Users["Skins"] = Users["Skins"] or {}
	Users["Attachs"] = Users["Attachs"] or {}
	Users["WeaponClips"] = Users["WeaponClips"] or {}

	local list = vRP.Players() or {}
	for Passport, src in pairs(list) do
		Users["Ammos"][Passport] = vRP.UserData(Passport, "Ammos") or {}
		Users["Skins"][Passport] = vRP.UserData(Passport, "Skins") or {}
		Users["Attachs"][Passport] = vRP.UserData(Passport, "Attachs") or {}
		Users["WeaponClips"][Passport] = vRP.UserData(Passport, "WeaponClips") or {}
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Connect", function(Passport, source)
	Users["Ammos"][Passport] = vRP.UserData(Passport, "Ammos") or {}
	Users["Skins"][Passport] = vRP.UserData(Passport, "Skins") or {}
	Users["Attachs"][Passport] = vRP.UserData(Passport, "Attachs") or {}
	Users["WeaponClips"][Passport] = vRP.UserData(Passport, "WeaponClips") or {}

	SetTimeout(1500, function()
		local src = source
		if src then
			Creative.ReapplyAttachs() -- usa a função já existente que emite ApplyComponentsBulk
		end
	end)

	TriggerClientEvent("objects:Table", source, Objects)
	TriggerClientEvent("inventory:Drops", source, Drops)
	TriggerClientEvent("inventory:Skins", source, Users["Skins"][Passport])

	for Name, _ in pairs(Buffs) do
		if Buffs[Name] and Buffs[Name][Passport] and os.time() < Buffs[Name][Passport] then
			TriggerClientEvent("hud:" .. Name, source, Buffs[Name][Passport] - os.time())
		end
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYERDROPPED -> GUARDA BALAS
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("playerDropped", function()
	local src = source
	local Passport = vRP.Passport(src)
	if not Passport then
		return
	end
	ForceSavePlayerAmmoByPassport(Passport)
	ForceSavePlayerClipsByPassport(Passport)
	ForceSavePlayerAttachsByPassport(Passport)
	ForceSavePlayerSkinsByPassport(Passport)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- ONRESOURCESTOP -> GUARDA BALAS DE TODOS ONLINE
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("onResourceStop", function(resName)
	if resName ~= GetCurrentResourceName() then
		return
	end

	local tried = {}

	-- via vRP (preferencial)
	if vRP and vRP.Players then
		local list = vRP.Players() or {}
		for Passport, _ in pairs(list) do
			if type(Passport) == "number" then
				ForceSavePlayerAmmoByPassport(Passport)
				ForceSavePlayerClipsByPassport(Passport)
				ForceSavePlayerAttachsByPassport(Passport)
				ForceSavePlayerSkinsByPassport(Passport) -- opcional
				tried[Passport] = true
			end
		end
	end

	-- fallback: GetPlayers
	for _, sid in ipairs(GetPlayers()) do
		local src = tonumber(sid)
		local Passport = vRP.Passport(src)
		if Passport and not tried[Passport] then
			ForceSavePlayerAmmoByPassport(Passport)
			ForceSavePlayerClipsByPassport(Passport)
			ForceSavePlayerAttachsByPassport(Passport)
			ForceSavePlayerSkinsByPassport(Passport)
			tried[Passport] = true
		end
	end
end)

--  EXPORTS (clips por arma) — manter em linha com as novas guards 
exports("SetWeaponClip", function(Passport, Weapon, Amount)
	return SetWeaponClip(Passport, Weapon, Amount, true)
end)

exports("GetWeaponClip", function(Passport, Weapon)
	return GetWeaponClip(Passport, Weapon)
end)

-- === PERSISTÊNCIA DE MUNIÇÃO ENTRE RESTARTS ===
-- Guarda o último snapshot de munição por passaporte em UserData
RegisterNetEvent("inventory:SnapshotAmmo")
AddEventHandler("inventory:SnapshotAmmo", function(snap, tag)
	local src = source
	local Passport = vRP.Passport(src)
	if not Passport or type(snap) ~= "table" then
		return
	end

	-- normaliza valores para inteiros >=0
	local clean = {}
	for weapon, ammo in pairs(snap) do
		if type(weapon) == "string" then
			local n = math.max(0, tonumber(ammo) or 0)
			clean[weapon] = n
		end
	end

	-- guarda em UserData (json) para sobreviver a restart do resource
	vRP.SetUserData(Passport, "Inventory:WeaponClips", clean)
	-- opcional: debug
	-- print(("[INV/SNAPSHOT %s] %s entries from %d"):format(tag or "-", tostring(next(clean) and "ok" or "empty"), Passport))
end)

-- Cliente pede o snapshot guardado após restart para reaplicar
RegisterNetEvent("inventory:RequestSnapshot")
AddEventHandler("inventory:RequestSnapshot", function()
	local src = source
	local Passport = vRP.Passport(src)
	if not Passport then
		return
	end

	local saved = vRP.UserData(Passport, "Inventory:WeaponClips") or {}
	-- devolve ao client para aplicar
	TriggerClientEvent("inventory:ApplySnapshot", src, saved)

	-- opcional: manter salvo para próximos restarts (não limpar)
	-- se preferir limpar após aplicar, descomenta:
	-- vRP.SetUserData(Passport, "Inventory:WeaponClips", {})
end)
