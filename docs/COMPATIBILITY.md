# Compatibility and verification status

As of 2026-09-28, this repository contains development source and a locally passing TypeScript/Vite build. No live FiveM server result is recorded.

| Component | Code present | Live verified | Status |
| --- | --- | --- | --- |
| FiveM resource manifest and Lua lifecycle | Yes | No | Requires build assets and server smoke test |
| React/TypeScript NUI close/request bridge | Yes | No | Browser build passed, FiveM interaction pending |
| ESX identity adapter | Yes | No | v0.1 target; independently test |
| QBCore identity adapter | Yes | No | v0.1 target; independently test |
| QBox identity adapter | Yes | No | v0.1 target; independently test |
| oxmysql/manual schema gate | Yes | No | Apply both SQL scripts; automated migration upgrades not implemented |
| ox_lib dependency | Declared | No | UI helpers not yet used |
| Inventory / target | No | No | Planned optional adapters |
| Standalone banking / billing | No | No | Planned separately |
| External banking / billing | No | No | Candidate APIs require inspection and live testing |

No compatibility claim should be published until a dated in-server test names framework and provider versions, configured options, pass/fail evidence and restart outcome.
