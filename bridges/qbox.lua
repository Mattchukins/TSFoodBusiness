-- QBox bridge: directly calls qbx_core; a qb-core compatibility layer
-- must not be considered an additional primary framework.
FrameworkAdapters = FrameworkAdapters or {}
FrameworkAdapters.qbox = {
    init = function()
        return {
            player = function(src)
                local player = exports.qbx_core:GetPlayer(src)
                if not player or not player.PlayerData then return nil end
                local data = player.PlayerData
                local grade = data.job and data.job.grade
                return { id = data.citizenid, job = data.job and data.job.name,
                    grade = type(grade) == 'table' and grade.level or grade }
            end,
        }
    end,
}
