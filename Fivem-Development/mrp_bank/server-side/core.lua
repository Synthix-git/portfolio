-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
Creative = {}
Tunnel.bindInterface("bank",Creative)
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Active = {}
local Cooldown = 0

-- Helper seguro para formatar valores, usando a tua existente Dotted se houver.
local function fmt(n)
	if Dotted then return Dotted(n) end
	local s = tostring(parseInt(n or 0))
	return s:reverse():gsub("(%d%d%d)","%1."):reverse():gsub("^%.","")
end

local function fullName(Passport)
	return vRP.FullName(Passport) or ("Passaporte "..tostring(Passport))
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- REQUESTWANTED
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.requestWanted()
	local source = source
	local Passport = vRP.Passport(source)

	if Passport then
		if exports["hud"]:Wanted(Passport,source) then
			return false
		end
	end

	return true
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADACTIVES
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	while true do
		if os.time() >= Cooldown then
			Cooldown = os.time() + 3600
			vRP.Query("investments/Actives")
		end

		Wait(1000)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- HOME
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Home()
	local source = source
	local Passport = vRP.Passport(source)
	if Passport then
		local Yield = 0
		local Identity = vRP.Identity(Passport)

		local InvestmentCheck = vRP.Query("investments/Check",{ Passport = Passport })
		if InvestmentCheck[1] then
			Yield = InvestmentCheck[1]["Monthly"]
		end

		return {
			["yield"] = Yield,
			["cardnumber"] = "MRP 2567 4523 " .. (1000 + Passport), -- fix concatenação
			["balance"] = Identity["bank"],
			["transactions"] = Transactions(Passport),
			["dependents"] = Dependents(Passport)
		}
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- ADDDEPENDENTS
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.AddDependents(OtherPassport)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and not Active[Passport] and OtherPassport ~= Passport then
		Active[Passport] = true

		local Check = vRP.Query("dependents/Check",{ Passport = Passport, Dependent = OtherPassport })
		if not Check[1] then
			local OtherSource = vRP.Source(OtherPassport)
			if OtherSource then
				if vRP.Request(OtherSource,"Banco","<b>"..vRP.FullName(Passport).."</b> deseja convida-lo para sua lista de dependentes bancário, você aceita esse convite?") then
					vRP.Query("dependents/Add",{ Passport = Passport, Dependent = OtherPassport, Name = vRP.FullName(OtherPassport) })
					Active[Passport] = nil
					return vRP.FullName(OtherPassport)
				end
			end
		end

		Active[Passport] = nil
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- REMOVEDEPENDENTS
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.RemoveDependents(OtherPassport)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and not Active[Passport] then
		Active[Passport] = true

		local Consult = vRP.Query("dependents/Check",{ Passport = Passport, Dependent = OtherPassport })
		if Consult[1] then
			vRP.Query("dependents/Remove",{ Passport = Passport, Dependent = OtherPassport })
			Active[Passport] = nil
			return true
		end

		Active[Passport] = nil
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- TRANSACTIONHISTORIY
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.TransactionHistory()
	local source = source
	local Passport = vRP.Passport(source)
	if Passport then
		return Transactions(Passport,50)
	end
end


-----------------------------------------------------------------------------------------------------------------------------------------
-- DEPOSIT
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Deposit(Valuation)
    local source   = source
    local Passport = vRP.Passport(source)
    Valuation      = parseInt(Valuation)

    if Passport and not Active[Passport] and Valuation > 0 then
        Active[Passport] = true

        if vRP.ConsultItem(Passport,"dollar",Valuation) and vRP.TakeItem(Passport,"dollar",Valuation) then
            local saldoAntes = vRP.GetBank(Passport)

            vRP.GiveBank(Passport,Valuation)

            local saldoDepois = vRP.GetBank(Passport)

            -- LOG
            local name = fullName(Passport)
            exports["discord"]:Embed(
                "Banco",
                "💰 **Depósito** — "..name.." [#"..Passport.."]\n"..
                "📊 Saldo anterior: $"..fmt(saldoAntes).."\n"..
                "💵 Valor depositado: $"..fmt(Valuation).."\n"..
                "💳 Saldo final: $"..fmt(saldoDepois),
                source
            )
        end

        Active[Passport] = nil

        local retorno = {
            ["balance"]      = vRP.GetBank(Passport),
            ["transactions"] = Transactions(Passport)
        }
        return retorno
    end
end



-----------------------------------------------------------------------------------------------------------------------------------------
-- WITHDRAW
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Withdraw(Valuation)
    local source   = source
    local Passport = vRP.Passport(source)
    Valuation      = parseInt(Valuation)

    if Passport and not Active[Passport] and Valuation > 0 then
        Active[Passport] = true

        local saldoAntes = vRP.GetBank(Passport)

        if vRP.PaymentBank(Passport, Valuation) then
            vRP.GiveItem(Passport,"dollar",Valuation,true)

            -- 🔑 ler de novo o saldo depois do UPDATE no DB
            local saldoDepois = vRP.GetBank(Passport)

            -- LOG
            local name = fullName(Passport)
            exports["discord"]:Embed(
                "Banco",
                "🏧 **Levantamento** — "..name.." [#"..Passport.."]\n"..
                "📊 Saldo anterior: $"..fmt(saldoAntes).."\n"..
                "💵 Valor levantado: $"..fmt(Valuation).."\n"..
                "💳 Saldo final: $"..fmt(saldoDepois),
                source
            )

            Active[Passport] = nil

            local retorno = {
                ["balance"]      = vRP.GetBank(Passport),
                ["transactions"] = Transactions(Passport)
            }
            return retorno
		end
    end
end


-----------------------------------------------------------------------------------------------------------------------------------------
-- TRANSFER
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Transfer(OtherPassport,Valuation)
	local source = source
	local Passport = vRP.Passport(source)
	Valuation = parseInt(Valuation)

	if Passport and not Active[Passport] and OtherPassport ~= Passport and Valuation > 0 and not exports["bank"]:CheckFines(Passport) then
		Active[Passport] = true

		if vRP.Identity(OtherPassport) and vRP.PaymentBank(Passport,Valuation,true) then
			vRP.GiveBank(OtherPassport,Valuation)

			-- LOG: Transferência (duas linhas, com saldos de ambos)
			local nameFrom = fullName(Passport)
			local nameTo = fullName(OtherPassport)
			local saldoFrom = vRP.GetBank(Passport)
			local saldoTo = vRP.GetBank(OtherPassport)
			exports["discord"]:Embed("Banco",
				"🔄 **Transferência** — "..nameFrom.." [#"..Passport.."] transferiu $"..fmt(Valuation).." para "..nameTo.." [#"..OtherPassport.."]\n"..
				"💳 Saldo final remetente: $"..fmt(saldoFrom),
			source)
		end

		Active[Passport] = nil
	end

	return {
		["balance"] = vRP.Identity(Passport)["bank"],
		["transactions"] = Transactions(Passport)
	}
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- TRANSACTIONS
-----------------------------------------------------------------------------------------------------------------------------------------
function Transactions(Passport,Limit)
	local Transaction = {}
	local TransactionList = vRP.Query("transactions/List",{ Passport = Passport, Limit = Limit or 4 })
	if TransactionList[1] then
		for _,v in pairs(TransactionList) do
			Transaction[#Transaction + 1] = {
				["type"] = v["Type"],
				["date"] = v["Date"],
				["value"] = v["Value"],
				["balance"] = v["Balance"]
			}
		end
	end
	return Transaction
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- DEPENDENTS
-----------------------------------------------------------------------------------------------------------------------------------------
function Dependents(Passport)
	local Dependents = {}
	local DependentList = vRP.Query("dependents/List",{ Passport = Passport })
	if DependentList[1] then
		for _,v in pairs(DependentList) do
			Dependents[#Dependents + 1] = {
				["name"] = v["Name"],
				["passport"] = v["Dependent"]
			}
		end
	end
	return Dependents
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- FINES
-----------------------------------------------------------------------------------------------------------------------------------------
function Fines(Passport)
	local Fines = {}
	local FineList = vRP.Query("fines/List",{ Passport = Passport })
	if FineList[1] then
		for _,v in pairs(FineList) do
			Fines[#Fines + 1] = {
				["id"] = v["id"],
				["name"] = v["Name"],
				["value"] = v["Value"],
				["date"] = v["Date"],
				["hour"] = v["Hour"],
				["message"] = v["Message"]
			}
		end
	end
	return Fines
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- FINELIST
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.FineList()
	local source = source
	local Passport = vRP.Passport(source)
	if Passport then
		return Fines(Passport)
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHECKFINES
-----------------------------------------------------------------------------------------------------------------------------------------
exports("CheckFines",function(Passport)
	if Passport and vRP.Query("fines/List",{ Passport = Passport })[1] then
		return true
	end
	return false
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- FINEPAYMENT
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.FinePayment(Number)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and not Active[Passport] then
		Active[Passport] = true

		local Fine = vRP.Query("fines/Check",{ Passport = Passport, id = Number })
		if Fine[1] then
			if vRP.PaymentBank(Passport,Fine[1]["Value"]) then
				vRP.Query("fines/Remove",{ Passport = Passport, id = Number })
				-- LOG: Pagamento de Multa
				local name = fullName(Passport)
				local saldo = vRP.GetBank(Passport)
				exports["discord"]:Embed("Banco","🚨 **Pagamento de Multa** — "..name.." [#"..Passport.."] pagou $"..fmt(Fine[1]["Value"]).."\n💳 Saldo final: $"..fmt(saldo),source)
				Active[Passport] = nil
				return true
			end
		end

		Active[Passport] = nil
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- FINEPAYMENTALL
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.FinePaymentAll()
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and not Active[Passport] then
		Active[Passport] = true

		local FineList = vRP.Query("fines/List",{ Passport = Passport })
		if FineList[1] then
			local total = 0
			for _,v in pairs(FineList) do
				total = total + parseInt(v["Value"])
			end

			if total > 0 and vRP.PaymentBank(Passport,total) then
				for _,v in pairs(FineList) do
					vRP.Query("fines/Remove",{ Passport = Passport, id = v["id"] })
				end
				-- LOG: Pagamento de Multas (todas)
				local name = fullName(Passport)
				local saldo = vRP.GetBank(Passport)
				exports["discord"]:Embed("Banco","🚨 **Pagamento de Multas (todas)** — "..name.." [#"..Passport.."] pagou $"..fmt(total).."\n💳 Saldo final: $"..fmt(saldo),source)

				Active[Passport] = nil
				return Fines(Passport)
			end
		end

		Active[Passport] = nil
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- TAXS
-----------------------------------------------------------------------------------------------------------------------------------------
function Taxs(Passport)
	local Taxs = {}
	local TaxList = vRP.Query("taxs/List",{ Passport = Passport })
	if TaxList[1] then
		for _,v in pairs(TaxList) do
			Taxs[#Taxs + 1] = {
				["id"] = v["id"],
				["name"] = v["Name"],
				["value"] = v["Value"],
				["date"] = v["Date"],
				["hour"] = v["Hour"],
				["message"] = v["Message"]
			}
		end
	end
	return Taxs
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- TAXLIST
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.TaxList()
	local source = source
	local Passport = vRP.Passport(source)
	if Passport then
		return Taxs(Passport)
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- TAXPAYMENT
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.TaxPayment(Number)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and not Active[Passport] then
		Active[Passport] = true

		local Tax = vRP.Query("taxs/Check",{ Passport = Passport, id = Number })
		if Tax[1] then
			if vRP.PaymentBank(Passport,Tax[1]["Value"]) then
				vRP.Query("taxs/Remove",{ Passport = Passport, id = Number })
				-- LOG: Pagamento de Imposto
				local name = fullName(Passport)
				local saldo = vRP.GetBank(Passport)
				exports["discord"]:Embed("Banco","📑 **Pagamento de Imposto** — "..name.." [#"..Passport.."] pagou $"..fmt(Tax[1]["Value"]).."\n💳 Saldo final: $"..fmt(saldo),source)
				Active[Passport] = nil
				return true
			end
		end

		Active[Passport] = nil
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVOICELIST
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.InvoiceList()
	local source = source
	local Passport = vRP.Passport(source)
	if Passport then
		return Invoices(Passport)
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- MAKEINVOICE
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.MakeInvoice(OtherPassport,Valuation,Reason)
	local source = source
	local Passport = vRP.Passport(source)
	Valuation = parseInt(Valuation)

	if Passport and not Active[Passport] and OtherPassport ~= Passport and Valuation > 0 then
		Active[Passport] = true

		local OtherSource = vRP.Source(OtherPassport)
		if OtherSource then
			if vRP.Request(OtherSource,"Banco","<b>"..vRP.FullName(Passport).."</b> lhe enviou uma fatura de <b>R$"..fmt(Valuation).."</b>, deseja aceita-la?") then
				vRP.Query("invoices/Add",{ Passport = OtherPassport, Received = Passport, Type = "received", Reason = Reason, Holder = vRP.FullName(Passport), Value = Valuation })
				vRP.Query("invoices/Add",{ Passport = Passport, Received = OtherPassport, Type = "sent",     Reason = Reason, Holder = "Você",                   Value = Valuation })
				Active[Passport] = nil
				return Invoices(Passport)
			end
		end

		Active[Passport] = nil
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVOICEPAYMENT
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.InvoicePayment(Number)
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and not Active[Passport] then
		Active[Passport] = true

		local Invoice = vRP.Query("invoices/Check",{ id = Number })
		if Invoice[1] then
			-- Valida que a fatura pertence ao jogador e é "received"
			if Invoice[1]["Passport"] == Passport and Invoice[1]["Type"] == "received" then
				if vRP.PaymentBank(Passport,Invoice[1]["Value"]) then
					vRP.GiveBank(Invoice[1]["Received"],Invoice[1]["Value"])
					vRP.Query("invoices/Remove",{ id = Number })

					-- LOG: Pagamento de Fatura
					local name = fullName(Passport)
					local saldo = vRP.GetBank(Passport)
					exports["discord"]:Embed("Banco","🧾 **Pagamento de Fatura** — "..name.." [#"..Passport.."] pagou $"..fmt(Invoice[1]["Value"]).."\n💳 Saldo final: $"..fmt(saldo),source)

					Active[Passport] = nil
					return true
				end
			end
		end

		Active[Passport] = nil
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVOICES
-----------------------------------------------------------------------------------------------------------------------------------------
function Invoices(Passport)
	local Invoices = {}
	local InvoiceList = vRP.Query("invoices/List",{ Passport = Passport })
	if InvoiceList[1] then
		for _,v in pairs(InvoiceList) do
			local Type = v["Type"]

			if not Invoices[Type] then
				Invoices[Type] = {}
			end

			Invoices[Type][#Invoices[Type] + 1] = {
				["id"] = v["id"],
				["reason"] = v["Reason"],
				["holder"] = v["Holder"],
				["value"] = v["Value"]
			}
		end
	end
	return Invoices
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVESTMENTS
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Investments()
	local source = source
	local Passport = vRP.Passport(source)
	if Passport then
		local Total,Brute,Liquid,Deposit = 0,0,0,0
		local InvestmentCheck = vRP.Query("investments/Check",{ Passport = Passport })
		if InvestmentCheck[1] then
			Total = InvestmentCheck[1]["Deposit"] + InvestmentCheck[1]["Liquid"]
			Brute = InvestmentCheck[1]["Deposit"]
			Liquid = InvestmentCheck[1]["Liquid"]
			Deposit = InvestmentCheck[1]["Deposit"]
		end

		return { ["total"] = Total, ["brute"] = Brute, ["liquid"] = Liquid, ["deposit"] = Deposit }
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVEST
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.Invest(Valuation)
	local source = source
	local Passport = vRP.Passport(source)
	Valuation = parseInt(Valuation)

	if Passport and not Active[Passport] and Valuation > 0 then
		Active[Passport] = true

		if vRP.PaymentBank(Passport,Valuation,true) then
			local InvestmentCheck = vRP.Query("investments/Check",{ Passport = Passport })
			if InvestmentCheck[1] then
				vRP.Query("investments/Invest",{ Passport = Passport, Value = Valuation })
			else
				vRP.Query("investments/Add",{ Passport = Passport, Deposit = Valuation })
			end

			Active[Passport] = nil
			return true
		end

		Active[Passport] = nil
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- INVESTRESCUE
-----------------------------------------------------------------------------------------------------------------------------------------
function Creative.InvestRescue()
	local source = source
	local Passport = vRP.Passport(source)
	if Passport and not Active[Passport] then
		Active[Passport] = true

		local InvestmentCheck = vRP.Query("investments/Check",{ Passport = Passport })
		if InvestmentCheck[1] then
			local Valuation = InvestmentCheck[1]["Deposit"] + InvestmentCheck[1]["Liquid"]
			vRP.Query("investments/Remove",{ Passport = Passport })
			vRP.GiveBank(Passport,Valuation)

			Active[Passport] = nil
			return true
		end

		Active[Passport] = nil
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- ADDTAXS (Compatível: assinatura antiga e nova)
-----------------------------------------------------------------------------------------------------------------------------------------
-- Nova (preferida): AddTaxs(Passport, Valuation, Reason, Name, chargeNow)
-- Antiga (legacy) : AddTaxs(Passport, source, Name, Valuation, Message) -> calcula % por premium e cria taxa
exports("AddTaxs",function(Passport, a, b, c, d)
	if not Passport then return end

	-- Detectar forma:
	-- Legacy: a=source(number), b=Name(string), c=Valuation(number), d=Message(string/nil)
	-- Nova  : a=Valuation(number), b=Reason(string), c=Name(string), d=chargeNow(boolean/nil)
	local isLegacy = (type(a) == "number" and type(b) == "string" and type(c) == "number")

	if isLegacy then
		local src = a
		local Name = b
		local baseVal = parseInt(c)
		local Message = d

		-- Mantém comportamento antigo: calcular % pela hierarquia premium
		local finalVal
		if vRP.UserPremium(Passport) then
			local hierarchy = vRP.LevelPremium(vRP.Source(Passport) or src) -- tenta obter source pelo Passport
			if hierarchy == 1 then
				finalVal = baseVal * 0.0125
			elseif hierarchy == 2 then
				finalVal = baseVal * 0.0250
			else
				finalVal = baseVal * 0.0375
			end
		else
			finalVal = baseVal * 0.05
		end

		vRP.Query("taxs/Add",{ Passport = Passport, Name = Name, Date = os.date("%d/%m/%Y"), Hour = os.date("%H:%M"), Value = parseInt(finalVal), Message = Message })
		return
	else
		-- Nova assinatura
		local Valuation = parseInt(a)
		local Reason = b
		local Name = c
		local chargeNow = d and true or false

		if Valuation <= 0 then return end

		if chargeNow then
			-- Cobra já e NÃO cria pendência em taxs (evita pagar duas vezes)
			vRP.PaymentBank(Passport,Valuation,true)
		else
			-- Apenas cria a "fatura" (pendência)
			vRP.Query("taxs/Add",{ Passport = Passport, Name = Name or "Taxa", Date = os.date("%d/%m/%Y"), Hour = os.date("%H:%M"), Value = Valuation, Message = Reason or "" })
		end
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- ADDTRANSACTIONS (atenção a duplicados pelo core)
-----------------------------------------------------------------------------------------------------------------------------------------
exports("AddTransactions",function(Passport,Type,Valuation)
	-- Mantém para compatibilidade, mas atenção: o core já regista transações em GiveBank/RemoveBank/PaymentBank
	vRP.Query("transactions/Add",{ Passport = Passport, Type = Type, Date = os.date("%d/%m/%Y"), Value = Valuation, Balance = vRP.GetBank(Passport) })
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- ADDFINES
-----------------------------------------------------------------------------------------------------------------------------------------
exports("AddFines",function(Passport,OtherPassport,Valuation,Message)
	vRP.Query("fines/Add",{ Passport = Passport, Name = vRP.FullName(OtherPassport), Date = os.date("%d/%m/%Y"), Hour = os.date("%H:%M"), Value = Valuation, Message = Message })
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Disconnect",function(Passport)
	if Active[Passport] then
		Active[Passport] = nil
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- EXPORTS
-----------------------------------------------------------------------------------------------------------------------------------------
exports("Taxs",Taxs)
exports("Fines",Fines)
exports("Invoices",Invoices)
exports("Dependents",Dependents)
exports("Transactions",Transactions)


-- server do resource "bank"
exports("GetCachedBalance", function(Passport)
    local id = vRP.Identity(Passport)
    return id and id.bank or 0
end)
