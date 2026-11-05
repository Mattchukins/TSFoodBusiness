-- QBCore bridge: independent identity/job/grade adapter.
FrameworkAdapters = FrameworkAdapters or {}
FrameworkAdapters.qbcore = {
    init = function()
        local core = exports['qb-core']:GetCoreObject()
        if type(core) ~= 'table' or type(core.Functions) ~= 'table'
            or type(core.Functions.GetPlayer) ~= 'function' then return nil end
        return {
            core = core,
            player = function(src)
                local player = core.Functions.GetPlayer(src)
                if not player or not player.PlayerData then return nil end
                local data = player.PlayerData
                local grade = data.job and data.job.grade
                return { id = data.citizenid, job = data.job and data.job.name,
                    grade = type(grade) == 'table' and grade.level or grade }
            end,
        }
    end,
}
