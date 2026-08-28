# Data Lifecycle & Retention Policy Documentation

## 1. Overview & Non-Negotiable Invariants

YellowShifts maintains a strict separation between ephemeral operational artifacts and permanent attendance records:

> **CRITICAL INVARIANT**: Historical attendance records (`attendance_records`), corrections (`attendance_corrections`), scheduled shifts (`work_schedule_shifts`), and audit logs (`audit_logs`) are **PERMANENT** and must **NEVER** be deleted by automated lifecycle cleanups or administrative operations.

---

## 2. Ephemeral Artifacts vs. Permanent Records

| Data Entity | Retention Classification | Lifecycle Action |
|---|---|---|
| `report_exports` | Ephemeral (24h TTL) | Status marked as `'EXPIRED'` upon reaching `expires_at` (24h from creation). |
| `reports_storage` Artifacts (PDF/CSV) | Ephemeral (24h TTL) | Uploaded PDF/CSV artifacts purged from storage bucket after expiry. |
| `kiosk_qr_challenges` | Ephemeral (30s TTL) | Broadcast challenges purged after 1 hour. |
| `identity_verification_attempts` (Photos) | Ephemeral (30 days TTL) | Verification photo blobs purged after 30 days while verification metadata is preserved. |
| `attendance_records` | **PERMANENT** | **Never deleted**. Maintained indefinitely for operational and labor compliance. |
| `attendance_corrections` | **PERMANENT** | **Never deleted**. Immutable ledger tracking every manual check-in/out adjustment. |
| `audit_logs` | **PERMANENT** | **Never deleted**. Append-only with all DELETE privileges revoked. |
| `stations` & `station_memberships` | **PERMANENT** | Soft-deactivated via `status = 'INACTIVE'` or `is_active = false`. No cascade deletion. |

---

## 3. Automated Lifecycle Cleanup & Access Control

### 1. Global Platform Cleanup (`cleanup_expired_data`)
- **Execution Role**: Strictly restricted to `service_role` (cron worker / backend orchestrator). Revoked from `authenticated` and `anon` (`42501`).
- **Functionality**:
  - Updates `report_exports` to `status = 'EXPIRED'` where `expires_at <= now()`.
  - Cleans up stale QR challenges and ephemeral nonces older than 1 hour.
  - Logs `SYSTEM_DATA_RETENTION_EXECUTED` in `audit_logs`.
  - **Invariant Assertion**: Verified across test suites that `COUNT(attendance_records)` before and after cleanup is identical.

### 2. Tenant-Scoped Station Cleanup (`admin_cleanup_station_exports`)
- **Execution Role**: Granted to authenticated `ADMIN` users for their active station.
- **Functionality**:
  - Allows station administrators to manually purge expired export rows strictly belonging to their station (`station_id = p_station_id`).
  - Cross-station cleanup attempts are rejected fail-closed with `42501`.

### 3. Expired Export Generation Block (`P0081`)
- If an export is requested for download or processing after its `expires_at` timestamp has passed, the database raises error `P0081`:
  ```sql
  RAISE EXCEPTION 'Export has expired' USING ERRCODE = 'P0081';
  ```
