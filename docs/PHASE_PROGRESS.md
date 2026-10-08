# Phase progress — 2026-09-28

The requested next seven roadmap phases are v0.1.0 through v0.7.0. Their exit criteria remain authoritative. This is implementation status, not a release announcement.

| Phase | Implemented in this pass | Still required for exit |
| --- | --- | --- |
| v0.1 Core runtime | Framework selection and identity adapters, fail-closed schema gate, Lua client/NUI request bridge with request limits, parameterized SQL and atomic business+audit mutation | Independently test all three frameworks, automatic migration tooling, complete ledger and financial bridges, malicious payload and restart tests |
| v0.2 Business builder | ACE-gated creation of a persistent business with server-derived owner, type validation, eight preset types with default operating profiles, audit and basic NUI list/create/rename forms; owner-only rename and kitchen station placement/removal are audited | Visual placement editor, other placements, zones, roles, editable presets and live unauthorized/restart tests |
| v0.3 Cooking | Persistent station types and positions, with owner-scoped placement/removal, editing, relocation and proximity checks; persistent one-stage production settings | Station interaction/props, validated ingredient consumption, stage/timer/quality state and effects |
| v0.4 Recipes/storage | Owner-scoped recipe creation/list, name/price/ingredient editing and deletion with transactional audit; NUI supports 1–16 unique ingredients with bounded quantities; no cooking or consumption | Food metadata, storage, spoilage and live tests |
| v0.5 Orders/POS | Owner-only server price quote from persisted recipe; no checkout | Order lifecycle, public POS, inventory reservation, billing, idempotent settlement and reconciliation |
| v0.6 Workforce/accounts | Not started | Staff management, shifts, ledger/reporting and optional banking/billing adapters |
| v0.7 Suppliers | Owner-scoped supplier item catalog creation/list/edit/delete with integer-cent unit prices and transactional audit | Purchase orders, receiving, stock ledger, logistics and adapters |

Import the single `sql/install.sql` for fresh setup or additive upgrades; it records all seven version rows after creating the required tables. They require an operator import and backup. Building `web/dist` locally is required before FiveM startup. TypeScript and Vite passed locally; Lua syntax and mocked contracts pass using LuaTeX; these do not replace FiveM tests. No in-server tests were available in this environment, so compatibility claims remain unverified. Never enable financial operations until a durable idempotent settlement and refund design has passed live tests.
