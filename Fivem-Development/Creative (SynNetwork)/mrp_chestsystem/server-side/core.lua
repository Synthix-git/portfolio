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
Tunnel.bindInterface("chest", Creative)
vKEYBOARD = Tunnel.getInterface("keyboard")

-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Open = {}
local Cooldown = {}

-- Capacidades Penthouse
local PENTHOUSE_VAULT_WEIGHT = 1800
local PENTHOUSE_FRIDGE_WEIGHT = 400

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS
-----------------------------------------------------------------------------------------------------------------------------------------
local function getEntry(tbl, slot)
	if not tbl then
		return nil
	end
	return tbl[slot] or tbl[tostring(slot)] or (tonumber(slot) and tbl[tonumber(slot)] or nil)
end

local function shallowCopy(t)
	local r = {}
	for k, v in pairs(t or {}) do
		r[k] = v
	end
	return r
end

local function formatItemList(list)
	-- list = { ["1"]={item,amount}, ... } -> "3x Diamond, 2x dollar"
	local parts = {}
	for _, v in pairs(list or {}) do
		if v and v.item and parseInt(v.amount) > 0 then
			parts[#parts + 1] = (tostring(parseInt(v.amount)) .. "x " .. (ItemName(v.item) or v.item))
		end
	end
	if #parts == 0 then
		return "—"
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- vRP.MountContainer (gera loot e grava no SrvData) -> devolve a tabela gerada
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.MountContainer(Passport, Name, DropList, Multiplier, save)
	if not Name or not DropList then
		return {}
	end
	local persistent = (save ~= false)

	local Data, slot = {}, 1
	local function add(item, amount)
		amount = parseInt(amount)
		if not item or amount <= 0 then
			return
		end
		Data[tostring(slot)] = { item = item, amount = amount }
		slot = slot + 1
	end

	Multiplier = parseInt(Multiplier or 1)
	if Multiplier < 1 then
		Multiplier = 1
	end

	for _, d in ipairs(DropList) do
		local item = d.Item or d["Item"]
		local chance = d.Chance or d["Chance"] or 100
		local min = d.Min or d["Min"] or 1
		local max = d.Max or d["Max"] or min
		if item and math.random(100) <= chance then
			add(item, math.random(min, max) * Multiplier)
		end
	end

	vRP.SetSrvData(Name, Data, persistent)
	return Data
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- CHESTITENS
-----------------------------------------------------------------------------------------------------------------------------------------
local ChestItens = {
	["foodbag"] = { ["Slots"] = 25, ["Weight"] = 25, ["Block"] = true },
	["storage25"] = { ["Slots"] = 25, ["Weight"] = 25, ["Block"] = true },
	["storage50"] = { ["Slots"] = 25, ["Weight"] = 50, ["Block"] = true },
	["storage75"] = { ["Slots"] = 25, ["Weight"] = 75, ["Block"] = true },
	["suitcase"] = {
		["Slots"] = 25,
		["Weight"] = 10,
		["Close"] = true,
		["Itens"] = { ["dollar"] = true, ["dirtydollar"] = true, ["wetdollar"] = true },
	},
	["pouch"] = {
		["Slots"] = 25,
		["Weight"] = 10,
		["Close"] = true,
		["Itens"] = { ["dollar"] = true, ["dirtydollar"] = true, ["wetdollar"] = true },
	},
	["ammobox"] = {
		["Slots"] = 25,
		["Weight"] = 50,
		["Close"] = true,
		["Itens"] = {
			["WEAPON_PISTOL_AMMO"] = true,
			["WEAPON_SMG_AMMO"] = true,
			["WEAPON_RIFLE_AMMO"] = true,
			["WEAPON_SHOTGUN_AMMO"] = true,
			["WEAPON_MUSKET_AMMO"] = true,
		},
	},
	["weaponbox"] = {
		["Slots"] = 50,
		["Weight"] = 250,
		["Close"] = true,
		["Itens"] = {
			["WEAPON_STUNGUN"] = true,
			["WEAPON_PISTOL"] = true,
			["WEAPON_PISTOL_MK2"] = true,
			["WEAPON_COMPACTRIFLE"] = true,
			["WEAPON_APPISTOL"] = true,
			["WEAPON_HEAVYPISTOL"] = true,
			["WEAPON_MACHINEPISTOL"] = true,
			["WEAPON_MICROSMG"] = true,
			["WEAPON_RPG"] = true,
			["WEAPON_MINISMG"] = true,
			["WEAPON_SNSPISTOL"] = true,
			["WEAPON_SNSPISTOL_MK2"] = true,
			["WEAPON_VINTAGEPISTOL"] = true,
			["WEAPON_PISTOL50"] = true,
			["WEAPON_COMBATPISTOL"] = true,
			["WEAPON_CARBINERIFLE"] = true,
			["WEAPON_CARBINERIFLE_MK2"] = true,
			["WEAPON_ADVANCEDRIFLE"] = true,
			["WEAPON_BULLPUPRIFLE"] = true,
			["WEAPON_BULLPUPRIFLE_MK2"] = true,
			["WEAPON_SPECIALCARBINE"] = true,
			["WEAPON_SPECIALCARBINE_MK2"] = true,
			["WEAPON_PUMPSHOTGUN"] = true,
			["WEAPON_PUMPSHOTGUN_MK2"] = true,
			["WEAPON_MUSKET"] = true,
			["WEAPON_SAWNOFFSHOTGUN"] = true,
			["WEAPON_SMG"] = true,
			["WEAPON_SMG_MK2"] = true,
			["WEAPON_TACTICALRIFLE"] = true,
			["WEAPON_HEAVYRIFLE"] = true,
			["WEAPON_ASSAULTRIFLE"] = true,
			["WEAPON_ASSAULTRIFLE_MK2"] = true,
			["WEAPON_ASSAULTSMG"] = true,
			["WEAPON_GUSENBERG"] = true,
		},
	},
	["medicbag"] = {
		["Slots"] = 25,
		["Weight"] = 100,
		["Close"] = true,
		["Itens"] = {
			["bandage"] = true,
			["gauze"] = true,
			["gdtkit"] = true,
			["medkit"] = true,
			["sinkalmy"] = true,
			["analgesic"] = true,
			["ritmoneury"] = true,
			["adrenaline"] = true,
		},
	},
	["treasurebox"] = { ["Slots"] = 25, ["Weight"] = 50, ["Close"] = true },
	["christmas_04"] = { ["Slots"] = 25, ["Weight"] = 50, ["Close"] = true },
}

-----------------------------------------------------------------------------------------------------------------------------------------
-- TREASUREBOX: PRESETS
-----------------------------------------------------------------------------------------------------------------------------------------
local TREASURE_PRESETS = {
    ["basic"] = {
        { Item = "dollar", Min = 50000, Max = 75000, Chance = 100 },
        { Item = "gemstone", Min = 1, Max = 5, Chance = 25 },
    },
    ["rare"] = {
        { Item = "dollar", Min = 1000000, Max = 1500000, Chance = 100 },
        { Item = "gemstone", Min = 2, Max = 7, Chance = 40 },
    },
    ["epic"] = {
        { Item = "dollar", Min = 1500000, Max = 2500000, Chance = 100 },
        { Item = "gemstone", Min = 3, Max = 8, Chance = 45 },
    },
    ["legendary"] = {
        { Item = "dollar", Min = 2500000, Max = 3500000, Chance = 100 },
        { Item = "gemstone", Min = 4, Max = 10, Chance = 50 },
    },
    ["mythic"] = {
        { Item = "dollar", Min = 3500000, Max = 5000000, Chance = 100 },
        { Item = "gemstone", Min = 5, Max = 12, Chance = 60 },
    },
}

-----------------------------------------------------------------------------------------------------------------------------------------
-- TREASUREBOX: SPAWN (baú preso ao passaporte) + LOG
-- Uso: /treasurebox <passaporte> [mult=1..10]
-- Ex.: /treasurebox 1 2
-----------------------------------------------------------------------------------------------------------------------------------------
local TREASURE_WEIGHTS = {
    basic = 1.0,
    rare = 0.8,
    epic = 0.6,
    legendary = 0.35,
    mythic = 0.2
}

local function pickRandomPreset()
    local names, weights, total = {}, {}, 0
    for name, preset in pairs(TREASURE_PRESETS) do
        local w = TREASURE_WEIGHTS[name] or 1.0
        if type(preset) == "table" and w > 0 then
            names[#names+1] = name
            weights[#weights+1] = w
            total = total + w
        end
    end
    if #names == 0 then return "basic" end

    local r, acc = math.random() * total, 0
    for i=1,#names do
        acc = acc + weights[i]
        if r <= acc then
            return names[i]
        end
    end
    return names[#names]
end

RegisterCommand("treasurebox", function(source, args)
    local src = source
    local staffPassport = vRP.Passport(src)

    -- Permissão: Admin (ou consola)
    if src ~= 0 then
        if not staffPassport or not vRP.HasGroup(staffPassport, "Admin", 2) then
            TriggerClientEvent("Notify", src, "Sistema", "Sem permissão.", "vermelho", 5000)
            return
        end
    end

    local targetPass = parseInt(args[1] or 0)
    if targetPass <= 0 then
        local msg = "Uso: /treasurebox <passaporte> [mult]"
        if src == 0 then print("^1"..msg.."^0") else TriggerClientEvent("Notify", src, "Sistema", msg, "amarelo", 8000) end
        return
    end

    local mult = parseInt(args[2] or 1)
    if mult < 1 then mult = 1 end
    if mult > 10 then mult = 10 end

    -- sorteia preset
    local presetName = pickRandomPreset()
    local preset = TREASURE_PRESETS[presetName] or TREASURE_PRESETS["basic"] or {}

    -- *** CHAVE PRESA AO PASSAPORTE ***
    local chestKey = "treasurebox:"..tostring(targetPass)

    -- Monta conteúdo e persiste
    local generated = vRP.MountContainer(targetPass, chestKey, preset, mult, true)

    -- Dá o ITEM BASE "treasurebox" (sem sufixo!):
    -- O teu uso faz fallback para treasurebox:<Passport>, que bate com chestKey acima.
    local ok = vRP.GenerateItem(targetPass, "treasurebox", 1)
    if not ok then
        -- limpa SrvData para não deixar "baú fantasma"
        vRP.SetSrvData(chestKey, {}, true)

        local msg = ("Falha ao gerar item <b>treasurebox</b> para o passaporte <b>%d</b>. Verifica peso/lotação do inventário."):format(targetPass)
        if src == 0 then
            print("^1[ERRO]^0 "..msg)
        else
            TriggerClientEvent("Notify", src, "Tesouro", msg, "vermelho", 8000)
        end
        return
    end

    -- Logs & feedback
    local fn, ln = vRP.FullName(targetPass); fn = fn or "Indefinido"; ln = ln or ""
    local parts = {}
    for _,v in pairs(generated or {}) do
        if v and v.item and parseInt(v.amount) > 0 then
            parts[#parts+1] = (tostring(parseInt(v.amount)).."x "..(ItemName(v.item) or v.item))
        end
    end
    table.sort(parts)
    local lootLine = (#parts > 0) and table.concat(parts, ", ") or "—"

    if exports["discord"] and exports["discord"].Embed then
        exports["discord"]:Embed("Baus",
            "**🎁 TREASUREBOX GERADA**\n\n"..
            "📦 **Baú:** "..chestKey..
            "\n👤 **Passaporte:** "..targetPass..
            "\n🧾 **Nome:** "..fn.." "..ln..
            "\n🎲 **Preset:** "..presetName.."  ×"..mult..
            "\n🎒 **Conteúdo:** "..lootLine..
            "\n🕒 **Data & Hora:** "..os.date("%d/%m/%Y").." às "..os.date("%H:%M")
        )
    end

    if src == 0 then
        print(("[OK] Treasurebox %s criada (preset=%s x%d). Conteúdo: %s"):format(chestKey, presetName, mult, lootLine))
    else
        TriggerClientEvent("Notify", src, "Tesouro", ("Treasure (preset <b>%s</b>) criada para <b>%d</b> (x<b>%d</b>)."):format(presetName, targetPass, mult), "verde", 6000)
    end
    local tSrc = vRP.Source(targetPass)
    if tSrc then
        TriggerClientEvent("Notify", tSrc, "Tesouro", "Recebeste uma <b>Treasure Box</b>!", "azul", 6000)
    end
end)


-----------------------------------------------------------------------------------------------------------------------------------------
-- PERMISSIONS
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Permissions(Name, Mode, Item)
	local src = source

	-- lock simples: evita abrir o mesmo por duas pessoas
	for _, data in pairs(Open) do
		if data and (data.Name == Name or data.Name == ("Chest:" .. Name) or data.Name == ("Trash:" .. Name)) then
			TriggerClientEvent(
				"Notify",
				src,
				"Sistema",
				"Este compartimento já está a ser usado por outra pessoa.",
				"amarelo",
				5000
			)
			return false
		end
	end

	local Passport = vRP.Passport(src)
	if not Passport then
		return false
	end

	-- Penthouse Vault
	if Mode == "PenthouseVault" or (type(Name) == "string" and Name:sub(1, 15) == "Vault:Penthouse:") then
		Open[Passport] = {
			Name = Name,
			NameLogs = "Chest:" .. Name,
			Weight = PENTHOUSE_VAULT_WEIGHT,
			Slots = 50,
			Save = true,
		}
		return true
	end

	-- Penthouse Fridge
	if Mode == "PenthouseFridge" or (type(Name) == "string" and Name:sub(1, 16) == "Fridge:Penthouse:") then
		Open[Passport] = {
			Name = Name,
			NameLogs = "Chest:" .. Name,
			Weight = PENTHOUSE_FRIDGE_WEIGHT,
			Slots = 50,
			Save = true,
		}
		return true
	end

	-- Personal
	if Mode == "Personal" then
		local perm = SplitOne(Name)
		if vRP.HasPermission(Passport, perm) then
			Open[Passport] = {
				Name = "Personal:" .. Passport,
				NameLogs = "Chest:Personal:" .. Passport,
				Weight = 250,
				Save = true,
				Slots = 40,
			}
			return true
		end
		return false

	-- Tray
	elseif Mode == "Tray" then
		Open[Passport] = {
			Name = Name,
			NameLogs = "Chest:" .. Name,
			Weight = 25,
			Slots = 25,
		}
		if Name == "Recycle" then
			Open[Passport].Weight = 100
			Open[Passport].Recycle = true
		end
		return true

	-- Trash (persistente simples)
	elseif Mode == "Trash" then
		Open[Passport] = {
			Name = "Trash:" .. Name,
			NameLogs = "Chest:Trash:" .. Name,
			Weight = 50,
			Slots = 25,
			Save = true,
		}
		return true

	-- Custom => NORMAL + snapshot/diff (logs ao fechar)
	elseif Mode == "Custom" then
		local current = vRP.GetSrvData(Name, true) or {}
		Open[Passport] = {
			Name = Name, -- ex.: "Helicrash:4"
			NameLogs = "Chest:" .. Name, -- nome para logs
			Weight = 50,
			Slots = 25,
			Save = true,
			Mode = "Custom",
			Snapshot = current, -- snapshot inicial
		}
		return true

	-- Item
	elseif Mode == "Item" then
		local uniq = SplitOne(Name, ":")
		if ChestItens[uniq] then
			-- BLOQUEIO: treasurebox vazia não abre (limpa item “zumbi”)
			if uniq == "treasurebox" then
				local data = vRP.GetSrvData(Name, true) or {}
				local hasAny = false
				for _, v in pairs(data) do
					if v and v.item and (parseInt(v.amount) > 0) then
						hasAny = true
						break
					end
				end
				if not hasAny then
					-- tentar retirar o item vazio do inventário do jogador
					if Item then
						vRP.TakeItem(Passport, Item)
					end
					TriggerClientEvent("Notify", src, "Tesouro", "Esta Treasure Box já foi usada.", "amarelo", 5000)
					return false
				end
			end

			Open[Passport] = {
				Name = Name,
				NameLogs = "Chest:" .. Name,
				Save = true,
				Unique = uniq,
				Slots = ChestItens[uniq].Slots,
				Weight = ChestItens[uniq].Weight,
				Item = Item,
			}
			return true
		end
		return false

	-- DB (grupos/nome registado)
	else
		local c = vRP.Query("chests/GetChests", { name = Name })
		if not c[1] then
			vRP.Query("chests/AddChests", { name = Name })
			c = vRP.Query("chests/GetChests", { name = Name })
		end

		if c[1] and vRP.HasGroup(Passport, c[1].perm) then
			Open[Passport] = {
				Slots = c[1].Slots,
				Weight = c[1].weight,
				NameLogs = Name, -- usado no log
				Name = "Chest:" .. Name, -- chave real (DB)
				Logs = c[1].logs,
				Permission = c[1].perm,
				Save = true,
			}
			return true
		end

		return false
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- MOUNT
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Mount()
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and Open[Passport] then
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

				local Split = splitString(v["item"])

				local Item = Split[1]
				if ChestItens[Item] and ChestItens[Item]["Close"] then
					v["block"] = true
				end

				if not v["desc"] then
					if Item == "vehiclekey" and Split[3] then
						v["desc"] = "Placa do Veículo: <common>" .. Split[3] .. "</common>"
					elseif ItemNamed(Item) and Split[2] then
						v["desc"] = "Propriedade: <common>" .. vRP.FullName(Split[2]) .. "</common>"
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

		local Secondary = {}
		local Result = vRP.GetSrvData(Open[Passport]["Name"], Open[Passport]["Save"]) or {}
		for Index, v in pairs(Result) do
			if v["amount"] <= 0 or not ItemExist(v["item"]) then
				vRP.RemoveChest(Open[Passport]["Name"], Index, Open[Passport]["Save"])
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

				local Split = splitString(v["item"])

				if not v["desc"] then
					if Split[1] == "vehiclekey" and Split[3] then
						v["desc"] = "Placa do Veículo: <common>" .. Split[3] .. "</common>"
					elseif ItemNamed(Split[1]) and Split[2] then
						if Split[1] == "identity" then
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

				Secondary[Index] = v
			end
		end

		-- Sem snapshot/diff para os normais; logs são em Store/Take
		return Primary, Secondary, vRP.CheckWeight(Passport), Open[Passport]["Weight"], Open[Passport]["Slots"]
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- STORE (logs usam NameLogs)
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Store(Item, Slot, Amount, Target, Inactived)
	local source = source
	local Amount = parseInt(Amount, true)
	local Passport = vRP.Passport(source)
	if not Passport or not Open[Passport] or Inactived then
		return TriggerClientEvent("inventory:Update", source)
	end

	-- Reciclagem
	if Open[Passport]["Recycle"] then
		local Recycled = ItemRecycle(Item)
		if Recycled then
			if vRP.TakeItem(Passport, Item, Amount) then
				TriggerClientEvent("inventory:Close", source)
				TriggerClientEvent("Notify", source, "Reciclagem", "A reciclar o item, aguarde...", "amarelo", 5000)
				TriggerClientEvent("chest:RecycleProgress", source)

				SetTimeout(5000, function()
					local Rewards = {}
					for Index, Number in pairs(Recycled) do
						vRP.GenerateItem(Passport, Index, Number * Amount)
						table.insert(Rewards, Number * Amount .. "x " .. ItemName(Index))
					end

					local FirstName, LastName = vRP.FullName(Passport)
					FirstName = FirstName or "Indefinido"
					LastName = LastName or ""
					local RewardList = table.concat(Rewards, ", ")

					exports["discord"]:Embed(
						"Reciclagem",
						"♻️ **[PASSAPORTE]:** "
							.. Passport
							.. "\n👤 **[NOME]:** "
							.. FirstName
							.. " "
							.. LastName
							.. "\n📦 **[RECICLOU]:** "
							.. Amount
							.. "x "
							.. (ItemName(Item) or Item)
							.. "\n🎁 **[RECEBEU]:** "
							.. RewardList
							.. "\n🕒 **[DATA & HORA]:** "
							.. os.date("%d/%m/%Y")
							.. " às "
							.. os.date("%H:%M")
					)
				end)
			end
		else
			TriggerClientEvent(
				"inventory:Notify",
				source,
				"Atenção",
				(ItemName(Item) or Item) .. " não pode ser reciclado.",
				"amarelo"
			)
			TriggerClientEvent("inventory:Update", source)
		end
		return
	end

	-- Diagrama (upgrade de peso)
	if Item == "diagram" and Open[Passport]["NameLogs"] then
		if vRP.TakeItem(Passport, Item, Amount) then
			vRP.Query("chests/UpdateWeight", { Name = Open[Passport]["NameLogs"], Multiplier = Amount })
			TriggerClientEvent("inventory:Notify", source, "Sucesso", "Armazenamento melhorado.", "verde")
			Open[Passport]["Weight"] = Open[Passport]["Weight"] + (10 * Amount)
			TriggerClientEvent("inventory:Update", source)
		end
		return
	end

	-- Regras por item/único
	local ItemKeyOriginal = Item
	local ItemBase = SplitOne(Item)
	local Unique = Open[Passport]["Unique"]
	if
		(ChestItens[ItemBase] and ChestItens[ItemBase]["Block"])
		or (Unique and ChestItens[Unique] and ChestItens[Unique]["Itens"] and not ChestItens[Unique]["Itens"][ItemBase])
	then
		if Unique and ItemBase == Unique then
			TriggerClientEvent("inventory:Open", source, { Type = "Inventory", Resource = "inventory" }, true)
		else
			TriggerClientEvent("inventory:Update", source)
		end
		return
	end

	-- Store
	local failed = vRP.StoreChest(
		Passport,
		Open[Passport]["Name"],
		Amount,
		Open[Passport]["Weight"],
		Slot,
		Target,
		Open[Passport]["Save"],
		ChestItens[Unique]
	)

	TriggerClientEvent("inventory:Update", source)

	if not failed then
		local FirstName, LastName = vRP.FullName(Passport)
		FirstName = FirstName or "Indefinido"
		LastName = LastName or ""

		local ChestLogName = Open[Passport]["NameLogs"] or Open[Passport]["Name"]
		exports["discord"]:Embed(
			"Baus",
			"**🟩 ITEM GUARDADO NO BAÚ**\n\n"
				.. "📦 **Passaporte:** "
				.. Passport
				.. "\n👤 **Nome:** "
				.. FirstName
				.. " "
				.. LastName
				.. "\n🏷️ **Baú:** "
				.. ChestLogName
				.. "\n📥 **Guardou:** "
				.. Amount
				.. "x "
				.. (ItemName(ItemKeyOriginal) or ItemKeyOriginal)
				.. "\n🕒 **Data & Hora:** "
				.. os.date("%d/%m/%Y")
				.. " às "
				.. os.date("%H:%M")
		)
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- TAKE (robusto: resolve slots string/number e loga 1:1 o que foi retirado)
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Take(Item, Slot, Amount, Target)
	local src = source
	local Passport = vRP.Passport(src)
	local Amount = parseInt(Amount, true)

	if not Passport or not Open[Passport] then
		return TriggerClientEvent("inventory:Update", src)
	end

	local chestKey = Open[Passport].Name
	local persistent = Open[Passport].Save

	-- Estado ANTES
	local beforeSrv = vRP.GetSrvData(chestKey, persistent) or {}
	local bSlot = getEntry(beforeSrv, Slot)
	local bItemKey = (bSlot and bSlot.item) or Item
	local bAmt = parseInt((bSlot and bSlot.amount) or 0)

	-- Nome p/ log
	local ItemNameLog = (bItemKey and ItemName(bItemKey))
		or bItemKey
		or (Item and ItemName(Item))
		or Item
		or "Desconhecido"

	-- Tenta retirar
	local ret = vRP.TakeChest(Passport, chestKey, Amount, Slot, Target, persistent)

	-- Estado DEPOIS
	local afterSrv = vRP.GetSrvData(chestKey, persistent) or {}
	local aSlot = getEntry(afterSrv, Slot)
	local aAmt = parseInt((aSlot and aSlot.amount) or 0)

	local taken = 0
	if ret then
		taken = math.min(Amount, bAmt)
		if taken <= 0 and bAmt > aAmt then
			taken = bAmt - aAmt
		end
	else
		if bAmt > 0 then
			taken = math.max(0, bAmt - aAmt)
			if not aSlot and Amount >= bAmt then
				taken = bAmt
			end
		end
	end

	-- Atualiza UI
	TriggerClientEvent("inventory:Update", src)

	-- Loga apenas se houve retirada real
	if taken > 0 then
		local FirstName, LastName = vRP.FullName(Passport)
		FirstName = FirstName or "Indefinido"
		LastName = LastName or ""

		local ChestLogName = Open[Passport].NameLogs or chestKey
		exports["discord"]:Embed(
			"Baus",
			"**🟥 ITEM RETIRADO DO BAÚ**\n\n"
				.. "📦 **Passaporte:** "
				.. Passport
				.. "\n👤 **Nome:** "
				.. FirstName
				.. " "
				.. LastName
				.. "\n🏷️ **Baú:** "
				.. ChestLogName
				.. "\n📤 **Retirou:** "
				.. taken
				.. "x "
				.. ItemNameLog
				.. "\n🕒 **Data & Hora:** "
				.. os.date("%d/%m/%Y")
				.. " às "
				.. os.date("%H:%M")
		)
	end

	-- Chest de item único: se ficou vazio, remove o item e apaga o baú (SrvData)
	if Open[Passport].Item and (not next(afterSrv)) then
		if vRP.TakeItem(Passport, Open[Passport].Item) then
			-- Se for uma treasurebox:<uid>, apaga o SrvData para desaparecer de vez
			local chestName = Open[Passport].Name or ""
			if type(chestName) == "string" and chestName:sub(1, 12) == "treasurebox:" then
				vRP.SetSrvData(chestName, {}, true)
			end
			TriggerClientEvent("inventory:Open", src, { Type = "Inventory", Resource = "inventory" }, true)
		end
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATE
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Update(Slot, Target, Amount)
	local source = source
	local Amount = parseInt(Amount, true)
	local Passport = vRP.Passport(source)
	if
		Passport
		and Open[Passport]
		and vRP.UpdateChest(Passport, Open[Passport]["Name"], Slot, Target, Amount, Open[Passport]["Save"])
	then
		TriggerClientEvent("inventory:Update", source)
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- COOLDOWN
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("chest:Cooldown", function(Name)
	Cooldown[Name] = os.time() + 600
end)

AddEventHandler("chest:CooldownCustom", function(Name, seconds)
	local secs = parseInt(seconds or 600)
	if secs < 0 then
		secs = 0
	end
	Cooldown[Name] = os.time() + secs
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- ARMOUR (utilitário policial)
-----------------------------------------------------------------------------------------------------------------------------------------
local armourCooldown = {}
local Pending = {}
local function newToken(src)
	return ("%s-%d-%d"):format(tostring(src), math.random(100000, 999999), os.time())
end

RegisterServerEvent("chest:Armour")
AddEventHandler("chest:Armour", function()
	local source = source
	local Passport = vRP.Passport(source)
	if not Passport then
		return
	end

	if armourCooldown[Passport] and os.time() <= armourCooldown[Passport] then
		TriggerClientEvent(
			"Notify",
			source,
			"Sistema",
			"Aguarde alguns segundos antes de usar novamente.",
			"amarelo",
			5000
		)
		return
	end

	if not vRP.HasGroup(Passport, "Policia") then
		TriggerClientEvent(
			"Notify",
			source,
			"Sistema",
			"Apenas membros da policia podem usar esta função.",
			"vermelho",
			5000
		)
		armourCooldown[Passport] = os.time() + 3
		return
	end

	local token = newToken(source)
	Pending[token] = { src = source, passport = Passport }
	TriggerClientEvent("admin:requestArmour", source, token)

	SetTimeout(5000, function()
		if Pending[token] then
			Pending[token] = nil
			TriggerClientEvent("Notify", source, "Sistema", "Sem resposta do cliente.", "amarelo", 4000)
		end
	end)

	armourCooldown[Passport] = os.time() + 30
end)

RegisterNetEvent("admin:requestArmour:response")
AddEventHandler("admin:requestArmour:response", function(token, armour)
	local req = Pending[token]
	if not req then
		return
	end
	Pending[token] = nil

	local src = req.src
	armour = tonumber(armour) or 0

	if armour <= 0 then
		TriggerClientEvent("Notify", src, "Sistema", "Não tens colete equipado para restaurar!", "amarelo", 5000)
		return
	end

	if armour >= 100 then
		TriggerClientEvent("Notify", src, "Sistema", "O colete está a 100%, não precisas de restaurar!", "azul", 5000)
		return
	end

	if armour < 25 then
		TriggerClientEvent(
			"Notify",
			src,
			"Sistema",
			"O colete está demasiado danificado, não consegues restaurar!",
			"vermelho",
			6000
		)
		return
	end

	TriggerClientEvent("admin:applyArmour", src, 100)
	TriggerClientEvent("Notify", src, "Governo", "Foi restaurado o seu <b>colete!</b>", "verde", 5000)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT / CLOSE
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Disconnect", function(Passport)
	if Open[Passport] then
		Open[Passport] = nil
	end
	if armourCooldown then
		armourCooldown[Passport] = nil
	end
end)

RegisterNetEvent("chest:Close")
AddEventHandler("chest:Close", function()
	local src = source
	local passport = vRP.Passport(src)
	if not passport then
		return
	end

	local sess = Open[passport]
	if not sess then
		return
	end

	-- Se for Custom, gera logs por diff (guarda/retira) mesmo sem Store/Take
	if sess.Mode == "Custom" then
		local before = shallowCopy(sess.Snapshot or {})
		local after = vRP.GetSrvData(sess.Name, sess.Save) or {}
		local chestName = sess.NameLogs or sess.Name

		-- index conjunto de todos os slots (before + after)
		local keys = {}
		for k in pairs(before) do
			keys[k] = true
		end
		for k in pairs(after) do
			keys[k] = true
		end

		local firstName, lastName = vRP.FullName(passport)
		firstName = firstName or "Indefinido"
		lastName = lastName or ""

		for k in pairs(keys) do
			local b = getEntry(before, k)
			local a = getEntry(after, k)

			local bItem = b and b.item or nil
			local aItem = a and a.item or nil
			local bAmt = b and parseInt(b.amount) or 0
			local aAmt = a and parseInt(a.amount) or 0

			if bItem and aItem and bItem == aItem then
				if aAmt > bAmt then
					local diff = aAmt - bAmt
					exports["discord"]:Embed(
						"Baus",
						"**🟩 ITEM GUARDADO NO BAÚ**\n\n"
							.. "📦 **Passaporte:** "
							.. passport
							.. "\n👤 **Nome:** "
							.. firstName
							.. " "
							.. lastName
							.. "\n🏷️ **Baú:** "
							.. chestName
							.. "\n📥 **Guardou:** "
							.. diff
							.. "x "
							.. (ItemName(aItem) or aItem)
							.. "\n🕒 **Data & Hora:** "
							.. os.date("%d/%m/%Y")
							.. " às "
							.. os.date("%H:%M")
					)
				elseif bAmt > aAmt then
					local diff = bAmt - aAmt
					exports["discord"]:Embed(
						"Baus",
						"**🟥 ITEM RETIRADO DO BAÚ**\n\n"
							.. "📦 **Passaporte:** "
							.. passport
							.. "\n👤 **Nome:** "
							.. firstName
							.. " "
							.. lastName
							.. "\n🏷️ **Baú:** "
							.. chestName
							.. "\n📤 **Retirou:** "
							.. diff
							.. "x "
							.. (ItemName(bItem) or bItem)
							.. "\n🕒 **Data & Hora:** "
							.. os.date("%d/%m/%Y")
							.. " às "
							.. os.date("%H:%M")
					)
				end
			elseif bItem and not aItem then
				exports["discord"]:Embed(
					"Baus",
					"**🟥 ITEM RETIRADO DO BAÚ**\n\n"
						.. "📦 **Passaporte:** "
						.. passport
						.. "\n👤 **Nome:** "
						.. firstName
						.. " "
						.. lastName
						.. "\n🏷️ **Baú:** "
						.. chestName
						.. "\n📤 **Retirou:** "
						.. bAmt
						.. "x "
						.. (ItemName(bItem) or bItem)
						.. "\n🕒 **Data & Hora:** "
						.. os.date("%d/%m/%Y")
						.. " às "
						.. os.date("%H:%M")
				)
			elseif aItem and not bItem then
				exports["discord"]:Embed(
					"Baus",
					"**🟩 ITEM GUARDADO NO BAÚ**\n\n"
						.. "📦 **Passaporte:** "
						.. passport
						.. "\n👤 **Nome:** "
						.. firstName
						.. " "
						.. lastName
						.. "\n🏷️ **Baú:** "
						.. chestName
						.. "\n📥 **Guardou:** "
						.. aAmt
						.. "x "
						.. (ItemName(aItem) or aItem)
						.. "\n🕒 **Data & Hóra:** "
						.. os.date("%d/%m/%Y")
						.. " às "
						.. os.date("%H:%M")
				)
			end
		end
	end

	-- limpar sessão
	Open[passport] = nil
	if armourCooldown then
		armourCooldown[passport] = nil
	end
end)
