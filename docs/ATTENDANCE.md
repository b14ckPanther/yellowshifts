# YellowShifts — Phase 4: Live Attendance Architecture & Specification

## 1. Overview
The YellowShifts Attendance Subsystem provides a server-authoritative, cryptographic presence verification framework connecting station tablet kiosks, mobile employee scanners, and manager operational dashboards.

Attendance builds directly upon Phase 3 published shift schedules, freezing schedule metadata at check-in time to ensure historical integrity against subsequent schedule revisions.

---

## 2. Core Invariants

### 2.1 Single Open Session Globally per Employee
An employee can only have **at most ONE active (open) attendance session across the entire platform at any given moment**, regardless of station count or membership assignments.
- **Database Enforcement**: Partial unique index on `public.attendance_records`:
  ```sql
  CREATE UNIQUE INDEX uq_attendance_single_open_session 
  ON public.attendance_records(employee_user_id) 
  WHERE check_out_time IS NULL;
  ```
- **Error Code**: `P0023` (*"Employee already has an open attendance session"*).

### 2.2 Server-Authoritative Elapsed Duration
Worked time is strictly calculated by the database engine as real UTC elapsed duration between `check_in_time` and `check_out_time` instants:
$$\text{worked\_minutes} = \left\lfloor \frac{\text{check\_out\_time} - \text{check\_in\_time}}{60} \right\rfloor$$
- Immune to client device clock tampering, time zone changes, and DST transitions (tested across Spring 23:00 $\to$ 07:00 7-hour and Fall 23:00 $\to$ 07:00 9-hour transitions).
- Zero arbitrary 8/10/12-hour caps applied.

### 2.3 Station Check-In Window & Lateness Grace
- **Early Check-In Window**: Configured per station (`stations.check_in_early_minutes`, default `60` min).
  $$\text{starts\_at} - \text{early\_minutes} \le \text{now}() < \text{ends\_at}$$
- **Lateness Grace**: Configured per station (`stations.late_grace_minutes`, default `5` min).
  $$\text{late\_minutes} = \max\left(0, \left\lfloor \frac{\text{check\_in\_time} - (\text{starts\_at} + \text{late\_grace\_minutes})}{60} \right\rfloor\right)$$

### 2.4 Immutable Schedule Snapshot Preservation
At the exact moment of check-in, the shift name, scheduled start/end instants, and schedule version are permanently frozen into `attendance_records`:
- `shift_name_snapshot`
- `scheduled_start_at_snapshot`
- `scheduled_end_at_snapshot`
- `schedule_version_at_check_in`
If a manager subsequently modifies or unpublishes the published schedule, existing attendance records remain untouched.

### 2.5 Multi-Station Isolation
Foreign station QR tokens or check-in attempts are rejected with standard `42501` access denied or `P0023` lockout without leaking station names or shift details.

---

## 3. Database Schema

### 3.1 `attendance_records`
| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | `UUID PK` | Record unique identifier |
| `station_id` | `UUID FK` | Target station |
| `employee_user_id` | `UUID FK` | Global profile id of the employee |
| `station_membership_id` | `UUID FK` | Station membership id |
| `work_schedule_shift_id` | `UUID NULL FK` | Optional link to scheduled shift |
| `shift_name_snapshot` | `TEXT NULL` | Frozen shift name |
| `scheduled_start_at_snapshot`| `TIMESTAMPTZ NULL` | Frozen scheduled start |
| `scheduled_end_at_snapshot` | `TIMESTAMPTZ NULL` | Frozen scheduled end |
| `schedule_version_at_check_in` | `INTEGER NULL` | Frozen schedule version |
| `check_in_time` | `TIMESTAMPTZ` | Authoritative check-in instant |
| `check_out_time` | `TIMESTAMPTZ NULL` | Authoritative check-out instant (NULL = OPEN) |
| `worked_minutes` | `INTEGER NULL` | Real UTC worked minutes |
| `late_minutes` | `INTEGER` | Computed late minutes |
| `status` | `attendance_status` | `OPEN`, `COMPLETED`, `CORRECTED` |
| `verification_method` | `attendance_verification_method` | `QR_ONLY`, `QR_PLUS_IDENTITY`, `MANUAL_ADMIN` |
| `check_in_kiosk_device_id` | `UUID FK` | Originating check-in kiosk |
| `check_out_kiosk_device_id`| `UUID NULL FK`| Originating check-out kiosk |

### 3.2 `attendance_corrections`
Immutable audit ledger tracking every manual change made by station administrators:
- `attendance_record_id`
- `corrected_by`
- `previous_check_in`, `previous_check_out`, `previous_worked_minutes`
- `new_check_in`, `new_check_out`, `new_worked_minutes`
- `reason` (minimum 3 characters, mandatory)

---

## 4. Operational RPCs

1. `scan_attendance_qr(p_qr_token_or_code TEXT) -> JSONB`
   - Validates active kiosk challenge (30s TTL).
   - Verifies caller station membership.
   - Matches next open/scheduled shift or active open session.
   - Issues single-use `presence_proof_token` (60s TTL).
2. `check_in_with_presence_proof(p_presence_proof_token TEXT) -> JSONB`
   - Consumes proof token atomically.
   - Enforces single open session invariant.
   - Calculates lateness and creates `attendance_records` row.
3. `check_out_with_presence_proof(p_presence_proof_token TEXT) -> JSONB`
   - Consumes proof token atomically.
   - Closes open session at caller's station.
   - Computes elapsed worked minutes.
4. `get_manager_live_attendance(p_station_id UUID, p_target_date DATE) -> JSONB`
   - Realtime operational summary containing KPI pills and shift roster.
5. `correct_attendance_record(...) -> JSONB`
   - Admin-only correction with interval validation and audit logging.
