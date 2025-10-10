



fx_version "bodacious"
game "gta5"
lua54 "yes"

name "farmer"
author "Synthix"
description "Frutas e Lenhador - Syn Network"


client_scripts {
	"@vrp/config/Native.lua",
	"@vrp/lib/Utils.lua",
	"client-side/*"
}

server_scripts {
	"@vrp/config/Item.lua",
	"@vrp/lib/Utils.lua",
	"server-side/*"
}              