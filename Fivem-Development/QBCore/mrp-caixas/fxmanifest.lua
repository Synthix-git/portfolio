fx_version 'cerulean'
game 'gta5'
author 'Synthix'
lua54 'yes'

-- Declare a dependência de 'oxmysql' para garantir que ele seja carregado
dependencies {
    'oxmysql',
    'qb-core'
}

-- Scripts compartilhados entre cliente e servidor
shared_scripts {
    'shared/config.lua',
}

client_script "client/main.lua"

server_script {
    '@oxmysql/lib/MySQL.lua', -- Necessário para interações com a base de dados
    'server/main.lua'
}
-- Arquivo HTML para a interface do usuário (UI)
ui_page "html/index.html"

-- Arquivos utilizados pelo recurso
files {
    'html/index.html',
    'html/index.js',
    'html/index.css',
    'html/reset.css',
    'html/img/*.*'
}