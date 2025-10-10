-- Path: qb-core/resources/[your_resource_name]/fxmanifest.lua

fx_version 'cerulean'
game 'gta5'

author 'Synthix'
description 'VIP Shop Script for QB-Core'
version '1.0.0'

shared_scripts {
    'config.lua' -- Ensure this line is present and correct
}

client_scripts {
    'client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}


files {
    'html/img/*.png',  -- Your case images
}

dependencies {
    'qb-core',
    'qb-menu',
    'oxmysql'
}


