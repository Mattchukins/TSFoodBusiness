-- Pure time and replay helpers for future conventional cooking jobs.
-- No inventory mutation or persistence is performed in this module.
ConventionalTiming = {}
local function whole(value, minimum, maximum)
    return type(value) == 'number' and value == math.floor(value)
        and value >= minimum and value <= maximum
end
function ConventionalTiming.deadline(now, duration)
    if not whole(now, 0, 2147480047) or not whole(duration, 1, 3600 * 100) then
        return nil
    end
    local deadline = now + duration
    if deadline > 2147483647 then return nil end
    return deadline
end
function ConventionalTiming.ready(now, deadline)
    if not whole(now, 0, 2147483647) or not whole(deadline, 1, 2147483647) then
        return nil
    end
    return now >= deadline
end
-- Duplicate tokens must match all immutable request dimensions.
function ConventionalTiming.sameRequest(previous, actor, data)
    if type(previous) ~= 'table' or type(data) ~= 'table'
        or type(actor) ~= 'string' then return false end
    return previous.actor_id == actor
        and previous.business_id == data.businessId
        and previous.recipe_id == data.recipeId
        and previous.station_id == data.stationId
        and previous.request_token == data.token
        and previous.batches == data.batches
end
