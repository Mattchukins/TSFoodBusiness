local engine = dofile('integrations/tsfb-ox-inventory/stock_engine.lua')
local good = { outputItem = 'bread', outputQuantity = 2,
    ingredients = { { item = 'flour', quantity = 3 }, { item = 'water', quantity = 1 } } }
assert(engine.validate(good))
assert(not engine.validate({ outputItem = 'bread', outputQuantity = 2, ingredients = {} }))
assert(not engine.validate({ outputItem = '../bread', outputQuantity = 2, ingredients = good.ingredients }))
assert(not engine.validate({ outputItem = 'bread', outputQuantity = -1, ingredients = good.ingredients }))
assert(not engine.validate({ outputItem = 'bread', outputQuantity = 2,
    ingredients = { { item = 'flour', quantity = 1 }, { item = 'flour', quantity = 1 } } }))
assert(select(2, engine.reserve()) == 'checked_transaction_executor_required')
assert(select(2, engine.commit()) == 'checked_transaction_executor_required')
assert(select(2, engine.release()) == 'checked_transaction_executor_required')
print('SQL stock plan validation and fail-closed transaction boundary passed')
