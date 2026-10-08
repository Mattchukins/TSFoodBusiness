FoodBusiness = FoodBusiness or {}

-- Local clock minute supplied by the caller. End boundary is exclusive.
function FoodBusiness.isWithinHours(opensMinute, closesMinute, minute)
    local function valid(value)
        return type(value) == 'number' and value == math.floor(value) and value >= 0 and value <= 1439
    end
    if not valid(opensMinute) or not valid(closesMinute) or not valid(minute)
        or opensMinute == closesMinute then return nil end
    if opensMinute < closesMinute then
        return minute >= opensMinute and minute < closesMinute
    end
    return minute >= opensMinute or minute < closesMinute
end
