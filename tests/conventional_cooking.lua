local stock = { flour = 3, water = 2, bread = 0 }
local failAward = false
Inventory = {
 standardOxCanCarry = function() return true end,
 inspectPlan = function() return { available = true } end,
 standardOxRemove = function(_, item, quantity)
  if stock[item] < quantity then return false, 'insufficient_stock' end
  stock[item] = stock[item] - quantity
  return true
 end,
 standardOxAdd = function(_, item, quantity)
  if item == 'bread' and failAward then return false, 'inventory_full' end
  stock[item] = stock[item] + quantity
  return true
 end,
}
dofile('server/conventional_cooking.lua')
local plan = { outputItem = 'bread', outputQuantity = 1,
 ingredients = { { item = 'flour', quantity = 2 }, { item = 'water', quantity = 1 } } }
assert(ConventionalCooking.produce(1, plan, function() return false end).error == 'forbidden')
assert(stock.flour == 3)
assert(ConventionalCooking.produce(1, plan, function() return true end).ok)
assert(stock.flour == 1 and stock.water == 1 and stock.bread == 1)
stock.flour, stock.water = 3, 2
failAward = true
assert(ConventionalCooking.produce(1, plan, function() return true end).error == 'inventory_full')
assert(stock.flour == 3 and stock.water == 2)
assert(ConventionalCooking.produce(1, { outputItem = 'bread', outputQuantity = 0,
 ingredients = plan.ingredients }, function() return true end).error == 'invalid_request')
-- Unknown output delivery must not restore ingredients (duplicate-award risk).
failAward = false
local originalAdd = Inventory.standardOxAdd
Inventory.standardOxAdd = function(_, item, quantity)
 if item == 'bread' then return nil, 'inventory_outcome_unknown' end
 return originalAdd(_, item, quantity)
end
assert(ConventionalCooking.produce(1, plan, function() return true end).error == 'manual_inventory_recovery_required')
assert(stock.flour == 1 and stock.water == 1)
Inventory.standardOxAdd = originalAdd
-- A re-entrant request must not mutate inventory.
stock.flour, stock.water = 3, 2
local nested
assert(ConventionalCooking.produce(1, plan, function()
 nested = ConventionalCooking.produce(1, plan, function() return true end)
 return false
end).error == 'forbidden')
assert(nested.error == 'cooking_busy' and stock.flour == 3)
-- Revoking access between ingredient removals must refund consumed items.
stock.flour, stock.water = 3, 2
local authorizationCalls = 0
local denied = ConventionalCooking.produce(1, plan, function()
 authorizationCalls = authorizationCalls + 1
 return authorizationCalls <= 2
end)
assert(denied.error == 'forbidden')
assert(stock.flour == 3 and stock.water == 2)
-- Public request path must fail closed until the durable timer/replay
-- implementation is actually available, even with feature flag enabled.
FoodBusiness = {
 ConventionalCookingEnabled = true,
 ConventionalCookingDurableReady = false,
 validJobId = function(value) return type(value) == 'string' and #value == 36 end,
}
ConventionalCooking.configure({
 owner = function() return true end,
 near = function() return true end,
 plan = function() return plan end,
})
local request = { businessId = string.rep('a', 36), recipeId = string.rep('b', 36),
 stationId = string.rep('c', 36), batches = 1 }
assert(ConventionalCooking.start(1, 'owner', request).error == 'durable_cooking_not_ready')
assert(stock.flour == 3 and stock.water == 2)
print('conventional cooking compensation, reauthorization, uncertain outcome, locking and safe feature gate tests passed')
