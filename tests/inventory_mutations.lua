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
state = 'absent'; errorCode = 'insufficient_stock'
assert(Inventory.reserve(job).error == 'insufficient_stock')
assert(Inventory.inspectReservation(job) == nil) -- Inspect cannot return reserve failure.
assert(Inventory.release(job) == nil) -- Release cannot return reserve failure.
state = 'reserved'; errorCode = 'output_full'
assert(Inventory.commit(job).error == 'output_full')
assert(Inventory.reserve(job) == nil) -- Reserve cannot return commit failure.
errorCode = nil
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
-- Even a mistaken operator override cannot enable the stock ox adapter.
FoodBusiness.Inventory.commitExport = 'CommitProduction'
FoodBusiness.Inventory.resource = 'tsfb-ox-inventory'
job.provider_resource = 'tsfb-ox-inventory'
local oxClaims = { atomicProduction = false, durableEscrow = false,
    atomicOutput = false, restartReconciliation = false, liveVerified = false }
exports['tsfb-ox-inventory'] = {
    ProductionMutationCapabilities = function() return oxClaims end,
    ReserveProduction = receipt, InspectProductionReservation = receipt,
    CommitProduction = receipt, ReleaseProduction = receipt,
}
assert(not Inventory.capabilities().atomicProduction)
assert(Inventory.reserve(job) == nil)
oxClaims.atomicProduction = true
oxClaims.durableEscrow = true
oxClaims.atomicOutput = true
oxClaims.restartReconciliation = true
assert(not Inventory.capabilities().atomicProduction) -- live verification still required
oxClaims.liveVerified = true
assert(Inventory.capabilities().atomicProduction)
oxClaims.liveVerified = false
FoodBusiness.Inventory.resource = 'custom_inventory'
job.provider_resource = 'custom_inventory'
-- Canonical keys survive JSON integer-to-float decoding.
local floatPlan = { stationType = 'oven', batches = 2.0, outputItem = 'bread', outputQuantity = 4.0,
    durationSeconds = 90.0, ingredients = { { item = 'flour', quantity = 6.0 } } }
assert(FoodBusiness.productionPlanKey(floatPlan) == job.plan_key)
print('verified custom mutation adapter: disabled defaults, receipt identity, immutable plans, capacity and uncertain outcomes passed (mocked)')
