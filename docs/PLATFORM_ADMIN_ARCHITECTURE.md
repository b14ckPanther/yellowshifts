# YellowShifts — Platform Administration Architecture

Phase 10.5 introduces a **global** operator role that is independent of station membership.

## Scopes

```
PLATFORM_ADMIN  (global, table public.platform_admins)
    |
    +-- Station A   ADMIN / SHIFT_MANAGER / EMPLOYEE   (station_memberships)
    +-- Station B   ADMIN / SHIFT_MANAGER / EMPLOYEE
    +-- Station C   ADMIN / SHIFT_MANAGER / EMPLOYEE
```

- **`PLATFORM_ADMIN`** is stored only in `public.platform_admins`. It is never `station_memberships.role`.
- **`ADMIN` remains Station Manager**. It is station-scoped. A Station Admin is not a platform operator.
- Opening a station as Platform Admin sets an explicit **operating context** in the Flutter client. No fake membership row is created.

## Authorization primitives

| Primitive | Purpose |
| :--- | :--- |
| `is_platform_admin()` | Fail-closed boolean from JWT `auth.uid()` + `platform_admins.is_active`. Client-supplied UUIDs are ignored. |
| `require_platform_admin()` | Raises `42501` unless an active Platform Admin |
| `is_station_membership_admin()` | True only for an **active station ADMIN membership** (not platform) |
| `is_station_admin()` | Station ADMIN membership **or** active Platform Admin **when the JWT subject is that user** (no PA oracle) |

Direct PostgREST mutations on `station_memberships` and `stations` require `is_station_membership_admin`. Platform mutations go through audited RPCs / Edge Functions.

## Privileged operations

| Operation | Path |
| :--- | :--- |
| Create station | Edge Function `platform-create-station` → RPC `platform_create_station` |
| Assign Station Manager | Edge Function `platform-assign-station-admin` → RPC `platform_assign_station_admin` |
| Remove / demote Station Manager | Edge Function `platform-remove-station-admin` → RPC `platform_remove_station_admin` |
| Update station metadata | RPC `platform_update_station` |
| Activate / deactivate | RPC `platform_set_station_active` (reuses `admin_update_station` / `P0082`) |
| Network summary | RPCs `platform_list_stations`, `platform_get_overview`, `platform_get_health_overview` |
| Audit | RPC `platform_query_audit_logs` (paginated, max 100) |

Flutter uses the public anon key only. Service role exists only in Edge Function environment secrets.

## Station Admin role rule (P00105)

A caller who is **only** a station ADMIN may transition:

- `EMPLOYEE` ↔ `SHIFT_MANAGER`

They may **not** grant, revoke, or edit `ADMIN`. Only `PLATFORM_ADMIN` may. Enforcement is in:

- Trigger `tr_enforce_station_admin_role_authority` (`P00105`)
- RPC `admin_update_membership`
- Edge Functions `admin-create-employee` and `admin-update-employee`

Last-admin protection (`P0001`) remains the final database invariant when a Platform Admin removes a Station Manager.

## Client architecture

`lib/features/platform_admin/` holds domain, repository, and presentation. Routes live under `/platform/*` inside `PlatformAdminShell`. Ordinary users are redirected by `app_router.dart` and see an unauthorized state if the shell still mounts.

After login, an active Platform Admin lands on `/platform` rather than being forced into a station.

## MFA

Supabase Auth supports TOTP MFA. YellowShifts does **not** implement MFA enrollment in Phase 10.5. **MFA is strongly recommended for every PLATFORM_ADMIN before broad production rollout.** Do not treat the current password session as sufficient for a large operator fleet.
