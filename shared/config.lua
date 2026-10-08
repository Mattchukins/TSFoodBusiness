FoodBusiness = FoodBusiness or {}
FoodBusiness.Version = '0.8.0-dev'
FoodBusiness.Framework = 'auto' -- esx, qbcore, qbox or auto
FoodBusiness.RequiredSchema = 7
FoodBusiness.Modules = {
    businesses = true,
    recipes = true,
    suppliers = true,
    kitchen = false,
    orders = false,
    finance = false,
    operations = true,
    stations = true,
    staff = true,
    npcCustomers = false,
    offlineSales = false,
}

-- Custom adapter exports are a TSFoodBusiness contract, not an assumed provider API.
FoodBusiness.Inventory = { provider = 'disabled', resource = '', itemExistsExport = 'ItemExists', countExport = 'GetItemCount' }

-- Explicit operator opt-in only after live adapter/recovery verification.
-- The provider must satisfy docs/INVENTORY_RESERVATIONS.md atomically and durably.
FoodBusiness.Inventory.mutationsVerified = false
FoodBusiness.Inventory.inspectExport = 'InspectProductionReservation'
FoodBusiness.Inventory.reserveExport = 'ReserveProduction'
FoodBusiness.Inventory.commitExport = 'CommitProduction'
FoodBusiness.Inventory.releaseExport = 'ReleaseProduction'
