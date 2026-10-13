-- Experimental SQL-owned stock API. Never advertise this as atomic ox_inventory.
-- Only install schema.sql, stock_schema.sql and stock_procedures.sql on an
-- isolated MySQL 8 test database. Gameplay mutation exports remain disabled.
local Engine = LoadResourceFile and assert(load(LoadResourceFile(
    GetCurrentResourceName(), 'stock_engine.lua'), '@stock_engine.lua'))()
    or dofile('integrations/tsfb-ox-inventory/stock_engine.lua')

local function procedure(name, args)
    if not MySQL or not MySQL.query or not MySQL.query.await then
        error('database_unavailable')
    end
    local allowed = { tsfb_stock_reserve = true,
        tsfb_stock_commit = true, tsfb_stock_release = true }
    if not allowed[name] then error('invalid_procedure') end
    local marks = name == 'tsfb_stock_reserve' and '?,?,?,?' or '?,?,?'
    local rows = MySQL.query.await('CALL ' .. name .. '(' .. marks .. ')', args)
    -- oxmysql CALL responses can be nested result sets.
    if type(rows) == 'table' and type(rows[1]) == 'table'
        and type(rows[1][1]) == 'table' then rows = rows[1] end
    if type(rows) ~= 'table' or type(rows[1]) ~= 'table' then
        error('missing_procedure_receipt')
    end
    return rows[1]
end

exports('SqlStockReserveExperimental', function(payload)
    return Engine.reserve(payload, procedure, json.encode)
end)
exports('SqlStockCommitExperimental', function(payload)
    return Engine.commit(payload, procedure)
end)
exports('SqlStockReleaseExperimental', function(payload)
    return Engine.release(payload, procedure)
end)
