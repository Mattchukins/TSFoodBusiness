# TwilightStore Food Business

Early development, currently **v0.8.0-dev**. [Roadmap](ROADMAP.md) phases v0.1–v0.7 are tracked in [phase progress](docs/PHASE_PROGRESS.md), and v0.8–v1.5 in [later phase progress](docs/LATER_PHASE_PROGRESS.md). This is not a playable or verified restaurant release.

## Local setup

1. Stop the resource, back up the oxmysql database and import `sql/install.sql` with stop-on-error enabled. Use the same file for fresh setup and additive upgrades. Existing data is preserved. The resource refuses database requests unless schema versions 1–5 and required columns are present. The database account must be able to read its own metadata from `information_schema`.
2. Start `oxmysql`, `ox_lib`, and exactly one primary framework: ESX, QBCore or QBox. QBox may expose qb-core compatibility without counting as a second framework. Set `FoodBusiness.Framework` explicitly in `shared/config.lua` if auto detection is inappropriate.
3. Run `cd web && npm install && npm run check && npm run build`. The generated `web/dist` folder must be included with the installed resource.
4. Add `ensure ts-foodbusiness` after dependencies in `server.cfg`. Grant trusted staff `add_ace group.admin tsfoodbusiness.create allow` or your equivalent ACE mapping.
5. Use `/foodbusiness_ui` to open the development interface. Trusted staff can create one of eight configured business types with a default operating profile; an owner can add recipes and supplier catalog entries. Cooking, purchasing, checkout and payments are disabled.

Do not advertise ESX/QBCore/QBox support until each is tested live. See [compatibility](docs/COMPATIBILITY.md), [architecture](docs/ARCHITECTURE.md) and [release gates](docs/RELEASE_GATES.md).

Startup also requires InnoDB tables and the expected primary/unique audit keys. Reapplying `CREATE TABLE IF NOT EXISTS` scripts does not repair an existing table's engine or indexes. If startup reports an integrity mismatch, keep the resource stopped, back up the database and have the operator inspect and repair that schema before restarting.

## Interface development

The NUI uses React and TypeScript with Tailwind CSS utilities. Add interface styling in React components using Tailwind; shared colors, focus shadows and the compact breakpoint are defined in `web/tailwind.config.js`. PostCSS compiles Tailwind and Autoprefixer during the Vite build. `web/src/style.css` keeps only Tailwind directives and global canvas, typography, focus and reduced-motion rules. Preflight is disabled to preserve existing browser typography and transparent FiveM rendering. Client/server game logic remains Lua.

Server integrations can call `exports['ts-foodbusiness']:IsOwnerNearStation(source, businessId, stationId, radius)` (use the installed resource name). Radius defaults to 2 metres and must be greater than 0 and at most 10. It returns true for an owned station within three-dimensional range in the same routing bucket, false for failed spatial validation, and nil for invalid arguments, missing ownership/station/player or database failure. This is a spatial prerequisite only; callers must separately validate cooking permissions, recipe compatibility and inventory. Recheck immediately before any future inventory mutation. Live OneSync/native behavior remains unverified.

Use `web/src/components/Panel.tsx` for management surfaces and their common form styling instead of copying its Tailwind utility list into each screen.

## Recipe production setup

In Kitchen, choose **Production settings** for an owned recipe. Set a supported equipment type, output item, output quantity (1–100) and preparation seconds (1–3600). Existing recipes start unconfigured; no food item is inferred from the recipe name. Settings are persisted separately and removed by the recipe foreign key when that recipe is deleted. Output item names are validated syntactically; existence in a configured inventory is not verified yet. Cooking remains disabled. See `docs/NEXT_50_STAGES.md` for the remaining implementation queue.

## Uninstall

Stop the resource and back up the database, then import `sql/uninstall.sql` only when permanently removing all resource data, including audit history. It drops dependent tables first and leaves foreign-key checks enabled. Do not uninstall to upgrade; use `sql/install.sql`. These are the only two SQL files shipped.

Server integrations can call `exports['ts-foodbusiness']:GetOwnerProductionPlan(source, businessId, recipeId, stationId, batches)` for 1–100 batches. It returns multiplied ingredients, output item/quantity, total sequential preparation seconds, equipment type and batch count, or nil for invalid/missing/incompatible data or a read failure. It is a planning snapshot: no proximity check, inventory availability, reservation, consumption or output occurs. Recompute and validate proximity and permissions before future cooking mutations.

## Inventory read adapter

Inventory is disabled by default. A server integrator can set `FoodBusiness.Inventory.provider = 'custom'`, the adapter resource name, and two export names in `shared/config.lua`. The adapter must expose server exports `ItemExists(itemName)` returning a strict boolean and `GetItemCount(source, itemName)` returning a nonnegative integer; these are our adapter contracts, not existing provider APIs. The adapter resource must be started. Wire those exports to the chosen inventory using its verified API. No native ox_inventory/QB/ESX inventory adapter is claimed implemented.

`GetInventoryCapabilities` reports whether reads are configured; reservation, atomic production and compensation remain false. `GetOwnerIngredientAvailability(source, businessId, recipeId, stationId, batches)` checks the owner-scoped production plan and reports required/available/missing ingredients plus `reservation = false`. A nil report includes a failure reason. Counts are a snapshot, not a guarantee that a later cook can consume ingredients; capacity and output creation are not checked. Provider errors, stopped resources and invalid return types fail closed.
