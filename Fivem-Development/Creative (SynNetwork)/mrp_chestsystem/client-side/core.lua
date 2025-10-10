-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")
vRPS = Tunnel.getInterface("vRP")
vRP = Proxy.getInterface("vRP")
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
vSERVER = Tunnel.getInterface("chest")
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Block = false
local Opened = false
local Animation = false
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHESTS
-----------------------------------------------------------------------------------------------------------------------------------------
local Chests = {
	-- ORGS LEGAIS
	{ ["Name"] = "Policia",    ["Coords"] = vec3(454.77,-996.58,35.06),    ["Mode"] = "1" },
	{ ["Name"] = "Paramedico", ["Coords"] = vec3(1135.52,-1540.48,35.38),  ["Mode"] = "2" },
	{ ["Name"] = "AutoExotic", ["Coords"] = vec3(-2032.48,-512.34,12.13),  ["Mode"] = "4" },
	{ ["Name"] = "LSCustoms",  ["Coords"] = vec3(-329.41,-112.81,39.01),   ["Mode"] = "11" },
	{ ["Name"] = "Bennys",     ["Coords"] = vec3(124.84,-3050.03,7.04),    ["Mode"] = "12" },
	{ ["Name"] = "Burgershot", ["Coords"] = vec3(-1190.78, -903.01, 13.8), ["Mode"] = "9" },

	-- Ammunations
	{ ["Name"] = "AmmunationSul",    ["Coords"] = vec3(244.22,-49.72,69.94),    ["Mode"] = "13" },
	{ ["Name"] = "AmmunationNorte",  ["Coords"] = vec3(-323.44,6080.22,31.46),  ["Mode"] = "14" },
	{ ["Name"] = "AmmunationCentro", ["Coords"] = vec3(-1111.29,2694.82,18.55), ["Mode"] = "15" },

    -- ORG ILEGAIS
	{ ["Name"] = "Playboy21", ["Coords"] = vec3(-1498.03,123.24,55.67),     ["Mode"] = "5" },
	{ ["Name"] = "NTB",       ["Coords"] = vec3(1364.05,-2495.59,53.35),    ["Mode"] = "6" },
	{ ["Name"] = "Bahamas",   ["Coords"] = vec3(-1365.18,-616.42,30.31),    ["Mode"] = "7" },
	{ ["Name"] = "Madrazo",   ["Coords"] = vec3(-1870.39, 2059.20, 135.44), ["Mode"] = "8" },
	{ ["Name"] = "Callisto",  ["Coords"] = vec3(395.06, -5.67, 84.92),      ["Mode"] = "10" },
	{ ["Name"] = "Vanilla",   ["Coords"] = vec3(106.5,-1299.04,28.76),      ["Mode"] = "16" },
	{ ["Name"] = "Tequila",   ["Coords"] = vec3(-571.22,289.1,79.18),       ["Mode"] = "17" },
	{ ["Name"] = "RCP",       ["Coords"] = vec3(0.26,526.74,170.62),        ["Mode"] = "18" },
	{ ["Name"] = "Beco",      ["Coords"] = vec3(3293.78,5083.16,27.27),   	["Mode"] = "19" }
}
-----------------------------------------------------------------------------------------------------------------------------------------
-- LABELS
-----------------------------------------------------------------------------------------------------------------------------------------
local Labels = {
	["1"] = {
		{ event = "chest:Open", label = "Compartimento Geral",   tunnel = "client", service = "Normal"  },
		{ event = "chest:Open", label = "Compartimento Pessoal", tunnel = "client", service = "Personal"},
		{ event = "chest:Armour", label = "Colete Balístico",    tunnel = "server" }
	},
	["2"] = {
		{ event = "chest:Open", label = "Compartimento Geral",   tunnel = "client", service = "Normal"  },
		{ event = "chest:Open", label = "Compartimento Pessoal", tunnel = "client", service = "Personal"}
	},
	["3"] = {
		{ event = "chest:Open", label = "Abrir", tunnel = "client", service = "Tray" }
	},
	["4"] = {
		{ event = "chest:Open", label = "Compartimento Geral",   tunnel = "client", service = "Normal"  },
		{ event = "chest:Open", label = "Compartimento Pessoal", tunnel = "client", service = "Personal"}
	},
	["5"] = {
		{ event = "chest:Open", label = "Compartimento Geral",   tunnel = "client", service = "Normal"  },
		{ event = "chest:Open", label = "Compartimento Pessoal", tunnel = "client", service = "Personal"}
	},
	["6"] = {
		{ event = "chest:Open", label = "Compartimento Geral",   tunnel = "client", service = "Normal"  },
		{ event = "chest:Open", label = "Compartimento Pessoal", tunnel = "client", service = "Personal"}
	},
	["7"] = {
		{ event = "chest:Open", label = "Compartimento Geral",   tunnel = "client", service = "Normal"  },
		{ event = "chest:Open", label = "Compartimento Pessoal", tunnel = "client", service = "Personal"}
	},
	["8"] = {
		{ event = "chest:Open", label = "Compartimento Geral",   tunnel = "client", service = "Normal"  },
		{ event = "chest:Open", label = "Compartimento Pessoal", tunnel = "client", service = "Personal"}
	},
	["9"] = {
		{ event = "chest:Open", label = "Compartimento Geral",   tunnel = "client", service = "Normal"  },
		{ event = "chest:Open", label = "Compartimento Pessoal", tunnel = "client", service = "Personal"}
	},
	["10"] = {
		{ event = "chest:Open", label = "Compartimento Geral",   tunnel = "client", service = "Normal"  },
		{ event = "chest:Open", label = "Compartimento Pessoal", tunnel = "client", service = "Personal"}
	},
	["11"] = {
		{ event = "chest:Open", label = "Compartimento Geral",   tunnel = "client", service = "Normal"  },
		{ event = "chest:Open", label = "Compartimento Pessoal", tunnel = "client", service = "Personal"}
	},
	["12"] = {
		{ event = "chest:Open", label = "Compartimento Geral",   tunnel = "client", service = "Normal"  },
		{ event = "chest:Open", label = "Compartimento Pessoal", tunnel = "client", service = "Personal"}
	},
	["13"] = {
		{ event = "chest:Open", label = "Compartimento Geral",   tunnel = "client", service = "Normal"  },
		{ event = "chest:Open", label = "Compartimento Pessoal", tunnel = "client", service = "Personal"}
	},
	["14"] = {
		{ event = "chest:Open", label = "Compartimento Geral",   tunnel = "client", service = "Normal"  },
		{ event = "chest:Open", label = "Compartimento Pessoal", tunnel = "client", service = "Personal"}
	},
	["15"] = {
		{ event = "chest:Open", label = "Compartimento Geral",   tunnel = "client", service = "Normal"  },
		{ event = "chest:Open", label = "Compartimento Pessoal", tunnel = "client", service = "Personal"}
	},
	["16"] = {
		{ event = "chest:Open", label = "Compartimento Geral",   tunnel = "client", service = "Normal"  },
		{ event = "chest:Open", label = "Compartimento Pessoal", tunnel = "client", service = "Personal"}
	},
	["17"] = {
		{ event = "chest:Open", label = "Compartimento Geral",   tunnel = "client", service = "Normal"  },
		{ event = "chest:Open", label = "Compartimento Pessoal", tunnel = "client", service = "Personal"}
	},
	["18"] = {
		{ event = "chest:Open", label = "Compartimento Geral",   tunnel = "client", service = "Normal"  },
		{ event = "chest:Open", label = "Compartimento Pessoal", tunnel = "client", service = "Personal"}
	},
	["19"] = {
		{ event = "chest:Open", label = "Compartimento Geral",   tunnel = "client", service = "Normal"  },
		{ event = "chest:Open", label = "Compartimento Pessoal", tunnel = "client", service = "Personal"}
	}
}
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADSERVERSTART
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	for Name,v in pairs(Chests) do
		exports["target"]:AddCircleZone("Chest:"..Name,v["Coords"],1.5,{
			name = "Chest:"..Name,
			heading = 0.0,
			useZ = true
		},{
			Distance = 1.5,
			shop = v["Name"],
			options = Labels[v["Mode"]]
		})
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- CHEST:OPEN
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("chest:Open")
AddEventHandler("chest:Open", function(Name, Mode, Item, Blocked, Force)
	if GetEntityHealth(PlayerPedId()) <= 100 then return end

	-- Verifica permissão com retorno
	if vSERVER.Permissions(Name, Mode, Item) then
		if Blocked or SplitBoolean(Name, "Helicrash", ":") then
			Block = true
		end

		Opened = true

		if Mode ~= "Item" then
			Animation = true
			vRP.playAnim(false, { "amb@prop_human_bum_bin@base", "base" }, true)
		end

		TriggerEvent("inventory:Open", {
			Type = "Chest",
			Resource = "chest",
			Force = Force
		})
	else
		TriggerEvent("Notify", "Acesso", "Não tens permissão para abrir este baú.", "vermelho", 5000)
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- CHEST:ITEM
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("chest:Item",function(Name)
	if vSERVER.Permissions(Name,"Item") and GetEntityHealth(PlayerPedId()) > 100 then
		Opened = true
		TriggerEvent("inventory:Open",{
			Type = "Chest",
			Resource = "chest"
		})
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- CHEST:RECYCLE
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("chest:Recycle",function()
	if vSERVER.Permissions("Recycle", "Tray") and GetEntityHealth(PlayerPedId()) > 100 then
		Opened = true
		TriggerEvent("inventory:Open",{
			Type = "Chest",
			Resource = "chest"
		})
	end
end)

RegisterNetEvent("chest:RecycleProgress")
AddEventHandler("chest:RecycleProgress", function()
	local time = 5000
	local interval = 1500
	local loops = math.floor(time / interval)

	CreateThread(function()
		for i = 1, loops do
			PlaySoundFrontend(-1, "DiggerRevOneShot", "BulldozerDefault", true)
			Wait(interval)
		end
	end)

	TriggerEvent("Progress", "A reciclar...", time)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- INVENTORY:CLOSE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("inventory:Close")
AddEventHandler("inventory:Close",function()
	if Opened then
		if Animation then
			Animation = false
			vRP.Destroy()
		end

		Opened = false
		Block = false

		-- notifica o servidor para libertar o chest (e fazer diff se Custom)
		TriggerServerEvent("chest:Close")
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- TAKE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Take",function(Data,Callback)
	if MumbleIsConnected() then
		vSERVER.Take(Data["item"],Data["slot"],Data["amount"],Data["target"])
	end
	Callback("Ok")
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- STORE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Store",function(Data,Callback)
	if MumbleIsConnected() then
		vSERVER.Store(Data["item"],Data["slot"],Data["amount"],Data["target"],Block)
	end
	Callback("Ok")
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Update",function(Data,Callback)
	if MumbleIsConnected() then
		vSERVER.Update(Data["slot"],Data["target"],Data["amount"])
	end
	Callback("Ok")
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- MOUNT
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("Mount",function(Data,Callback)
	local Primary,Secondary,PrimaryWeight,SecondaryWeight,SecondarySlots = vSERVER.Mount()
	if Primary then
		Callback({ Primary = Primary, Secondary = Secondary, PrimaryMaxWeight = PrimaryWeight, SecondaryMaxWeight = SecondaryWeight, SecondarySlots = SecondarySlots })
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- RESTAURAR COLETE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("admin:requestArmour")
AddEventHandler("admin:requestArmour", function(token)
	local armour = GetPedArmour(PlayerPedId())
	TriggerServerEvent("admin:requestArmour:response", token, armour)
end)
