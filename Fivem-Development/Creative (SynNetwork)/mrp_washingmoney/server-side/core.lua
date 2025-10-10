--[[
  washing - Money Wash Standalone
  Author: syn
]]

local Tunnel = module("vrp","lib/Tunnel")
local Proxy  = module("vrp","lib/Proxy")
vRP   = Proxy.getInterface("vRP")
vRPC  = Tunnel.getInterface("vRP")

local Washing = {}
Tunnel.bindInterface("washing",Washing)
local vCLIENT = Tunnel.getInterface("washing")

-----------------------------------------------------------------------------------------------------------------------------------------
-- CONFIG
-----------------------------------------------------------------------------------------------------------------------------------------
-- Perdas
local LOSS_PUBLIC = 0.60
local LOSS_ORGS = {
	["Bahamas"] = 0.20,
	["Vanilla"] = 0.20,
	["Tequila"] = 0.20
}

-- VIP reduz perda (sobre a perda, não sobre o total)
-- 1=ouro, 2=prata, 3=bronze
local VIP_REDUCTION = { [1]=0.15, [2]=0.10, [3]=0.05 }


-- XP / Nível “Lavagem”
local XP_PER_1000    = 6      -- reforçado (trabalho com risco)
local LEVEL_STEP_XP  = 2000     -- XP por nível aprox
local LEVEL_LOSS_PER = 0.01     -- -1% perda por nível
local LEVEL_LOSS_CAP = 0.30     -- cap -30%

-- Polícia
local POLICE_ROLE   = "Policia"
local POLICE_NAME   = "Lavagem de Dinheiro"
local POLICE_WANTED = 60
local POLICE_CODE   = 31
local POLICE_COLOR  = 22
-- Risco base 20% (reduz com nível), mínimo absoluto 5%
local POLICE_BASE   = 0.45
local POLICE_MIN    = 0.15

-- Evento informante (5%) + Suborno (em item dollar)
local INFORMANT_CHANCE = 0.35
local BRIBE_MIN = 20000
local BRIBE_MAX = 35000

-- Combo bónus (extra em item dollar)
local COMBO_THRESHOLD = 3
local COMBO_BONUS_MIN = 10000
local COMBO_BONUS_MAX = 25000

-- Valores por ponto
local MIN_PER_WASH = 150000

-- Teto variável por nº de polícias por ponto:
-- 0→30k; 3→600k; 5→800k; 10+→1000k
local function MaxPerWashByCops(n)
	if n >= 10 then return 1000000 end
	if n >= 5  then return 800000 end
	if n >= 3  then return 600000 end
	return 400000
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- STATE
-----------------------------------------------------------------------------------------------------------------------------------------
local Combo = {}  -- [Passport] = streak (sem alerta)

-----------------------------------------------------------------------------------------------------------------------------------------
-- HELPERS
-----------------------------------------------------------------------------------------------------------------------------------------
local function getLevel(xp) return 1 + math.floor((xp or 0) / LEVEL_STEP_XP) end

local function levelReduction(level)
	local r = math.max(0,(level-1)) * LEVEL_LOSS_PER
	return (r > LEVEL_LOSS_CAP) and LEVEL_LOSS_CAP or r
end

local function isInAnyOrg(passport)
	for group,loss in pairs(LOSS_ORGS) do
		if vRP.HasGroup(passport,group) then
			return true, loss
		end
	end
	return false, nil
end

local function fmt(n)
	local s = tostring(math.floor((n or 0) + 0.5))
	local k; repeat s,k = s:gsub("^(-?%d+)(%d%d%d)", "%1.%2") until k==0
	return s
end

local function getCopsOnline()
	local list = vRP.NumPermission(POLICE_ROLE) or {}
	return #list
end

local function policeRiskByLevel(lvl)
	local eff = math.max(POLICE_MIN, POLICE_BASE - levelReduction(lvl)) -- 0.20 - redução por nível (cap 0.05)
	return math.floor(eff * 1000) -- CallPolice usa 0-1000
end

local function resetCombo(passport) Combo[passport] = 0 end
local function addCombo(passport) Combo[passport] = (Combo[passport] or 0) + 1; return Combo[passport] end

-----------------------------------------------------------------------------------------------------------------------------------------
-- LOG DISCORD (opcional)
-----------------------------------------------------------------------------------------------------------------------------------------
local function DiscordEmbed(channel, lines)
	if exports["discord"] and exports["discord"].Embed then
		local msg = table.concat(lines,"\n")
		exports["discord"]:Embed(channel, msg)
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- CORE: EXECUTA A LAVAGEM
-----------------------------------------------------------------------------------------------------------------------------------------
local function executeWash(Passport, source, amount, lvl, vipRed, orgLoss)
	-- perda base
	local baseLoss = orgLoss or LOSS_PUBLIC
	-- perda efetiva (nunca negativa)
	local effectiveLoss = math.max(0, baseLoss - vipRed - levelReduction(lvl))
	local multiplier = 1.0 - effectiveLoss

	-- remover sujo
	if not vRP.TakeItem(Passport,"dirtydollar",amount) then
		TriggerClientEvent("Notify",source,"Lavagem","Falha ao remover dinheiro sujo.","vermelho",5000)
		return false, "remove_fail"
	end

	-- pagar limpo em ITEM dollar
	local cleanPay = math.floor(amount * multiplier)
	if cleanPay > 0 then
		vRP.GenerateItem(Passport,"dollar",cleanPay,true)
	end

	-- XP
	local gainXp = math.floor((amount/1000) * XP_PER_1000)
	if gainXp > 0 and vRP.PutExperience then
		vRP.PutExperience(Passport,"Lavagem",25)
	end

-- Risco polícia + roll de probabilidade
local risk = policeRiskByLevel(lvl)          -- 0..1000 (20% base reduzida pelo nível)
local roll = math.random(0,999)              -- d1000

if roll < risk then
    -- ALERTA: só chama polícia quando a sorte falha
    if exports["vrp"] and exports["vrp"].CallPolice then
        exports["vrp"]:CallPolice({
            ["Source"]     = source,
            ["Passport"]   = Passport,
            ["Permission"] = POLICE_ROLE,
            ["Name"]       = POLICE_NAME,
            ["Percentage"] = risk,
            ["Wanted"]     = POLICE_WANTED,
            ["Code"]       = POLICE_CODE,
            ["Color"]      = POLICE_COLOR
        })
    end

    -- loga apenas quando realmente alertou
    DiscordEmbed("Lavagem", {
        "🚨 **ALERTA POLÍCIA (LAVAGEM)**",
        "",
        "🪪 **Passaporte:** `"..Passport.."`",
        "💵 **Valor Tentado:** `$"..fmt(amount).."`",
        "🎲 **Rolagem:** `"..roll.." / 1000`",
        "📈 **Risco:** `"..risk.."‰`",
        "🗓️ **Data & Hora:** `"..os.date("%d/%m/%Y %H:%M").."`"
    })
end


	-- Combo bónus (ITEM)
	local streak = addCombo(Passport)
	local comboBonus = 0
	if streak >= COMBO_THRESHOLD then
		comboBonus = math.random(COMBO_BONUS_MIN, COMBO_BONUS_MAX)
		vRP.GenerateItem(Passport,"dollar",comboBonus,true)
	end

	-- Feedback + log final
	local lossTxt = math.floor(effectiveLoss*100)
	local vipTxt  = (vipRed>0) and (" VIP -"..math.floor(vipRed*100).."%") or ""
	local lvlRed  = levelReduction(lvl)
	local lvlTxt  = (lvlRed>0) and (" Nível -"..math.floor(lvlRed*100).."%") or ""
	local orgTxt  = orgLoss and " (ORG)" or " (Público)"
	local invAmt  = vRP.InventoryItemAmount(Passport,"dirtydollar"); invAmt = (invAmt and invAmt[1]) or 0

	TriggerClientEvent("Notify",source,"Lavagem",
		string.format("Lavou %s sujo ➜ recebeu %s (item dollar).\nPerda final: %d%%%s%s%s.\nSujo restante: %s%s",
			fmt(amount), fmt(cleanPay), lossTxt, orgTxt, vipTxt, lvlTxt, fmt(invAmt),
			(comboBonus>0 and ("\nBónus combo: +"..fmt(comboBonus)) or "")),
	"verde",6500)

	DiscordEmbed("Lavagem", {
		"🧼 **LAVAGEM CONCLUÍDA**",
		"",
		"🪪 **Passaporte:** `"..Passport.."`",
		"💸 **Lavado (sujo):** `$"..fmt(amount).."`",
		"💵 **Recebido (item dollar):** `$"..fmt(cleanPay).."`",
		"📉 **Perda Final:** `"..lossTxt.."%%"..(orgTxt or "")..(vipTxt or "")..(lvlTxt or "").."`",
		"🔥 **Combo:** `"..streak.."`"..(comboBonus>0 and " | **Bónus:** `$"..fmt(comboBonus).."`" or ""),
		"🧾 **Sujo Restante:** `$"..fmt(invAmt).."`",
		"🗓️ **Data & Hora:** `"..os.date("%d/%m/%Y %H:%M").."`"
	})

	return true, invAmt <= 0
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- INÍCIO DE PONTO: MONTANTE, EVENTO INFORMANTE (vRP.Request COM FREEZE), EXECUÇÃO
-- retorna: "done", finished(bool) | "fail"
-----------------------------------------------------------------------------------------------------------------------------------------
function Washing.StartSpot(minVal, maxVal)
    local source   = source
    local Passport = vRP.Passport(source)
    if not Passport then return "fail" end

    minVal = tonumber(minVal) or MIN_PER_WASH
    maxVal = tonumber(maxVal) or MIN_PER_WASH*10

    -- sujo disponível
    local inv  = vRP.InventoryItemAmount(Passport,"dirtydollar")
    local have = (inv and inv[1]) or 0
    if have <= 0 then
        TriggerClientEvent("Notify",source,"Lavagem","Não tem mais dinheiro sujo, acabou o seu serviço.","amarelo",7000)
        return "done", true
    end

    -- teto por nº de polícias
    local cops = getCopsOnline()
    local cap  = MaxPerWashByCops(cops)
    maxVal = math.min(maxVal, cap)

    -- montante a tentar lavar
    local desired = math.random(minVal, maxVal)
    local amount  = math.min(desired, have)

    -- dados de VIP/Nível/Org
    local xp     = (vRP.GetExperience and vRP.GetExperience(Passport,"Lavagem")) or 0
    local lvl    = getLevel(xp)
    local vipRed = 0
    if vRP.HasGroup and vRP.HasGroup(Passport,"Premium") then
        local tier = (vRP.LevelPremium and vRP.LevelPremium(source)) or 1  -- 1=ouro, 2=prata, 3=bronze
        vipRed = VIP_REDUCTION[tier] or 0
    end
    local inOrg, orgLoss = isInAnyOrg(Passport)

    --  Evento: Informante (chance)
    if math.random() < INFORMANT_CHANCE then
        local bribe = math.random(BRIBE_MIN, BRIBE_MAX)

        -- 1ª abordagem (freeze durante o request)
        TriggerClientEvent("washing:FreezeVehicle",source,true)
        local ok = vRP.Request(
            source,
            "Informante",
            "Foste marcado! Queres <b>subornar</b> por <b>$"..fmt(bribe).."</b> para prosseguir discretamente?",
            15000
        )
        TriggerClientEvent("washing:FreezeVehicle",source,false)

        if ok then
            -- tenta pagar suborno: 1) item dollar  2) banco
            local bribePaid = false
            if vRP.TryGetItem(Passport,"dollar",bribe,true) then
                bribePaid = true
            elseif vRP.PaymentBank(Passport,bribe) then
                bribePaid = true
            end

            if bribePaid then
                TriggerClientEvent("Notify",source,"Lavagem","Suborno pago: $"..fmt(bribe)..". Prosseguir discretamente.","amarelo",5000)
                DiscordEmbed("Lavagem", {
                    "🕵️ **INFORMANTE – SUBORNO PAGO**",
                    "",
                    "🪪 **Passaporte:** `"..Passport.."`",
                    "💵 **Suborno:** `$"..fmt(bribe).."`",
                    "🗓️ **Data & Hora:** `"..os.date("%d/%m/%Y %H:%M").."`"
                })
                local done, finished = executeWash(Passport, source, amount, lvl, vipRed, orgLoss)
                return done and "done" or "fail", finished
            else
                TriggerClientEvent("Notify",source,"Lavagem","Não tens <b>dollar</b> nem saldo bancário suficiente para subornar!","vermelho",5000)
                -- segue para 2ª chance mais cara
            end
        end

        --  2ª CHANCE: suborno mais caro (penalidade por dizer "não")
        local bribe2 = math.floor(bribe * 1.5 + 0.5)
        TriggerClientEvent("washing:FreezeVehicle",source,true)
        local ok2 = vRP.Request(
            source,
            "Informante",
            "Última oportunidade! O informante exige <b>$"..fmt(bribe2).."</b>. Aceitas?",
            12000
        )
        TriggerClientEvent("washing:FreezeVehicle",source,false)

        if ok2 then
            local paid2 = false
            if vRP.TryGetItem(Passport,"dollar",bribe2,true) then
                paid2 = true
            elseif vRP.PaymentBank(Passport,bribe2) then
                paid2 = true
            end

            if paid2 then
                TriggerClientEvent("Notify",source,"Lavagem","Suborno (2ª chance) pago: $"..fmt(bribe2)..". Prosseguir discretamente.","amarelo",5000)
                DiscordEmbed("Lavagem", {
                    "🕵️ **INFORMANTE – SUBORNO PAGO (2ª CHANCE)**",
                    "",
                    "🪪 **Passaporte:** `"..Passport.."`",
                    "💵 **Suborno:** `$"..fmt(bribe2).."`",
                    "🗓️ **Data & Hora:** `"..os.date("%d/%m/%Y %H:%M").."`"
                })
                local done2, finished2 = executeWash(Passport, source, amount, lvl, vipRed, orgLoss)
                return done2 and "done" or "fail", finished2
            else
                TriggerClientEvent("Notify",source,"Lavagem","Ainda sem fundos para subornar. O informante chamou a polícia!","vermelho",6000)
            end
        end

        -- Recusa definitiva / sem fundos → alerta polícia, zera combo, termina ponto
        resetCombo(Passport)
        if exports["vrp"] and exports["vrp"].CallPolice then
            local risk = math.floor(POLICE_BASE * 1000) -- risco base (sem reduções)
            exports["vrp"]:CallPolice({
                ["Source"]     = source,
                ["Passport"]   = Passport,
                ["Permission"] = POLICE_ROLE,
                ["Name"]       = POLICE_NAME.." (Informante)",
                ["Percentage"] = risk,
                ["Wanted"]     = POLICE_WANTED,
                ["Code"]       = POLICE_CODE,
                ["Color"]      = POLICE_COLOR
            })
        end
        DiscordEmbed("Lavagem", {
            "⚠️ **INFORMANTE – RECUSA/SEM FUNDOS (APÓS 2ª CHANCE)**",
            "",
            "🪪 **Passaporte:** `"..Passport.."`",
            "💵 **Suborno Final Exigido:** `$"..fmt(bribe2).."`",
            "🚨 **Polícia alertada.**",
            "🗓️ **Data & Hora:** `"..os.date("%d/%m/%Y %H:%M").."`"
        })
        TriggerClientEvent("Notify",source,"Lavagem","O informante alertou a polícia. Sai do local!","vermelho",6500)
        return "done", false
    end

    -- Sem evento: lava direto
    local ok3, finished3 = executeWash(Passport, source, amount, lvl, vipRed, orgLoss)
    return ok3 and "done" or "fail", finished3
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- /SAIRTRABALHO INTEGRAÇÃO (placeholder do lado server)
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("washing:ForceEndService")
AddEventHandler("washing:ForceEndService",function() end)
