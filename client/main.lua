local uiOpen = false

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

-- Development shell only. No gameplay operation is exposed by this command.
RegisterCommand('foodbusiness_ui', function()
    if uiOpen then closeUi() return end
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then SetNuiFocus(false, false) end
end)
