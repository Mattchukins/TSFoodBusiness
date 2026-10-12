Staff = {}
local function text(value, maximum)
    return type(value) == 'string' and #value >= 2 and #value <= maximum and not value:find('[%c]')
end
local function integer(value, minimum, maximum)
    return type(value) == 'number' and value == value and value >= minimum and value <= maximum and value == math.floor(value)
end
local function exact(data, keys)
    for key in pairs(data) do if not keys[key] then return false end end
    return true
end
local function owns(src, actor, businessId)
    local person = Framework.player(src)
    if not person or person.id ~= actor then return false end
    local row = MySQL.single.await('SELECT id FROM tsfb_businesses WHERE id = ? AND owner_id = ?', { businessId, actor })
    local current = Framework.player(src)
    return row ~= nil and current ~= nil and current.id == actor
end
function Staff.role(src, businessId)
    if not FoodBusiness.Modules.staff or not integer(src, 1, 2147483647) or not FoodBusiness.validJobId(businessId) then return nil end
    local ok, role = pcall(function()
        local person = Framework.player(src)
        if not person or not text(person.id, 80) then return nil end
        if owns(src, person.id, businessId) then return 'owner' end
        local row = MySQL.single.await('SELECT role FROM tsfb_staff WHERE business_id = ? AND member_id = ?', { businessId, person.id })
        local current = Framework.player(src)
        if not current or current.id ~= person.id then return nil end
        if row and FoodBusiness.StaffRoles[row.role] then return row.role end
    end)
    return ok and role or nil
end
function Staff.permission(src, businessId, permission)
    if type(permission) ~= 'string' or not FoodBusiness.StaffPermissions[permission] then return false end
    local role = Staff.role(src, businessId)
    if not role then return nil end
    return FoodBusiness.staffRoleAllows(role, permission)
end
function Staff.handle(src, actor, action, data)
    if not FoodBusiness.Modules.staff then return { ok = false, error = 'staff_disabled' } end
    if action == 'listStaffRoles' then
        if next(data) ~= nil then return { ok = false, error = 'invalid_payload' } end
        return { ok = true, staffRoles = FoodBusiness.listStaffRoles() }
    end
    if not FoodBusiness.validJobId(data.businessId) then return { ok = false, error = 'invalid_payload' } end
    local keys = action == 'listStaff' and { businessId = true }
        or action == 'assignStaffMember' and { businessId = true, targetSource = true, displayName = true, role = true }
        or action == 'updateStaffMember' and { businessId = true, staffId = true, revision = true, displayName = true, role = true }
        or action == 'setStaffDuty' and { businessId = true, staffId = true, revision = true, onDuty = true }
        or action == 'removeStaffMember' and { businessId = true, staffId = true, revision = true }
    if not keys or not exact(data, keys)
        or ((action == 'assignStaffMember' or action == 'updateStaffMember') and
            (not text(data.displayName, 80) or type(data.role) ~= 'string' or not FoodBusiness.StaffRoles[data.role]))
        or (action == 'assignStaffMember' and not integer(data.targetSource, 1, 2147483647))
        or (action == 'setStaffDuty' and (type(data.onDuty) ~= 'boolean' or not FoodBusiness.validJobId(data.staffId) or not integer(data.revision, 0, 2147483646)))
        or ((action == 'updateStaffMember' or action == 'removeStaffMember') and
            (not FoodBusiness.validJobId(data.staffId) or not integer(data.revision, 0, 2147483646))) then
        return { ok = false, error = 'invalid_payload' }
    end
    if not owns(src, actor, data.businessId) then return { ok = false, error = 'forbidden' } end
    if action == 'listStaff' then
        return { ok = true, staff = MySQL.query.await('SELECT s.id, s.display_name, s.role, s.revision, COALESCE(d.on_duty, 0) AS on_duty, COALESCE(d.revision, 0) AS duty_revision FROM tsfb_staff s LEFT JOIN tsfb_staff_duty d ON d.staff_id = s.id WHERE s.business_id = ? ORDER BY s.display_name, s.id LIMIT 200', { data.businessId }) }
    end
    if action == 'setStaffDuty' then
        local member = MySQL.single.await('SELECT id FROM tsfb_staff WHERE id = ? AND business_id = ?', { data.staffId, data.businessId })
        if not member then return { ok = false, error = 'not_found' } end
        local duty = MySQL.single.await('SELECT on_duty, revision FROM tsfb_staff_duty WHERE staff_id = ?', { data.staffId })
        if (duty and tonumber(duty.revision) or 0) ~= data.revision then return { ok = false, error = 'staff_conflict' } end
        local revision = data.revision + 1
        local mutation = duty
            and { query = 'UPDATE tsfb_staff_duty SET on_duty = ?, revision = revision + 1 WHERE staff_id = ? AND revision = ? AND EXISTS (SELECT 1 FROM tsfb_staff s JOIN tsfb_businesses b ON b.id = s.business_id WHERE s.id = ? AND b.id = ? AND b.owner_id = ?)',
                values = { data.onDuty and 1 or 0, data.staffId, data.revision, data.staffId, data.businessId, actor } }
            or { query = 'INSERT INTO tsfb_staff_duty (staff_id, on_duty, revision) SELECT s.id, ?, 1 FROM tsfb_staff s JOIN tsfb_businesses b ON b.id = s.business_id WHERE s.id = ? AND b.id = ? AND b.owner_id = ?',
                values = { data.onDuty and 1 or 0, data.staffId, data.businessId, actor } }
        local ok, done = pcall(function() return MySQL.transaction.await({ mutation,
            { query = 'INSERT INTO tsfb_audit (action, actor_id, business_id, correlation_id, details) SELECT ?, ?, s.business_id, ?, ? FROM tsfb_staff_duty d JOIN tsfb_staff s ON s.id = d.staff_id WHERE d.staff_id = ? AND d.revision = ?',
                values = { 'staff.duty', actor, 'duty:' .. data.staffId .. ':' .. revision, json.encode({ staffId = data.staffId, onDuty = data.onDuty }), data.staffId, revision } },
        }) end)
        if not ok or not done then return { ok = false, error = 'transaction_failed' } end
        local saved = MySQL.single.await('SELECT on_duty, revision FROM tsfb_staff_duty WHERE staff_id = ?', { data.staffId })
        return saved and tonumber(saved.revision) == revision and tonumber(saved.on_duty) == (data.onDuty and 1 or 0)
            and { ok = true } or { ok = false, error = 'staff_conflict' }
    end
    if action == 'assignStaffMember' then
        local target = Framework.player(data.targetSource)
        if not target or not text(target.id, 80) then return { ok = false, error = 'target_unavailable' } end
        if target.id == actor then return { ok = false, error = 'owner_is_not_staff' } end
        local duplicate = MySQL.single.await('SELECT id FROM tsfb_staff WHERE business_id = ? AND member_id = ?', { data.businessId, target.id })
        if duplicate then return { ok = false, error = 'already_staff' } end
        local id = MySQL.scalar.await('SELECT UUID()')
        if not FoodBusiness.validJobId(id) then return { ok = false, error = 'database_error' } end
        if not owns(src, actor, data.businessId) then return { ok = false, error = 'forbidden' } end
        local current = Framework.player(data.targetSource)
        if not current or current.id ~= target.id then return { ok = false, error = 'target_changed' } end
        local ok, done = pcall(function() return MySQL.transaction.await({
            { query = 'INSERT INTO tsfb_staff (id, business_id, member_id, display_name, role, revision) SELECT ?, id, ?, ?, ?, 0 FROM tsfb_businesses WHERE id = ? AND owner_id = ?',
                values = { id, target.id, data.displayName, data.role, data.businessId, actor } },
            { query = 'INSERT INTO tsfb_audit (action, actor_id, business_id, correlation_id, details) SELECT ?, ?, business_id, ?, ? FROM tsfb_staff WHERE id = ? AND revision = 0',
                values = { 'staff.assign', actor, 'staff:' .. id .. ':0', json.encode({ staffId = id, role = data.role, displayName = data.displayName }), id } },
        }) end)
        if not ok or not done then return { ok = false, error = 'transaction_failed' } end
        local row = MySQL.single.await('SELECT id, revision FROM tsfb_staff WHERE id = ? AND business_id = ?', { id, data.businessId })
        return row and { ok = true, staffId = id } or { ok = false, error = 'staff_conflict' }
    end
    local row = MySQL.single.await('SELECT id, revision FROM tsfb_staff WHERE id = ? AND business_id = ?', { data.staffId, data.businessId })
    if not row then return { ok = false, error = 'not_found' } end
    if tonumber(row.revision) ~= data.revision then return { ok = false, error = 'staff_conflict' } end
    local removing = action == 'removeStaffMember'
    local revision = data.revision + 1
    local mutation = removing
        and { query = 'UPDATE tsfb_staff SET revision = revision + 1 WHERE id = ? AND business_id = ? AND revision = ? AND EXISTS (SELECT 1 FROM tsfb_businesses WHERE id = ? AND owner_id = ?)',
            values = { data.staffId, data.businessId, data.revision, data.businessId, actor } }
        or { query = 'UPDATE tsfb_staff SET display_name = ?, role = ?, revision = revision + 1 WHERE id = ? AND business_id = ? AND revision = ? AND EXISTS (SELECT 1 FROM tsfb_businesses WHERE id = ? AND owner_id = ?)',
            values = { data.displayName, data.role, data.staffId, data.businessId, data.revision, data.businessId, actor } }
    local statements = { mutation,
        { query = 'INSERT INTO tsfb_audit (action, actor_id, business_id, correlation_id, details) SELECT ?, ?, business_id, ?, ? FROM tsfb_staff WHERE id = ? AND business_id = ? AND revision = ?',
            values = { removing and 'staff.remove' or 'staff.update', actor, 'staff:' .. data.staffId .. ':' .. revision,
                json.encode({ staffId = data.staffId, revision = revision, displayName = data.displayName, role = data.role }), data.staffId, data.businessId, revision } },
    }
    if removing then statements[#statements + 1] = { query = 'DELETE FROM tsfb_staff WHERE id = ? AND business_id = ? AND revision = ?', values = { data.staffId, data.businessId, revision } } end
    local ok, done = pcall(function() return MySQL.transaction.await(statements) end)
    if not ok or not done then return { ok = false, error = 'transaction_failed' } end
    local updated = MySQL.single.await('SELECT id, revision FROM tsfb_staff WHERE id = ? AND business_id = ?', { data.staffId, data.businessId })
    if removing then return not updated and { ok = true } or { ok = false, error = 'staff_conflict' } end
    return updated and tonumber(updated.revision) == revision and { ok = true } or { ok = false, error = 'staff_conflict' }
end
