# YellowShifts — Worked Hours Analytics, Reporting & Operational Insights (Phase 7)

## 1. Architectural Overview & Invariant Rules

Phase 7 introduces the server-authoritative operational reporting, worked hours analytics, and manager operational insight layer for the YellowShifts multi-station platform.

### Strict Core Invariants

1. **Absolute Zero Payroll Principle**:
   - The platform tracks strictly **operational time** (minutes, hours, shifts, check-in/out timestamps, late minutes, lateness frequency, correction counts, and roster coverage).
   - YellowShifts has **NO payroll fields, NO wages, NO currency symbols (`₪`, `$`, `€`), NO overtime rate multipliers (125%, 150%), NO tax computations, and NO pay slip generation**.
   - All reporting is exclusively designed for operational planning, schedule verification, attendance compliance, and labor management.

2. **Authoritative Attendance Source of Truth**:
   - The source of truth for completed duration is strictly `public.attendance_records` where:
     $$\text{check\_in\_time IS NOT NULL} \land \text{check\_out\_time IS NOT NULL} \land \text{worked\_minutes IS NOT NULL} \land \text{worked\_minutes} \ge 0$$
   - Durations are **NEVER recalculated** from shift template start/end hours or schedule estimates.
   - Corrupt negative durations (`worked_minutes < 0`) are strictly filtered out by the server aggregation pipeline.

3. **Multi-Station Tenant Isolation**:
   - Station managers and admins can only view analytics and employee breakdowns for stations where they hold an active membership with manager permissions (`reports.team.read` or `reports.station.read`).
   - Cross-station queries by unauthorized actors are strictly denied by PostgreSQL security barriers with SQL error code `42501`.
   - Employees querying their own attendance history (`get_my_attendance_summary`, `get_my_attendance_history`) receive their global attendance record across all stations or can filter by specific station ID.

4. **Active Open Session Isolation & Handling**:
   - Open sessions (`check_out_time IS NULL`) do **NOT** count toward completed worked minutes or completed shifts.
   - Active open sessions are reported with server-calculated elapsed time from check-in to current time.
   - If an open session has elapsed $> 16\text{ hours}$ (960 minutes), the server flags `needs_attention = true` without truncating or forcing checkout.

5. **Historical Snapshot Integrity**:
   - Analytics rely on immutable snapshot fields frozen in `attendance_records` (`shift_name_snapshot`, `scheduled_start_at_snapshot`, `scheduled_end_at_snapshot`).
   - Inactive, suspended, or transferred employees remain completely reportable across historical date ranges to preserve auditable records.

6. **Repeated Lateness Pattern Signal**:
   - An employee is flagged with `has_repeated_lateness = true` when they accumulate **3 or more late shifts** within the selected reporting period.

---

## 2. Server-Authoritative RPC Engine

All reporting endpoints are implemented as PostgreSQL `SECURITY DEFINER` functions with fixed `search_path = public, pg_temp` to prevent search path hijacking.

### 2.1 `public.get_my_attendance_summary`
Returns personal attendance metrics for the authenticated employee.

```sql
SELECT public.get_my_attendance_summary(
    p_from => '2026-08-01'::DATE,
    p_to => '2026-08-31'::DATE,
    p_station_id => '99999999-8888-7777-6666-555555555555'::UUID -- Optional
);
```

**Response Payload**:
```json
{
  "success": true,
  "from_date": "2026-08-01",
  "to_date": "2026-08-31",
  "station_id": null,
  "total_worked_minutes": 9600,
  "completed_shifts": 20,
  "late_shifts": 1,
  "total_late_minutes": 15,
  "corrected_records": 2,
  "open_session_count": 0,
  "stations_worked_count": 2,
  "first_shift_date": "2026-08-01",
  "last_shift_date": "2026-08-25",
  "active_open_session": null
}
```

### 2.2 `public.get_my_attendance_history`
Returns paginated, filterable shift history for the authenticated employee.

```sql
SELECT public.get_my_attendance_history(
    p_from => '2026-08-01'::DATE,
    p_to => '2026-08-31'::DATE,
    p_station_id => null,
    p_status_filter => 'ALL', -- 'ALL', 'COMPLETED', 'LATE', 'CORRECTED', 'OPEN'
    p_limit => 25,
    p_offset => 0
);
```

### 2.3 `public.get_station_attendance_summary`
Returns executive station-wide KPIs for authorized station managers and admins.

```sql
SELECT public.get_station_attendance_summary(
    p_station_id => '99999999-8888-7777-6666-555555555555'::UUID,
    p_from => '2026-08-01'::DATE,
    p_to => '2026-08-31'::DATE
);
```

**Response Payload**:
```json
{
  "success": true,
  "station_id": "99999999-8888-7777-6666-555555555555",
  "station_name": "תחנת יילו כורדני",
  "from_date": "2026-08-01",
  "to_date": "2026-08-31",
  "total_worked_minutes": 48000,
  "completed_shifts": 100,
  "late_shifts": 6,
  "total_late_minutes": 75,
  "corrected_records": 5,
  "open_sessions": 2,
  "employees_with_attendance_count": 12,
  "active_employees_count": 14,
  "repeated_lateness_employee_count": 1
}
```

### 2.4 `public.get_station_employee_attendance_summary`
Returns paginated, searchable, sortable per-employee operational breakdown for a station.

- **Sorting keys**: `name`, `employee_code`, `worked_minutes`, `completed_shifts`, `late_shifts`, `corrected_records`.
- **Search**: Sanitized prefix and substring matching on first name, last name, and employee code.

### 2.5 `public.get_station_daily_attendance_report`
Returns operational daily shift board for a target date, aggregating:
- Day summary (total worked minutes, completed shifts, late shifts, active open sessions, walk-in count).
- Scheduled shifts with staffing requirement vs assigned vs checked-in vs completed vs open vs late count, along with employee roster.
- Unscheduled walk-in attendance list.

### 2.6 `public.get_station_employee_attendance_detail`
Provides single-employee drilldown with complete attendance records and full chronological correction ledger (recording supervisor actor name, previous vs new duration, and justification reason).

---

## 3. Database Indexes & Performance

To guarantee sub-300ms execution at scale (benchmarked at **12.1ms** for 100 employees and 5,000+ records), Migration 011 added 7 composite and partial indexes:

```sql
CREATE INDEX idx_attendance_records_station_op_date_status
    ON public.attendance_records (station_id, operational_date, status);

CREATE INDEX idx_attendance_records_user_op_date
    ON public.attendance_records (user_id, operational_date DESC);

CREATE INDEX idx_attendance_records_station_user_op_date
    ON public.attendance_records (station_id, user_id, operational_date DESC);

CREATE INDEX idx_attendance_records_open_sessions
    ON public.attendance_records (station_id, user_id)
    WHERE check_out_time IS NULL;

CREATE INDEX idx_attendance_records_status_late
    ON public.attendance_records (station_id, is_late)
    WHERE is_late = true;

CREATE INDEX idx_attendance_records_shift_id
    ON public.attendance_records (work_schedule_shift_id)
    WHERE work_schedule_shift_id IS NOT NULL;

CREATE INDEX idx_attendance_corrections_record_id_created
    ON public.attendance_corrections (attendance_record_id, created_at DESC);
```

---

## 4. Mathematical Invariants & Verification

The reporting engine enforces the following exact mathematical invariants:

1. **Station Total Conservation**:
   $$\text{Station Total Worked Minutes} = \sum_{i=1}^{N} \text{Employee}_i\text{ Total Worked Minutes}$$
   $$\text{Station Completed Shifts} = \sum_{i=1}^{N} \text{Employee}_i\text{ Completed Shifts}$$
   $$\text{Station Late Shifts} = \sum_{i=1}^{N} \text{Employee}_i\text{ Late Shifts}$$
   $$\text{Station Late Minutes} = \sum_{i=1}^{N} \text{Employee}_i\text{ Late Minutes}$$

2. **Correction Dedup Invariant**:
   Multiple corrections applied to a single attendance record are counted as exactly **1 corrected attendance record** in summary metrics, preventing row multiplication from `LEFT JOIN` operations.

3. **Jerusalem DST Timezone Integrity**:
   Shifts crossing daylight saving transitions (Spring 23-hour day and Autumn 25-hour day) calculate exact elapsed minute durations (420m and 540m respectively) via authoritative UTC epoch difference.
