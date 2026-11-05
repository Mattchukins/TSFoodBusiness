dofile('shared/staff.lua')
local business = '12345678-1234-1234-1234-123456789abc'
FoodBusiness.validJobId = function(id) return id == business end
FoodBusiness.Modules = { staff = true }
local actors = { [42] = { id = 'owner-42' }, [55] = { id = 'staff-55' } }
Framework = { player = function(src) return actors[src] end }
local ownerExists, failure, swapOnOwnerRead = true, false, false
MySQL = { single = { await = function(query, values)
    assert(query:find('owner_id = ?', 1, true) ~= nil)
    assert(values[1] == business)
    if failure then error('mysql down') end
    if swapOnOwnerRead then actors[values[2] == 'owner-42' and 42 or 55] = { id = 'other-character' } end
    return ownerExists and values[2] == 'owner-42' and { id = business } or nil
end } }
local role = 'cook'
Staff = { permission = function(src, biz, permission)
    assert(biz == business and permission == 'cook')
    return FoodBusiness.staffRoleAllows(role, permission)
end }
dofile('server/cooking_access.lua')
assert(CookingAccess.allowed(42, 'owner-42', business))
assert(not CookingAccess.allowed(42, 'other-character', business))
assert(not CookingAccess.allowed(0, 'owner-42', business))
assert(not CookingAccess.allowed(42, 'owner-42', 'bad-business'))
swapOnOwnerRead = true
assert(not CookingAccess.allowed(42, 'owner-42', business))
actors[42] = { id = 'owner-42' }
swapOnOwnerRead = false
failure = true
assert(not CookingAccess.allowed(42, 'owner-42', business))
failure = false
FoodBusiness.Modules.staff = false
assert(CookingAccess.allowed(42, 'owner-42', business))
assert(not CookingAccess.allowed(55, 'staff-55', business))
FoodBusiness.Modules.staff = true
assert(CookingAccess.allowed(55, 'staff-55', business))
role = 'manager'; assert(CookingAccess.allowed(55, 'staff-55', business))
role = 'cashier'; assert(not CookingAccess.allowed(55, 'staff-55', business))
role = nil; assert(not CookingAccess.allowed(55, 'staff-55', business))
local owner = { ownerId = 'owner-42', staffMemberId = nil, staffRole = nil }
local cook = { ownerId = 'owner-42', staffMemberId = 'staff-55', staffRole = 'cook' }
local manager = { ownerId = 'owner-42', staffMemberId = 'staff-55', staffRole = 'manager' }
local cashier = { ownerId = 'owner-42', staffMemberId = 'staff-55', staffRole = 'cashier' }
assert(CookingAccess.targetAllowed('owner-42', owner))
assert(CookingAccess.targetAllowed('staff-55', cook))
assert(CookingAccess.targetAllowed('staff-55', manager))
assert(not CookingAccess.targetAllowed('staff-55', cashier))
assert(not CookingAccess.targetAllowed('unrelated', cook))
assert(not CookingAccess.targetAllowed('staff-55', {}))
assert(not CookingAccess.targetAllowed(nil, cook))
FoodBusiness.Modules.staff = false
assert(not CookingAccess.targetAllowed('staff-55', cook))
assert(CookingAccess.targetAllowed('owner-42', owner))
print('cooking staff role, identity, and target visibility tests passed')
