fx_version "bodacious"
game "gta5"
lua54 "yes"

author "Synthix"

ui_page "web-side/index.html"

client_scripts {
	"@vrp/config/Native.lua",
	"@PolyZone/client.lua",
	"@vrp/lib/Utils.lua",
	"client-side/*"
}

files {
	"web-side/*",
	"web-side/**/*"
}