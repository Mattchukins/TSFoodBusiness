dofile('shared/config.lua')
dofile('shared/stations.lua')
dofile('shared/recipes.lua')
dofile('shared/jobs.lua')
local plan = { stationType = 'oven', batches = 2, outputItem = 'bread', outputQuantity = 4,
    durationSeconds = 90, ingredients = { { item = 'flour', quantity = 6 } } }
local job = { id = '12345678-1234-1234-1234-123456789abc', actor_id = 'owner-42',
    provider_resource = 'custom_inventory', plan_json = 'plan', plan_key = FoodBusiness.productionPlanKey(plan) }
local calls, state, started, wrong, throws, errorCode = 0, 'absent', true, false, false, nil
json = { decode = function(value) assert(value == 'plan'); return plan end }
GetResourceState = function() return started and 'started' or 'stopped' end
local function receipt(_, payload)
    calls = calls + 1
    assert(payload.jobId == job.id and payload.ownerId == job.actor_id and payload.planKey == job.plan_key)
    if throws then error('provider threw') end
    return { jobId = wrong and 'wrong-job' or payload.jobId, ownerId = payload.ownerId, planKey = payload.planKey, state = state, error = errorCode }
end
exports = { custom_inventory = { InspectProductionReservation = receipt, ReserveProduction = receipt, CommitProduction = receipt, ReleaseProduction = receipt } }
dofile('bridges/inventory.lua')
FoodBusiness.Inventory.provider = 'custom'; FoodBusiness.Inventory.resource = 'custom_inventory'
assert(Inventory.reserve(job) == nil and calls == 0)
FoodBusiness.Inventory.mutationsVerified = true
assert(Inventory.capabilities().atomicProduction and Inventory.capabilities().durableRecovery and not Inventory.capabilities().compensation)
assert(Inventory.inspectReservation(job).state == 'absent')
state = 'reserved'; assert(Inventory.reserve(job).state == 'reserved')
errorCode = 'output_full'; assert(Inventory.commit(job).error == 'output_full')
state = 'committed'; assert(Inventory.commit(job) == nil) -- Contradictory error and terminal state.
errorCode = nil; assert(Inventory.commit(job).state == 'committed')
state = 'released'; assert(Inventory.release(job).state == 'released')
wrong = true; local result, reason = Inventory.inspectReservation(job)
assert(result == nil and reason == 'inventory_outcome_unknown')
wrong = false; state = 'unrecognized'; assert(Inventory.inspectReservation(job) == nil)
state = 'reserved'; throws = true; assert(Inventory.commit(job) == nil)
throws = false; started = false
local before = calls
assert(Inventory.reserve(job) == nil and calls == before)
started = true; job.provider_resource = 'other_provider'
assert(Inventory.reserve(job) == nil and calls == before)
job.provider_resource = 'custom_inventory'; job.plan_key = 'changed'
assert(Inventory.reserve(job) == nil and calls == before)
job.plan_key = FoodBusiness.productionPlanKey(plan)
job.plan_json = 'invalid'; assert(Inventory.reserve(job) == nil and calls == before)
job.plan_json = 'plan'; FoodBusiness.Inventory.commitExport = 'invalid/export'
assert(not Inventory.capabilities().atomicProduction and Inventory.commit(job) == nil)
-- Canonical keys survive JSON integer-to-float decoding.
local floatPlan = { stationType = 'oven', batches = 2.0, outputItem = 'bread', outputQuantity = 4.0,
    durationSeconds = 90.0, ingredients = { { item = 'flour', quantity = 6.0 } } }
assert(FoodBusiness.productionPlanKey(floatPlan) == job.plan_key)
print('verified custom mutation adapter: disabled defaults, receipt identity, immutable plans, capacity and uncertain outcomes passed (mocked)')
