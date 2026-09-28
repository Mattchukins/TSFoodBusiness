local ready = false
local allowedTypes = { restaurant = true, cafe = true, bakery = true, bar = true, takeaway = true, kiosk = true, truck = true }
local function validText(value, max)
    return type(value) == 'string' and #value >= 2 and #value <= max and not value:find('[%c]')
end
local function validId(value)
    return type(value) == 'string' and value:match('^[a-fA-F0-9%-]+$') and #value == 36
end
local function validPrice(value)
    return type(value) == 'number' and value == math.floor(value) and value >= 1 and value <= 10000000
end
local function exactKeys(data, keys)
    for key in pairs(data) do if not keys[key] then return false end end
    return true
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
        print('[ts-foodbusiness] disabled: apply sql/001_initial.sql then sql/002_catalogs.sql; expected schema ' .. FoodBusiness.RequiredSchema)
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
    if (request.action == 'listRecipes' or request.action == 'createRecipe'
        or request.action == 'quoteRecipe' or request.action == 'listSuppliers'
        or request.action == 'createSupplier') and validId(request.data.businessId) then
        local data = request.data
        local business = MySQL.single.await('SELECT id FROM tsfb_businesses WHERE id = ? AND owner_id = ?',
            { data.businessId, person.id })
        if not business then respond(src, request.requestId, { ok = false, error = 'forbidden' }); return end
        if request.action == 'listRecipes' and FoodBusiness.Modules.recipes then
            if not exactKeys(data, { businessId = true }) then
                respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
            end
            local rows = MySQL.query.await('SELECT id, name, price_cents, ingredients FROM tsfb_recipes WHERE business_id = ? ORDER BY name LIMIT 200', { data.businessId })
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
                or type(data.ingredients) ~= 'table' or #data.ingredients < 1 or #data.ingredients > 16
                or not exactKeys(data, { businessId = true, name = true, priceCents = true, ingredients = true }) then
                respond(src, request.requestId, { ok = false, error = 'invalid_payload' }); return
            end
            local ingredientCount = 0
            for key in pairs(data.ingredients) do
                if type(key) ~= 'number' or key ~= math.floor(key) or key < 1 or key > #data.ingredients then
                    respond(src, request.requestId, { ok = false, error = 'invalid_ingredient' }); return
                end
                ingredientCount = ingredientCount + 1
            end
            if ingredientCount ~= #data.ingredients then
                respond(src, request.requestId, { ok = false, error = 'invalid_ingredient' }); return
            end
            for _, ingredient in ipairs(data.ingredients) do
                if type(ingredient) ~= 'table' or not exactKeys(ingredient, { item = true, quantity = true })
                    or not validText(ingredient.item, 64) or type(ingredient.quantity) ~= 'number'
                    or ingredient.quantity ~= math.floor(ingredient.quantity) or ingredient.quantity < 1
                    or ingredient.quantity > 1000 then
                    respond(src, request.requestId, { ok = false, error = 'invalid_ingredient' }); return
                end
            end
            local id = MySQL.scalar.await('SELECT UUID()')
            local ok, done = pcall(function() return MySQL.transaction.await({
                { query = 'INSERT INTO tsfb_recipes (id, business_id, name, price_cents, ingredients) VALUES (?, ?, ?, ?, ?)',
                    values = { id, data.businessId, data.name, data.priceCents, json.encode(data.ingredients) } },
                { query = 'INSERT INTO tsfb_audit (action, actor_id, business_id, correlation_id, details) VALUES (?, ?, ?, ?, ?)',
                    values = { 'recipe.create', person.id, data.businessId, person.id .. ':' .. request.requestId,
                        json.encode({ id = id, name = data.name, priceCents = data.priceCents }) } },
            }) end)
            respond(src, request.requestId, ok and done and { ok = true, id = id } or { ok = false, error = 'transaction_failed' })
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
    end
    respond(src, request.requestId, { ok = false, error = 'unknown_action' })
end)
