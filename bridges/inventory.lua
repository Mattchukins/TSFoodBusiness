Inventory = {}

local function itemName(item)
    return type(item) == 'string' and #item >= 2 and #item <= 64 and item:match('^[%w_%-]+$') ~= nil
end
local function integer(value, maximum)
    return type(value) == 'number' and value == value and value >= 0 and value <= maximum and value == math.floor(value)
end
local function standardOx()
    return type(FoodBusiness.Inventory) == 'table'
        and FoodBusiness.Inventory.provider == 'ox_inventory'
        and GetResourceState('ox_inventory') == 'started'
end
local function provider()
    local config = FoodBusiness.Inventory
    if standardOx() then return {
        resource = 'ox_inventory', itemExistsExport = 'Items', countExport = 'GetItemCount',
        standardOx = true,
    } end
    if type(config) ~= 'table' or config.provider ~= 'custom' or type(config.resource) ~= 'string'
        or not config.resource:match('^[%w_%-]+$') or GetResourceState(config.resource) ~= 'started'
        or type(config.itemExistsExport) ~= 'string' or not config.itemExistsExport:match('^[%w_]+$')
        or type(config.countExport) ~= 'string' or not config.countExport:match('^[%w_]+$') then return nil end
    return config
end
local function mutationProvider()
    local config = provider()
    if not config or config.standardOx or config.mutationsVerified ~= true then return nil end
    for _, key in ipairs({ 'inspectExport', 'reserveExport', 'commitExport', 'releaseExport' }) do
        if type(config[key]) ~= 'string' or not config[key]:match('^[%w_]+$') then return nil end
    end
    -- The stock ox adapter has no atomic mutation engine. A configuration
    -- override must never turn its disabled exports into advertised capability.
    if config.resource == 'tsfb-ox-inventory' then
        local ok, claims = pcall(function()
            local proxy = exports[config.resource]
            return proxy.ProductionMutationCapabilities(proxy)
        end)
        if not ok or type(claims) ~= 'table'
            or claims.atomicProduction ~= true or claims.durableEscrow ~= true
            or claims.atomicOutput ~= true or claims.restartReconciliation ~= true
            or claims.liveVerified ~= true then return nil end
    end
    return config
end
function Inventory.capabilities()
    local mutations = mutationProvider() ~= nil
    return { configured = provider() ~= nil, itemLookup = provider() ~= nil, countRead = provider() ~= nil,
        reservation = mutations, atomicProduction = mutations, compensation = false, durableRecovery = mutations, outputCapacity = mutations }
end
function Inventory.itemExists(item)
    if not itemName(item) then return nil, 'invalid_item' end
    local config = provider()
    if not config then return nil, 'inventory_unavailable' end
    local ok, exists = pcall(function()
        local proxy = exports[config.resource]
        return proxy[config.itemExistsExport](proxy, item)
    end)
    if not ok then return nil, 'inventory_error' end
    if config.standardOx then return type(exists) == 'table' end
    if type(exists) ~= 'boolean' then return nil, 'inventory_error' end
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
    -- Validate the entire dense array before invoking any provider exports.
    local length, seen = #plan.ingredients, {}
    for key, entry in pairs(plan.ingredients) do
        if type(key) ~= 'number' or key ~= math.floor(key) or key < 1 or key > length
            or type(entry) ~= 'table' or not itemName(entry.item) or seen[entry.item]
            or not integer(entry.quantity, 100000) or entry.quantity == 0 then return nil, 'invalid_plan' end
        seen[entry.item] = true
    end
    for index = 1, length do
        if plan.ingredients[index] == nil then return nil, 'invalid_plan' end
    end
    if not integer(src, 2147483647) or src == 0 then return nil, 'invalid_arguments' end
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

local function productionOperation(operation, job)
    local config = mutationProvider()
    if not config then return nil, 'inventory_mutations_disabled' end
    if type(job) ~= 'table' or not FoodBusiness.validJobId(job.id)
        or type(job.actor_id) ~= 'string' or #job.actor_id < 2 or #job.actor_id > 80
        or type(job.plan_key) ~= 'string' or #job.plan_key > 1600
        or job.provider_resource ~= config.resource then return nil, 'invalid_reservation' end
    local decoded, plan = pcall(json.decode, job.plan_json)
    if not decoded or FoodBusiness.productionPlanKey(plan) ~= job.plan_key then return nil, 'invalid_reservation' end
    local ok, receipt = pcall(function()
        local proxy = exports[config.resource]
        return proxy[config[operation .. 'Export']](proxy, {
            jobId = job.id, ownerId = job.actor_id, planKey = job.plan_key, plan = plan,
        })
    end)
    if not ok or type(receipt) ~= 'table' or receipt.jobId ~= job.id
        or receipt.ownerId ~= job.actor_id or receipt.planKey ~= job.plan_key
        or (receipt.state ~= 'absent' and receipt.state ~= 'reserved' and receipt.state ~= 'committed' and receipt.state ~= 'released') then
        return nil, 'inventory_outcome_unknown'
    end
    -- Business failures are valid only for the operation that can produce them.
    -- Inspect/release must never smuggle a mutation failure into reconciliation.
    if receipt.error ~= nil and not ((operation == 'reserve' and receipt.error == 'insufficient_stock' and receipt.state == 'absent')
        or (operation == 'commit' and receipt.error == 'output_full' and receipt.state == 'reserved')) then
        return nil, 'inventory_outcome_unknown'
    end
    return { state = receipt.state, error = receipt.error }
end
function Inventory.inspectReservation(job) return productionOperation('inspect', job) end
function Inventory.reserve(job) return productionOperation('reserve', job) end
function Inventory.commit(job) return productionOperation('commit', job) end
function Inventory.release(job) return productionOperation('release', job) end
