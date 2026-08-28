# YellowShifts — Notification Event Catalog

Complete catalog of all domain notification events implemented in Phase 6, documenting producers, recipients, priority, deduplication, deep actions, and privacy classifications.

| Event Code | Producer | Recipient(s) | Category | Priority | Mandatory | Deduplication Key Pattern | Deep Action | Privacy Classification |
|---|---|---|---|---|---|---|---|---|
| `SCHEDULE_PUBLISHED` | `publish_work_schedule()` | Assigned station employees | `SCHEDULE` | `NORMAL` | No | `schedule-published:{schedule_id}:{v}:{emp_id}` | `NAVIGATE_SCHEDULE` | Standard operational |
| `SCHEDULE_REVISED` | `publish_work_schedule()` | Materially modified employees | `SCHEDULE` | `HIGH` | No | `schedule-revised:{schedule_id}:{v}:{emp_id}` | `NAVIGATE_SCHEDULE` | Standard operational |
| `SHIFT_ASSIGNED` | Schedule Manager RPC | Assigned employee | `SCHEDULE` | `NORMAL` | No | `shift-assigned:{shift_id}:{emp_id}` | `NAVIGATE_SCHEDULE` | Standard operational |
| `SHIFT_CHANGED` | Schedule Manager RPC | Affected employee | `SCHEDULE` | `HIGH` | No | `shift-changed:{shift_id}:{emp_id}` | `NAVIGATE_SCHEDULE` | Standard operational |
| `SHIFT_REMOVED` | Schedule Manager RPC | Removed employee | `SCHEDULE` | `HIGH` | No | `shift-removed:{shift_id}:{emp_id}` | `NAVIGATE_SCHEDULE` | Standard operational |
| `SCHEDULE_PUBLICATION_COMPLETED` | `publish_work_schedule()` | Publishing manager | `SCHEDULE` | `LOW` | No | `schedule-pub-ack:{schedule_id}:{v}` | `NAVIGATE_SCHEDULE` | Internal admin |
| `AVAILABILITY_SUBMISSION_REMINDER` | `generate_due_notification_reminders()` | Employees with unsubmitted availability | `AVAILABILITY` | `NORMAL` | No | `avail-remind:{period_id}:{emp_id}` | `NAVIGATE_AVAILABILITY` | Standard operational |
| `AVAILABILITY_DEADLINE_APPROACHING` | `generate_due_notification_reminders()` | Employees with unsubmitted availability (<=24h) | `AVAILABILITY` | `HIGH` | No | `avail-deadline:{period_id}:{emp_id}` | `NAVIGATE_AVAILABILITY` | Standard operational |
| `AVAILABILITY_SUBMITTED_CONFIRMATION` | `submit_availability()` | Submitting employee | `AVAILABILITY` | `LOW` | No | `avail-submit:{period_id}:{emp_id}` | `NAVIGATE_AVAILABILITY` | Internal confirm |
| `AVAILABILITY_MISSING_EMPLOYEES` | `generate_due_notification_reminders()` | Station managers / admins | `AVAILABILITY` | `HIGH` | No | `avail-missing:{period_id}:{st_id}` | `NAVIGATE_AVAILABILITY` | Internal management |
| `EMPLOYEE_CHECKED_IN` | `check_in_with_presence_proof()` | Station managers / admins | `ATTENDANCE` | `NORMAL` | No | `attendance-check-in:{rec_id}:{mgr_id}` | `NAVIGATE_ATTENDANCE` | Operational presence |
| `CHECK_IN_CONFIRMED` | `check_in_with_presence_proof()` | Checking-in employee | `ATTENDANCE` | `LOW` | No | `attendance-check-in-self:{rec_id}` | `NAVIGATE_ATTENDANCE` | Internal confirm |
| `EMPLOYEE_CHECKED_OUT` | `check_out_with_presence_proof()` | Station managers / admins | `ATTENDANCE` | `NORMAL` | No | `attendance-check-out:{rec_id}:{mins}:{mgr_id}` | `NAVIGATE_ATTENDANCE` | Operational presence |
| `CHECK_OUT_CONFIRMED` | `check_out_with_presence_proof()` | Checking-out employee | `ATTENDANCE` | `LOW` | No | `attendance-check-out-self:{rec_id}` | `NAVIGATE_ATTENDANCE` | Internal confirm |
| `EMPLOYEE_LATE` | `check_in_with_presence_proof()` | Station managers / admins | `ATTENDANCE` | `HIGH` | No | `attendance-late:{rec_id}:{mgr_id}` | `NAVIGATE_ATTENDANCE` | Operational exception |
| `EMPLOYEE_MISSED_CHECK_IN` | `generate_due_notification_reminders()` | Station managers / admins | `ATTENDANCE` | `HIGH` | No | `missed-check-in:{shift_id}:{mgr_id}` | `NAVIGATE_ATTENDANCE` | Operational exception |
| `ATTENDANCE_MANUALLY_CORRECTED` | `correct_attendance_record()` | Affected employee & station admin | `ATTENDANCE` | `HIGH` | **Yes (Mandatory)** | `attendance-corrected:{rec_id}:{corr_id}` | `NAVIGATE_ATTENDANCE` | Compliance audit |
| `KIOSK_OFFLINE` | `evaluate_kiosk_health_state()` | Station managers / admins | `OPERATIONS` | `HIGH` | No | `kiosk-offline:{kiosk_id}:{offline_ts}` | `NAVIGATE_KIOSK` | Operational health |
| `KIOSK_RECOVERED` | `evaluate_kiosk_health_state()` | Station managers / admins | `OPERATIONS` | `NORMAL` | No | `kiosk-online:{kiosk_id}:{online_ts}` | `NAVIGATE_KIOSK` | Operational health |
| `IDENTITY_ENROLLMENT_REQUIRED` | Identity Policy Change | Station employees | `IDENTITY` | `HIGH` | No | `identity-enroll-req:{policy_id}:{emp_id}` | `NAVIGATE_IDENTITY` | Security requirement |
| `IDENTITY_ENROLLMENT_COMPLETED` | Identity Enrollment Flow | Enrolled employee | `IDENTITY` | `LOW` | No | `identity-enrolled:{profile_id}` | `NAVIGATE_IDENTITY` | Privacy confirmation |
| `IDENTITY_PROFILE_REVOKED` | `revoke_my_identity_profile()` | Revoking employee & station admin | `IDENTITY` | `HIGH` | **Yes (Mandatory)** | `identity-revoked:{profile_id}` | `NAVIGATE_IDENTITY` | Security event |
| `IDENTITY_VERIFICATION_EXCEPTION` | Attendance Verification Flow | Station managers / admins | `IDENTITY` | `HIGH` | No | `identity-exception:{attempt_id}:{mgr_id}` | `NAVIGATE_IDENTITY` | Security exception |
| `IDENTITY_ADMIN_OVERRIDE_USED` | `create_identity_admin_override()` | Station admins & affected employee | `IDENTITY` | `CRITICAL` | **Yes (Mandatory)** | `identity-override:{proof_id}:{recip_id}` | `NAVIGATE_IDENTITY` | Critical compliance |

---

## Data Minimization & Privacy Rules

1. **No Media Payloads**: Biometric images, vector embeddings, facial metrics, or video frames are never stored or referenced in notification tables.
2. **No Secret Tokens**: Ephemeral QR challenge tokens, presence proof signatures, and identity proof tokens are strictly excluded from event payloads.
3. **Public Lock-Screen Minimization**: Render payloads are sanitized so that external lock screen push notifications display generic operational summaries without disclosing private identity exception details.
