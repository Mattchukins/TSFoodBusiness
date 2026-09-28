-- Bootstrap lifecycle only. Framework, database and gameplay services start in v0.1.0.
AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print(('[ts-foodbusiness] v%s bootstrap started; gameplay modules disabled'):format(FoodBusiness.Version))
end)
