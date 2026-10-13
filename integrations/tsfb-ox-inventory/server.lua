-- ox_inventory integration. Only read exports are exposed until a provider can
-- guarantee atomic, durable ingredient escrow and output delivery.
local Journal = LoadResourceFile and assert(load(LoadResourceFile(GetCurrentResourceName(), 'journal.lua'), '@journal.lua'))() or dofile('integrations/tsfb-ox-inventory/journal.lua')

-- A pinned upstream extension must explicitly advertise durable atomic mutations.
-- Until that extension exists, this adapter must not be configured as verified.
exports('ProductionMutationCapabilities', function()
    return {
        provider = 'ox_inventory',
        upstreamCommit = '488aa6d754dfbf7d169f355ccbd647dc60c5ec3a',
        atomicProduction = false,
        durableEscrow = false,
        atomicOutput = false,
        restartReconciliation = false,
        liveVerified = false,
    }
end)

local function validItem(item)
    return type(item) == 'string' and #item >= 2 and #item <= 64
        and item:match('^[%w_%-]+$') ~= nil
end

local function ready()
    return GetResourceState('ox_inventory') == 'started'
end

exports('ItemExists', function(item)
    if not validItem(item) then return false end
    if not ready() then return nil end
    local ok, result = pcall(function()
        return exports.ox_inventory:Items(item)
    end)
    if not ok then return nil end
    return type(result) == 'table'
end)

exports('GetItemCount', function(source, item)
    if not ready() or type(source) ~= 'number' or source < 1
        or source ~= math.floor(source) or not validItem(item) then return nil end
    local ok, count = pcall(function()
        return exports.ox_inventory:GetItemCount(source, item)
    end)
    if not ok or type(count) ~= 'number' or count < 0 or count ~= math.floor(count) then
        return nil
    end
    return count
end)

-- ox_inventory RemoveItem/AddItem are separate operations. Calling them in
-- sequence cannot satisfy the durable atomic-production contract.
-- Never claim a reservation or a commit when no such transaction occurred.
local function unsupported()
    error('tsfb_ox_inventory_atomic_mutations_not_implemented')
end
exports('InspectProductionReservation', function(payload)
    local receipt, reason = Journal.inspectReceipt(payload)
    if not receipt then error(reason or 'journal_unavailable') end
    return receipt
end)
exports('ReserveProduction', unsupported)
exports('CommitProduction', unsupported)
exports('ReleaseProduction', function(payload)
    local receipt, reason = Journal.releaseAbsent(payload)
    if not receipt then error(reason or 'journal_unavailable') end
    return receipt
end)
