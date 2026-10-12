# Later phase progress — 2026-09-29

These eight phases are v0.8.0 through v1.5.0. None meets its roadmap exit criteria. This table records the available foundation and the next implementation boundary; it is not a release claim.

| Phase | Current foundation | Still required for exit |
| --- | --- | --- |
| v0.8 NPC/offline shop | Owner-scoped operating hours and capacity persisted and audited; boundary-tested opening-hours predicate; NPC and offline sale switches remain off | NPC lifecycle, queues, preferences, worker tasks, stock-backed sales, performance and live tests |
| v0.9 Hygiene/inspections | Existing audit infrastructure can record future mutations | Hygiene state, pests, fires, inspection policy and reproducible ratings |
| v1.0 Core release | Bootstrap, catalogs and configuration have a NUI build and a manual migration path | Complete v0.1–v0.9 exits, security/load/restart tests, three framework and provider matrices |
| v1.1 Trucks/drive-through | Truck and drive-through business types have server-defined operating defaults; no vehicle or service logic | Vehicle restrictions, mobile stock, lanes, payment and pickup |
| v1.2 Hospitality | NUI shell and catalog prices exist | Audio, props, menus, channels, loyalty, reservations and feedback |
| v1.3 Ownership | Single owner ID with audited mutations | Shared ownership, transfers, payouts, family integration and liability preservation |
| v1.4 Advanced operations | Persisted operating profile, audit records and owner-only recent activity viewer | Equipment, maintenance, seasonal supply, diagnostics, import/export and load tests |
| v1.5 Extensibility | Eight server-defined business presets and two server-only read exports; see contract below | Stable versioned extensibility API, third-party presets, example modules and upgrade tooling |

## Operating profile and export contract

Import `sql/install.sql` with the resource stopped and a backup. The resource refuses requests until all eight schema version rows and required schema metadata exist. An owner can save a profile from the Operations NUI screen. Hours are minutes after midnight (0–1439); equal opening/closing values are rejected, and an overnight interval is allowed. Seats are 0–200 and queue places 0–100. Defaults in the NUI are 09:00–17:00, zero seats and zero queue places. New businesses receive their selected preset’s profile; existing businesses without a profile use these NUI defaults until saved.

Server integrations may call `exports['ts-foodbusiness']:GetBusinessOperations(businessId)`. It returns a new table `{ opensMinute, closesMinute, seatCapacity, queueCapacity }` or `nil` if the resource is not ready, the ID is invalid, the profile is absent or the database read fails. This is configuration, not proof that a business is open, occupied, staffed or stocked. It does not confer access to any private owner data or permit mutations. The export remains a development contract and is not yet a stable v1.5 API.

`exports['ts-foodbusiness']:IsBusinessWithinHours(businessId, minute)` returns `true` or `false` for an explicitly supplied local clock minute (0–1439), or `nil` for invalid input, missing profile or unavailable database. Opening minute is inclusive and closing minute exclusive. Overnight intervals work across midnight. The caller chooses the time zone and supplies the minute; this predicate alone does not establish that staff, stock or a service channel is available. Lua syntax and boundary cases are checked by `tests/syntax.lua` and `tests/operations.lua`.

New businesses use one of eight built-in types in `shared/presets.lua`: restaurant, café, bakery, bar, takeaway, kiosk, food truck and drive-through. The NUI requests the server list. Business creation writes its default operating profile and audit row in the same local transaction as the business. Existing businesses retain their current profiles; this change is not a data migration for their settings. The type list is source configuration, not a stable third-party registration API. `tests/presets.lua` checks the defaults and `tests/business_creation.lua` exercises spoofed identity rejection and the transaction statements under mocks; neither is a live database test.

No FiveM, MySQL or framework-specific runtime test was available here. NPC and financial modules remain disabled. Do not advertise v0.8–v1.5 as completed.
