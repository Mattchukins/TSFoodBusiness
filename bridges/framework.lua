Framework = {}

local function started(resource) return GetResourceState(resource) == 'started' end

function Framework.init()
    local available = { esx = started('es_extended'), qbox = started('qbx_core'), qbcore = started('qb-core') and not started('qbx_core') }
    local chosen = FoodBusiness.Framework
    if chosen == 'auto' then
        local count = 0
        for name, yes in pairs(available) do if yes then chosen = name; count = count + 1 end end
        if count ~= 1 then return nil, 'expected exactly one primary framework, found ' .. count end
    elseif not available[chosen] then return nil, 'configured primary framework is not running: ' .. tostring(chosen) end
    if chosen == 'esx' then Framework.core = exports['es_extended']:getSharedObject() end
    if chosen == 'qbcore' then Framework.core = exports['qb-core']:GetCoreObject() end
    Framework.name = chosen
    return true
end

function Framework.player(source)
    if Framework.name == 'esx' then
        local player = Framework.core.GetPlayerFromId(source)
        if not player then return nil end
        return { id = player.identifier, job = player.job and player.job.name, grade = player.job and player.job.grade }
    end
    local player = Framework.name == 'qbox' and exports.qbx_core:GetPlayer(source) or Framework.core.Functions.GetPlayer(source)
    if not player or not player.PlayerData then return nil end
    local data = player.PlayerData
    local grade = data.job and data.job.grade
    return { id = data.citizenid, job = data.job and data.job.name,
        grade = type(grade) == 'table' and grade.level or grade }
end
