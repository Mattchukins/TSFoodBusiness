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

-- Atomic stock consumption requires a conditional UPDATE and a rollback on
-- ANY affected-row mismatch. oxmysql transaction batches cannot assert
-- affected rows between statements, so this implementation deliberately
-- requires a transactional stored procedure or a dedicated SQL transaction
-- executor with checked row counts.
function Engine.reserve()
    return nil, 'checked_transaction_executor_required'
end
function Engine.commit()
    return nil, 'checked_transaction_executor_required'
end
function Engine.release()
    return nil, 'checked_transaction_executor_required'
end

return Engine
