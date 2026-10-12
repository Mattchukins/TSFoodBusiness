# TwilightStore Food Business

Early development, currently **v0.8.0-dev**. [Roadmap](ROADMAP.md) phases v0.1–v0.7 are tracked in [phase progress](docs/PHASE_PROGRESS.md), and v0.8–v1.5 in [later phase progress](docs/LATER_PHASE_PROGRESS.md). This is not a playable or verified restaurant release.

## Local setup

1. Stop the resource, back up the oxmysql database and import `sql/install.sql` with stop-on-error enabled. Use the same file for fresh setup and additive upgrades. Existing data is preserved. The resource refuses database requests unless schema versions 1–9 and required columns are present. The database account must be able to read its own metadata from `information_schema`.
2. Start `oxmysql`, `ox_lib`, and exactly one primary framework: ESX, QBCore or QBox. QBox may expose qb-core compatibility without counting as a second framework. Set `FoodBusiness.Framework` explicitly in `shared/config.lua` if auto detection is inappropriate.
3. Run `cd web && npm install && npm run check && npm run build`. The generated `web/dist` folder must be included with the installed resource.
4. Add `ensure ts-foodbusiness` after dependencies in `server.cfg`. Grant trusted staff `add_ace group.admin tsfoodbusiness.create allow` or your equivalent ACE mapping.
5. Use `/foodbusiness_ui` to open the development interface. Trusted staff can create one of eight configured business types with a default operating profile; an owner can add recipes and supplier catalog entries. Cooking is disabled by default; purchasing, checkout and payments remain disabled.

Do not advertise ESX/QBCore/QBox support until each is tested live. See [compatibility](docs/COMPATIBILITY.md), [architecture](docs/ARCHITECTURE.md) and [release gates](docs/RELEASE_GATES.md).

Startup also requires InnoDB tables and the expected primary/unique audit keys. Reapplying `CREATE TABLE IF NOT EXISTS` scripts does not repair an existing table's engine or indexes. If startup reports an integrity mismatch, keep the resource stopped, back up the database and have the operator inspect and repair that schema before restarting.

## Interface development

The NUI uses React and TypeScript with Tailwind CSS utilities. Add interface styling in React components using Tailwind; shared colors, focus shadows and the compact breakpoint are defined in `web/tailwind.config.js`. PostCSS compiles Tailwind and Autoprefixer during the Vite build. `web/src/style.css` keeps only Tailwind directives and global canvas, typography, focus and reduced-motion rules. Preflight is disabled to preserve existing browser typography and transparent FiveM rendering. Client/server game logic remains Lua.

Server integrations can call `exports['ts-foodbusiness']:IsOwnerNearStation(source, businessId, stationId, radius)` (use the installed resource name). Radius defaults to 2 metres and must be greater than 0 and at most 10. It returns true for an owned station within three-dimensional range in the same routing bucket, false for failed spatial validation, and nil for invalid arguments, missing ownership/station/player or database failure. This is a spatial prerequisite only; callers must separately validate cooking permissions, recipe compatibility and inventory. Recheck immediately before any future inventory mutation. Live OneSync/native behavior remains unverified.

Use `web/src/components/Panel.tsx` for management surfaces and their common form styling instead of copying its Tailwind utility list into each screen.

## Recipe production setup

In Kitchen, choose **Production settings** for an owned recipe. Set a supported equipment type, output item, output quantity (1–100) and preparation seconds (1–3600). Existing recipes start unconfigured; no food item is inferred from the recipe name. Settings are persisted separately and removed by the recipe foreign key when that recipe is deleted. Output item names are validated syntactically; existence in a configured inventory is not verified yet. Cooking is disabled by default. See `docs/NEXT_50_STAGES.md` for the remaining implementation queue.

## Uninstall

Stop the resource and back up the database, then import `sql/uninstall.sql` only when permanently removing all resource data, including audit history. It drops dependent tables first and leaves foreign-key checks enabled. Do not uninstall to upgrade; use `sql/install.sql`. These are the only two SQL files shipped.

Server integrations can call `exports['ts-foodbusiness']:GetOwnerProductionPlan(source, businessId, recipeId, stationId, batches)` for 1–100 batches. It returns multiplied ingredients, output item/quantity, total sequential preparation seconds, equipment type and batch count, or nil for invalid/missing/incompatible data or a read failure. It is a planning snapshot: no proximity check, inventory availability, reservation, consumption or output occurs. Recompute and validate proximity and permissions before future cooking mutations.

## Inventory read adapter

Inventory is disabled by default. A server integrator can set `FoodBusiness.Inventory.provider = 'custom'`, the adapter resource name, and two export names in `shared/config.lua`. The adapter must expose server exports `ItemExists(itemName)` returning a strict boolean and `GetItemCount(source, itemName)` returning a nonnegative integer; these are our adapter contracts, not existing provider APIs. The adapter resource must be started. Wire those exports to the chosen inventory using its verified API. No native ox_inventory/QB/ESX inventory adapter is claimed implemented.

`GetInventoryCapabilities` reports whether reads are configured; reservation and atomic production remain false unless the operator explicitly enables a verified custom mutation adapter. Compensation remains false; this workflow requires atomic commit and durable release. `GetOwnerIngredientAvailability(source, businessId, recipeId, stationId, batches)` checks the owner-scoped production plan and reports required/available/missing ingredients plus `reservation = false`. A nil report includes a failure reason. Counts are a snapshot, not a guarantee that a later cook can consume ingredients; capacity and output creation are not checked. Provider errors, stopped resources and invalid return types fail closed.

In Production settings, **Preview requirements** calculates 1–100 batches using the saved recipe/profile. Save changes before previewing. This preview checks configuration only; it does not verify station placement, proximity or inventory availability.

Production editor update: owners can check server-read ingredient stock for saved batch settings, including required, available and missing quantities. This is a snapshot without reservation or cooking authorization. Missing or failing inventory adapters return controlled errors. Owners can remove production settings with an audited transaction. Live FiveM, database and provider verification remains pending.

Server integrations may use `GetOwnerProductionReadiness(source, businessId, recipeId, stationId, batches)` to inspect stock and live station proximity together. It always returns `canStart = false`; it is not cooking authorization. See [the inventory reservation contract](docs/INVENTORY_RESERVATIONS.md) for prerequisites before implementing mutations.

## Cooking job development

Schema 6 adds durable cooking jobs. The Kitchen screen lists saved jobs, lets an owner select a recipe and station, and offers start, finish, cancellation, reservation retries and explicit recovery checks. Server start/finish require a compatible owned station within two metres in the same routing bucket. Each player and station holds at most one active job. A saved job retains its original plan even if the recipe changes. Its timer and every transition are server controlled; the browser countdown is an estimate.

The kitchen module and inventory mutation verification flag are **off by default**. Implement and live-test the four custom adapter exports described in [INVENTORY_RESERVATIONS.md](docs/INVENTORY_RESERVATIONS.md) before setting `FoodBusiness.Modules.kitchen = true` and `FoodBusiness.Inventory.mutationsVerified = true`. These flags are operator attestations, not automatic provider certification. No native ox_inventory/QB/ESX mutation provider is included. See [the 20-step batch](docs/COOKING_BATCH_20.md) for implementation evidence and remaining verification.

After a disconnect or restart, load Kitchen jobs and choose **Check recovery status**. This reads the durable provider receipt and reconciles known results. A lost reservation response restarts the full preparation duration. A lost commit response reconciles to completed without another output transfer. There is no automatic background fulfillment. An uncertain or unavailable provider keeps the job and its slots held; never manually delete a pending job or refund it without reconciling its receipt.

## Staff roster

The **Staff** screen lets a business owner assign an online character by current player server ID, set a roster label and choose Manager, Cook or Cashier. The server resolves the character identity; the browser never supplies it. Owners can edit labels/roles and remove staff while those characters are offline. Membership is unique per business and character, and changes include revision checks and transactional audit events. Import the current `sql/install.sql` with the resource stopped to add schema 7. `FoodBusiness.Modules.staff` controls the roster and role integrations.

`GetBusinessStaffRole(source, businessId)` returns `owner`, a saved role, or nil when no verified role is available. `HasBusinessStaffPermission(source, businessId, permission)` supports `cook`, `take_orders` and `manage_catalog`: owners/managers have all three, cooks have `cook`, and cashiers have `take_orders`. It returns true/false for a resolved role, nil when role lookup fails or membership is missing, and false for unknown permissions. Callers must require `== true` and recheck before mutation. Live source identity is checked after awaited reads.

These exports are integration prerequisites. Existing management and cooking actions remain owner-only; the staff roster does not yet grant staff access to those screens or jobs. Self-service duty and recorded shift history are available below; delegated management/cooking and automatic clock-out remain pending. Live database persistence, concurrency and each framework's character switching require verification.

Owner-managed duty status is now available in the Staff roster. Import the current install.sql to add schema 8. Entries start off duty, and owners can change the saved status even while members are offline. Each change uses a separate duty revision and transactional audit. Duty status persists across disconnects and restarts and grants no extra permissions. Schema 9 adds recorded shift times as described below; payroll remains pending.

## Self-service duty and shift history

Staff can use **My duty** to start/end their own shift at any business where their current character is assigned. The server resolves membership, and the request cannot name another staff entry. Owners can change duty status from the roster and review the latest 100 recorded shifts. Schema 9 records server start/end timestamps, a label/role snapshot and a closing reason. Start/end, the duty revision and the audit event share one transaction. One active shift per roster entry is enforced by a unique key.

Removing a staff member closes their active shift as `staff_removed` and preserves its historical label/role. Editing a roster entry does not rewrite old snapshots. Existing on-duty flags from schema 8 do not receive fabricated start times: their next recorded shift starts when they are marked on duty again. Open-shift durations are snapshots from the latest reload. Restart/disconnect does not automatically close a shift. This is recorded duty time, not verified attendance, payroll or a cooking permission grant. Server clock changes can affect duration; negative end intervals are clamped to zero. Live SQL, clock stability and framework switching remain unverified.
