dofile('shared/config.lua')
dofile('shared/stations.lua')
dofile('shared/recipes.lua')
dofile('shared/jobs.lua')
dofile('server/schema.lua')
local handler, response, dependencies, calls = nil, nil, nil, 0
local id = '12345678-1234-1234-1234-123456789abc'
local person = { id = 'owner-42' }
Framework = { name = 'test', init = function() return true end, player = function() return person end }
CreateThread = function(callback) callback() end
RegisterNetEvent = function(_, callback) handler = callback end
AddEventHandler = function() end
exports = function() end
TriggerClientEvent = function(_, _, payload) response = payload.result end
local timer = 0
GetGameTimer = function() return timer end
MySQL = {
    single = { await = function(query, values)
        if query:find('tsfb_schema', 1, true) then return { count = 7, minimum = 1, maximum = 7 } end
        if query:find('owner_id', 1, true) then assert(values[1] == id and values[2] == 'owner-42'); return { id = id } end
    end },
    query = { await = function(query)
        local fixture = dofile('tests/schema_fixture.lua')
        if query:find('information_schema.COLUMNS', 1, true) then return fixture.columns end
        if query:find('information_schema.TABLES', 1, true) then return fixture.tables end
        return fixture.indexes
    end },
}
CookingJobs = {
    configure = function(value) dependencies = value end,
    list = function(src, actor, business) assert(src == 42 and actor == 'owner-42' and business == id); calls = calls + 1; return { ok = true, jobs = {} } end,
    start = function(src, actor, data) assert(src == 42 and actor == 'owner-42' and data.businessId == id); calls = calls + 1; return { ok = false, error = 'cooking_disabled' } end,
    act = function(src, actor, data, action) assert(src == 42 and actor == 'owner-42' and data.jobId == id); calls = calls + 1; return { ok = true, action = action } end,
}
local staffCalls = 0
Staff = { handle = function(src, actor, action, data)
    assert(src == 42 and actor == 'owner-42')
    staffCalls = staffCalls + 1
    return { ok = true, action = action }
end }
dofile('server/main.lua')
source = 42
local function send(action, data)
    timer = timer + 1000
    handler({ requestId = 'request-' .. timer, action = action, data = data })
end
send('listCookingJobs', { businessId = id })
assert(response.ok and calls == 1)
send('startCookingJob', { businessId = id, recipeId = id, stationId = id, batches = 1, token = 'request-token' })
assert(response.error == 'cooking_disabled' and calls == 2)
for action, expected in pairs({ finishCookingJob = 'finish', cancelCookingJob = 'cancel', inspectCookingJob = 'inspect', resumeCookingJob = 'resume' }) do
    send(action, { businessId = id, jobId = id }); assert(response.ok and response.action == expected)
end
local before = calls
send('startCookingJob', { businessId = id, recipeId = id, stationId = id, batches = 1, token = 'request-token', actor = 'spoofed' })
assert(response.error == 'invalid_payload' and calls == before)
send('listCookingJobs', { businessId = string.rep('-', 36) })
assert(response.error == 'invalid_payload' and calls == before)
send('cancelCookingJob', { businessId = id, jobId = id, receipt = 'spoofed' })
assert(response.error == 'invalid_payload' and calls == before)
person = nil; send('listCookingJobs', { businessId = id })
assert(response.error == 'identity_unavailable' and calls == before)
person = { id = 'owner-42' }
assert(dependencies.owner(42, 'owner-42', id))
assert(not dependencies.owner(42, 'other-owner', id))
for _, action in ipairs({ 'listStaffRoles', 'listStaff', 'assignStaffMember', 'updateStaffMember', 'removeStaffMember' }) do
    send(action, {}); assert(response.ok and response.action == action)
end
assert(staffCalls == 5)
print('cooking and staff NUI action routing, exact payloads and server-derived identity passed (mocked)')
