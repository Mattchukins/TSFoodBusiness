# Release gates

## v0.0.0 bootstrap

- [x] Resource manifest, Lua client/server/shared layout and version string committed.
- [x] React/TypeScript source, build script and static check committed.
- [x] Source-inspected sibling UI inventory, architecture, threat model, feature matrix and compatibility record committed.
- [x] `npm install && npm run check && npm run build` passed locally on 2026-09-28.
- [ ] Empty resource startup, open/close and focus release tested in FiveM.
- [ ] Built NUI assets packaged for installation.

## v0.1.0 development checkpoint

- [x] Single framework detection and server-derived identity code added.
- [x] Schema gate refuses absent or wrong schema; manual version 1 and 2 SQL supplied.
- [x] NUI requests limited to explicit actions with server-side checks.
- [ ] ESX, QBCore and QBox separately smoke tested in FiveM.
- [ ] Migration runner, internal business ledger and complete v0.1 contracts.
- [ ] Security, restart and transaction rollback tested against MySQL.

Recipe and supplier catalog mutations are implemented but not live verified. See [phase progress](PHASE_PROGRESS.md) for v0.2–v0.7. Do not label any phase verified before its roadmap exit criteria pass.
