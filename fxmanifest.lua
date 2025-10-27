fx_version 'cerulean'
game 'gta5'

author 'RX Scripts'
description 'Advanced Report System for QBCore'
version '1.0.0'

shared_scripts {
    'config.lua',
    'locales/*.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/images/*.png'
}

lua54 'yes'

dependencies {
    'qb-core',
    'oxmysql'
}