# Installation, configuration and release procedure

This resource is **0.8.0-dev**, not a certified release. The instructions below are for a staging FiveM server.

## Install on staging

1. Back up the database and the existing resource directory. Keep a recovery copy.
2. Install/start one framework: ESX, QBCore or QBox. Do not simultaneously run two independent primary frameworks.
3. Install/start `oxmysql`, `ox_lib`, `ox_inventory` and `ox_target`. Verify each resource is healthy before starting TSFoodBusiness.
4. Import `sql/install.sql` into the intended MySQL database with stop-on-error enabled. Do **not** use `sql/uninstall.sql` to upgrade; it removes resource data.
5. From `web/`, run `npm ci`, `npm run check` and `npm run build`. Confirm `web/dist/index.html` and `web/dist/assets/` are present in the deployment package.
6. Set `FoodBusiness.Framework` to the actual primary framework in `shared/config.lua` if auto detection is ambiguous.
7. Keep `FoodBusiness.Modules.kitchen = false`, and leave orders, finance, NPC customers and offline sales disabled until separately tested and implemented.
8. Add `ensure ts-foodbusiness` to `server.cfg` **after** the framework and required ox resources. Grant trusted administrators `add_ace group.admin tsfoodbusiness.create allow` or an equivalent narrowly scoped ACE.
9. Start the resource. Check console for schema/integrity errors. The resource must refuse database-dependent functionality on schema mismatch; do not bypass that check.
10. Open `/foodbusiness_ui` with an authorized test character. Create a disposable business and verify recipes, stations, staff and operations according to [live QA](STAFF_BUSINESS_LIVE_QA.md).

## Release checks

- [ ] All Lua/SQL/TypeScript CI jobs pass for the exact release commit.
- [ ] NUI production bundle included and verified in FiveM.
- [ ] Database install and additive upgrade verified on real MySQL, including restart, constraints and rollback.
- [ ] Staff/business management scenarios pass on all three frameworks.
- [ ] UI mouse/keyboard/focus/error/restart tests pass in actual FiveM NUI.
- [ ] Cooking smoke test passes if kitchen is enabled (see [cooking test](COOKING_LIVE_SMOKE_TEST.md)).
- [ ] Unsupported modules remain disabled and are not advertised as functional.
- [ ] Permissions, audit and resource restart behaviour verified.
- [ ] Installation, rollback and known limitations included in release notes.
- [ ] Release version and changelog updated only after acceptance evidence is collected.

## Rollback

Stop the resource. Restore the prior resource directory and, **if schema changes are incompatible**, restore the database from the matching backup. Never apply `sql/uninstall.sql` as rollback. Verify schema compatibility before restarting the prior build.

## Known limitations

Conventional cooking uses non-atomic ox_inventory item mutations and requires manual recovery on uncertain outcomes. Cooking, orders, finance, NPC customers and offline sales are disabled by default. Passing unit tests does not establish FiveM runtime or ESX/QBCore/QBox compatibility.
