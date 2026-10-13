local uiOpen = false
local pending = {}
local sequence = 0
local pendingCount = 0
local refreshCookingTargets
local refreshActions = {
    createStation = true, moveStation = true, updateStation = true, deleteStation = true,
    createRecipe = true, updateRecipe = true, deleteRecipe = true,
    setProductionProfile = true, deleteProductionProfile = true,
}
local refreshRequests = {}

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
    if refreshActions[data.action] then refreshRequests[id] = true end
    pendingCount = pendingCount + 1
    TriggerServerEvent('tsfb:request', { requestId = id, action = data.action, data = data.payload })
    SetTimeout(10000, function()
        local callback = pending[id]
        if callback then
            pending[id] = nil
            refreshRequests[id] = nil
            pendingCount = pendingCount - 1
            callback({ ok = false, error = 'timeout' })
        end
    end)
end)

RegisterNetEvent('tsfb:response', function(message)
    if type(message) ~= 'table' or type(message.requestId) ~= 'string' then return end
    local cb = pending[message.requestId]
    if cb then
        pending[message.requestId] = nil
        pendingCount = pendingCount - 1
        local shouldRefresh = refreshRequests[message.requestId]
        refreshRequests[message.requestId] = nil
        cb(message.result)
        if shouldRefresh and type(message.result) == 'table' and message.result.ok == true
            and refreshCookingTargets then SetTimeout(250, refreshCookingTargets) end
    end
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
        local callbacks = pending
        pending = {}
        refreshRequests = {}
        pendingCount = 0
        for _, cb in pairs(callbacks) do cb({ ok = false, error = 'resource_stopped' }) end
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
        local callback = pending[id]
        if callback then
            pending[id] = nil
            pendingCount = pendingCount - 1
            callback({ ok = false, error = 'timeout' })
        end
    end)
end
local cookingErrors = {
    cooking_busy = 'You are already preparing food',
    cooking_disabled = 'Cooking is not enabled on this server',
    insufficient_ingredients = 'You do not have the required ingredients',
    output_full = 'Not enough inventory space for the prepared food',
    station_not_near = 'Move closer to the cooking station',
    forbidden = 'You no longer have permission to use this kitchen',
    cooking_not_ready = 'Food is still being prepared',
    cooking_expired = 'Cooking took too long to complete. Please try again',
    inventory_unavailable = 'Inventory is temporarily unavailable',
    manual_inventory_recovery_required = 'Inventory needs administrator review',
    timeout = 'The server did not respond in time',
}
local function cookingMessage(error, fallback)
    return cookingErrors[error] or fallback
end
exports('CookRecipe', function(businessId, recipeId, stationId, batches)
    if cooking or pendingCount >= 10 then return false end
    cooking = true
    ask('beginCooking', { businessId = businessId, recipeId = recipeId,
        stationId = stationId, batches = batches or 1 }, function(start)
        if not start or not start.ok then
            cooking = false
            lib.notify({ type = 'error', description = cookingMessage(start and start.error, 'Cooking unavailable') })
            return
        end
        if type(start.token) ~= 'string' or type(start.durationMs) ~= 'number'
            or start.durationMs < 1000 or start.durationMs > 3600000 then
            ask('cancelCooking', { token = type(start.token) == 'string' and start.token or '' }, function() end)
            cooking = false
            lib.notify({ type = 'error', description = 'Invalid cooking response' })
            return
        end
        local progressOk, completed = pcall(function()
            return lib.progressBar({
                duration = start.durationMs, label = 'Preparing food',
                canCancel = true, disable = { move = true, car = true, combat = true },
            })
        end)
        if not progressOk then completed = false end
        ask(completed and 'finishCooking' or 'cancelCooking', { token = start.token }, function(result)
            cooking = false
            if completed then
                lib.notify({ type = result and result.ok and 'success' or 'error',
                    description = result and (result.ok and 'Food prepared' or cookingMessage(result.error, 'Cooking failed')) or 'Cooking failed' })
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
    if type(config.label) ~= 'nil' and (type(config.label) ~= 'string'
        or #config.label > 120) then return false end
    local batches = config.batches or 1
    if type(batches) ~= 'number' or batches ~= math.floor(batches)
        or batches < 1 or batches > 100 then return false end
    local ok, zone = pcall(function() return exports.ox_target:addSphereZone({
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
    }) end)
    if not ok or not zone then return false end
    targetZones[zone] = true
    return zone
end)
exports('RemoveCookingStation', function(zone)
    if not targetZones[zone] then return false end
    targetZones[zone] = nil
    if GetResourceState('ox_target') == 'started' then
        pcall(function() exports.ox_target:removeZone(zone) end)
    end
    return true
end)

-- Refresh local target zones from the server's owned, compatible recipes.
local automaticZones = {}
local refreshingCookingTargets = false
local cookingRefreshQueued = false
local cookingRefreshEpoch = 0
local automaticTargetSignature = nil
local function clearAutomaticZones()
    for _, zone in ipairs(automaticZones) do
        exports[GetCurrentResourceName()]:RemoveCookingStation(zone)
    end
    automaticZones = {}
    automaticTargetSignature = nil
end
refreshCookingTargets = function()
    if refreshingCookingTargets then cookingRefreshQueued = true; return end
    if pendingCount >= 10 or GetResourceState('ox_target') ~= 'started' then return end
    refreshingCookingTargets = true
    local epoch = cookingRefreshEpoch
    ask('listCookingTargets', {}, function(result)
        refreshingCookingTargets = false
        if epoch ~= cookingRefreshEpoch then
            if cookingRefreshQueued then
                cookingRefreshQueued = false
                SetTimeout(250, refreshCookingTargets)
            end
            return
        end
        if cookingRefreshQueued then
            cookingRefreshQueued = false
            SetTimeout(250, refreshCookingTargets)
        end
        if not result or not result.ok or type(result.targets) ~= 'table' then return end
        local signatureParts = {}
        for _, target in ipairs(result.targets) do
            signatureParts[#signatureParts + 1] = table.concat({
                tostring(target.businessId), tostring(target.stationId),
                tostring(target.recipeId), tostring(target.recipeName),
                tostring(target.x), tostring(target.y), tostring(target.z),
            }, ':')
        end
        table.sort(signatureParts)
        local signature = table.concat(signatureParts, '|')
        if signature == automaticTargetSignature then return end
        clearAutomaticZones()
        -- One ox_target zone per station, with one option per compatible recipe.
        -- This avoids overlapping spheres for kitchens with several dishes.
        local stations = {}
        local order = {}
        for _, target in ipairs(result.targets) do
            if type(target.x) == 'number' and type(target.y) == 'number'
                and type(target.z) == 'number'
                and target.x == target.x and target.y == target.y and target.z == target.z
                and math.abs(target.x) < 100000 and math.abs(target.y) < 100000
                and math.abs(target.z) < 100000
                and type(target.businessId) == 'string'
                and type(target.stationId) == 'string'
                and type(target.recipeId) == 'string' then
                local key = target.businessId .. ':' .. target.stationId
                local station = stations[key]
                if not station then
                    station = { coords = vector3(target.x, target.y, target.z), options = {} }
                    stations[key] = station
                    order[#order + 1] = key
                end
                local businessId, stationId, recipeId =
                    target.businessId, target.stationId, target.recipeId
                station.options[#station.options + 1] = {
                    name = 'tsfb_cook_' .. stationId .. '_' .. recipeId,
                    icon = 'fa-solid fa-utensils',
                    label = 'Prepare ' .. tostring(target.recipeName or 'food'),
                    distance = 2.0,
                    onSelect = function()
                        exports[GetCurrentResourceName()]:CookRecipe(businessId, recipeId, stationId, 1)
                    end,
                }
            end
        end
        local registered = 0
        for _, key in ipairs(order) do
            local station = stations[key]
            local ok, zone = pcall(function()
                return exports.ox_target:addSphereZone({
                    coords = station.coords, radius = 1.5,
                    debug = false, options = station.options,
                })
            end)
            if ok and zone then
                targetZones[zone] = true
                automaticZones[#automaticZones + 1] = zone
                registered = registered + 1
            end
        end
        if registered == #order then automaticTargetSignature = signature end
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

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if GetResourceState('ox_target') == 'started' then
        for zone in pairs(targetZones) do
            pcall(function() exports.ox_target:removeZone(zone) end)
        end
    end
end)

-- A target restart invalidates its old zone IDs; discard local handles and
-- rebuild only once the provider is running again.
AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= 'ox_target' then return end
    cookingRefreshEpoch = cookingRefreshEpoch + 1
    cookingRefreshQueued = refreshingCookingTargets
    automaticZones = {}
    automaticTargetSignature = nil
    targetZones = {}
end)
