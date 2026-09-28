local ready = false
local allowedTypes = { restaurant = true, cafe = true, bakery = true, bar = true, takeaway = true, kiosk = true, truck = true }
local function validText(value, max)
    return type(value) == 'string' and #value >= 2 and #value <= max and not value:find('[%c]')
end
local function respond(source, requestId, result)
    TriggerClientEvent('tsfb:response', source, { requestId = requestId, result = result })
end

CreateThread(function()
    local ok, err = Framework.init()
    if not ok then print('[ts-foodbusiness] disabled: ' .. err); return end
    local success, version = pcall(function()
        return MySQL.scalar.await('SELECT MAX(version) FROM tsfb_schema')
    end)
    if not success or tonumber(version) ~= FoodBusiness.RequiredSchema then
        print('[ts-foodbusiness] disabled: apply sql/001_initial.sql; expected schema ' .. FoodBusiness.RequiredSchema)
        return
    end
    ready = true
    print(('[ts-foodbusiness] %s ready with %s'):format(FoodBusiness.Version, Framework.name))
end)

RegisterNetEvent('tsfb:request', function(request)
    local src = source
    if not ready or type(request) ~= 'table' or type(request.requestId) ~= 'string'
        or not request.requestId:match('^[%w%-]+$') or #request.requestId > 64
        or type(request.action) ~= 'string' or type(request.data) ~= 'table' then return end
    for key in pairs(request) do
        if key ~= 'requestId' and key ~= 'action' and key ~= 'data' then return end
    end
    local person = Framework.player(src)
    if not person or not validText(person.id, 80) then
        respond(src, request.requestId, { ok = false, error = 'identity_unavailable' }); return
    end
    if request.action == 'listBusinesses' then
        if next(request.data) ~= nil then
            respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
        end
        local ok, rows = pcall(function()
            return MySQL.query.await('SELECT id, name, type FROM tsfb_businesses WHERE owner_id = ? ORDER BY created_at DESC LIMIT 100', { person.id })
        end)
        respond(src, request.requestId, ok and { ok = true, businesses = rows } or { ok = false, error = 'database_error' })
        return
    end
    if request.action == 'createBusiness' and FoodBusiness.Modules.businesses then
        local data = request.data
        if not validText(data.name, 80) or not allowedTypes[data.type] or type(data.config) ~= 'table'
            or next(data.config) ~= nil then
            respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
        end
        for key in pairs(data) do
            if key ~= 'name' and key ~= 'type' and key ~= 'config' then
                respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
            end
        end
        if not IsPlayerAceAllowed(src, 'tsfoodbusiness.create') then
            respond(src, request.requestId, { ok = false, error = 'forbidden' }); return
        end
        local id = MySQL.scalar.await('SELECT UUID()')
        local correlation = person.id .. ':' .. request.requestId
        local statements = {
            { query = 'INSERT INTO tsfb_businesses (id, owner_id, name, type, config) VALUES (?, ?, ?, ?, ?)',
                values = { id, person.id, data.name, data.type, '{}' } },
            { query = 'INSERT INTO tsfb_audit (action, actor_id, business_id, correlation_id, details) VALUES (?, ?, ?, ?, ?)',
                values = { 'business.create', person.id, id, correlation, json.encode({ name = data.name, type = data.type }) } },
        }
        local ok, done = pcall(function() return MySQL.transaction.await(statements) end)
        respond(src, request.requestId, ok and done and { ok = true, id = id } or { ok = false, error = 'transaction_failed' })
        return
    end
    respond(src, request.requestId, { ok = false, error = 'unknown_action' })
end)
