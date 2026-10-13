-- Stateful mock of the custom production inventory contract.
-- This is a regression fixture, not a live provider implementation.
dofile('shared/config.lua')
dofile('shared/stations.lua')
dofile('shared/recipes.lua')
dofile('shared/jobs.lua')
local plan = { stationType = 'oven', batches = 1, outputItem = 'bread',
    outputQuantity = 2, durationSeconds = 30,
    ingredients = { { item = 'flour', quantity = 3 } } }
local job = { id = '12345678-1234-1234-1234-123456789abc',
    actor_id = 'owner-42', provider_resource = 'fake_inventory',
    plan_json = 'plan', plan_key = FoodBusiness.productionPlanKey(plan) }
json = { decode = function() return plan end }
GetResourceState = function() return 'started' end
local stock, output, state, hasCapacity = 3, 0, 'absent', true
local function operation(kind, payload)
    assert(payload.jobId == job.id and payload.planKey == job.plan_key)
    local err
    if kind == 'reserve' and state == 'absent' then
        if stock < 3 then err = 'insufficient_stock'
        else stock = stock - 3; state = 'reserved' end
    elseif kind == 'commit' and state == 'reserved' then
        if not hasCapacity then err = 'output_full'
        else output = output + 2; state = 'committed' end
    elseif kind == 'release' then
        if state == 'reserved' then stock = stock + 3 end
        if state == 'reserved' or state == 'absent' then state = 'released' end
    end
    return { jobId = payload.jobId, ownerId = payload.ownerId,
        planKey = payload.planKey, state = state, error = err }
end
exports = { fake_inventory = {
    InspectProductionReservation = function(_, p) return operation('inspect', p) end,
    ReserveProduction = function(_, p) return operation('reserve', p) end,
    CommitProduction = function(_, p) return operation('commit', p) end,
    ReleaseProduction = function(_, p) return operation('release', p) end
} }
dofile('bridges/inventory.lua')
FoodBusiness.Inventory.provider = 'custom'
FoodBusiness.Inventory.resource = 'fake_inventory'
FoodBusiness.Inventory.mutationsVerified = true
assert(Inventory.reserve(job).state == 'reserved' and stock == 0)
assert(Inventory.reserve(job).state == 'reserved' and stock == 0)
hasCapacity = false
local blocked = Inventory.commit(job)
assert(blocked.state == 'reserved' and blocked.error == 'output_full' and output == 0)
hasCapacity = true
assert(Inventory.commit(job).state == 'committed' and output == 2)
assert(Inventory.commit(job).state == 'committed' and output == 2)
assert(Inventory.release(job).state == 'committed' and stock == 0)
state, stock, output = 'absent', 3, 0
assert(Inventory.reserve(job).state == 'reserved')
assert(Inventory.release(job).state == 'released' and stock == 3)
assert(Inventory.commit(job).state == 'released' and output == 0)
state = 'absent'
assert(Inventory.release(job).state == 'released')
assert(Inventory.reserve(job).state == 'released' and stock == 3)
print('stateful inventory contract tests passed (mock only)')
