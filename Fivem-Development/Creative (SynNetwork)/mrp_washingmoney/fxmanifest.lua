fx_version "bodacious"
game "gta5"
lua54 "yes"

author "Synthix"
description "Standalone Money Washing job (drive-thru, informant event, VIP/Level bonuses, proximity routes)"

client_scripts {
  "@vrp/config/Native.lua",
  "@vrp/lib/Utils.lua",
  "client-side/core.lua"
}

server_scripts {
  "@vrp/lib/Utils.lua",
  "server-side/core.lua"
}
