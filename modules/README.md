# Feature modules

This folder is reserved for future **optional, independently gated gameplay modules** (POS, finance, NPC operations, hygiene, mobile businesses and extension contracts).

Today, enabled feature flags in `shared/config.lua` still route through existing shared/client/server code. Placing this folder in the resource does **not** mark roadmap modules implemented. Introduce module-specific Lua files here only with explicit startup dependencies, server-authoritative contracts, regression tests, and fail-closed configuration.

Do not add C# or JavaScript gameplay runtimes. The client and server remain Lua; the NUI remains React/TypeScript.
