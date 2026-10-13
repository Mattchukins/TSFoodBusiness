### Conventional cooking implementation boundary

A standard ox_inventory cooking mode should validate the recipe, business
permission, station proximity, quantities, output capacity, and a per-player
action lock on the server. It should consume ingredients through upstream
ox_inventory exports and award outputs only after successful removal. Failed
removals must never award output. If output delivery fails after removal, the
server must attempt restoration, log the incident and hold the job for operator
review if restoration cannot be confirmed. Such compensation is **not atomic**
and cannot guarantee crash recovery between independent ox_inventory calls.

Do not reuse the durable job engine's `atomicProduction` capability flag for
this weaker mode. Introduce a separate explicitly named conventional mode with
its own state machine and tests before enabling cooking. Keep any SQL escrow
and stock procedures isolated from the default player-inventory path.

## Standard ox_inventory default (simplified architecture)

The default `FoodBusiness.Inventory.provider = 'ox_inventory'` connects **directly**
to upstream `ox_inventory` for item definitions and player item counts. No
`tsfb-ox-inventory` resource, stored procedures, or SQL stock tables are
required for those read-only operations. Business ownership, staff, recipes,
stations and audit records continue to use the normal TSFoodBusiness database.

**Important:** This does not enable cooking. The existing durable cooking-job
engine still requires a verified atomic reservation/commit provider and
`FoodBusiness.Modules.kitchen` remains false. Upstream `RemoveItem` and
`AddItem` are not an atomic pair. Do not turn on kitchen or set
`mutationsVerified = true` simply because the item preview works.

The experimental SQL-owned stock procedures and reconciliation tooling remain
optional, isolated in `integrations/tsfb-ox-inventory/`, for a future
persistent-business-stock mode. They are **not** the default player-inventory
path and do not establish atomicity for player items.

---

# Inventory reservation contract

Status: custom mutation bridge and durable job orchestration implemented, verified only with mocks. The default configuration keeps all mutation calls disabled. No inventory-specific provider implementation or live certification is included. Atomic production requires explicit operator opt-in; compensation remains false because separate remove/add compensation is unsupported.

A stock snapshot must never authorize cooking. A future adapter must implement the following semantics before cooking can be enabled.

| Operation | Required behaviour |
| --- | --- |
| Reserve | Accept a server-generated job ID, stable player identity, validated ingredient plan and output specification. Atomically claim every ingredient or claim none. Return a durable receipt tied to that job and identity. |
| Repeat reserve | The same job and identical plan return the same receipt. A changed identity or plan with the same job ID is rejected. |
| Inspect receipt | Return reserved, committed, released or unknown. State survives provider/resource/server restarts. Unknown is a reconciliation condition, never permission to consume again. |
| Commit | Consume reserved ingredients and deliver the exact output together. Check output capacity within the same provider operation. Failure leaves the reservation intact with no output. |
| Repeat commit | Return the original successful result without consuming or delivering twice. |
| Release | Return all reserved ingredients exactly once. Repeating release is harmless. Reject release after commit and commit after release. |
| Recovery | Query receipts by job ID without relying on the player's transient server source. Offline players retain recoverable claims. |

The provider must protect reservations from unrelated inventory transfers or consumption. A receipt is authoritative only when verified through the server adapter; client-supplied receipts are never accepted. Provider calls must have bounded failure behaviour. Timeout or exception outcomes are uncertain: inspect the durable receipt before retrying a mutation.

Providers offering only separate remove/add exports do not satisfy this contract. A loop that removes ingredients followed by an output add can lose or duplicate items on failure. Such a provider needs its own transactional bridge or durable escrow and compensation ledger with demonstrated recovery. Capability flags must remain false until its implementation is verified.

## Job coordination and compensation

The application and provider do not share a database transaction. Persist a job intent with its immutable plan before reserving. Use that same job ID for every retry. Persist the receipt before starting the server timer. On restart, reconcile pending intents and receipts before allowing another mutation. A failed database write after a provider operation requires reconciliation, not a fresh reservation or refund.

If a provider cannot atomically commit both inputs and output, a future compensation design must record each transfer durably, use idempotent transfer IDs and reconcile uncertain results. Refunds must restore exact item metadata and quantities to the original identity, including offline recovery. Do not implement compensation using untracked best-effort add calls.

## Required verification before enabling

Exercise simultaneous reservations against the last ingredient, insufficient stock, full output capacity, duplicate requests, changed payload replays, provider exceptions, disconnects and process termination before and after each durable write. Confirm conservation of ingredients/output after every recovery and that each job has at most one commit or release. These checks require a live provider and FiveM environment; mocked read tests do not establish mutation safety.

## Current readiness export

`GetOwnerProductionReadiness(source, businessId, recipeId, stationId, batches)` returns a production plan, stock snapshot, `nearStation` and `prerequisitesMet`, or nil plus a controlled error. It rechecks station type, ownership and live server coordinates after inventory reads. Distance is fixed at two metres in the same routing bucket. `canStart` and `reservation` are always false. A caller must never cache this result as cooking authorization. The separate cooking job service implements durable intents, server deadlines and explicit receipt reconciliation. This readiness export remains read-only and never authorizes cooking.

## Custom server export protocol

The adapter must expose four server exports, configurable in `shared/config.lua`:

- `InspectProductionReservation(payload)` reads a durable receipt only.
- `ReserveProduction(payload)` atomically claims the exact ingredient plan, validating ingredient and output item existence. It must return reserved or an explicit absent result without partial claims.
- `CommitProduction(payload)` atomically consumes the claim and delivers the exact output, checking capacity within that operation.
- `ReleaseProduction(payload)` returns a reserved claim, or writes a durable released tombstone for an absent intent so a delayed reserve cannot occur later.

Each receives `{ jobId, ownerId, planKey, plan }`. `ownerId` is the server framework's stable character identity, never the temporary player source. `plan` contains ingredient quantities, output item/quantity, equipment, batches and total seconds. `planKey` is a canonical identity over the immutable plan. Every response is `{ jobId, ownerId, planKey, state, error? }` with all identities matching the request and state exactly `absent`, `reserved`, `committed` or `released`. A receipt mismatch, exception or unrecognized state is an uncertain outcome. Do not return a receipt before its durable transaction commits.

Allowed business failures are `insufficient_stock` with `state = 'absent'` and `output_full` with `state = 'reserved'`. Capacity failure preserves the full claim; the owner may free space and retry completion or cancel. An unavailable output item must never consume ingredients. Unsupported failures are treated as uncertain, leaving the job held for reconciliation.

All operations for the same job must be linearizable: a concurrent release and commit cannot both succeed, and inspection must not falsely report a settled reserved state while a conflicting mutation may still commit. Once committed or released, reserve cannot resurrect the claim. Repeats return the durable terminal receipt. This includes retries after network timeout and server restart. Provider storage must survive its resource stopping and restarting.

Set `mutationsVerified = true` only after proving those properties in the actual provider. The bridge validates receipt identities and shapes; it cannot prove an adapter is atomic or durable. Do not wire these exports directly to independent remove/add inventory calls.

## Operational boundaries

Jobs are owner-only. Staff roster and permission lookup exports are implemented separately, but cooking delegation remains pending. World target integrations, equipment props, animations, multi-stage recipes, food quality and expiry metadata remain pending. Finish revalidates station type, ownership, position and routing bucket; cancellation deliberately permits ingredient recovery from away from the station. Disconnected players receive no automatic output; their job remains held until an authorized owner returns and checks or cancels it. Provider changes require operator reconciliation with the original provider, not editing `provider_resource` in a job.

The application uses persisted Unix-second deadlines from the server clock; synchronize and monitor that clock. A lost reserve response restarts the full duration during reconciliation, avoiding premature completion. Recovery is explicit per job, not an automatic worker. A job in `committing` with a reserved receipt can retry finish after capacity/position checks; a job in `releasing` can retry cancellation. Uncertain outcomes hold active slots. Business rows cannot be deleted while job history references them. Recipe/station IDs remain in job snapshots without deletion cascades.
