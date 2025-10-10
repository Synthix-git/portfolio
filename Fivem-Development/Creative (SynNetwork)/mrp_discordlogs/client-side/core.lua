-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP:ACTIVE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("vRP:Active")
AddEventHandler("vRP:Active",function(Passport,Name)
	SetDiscordAppId(DISCORDAPPIDFAKE)
	SetDiscordRichPresenceAsset("mrp")
	SetRichPresence("#"..Passport.." "..Name)
	SetDiscordRichPresenceAssetText("Medusa Roleplay")
	SetDiscordRichPresenceAssetSmall("mrp")
	SetDiscordRichPresenceAssetSmallText("Medusa Roleplay")
	SetDiscordRichPresenceAction(0,"Discord","https://discord.gg/VsYNTkwBSy")
end)