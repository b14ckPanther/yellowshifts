# YellowShifts Role Authorization & UI Isolation Guide

## 1. Single Authoritative Station Capability Model

YellowShifts operates as a multi-station workforce platform where a single user may hold distinct station-scoped roles:
- **Station A**: `EMPLOYEE`
- **Station B**: `SHIFT_MANAGER`
- **Station C**: `ADMIN`

### Absolute Authorization Invariant
Operational authority is derived **exclusively** from the active station membership:
```sql
SELECT role, status 
FROM public.station_memberships 
WHERE user_id = auth.uid() 
  AND station_id = :active_station_id 
  AND status = 'ACTIVE';
```

**Never**:
- Rely on global `user_metadata.role` or `app_metadata.role` for station operational decisions.
- Cache roles across station switches.
- Permit fallback to elevated privileges during loading or error states (**Fail-Closed Guarantee**).

---

## 2. StationAccessContext Architecture

The entire client security model is mediated by `StationAccessContext` (`lib/core/permissions/station_access_context.dart`) and watched via `stationAccessContextProvider`.

### Capability Matrix

| Capability Getter | EMPLOYEE | SHIFT_MANAGER (Delegated) | ADMIN | Unauthenticated / Inactive |
| :--- | :---: | :---: | :---: | :---: |
| `canViewEmployeeSelfAttendance` | ✅ | ✅ | ✅ | ❌ |
| `canViewOwnHours` | ✅ | ✅ | ✅ | ❌ |
| `canSubmitAvailability` | ✅ | ✅ | ✅ | ❌ |
| `canViewOwnSchedule` | ✅ | ✅ | ✅ | ❌ |
| `canViewLiveAttendance` | ❌ | ✅ | ✅ | ❌ |
| `canViewTeamReports` | ❌ | ⚙️ (Per toggle) | ✅ | ❌ |
| `canViewStationReports` | ❌ | ⚙️ (Per toggle) | ✅ | ❌ |
| `canManageSchedule` | ❌ | ⚙️ (Per toggle) | ✅ | ❌ |
| `canPublishSchedule` | ❌ | ⚙️ (Per toggle) | ✅ | ❌ |
| `canCorrectAttendance` | ❌ | ⚙️ (Per toggle) | ✅ | ❌ |
| `canManageEmployees` | ❌ | ❌ | ✅ | ❌ |
| `canCreateEmployees` | ❌ | ❌ | ✅ | ❌ |
| `canEditEmployeeProfiles` | ❌ | ❌ | ✅ | ❌ |
| `canManageMembershipRoles`| ❌ | ❌ | ✅ | ❌ |
| `canManageMembershipStatuses`| ❌ | ❌ | ✅ | ❌ |
| `canResetEmployeePassword` | ❌ | ❌ | ✅ | ❌ |
| `canRevokeEmployeeSessions`| ❌ | ❌ | ✅ | ❌ |
| `canManageStationSettings` | ❌ | ❌ | ✅ | ❌ |
| `canManageShiftManagerPermissions` | ❌ | ❌ | ✅ | ❌ |
| `canManageKiosks` | ❌ | ❌ | ✅ | ❌ |
| `canManageIdentityPolicy` | ❌ | ❌ | ✅ | ❌ |

---

## 3. Dynamic Navigation Registry

All responsive app shells (`CompactAppShell`, `MediumAppShell`, `ExpandedAppShell`) consume the unified `AppNavigationRegistry` (`lib/app/routing/navigation_registry.dart`):

1. **Compact Mobile Shell (< 600px)**: Renders bottom navigation bar with dynamically prioritized destinations (max 5 items, role-isolated).
2. **Medium Tablet Shell (600px - 1024px)**: Renders condensed vertical navigation rail with authorized destinations.
3. **Expanded Desktop Shell (> 1024px)**: Renders multi-section sidebar with distinct groupings ("MY WORKSPACE", "STATION MANAGEMENT", "GENERAL").

---

## 4. Router-Level Route Guards

`app_router.dart` applies redirect guards on all privileged URL paths before widgets mount:
- `/employees` -> Requires `access.canManageEmployees`
- `/reports` -> Requires `access.canViewStationReports || access.canViewTeamReports`
- `/settings/station` -> Requires `access.canManageStationSettings`
- `/settings/shifts` -> Requires `access.canManageShiftTemplates`
- `/settings/permissions` -> Requires `access.canManageShiftManagerPermissions`
- `/settings/kiosks` -> Requires `access.canManageKiosks`
- `/settings/identity-policy` -> Requires `access.canManageIdentityPolicy`
- `/availability/matrix` -> Requires `access.canViewTeamAvailability`

Unauthorized navigation immediately redirects the user safely to `/dashboard` without flashing privileged UI.
- `/platform`, `/platform/stations`, `/platform/audit`, `/platform/health` → require an active Platform Admin (`isPlatformAdminValueProvider` / `canAccessPlatformAdministration`). Ordinary users are redirected to `/dashboard` or `/station-select`.

---

## 5. Admin Employee CRUD Security & Last-Admin Invariant

1. **Global Profile vs Station Scope Distinction**:
   - `profiles`: Human account identity (`first_name`, `last_name`, `phone`, `preferred_locale`).
   - `station_memberships`: Station association (`role`, `status`, `employee_code`).
   - `platform_admins`: Global operator flag (`is_active`). Not a station role.
2. **Database RPC `public.admin_update_employee_profile`**:
   - `SECURITY DEFINER` with fixed `search_path = public, pg_temp`.
   - Re-verifies caller is active Station Admin (`42501`).
   - Validates target membership belongs to active station (`P0002`).
   - Validates name length & normalizes phone with unique constraint validation (`23505`).
   - Generates immutable `audit_logs` record `EMPLOYEE_PROFILE_UPDATED`.
3. **Station Admin role authority (`P00105`)**:
   - Station Admin may only assign `EMPLOYEE` or `SHIFT_MANAGER`.
   - Grant/revoke of `ADMIN` is Platform Admin only (UI, repository, Edge Function, RPC, trigger).
4. **Last-Admin Invariant (`P0001`)**:
   - `admin_update_membership` / `platform_remove_station_admin` count active admins before demotion.
   - If `COUNT(*) <= 1`, demote/deactivate of the last admin raises SQLSTATE `P0001`.
