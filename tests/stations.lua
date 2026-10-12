dofile('shared/config.lua')
dofile('shared/stations.lua')
dofile('server/schema.lua')
assert(FoodBusiness.validStationPosition(10, 20, 30, 90, 7))
assert(not FoodBusiness.validStationPosition(math.huge, 0, 0, 0, 0))
assert(not FoodBusiness.validStationPosition(0, 0, 0, 361, 0))
assert(not FoodBusiness.validStationPosition(0, 0, 0, 0, -1))

local handler, result, transaction
local owned, positionValid, success = true, true, true
local stationExists = true
local id = '12345678-1234-1234-1234-123456789abc'
Framework = { name = 'test', init = function() return true end, player = function() return { id = 'server-owner' } end }
CreateThread = function(callback) callback() end
RegisterNetEvent = function(_, callback) handler = callback end
AddEventHandler = function() end
local exported = {}
exports = function(name, callback) exported[name] = callback end
TriggerClientEvent = function(_, _, message) result = message.result end
local timer = 100
GetGameTimer = function() return timer end
GetPlayerPed = function() return 42 end
GetEntityCoords = function() return { x = positionValid and 10 or math.huge, y = 20, z = 30 } end
GetEntityHeading = function() return 90 end
GetPlayerRoutingBucket = function() return 7 end
json = { encode = function() return '{}' end }
MySQL = {
    single = { await = function(query, values)
        if query:find('tsfb_schema') then return { count = 9, minimum = 1, maximum = 9 } end
        if query:find('owner_id') then
            assert(values[2] == 'server-owner')
            return owned and { id = id } or nil
        end
        if query:find('SELECT x, y, z') then
            assert(values[1] == id and values[2] == id)
            return stationExists and { x = 10, y = 20, z = 30, heading = 90, routing_bucket = 7 } or nil
        end
        return stationExists and { id = id } or nil
    end },
    scalar = { await = function() return id end },
    transaction = { await = function(statements) transaction = statements; return success end },
    query = { await = function(query, values)
        local fixture = dofile('tests/schema_fixture.lua')
        if query:find('information_schema.COLUMNS', 1, true) then return fixture.columns end
        if query:find('information_schema.TABLES', 1, true) then return fixture.tables end
        if query:find('information_schema.STATISTICS', 1, true) then return fixture.indexes end
        assert(query:find('tsfb_stations') and query:find('WHERE business_id = ?') and values[1] == id)
        return { { id = id, name = 'Grill', type = 'grill' } }
    end },
}
dofile('server/main.lua')
source = 42
local sequence = 0
local function send(action, data)
    sequence = sequence + 1
    handler({ requestId = 'station-' .. sequence, action = action, data = data })
end
owned = false
send('createStation', { businessId = id, name = 'Grill', type = 'grill' })
assert(result.error == 'forbidden' and transaction == nil)
owned = true
send('createStation', { businessId = id, name = 'Grill', type = 'grill', x = 999 })
assert(result.error == 'invalid_payload' and transaction == nil)
positionValid = false
send('createStation', { businessId = id, name = 'Grill', type = 'grill' })
assert(result.error == 'position_unavailable' and transaction == nil)
positionValid = true
send('createStation', { businessId = id, name = 'Grill', type = 'grill' })
assert(result.ok and #transaction == 2)
assert(transaction[1].values[5] == 10 and transaction[1].values[8] == 90 and transaction[1].values[9] == 7)
assert(transaction[2].values[1] == 'station.create')
send('listStations', { businessId = id })
assert(result.ok and #result.stations == 1)
success = false
send('deleteStation', { businessId = id, stationId = id })
assert(result.error == 'transaction_failed' and transaction[1].values[2] == id)
success = true
send('moveStation', { businessId = id, stationId = id, x = 999 })
assert(result.error == 'invalid_payload')
send('moveStation', { businessId = id, stationId = id })
assert(result.ok and transaction[1].query:find('UPDATE tsfb_stations'))
assert(transaction[1].values[1] == 10 and transaction[1].values[6] == id and transaction[1].values[7] == id)
assert(transaction[2].values[1] == 'station.move')
owned = false
send('moveStation', { businessId = id, stationId = id })
assert(result.error == 'forbidden')
print('station placement and authorization contracts passed')

timer = 2000
send('updateStation', { businessId = id, stationId = id, name = 'Oven', type = 'oven' })
assert(result.error == 'forbidden')
owned = true
send('updateStation', { businessId = id, stationId = id, name = 'Oven', type = 'unknown' })
assert(result.error == 'invalid_payload')
send('updateStation', { businessId = id, stationId = id, name = 'Oven', type = 'oven', x = 999 })
assert(result.error == 'invalid_payload')
send('updateStation', { businessId = id, stationId = id, name = 'Oven', type = 'oven' })
assert(result.ok and transaction[1].query == 'UPDATE tsfb_stations SET name = ?, type = ? WHERE id = ? AND business_id = ?')
assert(transaction[1].values[1] == 'Oven' and transaction[1].values[2] == 'oven')
assert(transaction[1].values[3] == id and transaction[1].values[4] == id)
assert(transaction[2].values[1] == 'station.update')
success = false
send('updateStation', { businessId = id, stationId = id, name = 'Oven', type = 'oven' })
assert(result.error == 'transaction_failed')
print('station editing contracts passed')

stationExists = false
send('updateStation', { businessId = id, stationId = id, name = 'Oven', type = 'oven' })
assert(result.error == 'not_found')

local station = { x = 0, y = 0, z = 0, heading = 0, routing_bucket = 7 }
assert(FoodBusiness.isNearStation(station, 2, 0, 0, 7, 2))
assert(not FoodBusiness.isNearStation(station, 2.001, 0, 0, 7, 2))
assert(not FoodBusiness.isNearStation(station, 0, 0, 3, 7, 2))
assert(not FoodBusiness.isNearStation(station, 0, 0, 0, 8, 2))
assert(not FoodBusiness.isNearStation(station, 0/0, 0, 0, 7, 2))
assert(not FoodBusiness.isNearStation(station, 0, 0, 0, 7, math.huge))
local near = exported.IsOwnerNearStation
assert(near(42, id, id) == nil) -- Missing station.
stationExists = true
assert(near(42, id, id) == true)
assert(near(42, id, id, 11) == nil)
assert(near(0, id, id) == nil)
owned = false
assert(near(42, id, id) == nil)
owned = true
positionValid = false
assert(near(42, id, id) == false)
timer = 4000
send('listStationTypes', {})
assert(result.ok and #result.stationTypes == 10)
assert(result.stationTypes[1] == 'cutting')
result.stationTypes[1] = 'changed'
assert(FoodBusiness.listStationTypes()[1] == 'cutting')
send('listStationTypes', { injected = true })
assert(result.error == 'invalid_payload')
MySQL.single.await = function() error('database unavailable') end
assert(near(42, id, id) == nil)
print('station proximity contracts passed')
