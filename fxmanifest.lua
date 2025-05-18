fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Your Name'
description 'ESX Missions System'
version '1.0.0'

shared_scripts {
  '@es_extended/imports.lua',
  '@ox_lib/init.lua',
  'shared/config.lua'
}

client_scripts {
  'client/main.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/main.lua'
}

ui_page 'client/html/index.html'

files {
  'client/html/index.html',
  'client/html/style.css',
  'client/html/script.js'
}

dependencies {
  'es_extended',
  'oxmysql',
  'ox_lib'
}
