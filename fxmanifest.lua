fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ts-foodbusiness'
author 'TwilightStore'
description 'Modular hospitality platform (bootstrap)'
version '0.8.0-dev'

dependencies { 'oxmysql', 'ox_lib', 'ox_inventory', 'ox_target' }
shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', 'shared/operations.lua', 'shared/presets.lua', 'shared/recipes.lua', 'shared/stations.lua', 'shared/jobs.lua', 'shared/conventional_timing.lua', 'shared/staff.lua' }
client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'bridges/framework.lua', 'bridges/inventory.lua', 'server/schema.lua', 'server/jobs.lua', 'server/conventional_cooking.lua', 'server/staff.lua', 'server/main.lua' }

ui_page 'web/dist/index.html'
files { 'web/dist/index.html', 'web/dist/assets/*' }
