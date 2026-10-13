-- SQL-owned stock transactions. Never mutates ox_inventory itself.
-- Execute as one MySQL.transaction.await batch to avoid partial state.
local Engine = {}

local function item(value)
    return type(value) == 'string' and #value >= 2 and #value <= 64
        and value:match('^[%w_%-]+$') ~= nil
end
local function quantity(value)
    return type(value) == 'number' and value == math.floor(value)
        and value > 0 and value <= 100000
end
local function validPlan(plan)
    if type(plan) ~= 'table' or not item(plan.outputItem)
        or not quantity(plan.outputQuantity)
        or type(plan.ingredients) ~= 'table'
        or #plan.ingredients < 1 or #plan.ingredients > 16 then return false end
    local seen, count = {}, 0
    for key, row in pairs(plan.ingredients) do
        if type(key) ~= 'number' or key < 1 or key > #plan.ingredients
            or key ~= math.floor(key) or type(row) ~= 'table'
            or not item(row.item) or not quantity(row.quantity)
            or seen[row.item] then return false end
        seen[row.item] = true
        count = count + 1
    end
    return count == #plan.ingredients
end

function Engine.validate(plan)
    return validPlan(plan)
end

-- SQL-owned stock only. The caller must explicitly inject a trusted procedure
-- executor; never fall back to separate ox_inventory RemoveItem/AddItem calls.
local function identity(payload)
    return type(payload) == 'table'
        and type(payload.jobId) == 'string'
        and payload.jobId:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$') ~= nil
        and type(payload.ownerId) == 'string' and #payload.ownerId >= 2
        and #payload.ownerId <= 80
        and type(payload.planKey) == 'string' and #payload.planKey >= 1
        and #payload.planKey <= 1600
end

local procedures = {
    reserve = 'tsfb_stock_reserve',
    commit = 'tsfb_stock_commit',
    release = 'tsfb_stock_release',
}

local function execute(operation, payload, executor, encode)
    if not identity(payload) then return nil, 'invalid_payload' end
    if operation == 'reserve' and not validPlan(payload.plan) then
        return nil, 'invalid_plan'
    end
    if type(executor) ~= 'function' then
        return nil, 'checked_transaction_executor_required'
    end
    local args = { payload.jobId, payload.ownerId, payload.planKey }
    if operation == 'reserve' then
        if type(encode) ~= 'function' then return nil, 'json_encoder_unavailable' end
        local ok, serialized = pcall(encode, payload.plan)
        if not ok or type(serialized) ~= 'string' or #serialized > 65535 then
            return nil, 'invalid_plan'
        end
        args[4] = serialized
    end
    local ok, result = pcall(executor, procedures[operation], args)
    if not ok then return nil, 'transaction_failed' end
    if type(result) ~= 'table' or result.job_id ~= payload.jobId
        or result.owner_id ~= payload.ownerId
        or result.plan_key ~= payload.planKey then
        return nil, 'invalid_transaction_receipt'
    end
    local states = {
        reserve = { reserved = true, committed = true, released = true },
        commit = { committed = true },
        release = { released = true },
    }
    if not states[operation][result.state] then
        return nil, 'invalid_transaction_state'
    end
    return { jobId = result.job_id, ownerId = result.owner_id,
        planKey = result.plan_key, state = result.state }
end

function Engine.reserve(payload, executor, encode)
    return execute('reserve', payload, executor, encode)
end
function Engine.commit(payload, executor)
    return execute('commit', payload, executor)
end
function Engine.release(payload, executor)
    return execute('release', payload, executor)
end

return Engine
