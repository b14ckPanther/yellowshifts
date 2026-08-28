# YellowShifts — Notification Delivery & Background Worker Infrastructure

## 1. Overview

The delivery layer processes queued notifications from `notification_delivery_jobs` and dispatches them across external communication channels (`PUSH`, `EMAIL`, `SMS`) while preserving strict database-driven transactional safety.

---

## 2. Channel Capability Status Matrix

| Channel | Architecture Status | Provider Status | Description |
|---|---|---|---|
| **IN_APP** | **PRODUCTION READY** | **Active & Authoritative** | Full real-time inbox synchronization via Supabase Realtime and PostgreSQL RLS. |
| **PUSH** | **ARCHITECTURE READY** | **Provider Configuration Required** | Complete schema, device registration (`notification_devices`), token hashing, and delivery worker adapter ready. Awaiting APNs / FCM / WebPush service credentials. |
| **EMAIL** | **ARCHITECTURE READY** | **Provider Configuration Required** | Delivery outbox queue, backoff retry, and template rendering ready. Awaiting SMTP / Resend / SendGrid API keys. |
| **SMS** | **ARCHITECTURE READY** | **Provider Configuration Required** | Queue and retry pipeline ready. Awaiting Twilio / InforU API keys. |

---

## 3. Background Delivery Worker Architecture

### 3.1 Edge Function: `process-notification-deliveries`
Located at `supabase/functions/process-notification-deliveries/index.ts`.

#### Processing Cycle:
1. **Authentication**: Restricts invocation to `SUPABASE_SERVICE_ROLE_KEY` or verified `CRON_SECRET`.
2. **Atomic Batch Claiming**: Calls PostgreSQL RPC `claim_notification_delivery_jobs` with a dynamic `worker_id` and lease duration (default 120s).
   - Uses `SELECT ... FOR UPDATE SKIP LOCKED` to allow multi-instance concurrent worker scaling without contention.
3. **Dispatch & Response Mapping**:
   - Matches channel (`PUSH`, `EMAIL`, `SMS`) against configured provider environment variables.
   - If provider is unconfigured, records `TEMPORARY_FAILURE` with `PROVIDER_NOT_CONFIGURED` without crashing.
4. **Outcome Recording**: Calls `record_delivery_attempt_outcome` to:
   - Transition status to `DELIVERED`, `RETRY`, or `FAILED`.
   - Update retry count and exponential backoff timestamp.
   - Insert append-only record into `notification_delivery_attempts`.

---

## 4. Scheduled Evaluators & Supabase Cron

YellowShifts defines two scheduled evaluation RPCs designed for invocation via `pg_cron` or Supabase Scheduled Triggers:

### 4.1 `generate_due_notification_reminders()`
- **Recommended Schedule**: Every 15 minutes (`*/15 * * * *`).
- **Tasks**:
  1. Identifies approaching weekly availability deadlines (within 24h) and emits `AVAILABILITY_DEADLINE_APPROACHING`.
  2. Scans for scheduled shifts where the shift start time + late grace period has elapsed without an open attendance record and emits `EMPLOYEE_MISSED_CHECK_IN`.
- **Idempotency**: Strictly deduplicated by period, shift, employee, and stage. Repeated runs are completely safe (no duplicate alerts).

### 4.2 `evaluate_kiosk_health_transitions(p_station_id UUID DEFAULT NULL)`
- **Recommended Schedule**: Every 2 minutes (`*/2 * * * *`).
- **Tasks**:
  1. Checks `last_seen_at` for all active kiosk devices.
  2. Respects a 15-minute onboarding grace window for newly provisioned kiosks without heartbeats.
  3. If inactive beyond threshold (default 3 minutes), transitions state `ONLINE -> OFFLINE`, generates a new `incident_id`, and emits `KIOSK_OFFLINE`.
  4. When a dormant kiosk sends a heartbeat, transitions `OFFLINE -> ONLINE`, generates a new `incident_id`, and emits `KIOSK_RECOVERED`.
- **Anti-Storm Defense**: State transitions are tracked with incident UUIDs in `kiosk_health_states`. Deduplication keys prevent alert storms while ensuring every distinct offline/recovery cycle produces an alert.

### 4.3 `cleanup_expired_notifications(p_retention_days INTEGER DEFAULT 90)`
- **Recommended Schedule**: Daily at 03:00 UTC (`0 3 * * *`).
- **Tasks**:
  - Purges delivered/failed jobs older than cutoff.
  - Purges read non-mandatory notifications older than retention days (`is_mandatory = false`).
  - Permanently preserves all unread items, mandatory compliance/audit notifications, and active events.
  - Restricted to `service_role` execution.

---

## 5. Deployment Guide for Remote Environment

When external providers are provisioned:
1. Set secrets in Supabase Dashboard:
   ```bash
   supabase secrets set FCM_SERVER_KEY="..."
   supabase secrets set APNS_KEY="..."
   supabase secrets set RESEND_API_KEY="..."
   supabase secrets set TWILIO_ACCOUNT_SID="..." TWILIO_AUTH_TOKEN="..."
   supabase secrets set CRON_SECRET="..."
   ```
2. Deploy the Edge Function:
   ```bash
   supabase functions deploy process-notification-deliveries
   ```
3. Configure `pg_cron` in Supabase SQL Editor:
   ```sql
   SELECT cron.schedule('eval-reminders', '*/15 * * * *', 'SELECT public.generate_due_notification_reminders()');
   SELECT cron.schedule('eval-kiosk-health', '*/2 * * * *', 'SELECT public.evaluate_kiosk_health_transitions()');
   SELECT cron.schedule('cleanup-notifications', '0 3 * * *', 'SELECT public.cleanup_expired_notifications()');
   ```
