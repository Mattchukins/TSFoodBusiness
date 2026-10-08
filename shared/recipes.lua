FoodBusiness = FoodBusiness or {}

function FoodBusiness.validIngredients(ingredients)
    if type(ingredients) ~= 'table' or #ingredients < 1 or #ingredients > 16 then return false end
    local count, seen = 0, {}
    for key in pairs(ingredients) do
        if type(key) ~= 'number' or key ~= math.floor(key) or key < 1 or key > #ingredients then return false end
        count = count + 1
    end
    if count ~= #ingredients then return false end
    for _, entry in ipairs(ingredients) do
        if type(entry) ~= 'table' then return false end
        for key in pairs(entry) do if key ~= 'item' and key ~= 'quantity' then return false end end
        if type(entry.item) ~= 'string' or #entry.item < 2 or #entry.item > 64
            or not entry.item:match('^[%w_%-]+$') or seen[entry.item]
            or type(entry.quantity) ~= 'number' or entry.quantity ~= math.floor(entry.quantity)
            or entry.quantity < 1 or entry.quantity > 1000 then return false end
        seen[entry.item] = true
    end
    return true
end

function FoodBusiness.validProductionProfile(profile)
    if type(profile) ~= 'table' then return false end
    for key in pairs(profile) do
        if key ~= 'stationType' and key ~= 'outputItem' and key ~= 'outputQuantity' and key ~= 'durationSeconds' then return false end
    end
    local function integer(value, maximum)
        return type(value) == 'number' and value == value and value >= 1 and value <= maximum and value == math.floor(value)
    end
    return type(profile.stationType) == 'string' and FoodBusiness.StationTypes[profile.stationType] == true
        and type(profile.outputItem) == 'string' and #profile.outputItem >= 2 and #profile.outputItem <= 64
        and profile.outputItem:match('^[%w_%-]+$') ~= nil
        and integer(profile.outputQuantity, 100) and integer(profile.durationSeconds, 3600)
end

-- Pure planning only: never removes ingredients or creates output items.
function FoodBusiness.planProduction(ingredients, profile, stationType, batches)
    if not FoodBusiness.validIngredients(ingredients) or not FoodBusiness.validProductionProfile(profile)
        or type(batches) ~= 'number' or batches ~= batches or batches < 1 or batches > 100
        or batches ~= math.floor(batches) or stationType ~= profile.stationType then return nil end
    local required = {}
    for _, ingredient in ipairs(ingredients) do
        required[#required + 1] = { item = ingredient.item, quantity = ingredient.quantity * batches }
    end
    return { ingredients = required, outputItem = profile.outputItem, outputQuantity = profile.outputQuantity * batches,
        durationSeconds = profile.durationSeconds * batches, stationType = profile.stationType, batches = batches }
end
