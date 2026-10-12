# Release gates

## v0.0.0 bootstrap

- [x] Resource manifest, Lua client/server/shared layout and version string committed.
- [x] React/TypeScript source, build script and static check committed.
- [x] Source-inspected sibling UI inventory, architecture, threat model, feature matrix and compatibility record committed.
- [x] `npm install && npm run check && npm run build` passed locally on 2026-09-28.
- [ ] Empty resource startup, open/close and focus release tested in FiveM.
- [ ] Built NUI assets packaged for installation.

## v0.1.0 development checkpoint

- [x] Single framework detection and server-derived identity code added.
- [x] Schema gate refuses absent or wrong schema; manual version 1 and 2 SQL supplied.
- [x] NUI requests limited to explicit actions with server-side checks.
- [x] Request size/depth and per-player rate bounded; pending NUI callbacks capped at ten.
- [ ] ESX, QBCore and QBox separately smoke tested in FiveM.
- [ ] Migration runner, internal business ledger and complete v0.1 contracts.
- [ ] Security, restart and transaction rollback tested against MySQL.

Recipe and supplier catalog mutations, including recipe name/price editing and deletion, are implemented but not live verified. Schema startup requires version rows 1–5. TypeScript and Vite passed on 2026-09-29; Lua syntax tooling was unavailable for this pass. See [phase progress](PHASE_PROGRESS.md) for v0.2–v0.7. Do not label any phase verified before its roadmap exit criteria pass.

## v0.8–v1.5 development checkpoint

- [x] Operating profile and server read export added behind version 3 schema gate.
- [x] Lua files parsed and opening-hours boundary tests passed locally on 2026-09-29 using LuaTeX's Lua runtime; CI Lua 5.4 job added but not yet observed remotely.
- [x] Built-in preset and mocked business creation contracts passed locally; live transaction rollback and framework tests remain open.
- [x] Ingredient validation and mocked owner-only recipe update checks passed locally on 2026-10-05. Writes require 1–16 distinct item IDs (letters, digits, underscore or hyphen, 2–64 characters), each with an integer quantity of 1–1000. Older catalog entries with other item names must be corrected when edited.
- [x] Mocked recipe transactions returning false or throwing return `transaction_failed`; this does not verify live MySQL rollback.
- [x] Schema column-presence and missing-column startup isolation tests passed under mocks on 2026-10-05. Data types, indexes, foreign keys and storage engines still need live verification.
- [x] Audit viewer ownership rejection and business-scoped query checked under mocks; live NUI/database behavior remains unverified.
- [x] Mocked integrity checks reject MyISAM tables, non-unique audit correlation keys and prefix-only audit keys. Startup now checks engines and primary/unique keys; live metadata and rollback tests remain outstanding.
- [x] Station placement authorization, payload, coordinate and transaction-failure contracts passed locally on 2026-10-08; TypeScript and production build passed. See [station checkpoint](STATION_CHECKPOINT.md).
- [ ] Version 4 migration, live player-position capture, station persistence/removal and framework smoke tests.
- [ ] Version 3 migration applied to a test MySQL database and verified on restart.
- [ ] NPC, offline sales, hygiene, mobile businesses, hospitality, shared ownership, advanced operations and stable extension API implemented and live tested.

See [later phase progress](LATER_PHASE_PROGRESS.md) for the status of all eight phases.

Production-profile configuration added on 2026-10-08: Lua syntax, mocked production validation/ownership/read/transaction-failure tests and React TypeScript/Vite checks pass locally. Schema version 5 migration, foreign-key cascade, persistence/restart and rollback require live database verification. Inventory item existence, consumption, cooking completion and multi-framework behavior remain unverified and disabled.

Schema 6 cooking jobs and the custom atomic mutation contract are locally implemented. The kitchen remains disabled by default. Live SQL upgrade, constraint/rollback behaviour, provider conservation/replay/recovery, disconnects, clock stability and each framework must be verified before enabling. React job controls compile but interactive FiveM QA remains pending.

Schema 7 staff roster is locally implemented with owner-only assignment/edit/removal, server-resolved online target identities, stale revision guards and transactional audit. Permission exports revalidate source identities after awaited reads; cooking and management delegation remain pending. Live persistence, concurrent edits, source recycling and framework character switching need verification.

Schema 8 manual staff duty flags compile and pass mocked owner/payload/revision/failure checks. Live SQL installation, duty persistence, audit rollback and membership-delete cascade remain pending. This is not shift or payroll tracking.
