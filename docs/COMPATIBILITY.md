# Compatibility and verification status

As of 2026-09-28, this repository contains only the v0.0.0 bootstrap. No live FiveM server result is recorded.

| Component | Implemented | Live verified | Status |
| --- | --- | --- | --- |
| FiveM resource manifest and Lua lifecycle | Yes | No | Build NUI then test in server |
| React/TypeScript NUI close bridge | Yes | No | Build and in-game smoke test pending |
| ESX | No | No | v0.1 target |
| QBCore | No | No | v0.1 target |
| QBox | No | No | v0.1 target |
| oxmysql / migrations | No | No | v0.1 target |
| ox_lib | No | No | v0.1 target |
| Inventory / target | No | No | Planned optional adapters |
| Standalone banking / billing | No | No | Planned separately |
| External banking / billing | No | No | Candidate APIs require inspection and live testing |

No compatibility claim should be published from this table until a dated in-server test names exact framework, provider versions, configured options, pass/fail evidence and restart outcome.
