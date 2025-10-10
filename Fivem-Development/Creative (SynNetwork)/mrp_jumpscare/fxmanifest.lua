fx_version "bodacious"
game "gta5"
lua54 "yes"

author "Synthix"
description "Jumpscare (Syn Network) – trigger por src & passport"

ui_page "html/index.html"

files {
    "html/listener.js",
    "html/style.css",
    "html/reset.css",
    "html/index.html",
    "html/yeet.ogg"
}

client_scripts {
    "client.lua"
}

server_scripts {
    "@vrp/lib/Utils.lua", -- necessário para module()
    "server.lua"
}
