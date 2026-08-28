# YellowShifts — Phase 10.5 Platform Administration

**Status:** `PHASE 10.5 INDEPENDENTLY CERTIFIED — READY FOR PRE-PILOT SETUP`  

Independent audit: [`PHASE-10-5-INDEPENDENT-AUDIT.md`](PHASE-10-5-INDEPENDENT-AUDIT.md). This file remains the **implementation** record. Claims below that conflict with the audit are superseded.

**Implementation migration:** `supabase/migrations/20260825000018_phase10_5_platform_administration.sql`  
**Remediation migration:** `supabase/migrations/20260825000019_phase10_5_independent_audit_remediation.sql` (**DEPLOYED**)  
**Schema version:** `20260825000019`  
**Platform version:** `1.0.5`  
**App / pubspec / AppConfig release:** `1.0.5+11`

Canonical migrations `001–017` were not edited. Extra file `20260828000001_fix_kiosk_audit_log_columns.sql` remains local-only (kiosk audit column fix from prior work; not deployed in this phase).

## Discrepancies vs prompt baseline

1. Git `main` may have no published history; this phase did not commit or push.
2. `pubspec.yaml` was `0.1.0+1` during implementation; the independent audit aligned it to `1.0.5+11`.
3. Option B (`public.platform_admins`) was chosen over a generic `platform_roles` table.
4. Phase 1 security tests apply only migrations `001–002`. Test 09 therefore keeps Phase 1 last-admin semantics (an extra Station Admin may be demoted). `P00105` is enforced on the current schema and covered by Phase 8 admin CRUD + Phase 10.5 suites.
5. MFA is documented and recommended, not implemented (no fake MFA).
6. Managing additional Platform Admins is bootstrap SQL only (no operator UI).
7. Remote `admin-create-employee` still has gateway `verify_jwt: false` (pre-existing). The function authenticates the Bearer token in source. New platform functions deploy with `verify_jwt: true`.
8. Local Docker was not running; `supabase status` could not inspect a local container. Remote Management API / linked DB were used instead.

## Authorization model

- Global: `PLATFORM_ADMIN` on `public.platform_admins` (`is_active`).
- Station: `ADMIN` / `SHIFT_MANAGER` / `EMPLOYEE` on `station_memberships`.
- Platform Admin is not auto-inserted into memberships.
- Operating a station is explicit client context + server `is_station_admin()` treating active platform admins as operators.

## New / modified database objects

- Tables: `platform_admins`, `platform_provisioning_keys`
- Helpers: `is_platform_admin`, `require_platform_admin`, `is_station_membership_admin`, `normalize_station_code`
- Trigger: `tr_enforce_station_admin_role_authority` (`P00105`)
- RPCs: `platform_create_station`, `platform_update_station`, `platform_set_station_active`, `platform_assign_station_admin`, `platform_remove_station_admin`, `platform_replace_station_admin`, `platform_list_stations`, `platform_get_overview`, `platform_get_health_overview`, `platform_get_station_managers`, `platform_query_audit_logs`, `platform_lookup_user_by_email`
- Hardened: `admin_update_membership`, `is_station_admin` / membership helpers, SELECT policies for platform admin on stations/profiles/audit_logs
- Schema bump (implementation): `get_platform_schema_version` → `20260825000018` / `1.0.5`  
- Schema bump (independent audit): → `20260825000019` / `1.0.5`

## Edge Functions

| Function | Change | Remote |
| :--- | :--- | :--- |
| `admin-create-employee` | Station callers may only create `EMPLOYEE` / `SHIFT_MANAGER` (`P00105`) | Deployed (v3) |
| `admin-update-employee` | Cannot grant/revoke `ADMIN` | Deployed (v2) |
| `platform-create-station` | **New** — provision station + optional manager Auth user | Deployed (v1) |
| `platform-assign-station-admin` | **New** | Deployed (v1) |
| `platform-remove-station-admin` | **New** | Deployed (v1) |

## Flutter

Feature module: `lib/features/platform_admin/`  
Routes: `/platform`, `/platform/stations`, `/platform/stations/new`, `/platform/stations/:id/managers`, `/platform/audit`, `/platform/health`  
Station employee UI: ADMIN is read-only; create/edit roles are Employee and Shift Manager only.

## Station creation flow

1. Platform Admin submits name, code, timezone (`Asia/Jerusalem` supported), optional initial manager email, idempotency key.
2. Flutter calls `platform-create-station` with the user JWT (anon key only).
3. Function verifies `is_platform_admin` server-side, then `platform_create_station` RPC (transactional station + defaults).
4. Optional Auth user provisioning uses service role in the function only, with compensating `deleteUser` on later failure.
5. Audit: `platform.station.created` (and manager assignment events when applicable).

## Manager assignment flow

`platform-assign-station-admin` / `platform_assign_station_admin`: PLATFORM_ADMIN only, upserts `ADMIN` membership, preserves last-admin (`P0001`), writes `platform.station_admin.assigned`. Removal uses `platform-remove-station-admin` with a required reason.

## Role restrictions

| Actor | EMPLOYEE ↔ SHIFT_MANAGER | Grant/revoke ADMIN | PLATFORM_ADMIN |
| :--- | :---: | :---: | :---: |
| EMPLOYEE / SHIFT_MANAGER | NO | NO | NO |
| Station ADMIN | YES | NO (`P00105`) | NO |
| PLATFORM_ADMIN | YES* | YES | trusted SQL only |

\* When operating in station context / via platform RPCs that treat active platform admins as operators.

## Local verification (completed)

| Gate | Result |
| :--- | :--- |
| `dart format --output=none --set-exit-if-changed .` | Pass |
| `flutter gen-l10n` | Pass |
| `flutter analyze` | No issues |
| `flutter test` | **310/310** |
| `flutter build web --release` | Pass |
| `flutter build web --wasm` | Pass |
| `scripts/audit_bundle_secrets.py` | Zero privileged client credentials |
| `scripts/verify_zero_payroll.py` | Zero payroll |

### Phase 10.5 suites

- Security: **36/36**
- Comprehensive audit: **70/70**
- Edge Function contracts: **29/29**
- Flutter platform UI: **26/26** (included in the 310)

### Historical SQL (final pass)

| Suite | Result |
| :--- | :--- |
| Phase 1 security | 12/12 |
| Phase 1 comprehensive | 5/5 |
| Phase 2 security / comprehensive | 19/19, 29/29 |
| Phase 3 security / comprehensive / v2 | 10/10, 18/18, 45/45 |
| Phase 4 security / comprehensive / v2 | 10/10, 38/38, 54/54 |
| Phase 5 security / comprehensive / v2 | 12/12, 46/46, 66/66 |
| Phase 6 security / comprehensive / v2 | 16/16, 60/60, 50/50 |
| Phase 7 security / comprehensive / v2 | 20/20, 26/26, 63/63 |
| Phase 8 security / admin CRUD / comprehensive / v2 | 26/26, 23/23, 22/22, 64/64 |
| Phase 9 security / comprehensive / v2 | 23/23, 54/54, 57/57 |
| Phase 10 security / comprehensive / v2 / performance | 26/26, 77/77, 88/88, pass |
| Phase 10.5 security / comprehensive / contracts | 36/36, 70/70, 33/33 (contracts are STATIC) |
| Phase 10.5 independent audit | 87/87 |

Phase 7 v2 is scoped to migrations `001–012` as originally intended (later migrations add a compatible `get_my_attendance_history` overload). Phase 4 overnight scan and Phase 8 export date windows were made time-of-day / calendar safe.

CI (`.github/workflows/ci.yml`) runs the new SQL/contract suites as mandatory gates (`continue-on-error` is not used).

## Remote deploy (completed)

Linked project confirmed: **yellowShifts** `<YOUR_SUPABASE_PROJECT_REF>` (`https://<YOUR_SUPABASE_PROJECT_REF>.supabase.co`). Migrations `001–017` were already aligned. Project was not reset, recreated, or relinked.

- Implementation applied `20260825000018_phase10_5_platform_administration.sql`
- Independent audit applied **only** `20260825000019_phase10_5_independent_audit_remediation.sql` (018 was not rewritten)
- `20260828000001` remains local-only (**KIOSK FIX SAFE TO DEFER**)
- Post-audit remote `get_platform_schema_version()`: `schema_version=20260825000019`, `platform_version=1.0.5`, `status=HEALTHY`
- `platform_admins` row count: **0** (first Platform Admin is not bootstrapped yet)

## Secrets / product invariants

Flutter never receives `service_role`. Zero payroll and zero GPS attendance remain true (bundle scan + Phase 10 GPS column checks).

## Remaining external prerequisites

- Phase 10.5 independent audit: **complete** ([`PHASE-10-5-INDEPENDENT-AUDIT.md`](PHASE-10-5-INDEPENDENT-AUDIT.md))
- Trusted bootstrap of the first production Platform Admin (`docs/PLATFORM_ADMIN_BOOTSTRAP.md`) — **not done**
- MFA enrollment for Platform Admin (strongly recommended before broad production rollout)
- Controlled real-station pilot (not started)
- Optional later deploy of local-only `20260828000001` kiosk audit-column fix (out of Phase 10.5 scope)
