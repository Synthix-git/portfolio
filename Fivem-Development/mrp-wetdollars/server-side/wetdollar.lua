--[[
	wetdollar - server-side/core.lua (MODO ZONAS FIXAS)
	- Valida entrada em HeatZone (centro+raio).
	- Inicia sessão 1 min; jogador tem de permanecer dentro da zona.
	- Converte wet -> dry com perdas; notifica só se secou; logs "Economia".
]]

local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")
vRP = Proxy.getInterface("vRP")

local Config = WETMONEY_CONFIG or {}

--  Tabelas runtime 
local Sessions = {} -- [Passport] = { id, src, startedAt, zoneIndex }
local Cooldown = {} -- [Passport] = os.time()

--  Utils 
local function now()
	return os.time()
end

local function randomLossPercent(minp, maxp)
	local a, b = math.floor(minp or 2), math.floor(maxp or 8)
	if a < 0 then
		a = 0
	end
	if b < a then
		b = a
	end
	return math.random(a, b)
end

local function getZone(idx)
	local z = (Config.HeatZones or {})[idx]
	if not z then
		return nil
	end
	return { center = z.center, radius = z.radius or 3.0, name = z.name or ("Zona #%d"):format(idx) }
end

-- Converte o retorno do InventoryItemAmount para número (robusto a várias versões vRP)
local function getAmount(passport, item)
	local ret = 0
	if vRP.InventoryItemAmount then
		local ok, val = pcall(vRP.InventoryItemAmount, passport, item)
		if ok then
			if type(val) == "number" then
				return val
			elseif type(val) == "table" then
				-- tenta campos comuns em bases PT/BR
				return tonumber(val.amount or val.qtd or val.quantity or val.count or val.value or val[1]) or 0
			else
				return tonumber(val) or 0
			end
		end
	end
	return ret
end

-- Converte qualquer valor para número (suporta tabelas de várias bases)
local function toNum(v)
	if type(v) == "number" then
		return v
	end
	if type(v) == "string" then
		return tonumber(v) or 0
	end
	if type(v) == "table" then
		return tonumber(v.amount or v.qtd or v.quantity or v.count or v.value or v.total or v[1]) or 0
	end
	return 0
end

-- Lê a quantidade do item no inventário, devolvendo SEMPRE número
local function getAmount(passport, item)
	if not vRP.InventoryItemAmount then
		return 0
	end
	local ok, val = pcall(vRP.InventoryItemAmount, passport, item)
	if not ok then
		return 0
	end
	return toNum(val)
end

--  Fluxo ZONAS 

-- pedido do client para iniciar secagem numa zona
RegisterNetEvent("wetmoney:TryActiveDryZone")
AddEventHandler("wetmoney:TryActiveDryZone", function(zoneIndex)
	local src = source
	if not src then
		return
	end

	local Passport = vRP.Passport(src)
	if not Passport then
		return
	end

	if not (Config.UseZonesOnly and (Config.HeatZones and #Config.HeatZones > 0)) then
		TriggerClientEvent("Notify", src, "Conforto", "Sem zonas de calor ativas.", "vermelho", 3000)
		return
	end

	local z = getZone(zoneIndex)
	if not z then
		TriggerClientEvent("Notify", src, "Conforto", "Zona de calor inválida.", "vermelho", 3000)
		return
	end

	-- Cooldown
	local last = Cooldown[Passport] or 0
	if now() - last < (Config.Active.CooldownSec or 30) then
		TriggerClientEvent(
			"Notify",
			src,
			"Dinheiro",
			"Aguarda um pouco antes de <b>secar novamente</b>.",
			"amarelo",
			3000
		)
		return
	end

	if Sessions[Passport] then
		TriggerClientEvent("Notify", src, "Dinheiro", "Já estás a <b>secar dinheiro</b>.", "amarelo", 3000)
		return
	end

	-- proximidade à zona
	local ped = GetPlayerPed(src)
	local pcoords = GetEntityCoords(ped)
	if #(pcoords - z.center) > z.radius then
		TriggerClientEvent("Notify", src, "Conforto", "Aproxima-te mais da <b>zona de calor</b>.", "amarelo", 3000)
		return
	end

	-- Inventário: tem dinheiro molhado?
	local wetCleanAmt = getAmount(Passport, Config.Items.WetClean)
	local wetDirtyAmt = getAmount(Passport, Config.Items.WetDirty)

	if (wetCleanAmt + wetDirtyAmt) <= 0 then
		TriggerClientEvent("Notify", src, "Dinheiro", "Não tens <b>dinheiro molhado</b>.", "amarelo", 3000)
		return
	end

	-- Cria sessão
	local sid = string.format("%d-%d", Passport, math.random(100000, 999999))
	Sessions[Passport] = { id = sid, src = src, startedAt = now(), zoneIndex = zoneIndex }

	-- Inicia client
	TriggerClientEvent("wetmoney:ActiveDry:Start", src, sid, Config.Active.TimeMs or 60000, zoneIndex)
end)

-- abort por cancel (saiu da zona, caiu, etc.)
RegisterNetEvent("wetmoney:ActiveDry:Abort")
AddEventHandler("wetmoney:ActiveDry:Abort", function(sid, _reason)
	local src = source
	if not src then
		return
	end
	local Passport = vRP.Passport(src)
	if not Passport then
		return
	end

	local sess = Sessions[Passport]
	if not sess or sess.id ~= sid then
		return
	end

	Sessions[Passport] = nil
	TriggerClientEvent("wetmoney:ActiveDry:Stop", src)
end)

-- terminar com sucesso
RegisterNetEvent("wetmoney:ActiveDry:Finish")
AddEventHandler("wetmoney:ActiveDry:Finish", function(sid)
	local src = source
	if not src then
		return
	end

	local Passport = vRP.Passport(src)
	if not Passport then
		return
	end

	local sess = Sessions[Passport]
	if not sess or sess.id ~= sid then
		TriggerClientEvent("wetmoney:ActiveDry:Stop", src)
		return
	end

	-- fecha sessão cedo para evitar duplicadas
	Sessions[Passport] = nil

	local z = getZone(sess.zoneIndex)
	if not z then
		TriggerClientEvent("wetmoney:ActiveDry:Stop", src)
		return
	end

	-- Revalida: tem de estar dentro da zona ao terminar
	local ped = GetPlayerPed(src)
	local pcoords = GetEntityCoords(ped)
	if #(pcoords - z.center) > z.radius then
		TriggerClientEvent("wetmoney:ActiveDry:Stop", src)
		return
	end

	-- Cooldown
	Cooldown[Passport] = now()

	-- ==== Conversão (robusto a retornos em tabela) ====
	local wetCleanAmt = toNum(getAmount(Passport, Config.Items.WetClean))
	local wetDirtyAmt = toNum(getAmount(Passport, Config.Items.WetDirty))

	local maxPerUse = toNum(Config.Active.MaxPerUse or 0)
	local toDryClean = toNum(wetCleanAmt)
	local toDryDirty = toNum(wetDirtyAmt)

	if maxPerUse > 0 then
		local remaining = maxPerUse
		if toDryDirty > remaining then
			toDryDirty = remaining
			remaining = 0
			toDryClean = 0
		else
			remaining = remaining - toDryDirty
			if toDryClean > remaining then
				toDryClean = remaining
			end
		end
	end

	local totalDryInput = toNum(toDryClean + toDryDirty)
	if totalDryInput <= 0 then
		TriggerClientEvent("wetmoney:ActiveDry:Stop", src)
		return
	end

	local lossPct = math.floor(
		toNum(Config.Active.LossMin)
			+ math.random(0, math.max(0, toNum(Config.Active.LossMax) - toNum(Config.Active.LossMin)))
	)
	local lossClean = math.floor((toDryClean * lossPct) / 100)
	local lossDirty = math.floor((toDryDirty * lossPct) / 100)

	local finalClean = math.max(0, toDryClean - lossClean)
	local finalDirty = math.max(0, toDryDirty - lossDirty)

	local removedClean, removedDirty = 0, 0

-- limpa e gera (LIMPO)
do
    local have = toNum(getAmount(Passport, Config.Items.WetClean))
    local t = math.min(have, toDryClean)
    if t > 0 then
        if vRP.TakeItem(Passport, Config.Items.WetClean, t, true) then
            removedClean = t
            local fin = math.max(0, t - math.floor((t * lossPct) / 100))
            if fin > 0 then
                vRP.GenerateItem(Passport, Config.Items.DryClean, fin, true)
            end
        end
    end
end

-- limpa e gera (SUJO)
do
    local have2 = toNum(getAmount(Passport, Config.Items.WetDirty))
    local t2 = math.min(have2, toDryDirty)
    if t2 > 0 then
        if vRP.TakeItem(Passport, Config.Items.WetDirty, t2, true) then
            removedDirty = t2
            local fin2 = math.max(0, t2 - math.floor((t2 * lossPct) / 100))
            if fin2 > 0 then
                vRP.GenerateItem(Passport, Config.Items.DryDirty, fin2, true)
            end
        end
    end
end


	local driedTotal = math.max(0, toNum(finalClean + finalDirty))
	local lostTotal = math.max(0, toNum(removedClean + removedDirty) - driedTotal)
	local stillWet = math.max(0, toNum(wetCleanAmt - removedClean) + toNum(wetDirtyAmt - removedDirty))

	TriggerClientEvent("wetmoney:ActiveDry:Stop", src)

	if driedTotal > 0 then
		TriggerClientEvent(
			"Notify",
			src,
			"Dinheiro",
			("<b>Conseguiste recuperar %s $</b> de dinheiro molhado (perdeste %s $ no processo)."):format(
				driedTotal,
				lostTotal
			),
			"verde",
			5500
		)
	end

	-- (se tiveres logs Discord, mantém como estava; usa valores numéricos acima)

	-- Logs Discord (opcional)
	if exports["discord"] and exports["discord"].Embed then
		local title = "🔥 Secagem (Zona Fixa)"
		local msg = ("**Passaporte:** `%s`\n**Seco:** `%s $`\n**Perdido:** `%s $` (`%d%%`)\n**Restante Molhado:** `%s $`\n**Zona:** `%s`"):format(
			Passport,
			driedTotal,
			lostTotal,
			lossPct,
			stillWet,
			z.name or tostring(sess.zoneIndex)
		)
		exports["discord"]:Embed("Economia", ("**%s**\n%s"):format(title, msg), src)
	end
end)
