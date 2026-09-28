# Release gates

## v0.0.0 bootstrap

- [x] Resource manifest, Lua client/server/shared layout and version string committed.
- [x] React/TypeScript source, build script and static check committed.
- [x] Source-inspected sibling UI inventory, architecture, threat model, feature matrix and compatibility record committed.
- [ ] `npm install && npm run check && npm run build` run and passing.
- [ ] Empty resource startup, open/close and focus release tested in FiveM.
- [ ] Built NUI assets packaged for installation.

Directories for future services (`bridges/`, `modules/`, `sql/`, `tests/`) are created with their first implementation in their respective milestone; empty folders cannot be represented in Git. Do not label v0.0.0 verified until all above gates pass.

## Each subsequent release

Record Lua/static/NUI checks, migration upgrade/failure/restart evidence, security and idempotency tests, framework-specific in-server results, configured provider versions, regression/performance results and changelog entries. Never claim compatibility from source review alone.
