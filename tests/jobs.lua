dofile('shared/config.lua')
dofile('shared/stations.lua')
dofile('shared/recipes.lua')
dofile('shared/jobs.lua')
local businessId = '12345678-1234-1234-1234-123456789abc'
local stationId = '22345678-1234-1234-1234-123456789abc'
local recipeId = '32345678-1234-1234-1234-123456789abc'
local actor, now, near, owned = 'owner-42', 1000, true, true
local originalTime = os.time
os.time = function() return now end
local plan = { stationType = 'oven', batches = 2, outputItem = 'bread', outputQuantity = 4,
    durationSeconds = 90, ingredients = { { item = 'flour', quantity = 6 } } }
local key = assert(FoodBusiness.productionPlanKey(plan))
assert(FoodBusiness.productionPlanKey({}) == nil)
assert(FoodBusiness.productionPlanKey({ batches = 1, durationSeconds = 'bad', outputQuantity = 1 }) == nil)
assert(FoodBusiness.jobDeadline(1000, 90) == 1090)
assert(not FoodBusiness.jobDeadline(0, 1))
assert(FoodBusiness.canTransitionJob('cooking', 'committing'))
assert(not FoodBusiness.canTransitionJob('completed', 'cooking'))
assert(not FoodBusiness.canTransitionJob('cooking', 'reserving'))
assert(not FoodBusiness.validJobId(string.rep('-', 36)))
assert(not FoodBusiness.validJobToken('short'))
local rows, audit, counter, transactionFails, casFails = {}, {}, 0, false, false
local function clone(value)
    if type(value) ~= 'table' then return value end
    local out = {}; for k, v in pairs(value) do out[k] = clone(v) end; return out
end
-- A deterministic codec fixture preserving immutable plan snapshots.
json = { encode = function(value) if value.ingredients then return 'saved-plan' end; return '{}' end,
    decode = function(value) assert(value == 'saved-plan'); return clone(plan) end }
MySQL = {
    scalar = { await = function() counter = counter + 1; return string.format('%08x-1234-1234-1234-123456789abc', counter) end },
    single = { await = function(query, values)
        if query:find('request_token') then
            for _, row in pairs(rows) do if row.actor_id == values[1] and row.request_token == values[2] then return clone(row) end end
        else return clone(rows[values[1]]) end
    end },
    query = { await = function(_, values)
        local out = {}; for _, row in pairs(rows) do
            if row.business_id == values[1] and row.actor_id == values[2] then out[#out + 1] = clone(row) end
        end; return out
    end },
    transaction = { await = function(statements)
        if transactionFails then return false end
        local first, event = statements[1], statements[2]
        local v = first.values
        if first.query:find('INSERT INTO tsfb_cooking_jobs', 1, true) then
            for _, row in pairs(rows) do
                if (row.actor_id == v[3] and row.request_token == v[6]) or row.station_slot == v[12] or row.actor_slot == v[13] then return false end
            end
            rows[v[1]] = { id = v[1], business_id = v[2], actor_id = v[3], recipe_id = v[4], station_id = v[5],
                request_token = v[6], batches = v[7], plan_json = v[8], plan_key = v[9], provider_resource = v[10],
                state = v[11], revision = 0, ready_at = 0, station_slot = v[12], actor_slot = v[13] }
            assert(not audit[event.values[4]]); audit[event.values[4]] = true
        else
            local row = rows[v[5]]
            if not casFails and row and row.state == v[6] and row.revision == v[7] then
                row.state = v[1]; row.revision = row.revision + 1; row.ready_at = v[2]
                row.station_slot = v[3] ~= '' and v[3] or nil; row.actor_slot = v[4] ~= '' and v[4] or nil
                assert(event.query:find('SELECT', 1, true) and event.values[5] == row.state and event.values[6] == row.revision)
                assert(not audit[event.values[2]]); audit[event.values[2]] = true
            end
        end
        return true
    end },
}
local receipts, reserves, commits, releases = {}, 0, 0, 0
local reserveLost, commitLost, outputFull, inspectThrows, inspectHook = false, false, false, false, nil
Inventory = {
    capabilities = function() return { atomicProduction = FoodBusiness.Inventory.mutationsVerified } end,
    inspectReservation = function(job)
        if inspectThrows then error('provider unavailable') end
        if inspectHook then inspectHook() end
        return { state = receipts[job.id] or 'absent' }
    end,
    reserve = function(job)
        if not receipts[job.id] then receipts[job.id] = 'reserved'; reserves = reserves + 1 end
        if reserveLost then return nil, 'inventory_outcome_unknown' end
        return { state = receipts[job.id] }
    end,
    commit = function(job)
        if outputFull then return { state = 'reserved', error = 'output_full' } end
        if receipts[job.id] == 'reserved' then receipts[job.id] = 'committed'; commits = commits + 1 end
        if commitLost then return nil, 'inventory_outcome_unknown' end
        return { state = receipts[job.id] }
    end,
    release = function(job)
        if receipts[job.id] ~= 'committed' and receipts[job.id] ~= 'released' then receipts[job.id] = 'released'; releases = releases + 1 end
        return { state = receipts[job.id] }
    end,
}
dofile('server/jobs.lua')
local function configure()
    CookingJobs.configure({ owner = function(src, identity, id) return owned and src == 42 and identity == actor and id == businessId end,
        plan = function() return clone(plan) end, near = function() return near end })
end
configure()
local function start(token, batches)
    return CookingJobs.start(42, actor, { businessId = businessId, recipeId = recipeId, stationId = stationId, batches = batches or 2, token = token })
end
local function act(id, action)
    return CookingJobs.act(42, actor, { businessId = businessId, jobId = id }, action)
end
assert(start('request-0001').error == 'cooking_disabled' and counter == 0)
FoodBusiness.Modules.kitchen = true; FoodBusiness.Inventory.mutationsVerified = true; FoodBusiness.Inventory.resource = 'custom_inventory'
near = false; assert(start('request-0001').error == 'station_not_near' and reserves == 0)
near = true; owned = false; assert(start('request-0001').error == 'forbidden' and reserves == 0)
owned = true; transactionFails = true; assert(start('request-0001').error == 'job_conflict_or_database_error' and reserves == 0)
transactionFails = false
-- Unsupported actions must never consult the provider or mutate pending jobs.
inspectThrows = true
assert(act(businessId, 'unsupported').error == 'invalid_action')
inspectThrows = false
assert(CookingJobs.act(42, actor, nil, 'inspect').error == 'invalid_payload')
assert(CookingJobs.start(42, actor, nil).error == 'invalid_payload')
assert(CookingJobs.start(42, nil, {}).error == 'invalid_payload')
assert(CookingJobs.list(42, actor, nil).error == 'invalid_payload')
assert(CookingJobs.list(42, nil, businessId).error == 'invalid_payload')
assert(CookingJobs.act(42, nil, { businessId = businessId, jobId = businessId }, 'inspect').error == 'invalid_payload')
local started = start('request-0001'); assert(started.ok and started.job.state == 'cooking' and started.job.readyAt == 1090)
local id = started.job.id
assert(start('request-0001').job.id == id and reserves == 1)
assert(start('request-0001', 3).error == 'replay_mismatch')
assert(start('request-0002').error == 'job_conflict_or_database_error' and reserves == 1)
local originalActor = actor; actor = 'other-owner'
assert(start('request-0002').error == 'job_conflict_or_database_error' and reserves == 1)
actor = originalActor
inspectHook = function() assert(act(id, 'inspect').error == 'job_busy') end
assert(act(id, 'inspect').ok)
inspectHook = nil
assert(act(id, 'finish').error == 'cooking_not_ready' and commits == 0)
now = 1090; near = false; assert(act(id, 'finish').error == 'station_not_near' and commits == 0)
near = true; outputFull = true
local full = act(id, 'finish'); assert(full.error == 'output_full' and full.job.state == 'committing' and commits == 0)
outputFull = false; commitLost = true
assert(act(id, 'finish').error == 'inventory_outcome_unknown' and commits == 1)
commitLost = false
assert(act(id, 'inspect').job.state == 'completed')
assert(act(id, 'finish').job.state == 'completed' and commits == 1)
assert(rows[id].station_slot == nil and rows[id].actor_slot == nil)
local second = start('request-0002'); assert(second.ok and reserves == 2)
assert(act(second.job.id, 'cancel').job.state == 'cancelled' and releases == 1)
assert(act(second.job.id, 'cancel').job.state == 'cancelled' and releases == 1)
reserveLost = true
local third = start('request-0003'); assert(third.error == 'inventory_outcome_unknown' and third.job.state == 'reserving')
reserveLost = false; now = 1200
-- Simulate resource restart by reloading all in-memory locks/service code.
dofile('server/jobs.lua'); configure()
local recovered = act(third.job.id, 'inspect'); assert(recovered.job.state == 'cooking' and recovered.job.readyAt == 1290 and reserves == 3)
assert(act(third.job.id, 'finish').error == 'cooking_not_ready')
owned = false; assert(act(third.job.id, 'cancel').error == 'forbidden')
owned = true; inspectThrows = true; assert(act(third.job.id, 'inspect').error == 'job_outcome_unknown')
inspectThrows = false
assert(act(third.job.id, 'cancel').job.state == 'cancelled')
local fourth = start('request-0004'); assert(fourth.ok)
now = fourth.job.readyAt
inspectHook = function() near = false end
assert(act(fourth.job.id, 'finish').error == 'station_not_near' and commits == 1)
inspectHook = nil; near = true
casFails = true
assert(act(fourth.job.id, 'finish').error == 'job_reconciliation_required' and commits == 1)
casFails = false
assert(act(fourth.job.id, 'finish').ok and commits == 2)
assert(CookingJobs.list(42, actor, businessId).ok)
local queryOriginal = MySQL.query.await
MySQL.query.await = function() error('database unavailable') end
assert(CookingJobs.list(42, actor, businessId).error == 'database_error')
MySQL.query.await = function() return nil end
assert(CookingJobs.list(42, actor, businessId).error == 'database_error')
MySQL.query.await = queryOriginal
local savedReadyAt = rows[fourth.job.id].ready_at
rows[fourth.job.id].ready_at = 'invalid'
assert(CookingJobs.list(42, actor, businessId).error == 'invalid_saved_job')
rows[fourth.job.id].ready_at = savedReadyAt
assert(not CookingJobs.list(42, 'wrong-owner', businessId).ok)
local reentered = false
inspectHook = function()
    reentered = true
    assert(start('request-nested').error == 'job_busy')
end
local fifth = start('request-0005')
assert(fifth.ok and reentered)
inspectHook = nil
assert(act(fifth.job.id, 'cancel').ok)
local reserveOriginal = Inventory.reserve
Inventory.reserve = function(job)
    local receipt = reserveOriginal(job)
    transactionFails = true -- Provider reserve succeeds, database acknowledgement fails.
    return receipt
end
local sixth = start('request-0006')
assert(sixth.error == 'job_reconciliation_required' and sixth.job.state == 'reserving')
transactionFails = false; Inventory.reserve = reserveOriginal
local sixthRecovered = act(sixth.job.id, 'inspect')
assert(sixthRecovered.ok and sixthRecovered.job.state == 'cooking')
now = sixthRecovered.job.readyAt
local commitOriginal = Inventory.commit
Inventory.commit = function(job)
    local receipt = commitOriginal(job)
    transactionFails = true -- Output exists; local job still says committing.
    return receipt
end
local sixthFinished = act(sixth.job.id, 'finish')
assert(sixthFinished.error == 'job_reconciliation_required' and receipts[sixth.job.id] == 'committed')
local committedCount = commits
transactionFails = false; Inventory.commit = commitOriginal
dofile('server/jobs.lua'); configure()
assert(act(sixth.job.id, 'inspect').job.state == 'completed' and commits == committedCount)
Inventory.reserve = function() return { state = 'absent', error = 'insufficient_stock' } end
local seventh = start('request-0007')
assert(seventh.error == 'insufficient_stock' and seventh.job.state == 'reserving')
assert(act(seventh.job.id, 'cancel').job.state == 'cancelled')
Inventory.reserve = reserveOriginal
FoodBusiness.Inventory.mutationsVerified = false
assert(CookingJobs.list(42, actor, businessId).cookingEnabled == false)
os.time = originalTime
print('durable cooking jobs: timer, replay, locks, slots, capacity, cancellation, uncertain outcomes and restart recovery passed (mocked)')
