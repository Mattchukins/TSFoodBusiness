FoodBusiness = { Version = 'test', RequiredSchema = 8, Modules = { businesses = true, operations = true, recipes = true } }
dofile('shared/presets.lua')
dofile('shared/recipes.lua')
dofile('server/schema.lua')

local handler, response, statements
Framework = { name = 'test', init = function() return true end,
    player = function() return { id = 'server-character' } end }
MySQL = {
    query = { await = function(query)
        local fixture = dofile('tests/schema_fixture.lua')
        if query:find('information_schema.TABLES', 1, true) then return fixture.tables end
        if query:find('information_schema.STATISTICS', 1, true) then return fixture.indexes end
        return fixture.columns
    end },
    single = { await = function() return { count = 8, minimum = 1, maximum = 8 } end },
    scalar = { await = function() return '12345678-1234-1234-1234-123456789abc' end },
    transaction = { await = function(items) statements = items; return true end },
}
json = { encode = function() return '{}' end }
CreateThread = function(callback) callback() end
RegisterNetEvent = function(_, callback) handler = callback end
AddEventHandler = function() end
exports = function() end
GetGameTimer = function() return 100 end
IsPlayerAceAllowed = function() return true end
TriggerClientEvent = function(_, _, message) response = message.result end

dofile('server/main.lua')
source = 42
handler({ requestId = 'create-1', action = 'createBusiness', data = {
    name = 'Demo Restaurant', type = 'restaurant', config = {}, owner_id = 'spoofed-character',
} })
assert(response.ok == false and response.error == 'invalid_payload')
assert(statements == nil)

handler({ requestId = 'create-2', action = 'createBusiness', data = {
    name = 'Demo Restaurant', type = 'drive_through', config = {},
} })
assert(response.ok == true and #statements == 3)
assert(statements[1].values[2] == 'server-character')
assert(statements[1].values[4] == 'drive_through')
assert(statements[2].values[2] == 360 and statements[2].values[3] == 120)
assert(statements[2].values[4] == 0 and statements[2].values[5] == 20)
assert(statements[3].values[2] == 'server-character')
print('business creation contract passed')

local businessId = '12345678-1234-1234-1234-123456789abc'
local recipeId = '87654321-1234-1234-1234-123456789abc'
statements = nil
MySQL.single.await = function(query, values)
    if query:find('owner_id') then
        assert(values[2] == 'server-character')
        return nil
    end
    return { id = recipeId }
end
handler({ requestId = 'edit-1', action = 'updateRecipe', data = {
    businessId = businessId, recipeId = recipeId, name = 'Sandwich', priceCents = 500,
    ingredients = { { item = 'bread', quantity = 2 } },
} })
assert(response.error == 'forbidden' and statements == nil)
MySQL.single.await = function() return { id = recipeId } end
handler({ requestId = 'edit-2', action = 'updateRecipe', data = {
    businessId = businessId, recipeId = recipeId, name = 'Sandwich', priceCents = 500,
    ingredients = { { item = 'bread', quantity = 2 }, { item = 'bread', quantity = 1 } },
} })
assert(response.error == 'invalid_payload' and statements == nil)
handler({ requestId = 'edit-3', action = 'updateRecipe', data = {
    businessId = businessId, recipeId = recipeId, name = 'Sandwich', priceCents = 500,
    ingredients = { { item = 'bread', quantity = 2 }, { item = 'cheese', quantity = 1 } },
} })
assert(response.ok and #statements == 2)
assert(statements[1].query:find('ingredients = ?'))
assert(statements[1].values[4] == recipeId and statements[1].values[5] == businessId)
assert(statements[2].values[1] == 'recipe.update')
print('recipe update authorization contract passed')

local update = { businessId = businessId, recipeId = recipeId, name = 'Sandwich', priceCents = 500,
    ingredients = { { item = 'bread', quantity = 2 } } }
MySQL.transaction.await = function() return false end
handler({ requestId = 'edit-4', action = 'updateRecipe', data = update })
assert(response.ok == false and response.error == 'transaction_failed')
MySQL.transaction.await = function() error('simulated database failure') end
handler({ requestId = 'edit-5', action = 'updateRecipe', data = update })
assert(response.ok == false and response.error == 'transaction_failed')
print('recipe transaction failure contract passed')

MySQL.single.await = function() return nil end
MySQL.query.await = function() error('audit query must not run without ownership') end
handler({ requestId = 'audit-1', action = 'listAudit', data = { businessId = businessId } })
assert(response.error == 'forbidden')
MySQL.single.await = function(query, values)
    assert(query:find('owner_id') and values[2] == 'server-character')
    return { id = businessId }
end
MySQL.query.await = function(query, values)
    assert(query:find('WHERE business_id = ?') and query:find('LIMIT 100'))
    assert(values[1] == businessId)
    return { { action = 'recipe.update', details = '{}', created_at = '2026-10-05' } }
end
handler({ requestId = 'audit-2', action = 'listAudit', data = { businessId = businessId } })
assert(response.ok and #response.audit == 1 and response.audit[1].action == 'recipe.update')
print('audit ownership and query scope contract passed')

MySQL.single.await = function() return { count = 8, minimum = 1, maximum = 8 } end
MySQL.query.await = function() return {} end
response, statements = nil, nil
dofile('server/main.lua')
handler({ requestId = 'disabled-1', action = 'createBusiness', data = {
    name = 'Blocked Restaurant', type = 'restaurant', config = {},
} })
assert(response == nil and statements == nil)
print('incomplete schema startup isolation passed')
