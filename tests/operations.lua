FoodBusiness = {}
dofile('shared/operations.lua')

local within = FoodBusiness.isWithinHours
assert(within(540, 1020, 540) == true)
assert(within(540, 1020, 1019) == true)
assert(within(540, 1020, 1020) == false)
assert(within(540, 1020, 0) == false)
assert(within(1200, 180, 1439) == true)
assert(within(1200, 180, 0) == true)
assert(within(1200, 180, 179) == true)
assert(within(1200, 180, 180) == false)
assert(within(1200, 180, 600) == false)
assert(within(500, 500, 500) == nil)
assert(within(-1, 600, 500) == nil)
assert(within(0, 600, 1440) == nil)
assert(within(0, 600, 1.5) == nil)
print('operations contract passed')
