# Station Administration & Governance Documentation

## 1. Overview

Station Administration allows designated station administrators to manage station-level configuration, operational grace windows, regional calendar standards, employee directories, and operational status safely without affecting global accounts or historical records.

---

## 2. Configuration Parameters

| Parameter | Type | Validation & Range | Default |
|---|---|---|---|
| `name` | `TEXT` | 1..100 characters | Required |
| `code` | `TEXT` | 1..20 alphanumeric uppercase | Required |
| `timezone` | `TEXT` | Must match valid IANA identifier in `pg_timezone_names` | `'Asia/Jerusalem'` |
| `locale` | `TEXT` | Supported: `'he'` (Hebrew RTL), `'en'` (English LTR) | `'he'` |
| `week_start` | `INTEGER` | `0` (Sunday) or `1` (Monday) | `0` |
| `late_grace_minutes` | `INTEGER` | `0` to `120` minutes | `5` |
| `check_in_early_minutes` | `INTEGER` | `0` to `120` minutes | `15` |
| `is_active` | `BOOLEAN` | Station operational toggle | `true` |
| `force_deactivate` | `BOOLEAN` | Override flag for open sessions | `false` |
| `deactivation_reason` | `TEXT` | Mandatory $\ge 10$ chars when `force_deactivate = true` | `NULL` |

---

## 3. Server-Side IANA Timezone Validation

To prevent scheduling corruptions and miscalculated worked hours, station timezones are strictly validated against PostgreSQL's internal `pg_timezone_names`:

```sql
IF NOT EXISTS (SELECT 1 FROM pg_timezone_names WHERE name = p_timezone) THEN
    RAISE EXCEPTION 'Invalid IANA timezone identifier: %', p_timezone 
    USING ERRCODE = '22000';
END IF;
```

---

## 4. Safe Station Deactivation Safeguards (`P0082`)

When a station administrator attempts to pause or deactivate a station (`is_active = false`):

1. **Active Attendance Inspection**: The RPC checks if any employee sessions are currently active (`check_out_time IS NULL`) for that station.
2. **Fail-Closed Block (`P0082`)**: If active sessions exist and `p_force_deactivate` is false, the database raises:
   ```sql
   RAISE EXCEPTION 'Cannot deactivate station while active attendance sessions exist'
   USING ERRCODE = 'P0082';
   ```
3. **Mandatory Deactivation Reason**: If `force_deactivate = true`, the administrator MUST provide a non-empty `deactivation_reason` of at least **10 characters**, otherwise rejected with error code `22000`.
4. **Dedicated Audit Event**: Force deactivation automatically emits a `STATION_FORCE_DEACTIVATED` audit log containing the active session count and mandatory override explanation.
5. **Zero Historical Deletion**: Deactivating a station never deletes employee memberships, shifts, corrections, or attendance records.

---

## 5. Employee CRUD & Last-Admin Invariant Protection

1. **E.164 Phone Normalization**: `public.normalize_phone_number(TEXT)` standardizes local Israeli formats (`050-123-4567`), international strings (`+972 50...`), and US formats into E.164 standard representation.
2. **Last-Admin Invariant (`P0001`)**: Table trigger `prevent_last_admin_demotion` ensures that a station's last active Administrator cannot be demoted, deleted, or marked `INACTIVE`.
3. **Secure Email Resolution**: Station admins can view employee emails retrieved securely from `auth.users` via SECURITY DEFINER function `admin_get_station_members`.

---

## 6. Real-Time Station Telemetry (`get_station_system_health`)

Station administrators have access to dedicated station health telemetry:
- **Kiosk Fleet Status**: Total registered kiosks, active kiosks, and last heartbeat timestamps.
- **Export Queue Metrics**: Total exports requested in 24h, pending jobs, processing counts, completed exports, and failed jobs.
- **Tenant Scoping**: Foreign station administrators cannot query telemetry for other stations (`42501`).
