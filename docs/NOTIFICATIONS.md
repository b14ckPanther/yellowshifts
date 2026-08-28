# YellowShifts — Notifications, Operational Alerts & Transactional Outbox Architecture

## 1. Executive Summary & Core Philosophy

YellowShifts Phase 6 establishes a robust, multi-station notification and operational alerting infrastructure built on an **Authoritative Database Event & Transactional Outbox Pattern**.

### Core Tenets:
1. **Authoritative Server Invariants**: Business transactions (such as attendance check-ins, check-outs, schedule publishing, and identity overrides) atomically emit durable domain events.
2. **Decoupled Outbox Model**: Domain operations commit immediately without synchronous dependency on external messaging providers. Delivery failures never roll back core business state.
3. **Multi-Station Tenant Isolation**: Station managers receive alerts only for stations where they hold active management authority. Employees receive only their own inbox notices.
4. **Mandatory Compliance Guarantees**: Critical operational and security alerts (identity overrides, manual attendance corrections, security notices) cannot be suppressed by user channel preferences.
5. **Realtime Synchronization**: Client inboxes synchronize dynamically via Supabase Realtime Postgres change streams while preserving PostgreSQL as the authoritative single source of truth.

---

## 2. Architectural Pipeline

```
[ Domain Operation / RPC ]
           │
           ▼
[ notification_events ] ──(Trigger: emit_domain_notification_event)
           │
           ├─► Server-Side Recipient Resolution (Station boundaries, role permissions)
           ├─► Idempotency & Deduplication Engine (deduplication_key uniqueness)
           │
           ├─► [ public.notifications ] (User-facing in-app inbox & Realtime sync)
           │
           └─► Preference Evaluation ──► [ public.notification_delivery_jobs ] (Outbox queue)
                                                      │
                                                      ▼ (Worker: claim_notification_delivery_jobs)
                                         [ PUSH / EMAIL / SMS Providers ]
                                                      │
                                                      ▼ (record_delivery_attempt_outcome)
                                         [ public.notification_delivery_attempts ] (Audit ledger)
```

---

## 3. Database Schema

### 3.1 `notification_events`
Durable, immutable ledger of domain-level notification events.
- `id` (UUID PK): Event identifier.
- `station_id` (UUID FK nullable): Associated station context.
- `event_type` (`notification_event_type` enum): Typed event classification.
- `aggregate_type`, `aggregate_id`: Domain entity reference (e.g., `attendance_records`).
- `actor_user_id` (UUID FK nullable): User who initiated the action.
- `occurred_at` (TIMESTAMPTZ): Server timestamp.
- `payload` (JSONB, <= 16KB): Structured domain data (zero biometric media, zero secrets, zero QR tokens).
- `deduplication_key` (TEXT UNIQUE): Uniqueness constraint preventing duplicate event generation.

### 3.2 `notifications`
User-facing durable inbox.
- `id` (UUID PK): Notification ID.
- `recipient_user_id` (UUID FK): Inbox owner (strictly isolated via RLS).
- `station_id` (UUID FK nullable): Station context for display.
- `event_id` (UUID FK): Traceability link back to source event.
- `category` (`notification_category` enum): `SCHEDULE`, `ATTENDANCE`, `AVAILABILITY`, `OPERATIONS`, `IDENTITY`, `SYSTEM`.
- `event_type` (TEXT): Specific event code.
- `priority` (`notification_priority` enum): `LOW`, `NORMAL`, `HIGH`, `CRITICAL`.
- `title_key`, `body_key` (TEXT): ARB localization template keys.
- `render_data` (JSONB): Dynamic variables for template interpolation.
- `action_type`, `action_data`: Safe internal deep-link routing identifiers.
- `is_mandatory` (BOOLEAN): If true, bypasses user opt-outs.
- `read_at`, `seen_at` (TIMESTAMPTZ nullable): Recipient interaction timestamps.
- `created_at` (TIMESTAMPTZ): Server timestamp.

### 3.3 `notification_preferences`
Per-user multi-channel delivery configuration across all 6 operational categories.
- `user_id` (UUID FK): User preference owner.
- `category` (`notification_category` enum): Category key.
- `in_app_enabled`, `push_enabled`, `email_enabled`, `sms_enabled` (BOOLEAN).

### 3.4 `notification_delivery_jobs`
Transactional outbox delivery queue for external push/email/SMS workers.
- `id` (UUID PK): Delivery job ID.
- `notification_id` (UUID FK): Linked notification.
- `recipient_user_id` (UUID FK): Target recipient.
- `channel` (`delivery_channel` enum): `PUSH`, `EMAIL`, `SMS`.
- `status` (`delivery_status` enum): `PENDING`, `PROCESSING`, `DELIVERED`, `RETRY`, `FAILED`, `CANCELLED`.
- `attempt_count` (INT): Current retry count (capped at 5).
- `next_attempt_at` (TIMESTAMPTZ): Exponential backoff schedule.
- `locked_at`, `locked_by`, `lease_expires_at`: Distributed lease locking fields for concurrency safety.

### 3.5 `notification_delivery_attempts`
Append-only audit log tracking every delivery attempt with outcome and latency metrics.

### 3.6 `notification_devices`
Push notification device registry with SHA-256 token hashing for fast indexing and encrypted/restricted storage for background dispatch.
- `id` (UUID PK): Device ID.
- `user_id` (UUID FK): Device owner.
- `platform` (TEXT): `ios`, `android`, `web`, `macos`, `windows`.
- `provider` (TEXT): `fcm`, `apns`, `webpush`, `mock`.
- `device_token_hash` (TEXT): SHA-256 digest for deduplication.
- `encrypted_device_token` (TEXT NULL): Secured push registration token (accessible strictly by `service_role` worker).
- `is_active` (BOOLEAN): Active device flag.

### 3.7 `kiosk_health_states`
Authoritative server-side health transition tracker preventing alert storms during kiosk disconnects.
- `kiosk_device_id` (UUID PK FK): Kiosk device.
- `station_id` (UUID FK): Station context.
- `current_status` (TEXT): `ONLINE` / `OFFLINE`.
- `incident_id` (UUID): Authoritative incident token for deterministic deduplication.
- `transition_count` (INT): Incremental state transition counter.
- `last_transition_at`, `updated_at` (TIMESTAMPTZ).

---

## 4. Concurrency & Idempotency Controls

1. **Deterministic Deduplication Keys**:
   - `schedule-published:{schedule_id}:{version}:{employee_id}`
   - `shift-assigned:{shift_id}:{employee_id}:v{version}`
   - `shift-removed:{assignment_id}:{employee_id}:v{version}`
   - `shift-moved:{assignment_id}:{employee_id}:v{version}`
   - `attendance-check-in:{record_id}:{manager_id}`
   - `attendance-check-out:{record_id}:{worked_minutes}:{manager_id}`
   - `kiosk-offline:{kiosk_id}:{incident_id}`
   - `kiosk-recovered:{kiosk_id}:{incident_id}`
   - `avail-deadline-24h:{period_id}:{deadline_epoch}:{user_id}`
   - `identity-override:{proof_id}:{manager_id}`
2. **Worker Lease Claiming via `FOR UPDATE SKIP LOCKED`**:
   - Multiple background workers can claim batches concurrently without deadlocks or duplicate deliveries.
   - Leases automatically expire after 60s to safely recover from crashed workers.
   - External idempotency keys generated deterministically (`job:{job_id}:attempt:{attempt_count}`).
3. **Exponential Backoff Retry Schedule**:
   - Attempt 1: +1 minute
   - Attempt 2: +5 minutes
   - Attempt 3: +15 minutes
   - Attempt 4: +60 minutes
   - Attempt 5: Final failure (`FAILED`)

---

## 5. Security & Privacy Hardening

- **Column Immutability Trigger**: Protective `BEFORE UPDATE` trigger `check_notification_column_immutability()` prevents modifying notification content (`title_key`, `body_key`, `is_mandatory`, `priority`, `action_type`, `render_data`) and blocks future timestamp spoofing.
- **Direct Table Modification Blocked**: Normal users cannot write directly to `notification_events`, `notifications`, `notification_preferences`, or `notification_delivery_jobs`. All mutations execute through hardened `SECURITY DEFINER` RPCs.
- **Mandatory Compliance Retention**: Maintenance cleanup (`cleanup_expired_notifications`) purges non-mandatory read records while permanently preserving `is_mandatory = true` audit records.
- **Search Path Pinning**: All Phase 6 functions have `SET search_path = public, pg_temp` explicitly defined.
- **Zero Sensitive Data Exposure**: Payloads are strictly prohibited from storing face images, embeddings, raw QR tokens, or kiosk private keys.
