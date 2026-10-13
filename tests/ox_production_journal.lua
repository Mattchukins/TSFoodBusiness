local id = '12345678-1234-1234-1234-123456789abc'
local row
MySQL = { single = { await = function(query, values)
    assert(query:find('WHERE job_id = ?', 1, true))
    assert(values[1] == id)
    return row
end } }
local journal = dofile('integrations/tsfb-ox-inventory/journal.lua')
assert(journal.inspect('invalid') == nil)
assert(journal.inspect(id).found == false)
row = { job_id = id, owner_id = 'owner-42', plan_key = 'plan-key', state = 'intent', revision = 0 }
assert(journal.inspect(id).state == 'intent')
row.state = 'reserved'; row.revision = 1
assert(journal.inspect(id).state == 'reserved')
row.state = 'committed'; row.revision = 2
assert(journal.inspect(id).state == 'committed')
row.state = 'released'
assert(journal.inspect(id).state == 'released')
row.state = 'unknown'
assert(select(2, journal.inspect(id)) == 'invalid_journal_row')
row.state = 'reserved'; row.revision = -1
assert(select(2, journal.inspect(id)) == 'invalid_journal_row')
MySQL.single.await = function() error('db stopped') end
assert(select(2, journal.inspect(id)) == 'database_unavailable')
print('ox production journal diagnostic validation passed (mocked)')
