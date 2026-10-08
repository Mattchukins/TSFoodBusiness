FoodBusiness = {}
dofile('shared/recipes.lua')
local valid = FoodBusiness.validIngredients
assert(valid({ { item = 'bread', quantity = 2 }, { item = 'cheese', quantity = 1 } }))
assert(not valid({}))
assert(not valid({ { item = 'bread', quantity = 0 } }))
assert(not valid({ { item = 'bread', quantity = 1.5 } }))
assert(not valid({ { item = 'bread', quantity = 1001 } }))
assert(not valid({ { item = 'bread', quantity = 1, owner = 'spoof' } }))
assert(not valid({ { item = 'bread', quantity = 1 }, { item = 'bread', quantity = 1 } }))
assert(not valid({ { item = 'bad item', quantity = 1 } }))
assert(not valid({ [1] = { item = 'bread', quantity = 1 }, [3] = { item = 'cheese', quantity = 1 } }))
assert(not valid({ { item = 'bread', quantity = 1 }, extra = true }))
local many = {}
for i = 1, 16 do many[i] = { item = 'item_' .. i, quantity = 1 } end
assert(valid(many))
many[17] = { item = 'extra', quantity = 1 }
assert(not valid(many))
print('recipe ingredient contract passed')
