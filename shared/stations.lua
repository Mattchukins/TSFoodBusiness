FoodBusiness = FoodBusiness or {}
FoodBusiness.StationTypes = { grill = true, fryer = true, oven = true, stove = true,
    microwave = true, mixing = true, cutting = true, drinks = true, finishing = true, ice = true }

function FoodBusiness.validStationPosition(x, y, z, heading, bucket)
    local function finite(value, minimum, maximum)
        return type(value) == 'number' and value == value and value >= minimum and value <= maximum
    end
    return finite(x, -100000, 100000) and finite(y, -100000, 100000) and finite(z, -100000, 100000)
        and finite(heading, 0, 360) and finite(bucket, 0, 2147483647) and bucket == math.floor(bucket)
end

-- Three-dimensional distance; invalid positions and other instances fail closed.
function FoodBusiness.isNearStation(station, x, y, z, bucket, radius)
    if type(station) ~= 'table' or type(radius) ~= 'number' or radius ~= radius
        or radius <= 0 or radius > 10 then return false end
    if not FoodBusiness.validStationPosition(x, y, z, 0, bucket)
        or not FoodBusiness.validStationPosition(station.x, station.y, station.z, station.heading, station.routing_bucket)
        or station.routing_bucket ~= bucket then return false end
    local dx, dy, dz = x - station.x, y - station.y, z - station.z
    return dx * dx + dy * dy + dz * dz <= radius * radius
end

function FoodBusiness.listStationTypes()
    local types = {}
    for kind, enabled in pairs(FoodBusiness.StationTypes) do
        if enabled then types[#types + 1] = kind end
    end
    table.sort(types)
    return types
end
