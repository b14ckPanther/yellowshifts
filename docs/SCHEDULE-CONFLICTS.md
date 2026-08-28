# YellowShifts — Schedule Conflict Detection & Concurrency Control

## 1. Validation Model

YellowShifts enforces a strict distinction between **Hard Conflicts** (which block database writes or schedule publishing) and **Operational Warnings** (which can be overridden with reason and explicit manager confirmation).

| Classification | Condition | Policy / Resolution |
| :--- | :--- | :--- |
| **Hard Conflict** | Overlapping Shifts (Same Station) | Blocked in SQL (`OVERLAPPING_ASSIGNMENT`) |
| **Hard Conflict** | Cross-Station Overlap (Multi-Station User) | Blocked in SQL (`CROSS_STATION_OVERLAP`) with sanitized privacy |
| **Hard Conflict** | Inactive or Suspended Membership | Blocked in SQL (`INACTIVE_MEMBERSHIP`) |
| **Hard Conflict** | Duplicate Assignment to Same Shift | Blocked in SQL (`uq_shift_assignments_membership`) |
| **Hard Conflict** | OCC Version Mismatch | Blocked in SQL (`SCHEDULE_VERSION_CONFLICT`) |
| **Operational Warning** | Employee Marked `UNAVAILABLE` | Allowed only with `override=true` and `override_reason` |
| **Operational Warning** | Employee `NOT_SUBMITTED` | Allowed only with `override=true` and `override_reason` |
| **Operational Warning** | Understaffed Shift (`assigned < required`) | Flagged during validation; requires `confirm_warnings=true` at publish |
| **Operational Warning** | Overstaffed Shift (`assigned > required`) | Flagged during validation; allowed for operational flex |
| **Operational Warning** | Availability Drift | Employee was available when assigned, but resubmitted unavailable |

---

## 2. Multi-Station Overlap Defense & Privacy

An employee user `U` can belong to multiple stations (e.g. Station A in Kurdani and Station B in Haifa).

When Station A attempts to assign `U` to Shift $S_A$:
1. A database row lock is taken on `public.profiles WHERE id = U FOR UPDATE`.
2. A cross-station interval query checks all active assignments across **all stations**:
   ```sql
   SELECT other_wss.station_id, other_wss.starts_at, other_wss.ends_at
   FROM public.shift_assignments other_sa
   JOIN public.work_schedule_shifts other_wss ON other_sa.work_schedule_shift_id = other_wss.id
   WHERE other_sa.user_id = v_user_id
     AND other_wss.starts_at < v_shift.ends_at
     AND v_shift.starts_at < other_wss.ends_at;
   ```
3. If an overlap is detected at a foreign station:
   - The transaction aborts with error code `P0009` (`CROSS_STATION_OVERLAP`).
   - The error message is sanitized so Station A managers learn only that the employee is scheduled elsewhere during the time window, preventing unauthorized leakage of foreign station rosters.

---

## 3. Optimistic Concurrency Control (OCC)

Every schedule mutation RPC (`assign_employee_to_shift`, `remove_shift_assignment`, `move_shift_assignment`, `update_schedule_shift_staffing`, `publish_work_schedule`) accepts `p_expected_version`.

The version check and increment occur atomically inside PostgreSQL:
```sql
UPDATE public.work_schedules
SET version = version + 1, updated_at = timezone('utc'::text, now())
WHERE id = v_schedule_id AND version = p_expected_version
RETURNING version INTO v_new_version;

IF NOT FOUND THEN
    RAISE EXCEPTION 'Schedule version conflict: expected version %, but current version has changed', p_expected_version
        USING ERRCODE = 'P0005';
END IF;
```
If two managers attempt simultaneous mutations, one transaction commits and increments the version; the second transaction fails with `P0005` (`SCHEDULE_VERSION_CONFLICT`), prompting the client to refetch the fresh schedule state.
