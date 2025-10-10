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
Tunnel.bindInterface("plants",Creative)

-----------------------------------------------------------------------------------------------------------------------------------------
-- STATE
-----------------------------------------------------------------------------------------------------------------------------------------
local Active  = {}
local Plants  = {}

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONFIG
-----------------------------------------------------------------------------------------------------------------------------------------
local GROWTH_TIME       = GetConvarInt("plants_growth_time", 600)     -- 10 min
local DEATH_AFTER       = GetConvarInt("plants_death_after", 18000)   -- 5 h após pronta
local WATER_TIME_REDUCE = GetConvarInt("plants_water_reduce", 160)     -- 120s por rega (base)
local MAX_WATERS_BASE   = GetConvarInt("plants_water_max", 3)         -- 3 regas base (nível pode dar +)
local MAX_FERTILIZERS   = GetConvarInt("plants_fert_max", 2)          -- 2 adubos
local ACTION_MAX_DIST   = 2.0 -- removemos checks de distância no fluxo (mantém só helper)

-- Skill / XP
local FARM_SKILL       = "Farmer"
local XP_WATER,XP_FERT,XP_CLONE,XP_HARVEST = 1,2,3,6

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS
-----------------------------------------------------------------------------------------------------------------------------------------
local function IsAdminLevel(Passport, level)
	if vRP.GroupLevel and vRP.HasGroup and vRP.HasGroup(Passport,"Admin") then
		return vRP.GroupLevel(Passport,"Admin") >= level
	end
	return vRP.HasGroup and vRP.HasGroup(Passport,"Admin")
end

-- LOGS — compatível com o teu recurso 'discord' (Embed(Hook, Message, source))
local function LogPlantas(title, description, _color, src)
    local channel = "Plantas" -- chave já existente no teu Discord[]
    local message = ("**%s**\n%s"):format(title or "Log", description or "")
    if GetResourceState("discord") == "started" and exports["discord"] then
        -- tenta chamada com ":" e com "." (ambas suportadas pela engine de exports)
        local ok = pcall(function() return exports["discord"]:Embed(channel, message, src or 0) end)
        if not ok then pcall(function() return exports["discord"].Embed(channel, message, src or 0) end) end
    else
        print(("[PLANTS][LOG FAIL] 'discord' não started. Msg:\n%s"):format(message))
    end
end


-- Consome 1 purifiedwater (suporta sufixo de durabilidade) e dá 1 emptypurifiedwater.
local function ConsumePurifiedWater(Passport)
	if not (vRP.InventoryItemAmount and vRP.TakeItem and vRP.GenerateItem) then
		return false
	end
	local info = vRP.InventoryItemAmount(Passport,"purifiedwater")
	local have = (info and info[1]) or 0
	local full = (info and info[2]) or ""
	if have <= 0 or full == "" then
		return false
	end
	if vRP.TakeItem(Passport, full, 1, true) then
		vRP.GenerateItem(Passport,"emptypurifiedwater",1,true)
		return true
	end
	return false
end

local function ConsumeFertilizer(Passport)
	if not (vRP.InventoryItemAmount and vRP.TakeItem) then return false end
	local info = vRP.InventoryItemAmount(Passport,"fertilizer")
	local have = (info and info[1]) or 0
	local full = (info and info[2]) or ""
	if have <= 0 or full == "" then return false end
	return vRP.TakeItem(Passport, full, 1, true)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- SKILL: AGRICULTOR (progressão lenta; boost nota-se 10+)
-----------------------------------------------------------------------------------------------------------------------------------------
local LEVEL_THRESHOLDS = {0,800,1800,3200,5200,7800,11000,15000,20000,26000,33000,41000,50000,60000,71500,84500,99000,115000,133000,153000,175000}
local function GetXP(Passport)
	if not Passport then return 0 end
	if exports["pause"] and exports["pause"].GetExperience then
		local ok,xp = pcall(function()
			return exports["pause"]:GetExperience(Passport, FARM_SKILL)
		end)
		if ok and type(xp) == "number" then return xp end
	end
	return 0
end

local function AddXP(Passport, amount)
	if not Passport or (tonumber(amount) or 0) <= 0 then return end
	if exports["pause"] and exports["pause"].AddExperience then
		pcall(function()
			exports["pause"]:AddExperience(Passport, FARM_SKILL, amount)
		end)
	end
end

local function LevelFromXP(xp) local lvl=0; for i=1,#LEVEL_THRESHOLDS do if xp>=LEVEL_THRESHOLDS[i] then lvl=i-1 else break end end return math.min(lvl,20) end
local function YieldBonusMult(lvl) local low=math.min(lvl,9)*0.005; local high=math.max(lvl-10,0)*0.02; return 1.0+math.min(0.20,low+high) end
local function CloneChance(lvl) local add=math.min(lvl,9)*0.5 + math.max(lvl-10,0)*1.5; return math.min(80.0,50.0+add) end
local function ExtraWaterReduce(lvl) return math.max(0,lvl-10)*2 end
local function ExtraMaxWaters(lvl) return (lvl>=12 and 1 or 0)+(lvl>=18 and 1 or 0) end

-----------------------------------------------------------------------------------------------------------------------------------------
-- LOAD DB + RESYNC
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	local ok,Consult = pcall(vRP.Query,"entitydata/GetData",{ Name = "Plants" })
	if ok and Consult and Consult[1] and Consult[1]["Information"] then
		local decoded = json.decode(Consult[1]["Information"])
		if type(decoded)=="table" then Plants = decoded end
	end

	for id,data in pairs(Plants) do
		if data and tonumber(data["Timer"]) and (os.time() - data["Timer"]) > DEATH_AFTER then
			Plants[id] = nil
		end
	end

	TriggerClientEvent("plants:Table",-1,Plants,os.time(),GROWTH_TIME)
end)

AddEventHandler("onResourceStart",function(res)
	if res == GetCurrentResourceName() then
		TriggerClientEvent("plants:Table",-1,Plants,os.time(),GROWTH_TIME)
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- CRIAR PLANTA (EXPORT)
-----------------------------------------------------------------------------------------------------------------------------------------
exports("Plants",function(Hash,Coords,Route,Item,_)
	repeat Selected = GenerateString("DDLLDDLL") until Selected and not Plants[Selected]

	Plants[Selected] = {
		["Water"]=0.0,["Fertilized"]=false,
		["WatersUsed"]=0,["FertsUsed"]=0,
		["Hash"]=Hash,["Item"]=Item,["Route"]=Route,["Coords"]=Coords,
		["Timer"]=os.time()+GROWTH_TIME
	}
	TriggerClientEvent("plants:New",-1,Selected,Plants[Selected],os.time(),GROWTH_TIME)

	LogPlantas("🌱 Nova Plantação",
		string.format("• **Item:** `%s`\n• **Rota:** `%s`\n• **Pos:** `%.2f, %.2f, %.2f`\n• **Pronta em:** **%d** s",
			Item,tostring(Route),Coords[1],Coords[2],Coords[3],GROWTH_TIME),
		3079437)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- CHECKDEATH
-----------------------------------------------------------------------------------------------------------------------------------------
local function CheckDeath(src,Number)
	local P = Plants[Number]
	if P and tonumber(P["Timer"]) and (os.time() - P["Timer"]) > DEATH_AFTER then
		local Tmp = Plants[Number]
		Plants[Number] = nil
		TriggerClientEvent("dynamic:Close",src)
		TriggerClientEvent("plants:Remove",-1,Number)
		TriggerClientEvent("Notify",src,"Horticultura","A plantação <b>apodreceu</b>.","vermelho",5000)
		if Tmp then
			LogPlantas("🧫 Planta Apodrecida",
				string.format("• **Item:** `%s`\n• **Rota:** `%s`\n• **Vida útil:** +%ds",
					Tmp["Item"], tostring(Tmp["Route"]), DEATH_AFTER),
				15158332)
		end
		return true
	end
	return false
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- COLHER (sem verificação de distância)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("plants:Collect")
AddEventHandler("plants:Collect",function(Number)
	local src=source; local Passport=vRP.Passport(src)
	if not (Passport and Plants[Number] and Plants[Number]["Timer"]) then return end
	if Active[Passport] or CheckDeath(src,Number) or os.time()<Plants[Number]["Timer"] then return end
	if not vRP.ConsultItem(Passport,"gardenshears") then
		TriggerClientEvent("Notify",src,"Horticultura","Precisa de <b>Tesoura de Poda</b>.","vermelho",5000)
		return
	end

	local tmp=Plants[Number]; Plants[Number]=nil
	Active[Passport]=true; Player(src)["state"]["Cancel"]=true; Player(src)["state"]["Buttons"]=true
	TriggerClientEvent("dynamic:Close",src); TriggerClientEvent("Progress",src,"Coletando",10000)
	vRPC.playAnim(src,false,{"anim@amb@clubhouse@tutorial@bkr_tut_ig3@","machinic_loop_mechandplayer"},true)

	SetTimeout(10000,function()
		local xp=GetXP(Passport); local lvl=LevelFromXP(xp); local mult=YieldBonusMult(lvl)
		local base = tmp["Fertilized"] and math.random(3,9) or math.random(1,3)
		local amount=base
		if tmp["Water"] and tmp["Water"]>0 then amount=amount+(amount*tmp["Water"]) end
		amount=math.floor(amount*mult)

		local can,_ = vRP.CanCarry and vRP.CanCarry(Passport,tmp["Item"],amount)
		if can then
			vRP.GenerateItem(Passport,tmp["Item"],amount,true)
		else
			TriggerClientEvent("Notify",src,"Mochila Sobrecarregada","Sua recompensa <b>caiu no chão</b>.","roxo",5000)
			if exports["inventory"] and exports["inventory"].Drops then
				exports["inventory"]:Drops(Passport,src,tmp["Item"],amount)
			end
		end

		-- Remoção imediata local + broadcast (garante que o prop some para ti na hora)
		TriggerClientEvent("plants:LocalRemove", src, Number)
		TriggerClientEvent("plants:Remove",-1,Number)

		Player(src)["state"]["Buttons"]=false; Player(src)["state"]["Cancel"]=false; Active[Passport]=nil; vRPC.Destroy(src)

		AddXP(Passport,XP_HARVEST)
		LogPlantas("✂️ Colheita",
			string.format("• **Passaporte:** `%s`\n• **Item:** `%s`\n• **Qtd:** **%d**\n• **Nível:** **%d**\n• **Água:** %.0f%% • **Adubo:** %s",
				tostring(Passport), tmp["Item"], amount, lvl, (tmp["Water"] or 0)*100, tmp["Fertilized"] and "Sim" or "Não"),
			3079437)
	end)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- CLONES (sempre)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("plants:Cloning")
AddEventHandler("plants:Cloning",function(Number)
	local src=source; local Passport=vRP.Passport(src)
	if not (Passport and Plants[Number] and Plants[Number]["Timer"]) then return end
	if Active[Passport] or CheckDeath(src,Number) then return end
	if not vRP.ConsultItem(Passport,"gardenshears") then
		TriggerClientEvent("Notify",src,"Horticultura","Precisa de <b>Tesoura de Poda</b> para obter clones.","vermelho",5000)
		return
	end

	Active[Passport]=true; Player(src)["state"]["Cancel"]=true; Player(src)["state"]["Buttons"]=true
	TriggerClientEvent("dynamic:Close",src); TriggerClientEvent("Progress",src,"A colher clones",10000)
	vRPC.playAnim(src,false,{"anim@amb@clubhouse@tutorial@bkr_tut_ig3@","machinic_loop_mechandplayer"},true)

	SetTimeout(10000,function()
		local xp=GetXP(Passport); local lvl=LevelFromXP(xp); local chance=CloneChance(lvl)
		local cloneItem=Plants[Number]["Item"].."clone"

		if math.random()*100.0 <= chance then
			local amount=math.random(1,3)
			local can,_ = vRP.CanCarry and vRP.CanCarry(Passport,cloneItem,amount)
			if can then
				vRP.GenerateItem(Passport,cloneItem,amount,true)
				TriggerClientEvent("Notify",src,"Horticultura","Obtiveste <b>"..amount.."</b> clone(s).","verde",5000)
			else
				TriggerClientEvent("Notify",src,"Mochila Sobrecarregada","Os clones <b>caíram no chão</b>.","roxo",5000)
				if exports["inventory"] and exports["inventory"].Drops then
					exports["inventory"]:Drops(Passport,src,cloneItem,amount)
				end
			end
			AddXP(Passport,XP_CLONE)
			LogPlantas("🌿 Clones Obtidos",
				string.format("• **Passaporte:** `%s`\n• **Item:** `%s`\n• **Clones:** **%d**\n• **Chance:** %.1f%% (Lv%d)",
					tostring(Passport), Plants[Number]["Item"], amount, chance, lvl),
				3447003)
		else
			TriggerClientEvent("Notify",src,"Horticultura","Desta vez não obtiveste clones.","amarelo",5000)
		end

		Player(src)["state"]["Buttons"]=false; Player(src)["state"]["Cancel"]=false; Active[Passport]=nil; vRPC.Destroy(src)
	end)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- ÁGUA
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("plants:Water")
AddEventHandler("plants:Water",function(Number)
	local src=source; local Passport=vRP.Passport(src)
	if not (Passport and Plants[Number] and Plants[Number]["Timer"]) then return end
	if Active[Passport] or CheckDeath(src,Number) then return end
	if Plants[Number]["Timer"] < os.time() then
		TriggerClientEvent("Notify",src,"Horticultura","Planta já está pronta.","amarelo",4000)
		return
	end
	if not vRP.ConsultItem(Passport,"purifiedwater") then
		TriggerClientEvent("Notify",src,"Horticultura","Precisa de <b>Água Purificada</b>.","amarelo",4000)
		return
	end

	local xp=GetXP(Passport); local lvl=LevelFromXP(xp); local maxWaters=MAX_WATERS_BASE+ExtraMaxWaters(lvl)
	local P=Plants[Number]
	if (P["WatersUsed"] or 0) >= maxWaters then
		TriggerClientEvent("Notify",src,"Horticultura","Esta planta já recebeu o <b>máximo de água</b>.","amarelo",5000)
		return
	end
	if P["Water"] >= 1.0 then
		TriggerClientEvent("Notify",src,"Horticultura","A planta já está com <b>hidratação máxima</b>.","amarelo",5000)
		return
	end

	Active[Passport]=true; Player(src)["state"]["Cancel"]=true; Player(src)["state"]["Buttons"]=true
	TriggerClientEvent("dynamic:Close",src); TriggerClientEvent("Progress",src,"Hidratando",10000)
	vRPC.CreateObjects(src,"weapon@w_sp_jerrycan","fire","prop_wateringcan",1,28422,0.4,0.1,0.0,90.0,180.0,0.0)
	SetTimeout(10000,function()
		-- consumir 1 purifiedwater (com sufixo)
		if not ConsumePurifiedWater(Passport) then
			Player(src)["state"]["Buttons"]=false
			Player(src)["state"]["Cancel"]=false
			Active[Passport]=nil
			vRPC.Destroy(src)
			TriggerClientEvent("Notify",src,"Horticultura","Sem <b>Água Purificada</b>.","amarelo",4000)
			return
		end

		-- aplica efeitos da rega
		if Plants[Number] then
			local extra = ExtraWaterReduce(lvl)
			Plants[Number]["Water"]      = math.min(1.0,(Plants[Number]["Water"] or 0.0) + 0.35)
			Plants[Number]["WatersUsed"] = (Plants[Number]["WatersUsed"] or 0) + 1
			Plants[Number]["Timer"]      = math.max(os.time(), Plants[Number]["Timer"] - (WATER_TIME_REDUCE + extra))
			TriggerClientEvent("plants:Update",-1,Number,Plants[Number],os.time(),GROWTH_TIME)
		end

		Player(src)["state"]["Buttons"]=false
		Player(src)["state"]["Cancel"]=false
		Active[Passport]=nil
		vRPC.Destroy(src)

		AddXP(Passport,XP_WATER)

		local remain = Plants[Number] and (Plants[Number]["Timer"] - os.time()) or 0
		LogPlantas("💧 Rega",
			string.format("• **Passaporte:** `%s`\n• **Nível:** **%d**\n• **Hidratação:** %.0f%% • **Usos:** %d/%d\n• **Tempo restante:** %ds",
				tostring(Passport), lvl, (Plants[Number] and Plants[Number]["Water"] or 0)*100,
				Plants[Number] and Plants[Number]["WatersUsed"] or 0,
				(MAX_WATERS_BASE + ExtraMaxWaters(lvl)), math.max(0,remain)),
			15844367)
	end)

end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- ADUBO
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterServerEvent("plants:Fertilizer")
AddEventHandler("plants:Fertilizer",function(Number)
	local src=source; local Passport=vRP.Passport(src)
	if not (Passport and Plants[Number] and Plants[Number]["Timer"]) then return end
	if Active[Passport] or CheckDeath(src,Number) then return end
	if Plants[Number]["Timer"] < os.time() then
		TriggerClientEvent("Notify",src,"Horticultura","Planta já está pronta.","amarelo",4000)
		return
	end
	if not vRP.ConsultItem(Passport,"fertilizer") then
		TriggerClientEvent("Notify",src,"Horticultura","Precisa de <b>Adubo</b>.","amarelo",4000)
		return
	end

	local P=Plants[Number]
	if (P["FertsUsed"] or 0) >= MAX_FERTILIZERS then
		TriggerClientEvent("Notify",src,"Horticultura","Esta planta já recebeu <b>adubo suficiente</b>.","amarelo",5000)
		return
	end

	Active[Passport]=true; Player(src)["state"]["Cancel"]=true; Player(src)["state"]["Buttons"]=true
	TriggerClientEvent("dynamic:Close",src); TriggerClientEvent("Progress",src,"Adubando",10000)
	vRPC.CreateObjects(src,"weapon@w_sp_jerrycan","fire","prop_wateringcan",1,28422,0.4,0.1,0.0,90.0,180.0,0.0)

	SetTimeout(10000,function()
		ConsumeFertilizer(Passport)

		if Plants[Number] then
			Plants[Number]["Fertilized"]=true
			Plants[Number]["FertsUsed"]=(Plants[Number]["FertsUsed"] or 0)+1
			TriggerClientEvent("plants:Update",-1,Number,Plants[Number],os.time(),GROWTH_TIME)
		end

		Player(src)["state"]["Buttons"]=false; Player(src)["state"]["Cancel"]=false; Active[Passport]=nil; vRPC.Destroy(src)
		AddXP(Passport,XP_FERT)
		LogPlantas("🧪 Adubo Aplicado",
			string.format("• **Passaporte:** `%s`\n• **Usos de adubo:** %d/%d",
				tostring(Passport), Plants[Number] and Plants[Number]["FertsUsed"] or 0, MAX_FERTILIZERS),
			3447003)
	end)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- INFORMATIONS
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Informations(Number)
	local src=source
	if Number and Plants[Number] and Plants[Number]["Timer"] and not CheckDeath(src,Number) then
		local Collect="Processo concluído."
		if os.time() < Plants[Number]["Timer"] then
			Collect="Aguarde "..CompleteTimers(Plants[Number]["Timer"]-os.time())
		end

		local xp=GetXP(vRP.Passport(src) or 0); local lvl=LevelFromXP(xp)
		local Cloning="Disponível para obter clones."

		return {
			Collect, Cloning, Plants[Number]["Item"], Plants[Number]["Water"],
			Plants[Number]["Fertilized"] and 1 or 0,
			Plants[Number]["WatersUsed"] or 0, Plants[Number]["FertsUsed"] or 0,
			MAX_WATERS_BASE+ExtraMaxWaters(lvl), MAX_FERTILIZERS,
			lvl, CloneChance(lvl)
		}
	end
	return false
end


-----------------------------------------------------------------------------------------------------------------------------------------
-- /plantwipe (Admin ≥ 2) — robusto com defaults e validações
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("plantwipe", function(source, args)
    local src = source
    local Passport = vRP.Passport(src)
    if not Passport or not IsAdminLevel(Passport, 2) then
        TriggerClientEvent("Notify", src, "Horticultura", "Sem permissão.", "vermelho", 5000)
        return
    end

    -- parse seguro do raio: default 50.0 se não vier nada / inválido
    local radius = tonumber(args and args[1] or nil)
    if not radius then radius = 50.0 end

    -- confirma se >200
    local confirm = tostring(args and args[2] or "")
    if radius > 200.0 and confirm ~= "confirm" then
        TriggerClientEvent("Notify", src, "Horticultura",
            "Raio > 200m. Confirma com: <b>/plantwipe "..math.floor(radius).." confirm</b>.",
            "amarelo", 8000)
        return
    end

    -- pega posição do staff
    local ped = GetPlayerPed(src)
    local px, py, pz = table.unpack(GetEntityCoords(ped))

    local removed = 0
    for id, data in pairs(Plants) do
        -- valida estrutura/coords
        local c = data and data["Coords"]
        local cx = c and tonumber(c[1])
        local cy = c and tonumber(c[2])
        local cz = c and tonumber(c[3])

        if cx and cy and cz then
            local dist = #(vec3(px, py, pz) - vec3(cx, cy, cz))
            -- radius é sempre número aqui
            if dist <= radius then
                Plants[id] = nil
                TriggerClientEvent("plants:Remove", -1, id)
                removed = removed + 1
            end
        end
    end

    TriggerClientEvent("Notify", src, "Horticultura",
        "Removidas <b>"..removed.."</b> planta(s) num raio de <b>"..math.floor(radius).."</b>m.",
        "verde", 5000)

    LogPlantas("🌪️ Plantas Removidas",
        string.format("• **Staff:** `%s`\n• **Removidas:** **%d**\n• **Raio:** **%dm**\n• **Pos:** `%.2f, %.2f, %.2f`",
            tostring(Passport), removed, math.floor(radius), px, py, pz),
        15158332)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECT / DISCONNECT / SAVE
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Connect",function(Passport,src)
	TriggerClientEvent("plants:Table",src,Plants,os.time(),GROWTH_TIME)
end)

AddEventHandler("Disconnect",function(Passport,src)
	if Active[Passport] then Active[Passport] = nil end
end)

AddEventHandler("SaveServer",function(Silenced)
	vRP.Query("entitydata/SetData",{ Name = "Plants", Information = json.encode(Plants) })
	if not Silenced then print("O resource ^2Plants^7 salvou os dados.") end
end)
