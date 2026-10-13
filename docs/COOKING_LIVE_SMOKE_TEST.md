# FiveM cooking smoke test

The automated Lua tests and GitHub Actions checks are not a substitute for a live FiveM server. Keep `FoodBusiness.Modules.kitchen = false` until this checklist has been completed with a disposable test business and inventory.

## Prerequisites

1. Use a non-production FiveM server with the configured ESX, QBCore or QBox bridge, oxmysql, ox_lib, ox_inventory and ox_target running before TSFoodBusiness.
2. Apply the repository's SQL install/migrations and verify TSFoodBusiness starts without schema errors.
3. Add valid ox_inventory item definitions for the test recipe's ingredients and output. Back up inventory data.
4. Configure a test business, station, recipe and compatible production profile using the existing management UI.
5. For this test server only, set `FoodBusiness.Modules.kitchen = true` in `shared/config.lua`, restart the resource, and run `/foodbusiness_refresh_cooking`.

## Player scenarios

| Scenario | Expected outcome |
| --- | --- |
| Owner approaches the station | One ox_target sphere with a distinct option for each compatible recipe |
| Owner selects a recipe with enough ingredients and space | Progress UI appears; on completion ingredients are removed and output is awarded once |
| Owner cancels progress | No ingredient consumption and no output |
| Owner tries to start another recipe during progress | Second start is rejected |
| Owner has insufficient ingredients | Clear failure message; no changes to inventory |
| Owner inventory cannot accept output | Cooking is rejected; no ingredient consumption |
| Owner walks away during progress | Server refuses production at finish; no output |
| Ownership or access is revoked during progress | Server refuses production at finish |
| Player disconnects during progress | In-memory session is discarded; no delayed award |
| Player reconnects and starts again | Fresh cooking request can succeed |
| Resource or ox_target restarts | Station options rebuild without duplicates |
| Station recipe or profile is changed | Target options update after refresh |
| Multiple compatible recipes share one station | Exactly one sphere zone, multiple recipe options |
| Finish/cancel is repeated with an old token | No second award or refund |

## Verify

For each case, capture server console output, player-facing notification, ingredient counts before/after, output counts before/after, and framework/version. Repeat the core happy path, cancel, no-ingredients and full-inventory tests separately on ESX, QBCore and QBox.

**Known limitation:** Conventional ox_inventory RemoveItem/AddItem calls are not an atomic transaction. On uncertain provider outcomes, the script returns `manual_inventory_recovery_required` rather than guessing whether items were transferred. Check inventory and server logs manually; do not retry blindly.

Do not enable cooking on a production server until the above tests pass and inventory failure/recovery behaviour is understood.
