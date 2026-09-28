fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ts-foodbusiness'
author 'TwilightStore'
description 'Modular hospitality platform (bootstrap)'
version '0.0.0'

shared_scripts { 'shared/config.lua' }
client_scripts { 'client/main.lua' }
server_scripts { 'server/main.lua' }

ui_page 'web/dist/index.html'
files { 'web/dist/index.html', 'web/dist/assets/*' }
