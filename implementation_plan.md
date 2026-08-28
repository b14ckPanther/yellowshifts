# YellowShifts Phase 10.5 — Implementation Plan

**Historical planning document.** Post-audit state is in [`docs/PHASE-10-5-INDEPENDENT-AUDIT.md`](docs/PHASE-10-5-INDEPENDENT-AUDIT.md). Do not treat numbered claims below as current production identity (schema is `20260825000019`; app release is `1.0.5+11`).

Inspected against the live repository on 2026-08-28. The repository is the source of truth.

## Baseline discrepancies vs. the Phase 10.5 prompt

1. **Git history**: `main` has **no commits**. All project files are untracked. No destructive Git operations will be performed; nothing will be committed or pushed.
2. **Migrations**: Canonical files are `20260825000001`–`20260825000017`. **018 is unused.** An extra additive file `20260828000001_fix_kiosk_audit_log_columns.sql` exists after 017. Phase 10.5 will add `20260825000018_phase10_5_platform_administration.sql` (sorts after 017 and before the 20260828 kiosk fix).
3. **Phase 10 had no migration 018** — confirmed.
4. **Roles**: `public.station_role` remains `ADMIN | SHIFT_MANAGER | EMPLOYEE`. `ADMIN` is station-scoped. It will **not** be renamed.
5. **`admin-create-employee` currently accepts `ADMIN`** — will be rejected for station-admin callers.
6. **`admin-update-employee` / `admin_update_membership` currently allow ADMIN role changes** for station admins (last-admin trigger only). Will be hardened server-side.
7. **No in-app station creation exists** — stations are created out-of-band today.
8. **Authorization is station-membership-only** (`docs/AUTHORIZATION-RLS.md`). Platform scope will be additive and separate.
9. **Schema version** is `20260825000017` (`get_platform_schema_version`, `get_station_system_health`, Flutter `kTargetSchemaVersion`). Will bump to `20260825000018`. Phase 9/10 tests that pin the exact version must be updated so historical suites still pass against the new canonical version.
10. **`pubspec.yaml` version is `0.1.0+1`** while `AppConfig` advertises `1.0.0+10`. Preserve both; bump `AppConfig.buildNumber` to 11 and schema minimum only.
11. **Supabase MCP is unauthenticated** in this session. Remote inspect/deploy will use the Supabase CLI against the already-linked project (`<YOUR_SUPABASE_PROJECT_REF>`) after local verification. No project reset/relink.

## Authorization model

```
PLATFORM_ADMIN  (public.platform_admins, global, not a station_memberships role)
    └── Station N
          ├── ADMIN           (station manager — station-scoped)
          ├── SHIFT_MANAGER
          └── EMPLOYEE
```

- Table: `public.platform_admins` (Option B — single platform role).
- `PLATFORM_ADMIN` is **never** stored as `station_memberships.role`.
- Platform Admin is **not** auto-inserted into `station_memberships`.
- Opening a station uses explicit operating context, not a fake membership.

## Server design

Helpers (SECURITY DEFINER, `search_path = public, pg_temp`, fail-closed):

- `is_platform_admin(uuid default auth.uid())`
- `require_platform_admin()`
- `is_station_admin` / `is_station_member` / `is_station_manager_or_admin` / `has_station_permission` extended so an **active** platform admin can operate a station without membership (read + existing admin RPCs).
- Membership **INSERT/UPDATE/DELETE RLS** recreated as **membership-admin only** so platform mutations stay on audited RPCs (no unaudited PostgREST writes).
- Trigger `enforce_station_admin_role_authority`: when `auth.role() = authenticated`, only `is_platform_admin()` may grant/revoke/mutate ADMIN memberships.
- `admin_update_membership` hardened: station ADMIN may only transition `EMPLOYEE ↔ SHIFT_MANAGER`. ADMIN grant/revoke is `P00105` unless caller is platform admin. Last-admin `P0001` remains.

Privileged RPCs (authenticated EXECUTE, revoked from PUBLIC/anon):

- `platform_create_station` (atomic, unique code, idempotency key)
- `platform_assign_station_admin`
- `platform_remove_station_admin`
- `platform_replace_station_admin`
- `platform_update_station`
- `platform_set_station_active` (reuses P0082 deactivation safety)
- `platform_list_stations` (aggregate summary, no per-employee fetch)
- `platform_get_overview`
- `platform_get_station_managers`
- `platform_query_audit_logs` (paginated, cross-station for platform admin)
- `platform_get_health_overview`

## Edge Functions

- Harden `admin-create-employee` and `admin-update-employee`: station-admin callers cannot assign/change ADMIN.
- New: `platform-create-station`, `platform-assign-station-admin`, `platform-remove-station-admin`.
- Auth from JWT only. Service role stays server-side. Auth user provisioning reuses the existing create-user pattern with compensating delete on failure.

## Flutter

- Feature module `lib/features/platform_admin/` (data / domain / presentation).
- Dedicated `/platform/*` routes and shell. Ordinary users fail closed.
- After login, active platform admins land in Platform Administration (not forced into a station).
- “Open station” sets operating context + banner: Platform Admin · Operating: {station}.
- Station employee UI: role dropdown is Employee / Shift Manager only. Existing ADMIN is read-only (“Managed by Platform Administration”).
- Hebrew + English ARB parity. Responsive 320–1920.

## Tests & CI

- `test/sql/run_phase10_5_platform_admin_security_tests.py`
- `test/sql/run_phase10_5_comprehensive_audit.py` (≥60 meaningful scenarios)
- Flutter widget/unit tests for guards, role restriction, platform screens, RTL/LTR, responsive widths.
- CI: add the new SQL suites; keep all prior gates; no `continue-on-error`.
- Update Phase 9/10 schema-version assertions to `20260825000018`.

## Out of scope (preserved)

- No payroll. No GPS attendance. No destructive station/user deletion UI.
- No client `service_role`. No PLATFORM_ADMIN management UI (bootstrap-only; documented).
- MFA: document as strongly recommended; do not invent fake MFA.
- No real-station pilot. No Git commit/push.
- Migrations 001–017 immutable.
