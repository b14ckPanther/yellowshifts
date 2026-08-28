# YellowShifts — Production Data Retention & Lifecycle Policy

## 1. Permanent Historical Records Policy

Under no circumstances may automated cleanup or maintenance processes delete:

1. **Attendance History**: `public.attendance_records` records are permanent operational records for workforce attendance auditing.
2. **Attendance Corrections**: `public.attendance_corrections` preserves permanent immutable ledger trails of all manager/admin manual adjustments.
3. **Audit Trail**: `public.audit_logs` entries are immutable and permanent. Direct `UPDATE` and `DELETE` queries are forbidden by RLS and database triggers.
4. **Historical Published Schedules**: `public.work_schedules` and `public.work_schedule_shifts` in `PUBLISHED` state are preserved permanently for historical schedule compliance.

---

## 2. Disposable / Transient Artifacts Lifecycle

| Data Type | Table | Retention Duration | Automated Cleanup Mechanism |
| :--- | :--- | :--- | :--- |
| **Kiosk Dynamic QR Challenges** | `public.kiosk_qr_challenges` | 30 seconds validity (retained 24h for audit replay check) | Soft-expiry after 30 seconds; purge challenges older than 7 days. |
| **Generated Report Exports** | `public.report_exports` & Storage files | 24 hours | Marked `EXPIRED` after 24h; physical file deleted from Supabase Storage `reports` bucket. |
| **Notification Delivery Jobs** | `public.notification_delivery_jobs` | Retained 30 days post-delivery | Pruned after 30 days if status is `DELIVERED` or `FAILED_MAX_RETRIES`. |
| **Expired Verification Tokens** | `public.identity_verification_attempts` | 90 days | Pruned after 90 days; summary result preserved in attendance log. |
