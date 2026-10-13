fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'tsfb-ox-inventory'
author 'TwilightStore'
description 'Fail-closed ox_inventory integration for TSFoodBusiness'
version '0.1.0'

dependencies { 'ox_inventory', 'oxmysql' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server.lua', 'stock_provider.lua' }
files { 'journal.lua', 'stock_engine.lua' }
