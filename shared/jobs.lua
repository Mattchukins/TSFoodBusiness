FoodBusiness = FoodBusiness or {}
FoodBusiness.JobStates = {
    reserving = true, cooking = true, committing = true, releasing = true,
    completed = true, cancelled = true,
}
local transitions = {
    reserving = { cooking = true, releasing = true, completed = true, cancelled = true },
    cooking = { committing = true, releasing = true, completed = true, cancelled = true },
    committing = { completed = true, releasing = true, cancelled = true },
    releasing = { cancelled = true, completed = true },
}
function FoodBusiness.validJobId(id)
    return type(id) == 'string' and id:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$') ~= nil
end
function FoodBusiness.validJobToken(token)
    return type(token) == 'string' and #token >= 8 and #token <= 64 and token:match('^[%w%-]+$') ~= nil
end
function FoodBusiness.canTransitionJob(from, to)
    return transitions[from] ~= nil and transitions[from][to] == true
end
function FoodBusiness.jobTerminal(state)
    return state == 'completed' or state == 'cancelled'
end
-- Canonical, delimiter-safe immutable plan identity for adapter replay verification.
function FoodBusiness.productionPlanKey(plan)
    if type(plan) ~= 'table' or type(plan.outputQuantity) ~= 'number'
        or type(plan.durationSeconds) ~= 'number' or type(plan.batches) ~= 'number' then return nil end
    local profile = { stationType = plan.stationType, outputItem = plan.outputItem,
        outputQuantity = plan.outputQuantity and plan.outputQuantity / (plan.batches or 0),
        durationSeconds = plan.durationSeconds and plan.durationSeconds / (plan.batches or 0) }
    local batches = plan.batches
    if type(batches) ~= 'number' or batches < 1 or batches > 100 or batches ~= math.floor(batches)
        or not FoodBusiness.validProductionProfile(profile) or type(plan.ingredients) ~= 'table' then return nil end
    local original, count = {}, 0
    for key, entry in pairs(plan.ingredients) do
        if type(key) ~= 'number' or key ~= math.floor(key) or key < 1 or key > #plan.ingredients
            or type(entry) ~= 'table' or type(entry.quantity) ~= 'number' then return nil end
        original[key] = { item = entry.item, quantity = entry.quantity / batches }
        count = count + 1
    end
    if count ~= #plan.ingredients or not FoodBusiness.validIngredients(original) then return nil end
    local parts = { plan.stationType, string.format('%d', batches), plan.outputItem .. ':' .. string.format('%d', plan.outputQuantity), string.format('%d', plan.durationSeconds) }
    local ingredients = {}
    for _, entry in ipairs(plan.ingredients) do ingredients[#ingredients + 1] = entry.item .. ':' .. string.format('%d', entry.quantity) end
    table.sort(ingredients)
    for _, entry in ipairs(ingredients) do parts[#parts + 1] = entry end
    return table.concat(parts, '|')
end
function FoodBusiness.jobDeadline(now, duration)
    if type(now) ~= 'number' or now < 1 or now > 2147123647 or now ~= math.floor(now)
        or type(duration) ~= 'number' or duration < 1 or duration > 360000 or duration ~= math.floor(duration) then return nil end
    return now + duration
end
