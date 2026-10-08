dofile('shared/config.lua')
local started, throws, count, exists = true, false, 4, true
GetResourceState = function() return started and 'started' or 'stopped' end
exports = { custom_inventory = {
    ItemExists = function(_, item) assert(type(item) == 'string'); if throws then error('provider failure') end; return exists end,
    GetItemCount = function(_, src, item) assert(src == 42 and item == 'flour'); return count end,
} }
dofile('bridges/inventory.lua')
assert(not Inventory.capabilities().configured)
assert(Inventory.count(42, 'flour') == nil)
FoodBusiness.Inventory = { provider = 'custom', resource = 'custom_inventory', itemExistsExport = 'ItemExists', countExport = 'GetItemCount' }
assert(Inventory.capabilities().configured and not Inventory.capabilities().atomicProduction)
assert(Inventory.itemExists('bread') == true)
assert(Inventory.count(42, 'flour') == 4)
local plan = { outputItem = 'bread', ingredients = { { item = 'flour', quantity = 5 } } }
local report = Inventory.inspectPlan(42, plan)
assert(not report.available and report.ingredients[1].missing == 1 and not report.reservation)
count = 5
assert(Inventory.inspectPlan(42, plan).available)
for _, invalid in ipairs({ -1, 1.5, math.huge, '5' }) do count = invalid; assert(Inventory.count(42, 'flour') == nil) end
count = 0/0; assert(Inventory.count(42, 'flour') == nil)
count = 5; exists = false
local result, reason = Inventory.inspectPlan(42, plan)
assert(result == nil and reason == 'unknown_output_item')
exists = 'yes'; assert(Inventory.itemExists('bread') == nil)
exists = true; throws = true; assert(Inventory.itemExists('bread') == nil)
throws = false; started = false; assert(Inventory.count(42, 'flour') == nil)
started = true
assert(Inventory.count(0, 'flour') == nil and Inventory.count(42, 'bad item') == nil)
plan.ingredients[2] = { item = 'flour', quantity = 1 }
assert(Inventory.inspectPlan(42, plan) == nil)
for _, ingredients in ipairs({
    { [1] = { item = 'flour', quantity = 1 }, [3] = { item = 'water', quantity = 1 } },
    { [1] = { item = 'flour', quantity = 1 }, hidden = { item = 'water', quantity = 1 } },
    { { item = 'flour', quantity = 1 }, { item = 'water', quantity = -1 } },
}) do
    throws = true -- Invalid plans must fail before calling any provider export.
    local value, errorCode = Inventory.inspectPlan(42, { outputItem = 'bread', ingredients = ingredients })
    assert(value == nil and errorCode == 'invalid_plan')
end
throws = false
FoodBusiness.Inventory.resource = 'invalid/resource'
assert(not Inventory.capabilities().configured)
print('inventory adapter and read-only availability contracts passed')
