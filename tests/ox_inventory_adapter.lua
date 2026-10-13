local callbacks = {}
local started = true
local items = { flour = { name = 'flour' }, bread = { name = 'bread' } }
local counts = { flour = 8, bread = 1 }
GetResourceState = function(name)
    assert(name == 'ox_inventory')
    return started and 'started' or 'stopped'
end
exports = setmetatable({ ox_inventory = {
    Items = function(_, item) return items[item] end,
    GetItemCount = function(_, source, item)
        assert(source == 42)
        return counts[item] or 0
    end,
} }, {
    __call = function(_, name, fn)
        assert(type(name) == 'string' and type(fn) == 'function')
        callbacks[name] = fn
    end,
})
dofile('integrations/tsfb-ox-inventory/server.lua')
assert(callbacks.ItemExists('flour') == true)
assert(callbacks.ItemExists('unknown') == false)
assert(callbacks.ItemExists('../flour') == false)
assert(callbacks.GetItemCount(42, 'flour') == 8)
assert(callbacks.GetItemCount(42, 'unknown') == 0)
assert(callbacks.GetItemCount(0, 'flour') == nil)
started = false
assert(callbacks.ItemExists('flour') == false)
assert(callbacks.GetItemCount(42, 'flour') == nil)
started = true
local original = exports.ox_inventory.GetItemCount
exports.ox_inventory.GetItemCount = function() error('provider offline') end
assert(callbacks.GetItemCount(42, 'flour') == nil)
exports.ox_inventory.GetItemCount = original
for _, operation in ipairs({
    'InspectProductionReservation', 'ReserveProduction',
    'CommitProduction', 'ReleaseProduction',
}) do
    local ok = pcall(callbacks[operation], {})
    assert(not ok, operation .. ' must fail closed')
end
print('ox_inventory read exports and disabled mutation exports passed (mocked)')
