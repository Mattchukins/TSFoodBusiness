for _, path in ipairs({
    'server/staff.lua', 'shared/staff.lua', 'server/jobs.lua', 'shared/jobs.lua', 'server/main.lua', 'server/schema.lua', 'client/main.lua', 'shared/config.lua',
    'shared/operations.lua', 'shared/presets.lua', 'shared/recipes.lua', 'shared/stations.lua', 'bridges/framework.lua', 'bridges/inventory.lua',
}) do
    local chunk, err = loadfile(path)
    assert(chunk, err)
    print(path .. ' parsed')
end
