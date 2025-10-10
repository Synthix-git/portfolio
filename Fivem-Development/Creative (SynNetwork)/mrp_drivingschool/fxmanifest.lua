fx_version "bodacious"
game "gta5"
lua54 "yes"

name "autoschool"
author "Synthix"
description "Autoescola com questionário via vKEYBOARD e target (Syn Network)"
version "1.1.0"

client_scripts{
    "@vrp/config/Native.lua",
    "@vrp/lib/Utils.lua",
    "client-side/core.lua"
}

server_scripts{
    "@vrp/lib/Utils.lua",
    "server-side/config.lua",
    "server-side/core.lua"
}

shared_scripts{
    "@vrp/config/Global.lua"
}
