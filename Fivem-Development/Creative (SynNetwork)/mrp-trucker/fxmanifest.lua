fx_version "bodacious"
game "gta5"
lua54 "yes"

author "Synthix"
description "Syn - Job Camionista (vRP) com target no ped"


shared_script "config.lua"

client_scripts {
    "@vrp/config/Native.lua",
    "@vrp/lib/Utils.lua",
    "client/main.lua"
}

server_scripts {
    "@vrp/lib/Utils.lua",
    "server/main.lua"
}

files { }
