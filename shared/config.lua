FoodBusiness = FoodBusiness or {}
FoodBusiness.Version = '0.4.0-dev'
FoodBusiness.Framework = 'auto' -- esx, qbcore, qbox or auto
FoodBusiness.RequiredSchema = 2
FoodBusiness.Modules = {
    businesses = true,
    recipes = true,
    suppliers = true,
    kitchen = false,
    orders = false,
    finance = false,
}
