# Architecture and trust boundaries (v0.4.0-dev)

## Current implementation

`fxmanifest.lua` loads oxmysql, ox_lib, shared configuration, framework selection, a server schema gate and a Lua client NUI bridge. The development `/foodbusiness_ui` command opens the React shell. The `close` and `request` callbacks check payloads; the allowlist covers business, recipe and supplier catalog actions plus a read-only recipe price quote. The latter derives character identity on the server, checks ACE permission and writes a business and audit row in one local transaction. `sql/001_initial.sql` and `sql/002_catalogs.sql` are imported manually. Startup refuses business requests if the schema check fails. These source paths have not been live verified.

## Service ownership

| Layer | Responsibility | Trust |
| --- | --- | --- |
| React NUI | Render state, collect inputs, send named callbacks | Untrusted |
| Lua client | Focus, request correlation and timeout | Untrusted for identity or money |
| Lua server | Resolve identity, authorize and validate operations, audit | Authority |
| Framework bridge | One primary ESX/QBCore/QBox adapter selected at startup | Server-side |
| Database | Versioned schema, parameterized queries and transactional mutations plus audit | Server-side |
| Future provider bridges | Independent inventory, target, banking and billing capabilities | Explicitly configured |

Current request flow: NUI form → validated client callback → server action with correlation ID → server-derived identity and permission → SQL transaction plus audit → response to NUI. External settlement and inventory are not implemented. A local SQL transaction cannot atomically commit an external provider call.

## Dependency and failure behavior

`web/dist` must be built for installation. `oxmysql` and `ox_lib` are declared hard dependencies. Framework detection rejects zero or multiple primary frameworks; QBox's qb-core compatibility does not count separately. Missing/incorrect schema disables database actions. Optional providers do not exist yet.

## Threat model and decisions

Untrusted NUI/client input, forged business IDs, replayed payment requests, duplicate fulfilment, stale roles, malformed prices and settlement failures are risks. All sensitive decisions belong on the server, with player identity derived from `source`, correlations and constrained transitions. Business creation is ACE-gated. Recipe and supplier creation require verified business ownership and are audited in local SQL transactions. It has not passed adversarial testing. Future payment mutations need durable idempotency and reconciliation before being enabled.

**ADR 0001:** Select one primary framework; test each independently.

**ADR 0002:** Banking and billing remain independently selected. Native money and internal ledger will support standalone operation.

**ADR 0003:** Use React/TypeScript and Lua NUI callbacks, following observed sibling design conventions recorded in [NUI_DESIGN.md](NUI_DESIGN.md).
