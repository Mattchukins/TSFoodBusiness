-- ESX bridge: independent identity/job/grade adapter.
FrameworkAdapters = FrameworkAdapters or {}
FrameworkAdapters.esx = {
    init = function()
        local core = exports['es_extended']:getSharedObject()
        if type(core) ~= 'table' or type(core.GetPlayerFromId) ~= 'function' then return nil end
        return {
            core = core,
            player = function(src)
                local player = core.GetPlayerFromId(src)
                if not player then return nil end
                local job = player.job
                return { id = player.identifier, job = job and job.name,
                    grade = job and job.grade }
            end,
        }
    end,
}
