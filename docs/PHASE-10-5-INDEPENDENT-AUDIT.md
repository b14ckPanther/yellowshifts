# YellowShifts — Phase 10.5 Independent Audit & Remediation

**Final status:** `PHASE 10.5 INDEPENDENTLY CERTIFIED — READY FOR PRE-PILOT SETUP`

This is not a controlled real-station pilot, not production launch, and not real-device validation.

**Audit date:** 2026-08-28  
**Auditor posture:** independent inspection of an already-implemented Phase 10.5. Implementation claims in `walkthrough.md`, `implementation_plan.md`, docs, comments, and recorded test counts were treated as **claimed state**, not evidence.

**Git:** no commit, no push, no history rewrite. Repository `main` still has **zero commits**.

---

## 1. Audit scope

Independent verification of platform administration, station provisioning, authorization boundaries, migrations, Edge Functions, Flutter platform-admin surfaces, secrets, version identity, CI configuration, and historical regression — before the system is allowed to proceed to **pre-pilot setup**.

**Not in scope:** bootstrapping the production Platform Admin; starting the controlled real-station pilot; inventing MFA; deploying `20260828000001`; GitHub publication.

Evidence classes used in this report:

| Class | Meaning |
| :--- | :--- |
| **STATIC CONTRACT VERIFIED** | Source inspection / string-level Edge Function contracts |
| **RUNTIME VERIFIED** | Tests executed against a local PostgreSQL database or Flutter test harness |
| **REMOTE VERIFIED** | Inspected or mutated on linked project `yellowShifts` / `<YOUR_SUPABASE_PROJECT_REF>` |

---

## 2. Repository state

| Item | Actual |
| :--- | :--- |
| Root | `<repository-root>` |
| Branch | `main` |
| Commits | **none** (`git log` empty) |
| Remote | `https://github.com/b14ckPanther/yellowshifts.git` (not pushed) |
| Working tree | entirely untracked; no staging performed |
| Linked Supabase | `yellowShifts` / `<YOUR_SUPABASE_PROJECT_REF>` |

**001–017 immutability:** cannot be cryptographically established. There is no Git commit history and no hash baseline to compare. Filenames and contents were inspected as they exist on disk. **001–017 were not edited during this audit.**

---

## 3. Claimed baseline vs actual baseline

| Claim | Independent result |
| :--- | :--- |
| Phase 10.5 ready — audit required | Was the pre-audit implementation status. **Superseded** by this audit. |
| Canonical migrations 001–017 immutable | Present on disk and remotely applied. Cryptographic immutability **not proven**. |
| Migration 018 applied remotely | **True** before this audit. Left unmodified. |
| Schema `20260825000018` / platform `1.0.5` | **True** before remediation. After 019: schema **`20260825000019`**, platform still **`1.0.5`**. |
| AppConfig `1.0.5+11` vs pubspec `0.1.0+1` | **True contradiction.** Remediated: pubspec is now `1.0.5+11`. |
| `platform_admins` = 0 | **True** before and after this audit. Production Platform Admin was **not** bootstrapped. |
| `20260828000001` local-only | **True.** Not deployed. Decision: **KIOSK FIX SAFE TO DEFER**. |

---

## 4. Canonical versioning policy

These numbers are **not** required to be identical; they must not contradict one another.

| Identity | Value | Meaning |
| :--- | :--- | :--- |
| Flutter package / app version | `pubspec.yaml` `1.0.5+11` | Application release identity (`1.0.5` version, build `11`) |
| AppConfig release | `1.0.5+11` | Must match pubspec |
| Platform / product compatibility version | `1.0.5` | Returned by `get_platform_schema_version().platform_version` |
| Schema version | `20260825000019` | Latest **applied** additive migration identity advertised by `get_platform_schema_version()` |
| Minimum compatible client | `1.0.0` | Fail-closed floor for older clients; not a lockout of current `1.0.5` |
| Minimum backend schema (Flutter) | `20260825000019` | Client refuses an older backend than this migration |

`0.1.0+1` is no longer an application release identity.

---

## 5. Kiosk migration `20260828000001` — decision

**KIOSK FIX SAFE TO DEFER**

| Question | Evidence |
| :--- | :--- |
| What it changes | `CREATE OR REPLACE` of `deactivate_kiosk_device` / `reactivate_kiosk_device` with explicit `target_id::text` and `timezone('utc', now())` |
| Why it exists | Defensive rewrite of Phase 4 (005) functions. Original 005 inserts a UUID into TEXT `audit_logs.target_id` (implicit cast). |
| Remote | **Not applied.** Remote still uses 005 bodies. |
| Flutter | Calls 1-arg RPCs; does not depend on the explicit cast. |
| Tests | Local suites apply all files including this one; they do not prove remote needs it. |
| Production defect | **Not demonstrated.** Phase 4 kiosk deactivate/reactivate tests pass on the 005 semantics. |
| Ordering | Timestamp `20260828` is after 018/019. Applying it after 019 is additive `CREATE OR REPLACE` and would be safe, but is unnecessary for pilot. |
| Local/remote drift | Local test DBs include it; remote does not. Drift is limited to two kiosk RPCs’ audit/timestamp style, not authorization. |

Do not rewrite migration numbering to hide this file. Leave it in `supabase/migrations/` undeployed until a real production failure is observed.

---

## 6. Findings (including those that were fixed)

### HIGH — `is_platform_admin` UUID oracle / `is_station_admin` PA enumeration

**Status:** FIXED in `20260825000019` (RUNTIME VERIFIED locally, REMOTE VERIFIED `search_path` + grant)

`is_platform_admin(p_user_id UUID DEFAULT NULL)` was granted to `anon`/`authenticated` and honored a client-supplied UUID. Combined with the Phase 10.5 `is_station_admin` platform-admin shortcut, an ordinary caller could ask `is_station_admin(any_station, candidate_uuid)` and detect Platform Admins.

**Remediation:** public `is_platform_admin()` ignores the argument and uses `auth.uid()` only. Internal `_active_platform_admin(uuid)` is **not** granted to `anon`/`authenticated`. Platform-admin shortcuts in `is_station_admin` / `is_station_member` / `is_station_manager_or_admin` / `has_station_permission` require `auth.uid() IS NOT DISTINCT FROM p_user_id`.

### HIGH — provisioning-key race / unscoped idempotency

**Status:** FIXED in `20260825000019` (RUNTIME VERIFIED)

Idempotency insert happened after station insert; keys were not caller-scoped. Concurrent same-key requests could orphan a station; another Platform Admin could reuse a key.

**Remediation:** keys are caller-scoped (`created_by`). Lost races delete the orphaned station/memberships/audit rows. Foreign key reuse raises `P00107`.

### MEDIUM — contradictory app release identity

**Status:** FIXED

`pubspec.yaml` was `0.1.0+1` while AppConfig was `1.0.5+11`. Pubspec is now `1.0.5+11`. Schema pins updated to `20260825000019`.

### MEDIUM — Platform Admin blocked on employee Edge Functions

**Status:** FIXED (STATIC CONTRACT VERIFIED; functions DEPLOYED)

`admin-create-employee` / `admin-update-employee` required a station membership ADMIN row, so a Platform Admin without membership could not create/update EMPLOYEE/SHIFT_MANAGER despite `is_station_admin` treating them as operators. Both functions now accept `rpc('is_platform_admin')` after the membership check fails, still reject `ADMIN` (`P00105`).

### MEDIUM — `platform-create-station` used first-page `listUsers()`

**Status:** FIXED (STATIC CONTRACT VERIFIED; function DEPLOYED v2)

Identity lookup now uses `platform_lookup_user_by_email` (PLATFORM_ADMIN-only, case-insensitive, no secrets). Compensating `deleteUser` on failure is unchanged.

### MEDIUM — Phase 1 SQL suite hardcoded Homebrew `psql`

**Status:** FIXED

`test/sql/run_phase1_security_tests.py` now uses `shutil.which("psql")` with a Homebrew fallback. Required for Ubuntu CI.

### LOW — `.gitignore` omitted `coverage/`

**Status:** FIXED

### LOW — `scripts/bootstrap_admin.py` claimed success without mutating anything and fell back to the anon key

**Status:** FIXED

The script now refuses anon-key bootstrap, prints the canonical SQL from `docs/PLATFORM_ADMIN_BOOTSTRAP.md`, and does not connect to any database.

### INFORMATIONAL — Edge Function “tests” are static

`run_phase10_5_edge_function_contracts.py` is **STATIC CONTRACT VERIFIED** (33/33 after remediation). It is not a live JWT invocation suite.

### INFORMATIONAL — MFA documented, not implemented

Does not block pre-pilot. **MFA is strongly recommended for PLATFORM_ADMIN before broad production rollout.**

### INFORMATIONAL — GitHub Actions never executed

Nothing has been pushed. Maximum valid claim: **CI CONFIGURATION LOCALLY AUDITED**.

---

## 7. Migration changes

| File | Action |
| :--- | :--- |
| `20260825000001`–`20260825000017` | Not edited |
| `20260825000018_phase10_5_platform_administration.sql` | Not edited (already applied remotely) |
| `20260825000019_phase10_5_independent_audit_remediation.sql` | **New additive.** Applied remotely. Records `schema_version=20260825000019`. |
| `20260828000001_fix_kiosk_audit_log_columns.sql` | Unchanged, **not deployed** |

---

## 8. Edge Function changes

| Function | Change | Remote after audit |
| :--- | :--- | :--- |
| `platform-create-station` | `platform_lookup_user_by_email` instead of `listUsers()` | ACTIVE v2, `verify_jwt: true` |
| `admin-create-employee` | Platform Admin may create EMPLOYEE/SHIFT_MANAGER without membership | ACTIVE v4, `verify_jwt: false` (pre-existing gateway flag preserved; function still calls `auth.getUser()`) |
| `admin-update-employee` | Same PA fallback; still rejects ADMIN grant/revoke | ACTIVE v3, `verify_jwt: true` |
| `platform-assign-station-admin` / `platform-remove-station-admin` | Unchanged | ACTIVE v1 |

Live HTTP JWT invocation of these functions was **not** performed (production `platform_admins` remains 0). SQL RPCs they wrap were **RUNTIME VERIFIED**.

---

## 9. Flutter changes

- `AppConfig.minimumBackendSchemaVersion` and `kTargetSchemaVersion` → `20260825000019`
- `pubspec.yaml` → `1.0.5+11`
- Tests pinning schema 018 updated
- Route guard remains fail-closed via `isPlatformAdminValueProvider` (false while loading)
- Employee UI: assignable roles Employee / Shift Manager only; existing ADMIN read-only (“Station Manager”)

---

## 10. `is_station_admin` blast radius

Phase 10.5 made an active Platform Admin pass `is_station_admin` / `is_station_member` / `has_station_permission` **without a membership row**. After 019 this shortcut applies **only when the JWT subject is that same user**.

| Capability gained by PA (self) | Classification |
| :--- | :--- |
| Station list/update/health, audit (platform RPCs) | EXPECTED PLATFORM OPERATION |
| Operate a station in Flutter operating-station context | EXPECTED PLATFORM OPERATION |
| Schedule / attendance / kiosk / export / identity admin RPCs that call `is_station_admin` | EXPECTED PLATFORM OPERATION (support) |
| Detect other users as PA via `is_station_admin(station, other_uuid)` | UNINTENDED — **fixed** |
| `recover_stuck_operational_jobs` | Not granted (service_role only) — RUNTIME VERIFIED |
| Insert `platform_admins` | Not granted |

PA does **not** require fake `station_memberships` rows (RUNTIME VERIFIED: count 0).

---

## 11. Station provisioning / Auth compensation

PostgreSQL `platform_create_station` is one transaction. Supabase Auth is not.

| Scenario | Actual behavior |
| :--- | :--- |
| DB station create succeeds, Auth fails | Auth is attempted **before** RPC when creating a new manager. Failure returns `AUTH_CREATION_FAILED` without calling the RPC. |
| Auth create succeeds, RPC fails | Compensating `deleteUser`. If compensation itself fails, an orphaned Auth user is possible. **Not atomic.** |
| Existing user email (case-insensitive) | Lookup via `platform_lookup_user_by_email`; no second Auth user. |
| Duplicate code | `P00106` |
| Same caller + same idempotency key | Returns original station (`idempotent: true`) |
| Different caller + same key | `P00107` |
| Concurrent same key | Loser deletes orphaned station and follows the stored key or `P00107` |

Do not claim Auth+DB atomicity.

---

## 12. Test evidence (executed in this audit)

### Independent audit suite (new)

`test/sql/run_phase10_5_independent_audit.py` — **87/87** RUNTIME VERIFIED

Covers: schema 019, `is_platform_admin` identity (including ignored foreign UUIDs), PA oracle blocked, grants on `_active_platform_admin` / keys / `platform_admins` / `recover_stuck_operational_jobs`, P00105 table+RPC, EMPLOYEE↔SHIFT_MANAGER, cross-station, last-admin P0001, inactive PA, idempotency + P00107, code normalization, lookup enumeration, station lifecycle retention, audit limit cap 100, search_path on public SECURITY DEFINER functions.

### Implementation suites (re-run after 019)

| Suite | Result |
| :--- | :--- |
| Phase 10.5 security | 36/36 |
| Phase 10.5 comprehensive | 70/70 |
| Phase 10.5 Edge contracts | 33/33 **STATIC CONTRACT VERIFIED** |

### Historical SQL (all available suites, no omissions)

Phase 1 security 12/12, comprehensive 5/5; Phase 2 security 19/19, comprehensive 29/29; Phase 3 security 10/10, comprehensive 18/18, v2 45/45; Phase 4 security 10/10, comprehensive 38/38, v2 54/54; Phase 5–10 including v2 and Phase 8 admin CRUD; Phase 9 23/23, 54/54, 57/57; Phase 10 26/26, 77/77, 88/88; Phase 10 performance pass; adversarial suite pass.

**Phase 7 v2** is explicitly scoped to migrations `001–012` (original design). Documented, not weakened.

### Historical test integrity (Phase 10.5-era modifications)

| Change | Verdict |
| :--- | :--- |
| Phase 1 Test 09 extra-admin demotion | **A.** Suite applies only 001–002. P00105 is enforced on the current schema by Phase 8 admin CRUD + 10.5 + independent audit. |
| Phase 4 overnight scan window | **A.** Still asserts the overnight shift; fixture made calendar-safe. |
| Phase 8 export date windows | **A.** Rolling 30-day window; assertion preserved. |
| Phase 7 v2 migration cap 001–012 | **A.** Original snapshot scope. |

No category B (weakened assertion) found.

### Flutter

| Gate | Result |
| :--- | :--- |
| `dart format --output=none --set-exit-if-changed .` | pass |
| `flutter gen-l10n` | pass |
| `flutter analyze` | No issues found |
| `flutter test` | **310/310** |
| `flutter build web --release` | pass |
| `flutter build web --wasm` | pass |

Platform UI tests cover Hebrew/English and widths 320–1920 for stations/create-station.

### Scans

| Scan | Result |
| :--- | :--- |
| `scripts/audit_bundle_secrets.py` | pass (270 files) |
| `scripts/verify_zero_payroll.py` | pass (237 files) |
| GPS attendance columns (Phase 10 suites) | zero `latitude`/`longitude`/`geofence`/`gps_coord` |

AppConfig embeds the **public anon JWT** for `<YOUR_SUPABASE_PROJECT_REF>`. That is expected for a public client key. `.env` is gitignored. `.env.example` uses a dummy anon token.

---

## 13. Performance (local synthetic — not production latency)

| Dataset | Query | Time | Environment |
| :--- | :--- | :--- | :--- |
| 10,000 audit rows | paginated station audit | 12.69 ms | local Postgres `yellowshifts_phase10_benchmarks` |
| 10,000 attendance rows | monthly KPI | 9.00 ms | same |
| 5,000 export rows | JSON aggregation | 8.58 ms | same |
| 304 stations | `platform_list_stations` | 26.35 ms wall | local `yellowshifts_phase10_5_independent_audit` |
| 304 stations | `platform_get_overview` | 17.16 ms wall | same |
| 304 stations | `platform_query_audit_logs` limit 100 | 12.23 ms wall | same |

---

## 14. Remote evidence (after remediation)

Project: **yellowShifts** `<YOUR_SUPABASE_PROJECT_REF>`. Not reset, recreated, or relinked.

| Check | Result |
| :--- | :--- |
| Remote history | 001–**019** applied |
| `20260828000001` | local only |
| `get_platform_schema_version()` | `20260825000019` / `1.0.5` / `HEALTHY` / min client `1.0.0` |
| `platform_admins` count | **0** |
| `_active_platform_admin` EXECUTE for authenticated | **false** |
| `_active_platform_admin` / `is_platform_admin` / `platform_create_station` search_path | `public, pg_temp` |

---

## 15. Unresolved limitations (not Critical/High)

- Production Platform Admin not bootstrapped (intentional).
- MFA not implemented.
- Remote Edge Functions not invoked with live JWTs (no PA).
- `admin-create-employee` gateway `verify_jwt` remains false; function still validates Bearer via `getUser()`.
- Auth user compensation can itself fail (orphaned Auth user possible).
- GitHub Actions not executed (repo unpublished).
- Production backup **restore** of a real backup has not been proven; migration-based schema reconstruction exists (`scripts/restore_drill.py`).
- External FCM/APNs, biometric provider, scheduler cron: **NOT CONFIGURED** unless previously configured outside this audit.
- Local/remote kiosk RPC body drift (SAFE TO DEFER).
- Real-device / kiosk hardware validation: **NOT DONE**.

---

## 16. Certification matrix

| Area | Classification | Evidence / limitation |
| :--- | :--- | :--- |
| Repository integrity | CERTIFIED WITH LIMITATIONS | Zero-commit tree; no cryptographic 001–017 baseline |
| Migration integrity | CERTIFIED | 001–018 untouched; 019 additive |
| Remote migration alignment | CERTIFIED | 001–019 remote; 28000001 deferred |
| Platform authorization | CERTIFIED | Independent suite + 10.5 suites |
| Station authorization | CERTIFIED | Cross-station tests |
| Role escalation protection | CERTIFIED | P00105 table, RPC, trigger |
| Station ADMIN restrictions | CERTIFIED | EMPLOYEE↔SM only |
| PLATFORM_ADMIN restrictions | CERTIFIED | No self-insert; inactive fails closed |
| Last-admin invariant | CERTIFIED | P0001 on active station |
| Cross-station isolation | CERTIFIED | Alpha/Beta/multi-station |
| Station provisioning | CERTIFIED WITH LIMITATIONS | RPC transactional; Auth not atomic |
| Provisioning idempotency | CERTIFIED | Same-caller retry + P00107 |
| Auth/DB compensation | CERTIFIED WITH LIMITATIONS | deleteUser best-effort |
| Platform provisioning keys | CERTIFIED | No client grants; caller-scoped |
| Station lifecycle | CERTIFIED | Deactivate retains memberships/row |
| Platform audit | CERTIFIED | PA-only; limit capped at 100 |
| Platform health | CERTIFIED | Overview/list RUNTIME VERIFIED |
| Edge Function authorization | CERTIFIED WITH LIMITATIONS | STATIC + DEPLOYED; not live JWT |
| RLS | CERTIFIED | Independent + historical suites |
| SECURITY DEFINER | CERTIFIED | All public SD functions pinned |
| Secret safety | CERTIFIED | Bundle scan pass; service_role not in Flutter |
| Flutter route guards | CERTIFIED | Fail-closed; defense in depth only |
| Flutter UI | CERTIFIED | 310 tests including platform UI |
| RTL/LTR localization | CERTIFIED | gen-l10n + HE/EN widget tests |
| Responsive layouts | CERTIFIED | 320–1920 platform layouts in tests |
| Version consistency | CERTIFIED | Policy above; pubspec=AppConfig |
| Attendance regression | CERTIFIED | Phase 4 suites including 16h telemetry-only |
| Kiosk regression | CERTIFIED WITH LIMITATIONS | Local includes 28000001; remote does not |
| Notifications regression | CERTIFIED | Phase 6 suites; provider delivery NOT CONFIGURED |
| Exports regression | CERTIFIED | Phase 8/10 suites |
| Operational maintenance | CERTIFIED | `recover_stuck_operational_jobs` service_role-only |
| Performance | CERTIFIED WITH LIMITATIONS | Local synthetic only |
| CI configuration | CERTIFIED WITH LIMITATIONS | Locally audited; Actions never ran |
| Documentation | CERTIFIED | This file + walkthrough updates |
| MFA readiness | NOT CONFIGURED | Recommended before broad production |
| Production bootstrap readiness | NOT CONFIGURED | SQL documented; not executed |
| Backup/restore readiness | CERTIFIED WITH LIMITATIONS | Schema restore drill exists; production restore unproven |
| Real-device validation | NOT CONFIGURED | Not performed |
| External provider integrations | NOT CONFIGURED | FCM/APNs/cron not claimed |

---

## 17. Remaining work before controlled real-station pilot

Pre-pilot setup may proceed. The pilot itself must **not** start until operators complete:

1. Trusted SQL bootstrap of the first Platform Admin (`docs/PLATFORM_ADMIN_BOOTSTRAP.md`).
2. Smoke of `platform-create-station` / assign / remove with that JWT.
3. Station kiosk hardware check-in/out on a real device.
4. Confirm notification providers if push is required for the pilot.
5. MFA for Platform Admin before **broad** production (strongly recommended; not a pre-pilot certification blocker).

---

## 18. Final decision

**PHASE 10.5 INDEPENDENTLY CERTIFIED — READY FOR PRE-PILOT SETUP**

Do not start the controlled real-station pilot from this document.
