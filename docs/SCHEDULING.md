# YellowShifts — Shift Scheduling Architecture & Domain Guide

## 1. Domain Overview

The YellowShifts Scheduling Domain powers the station workforce scheduling lifecycle. It strictly consumes frozen shift template snapshots from Phase 2 availability periods (`availability_period_shift_templates`) and authoritative submitted availability from `availability_submissions` and `availability_entries`.

```
Phase 2 Availability Period (Frozen Shift Templates + Final Submissions)
                            │
                            ▼
      Work Schedule (DRAFT, Version 1)
      ├── 7 Operational Dates x Frozen Period Templates
      ├── Shift Instants: [starts_at, ends_at) in Station Timezone
      └── Required Staffing Counts
                            │
                            ▼
      Shift Assignments (Atomic OCC + Profile Lock)
      ├── Finalized Availability State Check (AVAILABLE / UNAVAILABLE / NOT_SUBMITTED)
      ├── Global Intra-Station & Cross-Station Overlap Defense
      └── Explicit Override Reason Governance
                            │
                            ▼
      Publish Pre-Flight Validation
      ├── Hard Errors (Inactive Memberships, Overlapping Assignments)
      └── Staffing Warnings & Availability Drift Confirmation
                            │
                            ▼
      Work Schedule (PUBLISHED, Version N)
      ├── Invisible to Employees during DRAFT
      ├── Synchronized in Realtime via Supabase Realtime
      └── Post-Publish Changes require Change Reason -> work_schedule_changes
```

---

## 2. Core Entities

### `work_schedules`
Represents the weekly official or draft schedule for a station.
- `id` (UUID, Primary Key)
- `station_id` (UUID, Foreign Key to `stations`)
- `availability_period_id` (UUID, Unique Foreign Key to `availability_periods`)
- `week_start_date` (DATE)
- `status` (`DRAFT`, `PUBLISHED`, `ARCHIVED`)
- `version` (INTEGER, Optimistic Concurrency Control counter)
- `created_by`, `published_by`, `published_at`

### `work_schedule_shifts`
Represents an individual operational shift on a specific calendar date.
- `id` (UUID, Primary Key)
- `work_schedule_id` (UUID, Foreign Key)
- `operational_date` (DATE)
- `period_shift_template_id` (UUID, Foreign Key to frozen snapshot)
- `shift_name_snapshot`, `shift_code_snapshot` (TEXT)
- `start_time_snapshot`, `end_time_snapshot` (TIME)
- `starts_at`, `ends_at` (TIMESTAMPTZ, calculated in station timezone)
- `required_staff_count` (INTEGER >= 0)
- `sort_order` (INTEGER)

### `shift_assignments`
Represents the assignment of a station member to a scheduled shift.
- `id` (UUID, Primary Key)
- `work_schedule_shift_id` (UUID, Foreign Key)
- `station_id` (UUID, Foreign Key)
- `membership_id` (UUID, Foreign Key to `station_memberships`)
- `user_id` (UUID, Foreign Key to global `profiles`)
- `availability_state_snapshot` (`AVAILABLE`, `UNAVAILABLE`, `NOT_SUBMITTED`)
- `availability_override` (BOOLEAN)
- `availability_override_reason` (TEXT, required if override is true)
- `assigned_by` (UUID)

### `work_schedule_changes`
Immutable audit ledger for post-publish schedule adjustments.
- `id` (UUID, Primary Key)
- `work_schedule_id` (UUID, Foreign Key)
- `version_before`, `version_after` (INTEGER)
- `change_type` (`ASSIGNMENT_ADDED`, `ASSIGNMENT_REMOVED`, `ASSIGNMENT_MOVED`, `STAFFING_UPDATED`, `PUBLISHED`)
- `actor_id` (UUID)
- `reason` (TEXT, minimum 3 trimmed characters)
- `metadata` (JSONB)

---

## 3. Timezone & Cross-Midnight Calculation

For each shift generated from the frozen template on `operational_date`:
1. `starts_at = timezone(station_timezone, (operational_date + start_time)::timestamp)`
2. If `start_time < end_time` (daytime shift):
   `ends_at = timezone(station_timezone, (operational_date + end_time)::timestamp)`
3. If `start_time >= end_time` (cross-midnight shift ending next day):
   `ends_at = timezone(station_timezone, ((operational_date + 1) + end_time)::timestamp)`

Shifts are evaluated as **half-open intervals** `[starts_at, ends_at)`. Two shifts `S1` and `S2` overlap if and only if:
$$\text{starts\_at}_1 < \text{ends\_at}_2 \quad \text{AND} \quad \text{starts\_at}_2 < \text{ends\_at}_1$$
Adjacent shifts (e.g. 07:00–15:00 and 15:00–23:00) share an exact boundary and do **not** overlap.
