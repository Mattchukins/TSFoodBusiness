# ox_inventory integration (staged; cooking disabled)

The separate resource `integrations/tsfb-ox-inventory` provides server-only item
catalogue and player stock lookups using the actual ox_inventory exports.
It is **not** an atomic production provider yet.

## Installation for read-only stock checks

1. Install and start `ox_inventory` with its supported framework configuration.
2. Copy `integrations/tsfb-ox-inventory` to a standalone server resource named
   `tsfb-ox-inventory`, and start it **after** `ox_inventory`.
3. In `ts-foodbusiness/shared/config.lua`, set:
   `FoodBusiness.Inventory.provider = 'custom'` and
   `FoodBusiness.Inventory.resource = 'tsfb-ox-inventory'`.
4. Leave `FoodBusiness.Inventory.mutationsVerified = false` and
   `FoodBusiness.Modules.kitchen = false`.

This permits stock snapshots and item existence checks only. All stock reads
are advisory and must never authorize ingredient consumption.

## Mutation integration blocker

ox_inventory exposes item removal and addition as separate calls, so a
remove-then-add cooking operation is not atomic. A process crash, disconnect,
full output inventory, or duplicate request between those calls can lose or
duplicate items. A SQL receipt alone does not solve the cross-resource
atomicity gap.

The four mutation exports intentionally fail closed. Do **not** set
`mutationsVerified = true` until a provider-specific atomic escrow/commit
implementation has been built, independently reviewed, and live-tested.
This integration does not currently implement durable ingredient claims,
transactional output delivery, or restart reconciliation.

To complete this safely, the provider needs a proven escrow design tied to
ox_inventory's inventory mutation serialization/persistence boundaries,
including metadata, weights, capacity and offline owner recovery. Validate
it against the scenarios in `docs/INVENTORY_RESERVATIONS.md`. Never replace
the failing exports with direct RemoveItem/AddItem calls.

## Framework coverage

The read-only bridge is framework-agnostic and uses FiveM player source IDs
only for stock snapshots. ESX, QBCore and QBox each still require independent
live integration testing. No framework has been certified by this addition.


## Journal and absent-claim release (experimental)

The integration now includes `schema.sql` and a server-side journal.
Import `schema.sql` into the same oxmysql database before starting the
resource, after taking a backup. `oxmysql` is now a resource dependency.

`ReleaseProduction` can durably record a `released` tombstone **only when
no existing claim has been made**. An existing reserved/committed/intent
record is rejected; it does not restore ingredients. This does not make
`ReserveProduction` or `CommitProduction` operational. The journal
schema is not a substitute for atomic ox_inventory mutations.

Do not enable cooking based on this feature. The release export is
intentionally not an escrow recovery mechanism.
