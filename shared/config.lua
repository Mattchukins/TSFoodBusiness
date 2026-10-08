FoodBusiness = FoodBusiness or {}
FoodBusiness.Version = '0.8.0-dev'
FoodBusiness.Framework = 'auto' -- esx, qbcore, qbox or auto
FoodBusiness.RequiredSchema = 5
FoodBusiness.Modules = {
    businesses = true,
    recipes = true,
    suppliers = true,
    kitchen = false,
    orders = false,
    finance = false,
    operations = true,
    stations = true,
    npcCustomers = false,
    offlineSales = false,
}

-- Custom adapter exports are a TSFoodBusiness contract, not an assumed provider API.
FoodBusiness.Inventory = { provider = 'disabled', resource = '', itemExistsExport = 'ItemExists', countExport = 'GetItemCount' }
