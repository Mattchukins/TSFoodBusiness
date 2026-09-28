fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ts-foodbusiness'
author 'TwilightStore'
description 'Modular hospitality platform (bootstrap)'
version '0.0.0'

dependencies { 'oxmysql', 'ox_lib' }
shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'bridges/framework.lua', 'server/main.lua' }

ui_page 'web/dist/index.html'
files { 'web/dist/index.html', 'web/dist/assets/*' }
