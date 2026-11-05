-- Select one primary server framework. Identity never comes from the NUI.
Framework = {}
FrameworkAdapters = FrameworkAdapters or {}

local function started(name)
    return GetResourceState(name) == 'started'
end

function Framework.init()
    Framework.adapter, Framework.core, Framework.name = nil, nil, nil
    local available = {
        esx = started('es_extended'),
        qbox = started('qbx_core'),
        qbcore = started('qb-core') and not started('qbx_core'),
    }
    local count, detected = 0, nil
    for name, isRunning in pairs(available) do
        if isRunning then count = count + 1; detected = name end
    end
    if count ~= 1 then
        return nil, 'expected exactly one primary framework, found ' .. count
    end
    local selected = FoodBusiness.Framework
    if selected == 'auto' then selected = detected end
    if selected ~= detected then
        return nil, 'configured primary framework is not running: ' .. tostring(selected)
    end
    local definition = FrameworkAdapters[selected]
    if not definition or type(definition.init) ~= 'function' then
        return nil, 'framework adapter not installed: ' .. tostring(selected)
    end
    local ok, adapter = pcall(definition.init)
    if not ok or type(adapter) ~= 'table' or type(adapter.player) ~= 'function' then
        return nil, 'framework adapter initialization failed: ' .. tostring(selected)
    end
    Framework.adapter, Framework.core, Framework.name = adapter, adapter.core, selected
    return true
end

function Framework.player(src)
    if type(src) ~= 'number' or src < 1 or src ~= math.floor(src)
        or not Framework.adapter then return nil end
    local ok, person = pcall(Framework.adapter.player, src)
    if not ok or type(person) ~= 'table' or type(person.id) ~= 'string'
        or #person.id < 2 or #person.id > 80
        or person.id:find('[%c]') then return nil end
    return { id = person.id, job = person.job, grade = person.grade }
end
