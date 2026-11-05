-- Mocked framework adapter contracts. Real FiveM smoke tests remain required.
FoodBusiness = { Framework = 'auto' }
local running = {}
GetResourceState = function(name) return running[name] and 'started' or 'missing' end
local esxPlayer = { identifier = 'esx-character', job = { name = 'chef', grade = 2 } }
local qbPlayer = { PlayerData = { citizenid = 'qb-character', job = { name = 'chef', grade = { level = 3 } } } }
local qboxPlayer = { PlayerData = { citizenid = 'qbox-character', job = { name = 'cook', grade = { level = 4 } } } }
local esxCore = { GetPlayerFromId = function(src) return src == 1 and esxPlayer or nil end }
local qbCore = { Functions = { GetPlayer = function(src) return src == 1 and qbPlayer or nil end } }
exports = {
    ['es_extended'] = { getSharedObject = function() return esxCore end },
    ['qb-core'] = { GetCoreObject = function() return qbCore end },
    qbx_core = { GetPlayer = function(_, src) return src == 1 and qboxPlayer or nil end },
}
dofile('bridges/esx.lua')
dofile('bridges/qbcore.lua')
dofile('bridges/qbox.lua')
dofile('bridges/framework.lua')
assert(not Framework.init())
running.es_extended = true
assert(Framework.init())
assert(Framework.name == 'esx' and Framework.core == esxCore)
local person = Framework.player(1)
assert(person.id == 'esx-character' and person.job == 'chef' and person.grade == 2)
assert(Framework.player(2) == nil and Framework.player(0) == nil)
esxPlayer.identifier = 123
assert(Framework.player(1) == nil)
esxPlayer.identifier = 'esx-character'
esxCore.GetPlayerFromId = function() error('character lookup failed') end
assert(Framework.player(1) == nil)
esxCore.GetPlayerFromId = function(src) return src == 1 and esxPlayer or nil end
running.es_extended, running['qb-core'] = false, true
assert(Framework.init() and Framework.name == 'qbcore')
person = Framework.player(1)
assert(person.id == 'qb-character' and person.grade == 3)
running.qbx_core = true
assert(Framework.init() and Framework.name == 'qbox')
assert(Framework.player(1).id == 'qbox-character')
assert(Framework.player(1).grade == 4)
FoodBusiness.Framework = 'qbcore'
assert(not Framework.init())
FoodBusiness.Framework = 'auto'
running.es_extended = true
assert(not Framework.init())
assert(Framework.player(1) == nil)
running.es_extended, running['qb-core'], running.qbx_core = false, false, true
assert(Framework.init())
qboxPlayer.PlayerData.citizenid = 'bad\nidentity'
assert(Framework.player(1) == nil)
qboxPlayer.PlayerData.citizenid = 'qbox-character'
exports.qbx_core.GetPlayer = function() error('provider stopped') end
assert(Framework.player(1) == nil)
print('independent ESX, QBCore and QBox bridge mock tests passed')
