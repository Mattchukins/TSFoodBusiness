FoodBusiness = {}
dofile('shared/presets.lua')
dofile('shared/operations.lua')

local presets = FoodBusiness.listBusinessPresets()
assert(#presets == 8)
local previous = ''
for _, preset in ipairs(presets) do
    assert(preset.label >= previous)
    previous = preset.label
    assert(preset.opensMinute >= 0 and preset.opensMinute <= 1439)
    assert(preset.closesMinute >= 0 and preset.closesMinute <= 1439)
    assert(preset.seatCapacity >= 0 and preset.seatCapacity <= 200)
    assert(preset.queueCapacity >= 0 and preset.queueCapacity <= 100)
    assert(FoodBusiness.isWithinHours(preset.opensMinute, preset.closesMinute, preset.opensMinute))
end
assert(FoodBusiness.getBusinessPreset('drive_through').seatCapacity == 0)
assert(FoodBusiness.getBusinessPreset('unknown') == nil)
local copy = FoodBusiness.getBusinessPreset('restaurant')
copy.seatCapacity = 999
assert(FoodBusiness.getBusinessPreset('restaurant').seatCapacity == 40)
print('preset contract passed')
