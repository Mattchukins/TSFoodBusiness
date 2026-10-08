# Cooking implementation batch — 20 steps

2026-10-08. This is a 20-step implementation batch within the existing roadmap, not 20 completed roadmap releases. It advances cooking stages 15–27 and the jobs interface in stage 31. Shipped kitchen and inventory mutations remain disabled until live provider verification. Nothing here establishes production readiness.

| Step | Implementation | Local evidence |
| --- | --- | --- |
| 1 | Explicit verified custom mutation capability opt-in | inventory_mutations.lua |
| 2 | Canonical immutable production-plan identity | jobs.lua, inventory_mutations.lua |
| 3 | Custom atomic ingredient reservation bridge | inventory_mutations.lua |
| 4 | Durable receipt inspection and strict job/owner/plan matching | inventory_mutations.lua |
| 5 | Idempotent atomic consume/output commit bridge | inventory_mutations.lua, jobs.lua |
| 6 | Durable release and cancellation bridge | inventory_mutations.lua, jobs.lua |
| 7 | Immutable job-intent SQL storage | sql_contract.py; live execution pending |
| 8 | Schema 6 startup gate and cooking unique-key validation | schema.lua, jobs_requests.lua |
| 9 | Revisioned state changes and transactional audit events | jobs.lua; live rollback pending |
| 10 | Owner-scoped cooking start and job reads | jobs.lua, jobs_requests.lua |
| 11 | Compatible station and server position checks at start | existing production/station tests; live natives pending |
| 12 | Persisted server deadlines and earliest finish guard | jobs.lua |
| 13 | Start token replay protection and changed-payload rejection | jobs.lua |
| 14 | One active job per player/station and per-job locks | jobs.lua; live concurrency pending |
| 15 | Finish ownership, equipment and spatial revalidation | jobs.lua; live natives pending |
| 16 | Cancellation retry and terminal-state replay handling | jobs.lua |
| 17 | Explicit saved-receipt reconciliation after restart | jobs.lua simulated reload; live termination pending |
| 18 | Capacity failure preserves reservation for finish/cancel retry | jobs.lua |
| 19 | React/Tailwind active/recent jobs and owner controls | TypeScript and Vite build; interactive QA pending |
| 20 | NUI action validation, lifecycle failure regressions and CI entries | jobs_requests.lua, full local contract suite |

Test names are relative to `tests/`. Lua checks use mocks, including an in-memory database/provider and deterministic plan codec. They verify application decisions and failure paths; they do not prove MySQL transaction semantics or real provider atomicity. The custom bridge trusts an explicitly verified adapter to serialize durable operations and conserve inventory. See [INVENTORY_RESERVATIONS.md](INVENTORY_RESERVATIONS.md) for the exact protocol.

The SQL package contains exactly install.sql and uninstall.sql. Import install.sql with the resource stopped to add schema 6; CREATE IF NOT EXISTS cannot repair a malformed existing schema. uninstall.sql drops cooking jobs before business tables and permanently removes history.

Still pending: live install/upgrade/restart/rollback/concurrency rehearsal, a real inventory-specific adapter, each framework's native tests, keyboard/responsive NUI QA, background administrative recovery, station target integrations, props, animations, multiple recipe stages, quality/burn states, food metadata and expiry. No background cooking worker or automatic offline output is implemented.
