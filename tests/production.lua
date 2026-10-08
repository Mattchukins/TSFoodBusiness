dofile('shared/config.lua')
dofile('shared/stations.lua')
dofile('shared/recipes.lua')
dofile('server/schema.lua')
assert(FoodBusiness.validStationPosition(10, 20, 30, 90, 7))
assert(not FoodBusiness.validStationPosition(math.huge, 0, 0, 0, 0))
assert(not FoodBusiness.validStationPosition(0, 0, 0, 361, 0))
assert(not FoodBusiness.validStationPosition(0, 0, 0, 0, -1))

local handler, result, transaction
local owned, positionValid, success = true, true, true
local stationExists = true
local savedProfile = nil
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
json = { encode = function() return '{}' end, decode = function(value) return value end }
MySQL = {
    single = { await = function(query, values)
        if query:find('tsfb_schema') then return { count = 5, minimum = 1, maximum = 5 } end
        if query:find('owner_id') then
            assert(values[2] == 'server-owner')
            return owned and { id = id } or nil
        end
        if query:find('FROM tsfb_production_profiles') then assert(values[1] == id); return savedProfile end
        if query:find('FROM tsfb_recipes') then
            assert(query:find('WHERE id = ? AND business_id = ?', 1, true))
            assert(values[1] == id and values[2] == id)
        end
        if query:find('SELECT x, y, z') then
            assert(values[1] == id and values[2] == id)
            return stationExists and { x = 10, y = 20, z = 30, heading = 90, routing_bucket = 7 } or nil
        end
        if query:find('SELECT ingredients') then return stationExists and { ingredients = { { item = 'flour', quantity = 3 } } } or nil end
        if query:find('SELECT type FROM tsfb_stations') then
            assert(values[1] == id and values[2] == id)
            return stationExists and { type = 'oven' } or nil
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

local profile = { stationType = 'oven', outputItem = 'bread', outputQuantity = 2, durationSeconds = 45 }
assert(FoodBusiness.validProductionProfile(profile))
for _, change in ipairs({
    { 'stationType', 'unknown' }, { 'outputItem', 'x' }, { 'outputItem', 'bad item' },
    { 'outputQuantity', 0 }, { 'outputQuantity', 101 }, { 'outputQuantity', 1.5 },
    { 'durationSeconds', 0 }, { 'durationSeconds', 3601 }, { 'durationSeconds', math.huge },
    { 'durationSeconds', 0/0 }, { 'outputItem', string.rep('x', 65) },
}) do
    local candidate = {}
    for key, value in pairs(profile) do candidate[key] = value end
    candidate[change[1]] = change[2]
    assert(not FoodBusiness.validProductionProfile(candidate), change[1])
end
assert(not FoodBusiness.validProductionProfile({}))
profile.injected = true
assert(not FoodBusiness.validProductionProfile(profile))
profile.injected = nil
owned = false
send('setProductionProfile', { businessId = id, recipeId = id, profile = profile })
assert(result.error == 'forbidden' and transaction == nil)
owned = true
send('setProductionProfile', { businessId = id, recipeId = id, profile = profile, price = 1 })
assert(result.error == 'invalid_payload' and transaction == nil)
send('getProductionProfile', { businessId = id, recipeId = id })
assert(result.ok and result.productionProfile == nil)
stationExists = false
send('setProductionProfile', { businessId = id, recipeId = id, profile = profile })
assert(result.error == 'not_found' and transaction == nil)
stationExists = true
send('setProductionProfile', { businessId = id, recipeId = id, profile = profile })
assert(result.ok and #transaction == 2)
assert(transaction[1].query:find('ON DUPLICATE KEY UPDATE', 1, true))
assert(transaction[1].values[1] == id and transaction[1].values[2] == 'oven')
assert(transaction[1].values[3] == 'bread' and transaction[1].values[4] == 2 and transaction[1].values[5] == 45)
assert(transaction[2].values[1] == 'recipe.production' and transaction[2].values[2] == 'server-owner')
savedProfile = { station_type = 'oven', output_item = 'bread', output_quantity = 2, duration_seconds = 45 }
send('getProductionProfile', { businessId = id, recipeId = id })
assert(result.ok and result.productionProfile.output_item == 'bread')
success = false
send('setProductionProfile', { businessId = id, recipeId = id, profile = profile })
assert(result.error == 'transaction_failed')
local integrationPlan = exported.GetOwnerProductionPlan
assert(integrationPlan(42, id, id, id, 2).ingredients[1].quantity == 6)
assert(integrationPlan(42, id, id, id, 0) == nil)
owned = false
assert(integrationPlan(42, id, id, id, 2) == nil)
owned = true
stationExists = false
assert(integrationPlan(42, id, id, id, 2) == nil)
stationExists = true
savedProfile.station_type = 'grill'
assert(integrationPlan(42, id, id, id, 2) == nil)
savedProfile.station_type = 'oven'
MySQL.transaction.await = function() error('database unavailable') end
send('setProductionProfile', { businessId = id, recipeId = id, profile = profile })
assert(result.error == 'transaction_failed')
print('production profile validation, ownership, read and failure contracts passed')

local ingredients = { { item = 'flour', quantity = 3 }, { item = 'water', quantity = 1 } }
local plan = FoodBusiness.planProduction(ingredients, profile, 'oven', 4)
assert(plan.ingredients[1].quantity == 12 and plan.ingredients[2].quantity == 4)
assert(plan.outputQuantity == 8 and plan.durationSeconds == 180 and plan.batches == 4)
plan.ingredients[1].quantity = 99
assert(ingredients[1].quantity == 3) -- A returned plan cannot mutate the recipe.
assert(not FoodBusiness.planProduction(ingredients, profile, 'grill', 1))
for _, batches in ipairs({ 0, -1, 1.5, 101, math.huge }) do
    assert(not FoodBusiness.planProduction(ingredients, profile, 'oven', batches))
end
assert(not FoodBusiness.planProduction({}, profile, 'oven', 1))
assert(FoodBusiness.planProduction(ingredients, profile, 'oven', 100).outputQuantity == 200)
print('batch production planning and equipment compatibility contracts passed')

local inspections = 0
Inventory = { inspectPlan = function(src, plan)
    inspections = inspections + 1
    assert(src == 42 and plan.ingredients[1].quantity == 6)
    return { available = false, reservation = false }
end }
assert(exported.GetOwnerIngredientAvailability(42, id, id, id, 2).available == false)
owned = false
assert(exported.GetOwnerIngredientAvailability(42, id, id, id, 2) == nil and inspections == 1)
owned = true
Inventory.inspectPlan = function() error('inventory unavailable') end
local unavailable, inventoryError = exported.GetOwnerIngredientAvailability(42, id, id, id, 2)
assert(unavailable == nil and inventoryError == 'inventory_error')
MySQL.single.await = function() error('database unavailable') end
assert(integrationPlan(42, id, id, id, 2) == nil)
print('owner-scoped production plan integration contracts passed')
