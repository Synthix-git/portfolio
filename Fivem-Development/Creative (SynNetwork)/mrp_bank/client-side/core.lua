-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRP = Proxy.getInterface("vRP")
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
vSERVER = Tunnel.getInterface("bank")
-----------------------------------------------------------------------------------------------------------------------------------------
-- LOCATION (pontos simples antigos — mantidos)
-----------------------------------------------------------------------------------------------------------------------------------------
local Location = {
	vec3(149.64,-1041.36,29.59),
	vec3(313.95,-279.74,54.39),
	vec3(-351.2,-50.57,49.26),
	vec3(-2961.85,482.87,15.92),
	vec3(1175.09,2707.53,38.31),
	vec3(-1212.37,-331.37,38.0),
	vec3(-112.86,6470.46,31.85)
}

-----------------------------------------------------------------------------------------------------------------------------------------
-- BANK BRANCHES (balcões) + BLIPS (reintroduzido)
-----------------------------------------------------------------------------------------------------------------------------------------
local BankBranches = {
	{ blip = vec3(150.00,-1040.0,29.37), open = vec3(147.60,-1035.76,29.34), h = 340.0, name = "Banco Fleeca" },
	{ blip = vec3(150.00,-1040.0,29.37), open = vec3(149.93,-1040.74,29.37), h = 340.0, name = "Banco Fleeca" },
	{ blip = vec3(150.00,-1040.0,29.37), open = vec3(145.94,-1035.19,29.34), h = 340.0, name = "Banco Fleeca" },
	{ blip = vec3(-351.54,-49.52,49.04), open = vec3(-351.02,-54.10,49.04), h = 340.0, name = "Banco Fleeca" },
	{ blip = vec3(314.23,-278.88,54.17), open = vec3(311.12,-284.35,54.17), h = 340.0, name = "Banco Fleeca" },
	{ blip = vec3(-1212.98,-330.84,37.78), open = vec3(-1211.93,-334.89,37.78), h = 30.0,  name = "Banco Fleeca" },
	{ blip = vec3(-2962.60,482.17,15.70), open = vec3(-2961.14,482.95,15.70), h = 90.0,  name = "Banco Fleeca" },
	{ blip = vec3(-295.35,6200.68,31.49), open = vec3(-295.04,6200.46,31.49), h = 135.0, name = "Banco Fleeca" },
	{ blip = vec3(1176.02,2706.64,38.09), open = vec3(1175.07,2708.15,38.09), h = 180.0, name = "Banco Fleeca" },
	{ blip = vec3(235.12,216.84,106.29), open = vec3(247.66,224.72,106.29), h = 160.0, name = "Banco Pacific" }
}

-----------------------------------------------------------------------------------------------------------------------------------------
-- ATM MODELS (reintroduzido)
-----------------------------------------------------------------------------------------------------------------------------------------
local AtmModels = { `prop_atm_01`, `prop_atm_02`, `prop_atm_03`, `prop_fleeca_atm` }

-----------------------------------------------------------------------------------------------------------------------------------------
-- ELETRONIC LOCATIONS (para validação do roubo)
-----------------------------------------------------------------------------------------------------------------------------------------
local EletronicLocations = {
	["1"]  = { Coords = vec4(33.19,-1348.80,29.49,179.99) },
	["2"]  = { Coords = vec4(2559.05,389.47,108.62,267.71) },
	["3"]  = { Coords = vec4(1153.11,-326.90,69.20,100.00) },
	["4"]  = { Coords = vec4(-718.26,-915.71,19.21,90.00) },
	["5"]  = { Coords = vec4(-57.40,-1751.74,29.42,49.98) },
	["6"]  = { Coords = vec4(380.65,322.84,103.56,165.88) },
	["7"]  = { Coords = vec4(-3240.02,1008.54,12.83,265.07) },
	["8"]  = { Coords = vec4(1735.01,6410.00,35.03,153.64) },
	["9"]  = { Coords = vec4(540.22,2671.68,42.15,7.49) },
	["10"] = { Coords = vec4(1968.39,3743.07,32.34,210.00) },
	["11"] = { Coords = vec4(2683.59,3286.30,55.24,240.87) },
	["12"] = { Coords = vec4(1703.31,4934.05,42.06,324.99) },
	["13"] = { Coords = vec4(-1827.68,784.46,138.31,132.46) },
	["14"] = { Coords = vec4(-3040.20,593.29,7.90,287.75) }
}

-----------------------------------------------------------------------------------------------------------------------------------------
-- UTIL (distância ao ponto eletrónico mais próximo para roubo)
-----------------------------------------------------------------------------------------------------------------------------------------
local function GetNearestEletronicIdx(maxDist)
	maxDist = maxDist or 3.0
	local ped = PlayerPedId()
	local p = GetEntityCoords(ped)
	local bestIdx, bestDst = nil, 9999.0
	for idx, data in pairs(EletronicLocations) do
		local c = data.Coords
		local d = #(p - vec3(c.x, c.y, c.z))
		if d < bestDst then bestDst = d bestIdx = idx end
	end
	if bestIdx and bestDst <= maxDist then return tonumber(bestIdx), bestDst end
	return nil, bestDst
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADLOCATION (pontos simples antigos com target: mantidos)
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	for Number,v in pairs(Location) do
		exports["target"]:AddCircleZone("Bank:"..Number,v,1.0,{
			name = "Bank:"..Number,
			heading = 0.0,
			useZ = true
		},{
			Distance = 1.75,
			options = {
				{ event = "Bank", label = "Abrir", tunnel = "client" }
			}
		})
	end
end)

--------------------------------------------------------------------------------------------------------------------------------------------
----- TARGET NAS AGÊNCIAS (branches) + fallback sem target
--------------------------------------------------------------------------------------------------------------------------------------------
-- CreateThread(function()
-- 	local ok = pcall(function() return exports["target"] and exports["target"].AddCircleZone ~= nil end)
-- 	for i, b in ipairs(BankBranches) do
-- 		local id = ("BankBranch:%s"):format(i)
-- 		if ok then
-- 			exports["target"]:AddCircleZone(id, b.open, 0.85, { name = id, useZ = true },{
-- 				Distance = 1.75,
-- 				options = { { event = "Bank", label = "Abrir Banco", tunnel = "client" } }
-- 			})
-- 		else
-- 			CreateThread(function()
-- 				local radius = 1.5
-- 				while true do
-- 					local ped = PlayerPedId()
-- 					local p = GetEntityCoords(ped)
-- 					local d = #(p - b.open)
-- 					if d <= 10.0 then
-- 						DrawMarker(2,b.open.x,b.open.y,b.open.z+0.05,0.0,0.0,0.0,0.0,0.0,0.0,0.3,0.3,0.3,0,255,0,150,0,0,0,0)
-- 						if d <= radius then
-- 							SetTextComponentFormat("STRING")
-- 							AddTextComponentString("~g~E~w~ Abrir Banco")
-- 							DisplayHelpTextFromStringLabel(0,false,true,-1)
-- 							if IsControlJustPressed(0,38) then TriggerEvent("Bank") end
-- 						end
-- 					end
-- 					Wait(0)
-- 				end
-- 			end)
-- 		end
-- 	end
-- end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- TARGET: ATMs com opção Roubar
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	local ok = pcall(function() return exports["target"] and exports["target"].AddTargetModel ~= nil end)
	if ok then
		exports["target"]:AddTargetModel(AtmModels, {
			options = {
				{ event = "Bank",        label = "Abrir",  tunnel = "client" },
				{ event = "bank:RobAtm", label = "Roubar", tunnel = "client" }
			},
			Distance = 1.75
		})
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- ROUBO ATM (chama o teu outro script)
-----------------------------------------------------------------------------------------------------------------------------------------
local RobCooldown = 0
RegisterNetEvent("bank:RobAtm")
AddEventHandler("bank:RobAtm", function()
	local now = GetGameTimer()
	if now - RobCooldown < 2000 then return end
	RobCooldown = now

	local number = GetNearestEletronicIdx(3.0)
	if not number then
		TriggerEvent("Notify","Atenção","Este ATM não está num ponto válido de roubo.","amarelo",4000)
		return
	end

	TriggerEvent("Notify","Roubo","A tentar assaltar o ATM...","amarelo",2000)
	-- Integra com o teu sistema de roubos “single”:
	TriggerServerEvent("inventory:RobberySingle", number, "Eletronic")
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- ABRIR BANCO (com bloqueio por procurado via server.requestWanted)
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Bank",function()
	SetNuiFocus(true,true)
	TransitionToBlurred(1000)
	TriggerEvent("hud:Active",false)
	SendNUIMessage({ Action = "Open", name = LocalPlayer["state"]["Name"] })
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- CLOSE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Close",function(Data,Callback)
	SetNuiFocus(false,false)
	TransitionFromBlurred(1000)
	TriggerEvent("hud:Active",true)
	SendNUIMessage({ Action = "Hide" })
	Callback(true)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- HOME
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Home",function(Data,Callback)
	Callback(vSERVER.Home())
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- (Opcional) Debounce simples para spam de cliques
-----------------------------------------------------------------------------------------------------------------------------------------
local Busy = {}
local function TryBusy(key, ms)
	if Busy[key] then return false end
	Busy[key] = true
	SetTimeout(ms or 750, function() Busy[key] = nil end)
	return true
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- DEPOSIT
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Deposit",function(Data,Callback)
	if not TryBusy("Deposit",700) then Callback(false) return end
	if MumbleIsConnected() and Data and Data["value"] then
		local result = vSERVER.Deposit(Data["value"])
		if not result then
			TriggerEvent("Notify","Banco","Não foi possível depositar.", "amarelo", 5000)
		end
		Callback(result)
	else
		Callback(false)
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- WITHDRAW
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Withdraw",function(Data,Callback)
	if not TryBusy("Withdraw",700) then Callback(false) return end
	if MumbleIsConnected() and Data and Data["value"] then
		local result = vSERVER.Withdraw(Data["value"])
		if not result then
			TriggerEvent("Notify","Banco","Não foi possível levantar.", "amarelo", 5000)
		end
		Callback(result)
	else
		Callback(false)
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- TRANSFER
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Transfer",function(Data,Callback)
	if not TryBusy("Transfer",900) then Callback(false) return end
	if Data and Data["targetId"] and Data["value"] and MumbleIsConnected() then
		local result = vSERVER.Transfer(Data["targetId"],Data["value"])
		if not result then
			TriggerEvent("Notify","Banco","Não foi possível transferir.", "amarelo", 5000)
		end
		Callback(result)
	else
		Callback(false)
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- ADDDEPENDENTS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("AddDependents",function(Data,Callback)
	if not TryBusy("AddDependents",900) then Callback(false) return end
	if Data and Data["passport"] then
		local result = vSERVER.AddDependents(Data["passport"])
		if not result then
			TriggerEvent("Notify","Banco","Convite não aceito ou já existente.", "amarelo", 5000)
		end
		Callback(result)
	else
		Callback(false)
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- REMOVEDEPENDENTS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("RemoveDependents",function(Data,Callback)
	if not TryBusy("RemoveDependents",700) then Callback(false) return end
	Callback(vSERVER.RemoveDependents(Data["passport"]))
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- INVESTMENTS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Investments",function(Data,Callback)
	Callback(vSERVER.Investments())
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- INVEST
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Invest",function(Data,Callback)
	if not TryBusy("Invest",900) then Callback(false) return end
	if Data and Data["value"] and MumbleIsConnected() then
		local result = vSERVER.Invest(Data["value"])
		if not result then
			TriggerEvent("Notify","Banco","Não foi possível investir.", "amarelo", 5000)
		end
		Callback(result)
	else
		Callback(false)
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- INVESTRESCUE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("InvestRescue",function(Data,Callback)
	if not TryBusy("InvestRescue",900) then Callback(false) return end
	if MumbleIsConnected() then
		local result = vSERVER.InvestRescue()
		if not result then
			TriggerEvent("Notify","Banco","Sem fundos para resgatar.", "amarelo", 5000)
		end
		Callback(result)
	else
		Callback(false)
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- TRANSACTIONHISTORY
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("TransactionHistory",function(Data,Callback)
	Callback(vSERVER.TransactionHistory())
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- MAKEINVOICE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("MakeInvoice",function(Data,Callback)
	if not TryBusy("MakeInvoice",900) then Callback(false) return end
	if Data and Data["passport"] and Data["value"] and Data["reason"] and MumbleIsConnected() then
		local result = vSERVER.MakeInvoice(Data["passport"],Data["value"],Data["reason"])
		if not result then
			TriggerEvent("Notify","Banco","O jogador recusou ou houve um erro.", "amarelo", 5000)
		end
		Callback(result)
	else
		Callback(false)
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- INVOICEPAYMENT
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("InvoicePayment",function(Data,Callback)
	if not TryBusy("InvoicePayment",700) then Callback(false) return end
	if MumbleIsConnected() and Data and Data["id"] then
		local ok = vSERVER.InvoicePayment(Data["id"])
		if not ok then
			TriggerEvent("Notify","Banco","Não foi possível pagar a fatura.", "amarelo", 5000)
		end
		Callback(ok)
	else
		Callback(false)
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- INVOICELIST
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("InvoiceList",function(Data,Callback)
	Callback(vSERVER.InvoiceList())
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- FINELIST
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("FineList",function(Data,Callback)
	Callback(vSERVER.FineList())
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- FINEPAYMENT
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("FinePayment",function(Data,Callback)
	if not TryBusy("FinePayment",700) then Callback(false) return end
	if MumbleIsConnected() and Data and Data["id"] then
		local ok = vSERVER.FinePayment(Data["id"])
		if not ok then
			TriggerEvent("Notify","Banco","Não foi possível pagar a multa.", "amarelo", 5000)
		end
		Callback(ok)
	else
		Callback(false)
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- FINEPAYMENTALL
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("FinePaymentAll",function(Data,Callback)
	if not TryBusy("FinePaymentAll",900) then Callback(false) return end
	if MumbleIsConnected() then
		local list = vSERVER.FinePaymentAll()
		if not list then
			TriggerEvent("Notify","Banco","Não foi possível pagar todas as multas.", "amarelo", 5000)
		end
		Callback(list)
	else
		Callback(false)
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- TAXES
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Taxes",function(Data,Callback)
	Callback(vSERVER.TaxList())
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- TAXPAYMENT
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("TaxPayment",function(Data,Callback)
	if not TryBusy("TaxPayment",700) then Callback(false) return end
	if MumbleIsConnected() and Data and Data["id"] then
		local ok = vSERVER.TaxPayment(Data["id"])
		if not ok then
			TriggerEvent("Notify","Banco","Não foi possível pagar o imposto.", "amarelo", 5000)
		end
		Callback(ok)
	else
		Callback(false)
	end
end)
