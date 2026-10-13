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
            and data.action ~= 'listMyStaffBusinesses' and data.action ~= 'setMyStaffDuty' and data.action ~= 'listStaffShifts' and data.action ~= 'listStaffRoles' and data.action ~= 'listStaff'
            and data.action ~= 'setStaffDuty' and data.action ~= 'assignStaffMember' and data.action ~= 'updateStaffMember' and data.action ~= 'removeStaffMember'
            and data.action ~= 'listCookingTargets' and data.action ~= 'beginCooking' and data.action ~= 'finishCooking' and data.action ~= 'cancelCooking'
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

-- Station integrations may call exports['ts-foodbusiness']:CookRecipe(...)
local cooking = false
local function ask(action, data, callback)
    sequence = sequence + 1
    local id = ('cook-%d-%d'):format(GetGameTimer(), sequence)
    pending[id] = callback
    pendingCount = pendingCount + 1
    TriggerServerEvent('tsfb:request', { requestId = id, action = action, data = data })
    SetTimeout(10000, function()
        if pending[id] then
            pending[id]({ ok = false, error = 'timeout' })
            pending[id] = nil
            pendingCount = pendingCount - 1
        end
    end)
end
exports('CookRecipe', function(businessId, recipeId, stationId, batches)
    if cooking or pendingCount >= 10 then return false end
    cooking = true
    ask('beginCooking', { businessId = businessId, recipeId = recipeId,
        stationId = stationId, batches = batches or 1 }, function(start)
        if not start or not start.ok then
            cooking = false
            lib.notify({ type = 'error', description = start and start.error or 'Cooking unavailable' })
            return
        end
        local completed = lib.progressBar({
            duration = start.durationMs, label = 'Preparing food',
            canCancel = true, disable = { move = true, car = true, combat = true },
        })
        ask(completed and 'finishCooking' or 'cancelCooking', { token = start.token }, function(result)
            cooking = false
            if completed then
                lib.notify({ type = result and result.ok and 'success' or 'error',
                    description = result and (result.ok and 'Food prepared' or result.error) or 'Cooking failed' })
            end
        end)
    end)
    return true
end)

-- Optional ox_target integration for server-configured station locations.
-- The server still validates ownership, recipe, station and distance.
local targetZones = {}
exports('RegisterCookingStation', function(config)
    if type(config) ~= 'table' or type(config.businessId) ~= 'string'
        or type(config.recipeId) ~= 'string' or type(config.stationId) ~= 'string'
        or type(config.coords) ~= 'vector3' or GetResourceState('ox_target') ~= 'started' then
        return false
    end
    local batches = config.batches or 1
    if type(batches) ~= 'number' or batches ~= math.floor(batches)
        or batches < 1 or batches > 100 then return false end
    local zone = exports.ox_target:addSphereZone({
        coords = config.coords, radius = 1.5, debug = false,
        options = {{
            name = 'tsfb_cook_' .. config.stationId .. '_' .. config.recipeId,
            icon = 'fa-solid fa-utensils',
            label = config.label or 'Prepare food',
            distance = 2.0,
            onSelect = function()
                exports[GetCurrentResourceName()]:CookRecipe(
                    config.businessId, config.recipeId, config.stationId, batches)
            end,
        }},
    })
    if not zone then return false end
    targetZones[zone] = true
    return zone
end)
exports('RemoveCookingStation', function(zone)
    if not targetZones[zone] then return false end
    targetZones[zone] = nil
    if GetResourceState('ox_target') == 'started' then
        exports.ox_target:removeZone(zone)
    end
    return true
end)

-- Refresh local target zones from the server's owned, compatible recipes.
local automaticZones = {}
local refreshingCookingTargets = false
local function clearAutomaticZones()
    for _, zone in ipairs(automaticZones) do
        exports[GetCurrentResourceName()]:RemoveCookingStation(zone)
    end
    automaticZones = {}
end
local function refreshCookingTargets()
    if refreshingCookingTargets or pendingCount >= 10 or GetResourceState('ox_target') ~= 'started' then return end
    refreshingCookingTargets = true
    ask('listCookingTargets', {}, function(result)
        refreshingCookingTargets = false
        if not result or not result.ok or type(result.targets) ~= 'table' then return end
        clearAutomaticZones()
        for _, target in ipairs(result.targets) do
            if type(target.x) == 'number' and type(target.y) == 'number'
                and type(target.z) == 'number'
                then
                local zone = exports[GetCurrentResourceName()]:RegisterCookingStation({
                    businessId = target.businessId, recipeId = target.recipeId,
                    stationId = target.stationId,
                    coords = vector3(target.x, target.y, target.z),
                    label = 'Prepare ' .. tostring(target.recipeName or 'food'),
                })
                if zone then automaticZones[#automaticZones + 1] = zone end
            end
        end
    end)
end
RegisterCommand('foodbusiness_refresh_cooking', refreshCookingTargets, false)
CreateThread(function()
    Wait(5000)
    refreshCookingTargets()
end)
AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'ox_target' then
        Wait(1000)
        refreshCookingTargets()
    end
end)

-- Refresh after owner edits and periodically to follow server-side changes.
CreateThread(function()
    while true do
        Wait(60000)
        if not cooking then refreshCookingTargets() end
    end
end)

RegisterNetEvent('tsfb:refreshCookingTargets', function()
    refreshCookingTargets()
end)
