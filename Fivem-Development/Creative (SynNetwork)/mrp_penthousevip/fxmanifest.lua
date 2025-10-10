fx_version "bodacious"
game "gta5"
lua54 "yes"

name "Penthouse"
author "Synthix"
description "Penthouse VIP/Streamer (convites only) para Syn Network"
version "1.0.0"

client_scripts {
	"@vrp/config/Native.lua",
	"@vrp/lib/Utils.lua",
	"client-side/*.lua"
}

server_scripts {
	"@vrp/lib/Utils.lua",
	"server-side/*.lua"
}

shared_scripts {
	"shared/config.lua",
	"@vrp/config/Item.lua",
	"@vrp/config/Global.lua"
}
