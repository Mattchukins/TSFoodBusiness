dofile('shared/config.lua')
dofile('shared/stations.lua')
dofile('shared/recipes.lua')
dofile('shared/jobs.lua')
dofile('shared/staff.lua')
dofile('server/staff.lua')
local business = '12345678-1234-1234-1234-123456789abc'
local players = { [42] = { id = 'owner-42' }, [55] = { id = 'staff-55' } }
local owned, fail, stale, changeTarget, ownerChange, throws = true, false, false, false, false, false
Framework = { player = function(src) return players[src] end }
json = { encode = function() return '{}' end }
local swapLookup, swapOwner = false, false
local rows, audit, statements, counter = {}, {}, nil, 0
local function clone(value)
    if type(value) ~= 'table' then return value end
    local out = {}; for key, entry in pairs(value) do out[key] = clone(entry) end; return out
end
MySQL = {
    single = { await = function(query, values)
        if query:find('owner_id', 1, true) then
            local row = owned and values[1] == business and values[2] == 'owner-42' and { id = business } or nil
            if swapOwner then players[42] = { id = 'replacement-owner' } end
            return row
        end
        if query:find('member_id = ?', 1, true) then
            for _, row in pairs(rows) do if row.business_id == values[1] and row.member_id == values[2] then
                if swapLookup then players[55] = { id = 'replacement-55' } end
                return clone(row)
            end end
        else
            local row = rows[values[1]]
            if row and row.business_id == values[2] then return clone(row) end
        end
    end },
    scalar = { await = function()
        counter = counter + 1
        if changeTarget then players[55] = { id = 'replacement-55' } end
        return string.format('%08x-1234-1234-1234-123456789abc', counter)
    end },
    query = { await = function(_, values)
        local out = {}; for _, row in pairs(rows) do if row.business_id == values[1] then out[#out + 1] = clone(row) end end; return out
    end },
    transaction = { await = function(value)
        statements = value
        if throws then error('database unavailable') end
        if fail then return false end
        if ownerChange then owned = false end
        local mutation, event = value[1], value[2]
        local v = mutation.values
        if mutation.query:find('INSERT INTO tsfb_staff', 1, true) then
            for _, row in pairs(rows) do if row.business_id == v[5] and row.member_id == v[2] then return false end end
            if owned then rows[v[1]] = { id = v[1], member_id = v[2], display_name = v[3], role = v[4], business_id = v[5], revision = 0 } end
            local row = rows[v[1]]
            if row then assert(not audit[event.values[3]]); audit[event.values[3]] = true end
        else
            local editing = mutation.query:find('display_name = ?', 1, true) ~= nil
            local id, revision = editing and v[3] or v[1], editing and v[5] or v[3]
            local row = rows[id]
            if row and row.revision == revision and owned and not stale then
                row.revision = row.revision + 1
                if editing then row.display_name = v[1]; row.role = v[2] end
            end
            if row and row.revision == event.values[7] then
                assert(not audit[event.values[3]]); audit[event.values[3]] = true
            end
            local deletion = value[#value]
            if deletion.query:find('DELETE FROM tsfb_staff', 1, true) and row and row.revision == deletion.values[3] then rows[id] = nil end
        end
        return true
    end },
}
local function send(action, data, src) return Staff.handle(src or 42, (players[src or 42] or {}).id, action, data) end
local function assign(role) return send('assignStaffMember', { businessId = business, targetSource = 55, displayName = 'Kitchen staff', role = role or 'cook' }) end
assert(Staff.role(42, business) == 'owner')
assert(Staff.permission(42, business, 'cook') == true)
assert(Staff.permission(42, business, 'unknown_permission') == false)
assert(Staff.role(55, business) == nil)
swapOwner = true; assert(Staff.role(42, business) == nil)
swapOwner = false; players[42] = { id = 'owner-42' }
local roles = send('listStaffRoles', {}).staffRoles
assert(#roles == 3 and roles[1].id == 'cashier')
roles[1].permissions[1] = 'modified'; assert(FoodBusiness.staffRoleAllows('cashier', 'take_orders'))
assert(not FoodBusiness.staffRoleAllows('cook', 'manage_catalog'))
assert(assign('owner').error == 'invalid_payload')
for _, sourceId in ipairs({ 0, -1, '55', 55.5, math.huge }) do
    assert(send('assignStaffMember', { businessId = business, targetSource = sourceId, displayName = 'Staff', role = 'cook' }).error == 'invalid_payload')
end
assert(send('assignStaffMember', { businessId = business, targetSource = 42, displayName = 'Owner', role = 'manager' }).error == 'owner_is_not_staff')
assert(send('assignStaffMember', { businessId = business, targetSource = 55, displayName = 'Staff', role = 'cook', member_id = 'spoofed' }).error == 'invalid_payload')
assert(send('assignStaffMember', { businessId = business, targetSource = 77, displayName = 'Staff', role = 'cook' }).error == 'target_unavailable')
assert(send('listStaff', { businessId = business }, 55).error == 'forbidden')
assert(Staff.handle(55, 'owner-42', 'listStaff', { businessId = business }).error == 'forbidden')
changeTarget = true; assert(assign().error == 'target_changed' and next(rows) == nil)
changeTarget = false; players[55] = { id = 'staff-55' }
fail = true; assert(assign().error == 'transaction_failed' and next(rows) == nil)
fail = false; throws = true; assert(assign().error == 'transaction_failed')
throws = false
local added = assign(); assert(added.ok)
local id = added.staffId
assert(rows[id].member_id == 'staff-55' and audit['staff:' .. id .. ':0'])
assert(assign().error == 'already_staff')
assert(Staff.role(55, business) == 'cook' and Staff.permission(55, business, 'cook'))
assert(Staff.permission(55, business, 'take_orders') == false)
local update = { businessId = business, staffId = id, revision = 0, displayName = 'Manager label', role = 'manager' }
assert(send('updateStaffMember', update).ok and rows[id].role == 'manager' and rows[id].revision == 1)
assert(audit['staff:' .. id .. ':1'])
assert(send('updateStaffMember', update).error == 'staff_conflict')
assert(Staff.permission(55, business, 'manage_catalog'))
swapLookup = true; assert(Staff.role(55, business) == nil)
swapLookup = false; players[55] = { id = 'staff-55' }
update.revision = 1; stale = true
assert(send('updateStaffMember', update).error == 'staff_conflict' and rows[id].revision == 1)
stale = false
ownerChange = true
assert(send('updateStaffMember', update).error == 'staff_conflict' and rows[id].revision == 1)
ownerChange = false; owned = true
assert(send('removeStaffMember', { businessId = business, staffId = id, revision = 0 }).error == 'staff_conflict')
players[55] = nil -- An owner can remove offline staff by roster entry, never by source ID.
assert(send('removeStaffMember', { businessId = business, staffId = id, revision = 1 }).ok and rows[id] == nil)
assert(audit['staff:' .. id .. ':2'] and #statements == 4)
players[55] = { id = 'staff-55' }
assert(Staff.permission(55, business, 'cook') == nil)
local rehire = assign(); assert(rehire.ok)
local dutyRow, shifts = nil, {}
local oldTime = os.time
local clock = 1000
os.time = function() return clock end
local singleOriginal, transactionOriginal = MySQL.single.await, MySQL.transaction.await
MySQL.single.await = function(query, values)
    if query:find('FROM tsfb_staff_shifts', 1, true) then
        for _, shift in pairs(shifts) do if shift.staff_slot == values[1] then return clone(shift) end end
        return nil
    end
    if query:find('FROM tsfb_staff_duty', 1, true) then assert(values[1] == rehire.staffId); return clone(dutyRow) end
    return singleOriginal(query, values)
end
MySQL.transaction.await = function(value)
    if not value[1].query:find('tsfb_staff_duty', 1, true) then
        local result = transactionOriginal(value)
        local last = value[#value]
        if result and last.query:find('DELETE FROM tsfb_staff', 1, true) and rows[last.values[1]] == nil then
            local closing = value[#value - 1].values
            for _, shift in pairs(shifts) do if shift.staff_slot == closing[3] then
                shift.ended_at = math.max(shift.started_at, closing[1]); shift.end_reason = closing[2]; shift.staff_slot = nil
            end end
        end
        return result
    end
    if fail then return false end
    local v = value[1].values
    if owned or rows[rehire.staffId].member_id == v[#v] then
        if value[1].query:find('INSERT', 1, true) then
            if dutyRow then return false end
            dutyRow = { on_duty = v[1], revision = 1 }
        elseif dutyRow and dutyRow.revision == v[3] then
            dutyRow.on_duty = v[1]; dutyRow.revision = dutyRow.revision + 1
        end
    end
    if dutyRow and dutyRow.revision == value[2].values[6] then
        assert(not audit[value[2].values[3]]); audit[value[2].values[3]] = true
    end
    local shiftChange = value[3]
    local sv = shiftChange.values
    if dutyRow and dutyRow.revision == value[2].values[6] then
        if shiftChange.query:find('INSERT', 1, true) then
            for _, shift in pairs(shifts) do assert(shift.staff_slot ~= rehire.staffId) end
            shifts[sv[1]] = { id = sv[1], staff_slot = sv[4], started_at = sv[2], ended_at = 0, staff_label = rows[rehire.staffId].display_name }
        else
            for _, shift in pairs(shifts) do if shift.staff_slot == sv[3] then
                shift.ended_at = math.max(shift.started_at, sv[1]); shift.end_reason = sv[2]; shift.staff_slot = nil
            end end
        end
    end
    return true
end
local queryOriginal = MySQL.query.await
MySQL.query.await = function(query, values)
    if query:find('FROM tsfb_staff_shifts', 1, true) then
        assert(values[2] == business)
        local out = {}; for _, shift in pairs(shifts) do out[#out + 1] = clone(shift) end; return out
    elseif query:find('WHERE s.member_id', 1, true) then
        local out = {}
        for _, member in pairs(rows) do if member.member_id == values[1] then
            out[#out + 1] = { id = member.business_id, name = 'Test business', role = member.role, on_duty = dutyRow and dutyRow.on_duty or 0, duty_revision = dutyRow and dutyRow.revision or 0 }
        end end
        return out
    end
    return queryOriginal(query, values)
end
local dutyPayload = { businessId = business, staffId = rehire.staffId, revision = 0, onDuty = true }
assert(send('setStaffDuty', dutyPayload, 55).error == 'forbidden' and dutyRow == nil)
dutyPayload.onDuty = 'yes'; assert(send('setStaffDuty', dutyPayload).error == 'invalid_payload')
dutyPayload.onDuty = true; fail = true
assert(send('setStaffDuty', dutyPayload).error == 'transaction_failed' and dutyRow == nil)
fail = false
assert(send('setStaffDuty', dutyPayload).ok and dutyRow.on_duty == 1 and dutyRow.revision == 1)
assert(audit['duty:' .. rehire.staffId .. ':1'])
assert(send('setStaffDuty', dutyPayload).error == 'staff_conflict' and dutyRow.revision == 1)
dutyPayload.revision = 1; dutyPayload.onDuty = false
assert(send('setStaffDuty', dutyPayload).ok and dutyRow.on_duty == 0 and dutyRow.revision == 2)
assert(audit['duty:' .. rehire.staffId .. ':2'])
assert(#send('listMyStaffBusinesses', {}, 55).staffBusinesses == 1)
assert(#send('listMyStaffBusinesses', {}, 42).staffBusinesses == 0)
assert(send('listMyStaffBusinesses', { member_id = 'owner-42' }, 55).error == 'invalid_payload')
assert(send('listStaffShifts', { businessId = business }, 55).error == 'forbidden')
local historyCount = 0; for _, shift in pairs(shifts) do historyCount = historyCount + 1; assert(shift.started_at == 1000 and shift.ended_at == 1000 and shift.staff_slot == nil) end
assert(historyCount == 1)
assert(send('setMyStaffDuty', { businessId = business, revision = 2, onDuty = true, staffId = rehire.staffId }, 55).error == 'invalid_payload')
assert(send('setMyStaffDuty', { businessId = business, revision = 2, onDuty = true }, 42).error == 'forbidden')
owned = false; clock = 1100
assert(send('setMyStaffDuty', { businessId = business, revision = 2, onDuty = true }, 55).ok)
assert(dutyRow.on_duty == 1 and dutyRow.revision == 3)
clock = 1200
assert(send('setMyStaffDuty', { businessId = business, revision = 3, onDuty = false }, 55).ok)
assert(dutyRow.on_duty == 0 and dutyRow.revision == 4)
local second = 0; for _, shift in pairs(shifts) do if shift.started_at == 1100 then second = second + 1; assert(shift.ended_at == 1200) end end
assert(second == 1)
owned = true
assert(#send('listStaffShifts', { businessId = business }).shifts == 2)
clock = 1300
assert(send('setMyStaffDuty', { businessId = business, revision = 4, onDuty = true }, 55).ok)
clock = 1400
assert(send('removeStaffMember', { businessId = business, staffId = rehire.staffId, revision = 0 }).ok)
local removedShift = 0
for _, shift in pairs(shifts) do if shift.started_at == 1300 then
    removedShift = removedShift + 1; assert(shift.ended_at == 1400 and shift.end_reason == 'staff_removed' and shift.staff_slot == nil and shift.staff_label == 'Kitchen staff')
end end
assert(removedShift == 1 and #send('listStaffShifts', { businessId = business }).shifts == 3)
assert(#send('listMyStaffBusinesses', {}, 55).staffBusinesses == 0)
os.time = oldTime
FoodBusiness.Modules.staff = false
assert(send('listStaff', { businessId = business }).error == 'staff_disabled')
assert(Staff.role(42, business) == nil)
print('staff roster: roles, server identity, owner scope, source changes, revisions, audit and offline removal passed (mocked)')
