local engine = dofile('integrations/tsfb-ox-inventory/stock_engine.lua')
local good = { outputItem = 'bread', outputQuantity = 2,
    ingredients = { { item = 'flour', quantity = 3 }, { item = 'water', quantity = 1 } } }
assert(engine.validate(good))
assert(not engine.validate({ outputItem = 'bread', outputQuantity = 2, ingredients = {} }))
assert(not engine.validate({ outputItem = '../bread', outputQuantity = 2, ingredients = good.ingredients }))
assert(not engine.validate({ outputItem = 'bread', outputQuantity = -1, ingredients = good.ingredients }))
assert(not engine.validate({ outputItem = 'bread', outputQuantity = 2,
    ingredients = { { item = 'flour', quantity = 1 }, { item = 'flour', quantity = 1 } } }))
local payload = { jobId = '12345678-1234-1234-1234-123456789abc',
    ownerId = 'restaurant:1', planKey = 'recipe:bread:1', plan = good }
assert(select(2, engine.reserve(payload)) == 'checked_transaction_executor_required')
assert(select(2, engine.commit(payload)) == 'checked_transaction_executor_required')
assert(select(2, engine.release(payload)) == 'checked_transaction_executor_required')
local calls = {}
local function executor(name, args)
    calls[#calls + 1] = { name = name, args = args }
    local states = { tsfb_stock_reserve = 'reserved',
        tsfb_stock_commit = 'committed', tsfb_stock_release = 'released' }
    return { job_id = args[1], owner_id = args[2], plan_key = args[3],
        state = states[name] }
end
local function encode() return '{"ingredients":[]}' end
assert(engine.reserve(payload, executor, encode).state == 'reserved')
assert(calls[1].name == 'tsfb_stock_reserve' and #calls[1].args == 4)
assert(engine.commit(payload, executor).state == 'committed')
assert(engine.release(payload, executor).state == 'released')
assert(#calls == 3)
assert(select(2, engine.reserve({ jobId = payload.jobId, ownerId = payload.ownerId,
    planKey = payload.planKey, plan = { outputItem = 'bread',
    outputQuantity = 1, ingredients = {} } }, executor, encode)) == 'invalid_plan')
assert(#calls == 3)
assert(select(2, engine.commit(payload, function() error('db offline') end)) == 'transaction_failed')
assert(select(2, engine.commit(payload, function() return { job_id = payload.jobId,
    owner_id = 'other', plan_key = payload.planKey, state = 'committed' } end))
    == 'invalid_transaction_receipt')
assert(select(2, engine.commit(payload, function() return { job_id = payload.jobId,
    owner_id = payload.ownerId, plan_key = payload.planKey, state = 'reserved' } end))
    == 'invalid_transaction_state')
print('SQL stock plan validation, procedure dispatch, identity and fail-closed tests passed')
