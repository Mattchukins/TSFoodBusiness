for _, path in ipairs({
    'server/conventional_cooking.lua', 'server/staff.lua', 'shared/staff.lua', 'server/jobs.lua', 'shared/jobs.lua', 'server/main.lua', 'server/schema.lua', 'client/main.lua', 'shared/config.lua',
    'shared/operations.lua', 'shared/presets.lua', 'shared/recipes.lua', 'shared/stations.lua', 'shared/conventional_timing.lua', 'bridges/framework.lua', 'bridges/inventory.lua', 'integrations/tsfb-ox-inventory/server.lua',
}) do
    local chunk, err = loadfile(path)
    assert(chunk, err)
    print(path .. ' parsed')
end
