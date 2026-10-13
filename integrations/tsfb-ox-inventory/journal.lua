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

return Journal
