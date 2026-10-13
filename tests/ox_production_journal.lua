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

-- A released tombstone is idempotent and cannot overwrite an active claim.
local stored
json = { encode = function() return '{}' end }
MySQL.update = { await = function(_, values)
    if not stored then stored = { job_id = values[1], owner_id = values[2], plan_key = values[3], state = 'released', revision = 0 } end
    return 1
end }
MySQL.single.await = function() return stored end
local payload = { jobId = id, ownerId = 'owner-42', planKey = 'plan-key', plan = {} }
assert(journal.releaseAbsent(payload).state == 'released')
assert(journal.releaseAbsent(payload).state == 'released')
stored.state = 'reserved'
assert(select(2, journal.releaseAbsent(payload)) == 'reservation_conflict')
print('ox production journal diagnostic validation and release tombstones passed (mocked)')
