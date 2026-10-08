FoodBusiness = FoodBusiness or {}
-- Explicit integration permissions; staff cannot delegate roster or owner access.
FoodBusiness.StaffRoles = {
    manager = { label = 'Manager', permissions = { cook = true, take_orders = true, manage_catalog = true } },
    cook = { label = 'Cook', permissions = { cook = true } },
    cashier = { label = 'Cashier', permissions = { take_orders = true } },
}
FoodBusiness.StaffPermissions = { cook = true, take_orders = true, manage_catalog = true }
function FoodBusiness.listStaffRoles()
    local rows = {}
    for id, role in pairs(FoodBusiness.StaffRoles) do
        local permissions = {}
        for permission in pairs(role.permissions) do permissions[#permissions + 1] = permission end
        table.sort(permissions)
        rows[#rows + 1] = { id = id, label = role.label, permissions = permissions }
    end
    table.sort(rows, function(a, b) return a.id < b.id end)
    return rows
end
function FoodBusiness.staffRoleAllows(role, permission)
    if type(permission) ~= 'string' or not FoodBusiness.StaffPermissions[permission] then return false end
    return role == 'owner' or (FoodBusiness.StaffRoles[role] ~= nil and FoodBusiness.StaffRoles[role].permissions[permission] == true)
end
