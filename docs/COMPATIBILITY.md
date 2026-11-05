# Compatibility and verification status

As of 2026-11-05, separate server-side ESX/QBCore/QBox adapter files have mocked contract tests in CI. No live FiveM server result is recorded.

| Component | Code present | Live verified | Status |
| --- | --- | --- | --- |
| FiveM resource manifest and Lua lifecycle | Yes | No | Requires build assets and server smoke test |
| React/TypeScript NUI close/request bridge | Yes | No | Browser build passed, FiveM interaction pending |
| ESX identity adapter | Yes, isolated adapter and mocked tests | No | Run actual FiveM framework smoke test |
| QBCore identity adapter | Yes, isolated adapter and mocked tests | No | Run actual FiveM framework smoke test |
| QBox identity adapter | Yes, isolated adapter and mocked tests | No | Run actual FiveM framework smoke test |
| oxmysql/manual schema gate | Yes | No | Apply both SQL scripts; automated migration upgrades not implemented |
| ox_lib dependency | Declared | No | UI helpers not yet used |
| Inventory / target | No | No | Planned optional adapters |
| Standalone banking / billing | No | No | Planned separately |
| External banking / billing | No | No | Candidate APIs require inspection and live testing |

No compatibility claim should be published until a dated in-server test names framework and provider versions, configured options, pass/fail evidence and restart outcome.
