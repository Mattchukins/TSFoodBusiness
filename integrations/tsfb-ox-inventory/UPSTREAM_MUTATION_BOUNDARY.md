# Standard ox_inventory mutation boundary — implementation decision

Source baseline: upstream `overextended/ox_inventory` commit [`488aa6d754dfbf7d169f355ccbd647dc60c5ec3a`](https://github.com/overextended/ox_inventory/tree/488aa6d754dfbf7d169f355ccbd647dc60c5ec3a), `modules/inventory/server.lua` (reviewed 13 October 2026). Pin and revalidate this exact revision before integration; do not assume compatibility with forks.

## Verified source behaviour

- `Inventory.RemoveItem` and `Inventory.AddItem` are separate functions/exports, each modifying the live inventory independently.
- `Inventory.Save` serializes the current inventory and writes player/stash data through ox_inventory's own persistence adapter; it does not participate in TSFoodBusiness SQL transactions.
- `GetInventory` and `GetSlot` provide inventory access but do not establish a cross-resource atomic transaction.

Therefore **an external Lua resource cannot implement atomic ingredient escrow and output delivery merely by composing those exports with oxmysql transactions**. A SQL journal alone is insufficient: crashes can occur after an ox mutation and before the corresponding SQL acknowledgement.

## Chosen integration boundary

Implement a *version-pinned upstream extension* at ox_inventory's authoritative mutation and persistence boundary, rather than presenting an external export wrapper as atomic. Its contract must include:

1. A durable inventory snapshot/version or item-delta transaction covering ingredient escrow and output credit, persisted together with the job receipt and immutable plan identity.
2. A single owner-scoped serialization boundary for concurrent inventory mutations, including native ox_inventory actions (not just TSFoodBusiness requests).
3. Atomic commit/replay semantics: retries must return the same receipt without consuming or delivering twice; a crash must leave either the pre-operation or post-operation durable state.
4. No externally visible `reserved` or `committed` receipt until the corresponding inventory state is durable. Reject metadata, weight/slot and capacity violations before committing.
5. Cancellation must release only an actual reserved escrow exactly once; committed output cannot be rolled back through a cancellation replay.
6. Startup must fail closed on schema mismatch, version mismatch, dirty or unresolvable receipts, missing required dependencies, or interrupted migrations.
7. Tests must terminate the process before/after each durability boundary, simulate concurrent native inventory actions, and independently verify ESX/QBCore/QBox identities and ownership.

## Current status

The external `tsfb-ox-inventory` adapter provides read-only item/count operations and limited durable receipt inspection/released tombstones. It **does not** implement the required upstream extension, atomic reservation, atomic output credit, or restart reconciliation. Keep `FoodBusiness.Modules.kitchen = false` and `FoodBusiness.Inventory.mutationsVerified = false`.

Do not enable cooking until a version-pinned upstream integration passes source-level regression and staged server crash tests. Do not silently patch an operator's installed ox_inventory fork.
