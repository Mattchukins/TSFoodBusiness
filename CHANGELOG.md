# Changelog

## Unreleased — v0.8.0-dev

- Added owner-scoped saved-recipe batch preview in React/Tailwind with server-calculated ingredient/output quantities and sequential preparation time; it does not reserve stock.

- Added a disabled-by-default custom server inventory read contract, strict item/count validation, missing-ingredient reports and owner-scoped availability exports. Reservation and production mutations are disabled by default.

- Consolidated SQL delivery into exactly install.sql and uninstall.sql, with additive installation, child-first uninstall and package contract checks.
- Added GetOwnerProductionPlan server read with scoped ownership/recipe/station lookup and bounded batch planning; no inventory mutation.

- Added pure bounded batch production planning with exact equipment compatibility, multiplied ingredient/output quantities and sequential preparation duration. This does not consume or fulfil inventory.

- Added owner-only recipe production settings (equipment, output item/quantity and duration) with strict validation, transactional audit, a React/Tailwind editor and manual schema version 5 migration. Existing recipes remain unconfigured and cooking remains disabled.

- Added station name search, equipment filtering, result counts and clear-filter controls in React/Tailwind. The screen explicitly reports the 200-row loaded-list limit.

- Added reusable React/Tailwind station cards with expandable saved coordinates, direction and routing bucket, accessible action labels and keyboard focus for detail summaries.

- Extracted the six repeated management panel surfaces into a shared React/Tailwind Panel component; generated CSS remains identical.

- Added station loading/empty states and reload control. Successful station mutations now remain clearly reported when the subsequent list refresh fails, with further mutations blocked until the list reloads.

- Stations equipment selector now loads the sorted accepted types from the server; placement/edit submission stays disabled until a supported type is selected.

- Added owner-only server station proximity export with bounded 3D distance and routing-bucket checks; cooking remains disabled.

- Migrated the React NUI layout, navigation, forms and responsive styling to Tailwind utilities; added Tailwind/PostCSS build configuration and regenerated packaged assets.

- Added owner-only station name/equipment editing with strict payload validation and transactional audit.

- Added owner-only station relocation to the server-observed player position, preserving the station ID and auditing the move.
- Added owner-scoped station placement/list/removal with ten equipment types, server-observed coordinates and transactional audits; requires manual schema version 4 migration. Equipment props and cooking remain unimplemented.
- Startup requires InnoDB tables, single-column primary keys and a full unique audit correlation key. Fresh-install SQL now explicitly selects InnoDB.
- Added an owner-only Activity screen showing the latest 100 audited business changes; reads are scoped by business ownership and omit actor/correlation identifiers.
- Startup now checks required table/column presence in the active database after migration version checks and stays disabled if metadata is absent or unreadable.
- Prevented outdated NUI reads from replacing the selected business's catalogs or operating profile; operating profile save waits for that business's load. Keyboard focus now includes form controls.
- Added multi-ingredient recipe creation and editing in the NUI, shared validation for both server paths, and ingredient details in mutation audits. Switching business or page clears unfinished catalog edits.
- Added an owner-scoped operating profile for opening and closing minutes, seats and queue capacity with an atomic audit mutation.
- Added a read-only server export for business operating configuration. This does not enable NPCs, offline sales, stock or payments.
- Added a manual version 3 SQL migration and a fail-closed schema gate.
- Added a tested opening-hours predicate, a server read export for explicit local clock minutes and Lua syntax/contract CI checks.
- Added eight built-in business types with default operating profiles, including drive-through; business creation writes the profile with its audit record, and the NUI loads the type list from the server.

## Unreleased — v0.4.0-dev

- Added single-primary-framework detection and server-side character identity adapters for ESX, QBCore and QBox, awaiting individual in-server verification.
- Added an initial manual SQL migration and fail-closed schema version check.
- Added a request/response NUI bridge and permission-checked business creation with transactional audit.
- Added business creation and owner-only recipe/supplier catalogs with integer-cent prices; a server price quote reads persisted recipe prices. Cooking, purchases and settlement remain disabled.
- Added owner-only recipe name/price editing and deletion with transactional audit, and required both migration version rows at startup.
- Bounded incoming request shape and per-player request rate, capped client pending callbacks, and return a controlled error when a server request fails.
- Added owner-only business renaming through the NUI with a transactional audit record.
- Added owner-only supplier item editing and deletion through the NUI with transactional audit records.

## v0.0.0 bootstrap

- Added resource layout, React/TypeScript NUI preview, static build workflow and planning documents.

- Added owner-scoped production stock checks and React/Tailwind missing-ingredient display.
- Added confirmed production settings removal with transactional audit and controlled failure responses.

- Added read-only owner production readiness with fresh station, ownership, distance and routing-bucket checks after inventory reads. Cooking remains disabled.
- Reject sparse or malformed ingredient plans before invoking inventory providers.
- Documented reservation, replay, atomic output and recovery requirements for future inventory mutations.

### Cooking implementation batch — schema 6

- Added custom reservation inspection/reserve/atomic commit/release contracts with explicit operator verification opt-in, immutable plan identity and strict receipt validation. No native inventory provider is included.
- Added immutable cooking job storage, actor/token replay keys, active player/station slots and schema integrity checks in the existing install/uninstall SQL pair.
- Added owner-only start, server deadlines, fresh finish proximity/instance checks, cancellation, capacity retry and explicit restart receipt reconciliation. State transitions and audit events share transactions.
- Added React/Tailwind active/recent jobs, recipe/equipment selection and start/finish/cancel/recovery controls with disabled defaults and uncertain-result feedback.
- Added mocked lifecycle, mutation adapter and NUI routing tests to CI. Live FiveM, MySQL and provider recovery checks remain pending.
