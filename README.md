# TwilightStore Food Business

FiveM hospitality resource at **v0.0.0 bootstrap**. Gameplay, database migrations, framework bridges, payments and compatibility are planned, not implemented.

## Build and preview

Run `cd web && npm install && npm run check && npm run build`. The build generates `web/dist/index.html` and assets needed by the FiveM resource. Add `ensure ts-foodbusiness` after building. In game, `/foodbusiness_ui` opens and closes the development shell.

The NUI preview requires a running resource; the web page alone starts hidden. The development command is temporary and does not grant permissions or perform gameplay mutations. Do not release this bootstrap as a restaurant script.

See [ROADMAP.md](ROADMAP.md), [architecture](docs/ARCHITECTURE.md), [design inventory](docs/NUI_DESIGN.md) and [compatibility](docs/COMPATIBILITY.md).
