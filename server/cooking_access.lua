-- Authoritative cooking access: owner, or an assigned staff role with cook permission.
-- Staff duty flags are recorded separately and are not currently an access gate.
CookingAccess = {}

local function sameCharacter(src, actor)
    if type(src) ~= 'number' or src < 1 or src ~= math.floor(src)
        or type(actor) ~= 'string' or #actor < 2 or #actor > 80 then return false end
    local player = Framework.player(src)
    return player ~= nil and player.id == actor
end

function CookingAccess.allowed(src, actor, businessId)
    if not FoodBusiness or not FoodBusiness.validJobId(businessId)
        or not sameCharacter(src, actor) then return false end
    local ok, permitted = pcall(function()
        local owner = MySQL.single.await(
            'SELECT id FROM tsfb_businesses WHERE id = ? AND owner_id = ?',
            { businessId, actor })
        if not sameCharacter(src, actor) then return false end
        if owner then return true end
        if not FoodBusiness.Modules.staff or not Staff
            or type(Staff.permission) ~= 'function' then return false end
        return Staff.permission(src, businessId, 'cook') == true
            and sameCharacter(src, actor)
    end)
    return ok and permitted == true
end

-- The query may select assigned staff to avoid owner-only target lists. Always
-- filter its rows again with the shared permission contract before returning NUI data.
function CookingAccess.targetAllowed(actor, row)
    if type(actor) ~= 'string' or type(row) ~= 'table' then return false end
    if row.ownerId == actor then return true end
    return FoodBusiness.Modules.staff == true
        and row.staffMemberId == actor
        and FoodBusiness.staffRoleAllows(row.staffRole, 'cook') == true
end
