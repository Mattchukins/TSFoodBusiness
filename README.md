# TwilightStore Food Business

Early development, currently **v0.1.0-dev**. [Roadmap](ROADMAP.md) phases v0.1–v0.7 are tracked in [phase progress](docs/PHASE_PROGRESS.md). This is not a playable or verified restaurant release.

## Local setup

1. Back up the oxmysql database and apply `sql/001_initial.sql` once. The resource refuses database requests if schema version 1 is missing.
2. Start `oxmysql`, `ox_lib`, and exactly one primary framework: ESX, QBCore or QBox. QBox may expose qb-core compatibility without counting as a second framework. Set `FoodBusiness.Framework` explicitly in `shared/config.lua` if auto detection is inappropriate.
3. Run `cd web && npm install && npm run check && npm run build`. The generated `web/dist` folder must be included with the installed resource.
4. Add `ensure ts-foodbusiness` after dependencies in `server.cfg`. Grant trusted staff `add_ace group.admin tsfoodbusiness.create allow` or your equivalent ACE mapping.
5. Use `/foodbusiness_ui` to open the development interface. Only authorized characters can create businesses; no restaurant gameplay or payments exist yet.

Do not advertise ESX/QBCore/QBox support until each is tested live. See [compatibility](docs/COMPATIBILITY.md), [architecture](docs/ARCHITECTURE.md) and [release gates](docs/RELEASE_GATES.md).
