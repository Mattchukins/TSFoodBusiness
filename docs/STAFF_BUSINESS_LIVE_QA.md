# Staff and business management — live acceptance testing

**Status:** manual FiveM and real-MySQL validation required. Mocked Lua tests and CI cannot certify runtime behaviour.

## Test matrix

Repeat each scenario on a disposable ESX, QBCore and QBox test server. Use two connected characters (owner and employee), plus an unrelated player. Back up the test database before applying `sql/install.sql`.

| Area | Action | Pass criteria |
| --- | --- | --- |
| Business | Admin creates a business using `/foodbusiness_ui` | Exactly one business persists after resource restart; non-admin creation denied |
| Business | Owner renames or edits the business | Changes persist; unrelated player cannot edit |
| Business | Submit invalid names, spoofed IDs and duplicate requests | Request rejected; no extra rows or audit entries |
| Operations | Owner changes hours and capacities | Valid values persist; invalid values rejected; old values retained on failure |
| Catalog | Create, edit and remove recipes and supplier entries | Correct business scope; data persists; invalid ingredient lists rejected |
| Stations | Place, move and delete a station | Coordinates and routing bucket persist; other businesses unaffected |
| Staff | Owner assigns an online employee | Server resolves actual character ID; role persists; owner cannot assign themselves |
| Staff | Assign the same employee again | Duplicate denied; one roster row |
| Staff | Employee tries to edit the roster | Denied, including forged NUI requests |
| Staff | Owner changes a role using current revision | Exactly one update and audit entry; stale revision rejected |
| Staff | Owner removes employee | Role access immediately revoked; duty and active shift are closed or handled per schema contract |
| Duty | Employee clocks in and out | Revision increments, active shift opens/closes, history remains |
| Duty | Two concurrent duty updates | One succeeds, one conflicts; never two open shifts |
| Duty | Disconnect or character switch during duty | No cross-character authorization; record actual disconnect behaviour |
| Audit | Owner views business activity | Correct business only; no unrelated records |
| Reliability | Stop database during a write | Operation fails closed; no partial mutation or orphan audit |
| Reliability | Restart script with populated schema | Existing records survive; UI loads correctly |
| UI | Escape/close, keyboard navigation, focus and repeated open/close | No stuck cursor, duplicate submissions or unusable forms |
| UI | Disconnect or delay server response | Error displayed; loading controls recover; no false success |

## Evidence and sign-off

For each framework, record resource versions, server artifact version, SQL schema version, exact steps, expected/actual results, console logs, screenshots, and before/after database rows. Confirm rollback and audit records in MySQL; a green GitHub Actions run alone is insufficient.

Mark each case PASS / FAIL / BLOCKED. **Do not mark staff, business management, or framework compatibility release-ready until all applicable cases pass.**
