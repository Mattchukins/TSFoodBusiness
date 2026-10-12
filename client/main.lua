local uiOpen = false
local pending = {}
local sequence = 0
local pendingCount = 0

local function closeUi()
    if not uiOpen then return end
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(data, cb)
    if type(data) ~= 'table' or next(data) ~= nil then
        cb({ ok = false, error = 'invalid_payload' })
        return
    end
    closeUi()
    cb({ ok = true })
end)

RegisterNUICallback('request', function(data, cb)
    if type(data) ~= 'table' or type(data.action) ~= 'string' or type(data.payload) ~= 'table'
        or (data.action ~= 'listBusinesses' and data.action ~= 'listPresets' and data.action ~= 'listStationTypes'
            and data.action ~= 'listStaffRoles' and data.action ~= 'listStaff'
            and data.action ~= 'setStaffDuty' and data.action ~= 'assignStaffMember' and data.action ~= 'updateStaffMember' and data.action ~= 'removeStaffMember'
            and data.action ~= 'listCookingJobs' and data.action ~= 'startCookingJob'
            and data.action ~= 'finishCookingJob' and data.action ~= 'cancelCookingJob'
            and data.action ~= 'inspectCookingJob' and data.action ~= 'resumeCookingJob'
            and data.action ~= 'createBusiness'
            and data.action ~= 'renameBusiness'
            and data.action ~= 'listAudit'
            and data.action ~= 'listStations' and data.action ~= 'createStation'
            and data.action ~= 'deleteStation'
            and data.action ~= 'moveStation'
            and data.action ~= 'updateStation'
            and data.action ~= 'checkProductionStock' and data.action ~= 'deleteProductionProfile' and data.action ~= 'previewProduction' and data.action ~= 'getProductionProfile' and data.action ~= 'setProductionProfile'
            and data.action ~= 'getOperations' and data.action ~= 'setOperations'
            and data.action ~= 'listRecipes' and data.action ~= 'createRecipe'
            and data.action ~= 'listSuppliers' and data.action ~= 'createSupplier'
            and data.action ~= 'quoteRecipe' and data.action ~= 'updateRecipe'
            and data.action ~= 'deleteRecipe' and data.action ~= 'updateSupplier'
            and data.action ~= 'deleteSupplier') then
        cb({ ok = false, error = 'invalid_payload' }); return
    end
    for key in pairs(data) do
        if key ~= 'action' and key ~= 'payload' then cb({ ok = false, error = 'invalid_payload' }); return end
    end
    if pendingCount >= 10 then cb({ ok = false, error = 'too_many_requests' }); return end
    sequence = sequence + 1
    local id = ('%d-%d'):format(GetGameTimer(), sequence)
    pending[id] = cb
    pendingCount = pendingCount + 1
    TriggerServerEvent('tsfb:request', { requestId = id, action = data.action, data = data.payload })
    SetTimeout(10000, function()
        if pending[id] then pending[id]({ ok = false, error = 'timeout' }); pending[id] = nil; pendingCount = pendingCount - 1 end
    end)
end)

RegisterNetEvent('tsfb:response', function(message)
    if type(message) ~= 'table' or type(message.requestId) ~= 'string' then return end
    local cb = pending[message.requestId]
    if cb then pending[message.requestId] = nil; pendingCount = pendingCount - 1; cb(message.result) end
end)

-- Development shell only. No gameplay operation is exposed by this command.
RegisterCommand('foodbusiness_ui', function()
    if uiOpen then closeUi() return end
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        for id, cb in pairs(pending) do cb({ ok = false, error = 'resource_stopped' }); pending[id] = nil end
        pendingCount = 0
        SetNuiFocus(false, false)
    end
end)
