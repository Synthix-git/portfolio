fx_version "bodacious"
game "gta5"
lua54 "yes"

author "Synthix"

shared_scripts {
	"config.lua"
}

client_scripts {
	"@vrp/config/Native.lua",
	"@PolyZone/client.lua",
	"@vrp/lib/Utils.lua",
	"client-side/*"
}

server_scripts {
	"@vrp/lib/Utils.lua",
	"server-side/*"
}
