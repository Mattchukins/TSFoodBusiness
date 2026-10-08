FoodBusiness = FoodBusiness or {}

-- Configuration defaults only. Gameplay modules remain subject to their own gates.
FoodBusiness.BusinessPresets = {
    restaurant = { label = 'Restaurant', opensMinute = 660, closesMinute = 1380, seatCapacity = 40, queueCapacity = 12 },
    cafe = { label = 'Café', opensMinute = 480, closesMinute = 1080, seatCapacity = 24, queueCapacity = 8 },
    bakery = { label = 'Bakery', opensMinute = 360, closesMinute = 960, seatCapacity = 8, queueCapacity = 8 },
    bar = { label = 'Bar', opensMinute = 1020, closesMinute = 180, seatCapacity = 32, queueCapacity = 12 },
    takeaway = { label = 'Takeaway', opensMinute = 660, closesMinute = 60, seatCapacity = 0, queueCapacity = 12 },
    kiosk = { label = 'Kiosk', opensMinute = 540, closesMinute = 1020, seatCapacity = 0, queueCapacity = 6 },
    truck = { label = 'Food truck', opensMinute = 660, closesMinute = 1260, seatCapacity = 0, queueCapacity = 8 },
    drive_through = { label = 'Drive-through', opensMinute = 360, closesMinute = 120, seatCapacity = 0, queueCapacity = 20 },
}

function FoodBusiness.getBusinessPreset(kind)
    local preset = type(kind) == 'string' and FoodBusiness.BusinessPresets[kind]
    if not preset then return nil end
    return { label = preset.label, opensMinute = preset.opensMinute, closesMinute = preset.closesMinute,
        seatCapacity = preset.seatCapacity, queueCapacity = preset.queueCapacity }
end

function FoodBusiness.listBusinessPresets()
    local result = {}
    for kind in pairs(FoodBusiness.BusinessPresets) do
        local preset = FoodBusiness.getBusinessPreset(kind)
        preset.id = kind
        result[#result + 1] = preset
    end
    table.sort(result, function(a, b) return a.label < b.label end)
    return result
end
