# Phase progress — 2026-09-28

The requested next seven roadmap phases are v0.1.0 through v0.7.0. Their exit criteria remain authoritative. This is implementation status, not a release announcement.

| Phase | Implemented in this pass | Still required for exit |
| --- | --- | --- |
| v0.1 Core runtime | Framework selection and identity adapters, fail-closed schema gate, Lua client/NUI request bridge, parameterized SQL and atomic business+audit mutation | Independently test all three frameworks, automatic migration tooling, complete ledger and financial bridges, malicious payload and restart tests |
| v0.2 Business builder | ACE-gated creation of a persistent business with server-derived owner, type validation, audit and basic NUI list/create form | In-game spatial editor, placements, zones, roles and business presets; unauthorized and restart tests |
| v0.3 Cooking | Not started | Stations, validated ingredient consumption, stage/timer/quality state and effects |
| v0.4 Recipes/storage | Not started | Recipe editor, food metadata, storage and spoilage |
| v0.5 Orders/POS | Not started | Order lifecycle, inventory reservation, billing, idempotent settlement and reconciliation |
| v0.6 Workforce/accounts | Not started | Staff management, shifts, ledger/reporting and optional banking/billing adapters |
| v0.7 Suppliers | Not started | Purchase orders, receiving, logistics and adapters |

The first database script is `sql/001_initial.sql`. It requires a deliberate operator import and backup; startup refuses business requests when the schema version is absent or wrong. Building `web/dist` locally is required before FiveM startup. No in-server tests were available in this environment, so compatibility claims remain unverified. Never enable financial operations until a durable idempotent settlement and refund design has passed live tests.
