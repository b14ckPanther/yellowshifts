# YellowShifts — Schedule Publishing & Revision Governance

## 1. Publish Pre-Flight Lifecycle

A Work Schedule begins in `DRAFT` status and undergoes rigorous automated validation prior to publication.

```
       [ DRAFT (Version 1) ]
                 │
                 ▼
     validate_work_schedule()
     ├── Hard Conflicts (0 required)
     └── Staffing & Override Warnings
                 │
                 ├── (Hard Conflicts > 0) ──> Blocked (PUBLISH_VALIDATION_FAILED)
                 │
                 ├── (Warnings > 0 && confirm_warnings == false) ──> Prompt Confirmation
                 │
                 ▼
      publish_work_schedule(confirm_warnings == true)
                 │
                 ├── Atomically sets status = 'PUBLISHED'
                 ├── Sets published_at = now(), published_by = auth.uid()
                 ├── Increments version
                 └── Emits audit log WORK_SCHEDULE_PUBLISHED
                 │
                 ▼
       [ PUBLISHED (Official) ]
```

---

## 2. Post-Publish Controlled Revisions

Once a schedule is `PUBLISHED`, it represents the legally and operationally binding workforce schedule for the station.

Direct or silent modifications are strictly blocked:
1. Every subsequent assignment creation, move, removal, or staffing adjustment requires a non-empty `change_reason` (minimum 3 trimmed characters).
2. The mutation increments `work_schedules.version`.
3. An immutable entry is appended to `public.work_schedule_changes` recording `version_before`, `version_after`, `change_type`, `actor_id`, `reason`, and `metadata`.
4. Original `published_at` and `published_by` timestamps remain permanently intact.

---

## 3. Employee Visibility Transitions

- **DRAFT Status**: Strictly invisible to standard employees via Row Level Security. Querying `shift_assignments` or `work_schedules` returns 0 rows.
- **PUBLISHED Status**: Employees immediately gain read access to their own assignments (`user_id = auth.uid()`) via the `get_my_shifts` RPC and Supabase Realtime channel subscriptions.
