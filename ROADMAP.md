# TwilightStore Food Business — Master Roadmap

**Resource:** `ts-foodbusiness`  
**Versions:** `0.0.0` through `1.5.0`  
**Branch:** `main` only.  
**Status:** Specification and development targets, not implemented or verified functionality.

## Product scope and source references

An independently developed, modular FiveM restaurant and hospitality platform with feature coverage benchmarked against publicly advertised capabilities of [Envi Restaurants](https://forum.cfx.re/t/envi-restaurants-the-ultimate-fivem-restaurant-simulator-qbox-qb-esx-custom/5386908), [NANO Restaurant System](https://nanoscripts.tebex.io/package/7285930), [MT Restaurants](https://forum.cfx.re/t/mt-restaurants-advanced-restaurants-script-for-fivem-multiple-restaurants-recipes-creation/5228614) and [MT v3](https://www.mt-scripts.com/products/7327565). Those products are references, not runtime dependencies; never reproduce proprietary source, interfaces, art or other assets.

Implement configurable restaurants, cafés, bakeries, bars, takeaway shops, kiosks, food trucks and drive-throughs with per-business feature flags. Maintain a traceable feature matrix identifying source, publicly advertised capability, acceptance test and real implementation status. Feature parity is a *target*, never a claim without verification.

## Mandatory engineering and compatibility contract

1. **ESX, QBCore and QBox** are all first-class, independently tested frameworks at every applicable milestone. Detect exactly one primary framework; QBox's qb-core compatibility layer does not constitute a second primary framework. Do not advertise untested adapters.
2. **Lua** client/server gameplay, authoritative Lua server; **React + TypeScript NUI**. Never add a C# or JS gameplay runtime without approval. Validate every NUI callback and every client/server event; resolve identity, ownership, permissions, prices, ingredient use and money server-side.
3. **NUI design continuity is mandatory:** adopt the established TwilightStore **Family Legacy and Animal Services design routes**, navigation conventions, screen layouts, shared React/TypeScript components, tokens, accessibility and responsive patterns. Build restaurant-specific screens *inside that system* rather than inventing a disconnected UI. Obtain and inspect the actual source/style references before implementation; the roadmap does not assume their code has been inspected. Route NUI messages and callbacks through the Lua client bridge.
4. Prefer maintained **ox** capabilities where appropriate: ox_lib UI/helpers, oxmysql for database, optional ox_target and ox_inventory adapters. ox_target/ox_inventory must not be mandatory if a supported alternate provider is configured. Declare and validate hard dependencies; disable only affected optional modules when dependencies are missing.
5. Database: parameterised SQL, versioned migrations, explicit transactions encompassing related SQL changes **and their audit records**; fail closed on migration failure before starting database-dependent modules.
6. **Banking and billing are independently selectable and can each run standalone.** Support framework-native player money and persistent internal business accounts/ledger as needed on ESX/QBCore/QBox, plus internal invoices without external billing. Optional banking and billing scripts are separate adapters; neither is prerequisite for the other.
7. Financial safety: trusted server-side settlement checks, unique idempotency/correlation identifiers, atomic local inventory/order/ledger mutations, refunds/reversals, reconciliation after external-provider failures, and no double-charge/double-fulfilment. Do not assume transactions across resources are atomic.
8. Modules: business creator, kitchen/recipes, ingredient supply, POS/orders, financials, employees, NPCs, hygiene/hazards/inspections, logistics, food trucks, drive-throughs, analytics, administration and extensibility. Optional Family Legacy and Animal Services interoperability must **not** create mandatory runtime dependencies.
9. Test ESX, QBCore, QBox separately with the configured inventory, target, banking, billing and UI bridges. Maintain contract/security/database/NUI/regression/load tests, changelog, migrations and integration-status documentation. Publish compatibility only after live in-server verification.

## Banking and billing adapters

### Banking (one provider selected; standalone always available)

| Provider | Target | Status |
| --- | --- | --- |
| Framework-native player money + internal persisted business account/ledger | 0.1–0.6 | Required on ESX/QBCore/QBox |
| Renewed-Banking | 0.6 | Planned optional adapter |
| esx_banking | 0.6 | Planned optional adapter |
| qb-banking | 0.6 | Planned optional adapter |
| okokBanking | 0.7 | Planned optional adapter |
| ps-banking | 0.7 | Planned optional adapter |
| omes_banking | 0.7 | Planned optional adapter |
| ak47_banking | 0.7 | Planned optional adapter |
| tgg-banking | 1.0 | Candidate; confirm API and availability |
| fd_banking | 1.0 | Candidate; confirm API and availability |

### Billing (chosen separately; standalone always available)

| Provider | Target | Status |
| --- | --- | --- |
| Native internal invoicing / collection | 0.5 | Required on ESX/QBCore/QBox |
| esx_billing | 0.6 | Planned optional adapter |
| okokBilling | 0.6 | Planned optional adapter |
| RxBilling | 0.7 | Planned optional adapter |
| tgg-billing | 0.7 | Planned optional adapter |
| qs-billing | 0.7 | Planned optional adapter |
| codem-billingv2 | 0.7 | Planned optional adapter |
| randol_billing | 0.7 | Planned optional adapter |
| codem-billing | 0.8 | Planned optional adapter |
| vivum-billing | 1.0 | Candidate; original pasted table merged rows |
| loaf_billing | 1.0 | Candidate; original pasted table merged rows |
| wasabi_billing | 1.0 | Candidate; unmarked in original list |

Targets are **not** verified compatibility claims. Examine documented server exports and callbacks, provider versions, settlement semantics and permissions before implementing each; test against licensed/available versions. If an adapter does not expose refunds, partial payments or account operations, mark those capabilities unavailable rather than inventing behaviour. Direct POS payment never requires an external billing script.

### Other integrations

ox_inventory, qb-inventory and appropriate ESX inventory adapter; ox_target, qb-target and built-in fallback interaction; banking, billing, notifications, phone, dispatch, prop packs and positional audio as separately configurable providers. Respect metadata limitations of non-ox inventories. Configuration must report unsupported provider combinations clearly.

## Roadmap milestones

### v0.0.0 — Bootstrap and architecture
Deliver resource layout (`fxmanifest.lua`, `client/`, `server/`, `shared/`, `bridges/`, `modules/`, `web/`, `sql/`, `tests/`, `docs/`), versioning, ADRs, dependency graph, threat model, style/design-route inventory for Family Legacy and Animal Services, source-attributed feature matrix, release gates and `main`-only repository process.

**Exit:** clean empty resource lifecycle, repeatable NUI build/static checks, no completed feature claims.

### v0.1.0 — Core runtime, frameworks and database
Implement independent ESX/QBCore/QBox bridges; player/character identity, jobs, grades, permissions, money capabilities; startup framework and dependency checks; ox_lib and oxmysql services; migrations and fail-closed startup; audit; safe event/NUI bridge contracts; banking/billing abstractions and initial internal account ledger; shared TwilightStore NUI shell following Family Legacy/Animal Services routes.

**Exit:** separate live framework smoke tests, rejected identity spoofing, migration failure isolation, shared NUI shell renders on each framework.

### v0.2.0 — In-game restaurant builder and governance
Create/edit unlimited persistent restaurants and business types in-game; map blips, polygon zones and visual placement of boss menus, workstations, storage, menu boards, registers, tables/seats, NPCs and garages; ownership, business jobs, employee roles, grade permission editor and configuration presets. Log admin mutations.

**Exit:** an authorised player creates and reopens a business without editing Lua; an unauthorised player cannot create, move or edit it.

### v0.3.0 — Kitchen equipment and interactive cooking
Grills, fryers, ovens, stoves, microwaves, mixing pots, cutting boards, drinks, finishing stations and ice machines; ingredient inventory consumption; multi-stage cooking with time/state, raw→undercooked→cooked→overcooked→burnt, quality calculations, props/native/custom mappings, animation, particle/audio and optional camera. Station-specific configuration and input/output routing.

**Exit:** server validates ingredients, time, station and output; no duplicated stock or impossible cooking progress; on-screen interactions conform to shared NUI patterns.

### v0.4.0 — Recipe editor, nutrition and storage
In-game recipe/ingredient CRUD with limits, configurable images, substitutions/toppings, portions, calories/hunger/thirst/buffs, quality metadata, ingredient hygiene; expiry and storage-dependent spoilage; fridges, warmers, staff stashes, public collection trays, capacity and access controls. Support alternative inventory metadata representations safely.

**Exit:** recipe→prepare→store→degrade→consume is persistent and audited; user cannot fabricate effects/metadata.

### v0.5.0 — Orders, POS and first playable business
Staff POS, priced carts, modifiers, self-order kiosks, full-screen digital menus, receipts, numbered printed tickets, kitchen display/queues, station routing, order status and collection screens. Cash/bank checkout; standalone internal invoicing; cancellation, rejection and payment reconciliation; auditable order history and business ledger.

**Exit:** player orders, pays, cooks and collects correctly on ESX/QBCore/QBox, including restart/reconnect and double-submit tests.

### v0.6.0 — Workforce, accounts and reporting
Hiring/dismissal, roles/grade controls, shifts, managers, wages, tips, staff statistics; owner dashboard, profit/loss, item/station/employee sales and quality statistics; supply/equipment purchasing authority; internal business account completed; initial Renewed-Banking, esx_banking, qb-banking, esx_billing and okokBilling adapters.

**Exit:** financial reports reconcile with order/stock/settlement records; external adapters pass separate contract/live tests; standalone finance still works.

### v0.7.0 — Suppliers, deliveries and integration expansion
Supplier catalogues, ingredient purchasing, purchase orders, receiving, stock transfers/ledger, garages and vehicles, NPC delivery missions, configurable cooldowns and delivery rewards. Banking: okokBanking, ps-banking, omes_banking, ak47_banking. Billing: RxBilling, tgg-billing, qs-billing, codem-billingv2, randol_billing. Adapter capability/health UI.

**Exit:** procure→receive→cook→sell with accurate stock and money, and no exploitable delivery reward loops.

### v0.8.0 — NPC customers, NPC workers and offline shop
NPC customer traffic, preferences, orders, queues, seats/dining, takeaway, satisfaction, staffing needs, configurable NPC employees/tasks/operating hours, offline prepared-stock sales and sales reporting. codem-billing optional adapter. Bounding/cleanup to avoid population or network floods.

**Exit:** NPCs obey opening hours, physical capacity, available stock and configured performance limits; offline shop never sells nonexistent stock.

### v0.9.0 — Hygiene, pests, fires and inspections
Handwashing/dirty hands, preparation hygiene metadata, cooking mess and persistent cleanliness, rats/roach effects, pest probability by cleanliness, fumigation with temporary suppression and contamination risks; cooking/fire hazards, station-configured fire control and expiry. Inspector job, scheduled/routine inspections, station audits, violation history and transparent one-to-five-star ratings.

**Exit:** inspection outcomes are reproducible from server records, hygiene actions cannot be fabricated, hazards persist/expire consistently.

### v1.0.0 — Complete core production release
Close benchmark coverage matrix for all **core** features, with post-1.0 items explicitly recorded. Polish kitchen/menu/business dashboards, admin tools, configuration, localization/accessibility, docs, migration/backup instructions and demo restaurant presets. Validate tgg-banking, fd_banking, vivum-billing, loaf_billing and wasabi_billing only if provider APIs and test environments are available; otherwise keep marked pending, not compatible. Full load, security, restart and ESX/QBCore/QBox × adapter testing.

**Exit:** repeatable install, no critical security/data-loss defects, accurate compatibility chart, documented limitations, release checklist signed off.

### v1.1.0 — Food trucks and drive-through
Mobile business inventory/equipment, service locations, vehicle cooking/ordering restrictions, parking and garages; drive-through menu/ordering/payment/pickup, queue management, optional location-specific private voice adapter.

**Exit:** mobile and fixed businesses share authoritative stock/order/finance services; no duplicate mobile stock or cross-channel voice leak.

### v1.2.0 — Hospitality experience
Positional restaurant music, placeable props/chairs, order notifications, optional phone surfaces, advanced customer menu imagery/collection displays; original extensions for loyalty, promotions, in-game reservations and customer feedback.

**Exit:** all channels share current price, availability and order status; optional phone/audio absence is safe.

### v1.3.0 — Ownership, family businesses and commercial controls
Shared ownership, profit distribution, transfers, franchise options, account and liability history, payroll/payout enhancements; optional Family Legacy adapter for family-owned restaurants, business succession and authorised manager assignments. Do not expose private family/character information without explicit permission.

**Exit:** transfers preserve stock, debt, orders, permissions and audit; Family Legacy not required to boot.

### v1.4.0 — Advanced simulation and operations
Equipment wear, repair/maintenance, supplier contracts and seasonal inventory, configurable NPC scenarios/demand, inspections policies, expanded analytics, diagnostics, integration health, data import/export and admin audit tooling. Optional Animal Services interoperability only when explicitly useful and appropriately permissioned.

**Exit:** optional module toggles do not corrupt persistent businesses; load/resource budgets and migration regression gates pass.

### v1.5.0 — Extensible hospitality platform
Stable documented API/exports for business types, recipes, equipment, stations, ingredients, order channels, NPC scenarios, suppliers, payments and notifications. Hospitality presets for cafés, bakeries, bars, kiosks, takeaways, restaurants, trucks and drive-throughs; versioned extension contracts, upgrade tooling, example modules, operator handbook and full compatibility/capability matrix.

**Exit:** third parties can add a business type primarily using configuration and documented extension interfaces; all claimed supported combinations have repeatable tests and migration paths.

## End-to-end feature coverage checklist

| Area | Minimum planned scope |
| --- | --- |
| Restaurant setup | Unlimited businesses, visual editor, zones/blips, permissions, configurable placements/NPCs/props/seats/garages |
| Cooking | All common appliances incl. ice machine, ingredient-driven recipes, stages/animations/props, quality/burn states |
| Food | Recipe editor, modifiers, calories/needs/buffs, expiry, cold/warm storage, contamination |
| Orders | POS, self-service, carts, payment requests, receipts/tickets, kitchen displays, collection, drive-through |
| Financials | Standalone/external banking and billing independently; ledger, sales, payroll, refunds, audits, analytics |
| Staff and supply | Hiring, grades/shifts, NPC workers, wholesale stock purchasing, suppliers, deliveries, vehicles |
| Customer simulation | NPC queues, dining/takeaway, satisfaction, offline shop, NPC delivery missions |
| Hygiene | Handwashing, dirt, pests, fumigation, fires, inspections, ratings and compliance history |
| Experience | Maps/props, menu boards/images, audio, notifications, camera, optional phone and private drive-through voice |
| Platform | ESX/QBCore/QBox, ox-friendly optional adapters, Family Legacy optional link, reusable NUI routes, API |

## Release verification checklist

For **each** release: document requirements, update feature matrix and changelog, run Lua/static/NUI tests, audit all NUI and network payloads, test parameterised SQL and transaction rollbacks, validate migration failure/upgrade/restart, perform ESX/QBCore/QBox in-server smoke tests, test every claimed integration, check idempotency/reconciliation, verify optional modules without optional dependencies, and profile CPU/network/NPC performance. Never mark a test passed without actual evidence.

## Initial repository documentation sequence

1. `ROADMAP.md` — this specification.
2. `docs/FEATURE_COVERAGE.md` — cited Envi/NANO/MT coverage and evidence.
3. `docs/ARCHITECTURE.md` — service ownership, message contracts and trust boundaries.
4. `docs/NUI_DESIGN.md` — **inspect Family Legacy and Animal Services source first**, then map their actual routes/tokens/components into reusable TwilightStore shells and food-business screens.
5. `docs/COMPATIBILITY.md` — tested framework/provider matrix, version requirements and failures.
6. Implement `v0.0.0` skeleton and test/CI harness on `main`.

**Boundary:** this roadmap is planning documentation only; it does not indicate that gameplay code, live server tests or third-party integration checks have already been completed.
