local uiOpen = false
local pending = {}
local sequence = 0

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
        or (data.action ~= 'listBusinesses' and data.action ~= 'createBusiness') then
        cb({ ok = false, error = 'invalid_payload' }); return
    end
    for key in pairs(data) do
        if key ~= 'action' and key ~= 'payload' then cb({ ok = false, error = 'invalid_payload' }); return end
    end
    sequence = sequence + 1
    local id = ('%d-%d'):format(GetGameTimer(), sequence)
    pending[id] = cb
    TriggerServerEvent('tsfb:request', { requestId = id, action = data.action, data = data.payload })
    SetTimeout(10000, function()
        if pending[id] then pending[id]({ ok = false, error = 'timeout' }); pending[id] = nil end
    end)
end)

RegisterNetEvent('tsfb:response', function(message)
    if type(message) ~= 'table' or type(message.requestId) ~= 'string' then return end
    local cb = pending[message.requestId]
    if cb then pending[message.requestId] = nil; cb(message.result) end
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
        SetNuiFocus(false, false)
    end
end)
