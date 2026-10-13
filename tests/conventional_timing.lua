dofile('shared/conventional_timing.lua')
assert(ConventionalTiming.deadline(100, 30) == 130)
assert(ConventionalTiming.ready(129, 130) == false)
assert(ConventionalTiming.ready(130, 130) == true)
assert(ConventionalTiming.ready(131, 130) == true)
for _, value in ipairs({ 0, -1, 1.5, math.huge, '20' }) do
 assert(ConventionalTiming.deadline(100, value) == nil)
end
assert(ConventionalTiming.deadline(2147483600, 100) == nil)
assert(ConventionalTiming.ready(-1, 130) == nil)
local data = { businessId = 'b', recipeId = 'r', stationId = 's', token = 't', batches = 2 }
local prior = { actor_id = 'owner', business_id = 'b', recipe_id = 'r',
 station_id = 's', request_token = 't', batches = 2 }
assert(ConventionalTiming.sameRequest(prior, 'owner', data))
for _, key in ipairs({ 'businessId', 'recipeId', 'stationId', 'token', 'batches' }) do
 local changed = {}
 for k, v in pairs(data) do changed[k] = v end
 changed[key] = key == 'batches' and 3 or 'different'
 assert(not ConventionalTiming.sameRequest(prior, 'owner', changed))
end
assert(not ConventionalTiming.sameRequest(prior, 'other', data))
print('conventional cooking timer and replay helpers passed')
