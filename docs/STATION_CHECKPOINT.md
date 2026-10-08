# Kitchen station checkpoint — 2026-10-08

The ten implementation stages in this pass deliver a placement prerequisite for v0.2/v0.3. They do not complete ten roadmap releases.

| Stage | Delivered |
| --- | --- |
| 1 Storage | Manual version 4 station migration with InnoDB and business foreign key |
| 2 Startup | Station table/column and primary key checks added to schema gate |
| 3 Equipment types | Ten accepted station types in shared source configuration |
| 4 Position validation | Finite coordinate, direction and routing bucket bounds |
| 5 Creation | Owner-only placement from server-observed player position with transactional audit |
| 6 Read | Owner-scoped listing capped at 200 records |
| 7 Removal | Owner-scoped station removal with transactional audit |
| 8 NUI | Lua request allowlist and Stations screen for placement/list/removal |
| 9 Checks | Lua syntax, mocked authorization/position/failure checks, TypeScript and production build passed locally |
| 10 Documentation/package | Migration instructions, phase status and built NUI assets updated |

Import `sql/install.sql` with a backup and the resource stopped. Server-side position capture requires working player entity natives/OneSync; live startup and placement tests remain required on ESX, QBCore and QBox. Stand at the desired location before opening `/foodbusiness_ui`, select an owned business, then place a station. Its direction and routing bucket are recorded with its position. A station is configuration only: props, targets, cooking, ingredient consumption and output inventory are not implemented. Placement is not constrained to a business polygon because business zones are not implemented yet. The list currently shows the first 200 stations; pagination and configurable placement limits remain outstanding.

The local contract harness mocks FiveM and MySQL. It checks rejection of an unowned business, client-provided coordinates and invalid server positions, confirms that captured coordinates enter the transaction, and checks a failed removal transaction. It does not prove live persistence, rollback, collision, station proximity or cooking behavior.

Station relocation is also available through **Move here**. Stand at the new location before opening the screen. Moving preserves the station ID, name and equipment type while updating the server-observed coordinates, direction and routing bucket with an audit entry. Mocked relocation checks reject supplied coordinates and non-owner requests; live movement/persistence tests remain outstanding.

Station details can be changed through **Edit**, then **Save details**. This changes only the name and equipment type, preserving position and identity. Changing business or page clears unfinished edits. Mock checks cover ownership, invalid equipment, coordinate injection, scoped writes and transaction failure; live persistence remains unverified.

A server-only `IsOwnerNearStation` export now checks ownership, scoped station lookup, live player position and matching routing bucket with a bounded radius. Mock tests cover the distance boundary, vertical separation, different instances, invalid coordinates, missing records and database errors. This does not implement cooking or establish live proximity behavior.

The React/Tailwind equipment selector now reads `listStationTypes` from the shared server configuration instead of duplicating a type list. Requests reject extra fields; returned lists are sorted copies. A supported selection is required before placing or editing.

The Stations screen distinguishes loading, an empty loaded list and load failures. **Reload stations** retries reads. If a mutation succeeds but its refresh fails, the UI reports the completed change and failed refresh separately, clears stale rows and requires a successful reload before another mutation. Reload clears unfinished station edits. TypeScript and production build checks pass; interactive FiveM failure-path verification remains pending.

Station cards expose **Saved position** with coordinates to two decimal places, direction and routing bucket. This displays persisted configuration rather than live player position. Actions have station-specific accessible labels; detail summaries participate in the NUI keyboard focus trap. Live visual and keyboard checks remain pending.

Station search matches names without case sensitivity and combines with equipment filtering. Counts and no-match feedback describe the loaded list only. When 200 rows are loaded the screen states the cap; server pagination remains outstanding. Filters reset on business/page changes and reload.
