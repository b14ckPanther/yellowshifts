# YellowShifts — Production Operator Runbook

## 1. Platform Architecture & Services Overview

YellowShifts is an enterprise workforce operations, scheduling, attendance verification, and operational reporting platform for fuel station networks.

### Core Stack
- **Client Frontend**: Flutter Web (CanvasKit / WebAssembly) & Flutter Mobile (iOS/Android PWA standalone).
- **Backend Database**: PostgreSQL 15+ hosted on Supabase Enterprise.
- **Authorization Engine**: Multi-station Row Level Security (RLS) with Fail-Closed Policies.
- **Serverless Compute**: Supabase Deno Edge Functions for administrative actions (`admin-create-employee`, `admin-reset-password`, `admin-revoke-sessions`, `admin-update-employee`, `generate-report-export`, `process-notification-deliveries`).
- **Presence Verification Engine**: Cryptographically salted, rotatable dynamic QR codes (30-second TTL) combined with local biometric liveness checking.
- **Storage**: Supabase Storage (`reports` bucket) with signed temporal download URLs (15-minute validity).

---

## 2. Environment Configurations & Secrets

### Required Client Environment Variables (`.env` or `--dart-define`)
| Variable | Required | Description | Example |
| :--- | :--- | :--- | :--- |
| `SUPABASE_URL` | Yes | Supabase Project Gateway URL | `https://<YOUR_SUPABASE_PROJECT_REF>.supabase.co` |
| `SUPABASE_ANON_KEY` | Yes | Supabase Public Anonymous API Key | `eyJhbGciOi...` |
| `ENVIRONMENT` | No | Target Deployment Stage | `production` / `staging` / `development` |

### Required Edge Function Secrets (Supabase Secrets Vault)
| Secret Key | Target Functions | Description |
| :--- | :--- | :--- |
| `SUPABASE_URL` | All Functions | Internal Supabase Gateway |
| `SUPABASE_SERVICE_ROLE_KEY` | All Functions | Privileged Service Role Key |
| `RESEND_API_KEY` | `process-notification-deliveries` | Transactional Email Delivery |
| `TWILIO_ACCOUNT_SID` | `process-notification-deliveries` | SMS Provider Credentials |
| `TWILIO_AUTH_TOKEN` | `process-notification-deliveries` | SMS Provider Token |

---

## 3. Routine Health Checks & Telemetry Monitoring

### 3.1 Platform Health & Compatibility Probe
Any monitoring probe (e.g. Datadog, Prometheus, UptimeRobot) can ping the zero-auth compatibility endpoint:
```sql
SELECT public.get_platform_schema_version();
```
**Expected Response:**
```json
{
  "schema_version": "20260825000016",
  "platform_version": "1.0.0",
  "min_compatible_client_version": "1.0.0",
  "status": "HEALTHY",
  "server_timestamp": "2026-08-27T18:00:00.000Z"
}
```

### 3.2 Station-Level Operational Health Check (Admin / Service Role)
```sql
SELECT public.get_station_system_health('<station-uuid>');
```
Evaluates:
- Active Kiosk heartbeat counts (online within 2 minutes vs offline).
- Report export processing pipeline (pending, failed, completed).
- Stale open attendance sessions (open >= 16 hours).
- Biometric verification failure counts.
- Pending notification outbox queue size.

---

## 4. Routine Maintenance & Zombie Job Recovery

### Automated Cleanup Cron
YellowShifts automatically recovers abandoned background jobs every 5 minutes via the database scheduler:
```sql
SELECT public.recover_stuck_operational_jobs();
```
- Report exports stuck in `PROCESSING` for > 30 minutes are automatically failed with failure code `LEASE_TIMEOUT`.
- Notification deliveries leased to dead workers for > 15 minutes are reset to `PENDING` for redelivery.
- All recovery actions create audit trail entries in `public.audit_logs`.

---

## 5. Deployment Procedures

### 5.1 Web Application Build & CDN Deployment
```bash
# Clean workspace
flutter clean
flutter pub get

# Compile Web Release bundle
flutter build web --release --base-href "/"

# Or WebAssembly Build (Modern Browsers)
flutter build web --wasm --base-href "/"
```
Deploy the contents of `build/web/` to the static hosting target (Cloudflare Pages, AWS S3/CloudFront, or Supabase Hosting).

### 5.2 Database Migration Deployment
```bash
# Verify remote migration status
supabase migration list

# Push additive migrations
supabase db push
```
*Note: Canonical migrations `001` through `015` are strictly immutable. Only additive migrations (`016+`) are deployed.*
