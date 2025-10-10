-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
Creative = {}
Tunnel.bindInterface("routes", Creative)

-----------------------------------------------------------------------------------------------------------------------------------------
-- ESTADOS
-----------------------------------------------------------------------------------------------------------------------------------------
local RewardItems  = {}  -- [Passport] = { opções ativas }
local ActiveRoutes = {}  -- [Passport] = { Route = "Name", Items = { indices } }
local RouteCost    = {}  -- [Passport] = soma dos preços

-----------------------------------------------------------------------------------------------------------------------------------------
-- ADMIN: /routes <Nome>
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterCommand("routes", function(source, args)
	local Passport = vRP.Passport(source)
	if not Passport then return end

	if vRP.HasGroup(Passport, "Admin") and args[1] then
		local name = args[1]
		if not Config[name] then
			TriggerClientEvent("Notify", source, "Rotas", ("Nome inválido: <b>%s</b>."):format(name), "amarelo", 6000)
			return
		end

		local ped = GetPlayerPed(source)
		local init = Config[name].Init
		if init then
			SetEntityCoords(ped, init.x, init.y, init.z, false, false, false, false)
			TriggerClientEvent("routes:Open", source, name)
		end
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- UTIL: sorteio por peso (Chance)
-----------------------------------------------------------------------------------------------------------------------------------------
local function RandByWeight(list)
	local total = 0
	for _, v in ipairs(list) do
		total = total + (tonumber(v.Chance) or 1)
	end
	if total <= 0 then
		return list[1]
	end
	local pick = math.random() * total
	local acum = 0
	for _, v in ipairs(list) do
		acum = acum + (tonumber(v.Chance) or 1)
		if pick <= acum then
			return v
		end
	end
	return list[#list]
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- BOOSTS: calcula multiplicador com base em Experience.Boosts
-- Cada boost tem: at (mín exp), mult (multiplicador), chance (%)
-----------------------------------------------------------------------------------------------------------------------------------------
local function ApplyBoosts(baseAmount, exp, boosts)
	if type(boosts) ~= "table" or #boosts == 0 then
		return baseAmount
	end

	local amount = baseAmount
	for _, b in ipairs(boosts) do
		local at     = tonumber(b.at) or 0
		local mult   = tonumber(b.mult) or 1.0
		local chance = tonumber(b.chance) or 0
		if exp >= at and chance > 0 and mult > 0 then
			if math.random(100) <= chance then
				amount = amount * mult
			end
		end
	end

	-- arredonda e garante mínimo 1
	amount = math.floor(amount + 0.0001)
	if amount < 1 then amount = 1 end
	return amount
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- PERMISSION
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Permission(Name)
	local src = source
	local Passport = vRP.Passport(src)
	if not Passport then return false end

	local Route = Config[Name]
	if not Route then return false end

	-- Se já está em rota e é a mesma, permite SEM verificar nada
	if ActiveRoutes[Passport] and ActiveRoutes[Passport].Route == Name then
		return true
	end

	-- Bloqueios primeiro
	if Route.Blocked and type(Route.Blocked) == "table" then
		for _, grp in ipairs(Route.Blocked) do
			if vRP.HasGroup(Passport, grp) then
				return false
			end
		end
	end

	-- Permission:
	if Route.Permission then
		if type(Route.Permission) == "string" then
			if not vRP.HasGroup(Passport, Route.Permission) then
				return false
			end
		elseif type(Route.Permission) == "table" then
			local group = Route.Permission[1]
			local level = tonumber(Route.Permission[2]) or 0
			if not vRP.HasPermission(Passport, group, level) then
				return false
			end
		end
	end

	return true
end


-----------------------------------------------------------------------------------------------------------------------------------------
-- START
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Start(Items, Name)
    local source = source
    local Passport = vRP.Passport(source)
    if not Passport then return false end

    -- ⬇️ guarda extra
    if ActiveRoutes[Passport] and ActiveRoutes[Passport].Route ~= Name then
        TriggerClientEvent("Notify", source, "Rotas", "Termina a tua rota atual antes de iniciar outra.", "amarelo", 6000)
        return false
    end


	local Route = Config[Name]
	if not Route then return false end

	RouteCost[Passport] = 0
	local activeOpts = {}

	-- Monta opções com Min/Max/Chance/Price
	for _, Index in ipairs(Items or {}) do
		local opt = Route.List[Index]
		if opt then
			RouteCost[Passport] = RouteCost[Passport] + (opt.Price or 0)
			activeOpts[#activeOpts+1] = {
				Item   = opt.Item,
				Min    = tonumber(opt.Min) or 1,
				Max    = tonumber(opt.Max) or 1,
				Chance = tonumber(opt.Chance) or 1
			}
		end
	end

	-- Se nada selecionado, assume todos
	if #activeOpts == 0 then
		for _, opt in ipairs(Route.List) do
			RouteCost[Passport] = RouteCost[Passport] + (opt.Price or 0)
			activeOpts[#activeOpts+1] = {
				Item   = opt.Item,
				Min    = tonumber(opt.Min) or 1,
				Max    = tonumber(opt.Max) or 1,
				Chance = tonumber(opt.Chance) or 1
			}
		end
	end

	-- Cobrança inicial (se houver custo)
	if RouteCost[Passport] > 0 then
		if not vRP.PaymentFull(Passport, RouteCost[Passport]) then
			TriggerClientEvent("Notify", source, "Rotas", "Saldo insuficiente para iniciar esta rota.", "vermelho", 6000)
			RouteCost[Passport] = nil
			return false
		end
	end

	ActiveRoutes[Passport] = { Route = Name, Items = Items or {} }
	RewardItems[Passport]  = activeOpts
	return true
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- DELIVER
-----------------------------------------------------------------------------------------------------------------------------------------
-- Cooldown server-side por passaporte (failsafe)
local _lastDeliverAt = {} -- [Passport] = ms

function Creative.Deliver()
    local src = source
    local Passport = vRP.Passport(src)
    if not Passport then return false end

    -- cooldown (700ms) para não duplicar por lag
    local now = GetGameTimer and GetGameTimer() or os.clock() * 1000
    local last = _lastDeliverAt[Passport] or 0
    if (now - last) < 700 then
        return false
    end
    _lastDeliverAt[Passport] = now

    local active = ActiveRoutes[Passport]
    if not active then return false end

    local routeName = active.Route
    local Route = Config[routeName]
    if not Route then return false end

    local options = RewardItems[Passport]
    if not options or #options == 0 then return false end

    -- sorteia UMA recompensa para este jogador nesta paragem
    local pick = RandByWeight(options)
    if not pick then return false end

    local minQ = math.max(1, tonumber(pick.Min) or 1)
    local maxQ = math.max(minQ, tonumber(pick.Max) or minQ)
    local baseAmount = math.random(minQ, maxQ)

    -- aplica boosts conforme a experiência deste jogador (se houver)
    local expTrack = Route.Experience and Route.Experience.Name or nil
    local currentExp = expTrack and (vRP.GetExperience(Passport, expTrack) or 0) or 0
    local finalAmount = ApplyBoosts(baseAmount, currentExp, Route.Experience and Route.Experience.Boosts or nil)

    -- entrega item
    vRP.GenerateItem(Passport, pick.Item, finalAmount, true)

    -- experiência (cap 100)
    if Route.Experience then
        local MaxExperience = 100
        local curr = vRP.GetExperience(Passport, Route.Experience.Name) or 0
        local add  = tonumber(Route.Experience.Amount) or 0
        local give = (curr + add <= MaxExperience) and add or (MaxExperience - curr)
        if give > 0 then
            vRP.PutExperience(Passport, Route.Experience.Name, give)
        end
    end

    -- avança SÓ o ponto deste jogador
    local isSequential = Route.Route and true or false
    TriggerClientEvent("routes:AdvancePoint", src, routeName, isSequential)

    return true
end


-----------------------------------------------------------------------------------------------------------------------------------------
-- FINISH
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Finish()
	local source = source
	local Passport = vRP.Passport(source)
	if not Passport then return false end

	if ActiveRoutes[Passport] then
		ActiveRoutes[Passport] = nil
		RewardItems[Passport]  = nil
		RouteCost[Passport]    = nil
		return true
	end

	return false
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Disconnect", function(Passport)
	if ActiveRoutes[Passport] then
		ActiveRoutes[Passport] = nil
		RewardItems[Passport]  = nil
		RouteCost[Passport]    = nil
	end
end)


-- força terminar sem passar pela NUI/tunnel (usado por outros recursos)
local function _forceFinishForSource(targetSrc)
    if not targetSrc or targetSrc <= 0 then return false end
    local Passport = vRP.Passport(targetSrc)
    if not Passport then return false end

    if ActiveRoutes[Passport] then
        ActiveRoutes[Passport] = nil
        RewardItems[Passport]  = nil
        RouteCost[Passport]    = nil
        -- manda limpar o lado client também
        TriggerClientEvent("routes:ResetClient", targetSrc)
        return true
    end
    -- mesmo sem rota ativa no server, garante que o client limpa
    TriggerClientEvent("routes:ResetClient", targetSrc)
    return false
end

-- EVENTO SERVER-SIDE para outros scripts: TriggerEvent("routes:ForceFinishServer", targetSrc)
RegisterNetEvent("routes:ForceFinishServer")
AddEventHandler("routes:ForceFinishServer", function(targetSrc)
    _forceFinishForSource(tonumber(targetSrc) or source)
end)

-- EXPORT opcional: exports["routes"]:ForceFinishBySource(targetSrc)
exports("ForceFinishBySource", function(targetSrc)
    return _forceFinishForSource(tonumber(targetSrc))
end)

-- mantém a API via Tunnel para o client (já tinhas)
function Creative.ForceFinish()
    local src = source
    return _forceFinishForSource(src)
end
