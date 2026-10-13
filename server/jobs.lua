CookingJobs = {}
local dependencies, locks = {}, {}
function CookingJobs.configure(value) dependencies = value end
local function enabled()
    return FoodBusiness.Modules.kitchen == true and FoodBusiness.Modules.recipes == true
        and FoodBusiness.Modules.stations == true and Inventory.capabilities().atomicProduction == true
end
local function decodePlan(job)
    local ok, plan = pcall(json.decode, job.plan_json)
    if not ok or FoodBusiness.productionPlanKey(plan) ~= job.plan_key then return nil end
    return plan
end
local function view(job)
    local plan = decodePlan(job)
    local revision, readyAt = tonumber(job.revision), tonumber(job.ready_at)
    if not plan or not FoodBusiness.JobStates[job.state] or not FoodBusiness.validJobId(job.id)
        or not FoodBusiness.validJobId(job.recipe_id) or not FoodBusiness.validJobId(job.station_id)
        or not revision or revision < 0 or revision > 2147483647 or revision ~= math.floor(revision)
        or not readyAt or readyAt < 0 or readyAt > 2147483647 or readyAt ~= math.floor(readyAt)
        or ((job.state == 'cooking' or job.state == 'committing') and readyAt == 0) then return nil end
    return { id = job.id, recipeId = job.recipe_id, stationId = job.station_id, batches = tonumber(job.batches),
        state = job.state, readyAt = tonumber(job.ready_at), revision = tonumber(job.revision), productionPlan = plan,
        canMutate = enabled(), serverNow = os.time() }
end
local function owned(src, actor, businessId)
    return dependencies.owner and dependencies.owner(src, actor, businessId) == true
end
local function read(id)
    return MySQL.single.await('SELECT * FROM tsfb_cooking_jobs WHERE id = ?', { id })
end
local function locked(key, callback)
    if locks[key] then return { ok = false, error = 'job_busy' } end
    locks[key] = true
    local ok, result = pcall(callback)
    locks[key] = nil
    if not ok then return { ok = false, error = 'job_outcome_unknown' } end
    return result
end
local function result(job, errorCode)
    return { ok = errorCode == nil, error = errorCode, job = job and view(job) or nil }
end
-- State and its audit event commit together. Revision correlations prevent duplicate events.
local function transition(job, target, readyAt)
    if not FoodBusiness.canTransitionJob(job.state, target) then return nil end
    local revision = tonumber(job.revision)
    if not revision or revision < 0 or revision ~= math.floor(revision) then return nil end
    local terminal = FoodBusiness.jobTerminal(target)
    local ok, done = pcall(function() return MySQL.transaction.await({
        { query = "UPDATE tsfb_cooking_jobs SET state = ?, revision = revision + 1, ready_at = ?, station_slot = NULLIF(?, ''), actor_slot = NULLIF(?, '') WHERE id = ? AND state = ? AND revision = ?",
            values = { target, readyAt or tonumber(job.ready_at) or 0, terminal and '' or job.station_id,
                terminal and '' or job.actor_id, job.id, job.state, revision } },
        { query = 'INSERT INTO tsfb_audit (action, actor_id, business_id, correlation_id, details) SELECT ?, actor_id, business_id, ?, ? FROM tsfb_cooking_jobs WHERE id = ? AND state = ? AND revision = ?',
            values = { 'cooking.' .. target, 'cook:' .. job.id .. ':' .. (revision + 1),
                json.encode({ jobId = job.id, from = job.state, state = target }), job.id, target, revision + 1 } },
    }) end)
    if not ok or not done then return nil end
    local updated = read(job.id)
    if not updated or updated.state ~= target or tonumber(updated.revision) ~= revision + 1 then return nil end
    return updated
end
local function reconcileReceipt(job, receipt)
    -- A conflicting durable receipt is not a successful reconciliation.
    -- Hold the job for operator investigation rather than silently accepting it.
    if job.state == 'completed' and receipt.state ~= 'committed' then return nil end
    if job.state == 'cancelled' and receipt.state ~= 'released' then return nil end
    if receipt.state == 'committed' then
        return job.state == 'completed' and job or transition(job, 'completed')
    elseif receipt.state == 'released' then
        return job.state == 'cancelled' and job or transition(job, 'cancelled')
    elseif receipt.state == 'reserved' and job.state == 'reserving' then
        local plan = decodePlan(job)
        if not plan then return nil end
        -- If the reserve result was lost, restart the full duration; never shorten it.
        local deadline = FoodBusiness.jobDeadline(os.time(), plan.durationSeconds)
        if not deadline then return nil end
        return transition(job, 'cooking', deadline)
    end
    return job
end
local function resumeReservation(src, actor, job)
    if FoodBusiness.jobTerminal(job.state) or job.state ~= 'reserving' then return result(job) end
    if not owned(src, actor, job.business_id) then return result(nil, 'forbidden') end
    if not dependencies.near(src, actor, job.business_id, job.station_id, decodePlan(job)) then
        return result(job, 'station_not_near')
    end
    local receipt, reason = Inventory.inspectReservation(job)
    if not receipt then return result(job, reason) end
    if receipt.state == 'absent' then
        if not owned(src, actor, job.business_id) or not dependencies.near(src, actor, job.business_id, job.station_id, decodePlan(job)) then
            return result(job, 'station_not_near')
        end
        receipt, reason = Inventory.reserve(job)
        if not receipt then return result(job, reason) end
    end
    if receipt.state == 'absent' then
        return result(job, receipt.error or 'reservation_unavailable')
    end
    local updated = reconcileReceipt(job, receipt)
    return updated and result(updated) or result(job, 'job_reconciliation_required')
end
function CookingJobs.start(src, actor, data)
    if not enabled() then return result(nil, 'cooking_disabled') end
    if type(data) ~= 'table' or type(actor) ~= 'string' or #actor < 2 or #actor > 80 then
        return result(nil, 'invalid_payload')
    end
    if not FoodBusiness.validJobId(data.businessId) or not FoodBusiness.validJobId(data.recipeId)
        or not FoodBusiness.validJobId(data.stationId) or not FoodBusiness.validJobToken(data.token)
        or type(data.batches) ~= 'number' or data.batches < 1 or data.batches > 100 or data.batches ~= math.floor(data.batches) then
        return result(nil, 'invalid_payload')
    end
    return locked('actor:' .. actor, function()
        if not owned(src, actor, data.businessId) then return result(nil, 'forbidden') end
        local previous = MySQL.single.await('SELECT * FROM tsfb_cooking_jobs WHERE actor_id = ? AND request_token = ?', { actor, data.token })
        if previous then
            if previous.actor_id ~= actor or previous.business_id ~= data.businessId or previous.recipe_id ~= data.recipeId
                or previous.station_id ~= data.stationId or tonumber(previous.batches) ~= data.batches then return result(nil, 'replay_mismatch') end
            return locked('job:' .. previous.id, function() return resumeReservation(src, actor, previous) end)
        end
        local plan = dependencies.plan(src, data.businessId, data.recipeId, data.stationId, data.batches)
        local key = FoodBusiness.productionPlanKey(plan)
        if not key then return result(nil, 'production_plan_unavailable') end
        if not dependencies.near(src, actor, data.businessId, data.stationId, plan) then return result(nil, 'station_not_near') end
        local id = MySQL.scalar.await('SELECT UUID()')
        if not FoodBusiness.validJobId(id) then return result(nil, 'database_error') end
        local ok, done = pcall(function() return MySQL.transaction.await({
            { query = 'INSERT INTO tsfb_cooking_jobs (id, business_id, actor_id, recipe_id, station_id, request_token, batches, plan_json, plan_key, provider_resource, state, revision, ready_at, station_slot, actor_slot) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, ?, ?)',
                values = { id, data.businessId, actor, data.recipeId, data.stationId, data.token, data.batches,
                    json.encode(plan), key, FoodBusiness.Inventory.resource, 'reserving', data.stationId, actor } },
            { query = 'INSERT INTO tsfb_audit (action, actor_id, business_id, correlation_id, details) VALUES (?, ?, ?, ?, ?)',
                values = { 'cooking.reserving', actor, data.businessId, 'cook:' .. id .. ':0', json.encode({ jobId = id, recipeId = data.recipeId, stationId = data.stationId, batches = data.batches }) } },
        }) end)
        if not ok or not done then return result(nil, 'job_conflict_or_database_error') end
        local job = read(id)
        if not job then return result(nil, 'job_outcome_unknown') end
        return locked('job:' .. id, function() return resumeReservation(src, actor, job) end)
    end)
end
function CookingJobs.list(src, actor, businessId)
    if not FoodBusiness.validJobId(businessId) or type(actor) ~= 'string' or #actor < 2 or #actor > 80 then
        return result(nil, 'invalid_payload')
    end
    if not owned(src, actor, businessId) then return result(nil, 'forbidden') end
    local queried, rows = pcall(function()
        return MySQL.query.await('SELECT * FROM tsfb_cooking_jobs WHERE business_id = ? AND actor_id = ? ORDER BY created_at DESC, id DESC LIMIT 100', { businessId, actor })
    end)
    if not queried or type(rows) ~= 'table' then return result(nil, 'database_error') end
    local jobs = {}
    for _, row in ipairs(rows) do
        local item = view(row)
        if not item then return result(nil, 'invalid_saved_job') end
        jobs[#jobs + 1] = item
    end
    return { ok = true, jobs = jobs, cookingEnabled = enabled() }
end
function CookingJobs.act(src, actor, data, action)
    -- Reject unsupported actions before reading provider receipts or reconciling state.
    if action ~= 'inspect' and action ~= 'resume' and action ~= 'finish' and action ~= 'cancel' then
        return result(nil, 'invalid_action')
    end
    if type(data) ~= 'table' or type(actor) ~= 'string' or #actor < 2 or #actor > 80 then
        return result(nil, 'invalid_payload')
    end
    if not FoodBusiness.validJobId(data.businessId) or not FoodBusiness.validJobId(data.jobId) then return result(nil, 'invalid_payload') end
    return locked('job:' .. data.jobId, function()
        if not owned(src, actor, data.businessId) then return result(nil, 'forbidden') end
        local job = read(data.jobId)
        if not job or job.business_id ~= data.businessId or job.actor_id ~= actor then return result(nil, 'not_found') end
        if not view(job) then return result(nil, 'invalid_saved_job') end
        if FoodBusiness.jobTerminal(job.state) then return result(job) end
        if not enabled() then return result(job, 'cooking_disabled') end
        local receipt, reason = Inventory.inspectReservation(job)
        if not receipt then return result(job, reason) end
        local updated = reconcileReceipt(job, receipt)
        if not updated then return result(job, 'job_reconciliation_required') end
        job = updated
        if FoodBusiness.jobTerminal(job.state) or action == 'inspect' then return result(job) end
        if action == 'resume' then return resumeReservation(src, actor, job) end
        if action == 'finish' then
            if job.state ~= 'cooking' and job.state ~= 'committing' then return result(job, 'invalid_job_state') end
            if receipt.state ~= 'reserved' then return result(job, 'reservation_unavailable') end
            if os.time() < tonumber(job.ready_at) then return result(job, 'cooking_not_ready') end
            if not owned(src, actor, data.businessId) or not dependencies.near(src, actor, data.businessId, job.station_id, decodePlan(job)) then
                return result(job, 'station_not_near')
            end
            if job.state == 'cooking' then
                job = transition(job, 'committing')
                if not job then return result(nil, 'job_reconciliation_required') end
            end
            -- A provider call can yield; check the live player again immediately before commit.
            if not owned(src, actor, data.businessId) or not dependencies.near(src, actor, data.businessId, job.station_id, decodePlan(job)) then
                return result(job, 'station_not_near')
            end
            receipt, reason = Inventory.commit(job)
        elseif action == 'cancel' then
            if job.state ~= 'releasing' then
                job = transition(job, 'releasing')
                if not job then return result(nil, 'job_reconciliation_required') end
            end
            receipt, reason = Inventory.release(job)
        else return result(job, 'invalid_action') end
        if not receipt then return result(job, reason) end
        updated = reconcileReceipt(job, receipt)
        if not updated then return result(job, 'job_reconciliation_required') end
        if action == 'finish' and receipt.state ~= 'committed' then return result(updated, receipt.error or 'commit_pending') end
        if action == 'cancel' and receipt.state ~= 'released' and receipt.state ~= 'committed' then return result(updated, 'release_pending') end
        return result(updated)
    end)
end
