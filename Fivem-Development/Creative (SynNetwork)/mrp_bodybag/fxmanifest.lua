fx_version "bodacious"
game "gta5"
lua54 "yes"

name "bodybag"
author "Synthix"
description "Body Bag - Syn Network"
version "1.1.0"

shared_scripts {
  "shared/config.lua"
}

client_scripts {
  "@vrp/config/Native.lua",   
  "@vrp/lib/Utils.lua",       
  "client/client.lua"
}

server_scripts {
  "@vrp/lib/Utils.lua",       
  "server/server.lua"
}