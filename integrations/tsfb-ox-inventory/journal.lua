-- Read-only operator diagnostics for the durable production journal.
-- Never infers an inventory mutation from a SQL row.
local Journal = {}

local function validId(value)
    return type(value) == 'string'
        and value:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$') ~= nil
end

function Journal.inspect(jobId)
    if not validId(jobId) then return nil, 'invalid_job_id' end
    if not MySQL or not MySQL.single or not MySQL.single.await then
        return nil, 'database_unavailable'
    end
    local ok, row = pcall(function()
        return MySQL.single.await(
            'SELECT job_id, owner_id, plan_key, state, revision, updated_at FROM tsfb_ox_production_receipts WHERE job_id = ?',
            { jobId }
        )
    end)
    if not ok then return nil, 'database_unavailable' end
    if row == nil then return { found = false } end
    if type(row) ~= 'table' or row.job_id ~= jobId
        or type(row.owner_id) ~= 'string' or #row.owner_id < 2
        or type(row.plan_key) ~= 'string'
        or (row.state ~= 'intent' and row.state ~= 'reserved'
            and row.state ~= 'committed' and row.state ~= 'released')
        or type(tonumber(row.revision)) ~= 'number'
        or tonumber(row.revision) < 0
        or tonumber(row.revision) ~= math.floor(tonumber(row.revision)) then
        return nil, 'invalid_journal_row'
    end
    return {
        found = true, jobId = row.job_id, ownerId = row.owner_id,
        planKey = row.plan_key, state = row.state,
        revision = tonumber(row.revision), updatedAt = row.updated_at
    }
end

-- Only an absent claim can be safely tombstoned without touching ox_inventory.
-- This does not implement ingredient escrow or output delivery.
function Journal.inspectReceipt(payload)
    if type(payload) ~= 'table' or not validId(payload.jobId)
        or type(payload.ownerId) ~= 'string' or #payload.ownerId < 2 or #payload.ownerId > 80
        or type(payload.planKey) ~= 'string' or #payload.planKey < 1 or #payload.planKey > 1600 then
        return nil, 'invalid_payload'
    end
    local record, reason = Journal.inspect(payload.jobId)
    if not record then return nil, reason end
    if not record.found then
        return { jobId = payload.jobId, ownerId = payload.ownerId,
            planKey = payload.planKey, state = 'absent' }
    end
    if record.ownerId ~= payload.ownerId or record.planKey ~= payload.planKey then
        return nil, 'reservation_conflict'
    end
    -- No ox_inventory mutation engine exists yet: reserved/committed journal
    -- rows cannot be trusted as proof of inventory movement.
    if record.state ~= 'released' then return nil, 'reservation_unresolved' end
    return { jobId = payload.jobId, ownerId = payload.ownerId,
        planKey = payload.planKey, state = record.state }
end

function Journal.releaseAbsent(payload)
    if type(payload) ~= 'table' or not validId(payload.jobId)
        or type(payload.ownerId) ~= 'string' or #payload.ownerId < 2 or #payload.ownerId > 80
        or type(payload.planKey) ~= 'string' or #payload.planKey < 1 or #payload.planKey > 1600
        or type(payload.plan) ~= 'table' then return nil, 'invalid_payload' end
    local encodedOk, planJson = pcall(json.encode, payload.plan)
    if not encodedOk or type(planJson) ~= 'string' or #planJson > 65535 then return nil, 'invalid_payload' end
    if not MySQL or not MySQL.update or not MySQL.update.await then return nil, 'database_unavailable' end
    local ok = pcall(function()
        MySQL.update.await(
            "INSERT IGNORE INTO tsfb_ox_production_receipts (job_id, owner_id, plan_key, plan_json, state) VALUES (?, ?, ?, ?, 'released')",
            { payload.jobId, payload.ownerId, payload.planKey, planJson }
        )
    end)
    if not ok then return nil, 'database_unavailable' end
    local receipt, reason = Journal.inspect(payload.jobId)
    if not receipt then return nil, reason end
    if not receipt.found or receipt.ownerId ~= payload.ownerId
        or receipt.planKey ~= payload.planKey or receipt.state ~= 'released' then
        return nil, 'reservation_conflict'
    end
    return { jobId = payload.jobId, ownerId = payload.ownerId,
        planKey = payload.planKey, state = 'released' }
end

return Journal
