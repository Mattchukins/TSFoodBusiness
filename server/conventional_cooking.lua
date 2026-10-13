-- Conventional ox_inventory cooking transaction. No atomicity or crash durability
-- is claimed. Caller must authorize actor, recipe, station and proximity.
ConventionalCooking = {}
local busy = {}
local function validItem(value)
    return type(value) == 'string' and #value >= 2 and #value <= 64
        and value:match('^[%w_%-]+$') ~= nil
end
local function positive(value)
    return type(value) == 'number' and value == math.floor(value)
        and value >= 1 and value <= 100000
end
local function validate(plan)
    if type(plan) ~= 'table' or not validItem(plan.outputItem)
        or not positive(plan.outputQuantity) or type(plan.ingredients) ~= 'table'
        or #plan.ingredients < 1 or #plan.ingredients > 16 then return false end
    local seen, size = {}, #plan.ingredients
    for index, entry in pairs(plan.ingredients) do
        if type(index) ~= 'number' or index ~= math.floor(index) or index < 1 or index > size
            or type(entry) ~= 'table' or not validItem(entry.item)
            or not positive(entry.quantity) or seen[entry.item] then return false end
        seen[entry.item] = true
    end
    for i = 1, size do if not plan.ingredients[i] then return false end end
    return true
end
-- A single server-side invocation only. Never call from an unvalidated NUI
-- payload; plan must come from the server's authoritative recipe resolver.
function ConventionalCooking.produce(src, plan, authorize)
    if type(src) ~= 'number' or src < 1 or src ~= math.floor(src)
        or not validate(plan) or type(authorize) ~= 'function' then
        return { ok = false, error = 'invalid_request' }
    end
    if busy[src] then return { ok = false, error = 'cooking_busy' } end
    busy[src] = true
    local ok, result = pcall(function()
        if authorize(src, plan) ~= true then return { ok = false, error = 'forbidden' } end
        local capacity, capacityError = Inventory.standardOxCanCarry(src, plan.outputItem, plan.outputQuantity)
        if capacity ~= true then
            return { ok = false, error = capacity == nil and capacityError or 'output_full' }
        end
        local inspection, reason = Inventory.inspectPlan(src, plan)
        if not inspection then return { ok = false, error = reason } end
        if not inspection.available then return { ok = false, error = 'insufficient_ingredients' } end
        local removed = {}
        for _, entry in ipairs(plan.ingredients) do
            -- Re-check access immediately before each irreversible mutation.
            if authorize(src, plan) ~= true then
                local restored = true
                for i = #removed, 1, -1 do
                    if Inventory.standardOxAdd(src, removed[i].item, removed[i].quantity) ~= true then
                        restored = false
                    end
                end
                return { ok = false, error = restored and 'forbidden' or 'manual_inventory_recovery_required' }
            end
            local done, removeError = Inventory.standardOxRemove(src, entry.item, entry.quantity)
            if done ~= true then
                -- A thrown export or malformed result has an unknown mutation
                -- outcome. Do not blindly refund the failed ingredient.
                if done == nil then
                    return { ok = false, error = 'manual_inventory_recovery_required' }
                end
                local restored = true
                for i = #removed, 1, -1 do
                    if Inventory.standardOxAdd(src, removed[i].item, removed[i].quantity) ~= true then
                        restored = false
                    end
                end
                return { ok = false, error = restored and (removeError or 'remove_failed')
                    or 'manual_inventory_recovery_required' }
            end
            removed[#removed + 1] = entry
        end
        if authorize(src, plan) ~= true then
            local restored = true
            for i = #removed, 1, -1 do
                if Inventory.standardOxAdd(src, removed[i].item, removed[i].quantity) ~= true then
                    restored = false
                end
            end
            return { ok = false, error = restored and 'forbidden' or 'manual_inventory_recovery_required' }
        end
        local awarded, awardError = Inventory.standardOxAdd(src, plan.outputItem, plan.outputQuantity)
        if awarded == true then return { ok = true } end
        -- Unknown AddItem outcome may already have awarded food. Never refund
        -- ingredients and risk duplicating value without operator inspection.
        if awarded == nil then
            return { ok = false, error = 'manual_inventory_recovery_required' }
        end
        local restored = true
        for i = #removed, 1, -1 do
            if Inventory.standardOxAdd(src, removed[i].item, removed[i].quantity) ~= true then
                restored = false
            end
        end
        return { ok = false, error = restored and (awardError or 'output_delivery_failed')
            or 'manual_inventory_recovery_required' }
    end)
    busy[src] = nil
    if not ok then
        print(('[TSFoodBusiness] uncertain conventional cooking outcome for source %s: %s'):format(src, tostring(result)))
        return { ok = false, error = 'manual_inventory_recovery_required' }
    end
    if result.error == 'manual_inventory_recovery_required' then
        print(('[TSFoodBusiness] manual inventory recovery required for source %s'):format(src))
    end
    return result
end

-- Resolve the recipe and station exclusively on the server. This entrypoint
-- remains opt-in until duration, replay and recovery are integrated.
function ConventionalCooking.start(src, actor, data)
    if not FoodBusiness or not FoodBusiness.ConventionalCookingEnabled then
        return { ok = false, error = 'cooking_disabled' }
    end
    if type(data) ~= 'table' or type(actor) ~= 'string'
        or not FoodBusiness.validJobId(data.businessId)
        or not FoodBusiness.validJobId(data.recipeId)
        or not FoodBusiness.validJobId(data.stationId)
        or type(data.batches) ~= 'number' or data.batches ~= math.floor(data.batches)
        or data.batches < 1 or data.batches > 100 then
        return { ok = false, error = 'invalid_request' }
    end
    if type(dependencies.owner) ~= 'function' or type(dependencies.plan) ~= 'function'
        or type(dependencies.near) ~= 'function' then
        return { ok = false, error = 'cooking_unavailable' }
    end
    local ok, result = pcall(function()
        if not dependencies.owner(src, actor, data.businessId) then
            return { ok = false, error = 'forbidden' }
        end
        local plan = dependencies.plan(src, data.businessId, data.recipeId, data.stationId, data.batches)
        if not validate(plan) then return { ok = false, error = 'production_plan_unavailable' } end
        if not dependencies.near(src, actor, data.businessId, data.stationId, plan) then
            return { ok = false, error = 'station_not_near' }
        end
        return ConventionalCooking.produce(src, plan, function()
            return dependencies.owner(src, actor, data.businessId)
                and dependencies.near(src, actor, data.businessId, data.stationId, plan)
        end)
    end)
    if not ok then return { ok = false, error = 'cooking_unavailable' } end
    return result
end
