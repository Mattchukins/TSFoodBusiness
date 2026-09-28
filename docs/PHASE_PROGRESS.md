# Phase progress — 2026-09-28

The requested next seven roadmap phases are v0.1.0 through v0.7.0. Their exit criteria remain authoritative. This is implementation status, not a release announcement.

| Phase | Implemented in this pass | Still required for exit |
| --- | --- | --- |
| v0.1 Core runtime | Framework selection and identity adapters, fail-closed schema gate, Lua client/NUI request bridge, parameterized SQL and atomic business+audit mutation | Independently test all three frameworks, automatic migration tooling, complete ledger and financial bridges, malicious payload and restart tests |
| v0.2 Business builder | ACE-gated creation of a persistent business with server-derived owner, type validation, audit and basic NUI list/create form | In-game spatial editor, placements, zones, roles and business presets; unauthorized and restart tests |
| v0.3 Cooking | Not started | Stations, validated ingredient consumption, stage/timer/quality state and effects |
| v0.4 Recipes/storage | Owner-scoped recipe creation/list and ingredient requirements stored with integer-cent prices; no cooking or consumption | Recipe edit/delete, food metadata, storage, spoilage and live tests |
| v0.5 Orders/POS | Owner-only server price quote from persisted recipe; no checkout | Order lifecycle, public POS, inventory reservation, billing, idempotent settlement and reconciliation |
| v0.6 Workforce/accounts | Not started | Staff management, shifts, ledger/reporting and optional banking/billing adapters |
| v0.7 Suppliers | Owner-scoped supplier item catalog creation/list with integer-cent unit prices | Purchase orders, receiving, stock ledger, logistics and adapters |

The database scripts are `sql/001_initial.sql` then `sql/002_catalogs.sql`. They require an operator import and backup; startup refuses requests when schema version 2 is absent or wrong. Building `web/dist` locally is required before FiveM startup. No in-server tests were available in this environment, so compatibility claims remain unverified. Never enable financial operations until a durable idempotent settlement and refund design has passed live tests.
