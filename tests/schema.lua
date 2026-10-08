dofile('server/schema.lua')
local rows = {}
for name, columns in pairs(Schema.required) do
    for _, column in ipairs(columns) do rows[#rows + 1] = { table_name = name, column_name = column } end
end
assert(Schema.checkColumns(rows))
local removed = table.remove(rows)
local ok, reason = Schema.checkColumns(rows)
assert(not ok and reason:find('missing column'))
rows[#rows + 1] = removed
local fixture = dofile('tests/schema_fixture.lua')
MySQL = { query = { await = function(query)
    if query:find('information_schema.TABLES', 1, true) then return fixture.tables end
    if query:find('information_schema.STATISTICS', 1, true) then return fixture.indexes end
    return rows
end } }
assert(Schema.verify())
fixture.tables[1].engine = 'MyISAM'
assert(not Schema.verify())
fixture.tables[1].engine = 'InnoDB'
local correlation = fixture.indexes[#fixture.indexes]
correlation.non_unique = 1
assert(not Schema.verify())
correlation.non_unique = 0
correlation.sub_part = 20
assert(not Schema.verify())
correlation.sub_part = nil
assert(Schema.verify())
for _, entry in ipairs(fixture.indexes) do
    if entry.table_name == 'tsfb_cooking_jobs' and entry.index_name == 'active_station' then
        entry.non_unique = 1; assert(not Schema.verify()); entry.non_unique = 0
        entry.sub_part = 20; assert(not Schema.verify()); entry.sub_part = nil
    end
end
assert(Schema.verify())
MySQL.query.await = function() error('unavailable database') end
assert(not Schema.verify())
assert(not Schema.checkColumns(nil))
assert(not Schema.checkColumns({ { table_name = 'tsfb_schema' } }))
print('schema presence contract passed')
