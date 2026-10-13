dofile('shared/config.lua'); dofile('shared/stations.lua'); dofile('shared/recipes.lua'); dofile('shared/jobs.lua'); dofile('shared/staff.lua'); dofile('server/staff.lua')
local business = '12345678-1234-1234-1234-123456789abc'
local staffId = '22345678-1234-1234-1234-123456789abc'
local shiftId = '32345678-1234-1234-1234-123456789abc'
local duty, active, fail, replaced, cleanupCalls = nil, nil, false, false, 0
Framework = { player = function() return { id = 'member-55' } end }
json = { encode = function() return '{}' end }
MySQL = {
 scalar = { await = function() return shiftId end },
 single = { await = function(query, values)
  if query:find('h.id = ?', 1, true) then
   assert(values[1] == staffId and values[2] == 'member-55' and values[3] == shiftId)
   return active == shiftId and duty.on_duty == 1 and { revision = duty.revision, business_id = business } or nil
  end
  if query:find('FROM tsfb_staff_shifts', 1, true) then return active and { id = active } or nil end
  if query:find('FROM tsfb_staff_duty', 1, true) then return duty end
  return { id = staffId }
 end },
 transaction = { await = function(statements)
  if fail then return false end
  local q, v = statements[1].query, statements[1].values
  if q:find('SET on_duty = 0', 1, true) then
   cleanupCalls = cleanupCalls + 1
   if replaced then active = 'newer-shift'; duty.revision = duty.revision + 2; return true end
   assert(v[3] == shiftId and v[4] == staffId)
   duty = { on_duty = 0, revision = duty.revision + 1 }; active = nil
   assert(statements[3].values[2] == 'disconnect' and statements[3].values[3] == shiftId)
  else
   duty = { on_duty = 1, revision = (duty and duty.revision or 0) + 1 }; active = shiftId
  end
  return true
 end },
}
local function start()
 return Staff.handle(55, 'member-55', 'setMyStaffDuty', { businessId = business, revision = duty and duty.revision or 0, onDuty = true })
end
assert(start().ok)
assert(Staff.disconnect(55) and duty.on_duty == 0 and active == nil and cleanupCalls == 1)
assert(Staff.disconnect(55) and cleanupCalls == 1)
assert(start().ok); replaced = true
assert(Staff.disconnect(55) and active == 'newer-shift' and duty.on_duty == 1)
replaced = false; duty = nil; active = nil
assert(start().ok); fail = true
assert(not Staff.disconnect(55) and duty.on_duty == 1 and active == shiftId)
fail = false
assert(Staff.disconnect(999))
print('self-service disconnect cleanup: exact shift binding, duplicate drops, newer-shift protection and failure isolation passed (mocked)')
