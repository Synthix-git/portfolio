-----------------------------------------------------------------------------------------------------------------------------------------
-- DISCORD
-----------------------------------------------------------------------------------------------------------------------------------------

local Discord = {
    ["Connect"] = "/",
    ["Disconnect"] = "/",
    ["Airport"] = "/",
    ["Deaths"] = "/",
    ["Gemstone"] = "/",
    ["Rename"] = "/",
	["Roles"] = "/",
    ["Admin"] = "/",
    ["Marketplace"] = "/",
    ["Pause"] = "/",
    ["Boxes"] = "/",
    ["Hackers"] = "/",
    ["Skin"] = "/",
    ["ClearInv"] = "/",
    ["Dima"] = "/",
    ["God"] = "/",
    ["Item"] = "/-",
    ["Delete"] = "/",
	["Kick"] = "/",
    ["Ban"] = "/",
    ["Group"] = "/",
    ["AddCar"] = "/",
    ["Print"] = "/",
    ["Permissions"] = "/",
    ["Algemar"] = "/",
    ["Calladmin"] = "/",
    ["Wall"] = "/",
    ["Prisoes"] = "/",
    ["Baus"] = "/",
    ["Reciclagem"] = "/",
    ["Malacarro"] = "/",
    ["Presets"] = "/",
    ["Apreensoes"] = "/",
    ["Teleports"] = "/",
    ["Freeze"] = "/",
    ["NoClip"] = "/",
    ["Perimetro"] = "/",
    ["Lavagem"] = "/",
    ["Banco"] = "/",
    ["Socorro"] = "/",
    ["Caixas"] = "/",
    ["Battlepass"] = "/",
    ["Marketplace"] = "/",
    ["Assaltos"] = "/",
    ["Stand"] = "/",
    ["Tunagens"] = "/",
    ["Garagens"] = "/",
    ["Plantas"] = "/",
    ["Licenças"] ="/",
    ["Wanted"] = "/",
    ["Warn"] = "/",
    ["Bodybags"] = "/",
    ["Pets"] = "/",
    ["Jobs"] = "/",
    ["Helicrash"] = "/",
    ["Horas"] = "/",
    ["Economia"] = "/",
    ["Totem"] = "/"
}
-----------------------------------------------------------------------------------------------------------------------------------------
-- EMBED
-----------------------------------------------------------------------------------------------------------------------------------------
exports("Embed",function(Hook,Message,source)
	PerformHttpRequest(Discord[Hook],function() end,"POST",json.encode({
		username = ServerName,
		embeds = {
			{ color = 0x2b2d31, description = Message }
		}
	}),{ ["Content-Type"] = "application/json" })
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONTENT
-----------------------------------------------------------------------------------------------------------------------------------------
exports("Content",function(Hook,Message)
	PerformHttpRequest(Discord[Hook],function() end,"POST",json.encode({
		username = ServerName,
		content = Message
	}),{ ["Content-Type"] = "application/json" })
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- WEBHOOK
-----------------------------------------------------------------------------------------------------------------------------------------
exports("Webhook",function(Hook)
	return Discord[Hook] or ""
end)
