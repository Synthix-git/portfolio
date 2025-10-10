fx_version "bodacious"
game "gta5"
lua54 "yes"

name "Lumberjack"
author "Synthix"
description "Job de Lenhador (CDs) - Syn Network"
version "1.4.0"

client_scripts {
    "@vrp/config/Native.lua",
    "@vrp/lib/Utils.lua",
    "client-side/core.lua"
}

server_scripts {
    "@vrp/lib/Utils.lua",
    "server-side/core.lua"
}

shared_scripts {
    "@vrp/config/Global.lua",
    "@vrp/config/Item.lua"
}
