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
-- Lightweight FiveM timer: reject early finish and replay.
local now = 1000
GetGameTimer = function() return now end
FoodBusiness = { Modules = { kitchen = true },
 validJobId = function(value) return type(value) == 'string' and #value == 36 end }
plan.durationSeconds = 2
ConventionalCooking.configure({
 owner = function() return true end,
 near = function() return true end,
 plan = function() return plan end,
})
local request = { businessId = string.rep('a', 36), recipeId = string.rep('b', 36),
 stationId = string.rep('c', 36), batches = 1 }
stock.flour, stock.water = 3, 2
local started = ConventionalCooking.begin(1, 'owner', request)
assert(started.ok and started.durationMs == 2000)
assert(ConventionalCooking.begin(1, 'owner', request).error == 'cooking_busy')
assert(ConventionalCooking.finish(1, 'owner', started.token).error == 'cooking_not_ready')
now = 3000
assert(ConventionalCooking.finish(1, 'owner', started.token).ok)
assert(ConventionalCooking.finish(1, 'owner', started.token).error == 'not_found')
local cancelled = ConventionalCooking.begin(1, 'owner', request)
assert(cancelled.ok and ConventionalCooking.cancel(1, cancelled.token).ok)
assert(ConventionalCooking.finish(1, 'owner', cancelled.token).error == 'not_found')
local expired = ConventionalCooking.begin(1, 'owner', request)
assert(expired.ok)
now = now + 33001
assert(ConventionalCooking.finish(1, 'owner', expired.token).error == 'cooking_expired')
local again = ConventionalCooking.begin(1, 'owner', request)
assert(again.ok)
ConventionalCooking.drop(1)
local originalInspect = Inventory.inspectPlan
Inventory.inspectPlan = function() return { available = false } end
assert(ConventionalCooking.begin(1, 'owner', request).error == 'insufficient_ingredients')
Inventory.inspectPlan = function() error('inventory disconnected') end
assert(ConventionalCooking.begin(1, 'owner', request).error == 'inventory_unavailable')
Inventory.inspectPlan = originalInspect
assert(ConventionalCooking.begin(1, 'owner', request).ok)
ConventionalCooking.drop(1)
-- Finishing cannot overlap a new cooking start, even during inventory callbacks.
local finishingSession = ConventionalCooking.begin(1, 'owner', request)
assert(finishingSession.ok)
now = now + 2000
local originalRemove = Inventory.standardOxRemove
local overlapping
Inventory.standardOxRemove = function(src, item, quantity)
 overlapping = ConventionalCooking.begin(src, 'owner', request)
 return originalRemove(src, item, quantity)
end
stock.flour, stock.water = 3, 2
assert(ConventionalCooking.finish(1, 'owner', finishingSession.token).ok)
assert(overlapping.error == 'cooking_busy')
Inventory.standardOxRemove = originalRemove
FoodBusiness.Modules.kitchen = false
assert(ConventionalCooking.begin(1, 'owner', request).error == 'cooking_disabled')
print('conventional cooking inventory, timer, replay and cancellation tests passed')
