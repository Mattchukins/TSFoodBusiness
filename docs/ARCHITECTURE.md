# Architecture and trust boundaries (v0.0.0)

## Current implementation

`fxmanifest.lua` loads shared configuration, a server lifecycle logger, a client NUI lifecycle bridge and a React/TypeScript shell. The temporary `/foodbusiness_ui` command opens it; the `close` NUI callback checks for an empty object and releases focus. No server network events, persistence, inventory or finance operations exist yet. Build `web/dist` before starting the resource.

## Planned service ownership

| Layer | Responsibility | Trust |
| --- | --- | --- |
| React NUI | Render state, collect inputs, send named callbacks | Untrusted |
| Lua client | Focus, local presentation and callback forwarding | Untrusted for identity or money |
| Lua server | Resolve source/character, authorize operations, calculate prices, consume stock, audit | Authority |
| Framework bridge | One primary ESX/QBCore/QBox implementation selected at startup | Server-side |
| Database service | Versioned migrations, parameterized queries and transactional mutations plus audit | Server-side |
| Provider bridges | Independent inventory, target, banking and billing capabilities | Explicitly configured |

Planned flow: NUI action → validated client callback → server event with request correlation ID → resolve identity and permissions on server → transaction for local state and audit → explicit result to client → update NUI. External settlement requires durable state transitions, idempotency and reconciliation; a local SQL transaction cannot atomically commit an external provider call.

## Dependency graph and startup

`web/dist` is a build artifact. Bootstrap has no ox dependency. At v0.1, oxmysql and ox_lib must be declared and checked before starting database-backed modules; framework selection must reject zero or ambiguous primary frameworks while treating QBox qb-core compatibility as part of QBox. Optional providers must fail only their dependent module. A failed migration blocks database-backed modules.

## Threat model

Untrusted NUI messages, client events, forged business IDs, replayed payment requests, duplicate fulfilment, stale role permissions, malformed prices and external settlement failures are the main risks. All sensitive decisions belong on the server; reject unknown callbacks and payload fields, derive player identity from `source`, use correlation IDs and constrained state transitions, and record audit within the same local transaction as its mutation. These are design requirements, not implemented controls.

## ADR 0001: Single primary framework

Choose exactly one primary framework at startup. QBox compatibility exports do not imply an additional QBCore instance. Separate live smoke tests are required before advertising support.

## ADR 0002: Separate financial adapters

Native player money and an internal persisted business ledger support standalone operation. Banking and billing integrations select independently; provider capability gaps remain visible rather than silently simulated.

## ADR 0003: Source-aligned NUI shell

Use React/TypeScript and NUI callbacks through Lua. Follow the inspected sibling design routes documented in [NUI_DESIGN.md](NUI_DESIGN.md). Keep screen navigation separate from server permissions.
