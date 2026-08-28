# YellowShifts — Authorization & Row Level Security (RLS)

This document details the multi-station permission model, the Phase 10.5 global Platform Admin scope, role definitions, and Row Level Security implementation.

---

## 1. Authorization hierarchy

Authorization is **station-scoped for ADMIN / SHIFT_MANAGER / EMPLOYEE**. Phase 10.5 adds a **separate global** operator role:

```
PLATFORM_ADMIN  →  public.platform_admins (not station_memberships)
    |
    +-- Station A memberships: ADMIN | SHIFT_MANAGER | EMPLOYEE
    +-- Station B memberships: ADMIN | SHIFT_MANAGER | EMPLOYEE
```

`ADMIN` is Station Manager of one station. It is not a platform superuser.

### Roles:
1. **`PLATFORM_ADMIN`** (global):
   - Stored in `public.platform_admins` (`is_active`).
   - Creates stations, assigns Station Managers, inspects network health and audit.
   - May operate a station without a membership row via `is_station_admin()` extension.
   - Mutations that grant/revoke `ADMIN` must use platform RPCs / Edge Functions (audited).
2. **`ADMIN`** (station):
   - Full operational control of that station except granting/revoking `ADMIN` (`P00105`).
   - May transition `EMPLOYEE` ↔ `SHIFT_MANAGER` only.
3. **`SHIFT_MANAGER`**:
   - Operational management as previously documented. Cannot assign roles or create Platform Admin.
4. **`EMPLOYEE`**:
   - Self-scoped operational access as previously documented.

Direct client access to `platform_admins` is revoked. `is_platform_admin()` is the only client-reachable check.

---

## 2. Row Level Security Policies Across Phases

Every table has RLS explicitly enabled. The PostgreSQL engine enforces tenant boundary isolation directly:

### Core Identity & Station Tables
- **`public.profiles`**: Read own profile and profiles of station colleagues. Update self only.
- **`public.stations`**: Read stations where user holds active membership. Update station configuration restricted to station admins.
- **`public.station_memberships`**: Read roster of active station colleagues. Mutating memberships restricted to station admins with last-admin protection trigger.

### Phase 2 Availability & Template Tables
- **`public.shift_templates`**: Read active templates in station. Management requires `shift_templates.manage` capability.
- **`public.availability_periods`**: Read station periods. Creation and status transitions require management capability.
- **`public.availability_submissions`**: Employees submit and edit their own availability drafts; managers view the compiled matrix.

### Phase 3 Scheduling Tables
- **`public.work_schedules`**: Managers create and edit drafts; published schedules visible to station employees.
- **`public.work_schedule_shifts`**: Shift instances scoped to schedule.
- **`public.shift_assignments`**: Direct client write denied. Assignments managed exclusively through atomic scheduling RPCs.
- **`public.work_schedule_changes`**: Immutable post-publish audit ledger. Direct client write denied.

### Phase 4 Attendance & Kiosk Tables
- **`public.kiosk_devices`**: Direct writes denied. Managed exclusively via admin RPCs.
- **`public.kiosk_qr_challenges`**: Direct client access completely denied (`USING (false)`). Minted and validated strictly in RPCs.
- **`public.attendance_presence_proofs`**: Direct client access completely denied (`USING (false)`).
- **`public.attendance_records`**: Direct client writes denied. Read own records or station records for managers.
- **`public.attendance_corrections`**: Direct client writes denied. Appended exclusively through `correct_attendance_record`.

### Phase 6 Notifications Tables
- **`public.notifications`**: Direct table write denied. Users query their own inbox (`user_id = auth.uid()`).
- **`public.notification_events`**: Append-only system outbox. Direct client write denied.
- **`public.notification_preferences`**: Users read and update their own preferences. System mandatory alerts cannot be suppressed.
- **`public.notification_delivery_jobs`**: Managed exclusively by service-role background workers with lease locking.
- **`public.notification_devices`**: Users manage their own registered device tokens.

### Phase 7 Worked Hours & Operational Reporting
- **`reports.self.read`**: Granted to all active station members to retrieve personal attendance history and aggregate summaries (`get_my_attendance_summary`, `get_my_attendance_history`).
- **`reports.team.read`** & **`reports.station.read`**: Granted to station admins and shift managers to view station-wide KPIs and employee breakdowns.
- **Cross-Station Security Barrier**: RPCs verify membership and role before querying or aggregating data.

### Phase 8 Server-Side Exports, Audit Center & Station Governance
- **`public.report_exports`**:
  - `SELECT`: Allowed for requester (`requested_by = auth.uid()`) or station Admin (`is_station_admin(station_id, auth.uid())`).
  - Direct `INSERT`, `UPDATE`, `DELETE`: Revoked from `authenticated`, `anon`, and `PUBLIC`. Managed strictly via RPCs and Edge Functions.
- **`public.audit_logs`**:
  - `SELECT`: Restricted to station administrators (`is_station_admin(station_id, auth.uid())`).
  - Direct `INSERT`, `UPDATE`, `DELETE`: Revoked from client roles. Append-only system trigger enforcement.
- **`reports_storage` Bucket**:
  - Direct read/download: Restricted to authorized requester or station Admin via authenticated RLS and short-lived signed URLs ($\le 3600\text{s}$).

---

## 3. Function Execution Matrix

| RPC Function | Allowed Roles | Security Definer | Search Path |
| :--- | :--- | :--- | :--- |
| `provision_kiosk_device` | `authenticated` (Admin only) | Yes | `public, pg_temp` |
| `rotate_kiosk_credentials` | `authenticated` (Admin only) | Yes | `public, pg_temp` |
| `deactivate_kiosk_device` | `authenticated` (Admin only) | Yes | `public, pg_temp` |
| `reactivate_kiosk_device` | `authenticated` (Admin only) | Yes | `public, pg_temp` |
| `kiosk_authenticate_and_mint_qr` | `authenticated` (Kiosk/Admin) | Yes | `public, pg_temp` |
| `scan_attendance_qr` | `authenticated` (Station Member) | Yes | `public, pg_temp` |
| `check_in_with_presence_proof` | `authenticated` (Bound Employee) | Yes | `public, pg_temp` |
| `check_out_with_presence_proof`| `authenticated` (Bound Employee) | Yes | `public, pg_temp` |
| `correct_attendance_record` | `authenticated` (Admin / Authorized Manager) | Yes | `public, pg_temp` |
| `get_manager_live_attendance` | `authenticated` (Manager/Admin) | Yes | `public, pg_temp` |
| `claim_notification_delivery_jobs` | `service_role` | Yes | `public, pg_temp` |
| `record_delivery_attempt_outcome` | `service_role` | Yes | `public, pg_temp` |
| `get_my_attendance_summary` | `authenticated` (Active Member) | Yes | `public, pg_temp` |
| `get_my_attendance_history` | `authenticated` (Active Member) | Yes | `public, pg_temp` |
| `get_station_attendance_summary` | `authenticated` (Manager/Admin) | Yes | `public, pg_temp` |
| `get_station_employee_attendance_summary` | `authenticated` (Manager/Admin) | Yes | `public, pg_temp` |
| `get_station_daily_attendance_report` | `authenticated` (Manager/Admin) | Yes | `public, pg_temp` |
| `get_station_employee_attendance_detail` | `authenticated` (Manager/Admin) | Yes | `public, pg_temp` |
| `request_report_export` | `authenticated` (Role/Capability dependent) | Yes | `public, pg_temp` |
| `claim_report_export` | `authenticated`, `service_role` | Yes | `public, pg_temp` |
| `get_report_export_dataset` | `authenticated`, `service_role` | Yes | `public, pg_temp` |
| `generate_report_export_csv` | `authenticated`, `service_role` | Yes | `public, pg_temp` |
| `admin_query_audit_logs` | `authenticated` (Admin only) | Yes | `public, pg_temp` |
| `admin_update_station` | `authenticated` (Admin only) | Yes | `public, pg_temp` |
| `admin_cleanup_station_exports` | `authenticated` (Admin only) | Yes | `public, pg_temp` |
| `get_station_system_health` | `authenticated` (Admin only) | Yes | `public, pg_temp` |
| `is_platform_admin` | `anon`, `authenticated` (boolean; fail-closed) | Yes | `public, pg_temp` |
| `platform_create_station` | `authenticated` (PLATFORM_ADMIN) | Yes | `public, pg_temp` |
| `platform_update_station` | `authenticated` (PLATFORM_ADMIN) | Yes | `public, pg_temp` |
| `platform_set_station_active` | `authenticated` (PLATFORM_ADMIN) | Yes | `public, pg_temp` |
| `platform_assign_station_admin` | `authenticated` (PLATFORM_ADMIN) | Yes | `public, pg_temp` |
| `platform_remove_station_admin` | `authenticated` (PLATFORM_ADMIN) | Yes | `public, pg_temp` |
| `platform_list_stations` | `authenticated` (PLATFORM_ADMIN) | Yes | `public, pg_temp` |
| `platform_get_overview` | `authenticated` (PLATFORM_ADMIN) | Yes | `public, pg_temp` |
| `platform_query_audit_logs` | `authenticated` (PLATFORM_ADMIN) | Yes | `public, pg_temp` |
| `admin_get_station_members` | `authenticated` (Admin only) | Yes | `public, pg_temp` |
| `admin_update_employee_profile` | `authenticated` (Admin only) | Yes | `public, pg_temp` |
| `admin_update_membership` | `authenticated` (Admin only) | Yes | `public, pg_temp` |
| `cleanup_expired_data` | `service_role` | Yes | `public, pg_temp` |
