Schema = {}
Schema.required = {
    tsfb_schema = { 'version' },
    tsfb_businesses = { 'id', 'owner_id', 'name', 'type', 'config', 'created_at' },
    tsfb_audit = { 'id', 'action', 'actor_id', 'business_id', 'correlation_id', 'details', 'created_at' },
    tsfb_recipes = { 'id', 'business_id', 'name', 'price_cents', 'ingredients', 'created_at' },
    tsfb_suppliers = { 'id', 'business_id', 'name', 'item_name', 'unit_price_cents', 'created_at' },
    tsfb_operations = { 'business_id', 'opens_minute', 'closes_minute', 'seat_capacity', 'queue_capacity', 'updated_at' },
    tsfb_production_profiles = { 'recipe_id', 'station_type', 'output_item', 'output_quantity', 'duration_seconds', 'updated_at' },
    tsfb_stations = { 'id', 'business_id', 'name', 'type', 'x', 'y', 'z', 'heading', 'routing_bucket', 'created_at' },
}

function Schema.checkColumns(rows)
    if type(rows) ~= 'table' then return false, 'schema metadata unavailable' end
    local available = {}
    for _, row in ipairs(rows) do
        if type(row) ~= 'table' or type(row.table_name) ~= 'string' or type(row.column_name) ~= 'string' then
            return false, 'invalid schema metadata'
        end
        available[row.table_name .. '.' .. row.column_name] = true
    end
    for name, columns in pairs(Schema.required) do
        for _, column in ipairs(columns) do
            if not available[name .. '.' .. column] then return false, 'missing column ' .. name .. '.' .. column end
        end
    end
    return true
end

function Schema.verify()
    local ok, rows = pcall(function()
        return MySQL.query.await("SELECT TABLE_NAME AS table_name, COLUMN_NAME AS column_name FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('tsfb_schema', 'tsfb_businesses', 'tsfb_audit', 'tsfb_recipes', 'tsfb_suppliers', 'tsfb_operations', 'tsfb_stations', 'tsfb_production_profiles')")
    end)
    if not ok then return false, 'schema metadata query failed' end
    local valid, reason = Schema.checkColumns(rows)
    if not valid then return false, reason end
    local metadataOk, tables, indexes = pcall(function()
        local engines = MySQL.query.await("SELECT TABLE_NAME AS table_name, ENGINE AS engine FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('tsfb_schema', 'tsfb_businesses', 'tsfb_audit', 'tsfb_recipes', 'tsfb_suppliers', 'tsfb_operations', 'tsfb_stations', 'tsfb_production_profiles')")
        local keys = MySQL.query.await("SELECT TABLE_NAME AS table_name, INDEX_NAME AS index_name, NON_UNIQUE AS non_unique, COLUMN_NAME AS column_name, SUB_PART AS sub_part FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('tsfb_schema', 'tsfb_businesses', 'tsfb_audit', 'tsfb_recipes', 'tsfb_suppliers', 'tsfb_operations', 'tsfb_stations', 'tsfb_production_profiles')")
        return engines, keys
    end)
    if not metadataOk then return false, 'schema integrity query failed' end
    return Schema.checkIntegrity(tables, indexes)
end

function Schema.checkIntegrity(tables, indexes)
    if type(tables) ~= 'table' or type(indexes) ~= 'table' then return false, 'integrity metadata unavailable' end
    local engines, keys = {}, {}
    for _, row in ipairs(tables) do
        if type(row) ~= 'table' or type(row.table_name) ~= 'string' or type(row.engine) ~= 'string' then return false, 'invalid engine metadata' end
        engines[row.table_name] = row.engine:lower()
    end
    for _, row in ipairs(indexes) do
        if type(row) ~= 'table' or type(row.table_name) ~= 'string' or type(row.index_name) ~= 'string' then return false, 'invalid index metadata' end
        local name = row.table_name .. '.' .. row.index_name
        keys[name] = keys[name] or {}
        keys[name][#keys[name] + 1] = row
    end
    local function uniqueColumn(tableName, indexName, column)
        local entries = keys[tableName .. '.' .. indexName]
        return entries and #entries == 1 and entries[1].column_name == column
            and tonumber(entries[1].non_unique) == 0 and entries[1].sub_part == nil
    end
    for name in pairs(Schema.required) do
        if engines[name] ~= 'innodb' then return false, 'transactional InnoDB table required: ' .. name end
        local column = name == 'tsfb_schema' and 'version' or name == 'tsfb_operations' and 'business_id' or name == 'tsfb_production_profiles' and 'recipe_id' or 'id'
        if not uniqueColumn(name, 'PRIMARY', column) then return false, 'invalid primary key: ' .. name end
    end
    for name in pairs(keys) do
        local prefix = 'tsfb_audit.'
        if name:sub(1, #prefix) == prefix and uniqueColumn('tsfb_audit', name:sub(#prefix + 1), 'correlation_id') then return true end
    end
    return false, 'unique audit correlation key required'
end
