local fixture = { columns = {}, tables = {}, indexes = {} }
for name, columns in pairs(Schema.required) do
    for _, column in ipairs(columns) do fixture.columns[#fixture.columns + 1] = { table_name = name, column_name = column } end
    fixture.tables[#fixture.tables + 1] = { table_name = name, engine = 'InnoDB' }
    fixture.indexes[#fixture.indexes + 1] = { table_name = name, index_name = 'PRIMARY', non_unique = 0,
        column_name = name == 'tsfb_schema' and 'version' or name == 'tsfb_operations' and 'business_id' or name == 'tsfb_staff_duty' and 'staff_id' or name == 'tsfb_production_profiles' and 'recipe_id' or 'id' }
end
for name, columns in pairs({ job_request = { 'actor_id', 'request_token' }, active_station = { 'station_slot' }, active_actor = { 'actor_slot' } }) do
    for _, column in ipairs(columns) do fixture.indexes[#fixture.indexes + 1] = { table_name = 'tsfb_cooking_jobs', index_name = name, non_unique = 0, column_name = column } end
end
for _, column in ipairs({ 'business_id', 'member_id' }) do
    fixture.indexes[#fixture.indexes + 1] = { table_name = 'tsfb_staff', index_name = 'business_member', non_unique = 0, column_name = column }
end
fixture.indexes[#fixture.indexes + 1] = { table_name = 'tsfb_staff_shifts', index_name = 'active_staff', non_unique = 0, column_name = 'staff_slot' }
fixture.indexes[#fixture.indexes + 1] = { table_name = 'tsfb_audit', index_name = 'correlation_id', non_unique = 0, column_name = 'correlation_id' }
return fixture
