# Feature coverage and evidence

Status checked against `main` commit `502e526` (2026-10-13). This is a source/documentation review, **not** a live FiveM certification. Competitor descriptions are feature benchmarks, never dependencies or assets to copy.

| Capability | Current implementation evidence | Status | Next acceptance gate |
| --- | --- | --- | --- |
| Framework runtime | Detection and server-derived identity; ESX/QBCore/QBox targeted | Local foundation; live unverified | Separate live framework smoke tests |
| Business creation | Eight presets, owner-scoped business creation, operating profiles | Partial; live unverified | In-game persistence, restart and authorisation tests |
| Visual placement | Station CRUD, position/bucket validation under mocks | Partial; live unverified | Live placement and rollback |
| Recipes and ingredients | Catalog CRUD, ingredient validation, production profiles | Partial; live unverified | Inventory-backed recipe→output |
| Cooking jobs | Durable intents, server timing, replay/recovery, React Kitchen | Implemented locally, **disabled by default** | Provider atomicity and live conservation tests |
| Staff and duty | Roster, role lookup, manual duty, self-service shifts, guarded disconnect close | Partial; local mocked tests | Live identity-switch, reconnect and database tests |
| Supplies | Supplier catalog entries | Partial; purchasing disabled | Purchase/receive/stock reconciliation |
| Orders and POS | Roadmap only | Not implemented | Paid order→KDS→collection |
| Internal finance | Roadmap contracts | Not implemented | Idempotent settlement and ledger |
| Cooking minigames and quality | Roadmap only | Not implemented | Server-authoritative stages and quality |
| Spoilage/storage | Roadmap only | Not implemented | Metadata and storage tests |
| Hygiene, pests, fires, inspections | Roadmap only | Not implemented | Persistent simulation and reproducible ratings |
| NPC customers/offline shop | Operating profile switches remain off | Not implemented | Stock-backed NPC lifecycle |
| Food trucks/drive-through | Preset types only | Gameplay not implemented | Vehicle/lane/service flow |
| Delivery jobs | Roadmap only | Not implemented | Reward/stock/security tests |
| Analytics | Owner-scoped audit/activity view | Partial | Financial and operations reporting |
| Smartphone, music, reservations, loyalty | Roadmap only | Not implemented | Independent integration acceptance |

## Active five-phase delivery queue

1. [Phase 1 — Verify playable kitchen and inventory](https://github.com/Mattchukins/TSFoodBusiness/issues/1)
2. [Phase 2 — POS, checkout and kitchen order lifecycle](https://github.com/Mattchukins/TSFoodBusiness/issues/2)
3. [Phase 3 — Interactive cooking and food quality](https://github.com/Mattchukins/TSFoodBusiness/issues/3)
4. [Phase 4 — Workforce, supplies and financial operations](https://github.com/Mattchukins/TSFoodBusiness/issues/4)
5. [Phase 5 — NPCs, mobile businesses and safety simulation](https://github.com/Mattchukins/TSFoodBusiness/issues/5)

## Release discipline

- No milestone is complete until its acceptance tests and required live framework/provider matrix pass.
- Keep inventory mutation and kitchen modules disabled until provider correctness is demonstrated.
- Validate client/NUI payloads; server owns identity, money, stock, permissions and time.
- Use parameterised SQL and transactions including audit records; fail closed on schema errors.
- Preserve exactly one `sql/install.sql` and one `sql/uninstall.sql`; migrations must be additive.
- Lua gameplay and React/TypeScript NUI; do not add C# or JS gameplay runtimes without approval.
- Update this matrix whenever an issue is implemented, tested, or blocked.
