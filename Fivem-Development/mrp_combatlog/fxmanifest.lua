fx_version "cerulean"
game "gta5"

name "syn-leavelogger"
author "Synthix"
version "1.0.0"
description "LeaveLogger com texto 3D e logs no canal Disconnect (Syn Network)."

lua54 "yes"

client_scripts {
    "client.lua"
}

server_scripts {
    "@vrp/lib/Utils.lua", -- se necessário na tua base; se não usas, remove
    "server.lua"
}
