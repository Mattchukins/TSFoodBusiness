local ready = false
local requestWindows = {}
local function validText(value, max)
    return type(value) == 'string' and #value >= 2 and #value <= max and not value:find('[%c]')
end
local function validId(value)
    return type(value) == 'string' and value:match('^[a-fA-F0-9%-]+$') and #value == 36
end
local function validPrice(value)
    return type(value) == 'number' and value == math.floor(value) and value >= 1 and value <= 10000000
end
local function validInteger(value, minimum, maximum)
    return type(value) == 'number' and value == math.floor(value) and value >= minimum and value <= maximum
end
local function exactKeys(data, keys)
    for key in pairs(data) do if not keys[key] then return false end end
    return true
end
local function respond(source, requestId, result)
    TriggerClientEvent('tsfb:response', source, { requestId = requestId, result = result })
end
local function bounded(value, depth, budget, seen)
    if depth > 4 or budget.count > 80 then return false end
    local kind = type(value)
    if kind == 'string' then return #value <= 512 end
    if kind == 'number' then return value == value and value ~= math.huge and value ~= -math.huge end
    if kind == 'boolean' then return true end
    if kind ~= 'table' or seen[value] then return false end
    seen[value] = true
    for key, entry in pairs(value) do
        budget.count = budget.count + 1
        if budget.count > 80 or not bounded(key, depth + 1, budget, seen)
            or not bounded(entry, depth + 1, budget, seen) then return false end
    end
    seen[value] = nil
    return true
end

CreateThread(function()
    local ok, err = Framework.init()
    if not ok then print('[ts-foodbusiness] disabled: ' .. err); return end
    local success, schema = pcall(function()
        return MySQL.single.await('SELECT COUNT(*) AS count, MIN(version) AS minimum, MAX(version) AS maximum FROM tsfb_schema')
    end)
    if not success or not schema or tonumber(schema.count) ~= FoodBusiness.RequiredSchema
        or tonumber(schema.minimum) ~= 1 or tonumber(schema.maximum) ~= FoodBusiness.RequiredSchema then
        print('[ts-foodbusiness] disabled: apply sql/install.sql; expected schema ' .. FoodBusiness.RequiredSchema)
        return
    end
    local verified, reason = Schema.verify()
    if not verified then print('[ts-foodbusiness] disabled: ' .. reason); return end
    ready = true
    print(('[ts-foodbusiness] %s ready with %s'):format(FoodBusiness.Version, Framework.name))
end)

local function handleRequest(src, request)
    if not ready or type(request) ~= 'table' or type(request.requestId) ~= 'string'
        or not request.requestId:match('^[%w%-]+$') or #request.requestId > 64
        or type(request.action) ~= 'string' or type(request.data) ~= 'table' then return end
    for key in pairs(request) do
        if key ~= 'requestId' and key ~= 'action' and key ~= 'data' then return end
    end
    if #request.action > 32 or not bounded(request.data, 0, { count = 0 }, {}) then
        respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
    end
    local person = Framework.player(src)
    if not person or not validText(person.id, 80) then
        respond(src, request.requestId, { ok = false, error = 'identity_unavailable' }); return
    end
    if request.action == 'listMyStaffBusinesses' or request.action == 'setMyStaffDuty' or request.action == 'listStaffShifts' or request.action == 'listStaffRoles' or request.action == 'listStaff' or request.action == 'assignStaffMember'
        or request.action == 'setStaffDuty' or request.action == 'updateStaffMember' or request.action == 'removeStaffMember' then
        respond(src, request.requestId, Staff.handle(src, person.id, request.action, request.data)); return
    end
    if request.action == 'startConventionalCooking' then
        local data = request.data
        if not exactKeys(data, { businessId = true, recipeId = true, stationId = true, batches = true }) then
            respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
        end
        if not ConventionalCooking then
            respond(src, request.requestId, { ok = false, error = 'cooking_unavailable' }); return
        end
        respond(src, request.requestId, ConventionalCooking.start(src, person.id, data)); return
    end
    local jobActions = { listCookingJobs = 'list', startCookingJob = 'start',
        finishCookingJob = 'finish', cancelCookingJob = 'cancel',
        inspectCookingJob = 'inspect', resumeCookingJob = 'resume' }
    local jobAction = jobActions[request.action]
    if jobAction then
        local data = request.data
        local keys = jobAction == 'list' and { businessId = true }
            or jobAction == 'start' and { businessId = true, recipeId = true, stationId = true, batches = true, token = true }
            or { businessId = true, jobId = true }
        if not exactKeys(data, keys) or not FoodBusiness.validJobId(data.businessId) then
            respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
        end
        local result = jobAction == 'list' and CookingJobs.list(src, person.id, data.businessId)
            or jobAction == 'start' and CookingJobs.start(src, person.id, data)
            or CookingJobs.act(src, person.id, data, jobAction)
        respond(src, request.requestId, result); return
    end
    if request.action == 'listPresets' then
        if next(request.data) ~= nil then
            respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
        end
        respond(src, request.requestId, { ok = true, presets = FoodBusiness.listBusinessPresets() }); return
    end
    if request.action == 'listStationTypes' and FoodBusiness.Modules.stations then
        if next(request.data) ~= nil then
            respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
        end
        respond(src, request.requestId, { ok = true, stationTypes = FoodBusiness.listStationTypes() }); return
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
        local preset = FoodBusiness.getBusinessPreset(data.type)
        if not validText(data.name, 80) or not preset or type(data.config) ~= 'table'
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
            { query = 'INSERT INTO tsfb_operations (business_id, opens_minute, closes_minute, seat_capacity, queue_capacity) VALUES (?, ?, ?, ?, ?)',
                values = { id, preset.opensMinute, preset.closesMinute, preset.seatCapacity, preset.queueCapacity } },
            { query = 'INSERT INTO tsfb_audit (action, actor_id, business_id, correlation_id, details) VALUES (?, ?, ?, ?, ?)',
                values = { 'business.create', person.id, id, correlation, json.encode({ name = data.name, type = data.type }) } },
        }
        local ok, done = pcall(function() return MySQL.transaction.await(statements) end)
        respond(src, request.requestId, ok and done and { ok = true, id = id } or { ok = false, error = 'transaction_failed' })
        return
    end
    if request.action == 'renameBusiness' and FoodBusiness.Modules.businesses then
        local data = request.data
        if not exactKeys(data, { businessId = true, name = true }) or not validId(data.businessId)
            or not validText(data.name, 80) then
            respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
        end
        local owned = MySQL.single.await('SELECT id FROM tsfb_businesses WHERE id = ? AND owner_id = ?',
            { data.businessId, person.id })
        if not owned then respond(src, request.requestId, { ok = false, error = 'forbidden' }); return end
        local ok, done = pcall(function() return MySQL.transaction.await({
            { query = 'UPDATE tsfb_businesses SET name = ? WHERE id = ? AND owner_id = ?',
                values = { data.name, data.businessId, person.id } },
            { query = 'INSERT INTO tsfb_audit (action, actor_id, business_id, correlation_id, details) VALUES (?, ?, ?, ?, ?)',
                values = { 'business.rename', person.id, data.businessId, person.id .. ':' .. request.requestId,
                    json.encode({ name = data.name }) } },
        }) end)
        respond(src, request.requestId, ok and done and { ok = true } or { ok = false, error = 'transaction_failed' })
        return
    end
    if (request.action == 'getOperations' or request.action == 'setOperations') and FoodBusiness.Modules.operations then
        local data = request.data
        if not validId(data.businessId) then
            respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
        end
        local business = MySQL.single.await('SELECT id FROM tsfb_businesses WHERE id = ? AND owner_id = ?',
            { data.businessId, person.id })
        if not business then respond(src, request.requestId, { ok = false, error = 'forbidden' }); return end
        if request.action == 'getOperations' then
            if not exactKeys(data, { businessId = true }) then
                respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
            end
            local profile = MySQL.single.await('SELECT opens_minute, closes_minute, seat_capacity, queue_capacity FROM tsfb_operations WHERE business_id = ?', { data.businessId })
            respond(src, request.requestId, { ok = true, operations = profile }); return
        end
        if not exactKeys(data, { businessId = true, opensMinute = true, closesMinute = true,
            seatCapacity = true, queueCapacity = true })
            or not validInteger(data.opensMinute, 0, 1439) or not validInteger(data.closesMinute, 0, 1439)
            or data.opensMinute == data.closesMinute
            or not validInteger(data.seatCapacity, 0, 200) or not validInteger(data.queueCapacity, 0, 100) then
            respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
        end
        local ok, done = pcall(function() return MySQL.transaction.await({
            { query = 'INSERT INTO tsfb_operations (business_id, opens_minute, closes_minute, seat_capacity, queue_capacity) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE opens_minute = VALUES(opens_minute), closes_minute = VALUES(closes_minute), seat_capacity = VALUES(seat_capacity), queue_capacity = VALUES(queue_capacity)',
                values = { data.businessId, data.opensMinute, data.closesMinute, data.seatCapacity, data.queueCapacity } },
            { query = 'INSERT INTO tsfb_audit (action, actor_id, business_id, correlation_id, details) VALUES (?, ?, ?, ?, ?)',
                values = { 'operations.set', person.id, data.businessId, person.id .. ':' .. request.requestId,
                    json.encode({ opensMinute = data.opensMinute, closesMinute = data.closesMinute,
                        seatCapacity = data.seatCapacity, queueCapacity = data.queueCapacity }) } },
        }) end)
        respond(src, request.requestId, ok and done and { ok = true } or { ok = false, error = 'transaction_failed' })
        return
    end
    if (request.action == 'listRecipes' or request.action == 'createRecipe'
        or request.action == 'quoteRecipe' or request.action == 'listSuppliers'
        or request.action == 'createSupplier' or request.action == 'deleteRecipe'
        or request.action == 'updateRecipe' or request.action == 'updateSupplier'
        or request.action == 'deleteSupplier' or request.action == 'listAudit'
        or request.action == 'getProductionProfile' or request.action == 'setProductionProfile' or request.action == 'previewProduction' or request.action == 'checkProductionStock' or request.action == 'deleteProductionProfile'
        or request.action == 'listStations' or request.action == 'createStation'
        or request.action == 'deleteStation' or request.action == 'moveStation' or request.action == 'updateStation') and validId(request.data.businessId) then
        local data = request.data
        local business = MySQL.single.await('SELECT id FROM tsfb_businesses WHERE id = ? AND owner_id = ?',
            { data.businessId, person.id })
        if not business then respond(src, request.requestId, { ok = false, error = 'forbidden' }); return end
        if (request.action == 'getProductionProfile' or request.action == 'setProductionProfile' or request.action == 'previewProduction' or request.action == 'checkProductionStock' or request.action == 'deleteProductionProfile') and FoodBusiness.Modules.recipes then
            local writing = request.action == 'setProductionProfile'
            local checking = request.action == 'checkProductionStock'
            local deleting = request.action == 'deleteProductionProfile'
            local preview = request.action == 'previewProduction' or checking
            local allowed = preview and { businessId = true, recipeId = true, batches = true } or writing and { businessId = true, recipeId = true, profile = true } or { businessId = true, recipeId = true }
            if not exactKeys(data, allowed) or not validId(data.recipeId)
                or (preview and not validInteger(data.batches, 1, 100))
                or (writing and not FoodBusiness.validProductionProfile(data.profile)) then
                respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
            end
            local recipe = MySQL.single.await('SELECT id, ingredients FROM tsfb_recipes WHERE id = ? AND business_id = ?', { data.recipeId, data.businessId })
            if not recipe then respond(src, request.requestId, { ok = false, error = 'not_found' }); return end
            if deleting then
                local ok, done = pcall(function() return MySQL.transaction.await({
                    { query = 'DELETE FROM tsfb_production_profiles WHERE recipe_id = ?', values = { data.recipeId } },
                    { query = 'INSERT INTO tsfb_audit (action, actor_id, business_id, correlation_id, details) VALUES (?, ?, ?, ?, ?)',
                        values = { 'recipe.production.delete', person.id, data.businessId, person.id .. ':' .. request.requestId, json.encode({ recipeId = data.recipeId }) } },
                }) end)
                respond(src, request.requestId, ok and done and { ok = true } or { ok = false, error = 'transaction_failed' }); return
            end
            if not writing then
                local profile = MySQL.single.await('SELECT station_type, output_item, output_quantity, duration_seconds FROM tsfb_production_profiles WHERE recipe_id = ?', { data.recipeId })
                if preview then
                    if not profile then respond(src, request.requestId, { ok = false, error = 'production_unconfigured' }); return end
                    local plan = FoodBusiness.planProduction(json.decode(recipe.ingredients), {
                        stationType = profile.station_type, outputItem = profile.output_item,
                        outputQuantity = tonumber(profile.output_quantity), durationSeconds = tonumber(profile.duration_seconds),
                    }, profile.station_type, data.batches)
                    if checking and plan then
                        local ok, report, reason = pcall(Inventory.inspectPlan, src, plan)
                        respond(src, request.requestId, ok and report and { ok = true, productionPlan = plan, stockReport = report }
                            or { ok = false, error = ok and (reason or 'inventory_unavailable') or 'inventory_error' }); return
                    end
                    respond(src, request.requestId, plan and { ok = true, productionPlan = plan } or { ok = false, error = 'invalid_production_configuration' }); return
                end
                respond(src, request.requestId, { ok = true, productionProfile = profile }); return
            end
            local profile = data.profile
            local ok, done = pcall(function() return MySQL.transaction.await({
                { query = 'INSERT INTO tsfb_production_profiles (recipe_id, station_type, output_item, output_quantity, duration_seconds) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE station_type = VALUES(station_type), output_item = VALUES(output_item), output_quantity = VALUES(output_quantity), duration_seconds = VALUES(duration_seconds)',
                    values = { data.recipeId, profile.stationType, profile.outputItem, profile.outputQuantity, profile.durationSeconds } },
                { query = 'INSERT INTO tsfb_audit (action, actor_id, business_id, correlation_id, details) VALUES (?, ?, ?, ?, ?)',
                    values = { 'recipe.production', person.id, data.businessId, person.id .. ':' .. request.requestId,
                        json.encode({ recipeId = data.recipeId, profile = profile }) } },
            }) end)
            respond(src, request.requestId, ok and done and { ok = true } or { ok = false, error = 'transaction_failed' }); return
        end
        if request.action == 'listStations' and FoodBusiness.Modules.stations then
            if not exactKeys(data, { businessId = true }) then
                respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
            end
            local rows = MySQL.query.await('SELECT id, name, type, x, y, z, heading, routing_bucket FROM tsfb_stations WHERE business_id = ? ORDER BY created_at, id LIMIT 200', { data.businessId })
            respond(src, request.requestId, { ok = true, stations = rows }); return
        end
        if (request.action == 'createStation' or request.action == 'moveStation') and FoodBusiness.Modules.stations then
            local moving = request.action == 'moveStation'
            if not moving and (not exactKeys(data, { businessId = true, name = true, type = true })
                or not validText(data.name, 80) or type(data.type) ~= 'string' or not FoodBusiness.StationTypes[data.type]) then
                respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
            end
            if moving and (not exactKeys(data, { businessId = true, stationId = true }) or not validId(data.stationId)) then
                respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
            end
            if moving then
                local station = MySQL.single.await('SELECT id FROM tsfb_stations WHERE id = ? AND business_id = ?', { data.stationId, data.businessId })
                if not station then respond(src, request.requestId, { ok = false, error = 'not_found' }); return end
            end
            local ped = GetPlayerPed(src)
            if not ped or ped == 0 then respond(src, request.requestId, { ok = false, error = 'position_unavailable' }); return end
            local coords, heading, bucket = GetEntityCoords(ped), GetEntityHeading(ped), GetPlayerRoutingBucket(src)
            if not coords or not FoodBusiness.validStationPosition(coords.x, coords.y, coords.z, heading, bucket) then
                respond(src, request.requestId, { ok = false, error = 'position_unavailable' }); return
            end
            local id = moving and data.stationId or MySQL.scalar.await('SELECT UUID()')
            local mutation = moving
                and { query = 'UPDATE tsfb_stations SET x = ?, y = ?, z = ?, heading = ?, routing_bucket = ? WHERE id = ? AND business_id = ?',
                    values = { coords.x, coords.y, coords.z, heading, bucket, id, data.businessId } }
                or { query = 'INSERT INTO tsfb_stations (id, business_id, name, type, x, y, z, heading, routing_bucket) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
                    values = { id, data.businessId, data.name, data.type, coords.x, coords.y, coords.z, heading, bucket } }
            local ok, done = pcall(function() return MySQL.transaction.await({
                mutation,
                { query = 'INSERT INTO tsfb_audit (action, actor_id, business_id, correlation_id, details) VALUES (?, ?, ?, ?, ?)',
                    values = { moving and 'station.move' or 'station.create', person.id, data.businessId, person.id .. ':' .. request.requestId,
                        json.encode({ id = id, name = data.name, type = data.type, x = coords.x, y = coords.y, z = coords.z,
                            heading = heading, routingBucket = bucket }) } },
            }) end)
            respond(src, request.requestId, ok and done and { ok = true, id = id } or { ok = false, error = 'transaction_failed' }); return
        end
        if request.action == 'updateStation' and FoodBusiness.Modules.stations then
            if not exactKeys(data, { businessId = true, stationId = true, name = true, type = true })
                or not validId(data.stationId) or not validText(data.name, 80)
                or type(data.type) ~= 'string' or not FoodBusiness.StationTypes[data.type] then
                respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
            end
            local station = MySQL.single.await('SELECT id FROM tsfb_stations WHERE id = ? AND business_id = ?', { data.stationId, data.businessId })
            if not station then respond(src, request.requestId, { ok = false, error = 'not_found' }); return end
            local ok, done = pcall(function() return MySQL.transaction.await({
                { query = 'UPDATE tsfb_stations SET name = ?, type = ? WHERE id = ? AND business_id = ?',
                    values = { data.name, data.type, data.stationId, data.businessId } },
                { query = 'INSERT INTO tsfb_audit (action, actor_id, business_id, correlation_id, details) VALUES (?, ?, ?, ?, ?)',
                    values = { 'station.update', person.id, data.businessId, person.id .. ':' .. request.requestId,
                        json.encode({ id = data.stationId, name = data.name, type = data.type }) } },
            }) end)
            respond(src, request.requestId, ok and done and { ok = true } or { ok = false, error = 'transaction_failed' }); return
        end
        if request.action == 'deleteStation' and FoodBusiness.Modules.stations then
            if not exactKeys(data, { businessId = true, stationId = true }) or not validId(data.stationId) then
                respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
            end
            local station = MySQL.single.await('SELECT id FROM tsfb_stations WHERE id = ? AND business_id = ?', { data.stationId, data.businessId })
            if not station then respond(src, request.requestId, { ok = false, error = 'not_found' }); return end
            local ok, done = pcall(function() return MySQL.transaction.await({
                { query = 'DELETE FROM tsfb_stations WHERE id = ? AND business_id = ?', values = { data.stationId, data.businessId } },
                { query = 'INSERT INTO tsfb_audit (action, actor_id, business_id, correlation_id, details) VALUES (?, ?, ?, ?, ?)',
                    values = { 'station.delete', person.id, data.businessId, person.id .. ':' .. request.requestId, json.encode({ id = data.stationId }) } },
            }) end)
            respond(src, request.requestId, ok and done and { ok = true } or { ok = false, error = 'transaction_failed' }); return
        end
        if request.action == 'listAudit' and FoodBusiness.Modules.businesses then
            if not exactKeys(data, { businessId = true }) then
                respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
            end
            local rows = MySQL.query.await('SELECT action, details, created_at FROM tsfb_audit WHERE business_id = ? ORDER BY id DESC LIMIT 100', { data.businessId })
            respond(src, request.requestId, { ok = true, audit = rows }); return
        end
        if request.action == 'listRecipes' and FoodBusiness.Modules.recipes then
            if not exactKeys(data, { businessId = true }) then
                respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
            end
            local rows = MySQL.query.await('SELECT id, name, price_cents, ingredients FROM tsfb_recipes WHERE business_id = ? ORDER BY name LIMIT 200', { data.businessId })
            for _, row in ipairs(rows) do
                local ok, ingredients = pcall(json.decode, row.ingredients)
                if not ok or type(ingredients) ~= 'table' then
                    respond(src, request.requestId, { ok = false, error = 'invalid_stored_recipe' }); return
                end
                row.ingredients = ingredients
            end
            respond(src, request.requestId, { ok = true, recipes = rows }); return
        end
        if request.action == 'quoteRecipe' and FoodBusiness.Modules.recipes then
            if not validId(data.recipeId) or not exactKeys(data, { businessId = true, recipeId = true }) then
                respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
            end
            local recipe = MySQL.single.await('SELECT id, name, price_cents FROM tsfb_recipes WHERE id = ? AND business_id = ?', { data.recipeId, data.businessId })
            respond(src, request.requestId, recipe and { ok = true, quote = recipe } or { ok = false, error = 'not_found' })
            return
        end
        if request.action == 'listSuppliers' and FoodBusiness.Modules.suppliers then
            if not exactKeys(data, { businessId = true }) then
                respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
            end
            local rows = MySQL.query.await('SELECT id, name, item_name, unit_price_cents FROM tsfb_suppliers WHERE business_id = ? ORDER BY name LIMIT 200', { data.businessId })
            respond(src, request.requestId, { ok = true, suppliers = rows }); return
        end
        if request.action == 'createRecipe' and FoodBusiness.Modules.recipes then
            if not validText(data.name, 80) or not validPrice(data.priceCents)
                or not FoodBusiness.validIngredients(data.ingredients)
                or not exactKeys(data, { businessId = true, name = true, priceCents = true, ingredients = true }) then
                respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
            end
            local id = MySQL.scalar.await('SELECT UUID()')
            local ok, done = pcall(function() return MySQL.transaction.await({
                { query = 'INSERT INTO tsfb_recipes (id, business_id, name, price_cents, ingredients) VALUES (?, ?, ?, ?, ?)',
                    values = { id, data.businessId, data.name, data.priceCents, json.encode(data.ingredients) } },
                { query = 'INSERT INTO tsfb_audit (action, actor_id, business_id, correlation_id, details) VALUES (?, ?, ?, ?, ?)',
                    values = { 'recipe.create', person.id, data.businessId, person.id .. ':' .. request.requestId,
                        json.encode({ id = id, name = data.name, priceCents = data.priceCents, ingredients = data.ingredients }) } },
            }) end)
            respond(src, request.requestId, ok and done and { ok = true, id = id } or { ok = false, error = 'transaction_failed' })
            return
        end
        if (request.action == 'updateRecipe' or request.action == 'deleteRecipe') and FoodBusiness.Modules.recipes then
            if not validId(data.recipeId) then
                respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
            end
            if request.action == 'updateRecipe' and (not exactKeys(data, { businessId = true, recipeId = true, name = true, priceCents = true, ingredients = true })
                or not validText(data.name, 80) or not validPrice(data.priceCents)
                or not FoodBusiness.validIngredients(data.ingredients)) then
                respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
            end
            if request.action == 'deleteRecipe' and not exactKeys(data, { businessId = true, recipeId = true }) then
                respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
            end
            local recipe = MySQL.single.await('SELECT id FROM tsfb_recipes WHERE id = ? AND business_id = ?',
                { data.recipeId, data.businessId })
            if not recipe then respond(src, request.requestId, { ok = false, error = 'not_found' }); return end
            local action = request.action == 'updateRecipe' and 'recipe.update' or 'recipe.delete'
            local statement = request.action == 'updateRecipe'
                and { query = 'UPDATE tsfb_recipes SET name = ?, price_cents = ?, ingredients = ? WHERE id = ? AND business_id = ?',
                    values = { data.name, data.priceCents, json.encode(data.ingredients), data.recipeId, data.businessId } }
                or { query = 'DELETE FROM tsfb_recipes WHERE id = ? AND business_id = ?',
                    values = { data.recipeId, data.businessId } }
            local ok, done = pcall(function() return MySQL.transaction.await({
                statement,
                { query = 'INSERT INTO tsfb_audit (action, actor_id, business_id, correlation_id, details) VALUES (?, ?, ?, ?, ?)',
                    values = { action, person.id, data.businessId, person.id .. ':' .. request.requestId,
                        json.encode({ id = data.recipeId, name = data.name, priceCents = data.priceCents, ingredients = data.ingredients }) } },
            }) end)
            respond(src, request.requestId, ok and done and { ok = true } or { ok = false, error = 'transaction_failed' })
            return
        end
        if request.action == 'createSupplier' and FoodBusiness.Modules.suppliers then
            if not validText(data.name, 80) or not validText(data.itemName, 80)
                or not validPrice(data.unitPriceCents)
                or not exactKeys(data, { businessId = true, name = true, itemName = true, unitPriceCents = true }) then
                respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
            end
            local id = MySQL.scalar.await('SELECT UUID()')
            local ok, done = pcall(function() return MySQL.transaction.await({
                { query = 'INSERT INTO tsfb_suppliers (id, business_id, name, item_name, unit_price_cents) VALUES (?, ?, ?, ?, ?)',
                    values = { id, data.businessId, data.name, data.itemName, data.unitPriceCents } },
                { query = 'INSERT INTO tsfb_audit (action, actor_id, business_id, correlation_id, details) VALUES (?, ?, ?, ?, ?)',
                    values = { 'supplier.create', person.id, data.businessId, person.id .. ':' .. request.requestId,
                        json.encode({ id = id, name = data.name, itemName = data.itemName, unitPriceCents = data.unitPriceCents }) } },
            }) end)
            respond(src, request.requestId, ok and done and { ok = true, id = id } or { ok = false, error = 'transaction_failed' })
            return
        end
        if (request.action == 'updateSupplier' or request.action == 'deleteSupplier') and FoodBusiness.Modules.suppliers then
            if not validId(data.supplierId) then
                respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
            end
            if request.action == 'updateSupplier' and
                (not exactKeys(data, { businessId = true, supplierId = true, name = true, itemName = true, unitPriceCents = true })
                or not validText(data.name, 80) or not validText(data.itemName, 80)
                or not validPrice(data.unitPriceCents)) then
                respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
            end
            if request.action == 'deleteSupplier' and not exactKeys(data, { businessId = true, supplierId = true }) then
                respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
            end
            local supplier = MySQL.single.await('SELECT id FROM tsfb_suppliers WHERE id = ? AND business_id = ?',
                { data.supplierId, data.businessId })
            if not supplier then respond(src, request.requestId, { ok = false, error = 'not_found' }); return end
            local action = request.action == 'updateSupplier' and 'supplier.update' or 'supplier.delete'
            local statement = request.action == 'updateSupplier'
                and { query = 'UPDATE tsfb_suppliers SET name = ?, item_name = ?, unit_price_cents = ? WHERE id = ? AND business_id = ?',
                    values = { data.name, data.itemName, data.unitPriceCents, data.supplierId, data.businessId } }
                or { query = 'DELETE FROM tsfb_suppliers WHERE id = ? AND business_id = ?',
                    values = { data.supplierId, data.businessId } }
            local ok, done = pcall(function() return MySQL.transaction.await({
                statement,
                { query = 'INSERT INTO tsfb_audit (action, actor_id, business_id, correlation_id, details) VALUES (?, ?, ?, ?, ?)',
                    values = { action, person.id, data.businessId, person.id .. ':' .. request.requestId,
                        json.encode({ id = data.supplierId, name = data.name, itemName = data.itemName,
                            unitPriceCents = data.unitPriceCents }) } },
            }) end)
            respond(src, request.requestId, ok and done and { ok = true } or { ok = false, error = 'transaction_failed' })
            return
        end
    end
    respond(src, request.requestId, { ok = false, error = 'unknown_action' })
end

RegisterNetEvent('tsfb:request', function(request)
    local src = source
    if type(src) ~= 'number' or src <= 0 then return end
    local now = GetGameTimer()
    local window = requestWindows[src]
    if not window or now < window.started or now - window.started >= 1000 then
        window = { started = now, count = 0 }
        requestWindows[src] = window
    end
    window.count = window.count + 1
    if window.count > 10 then return end
    local ok, err = pcall(handleRequest, src, request)
    if not ok then
        print(('[ts-foodbusiness] request failed: %s'):format(tostring(err)))
        if type(request) == 'table' and type(request.requestId) == 'string'
            and #request.requestId <= 64 and request.requestId:match('^[%w%-]+$') then
            respond(src, request.requestId, { ok = false, error = 'server_error' })
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    requestWindows[src] = nil
    if Staff and not Staff.disconnect(src) then
        print('[ts-foodbusiness] staff disconnect cleanup failed; owner must review saved duty and shift status')
    end
end)

-- Server-only integration contract. Values describe configuration, never availability or stock.
local function getBusinessOperations(businessId)
    if not ready or not validId(businessId) then return nil end
    local ok, row = pcall(function()
        return MySQL.single.await('SELECT opens_minute, closes_minute, seat_capacity, queue_capacity FROM tsfb_operations WHERE business_id = ?', { businessId })
    end)
    if not ok or not row then return nil end
    return { opensMinute = tonumber(row.opens_minute), closesMinute = tonumber(row.closes_minute),
        seatCapacity = tonumber(row.seat_capacity), queueCapacity = tonumber(row.queue_capacity) }
end

exports('GetBusinessOperations', function(businessId)
    return getBusinessOperations(businessId)
end)

exports('IsBusinessWithinHours', function(businessId, minute)
    if not validInteger(minute, 0, 1439) then return nil end
    local profile = getBusinessOperations(businessId)
    if not profile then return nil end
    return FoodBusiness.isWithinHours(profile.opensMinute, profile.closesMinute, minute)
end)

-- Owner-only spatial prerequisite, not authorization to cook or consume inventory.
exports('IsOwnerNearStation', function(src, businessId, stationId, radius)
    if not ready or not FoodBusiness.Modules.stations or not validInteger(src, 1, 2147483647)
        or not validId(businessId) or not validId(stationId) then return nil end
    radius = radius == nil and 2.0 or radius
    if type(radius) ~= 'number' or radius ~= radius or radius <= 0 or radius > 10 then return nil end
    local ok, near = pcall(function()
        local person = Framework.player(src)
        if not person then return nil end
        local business = MySQL.single.await('SELECT id FROM tsfb_businesses WHERE id = ? AND owner_id = ?', { businessId, person.id })
        if not business then return nil end
        local station = MySQL.single.await('SELECT x, y, z, heading, routing_bucket FROM tsfb_stations WHERE id = ? AND business_id = ?', { stationId, businessId })
        if not station then return nil end
        -- Read live player state after database awaits.
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then return nil end
        local coords = GetEntityCoords(ped)
        if not coords then return nil end
        return FoodBusiness.isNearStation(station, coords.x, coords.y, coords.z, GetPlayerRoutingBucket(src), radius)
    end)
    if not ok then return nil end
    return near
end)

-- Read-only integration: recompute on cook start; never treat a plan as a reservation.
local function getOwnerProductionPlan(src, businessId, recipeId, stationId, batches)
    if not ready or not FoodBusiness.Modules.recipes or not FoodBusiness.Modules.stations
        or not validInteger(src, 1, 2147483647) or not validId(businessId)
        or not validId(recipeId) or not validId(stationId) or not validInteger(batches, 1, 100) then return nil end
    local ok, plan = pcall(function()
        local person = Framework.player(src)
        if not person or not validText(person.id, 80) then return nil end
        local business = MySQL.single.await('SELECT id FROM tsfb_businesses WHERE id = ? AND owner_id = ?', { businessId, person.id })
        if not business then return nil end
        local recipe = MySQL.single.await('SELECT ingredients FROM tsfb_recipes WHERE id = ? AND business_id = ?', { recipeId, businessId })
        local station = MySQL.single.await('SELECT type FROM tsfb_stations WHERE id = ? AND business_id = ?', { stationId, businessId })
        local profile = MySQL.single.await('SELECT station_type, output_item, output_quantity, duration_seconds FROM tsfb_production_profiles WHERE recipe_id = ?', { recipeId })
        if not recipe or not station or not profile then return nil end
        local ingredients = json.decode(recipe.ingredients)
        return FoodBusiness.planProduction(ingredients, { stationType = profile.station_type, outputItem = profile.output_item,
            outputQuantity = tonumber(profile.output_quantity), durationSeconds = tonumber(profile.duration_seconds) }, station.type, batches)
    end)
    if not ok then return nil end
    return plan
end
exports('GetOwnerProductionPlan', getOwnerProductionPlan)
exports('GetInventoryCapabilities', function() return Inventory.capabilities() end)
exports('GetOwnerIngredientAvailability', function(src, businessId, recipeId, stationId, batches)
    local plan = getOwnerProductionPlan(src, businessId, recipeId, stationId, batches)
    if not plan then return nil, 'production_plan_unavailable' end
    local ok, report, reason = pcall(Inventory.inspectPlan, src, plan)
    if not ok then return nil, 'inventory_error' end
    return report, reason
end)

-- Read-only prerequisites. This result is never a reservation or permission to start cooking.
exports('GetOwnerProductionReadiness', function(src, businessId, recipeId, stationId, batches)
    local plan = getOwnerProductionPlan(src, businessId, recipeId, stationId, batches)
    if not plan then return nil, 'production_plan_unavailable' end
    local ok, result, reason = pcall(function()
        local report, inventoryError = Inventory.inspectPlan(src, plan)
        if not report then return nil, inventoryError end
        -- Re-read the station and live player state after inventory/database awaits.
        local station = MySQL.single.await('SELECT type, x, y, z, heading, routing_bucket FROM tsfb_stations WHERE id = ? AND business_id = ?', { stationId, businessId })
        if not station or station.type ~= plan.stationType then return nil, 'station_unavailable' end
        local person = Framework.player(src)
        if not person or not validText(person.id, 80) then return nil, 'player_unavailable' end
        local business = MySQL.single.await('SELECT id FROM tsfb_businesses WHERE id = ? AND owner_id = ?', { businessId, person.id })
        if not business then return nil, 'forbidden' end
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then return nil, 'position_unavailable' end
        local coords = GetEntityCoords(ped)
        if not coords then return nil, 'position_unavailable' end
        local near = FoodBusiness.isNearStation(station, coords.x, coords.y, coords.z, GetPlayerRoutingBucket(src), 2.0)
        return { productionPlan = plan, stockReport = report, nearStation = near,
            prerequisitesMet = near and report.available == true, canStart = false, reservation = false }
    end)
    if not ok then return nil, 'readiness_unavailable' end
    return result, reason
end)

if CookingJobs then
    local cookingDependencies = {
        plan = getOwnerProductionPlan,
        owner = function(src, actor, businessId)
            if not ready then return false end
            local person = Framework.player(src)
            if not person or person.id ~= actor then return false end
            return MySQL.single.await('SELECT id FROM tsfb_businesses WHERE id = ? AND owner_id = ?', { businessId, actor }) ~= nil
        end,
        near = function(src, actor, businessId, stationId, plan)
            if not ready or not plan then return false end
            local station = MySQL.single.await('SELECT type, x, y, z, heading, routing_bucket FROM tsfb_stations WHERE id = ? AND business_id = ?', { stationId, businessId })
            if not station or station.type ~= plan.stationType then return false end
            local person = Framework.player(src)
            if not person or person.id ~= actor then return false end
            local ped = GetPlayerPed(src)
            if not ped or ped == 0 then return false end
            local coords = GetEntityCoords(ped)
            return coords ~= nil and FoodBusiness.isNearStation(station, coords.x, coords.y, coords.z, GetPlayerRoutingBucket(src), 2.0)
        end,
    }
    CookingJobs.configure(cookingDependencies)
    if ConventionalCooking then ConventionalCooking.configure(cookingDependencies) end
end

exports('GetBusinessStaffRole', function(src, businessId)
    if not ready then return nil end
    return Staff.role(src, businessId)
end)
exports('HasBusinessStaffPermission', function(src, businessId, permission)
    if not ready then return nil end
    return Staff.permission(src, businessId, permission)
end)
