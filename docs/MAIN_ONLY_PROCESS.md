# Main-only repository workflow

The project currently develops on `main`. This document is a **contributor procedure**, not a claim that GitHub branch protection is configured.

1. Inspect `main` and the latest completed GitHub Actions run before changing source.
2. Keep a change narrow, with tests and docs in the same commit. Prefer atomic updates with the current `main` commit as an expected parent.
3. Use fast-forward-only updates and reject stale expected heads; never force-push or rewrite published history.
4. Each commit must run Lua 5.4 syntax/contracts, SQL checks, MySQL stock tests and React TypeScript/Vite jobs through `.github/workflows/nui.yml`.
5. On failure, inspect the failing job, fix on `main` with an explanatory commit, and rerun checks. Do not interpret queued CI as passed.
6. Keep unfinished modules disabled. Do not create a release tag or claim live ESX/QBCore/QBox support without a dated in-game evidence record.
7. Record testing gaps, provider contracts and rollback information before any operator-facing release.

Repository administrators should review whether approvals/branch protection are desirable. This procedure alone cannot enforce them.
