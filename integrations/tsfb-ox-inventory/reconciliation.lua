-- Read-only reconciliation diagnostics for SQL-owned stock. Never silently
-- settle escrow or infer that ox_inventory has been modified.
local Reconciliation = {}
local function database()
    return MySQL and MySQL.query and type(MySQL.query.await) == 'function'
end
function Reconciliation.scan()
    if not database() then return nil, 'database_unavailable' end
    local ok, rows = pcall(function()
        return MySQL.query.await([[
            SELECT r.job_id, r.owner_id, r.state, r.revision,
                   COUNT(e.item) AS escrow_rows,
                   COALESCE(SUM(e.quantity), 0) AS escrow_quantity
            FROM tsfb_ox_production_receipts AS r
            LEFT JOIN tsfb_ox_escrow AS e ON e.job_id = r.job_id
            GROUP BY r.job_id, r.owner_id, r.state, r.revision
            HAVING (r.state = 'reserved' AND COUNT(e.item) = 0)
                OR (r.state <> 'reserved' AND COUNT(e.item) > 0)
                OR r.state = 'intent'
            ORDER BY r.job_id
        ]], {})
    end)
    if not ok or type(rows) ~= 'table' then return nil, 'database_unavailable' end
    local anomalies = {}
    for _, row in ipairs(rows) do
        if type(row) ~= 'table' or type(row.job_id) ~= 'string'
            or type(row.owner_id) ~= 'string' or type(row.state) ~= 'string'
            or tonumber(row.escrow_rows) == nil then
            return nil, 'invalid_reconciliation_row'
        end
        anomalies[#anomalies + 1] = {
            jobId = row.job_id, ownerId = row.owner_id, state = row.state,
            revision = tonumber(row.revision),
            escrowRows = tonumber(row.escrow_rows),
            escrowQuantity = tonumber(row.escrow_quantity),
        }
    end
    return anomalies
end
return Reconciliation
