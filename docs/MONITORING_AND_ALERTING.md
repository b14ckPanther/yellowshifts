# YellowShifts — Production Monitoring, Observability & Alerting Guide

## 1. Observability Model

Production observability in YellowShifts relies on structured database telemetry, station-scoped health aggregations, and fail-closed audit logging:

1. **Platform Compatibility & Status**:
   - RPC: `public.get_platform_schema_version()`
   - Returns platform health, schema version, and minimum client version.
2. **Station Operational Health Telemetry**:
   - RPC: `public.get_station_system_health(station_id UUID)`
   - Accessible strictly by active station administrators.
   - Aggregates:
     - Kiosks: Total, online, offline (heartbeat threshold: 2 minutes).
     - Exports: 24-hour total, pending, and failed export counts.
     - Attendance: Stale open sessions (>16 hours).
     - Identity: Verification failure counts (24-hour).
     - Notifications: Pending outbox queue depth.
     - Storage: Reports bucket accessibility.
3. **Audit Trail**:
   - Table: `public.audit_logs`
   - Records all administrative mutations, logins, check-ins, status transitions, and automated system maintenance executions.

---

## 2. Operational Alerting Matrix

| Alert Condition | Severity | Trigger Threshold | Operator Action | Escalation Guidance |
| :--- | :---: | :--- | :--- | :--- |
| **All Station Kiosks Offline** | **P1 (Critical)** | Station has > 0 kiosks and online kiosk count = 0 for > 5 minutes | Contact station shift manager; verify kiosk hardware power and Wi-Fi connectivity. | If network outage at station, advise manual attendance fallback via admin attendance console. |
| **Stale Attendance Sessions Spike** | **P2 (High)** | > 5 open sessions older than 16 hours in a single station | Inspect Station Attendance Dashboard. Determine if employees forgot to check out. | Station Admin executes audited attendance close/correction. |
| **Stuck Export Jobs Detected** | **P2 (High)** | Report export status remains `PROCESSING` for > 30 minutes | Verify background maintenance job `recover_stuck_operational_jobs()` is running. | Review Edge Function `generate-report-export` logs for memory or timeout crashes. |
| **Notification Queue Backlog** | **P3 (Medium)** | Pending delivery jobs > 100 or lease timeouts > 10 in 1 hour | Verify Edge Function `process-notification-deliveries` is active. | Check external push/email provider credentials and quota limits. |
| **Client Schema Mismatch Mismatch** | **P2 (High)** | Client startup logs `CompatibilityStatus.clientUpdateRequired` | Verify latest Flutter Web bundle was published to CDN; clear browser cache if stale. | Instruct station staff to hard-refresh browser (Ctrl+F5 / Cmd+Shift+R). |
| **Last Admin Demotion Attempt** | **P3 (Medium)** | Audit log records `TRIGGER_REJECT_LAST_ADMIN` exception | Confirm if station reorganization is underway. | Ensure another administrator is provisioned before demoting remaining admin. |

---

## 3. Log Sanitization & PII Protection

No sensitive authentication tokens, database passwords, dynamic QR secrets, biometric facial embeddings, or FCM push credentials may ever be logged. All audit metadata and log outputs are automatically sanitized by Edge Function handlers and PostgreSQL triggers.
