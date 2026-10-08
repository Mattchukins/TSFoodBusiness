-- TSFoodBusiness destructive uninstall. Stop the resource and back up first.
-- Permanently deletes all TSFoodBusiness records, including audit history.
-- Child tables precede parent tables; foreign-key checking stays enabled.
DROP TABLE IF EXISTS tsfb_production_profiles;
DROP TABLE IF EXISTS tsfb_stations;
DROP TABLE IF EXISTS tsfb_operations;
DROP TABLE IF EXISTS tsfb_suppliers;
DROP TABLE IF EXISTS tsfb_recipes;
DROP TABLE IF EXISTS tsfb_audit;
DROP TABLE IF EXISTS tsfb_businesses;
DROP TABLE IF EXISTS tsfb_schema;
