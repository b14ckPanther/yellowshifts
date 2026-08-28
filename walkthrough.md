# YellowShifts Phase 10.5 — Walkthrough

## Status

**PHASE 10.5 INDEPENDENTLY CERTIFIED — READY FOR PRE-PILOT SETUP**

This is not a controlled real-station pilot, not production launch, and not real-device validation.

Independent audit record: [`docs/PHASE-10-5-INDEPENDENT-AUDIT.md`](docs/PHASE-10-5-INDEPENDENT-AUDIT.md).  
Implementation record: [`docs/PHASE-10-5-PLATFORM-ADMIN.md`](docs/PHASE-10-5-PLATFORM-ADMIN.md).

## Git

Independent audit recorded a zero-commit working tree. Public Git history is reconstructed as multiple logical commits on `main` (see [`docs/PUBLICATION_MANIFEST.md`](docs/PUBLICATION_MANIFEST.md)). No destructive Git operations. The first GitHub push is a separate step after local verification.

---

## Phase 10.5 implementation (historical)

A global **Platform Admin** operator layer on top of the existing station-scoped `ADMIN` / `SHIFT_MANAGER` / `EMPLOYEE` model.

- Storage: `public.platform_admins` (not `station_memberships.role`)
- Implementation migration: `20260825000018_phase10_5_platform_administration.sql` (additive; 001–017 untouched)
- UI: `/platform` Platform Administration (Overview, Stations, Station Managers, Health, Audit)
- Server rule: only PLATFORM_ADMIN may grant or revoke station ADMIN (`P00105`)
- Station creation: in-app → `platform-create-station` Edge Function → PostgreSQL RPC
- Bootstrap: trusted SQL only — [`docs/PLATFORM_ADMIN_BOOTSTRAP.md`](docs/PLATFORM_ADMIN_BOOTSTRAP.md)

Station Admins may move staff between **Employee** and **Shift Manager** only. Station Manager (`ADMIN`) assignment is a platform operation.

Claimed implementation gates at that time (not reused as audit proof): Flutter 310/310, Phase 10.5 SQL 36/36 + 70/70, contracts 29/29, remote 018 applied, `platform_admins` = 0.

---

## Phase 10.5 Independent Audit & Remediation

Independent inspection found real defects. They were fixed additively. Tests were re-executed by the auditor.

### Remediation migration (applied remotely)

`supabase/migrations/20260825000019_phase10_5_independent_audit_remediation.sql`

- `is_platform_admin()` uses `auth.uid()` only (client UUIDs ignored)
- Internal `_active_platform_admin` not granted to client roles
- Platform-admin station shortcuts only when the JWT subject matches
- Provisioning keys caller-scoped; foreign reuse `P00107`; lost-race orphan cleanup
- Schema version **`20260825000019`** / platform **`1.0.5`**

### Other remediations

- `pubspec.yaml` aligned to **`1.0.5+11`** (was `0.1.0+1`)
- Employee Edge Functions allow Platform Admin without membership (still cannot mint ADMIN)
- `platform-create-station` looks up users via `platform_lookup_user_by_email`
- Phase 1 SQL `psql` path works on Ubuntu CI
- Independent suite: `test/sql/run_phase10_5_independent_audit.py` **87/87**
- CI includes that suite; no `continue-on-error` on security gates

### Kiosk file

`20260828000001_fix_kiosk_audit_log_columns.sql` remains **local-only**. Decision: **KIOSK FIX SAFE TO DEFER**.

### Remote (yellowShifts `<YOUR_SUPABASE_PROJECT_REF>`)

- Migrations **001–019** applied; **28000001 not applied**
- Schema `20260825000019` / platform `1.0.5` / `HEALTHY`
- `platform_admins` = **0** (production Platform Admin not bootstrapped)
- Deployed: `platform-create-station` v2, `admin-create-employee` v4, `admin-update-employee` v3

### Audit gates (executed)

- Historical SQL Phases 1–10 including V2: pass
- Flutter format, gen-l10n, analyze, **310/310** tests, web release, WASM: pass
- Secret scan and zero-payroll scan: pass

## Next (not started)

1. Trusted bootstrap of the first Platform Admin
2. Pre-pilot operational setup
3. Controlled real-station pilot — **do not start from this walkthrough**

## Historical note

Prior walkthrough content documented Phase 6 notifications. That work remains in the repository and in `docs/`.
