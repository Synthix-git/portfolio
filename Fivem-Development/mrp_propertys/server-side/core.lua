-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP          = Proxy.getInterface("vRP")
vRPC         = Tunnel.getInterface("vRP")

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
Creative = {}
Tunnel.bindInterface("propertys",Creative)
vKEYBOARD = Tunnel.getInterface("keyboard")
vSKINSHOP = Tunnel.getInterface("skinshop")

-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Lock          = {}
local Saved         = {}
local Inside        = {}
local Active        = {}
local CountClothes  = {}

-- Cooldowns de roubo
local RobberyCooldowns = {}   -- por propriedade (Name) -> epoch
local PlayerCooldowns  = {}   -- por passaporte -> epoch

-- Animação usada no arrombamento (mesma do “Stockade”)
local ANIM_DICT = "missheistfbi3b_ig7"
local ANIM_NAME = "lift_fibagent_loop"

-- [[ LOOT LIST DO ROUBO DE MÓVEL ]]
PropertyRobbery_DropList = {
    -- Dinheiro sujo base (sempre tenta cair)
    { Item = "dirtydollar", Chance = 100, Min = 4500, Max = 12750 },

    -- Comuns
    { Item = "techtrash",            Chance = 70, Min = 1, Max = 3 },
    { Item = "electroniccomponents", Chance = 65, Min = 1, Max = 3 },
    { Item = "powercable",           Chance = 60, Min = 1, Max = 2 },
    { Item = "screws",               Chance = 50, Min = 1, Max = 3 },
    { Item = "screwnuts",            Chance = 45, Min = 1, Max = 3 },
    { Item = "scotchtape",           Chance = 40, Min = 1, Max = 2 },
    { Item = "insulatingtape",       Chance = 40, Min = 1, Max = 2 },
    { Item = "tarp",                 Chance = 35, Min = 1, Max = 2 },
    { Item = "sheetmetal",           Chance = 35, Min = 1, Max = 2 },
    { Item = "roadsigns",            Chance = 35, Min = 1, Max = 2 },
    { Item = "batteryaa",            Chance = 35, Min = 1, Max = 2 },
    { Item = "batteryaaplus",        Chance = 30, Min = 1, Max = 2 },

    -- Eletrônicos valiosos
    { Item = "ssddrive",             Chance = 25, Min = 1, Max = 2 },
    { Item = "safependrive",         Chance = 20, Min = 1, Max = 1 },
    { Item = "rammemory",            Chance = 25, Min = 1, Max = 2 },
    { Item = "processor",            Chance = 20, Min = 1, Max = 1 },
    { Item = "processorfan",         Chance = 20, Min = 1, Max = 1 },
    { Item = "powersupply",          Chance = 20, Min = 1, Max = 1 },
    { Item = "videocard",            Chance = 8,  Min = 1, Max = 1 },
    { Item = "television",           Chance = 4,  Min = 1, Max = 1 },

    -- Jóias/luxo
    { Item = "goldnecklace",         Chance = 20, Min = 1, Max = 2 },
    { Item = "silverchain",          Chance = 22, Min = 1, Max = 2 },
    { Item = "horsefigurine",        Chance = 6,  Min = 1, Max = 1 },
    { Item = "goldenjug",            Chance = 3,  Min = 1, Max = 1 },
    { Item = "goldenleopard",        Chance = 2,  Min = 1, Max = 1 },
    { Item = "goldenlion",           Chance = 1,  Min = 1, Max = 1 },

    -- “Kit do crime”
    { Item = "handcuff",             Chance = 8,  Min = 1, Max = 1 },
    { Item = "rope",                 Chance = 10, Min = 1, Max = 1 },
    { Item = "hood",                 Chance = 8,  Min = 1, Max = 1 },
    { Item = "pager",                Chance = 6,  Min = 1, Max = 1 },

    -- Raro
    { Item = "watch",                Chance = 2,  Min = 1, Max = 1 }
}

-----------------------------------------------------------------------------------------------------------------------------------------
-- GLOBALSTATE
-----------------------------------------------------------------------------------------------------------------------------------------
GlobalState["Markers"] = GlobalState["Markers"] or {}

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS
-----------------------------------------------------------------------------------------------------------------------------------------
local function normName(n)
    if type(n) == "string" then return n
    elseif type(n) == "number" then return tostring(n)
    elseif type(n) == "table" then
        return tostring(n.Name or n.name or n.id or n[1] or "")
    elseif type(n) == "boolean" or n == nil then
        return ""
    else
        return tostring(n)
    end
end

local function asNumber(x, default)
	if type(x) == "number" then return x end
	if type(x) == "string" then return tonumber(x) or (default or 0) end
	return default or 0
end

local function toEpoch(v)
	if type(v) == "number" then return v end
	if type(v) == "string" then local n = tonumber(v); if n then return n end end
	return 0
end

local function getAmount(x)
	if type(x) == "number" then return x end
	if type(x) == "table" then return tonumber(x.amount) or tonumber(x[1]) or 0 end
	if type(x) == "string" then return tonumber(x) or 0 end
	return 0
end

local function CountPolice()
	local total = 0
	for _,_ in pairs(vRP.NumPermission("LSPD") or {}) do total = total + 1 end
	for _,_ in pairs(vRP.NumPermission("SWAT") or {}) do total = total + 1 end
	for _,_ in pairs(vRP.NumPermission("FIB")  or {}) do total = total + 1 end
	return total
end

-- VIP Mult
local function robberyVipMult(source, passport)
	if not passport then return 1.0 end
	if not vRP.HasGroup(passport,"Premium") then return 1.0 end
	local lvl = (vRP.LevelPremium and vRP.LevelPremium(source)) or 1
	if lvl == 1 then return 1.25 -- Ouro
	elseif lvl == 2 then return 1.15 -- Prata
	elseif lvl == 3 then return 1.10 -- Bronze
	end
	return 1.0
end

-- Level/XP (usa ESC do teu servidor)  (MANTER ANTES DAS FUNÇÕES QUE USAM)
local ROB_XP_TRACK       = "Assaltante"
local ROB_XP_INVASION    = 3
local ROB_XP_LOOT        = 1
local ROB_LEVEL_RARE     = 0.05
local ROB_LEVEL_QTY      = 0.05

-- ROLAGEM DE LOOT (única!)
local function RollRobberyLoot(list, lvl, vipMult)
    local qtyMult  = 1.0 + (lvl * ROB_LEVEL_QTY)
    local rareMult = 1.0 + (lvl * ROB_LEVEL_RARE)

    local loot, slot = {}, 1
    local function add(item, amount)
        amount = parseInt(amount or 0)
        if ItemExist(item) and amount > 0 then
            loot[tostring(slot)] = { item = item, amount = amount }
            slot = slot + 1
        end
    end

    for _, d in ipairs(list or {}) do
        local chance = math.min(100, math.floor((d.Chance or 100) * rareMult + 0.0001))
        if math.random(100) <= chance then
            local base = math.random(d.Min or 1, d.Max or 1)
            local q    = math.max(1, math.floor(base * qtyMult * vipMult + 0.0001))
            add(d.Item, q)
        end
    end

    return loot
end

-- Break-in (server-side, estilo Stockade)
local MIN_POLICE         = 1
local PROPERTY_COOLDOWN  = 300
local PLAYER_COOLDOWN    = 60
local MAX_MOVE_DISTANCE  = 0.35
local WATCHDOG_TICK      = 150
local EXPIRE_GRACE_MS    = 1500
local PROGRESS_EVENT_START  = "Progress"
local PROGRESS_EVENT_CANCEL = "ProgressCancel"

-- Sessões de arrombamento ativas
local ActiveBreakin = {}
local SeqBreakin    = 0

local function getCoordsSafe(src)
    local ok, coords = pcall(vRP.GetEntityCoords, src)
    if ok and coords then return coords end
    return nil
end

local function vecDist(a,b)
    local dx,dy,dz = a.x-b.x, a.y-b.y, a.z-b.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local function lockPlayer(src)
    Player(src)["state"]["Buttons"] = true
    if vRPC and vRPC.FreezePosition then vRPC.FreezePosition(src,true) end
    if vRPC and vRPC.BlockTasks then vRPC.BlockTasks(src,true) end
end

local function unlockPlayer(src)
    Player(src)["state"]["Buttons"] = false
    if vRPC and vRPC.BlockTasks then vRPC.BlockTasks(src,false) end
    if vRPC and vRPC.FreezePosition then vRPC.FreezePosition(src,false) end
end

local function startAnim(src) if vRPC and vRPC.playAnim then vRPC.playAnim(src,false,{ANIM_DICT,ANIM_NAME},true) end end
local function stopAnim(src)  if vRPC and vRPC.Destroy then vRPC.Destroy(src) end end

local function forceCloseProgress(src)
    TriggerClientEvent(PROGRESS_EVENT_CANCEL, src)
    TriggerClientEvent(PROGRESS_EVENT_START,  src, "", 50)
    SetTimeout(60, function() TriggerClientEvent(PROGRESS_EVENT_CANCEL, src) end)
end

local function cancelBreakin(passport, reasonNotify)
    local act = ActiveBreakin[passport]
    if not act then return end
    local src = act.src
    ActiveBreakin[passport] = nil
    if src then
        stopAnim(src)
        forceCloseProgress(src)
        unlockPlayer(src)
        if reasonNotify then
            TriggerClientEvent("Notify",src,"Propriedades","Assalto <b>cancelado</b> ("..reasonNotify..").","amarelo",5000)
        end
    end
end

local function startWatchdogBreakin(passport, token, startCoords, effMs)
    CreateThread(function()
        local deadline = GetGameTimer() + effMs + 250
        while true do
            Wait(WATCHDOG_TICK)
            local act = ActiveBreakin[passport]
            if not act or act.token ~= token then break end
            if GetGameTimer() >= deadline then break end

            local coords = getCoordsSafe(act.src)
            if not coords then
                cancelBreakin(passport,"desconexão do ped")
                break
            end
            if vecDist(coords, startCoords) > MAX_MOVE_DISTANCE then
                cancelBreakin(passport,"movimentação")
                break
            end
        end
    end)
end

CreateThread(function()
    while true do
        Wait(1000)
        local nowMs = GetGameTimer()
        for passport, act in pairs(ActiveBreakin) do
            repeat
                if not act or not act.endsAtMs then
                    cancelBreakin(passport)
                    break
                end
                if nowMs >= (act.endsAtMs + EXPIRE_GRACE_MS) then
                    cancelBreakin(passport)
                    break
                end
                if not act.src or not Player(act.src) then
                    ActiveBreakin[passport] = nil
                    break
                end
            until true
        end
    end
end)

local function robberyLevel(passport)
	local exp = vRP.GetExperience(passport, ROB_XP_TRACK)
	return (ClassCategory and ClassCategory(exp)) or 1
end

local function GetRobbableInterior()
	for name,data in pairs(Internal) do
		if type(data) == "table" and data["Furniture"] and next(data["Furniture"]) then
			return name
		end
	end
	return "Hotel"
end

local CROWBAR_ALIASES = {
    ["crowbar"] = true,
    ["weapon_crowbar"] = true,
    ["pe-de-cabra"] = true,
    ["pedecabra"] = true,
    ["pé-de-cabra"] = true,
    ["pédecabra"] = true
}

local function HasCrowbarInInventory(passport)
    local inv = vRP.Inventory(passport) or {}
    for _, it in pairs(inv) do
        local key   = tostring(it.item or ""):lower()
        local amt   = tonumber(it.amount) or 0
        if amt > 0 then
            if CROWBAR_ALIASES[key] then return true end
            if key:find("crowbar", 1, true) or key:find("cabra", 1, true) then return true end
        end
    end
    return false
end

local function HasCrowbar(src, passport)
    if HasCrowbarInInventory(passport) then return true end
    if vRPC and vRPC.CheckWeapon then
        local ok = vRPC.CheckWeapon(src, "WEAPON_CROWBAR")
        if ok then return true end
    end
    return false
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYS
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Propertys(Name)
	local source   = source
	local Passport = vRP.Passport(source)
	if not Passport then return false end

    Name = normName(Name)
    if Name == "" then return false end

	local Consult = vRP.Query("propertys/Exist",{ Name = Name })
	if Consult[1] then
		if Consult[1]["Passport"] == Passport or vRP.InventoryFull(Passport,"propertys-"..Consult[1]["Serial"]) or Lock[Name] then
			if not Saved[Name] then Saved[Name] = Consult[1]["Interior"] end

			local Interior = Saved[Name]
			local Price    = (Informations[Interior]["Price"] or 0) * 0.25
			local Tax      = CompleteTimers((Consult[1]["Tax"] or os.time()) - os.time())

			if os.time() > (Consult[1]["Tax"] or 0) then
				Tax = "Efetue o pagamento da <b>Hipoteca</b>."
				if vRP.Request(source,"Propriedades","Deseja pagar a hipoteca de <b>$"..Dotted(Price).."</b>?") and vRP.PaymentFull(Passport,Price) then
					TriggerClientEvent("Notify",source,"Propriedades","Pagamento concluído.","verde",5000)
					vRP.Query("propertys/Tax",{ Name = Name })
					Tax = CompleteTimers(2592000)
				else
					return false
				end
			end

			return { ["Interior"] = Interior, ["Tax"] = Tax }
		end
	else
		return "Nothing"
	end
	return false
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- TOGGLE (dentro/fora) — bucket isolado por PROPRIEDADE (Hotel por passaporte)
-----------------------------------------------------------------------------------------------------------------------------------------

-- gera um id de bucket estável
local function makeBucketId(key, salt)
    -- tenta extrair número final se existir (ex.: "Propertys0123" -> 123)
    local num = tonumber(tostring(key):match("(%d+)$") or "")
    if num then return salt + (num % 50000) end

    -- fallback: hash estável
    local h = GetHashKey(("bucket:%s"):format(key))
    if h < 0 then h = h + 0x100000000 end
    return salt + (h % 50000)
end

-- bucket por propriedade; Hotel fica por-passaporte (cada jogador sua “suíte”)
local function bucketFor(Name, Passport)
    if Name == "Hotel" then
        return makeBucketId(("Hotel:%s"):format(Passport), 15000)
    end
    return makeBucketId(("Prop:%s"):format(Name), 12000)
end

-- guardas de estado (útil p/ debug/limpeza)
local PlayerBucket = {}
local Inside = Inside or {} -- mantém compat com o teu estado atual

function Creative.Toggle(Name, Mode)
    local src = source
    local Passport = vRP.Passport(src)
    if not Passport then return end

    Name = normName(Name or "")
    if Name == "" then return end

    if Mode == "Exit" then
        Inside[Passport] = nil
        PlayerBucket[src] = nil

        -- sai para o bucket 0 (mundo público)
        SetPlayerRoutingBucket(src, 0)
        -- (opcional) reativa população do bucket 0 — normalmente já ativa
        -- SetRoutingBucketPopulationEnabled(0, true)

        -- teu fluxo original
        TriggerEvent("vRP:ReloadWeapons", src)

        -- debug
        -- print(("[PROPERTYS] %s (%s) EXIT -> bucket 0"):format(GetPlayerName(src) or "?", Passport))
        return
    end

    -- ENTER
    if not Propertys[Name] or not Propertys[Name]["Coords"] then
        -- print(("[PROPERTYS] Toggle: propriedade inválida: %s"):format(tostring(Name)))
        return
    end

    TriggerEvent("DebugWeapons", Passport, src)
    Inside[Passport] = Propertys[Name]["Coords"]

    local bucket = bucketFor(Name, Passport)

    -- desativa população (peds/tráfego) no interior
    SetRoutingBucketPopulationEnabled(bucket, false)
    -- aplica bucket ao jogador
    SetPlayerRoutingBucket(src, bucket)
    PlayerBucket[src] = bucket

    -- debug
    -- print(("[PROPERTYS] %s (%s) ENTER %s -> bucket %d")
    --     :format(GetPlayerName(src) or "?", Passport, Name, bucket))
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- ROUTENUMBER
-----------------------------------------------------------------------------------------------------------------------------------------
function RouteNumber(Name)
    Name = normName(Name)
	local Route = string.sub(Name,-4)
	return parseInt(Route)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- COMPRAR PROPRIEDADE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:Buy")
AddEventHandler("propertys:Buy", function(rawName)
    local src = source
    local Passport = vRP.Passport(src)
    if not Passport or not rawName then return end

    rawName = normName(rawName)
    if rawName == "" then return end

    local parts = splitString(rawName)
    local propName, interior, mode = parts[1], parts[2], parts[3]

    if not propName or not interior or not mode or not Informations or not Informations[interior] then
        TriggerClientEvent("Notify", src, "Propriedades", "Parâmetros inválidos.","vermelho",5000)
        return
    end

    if (vRP.GetFine(Passport) or 0) > 0 then
        TriggerClientEvent("Notify", src, "Propriedades", "Você possui débitos bancários.","amarelo",5000)
        return
    end

    local exists = vRP.Query("propertys/Exist", { Name = propName })
    if exists and exists[1] then
        TriggerClientEvent("Notify", src, "Propriedades", "Esta propriedade já foi comprada.","amarelo",5000)
        return
    end

    TriggerClientEvent("dynamic:Close", src)
    if not vRP.Request(src, "Propriedades", "Deseja comprar a propriedade?") then return end

    local serial = PropertysSerials()
    local info   = Informations[interior]

    if mode == "Dollar" then
        local price = parseInt(info.Price or 0)
        if price <= 0 then
            TriggerClientEvent("Notify", src, "Propriedades", "Preço inválido.","vermelho",5000)
            return
        end

        if not vRP.PaymentFull(Passport, price) then
            TriggerClientEvent("Notify", src, "Propriedades", "Dinheiro insuficiente.","amarelo",5000)
            return
        end

        local markers = GlobalState["Markers"] or {}
        markers[propName] = true
        GlobalState:set("Markers", markers, true)

        Saved[propName] = interior
        vRP.GiveItem(Passport, "propertys-"..serial, 3, true)

        vRP.Query("propertys/Buy", {
            Name     = propName,
            Interior = interior,
            Passport = Passport,
            Serial   = serial,
            Vault    = info.Vault or 0,
            Fridge   = info.Fridge or 0
        })

        TriggerClientEvent("Notify", src, "Propriedades", "Compra concluída.","verde",5000)
        return

    elseif mode == "Gemstone" then
        local gems = parseInt(info.Gemstone or 0)
        if gems <= 0 then
            TriggerClientEvent("Notify", src, "Propriedades", "Preço inválido.","vermelho",5000)
            return
        end

        if not vRP.PaymentGems(Passport, gems) then
            TriggerClientEvent("Notify", src, "Propriedades", "Diamante insuficiente.","amarelo",5000)
            return
        end

        local markers = GlobalState["Markers"] or {}
        markers[propName] = true
        GlobalState:set("Markers", markers, true)

        Saved[propName] = interior
        vRP.GiveItem(Passport, "propertys-"..serial, 3, true)

        vRP.Query("propertys/Buy", {
            Name     = propName,
            Interior = interior,
            Passport = Passport,
            Serial   = serial,
            Vault    = info.Vault or 0,
            Fridge   = info.Fridge or 0
        })

        TriggerClientEvent("Notify", src, "Propriedades", "Compra concluída.","verde",5000)
        return
    end

    TriggerClientEvent("Notify", src, "Propriedades", "Modo de compra inválido.","vermelho",5000)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- FECHADURA
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:Lock")
AddEventHandler("propertys:Lock",function(Name)
	local source   = source
	local Passport = vRP.Passport(source)
    Name = normName(Name)
    if not Passport or Name == "" then return end

	local Consult  = vRP.Query("propertys/Exist",{ Name = Name })
	if Passport and Consult[1] and (vRP.InventoryFull(Passport,"propertys-"..Consult[1]["Serial"]) or Consult[1]["Passport"] == Passport) then
		if Lock[Name] then
			Lock[Name] = nil
			TriggerClientEvent("Notify",source,"Propriedades","Propriedade <b>trancada</b>.","amarelo",5000)
		else
			Lock[Name] = true
			TriggerClientEvent("Notify",source,"Propriedades","Propriedade <b>destrancada</b>.","verde",5000)
		end
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- SELL / TRANSFER / CREDENTIALS / ITEM
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:Sell")
AddEventHandler("propertys:Sell",function(Name)
	local source   = source
	local Passport = vRP.Passport(source)
    Name = normName(Name)
	if not Passport or Name == "" then return end
	if Passport and not Active[Passport] then
		Active[Passport] = true

		local Consult = vRP.Query("propertys/Exist",{ Name = Name })
		if Consult[1] and Consult[1]["Passport"] == Passport then
			TriggerClientEvent("dynamic:Close",source)

			local Interior = Consult[1]["Interior"]
			local Price    = (Informations[Interior]["Price"] or 0) * 0.25
			if vRP.Request(source,"Propriedades","Vender por <b>$"..Dotted(Price).."</b>?") then
				if GlobalState["Markers"][Name] then
					local Markers = GlobalState["Markers"]
					Markers[Name] = nil
					GlobalState:set("Markers",Markers,true)
				end

				vRP.GiveBank(Passport,Price)
				vRP.RemSrvData("Vault:"..Name)
				vRP.RemSrvData("Fridge:"..Name)
				vRP.Query("propertys/Sell",{ Name = Name })
				TriggerClientEvent("garages:Clean",-1,Name)
				TriggerClientEvent("Notify",source,"Propriedades","Venda concluída.","verde",5000)
			end
		end

		Active[Passport] = nil
	end
end)

RegisterServerEvent("propertys:Transfer")
AddEventHandler("propertys:Transfer",function(Name)
	local source   = source
	local Passport = vRP.Passport(source)
    Name = normName(Name)
	if not Passport or Name == "" then return end
	if Passport and not Active[Passport] then
		Active[Passport] = true

		local Consult = vRP.Query("propertys/Exist",{ Name = Name })
		if Consult[1] and Consult[1]["Passport"] == Passport then
			TriggerClientEvent("dynamic:Close",source)

			local Keyboard = vKEYBOARD.Primary(source,"Passaporte")
			if Keyboard and vRP.Identity(Keyboard[1]) and vRP.Request(source,"Propriedades","Deseja transferir para o passaporte <b>"..Keyboard[1].."</b>?") then
				TriggerClientEvent("Notify",source,"Propriedades","Transferência concluída.","verde",5000)
				vRP.Query("propertys/Transfer",{ Name = Name, Passport = Keyboard[1] })
			end
		end

		Active[Passport] = nil
	end
end)

RegisterServerEvent("propertys:Credentials")
AddEventHandler("propertys:Credentials",function(Name)
	local source   = source
	local Passport = vRP.Passport(source)
    Name = normName(Name)
    if not Passport or Name == "" then return end
	local Consult  = vRP.Query("propertys/Exist",{ Name = Name })
	if Passport and Consult[1] and Consult[1]["Passport"] == Passport then
		TriggerClientEvent("dynamic:Close",source)

		if vRP.Request(source,"Propriedades","Ao prosseguir todos os cartões atuais deixam de funcionar. Continuar?") then
			local Serial = PropertysSerials()
			vRP.Query("propertys/Credentials",{ Name = Name, Serial = Serial })
			vRP.GiveItem(Passport,"propertys-"..Serial,Consult[1]["Item"],true)
		end
	end
end)

RegisterServerEvent("propertys:Item")
AddEventHandler("propertys:Item",function(Name)
	local source   = source
	local Passport = vRP.Passport(source)
    Name = normName(Name)
    if not Passport or Name == "" then return end
	local Consult  = vRP.Query("propertys/Exist",{ Name = Name })
	if Passport and Consult[1] and Consult[1]["Passport"] == Passport and Consult[1]["Item"] < 5 then
		TriggerClientEvent("dynamic:Close",source)

		if vRP.Request(source,"Propriedades","Comprar uma chave adicional por <b>"..Currency.."150.000</b>?") then
			if vRP.PaymentFull(Passport,150000) then
				vRP.Query("propertys/Item",{ Name = Name })
				vRP.GiveItem(Passport,"propertys-"..Consult[1]["Serial"],1,true)
			else
				TriggerClientEvent("Notify",source,"Propriedades","Dinheiro insuficiente.","amarelo",5000)
			end
		end
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- WARDROBE
-----------------------------------------------------------------------------------------------------------------------------------------
local function WardrobeLimit(src, Passport)
	local limit = 10
	if vRP.UserPremium(Passport) then
		local Hierarchy = vRP.LevelPremium and (vRP.LevelPremium(src) or 0) or 0
		limit = (Hierarchy == 1 and 30) or (Hierarchy == 2 and 25) or (Hierarchy >= 3 and 20) or 10
	end
	return limit
end

function Creative.Clothes()
    local Clothes = {}
    local src = source
    local Passport = vRP.Passport(src)
    if Passport then
        if not CountClothes[Passport] then
            CountClothes[Passport] = WardrobeLimit(src, Passport)
        end
        local Consult = vRP.GetSrvData("Wardrobe:"..Passport, true)
        for name,_ in pairs(Consult) do
            Clothes[#Clothes + 1] = name
        end
    end
    return Clothes
end

RegisterServerEvent("propertys:Clothes")
AddEventHandler("propertys:Clothes", function(Mode)
    local src = source
    local Passport = vRP.Passport(src)
    if Passport then
        local Consult = vRP.GetSrvData("Wardrobe:"..Passport, true)
        local Split   = splitString(Mode)
        local Name    = Split[2]

        if not CountClothes[Passport] then
            CountClothes[Passport] = WardrobeLimit(src, Passport)
        end

        if Split[1] == "Save" then
            if CountTable(Consult) >= CountClothes[Passport] then
                TriggerClientEvent("Notify", src, "Armário", "Limite atingido de roupas.","amarelo",5000)
                return false
            end

			local Keyboard = vKEYBOARD.Primary(src,"Nome")
			if Keyboard then
				local Check = sanitizeString(Keyboard[1],"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")

				if string.len(Check) >= 4 then
					if not Consult[Check] then
						Consult[Check] = vSKINSHOP.Customization(src)
						vRP.SetSrvData("Wardrobe:"..Passport,Consult,true)
						TriggerClientEvent("dynamic:AddMenu",src,Check,"Informações da vestimenta.",Check,"wardrobe")
						TriggerClientEvent("dynamic:AddButton",src,"Aplicar","Vestir-se com as vestimentas.","propertys:Clothes","Apply-"..Check,Check,true)
						TriggerClientEvent("dynamic:AddButton",src,"Remover","Deletar a vestimenta do armário.","propertys:Clothes","Delete-"..Check,Check,true,true)
					end
				else
					TriggerClientEvent("Notify",src,"Armário","Nome precisa ter mínimo de 4 letras.","amarelo",5000)
				end
			end

		elseif Split[1] == "Delete" then
			if Consult[Name] then
				Consult[Name] = nil
				vRP.SetSrvData("Wardrobe:"..Passport,Consult,true)
			end

		elseif Split[1] == "Apply" then
			if Consult[Name] then
				TriggerClientEvent("skinshop:Apply",src,Consult[Name])
			end
		end
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- PROPERTYSSERIALS
-----------------------------------------------------------------------------------------------------------------------------------------
function PropertysSerials()
	repeat
		Serial  = GenerateString("LDLDLDLDLD")
		Consult = vRP.Query("propertys/Serial",{ Serial = Serial })
	until Serial and not Consult[1]
	return Serial
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- PERMISSION
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Permission(Name)
	local source   = source
	local Passport = vRP.Passport(source)
    Name = normName(Name)
    if Name == "" then return false end
	local Consult  = vRP.Query("propertys/Exist",{ Name = Name })
	if Passport and (Consult[1] and (vRP.InventoryFull(Passport,"propertys-"..Consult[1]["Serial"]) or Consult[1]["Passport"] == Passport)) then
		return true
	end
	return false
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- MOUNT / STORE / TAKE / UPDATE
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Mount(Name,Mode)
	local Weight   = 25
	local source   = source
	local Passport = vRP.Passport(source)

    Name = normName(Name)
	if not (Passport and Name ~= "" and Mode) then return false end

	local Consult = vRP.Query("propertys/Exist",{ Name = Name })
	if Consult and Consult[1] and Consult[1][Mode] then
		Weight = Consult[1][Mode]
	end

	-- CUSTOM CHEST (loot do roubo) → Name é a key completa do chest (ex: PropertyRobbery:CasaX:3)
    if Mode == "Custom" then
        local src      = source
        local Passport = vRP.Passport(src)
        if not Passport then return false end

        local Weight    = 0 -- sem limite visual
        local Primary   = {}
        local Secondary = {}

        -- inventário do player (Primary)
        local Inv = vRP.Inventory(Passport)
        for Index,v in pairs(Inv) do
            if (v["amount"] <= 0 or not ItemExist(v["item"])) then
                vRP.RemoveItem(Passport,v["item"],v["amount"],false)
            else
                v["name"]    = ItemName(v["item"])
                v["weight"]  = ItemWeight(v["item"])
                v["index"]   = ItemIndex(v["item"])
                v["amount"]  = parseInt(v["amount"])
                v["rarity"]  = ItemRarity(v["item"])
                v["economy"] = ItemEconomy(v["item"])
                v["desc"]    = ItemDescription(v["item"])
                v["key"]     = v["item"]
                v["slot"]    = Index

                local Split = splitString(v["item"])
                if Split[2] then
                    local Loaded = ItemLoads(v["item"])
                    if Loaded then v["charges"] = parseInt(Split[2] * (100 / Loaded)) end
                    if ItemDurability(v["item"]) then
                        v["durability"] = parseInt(os.time() - Split[2])
                        v["days"]       = ItemDurability(v["item"])
                    end
                end
                Primary[Index] = v
            end
        end

        -- conteúdo do chest (Secondary) está salvo diretamente em Name
        local ChestData = vRP.GetSrvData(Name, true) or {}
        for Index,v in pairs(ChestData) do
            if (v["amount"] <= 0 or not ItemExist(v["item"])) then
                vRP.RemoveChest(Name, Index, true)
            else
                v["name"]    = ItemName(v["item"])
                v["weight"]  = ItemWeight(v["item"])
                v["index"]   = ItemIndex(v["item"])
                v["amount"]  = parseInt(v["amount"])
                v["rarity"]  = ItemRarity(v["item"])
                v["economy"] = ItemEconomy(v["item"])
                v["desc"]    = ItemDescription(v["item"])
                v["key"]     = v["item"]
                v["slot"]    = Index

                local Split = splitString(v["item"])
                if Split[2] then
                    local Loaded = ItemLoads(v["item"])
                    if Loaded then v["charges"] = parseInt(Split[2] * (100 / Loaded)) end
                    if ItemDurability(v["item"]) then
                        v["durability"] = parseInt(os.time() - Split[2])
                        v["days"]       = ItemDurability(v["item"])
                    end
                end

                Secondary[Index] = v
            end
        end

        return Primary, Secondary, vRP.CheckWeight(Passport), Weight
    end

	local Primary = {}
	local Inv     = vRP.Inventory(Passport)
	for Index,v in pairs(Inv) do
		if (v["amount"] <= 0 or not ItemExist(v["item"])) then
			vRP.RemoveItem(Passport,v["item"],v["amount"],false)
		else
			v["name"]    = ItemName(v["item"])
			v["weight"]  = ItemWeight(v["item"])
			v["index"]   = ItemIndex(v["item"])
			v["amount"]  = parseInt(v["amount"])
			v["rarity"]  = ItemRarity(v["item"])
			v["economy"] = ItemEconomy(v["item"])
			v["desc"]    = ItemDescription(v["item"])
			v["key"]     = v["item"]
			v["slot"]    = Index

			local Split = splitString(v["item"])

			if not v["desc"] then
				if Split[1] == "vehiclekey" and Split[3] then
					v["desc"] = "Placa do Veículo: <common>"..Split[3].."</common>"
				elseif ItemNamed(Split[1]) and Split[2] then
					if Split[1] == "identity" then
						v["desc"] = "Passaporte: <rare>"..Dotted(Split[2]).."</rare><br>Nome: <rare>"..vRP.FullName(Split[2]).."</rare><br>Telefone: <rare>"..vRP.Phone(Passport).."</rare>"
					else
						v["desc"] = "Propriedade: <common>"..vRP.FullName(Split[2]).."</common>"
					end
				end
			end

			if Split[2] then
				local Loaded = ItemLoads(v["item"])
				if Loaded then v["charges"] = parseInt(Split[2] * (100 / Loaded)) end
				if ItemDurability(v["item"]) then
					v["durability"] = parseInt(os.time() - Split[2])
					v["days"]       = ItemDurability(v["item"])
				end
			end

			Primary[Index] = v
		end
	end

	local Secondary = {}
	local ChestData = vRP.GetSrvData(Mode..":"..Name,true)
	for Index,v in pairs(ChestData) do
		if (v["amount"] <= 0 or not ItemExist(v["item"])) then
			vRP.RemoveChest(Mode..":"..Name,Index,true)
		else
			v["name"]    = ItemName(v["item"])
			v["weight"]  = ItemWeight(v["item"])
			v["index"]   = ItemIndex(v["item"])
			v["amount"]  = parseInt(v["amount"])
			v["rarity"]  = ItemRarity(v["item"])
			v["economy"] = ItemEconomy(v["item"])
			v["desc"]    = ItemDescription(v["item"])
			v["key"]     = v["item"]
			v["slot"]    = Index

			local Split = splitString(v["item"])
			if not v["desc"] then
				if Split[1] == "vehiclekey" and Split[3] then
					v["desc"] = "Placa do Veículo: <common>"..Split[3].."</common>"
				elseif ItemNamed(Split[1]) and Split[2] then
					if Split[1] == "identity" then
						v["desc"] = "Passaporte: <rare>"..Dotted(Split[2]).."</rare><br>Nome: <rare>"..vRP.FullName(Split[2]).."</rare><br>Telefone: <rare>"..vRP.Phone(Passport).."</rare>"
					else
						v["desc"] = "Propriedade: <common>"..vRP.FullName(Split[2]).."</common>"
					end
				end
			end

			if Split[2] then
				local Loaded = ItemLoads(v["item"])
				if Loaded then v["charges"] = parseInt(Split[2] * (100 / Loaded)) end
				if ItemDurability(v["item"]) then
					v["durability"] = parseInt(os.time() - Split[2])
					v["days"]       = ItemDurability(v["item"])
				end
			end

			Secondary[Index] = v
		end
	end

	return Primary,Secondary,vRP.CheckWeight(Passport),Weight
end

function Creative.Store(Item,Slot,Amount,Target,Name,Mode)
	local source   = source
	local Amount   = parseInt(Amount,true)
	local Passport = vRP.Passport(source)
	if not Passport then return end

    Name = normName(Name)
    if Name == "" then
        TriggerClientEvent("inventory:Update",source)
        return
    end

	-- no chest de roubo só pode RETIRAR
    if Mode == "Custom" then
        TriggerClientEvent("Notify",source,"Propriedades","Aqui só podes <b>retirar</b> itens.","amarelo",4000)
        TriggerClientEvent("inventory:Update",source)
        return
    end

	if (Mode == "Vault" and ItemFridge(Item)) or (Mode == "Fridge" and not ItemFridge(Item)) then
		TriggerClientEvent("inventory:Update",source)
		return
	end

	local Consult = vRP.Query("propertys/Exist",{ Name = Name })
	if not Consult[1] then return end

	if Item == "diagram" then
		if vRP.TakeItem(Passport,Item,Amount,false,Slot) then
			vRP.Query("propertys/"..Mode,{ Name = Name, Weight = 10 * Amount })
			TriggerClientEvent("inventory:Update",source)
		end
	elseif vRP.StoreChest(Passport,Mode..":"..Name,Amount,Consult[1][Mode],Slot,Target,true) then
		TriggerClientEvent("inventory:Update",source)
	end
end

function Creative.Take(Slot,Amount,Target,Name,Mode)
    local source   = source
    local Amount   = parseInt(Amount,true)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    Name = normName(Name)
    if Name == "" then return end

    local chestKey = (Mode == "Custom") and Name or (Mode..":"..Name)
    if vRP.TakeChest(Passport, chestKey, Amount, Slot, Target, true) then
        TriggerClientEvent("inventory:Update",source)
    end
end

function Creative.Update(Slot,Target,Amount,Name,Mode)
    local source   = source
    local Amount   = parseInt(Amount,true)
    local Passport = vRP.Passport(source)
    if not Passport then return end

    Name = normName(Name)
    if Name == "" then return end

    local chestKey = (Mode == "Custom") and Name or (Mode..":"..Name)
    if vRP.UpdateChest(Passport, chestKey, Slot, Target, Amount, true) then
        TriggerClientEvent("inventory:Update",source)
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Disconnect",function(Passport)
	if Inside[Passport] then
		vRP.InsidePropertys(Passport,Inside[Passport])
		Inside[Passport] = nil
	end
	if CountClothes[Passport] then
		CountClothes[Passport] = nil
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADSERVERSTART (Marcar propriedades existentes)
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	local Markers = GlobalState["Markers"]
	for _,v in pairs(vRP.Query("propertys/All")) do
		local Name = v["Name"]
		if Propertys[Name] then
			Markers[Name] = true
		end
	end
	GlobalState:set("Markers",Markers,true)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- CHARACTERCHOSEN
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("CharacterChosen",function(Passport,source)
	local Increments = {}
	if vRP.Scalar("propertys/Count",{ Passport = Passport }) > 0 then
		local Consult = vRP.Query("propertys/AllUser",{ Passport = Passport })
		if Consult[1] then
			for _,v in pairs(Consult) do
				local Name = v["Name"]
				if Propertys[Name] then
					Increments[#Increments + 1] = Propertys[Name]["Coords"]
				end
			end
		end
	end
	TriggerClientEvent("spawn:Increment",source,Increments)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- POLÍCIA (ruído)
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Police(entryCoords, playerCoords)
	local src      = source
	local Passport = vRP.Passport(src)
	if not Passport then return end

	exports["vrp"]:CallPolice({
		["Source"]      = src,
		["Passport"]    = Passport,
		["Permission"]  = "Policia",
		["Name"]        = "Invasão de Propriedade",
		["Percentage"]  = 650,
		["Wanted"]      = 90,
		["Code"]        = 13,
		["Color"]       = 6,
		["x"] = entryCoords and entryCoords.x, ["y"] = entryCoords and entryCoords.y, ["z"] = entryCoords and entryCoords.z
	})
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- TRY BREAK-IN (server valida e entra)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:TryBreakIn")
AddEventHandler("propertys:TryBreakIn", function(Name, durationMs)
    local src      = source
    local Passport = vRP.Passport(src)
    if not Passport then return end

    Name = normName(Name)
    if Name == "" or not Propertys[Name] then return end

    local now = os.time()

    PlayerCooldowns[Passport] = PlayerCooldowns[Passport] or 0
    if PlayerCooldowns[Passport] > now then
        TriggerClientEvent("Notify", src, "Propriedades", "Aguarde para tentar novamente.","amarelo",4500)
        return
    end

    if Propertys[Name]["Armazém"] or Name == "Hotel" then
        TriggerClientEvent("Notify", src, "Propriedades", "Este local não pode ser invadido.","amarelo",4500)
        return
    end

    if CountPolice() < MIN_POLICE then
        TriggerClientEvent("Notify", src, "Propriedades", "Poucos agentes em patrulha.","amarelo",4500)
        return
    end

    RobberyCooldowns[Name] = RobberyCooldowns[Name] or 0
    if RobberyCooldowns[Name] > now then
        TriggerClientEvent("Notify", src, "Propriedades", "Esta casa foi assaltada há pouco. Aguarde "..(RobberyCooldowns[Name] - now).."s.","amarelo",6000)
        return
    end

	if not HasCrowbar(src, Passport) then
		TriggerClientEvent("Notify", src, "Propriedades", "Precisas de um <b>Pé de Cabra</b>.", "amarelo", 5000)
		return
	end

    local exists = vRP.Query("propertys/Exist", { Name = Name })
    local TheftInterior
    if exists and exists[1] then
        TheftInterior = exists[1]["Interior"]
        Saved[Name]   = TheftInterior
    else
        TheftInterior = GetRobbableInterior()
    end
    if not TheftInterior or TheftInterior == "Hotel" then
        TriggerClientEvent("Notify", src, "Propriedades", "Sem interior configurado para assalto.","vermelho",4500)
        return
    end

    local effMs = tonumber(durationMs) or 10000

    if ActiveBreakin[Passport] then
        TriggerClientEvent("Notify", src, "Propriedades", "Já estás a arrombar.","amarelo",4500)
        return
    end

    SeqBreakin = SeqBreakin + 1
    local token       = SeqBreakin
    local startCoords = getCoordsSafe(src) or vec3(0.0,0.0,0.0)

    ActiveBreakin[Passport] = {
        token    = token,
        src      = src,
        name     = Name,
        interior = TheftInterior,
        endsAtMs = GetGameTimer() + effMs,
        warned25 = false,
        start    = startCoords
    }

    lockPlayer(src)
    TriggerClientEvent(PROGRESS_EVENT_START, src, "Arrombando", effMs)
    startAnim(src)

    SetTimeout(math.floor(effMs * 0.25), function()
        local act = ActiveBreakin[Passport]
        if act and act.token == token and not act.warned25 then
            act.warned25 = true
            TriggerClientEvent("Notify",src,"Atenção","<b>Uma testemunha viu o assalto, a polícia foi avisada!</b>","amarelo",6000)
            exports["vrp"]:CallPolice({
                ["Source"]=src, ["Passport"]=Passport,
                ["Permission"]="Policia", ["Name"]="Invasão de Propriedade",
                ["Code"]=31, ["Color"]=22
            })
        end
    end)

    startWatchdogBreakin(Passport, token, startCoords, effMs)

    SetTimeout(effMs, function()
        local act = ActiveBreakin[passport]
        act = ActiveBreakin[Passport] or act
        if not act or act.token ~= token then
            return
        end

        ActiveBreakin[Passport] = nil
        stopAnim(src); forceCloseProgress(src); unlockPlayer(src)

        RobberyCooldowns[Name]    = os.time() + PROPERTY_COOLDOWN
        PlayerCooldowns[Passport] = os.time() + PLAYER_COOLDOWN

        vRP.PutExperience(Passport, ROB_XP_TRACK, ROB_XP_INVASION)
        if exports["pause"] and exports["pause"].AddPoints then
            exports["pause"]:AddPoints(Passport, ROB_XP_INVASION)
        end

        TriggerClientEvent("propertys:Enter", src, Name, TheftInterior)
    end)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- ROBBERY: ROUBAR MÓVEL → GERAR BAÚ CUSTOM (abre pela NUI via chest:Open)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("propertys:RobberyItem")
AddEventHandler("propertys:RobberyItem", function(a, b)
    local src      = source
    local Passport = vRP.Passport(src)
    if not Passport then return end

    -- normalização de argumentos vindos do target
    -- pode vir (shop, service) OU (service, shop) OU (data = table) OU (data.params)
    local shopId, service

    local function pick(tbl)
        if type(tbl) ~= "table" then return nil end
        return tbl.shop or (tbl.params and tbl.params.shop),
               tbl.service or (tbl.params and tbl.params.service)
    end

    if type(a) == "table" then
        shopId, service = pick(a)
    elseif type(b) == "table" then
        shopId, service = pick(b)
        if not shopId and type(a) == "number" then shopId = a end
        if not service and type(a) == "string" then service = a end
    else
        -- posicional: a=shop (number), b=service (string)
        if type(a) == "number" and type(b) == "string" then
            shopId, service = a, b
        -- alternativa: a=service (string), b=shop (number)
        elseif type(a) == "string" and type(b) == "number" then
            shopId, service = b, a
        end
    end

    shopId  = tonumber(shopId) or 0
    service = tostring(service or "Property")

    -- anti-spam curtinho
    local now = os.time()
    PlayerCooldowns[Passport] = PlayerCooldowns[Passport] or 0
    if PlayerCooldowns[Passport] > now then return end
    PlayerCooldowns[Passport] = now + 2

    -- nivel/vip
    local lvl      = robberyLevel(Passport)
    local vipMult  = robberyVipMult(src, Passport)

    -- gerar loot a partir da lista configurada
    local loot = RollRobberyLoot(PropertyRobbery_DropList, lvl, vipMult)
    -- garante que há pelo menos algo (fallback: só dirtydollar com multiplicadores)
    if next(loot) == nil then
        local qtyMult = 1.0 + (lvl * ROB_LEVEL_QTY)
        local baseDirty = math.random(450, 950)
        local dirty = math.max(1, math.floor(baseDirty * qtyMult * vipMult + 0.0001))
        loot = { ["1"] = { item = "dirtydollar", amount = dirty } }
    end

    -- chave única do chest deste móvel
    local chestKey = ("PropertyRobbery:%s:%s"):format(service, tostring(shopId))

    -- grava e abre
    vRP.SetSrvData(chestKey, loot, true)
    TriggerClientEvent("chest:Open", src, chestKey, "Custom", false, true)

    -- XP/pontos
    vRP.PutExperience(Passport, ROB_XP_TRACK, ROB_XP_LOOT)
    if exports["pause"] and exports["pause"].AddPoints then
        exports["pause"]:AddPoints(Passport, ROB_XP_LOOT)
    end

    -- remove a zona para não duplicar
    if shopId and shopId ~= 0 then
        TriggerClientEvent("propertys:RemCircleZone", src, shopId)
    end
end)

