Inventory = {}

local function itemName(item)
    return type(item) == 'string' and #item >= 2 and #item <= 64 and item:match('^[%w_%-]+$') ~= nil
end
local function integer(value, maximum)
    return type(value) == 'number' and value == value and value >= 0 and value <= maximum and value == math.floor(value)
end
local function provider()
    local config = FoodBusiness.Inventory
    if type(config) ~= 'table' or config.provider ~= 'custom' or type(config.resource) ~= 'string'
        or not config.resource:match('^[%w_%-]+$') or GetResourceState(config.resource) ~= 'started'
        or type(config.itemExistsExport) ~= 'string' or not config.itemExistsExport:match('^[%w_]+$')
        or type(config.countExport) ~= 'string' or not config.countExport:match('^[%w_]+$') then return nil end
    return config
end
function Inventory.capabilities()
    return { configured = provider() ~= nil, itemLookup = provider() ~= nil, countRead = provider() ~= nil,
        reservation = false, atomicProduction = false, compensation = false }
end
function Inventory.itemExists(item)
    if not itemName(item) then return nil, 'invalid_item' end
    local config = provider()
    if not config then return nil, 'inventory_unavailable' end
    local ok, exists = pcall(function()
        local proxy = exports[config.resource]
        return proxy[config.itemExistsExport](proxy, item)
    end)
    if not ok or type(exists) ~= 'boolean' then return nil, 'inventory_error' end
    return exists
end
function Inventory.count(src, item)
    if not integer(src, 2147483647) or src == 0 or not itemName(item) then return nil, 'invalid_arguments' end
    local config = provider()
    if not config then return nil, 'inventory_unavailable' end
    local ok, count = pcall(function()
        local proxy = exports[config.resource]
        return proxy[config.countExport](proxy, src, item)
    end)
    if not ok or not integer(count, 2147483647) then return nil, 'inventory_error' end
    return count
end
-- Read-only snapshot. Availability can change immediately after this function returns.
function Inventory.inspectPlan(src, plan)
    if type(plan) ~= 'table' or type(plan.ingredients) ~= 'table' or #plan.ingredients < 1 or #plan.ingredients > 16
        or not itemName(plan.outputItem) then return nil, 'invalid_plan' end
    local outputExists, outputError = Inventory.itemExists(plan.outputItem)
    if outputExists == nil then return nil, outputError end
    if not outputExists then return nil, 'unknown_output_item' end
    local rows, seen, available = {}, {}, true
    for _, entry in ipairs(plan.ingredients) do
        if type(entry) ~= 'table' or not itemName(entry.item) or seen[entry.item]
            or not integer(entry.quantity, 100000) or entry.quantity == 0 then return nil, 'invalid_plan' end
        seen[entry.item] = true
        local exists, lookupError = Inventory.itemExists(entry.item)
        if exists == nil then return nil, lookupError end
        if not exists then return nil, 'unknown_ingredient' end
        local count, countError = Inventory.count(src, entry.item)
        if count == nil then return nil, countError end
        local enough = count >= entry.quantity
        available = available and enough
        rows[#rows + 1] = { item = entry.item, required = entry.quantity, available = count, missing = math.max(0, entry.quantity - count) }
    end
    return { available = available, ingredients = rows, outputItem = plan.outputItem, reservation = false }
end
