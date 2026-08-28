# YellowShifts — Production Operations & Support Runbook

## 1. Support Principles

- **Zero Direct Production Database Mutations**: Operators must never run ad-hoc `UPDATE` or `DELETE` SQL queries against production database tables unless executing an emergency, peer-reviewed, audited repair script.
- **Server Authorization Authority**: All membership, role, attendance, and shift updates must occur through audited application flows or Edge Functions.

## 1.1 Platform Administration (Phase 10.5)

Routine station creation, Station Manager assignment, and station lifecycle are performed in **Platform Administration** (`/platform`). Do not use the Supabase Table Editor for ordinary onboarding.

- Bootstrap of the first Platform Admin: [`PLATFORM_ADMIN_BOOTSTRAP.md`](PLATFORM_ADMIN_BOOTSTRAP.md).
- There is no UI to create another `PLATFORM_ADMIN`. Use trusted SQL.
- Station Admins cannot grant Station Manager (`ADMIN`) access.
- Prefer deactivation over deletion. Do not run ad-hoc `DELETE` against stations, attendance, or audit logs.

**MFA is strongly recommended for Platform Admin accounts before broad production rollout.**

---

## 2. Common Support Scenarios & Resolution Workflows

### 2.1 Employee Cannot Log In
- **Symptom**: "Invalid login credentials" or "Account suspended".
- **Diagnostic Steps**:
  1. Check `public.station_memberships` for employee `status` (`ACTIVE` vs `INACTIVE` vs `SUSPENDED`).
  2. Verify email address casing in `auth.users`.
- **Remediation**:
  - If password forgotten: Station Admin executes **Admin Reset Password** from Employees screen -> generates temporary one-time credential via Edge Function `admin-reset-password`.
  - If membership inactive: Station Admin reactivates membership from Employees console.

### 2.2 Employee Cannot Check In (Duplicate Session Error)
- **Symptom**: "Active attendance session already open".
- **Diagnostic Steps**:
  1. Inspect `public.attendance_records` for employee with `check_out_time IS NULL`.
  2. Confirm if employee forgot to check out from previous shift.
- **Remediation**:
  - Station Admin accesses Attendance Management console -> locates open record -> selects "Force Check-Out with Audit Reason" -> enters actual departure time.
  - Employee can immediately perform new check-in at physical kiosk.

### 2.3 Physical Kiosk Offline
- **Symptom**: Red indicator on Admin Health Dashboard: "Offline Kiosk".
- **Diagnostic Steps**:
  1. Verify power cord and battery state on kiosk tablet.
  2. Verify Wi-Fi network connectivity at physical station.
  3. Check browser tab is open to `/kiosk` with active display awake lock.
- **Remediation**:
  - Refresh kiosk browser page.
  - If tablet damaged, deactivate kiosk in Station Settings and provision a replacement device.

### 2.4 Browser Stuck on Old Cached PWA Release
- **Symptom**: User sees update banner or outdated interface.
- **Diagnostic Steps**:
  1. Check browser Console for `CompatibilityStatus.clientUpdateRequired`.
- **Remediation**:
  - Click "Update Now" button on update banner (triggers `window.location.reload(true)` and cache invalidation).
  - Alternatively, hard-refresh browser via keyboard shortcut (`Ctrl+Shift+R` / `Cmd+Shift+R`).
