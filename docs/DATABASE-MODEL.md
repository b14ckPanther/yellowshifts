# YellowShifts — Database Model & Schema Reference

This document provides complete documentation of the PostgreSQL schema across all implemented and audited phases of the YellowShifts platform (Migrations 001–006).

---

## 1. Core Identity & Multi-Station Tenancy (Phases 0–1)

### 1.1 `public.profiles`
Stores global user identity attributes linked 1:1 to `auth.users`.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE` | Auth user ID |
| `first_name` | `TEXT` | `NOT NULL DEFAULT ''` | Given name |
| `last_name` | `TEXT` | `NOT NULL DEFAULT ''` | Family name |
| `phone` | `TEXT` | `NULL` | Formatted contact phone number |
| `preferred_locale`| `TEXT` | `NOT NULL DEFAULT 'he'` | Preferred UI language (`he` or `en`) |
| `avatar_url` | `TEXT` | `NULL` | Public avatar storage URL |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now())` | Record creation timestamp |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now())` | Record modification timestamp |

---

### 1.2 `public.stations`
Represents an independent physical station / branch tenant.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Unique station identifier |
| `name` | `TEXT` | `NOT NULL` | Station display name (e.g. 'תחנת יילו כורדני') |
| `code` | `TEXT` | `NOT NULL UNIQUE` | Unique station operational code (e.g. 'YLW-KRD-01') |
| `timezone` | `TEXT` | `NOT NULL DEFAULT 'Asia/Jerusalem'` | IANA timezone string |
| `locale` | `TEXT` | `NOT NULL DEFAULT 'he'` | Default station operational language |
| `week_start` | `INTEGER` | `NOT NULL DEFAULT 0` | Week starting day (0 = Sunday, 1 = Monday) |
| `is_active` | `BOOLEAN` | `NOT NULL DEFAULT true` | Operational active status |
| `check_in_early_minutes`| `INTEGER`| `NOT NULL DEFAULT 60` | Allowed early check-in window (minutes) |
| `late_grace_minutes` | `INTEGER` | `NOT NULL DEFAULT 5` | Lateness calculation grace window (minutes) |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now())` | Record creation timestamp |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now())` | Record modification timestamp |

---

### 1.3 `public.station_memberships`
Maps global users to stations with a station-scoped role and status.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Unique membership identifier |
| `station_id` | `UUID` | `NOT NULL REFERENCES public.stations(id) ON DELETE RESTRICT` | Target station |
| `user_id` | `UUID` | `NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT` | Target user profile |
| `role` | `public.station_role` | `NOT NULL DEFAULT 'EMPLOYEE'` | Station role (`ADMIN`, `SHIFT_MANAGER`, `EMPLOYEE`) |
| `status` | `public.membership_status` | `NOT NULL DEFAULT 'ACTIVE'` | Membership state (`ACTIVE`, `INACTIVE`, `SUSPENDED`) |
| `employee_code` | `TEXT` | `NULL` | Station-specific employee code |
| `joined_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now())` | Date membership commenced |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now())` | Creation timestamp |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now())` | Modification timestamp |

**Constraint**: `UNIQUE (station_id, user_id)` — A user can only hold one membership record per station.

`station_memberships.role` is never `PLATFORM_ADMIN`. Global operators live in `public.platform_admins`.

### 1.4 `public.platform_admins` (Phase 10.5)

Global Platform Admin assignments, separate from station membership.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `user_id` | `UUID` | `PRIMARY KEY REFERENCES public.profiles(id) ON DELETE RESTRICT` | Operator identity |
| `is_active` | `BOOLEAN` | `NOT NULL DEFAULT true` | Inactive operators lose global privileges immediately |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now())` | Created |
| `created_by` | `UUID` | `REFERENCES public.profiles(id) ON DELETE SET NULL` | Must not equal `user_id` |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now())` | Updated |

RLS is enabled with **no authenticated policies**. Client roles have no table grants. `platform_provisioning_keys` stores station-create idempotency keys (service_role only).

Canonical schema version after Phase 10.5 independent audit: **`20260825000019`**. Platform version: **`1.0.5`**. App release: **`1.0.5+11`**.

---

## 2. Shift Templates & Availability Architecture (Phase 2)

### 2.1 `public.shift_templates`
Station-defined shift blueprints.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Template identifier |
| `station_id` | `UUID` | `NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE` | Station owner |
| `name` | `TEXT` | `NOT NULL` | Template name |
| `code` | `TEXT` | `NULL` | Operational shift code |
| `start_time` | `TIME` | `NOT NULL` | Daily start time |
| `end_time` | `TIME` | `NOT NULL` | Daily end time (supports cross-midnight if < start_time) |
| `sort_order` | `INTEGER` | `NOT NULL DEFAULT 0` | Display sorting order |
| `is_active` | `BOOLEAN` | `NOT NULL DEFAULT true` | Active flag |

---

## 3. Work Scheduling & Assignment Domain (Phase 3)

### 3.1 `public.work_schedules`
Weekly station work schedules generated from Phase 2 frozen availability periods.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Unique schedule identifier |
| `station_id` | `UUID` | `NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE` | Station owner |
| `availability_period_id` | `UUID` | `NOT NULL UNIQUE REFERENCES public.availability_periods(id) ON DELETE RESTRICT` | Source frozen period |
| `week_start_date` | `DATE` | `NOT NULL` | Schedule week start date |
| `status` | `public.work_schedule_status` | `NOT NULL DEFAULT 'DRAFT'` | Status (`DRAFT`, `PUBLISHED`, `ARCHIVED`) |
| `version` | `INTEGER` | `NOT NULL DEFAULT 1` | OCC version counter |
| `created_by` | `UUID` | `NOT NULL REFERENCES public.profiles(id)` | Creating manager ID |
| `published_by` | `UUID` | `NULL REFERENCES public.profiles(id)` | Publishing manager ID |
| `published_at` | `TIMESTAMPTZ` | `NULL` | Publication timestamp |
| `notes` | `TEXT` | `NULL` | Operational notes |

**Constraint**: `UNIQUE (station_id, week_start_date)` — Exactly one schedule per station and week.

---

### 3.2 `public.work_schedule_shifts`
Operational daily shifts generated for all 7 days from frozen templates.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Shift identifier |
| `work_schedule_id` | `UUID` | `NOT NULL REFERENCES public.work_schedules(id) ON DELETE CASCADE` | Parent schedule |
| `station_id` | `UUID` | `NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE` | Station identifier |
| `operational_date` | `DATE` | `NOT NULL` | Calendar date of shift |
| `period_shift_template_id` | `UUID` | `NOT NULL REFERENCES public.availability_period_shift_templates(id)` | Frozen template reference |
| `shift_name_snapshot` | `TEXT` | `NOT NULL` | Frozen shift name |
| `shift_code_snapshot` | `TEXT` | `NULL` | Frozen shift code |
| `start_time_snapshot` | `TIME` | `NOT NULL` | Shift start time |
| `end_time_snapshot` | `TIME` | `NOT NULL` | Shift end time |
| `starts_at` | `TIMESTAMPTZ` | `NOT NULL` | Timezone-aware UTC start instant |
| `ends_at` | `TIMESTAMPTZ` | `NOT NULL` | Timezone-aware UTC end instant |
| `required_staff_count` | `INTEGER` | `NOT NULL DEFAULT 1 CHECK (required_staff_count >= 0)` | Required headcount |
| `sort_order` | `INTEGER` | `NOT NULL DEFAULT 0` | Shift sort order |

---

### 3.3 `public.shift_assignments`
Atomic employee shift assignments with availability snapshot and override governance.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Assignment identifier |
| `work_schedule_shift_id` | `UUID` | `NOT NULL REFERENCES public.work_schedule_shifts(id) ON DELETE CASCADE` | Target shift |
| `station_id` | `UUID` | `NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE` | Station identifier |
| `membership_id` | `UUID` | `NOT NULL REFERENCES public.station_memberships(id)` | Assigned membership |
| `user_id` | `UUID` | `NOT NULL REFERENCES public.profiles(id)` | Global user ID (for cross-station locking) |
| `availability_state_snapshot` | `TEXT` | `NOT NULL` | `'AVAILABLE'`, `'UNAVAILABLE'`, `'NOT_SUBMITTED'` |
| `availability_override` | `BOOLEAN` | `NOT NULL DEFAULT false` | Explicit override flag |
| `availability_override_reason` | `TEXT` | `NULL` | Mandatory reason if override is true |
| `assigned_by` | `UUID` | `NOT NULL REFERENCES public.profiles(id)` | Manager actor ID |

**Constraint**: `UNIQUE (work_schedule_shift_id, membership_id)` — Duplicate same-person assignment on same shift blocked.

---

## 4. Live Attendance & Station Kiosk Domain (Phase 4)

### 4.1 `public.kiosk_devices`
Physical station kiosk devices registered for dynamic QR challenge generation.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Device identifier |
| `station_id` | `UUID` | `NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE` | Associated station |
| `name` | `TEXT` | `NOT NULL` | Device display name (e.g. 'Tablet 1') |
| `device_identifier` | `TEXT` | `NOT NULL` | Hardware/station identifier (e.g. 'TAB-KRD-01') |
| `secret_hash` | `TEXT` | `NOT NULL` | One-way SHA-256 hash of device secret |
| `credential_version`| `INTEGER` | `NOT NULL DEFAULT 1` | Version counter incremented on secret rotation |
| `is_active` | `BOOLEAN` | `NOT NULL DEFAULT true` | Active operational status |
| `last_seen_at` | `TIMESTAMPTZ` | `NULL` | Timestamp of latest successful challenge minting |
| `created_by` | `UUID` | `NOT NULL REFERENCES public.profiles(id)` | Provisioning admin user ID |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now())` | Creation timestamp |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now())` | Modification timestamp |

**Constraint**: `UNIQUE (station_id, device_identifier)`

---

### 4.2 `public.kiosk_qr_challenges`
Ephemeral dynamic rotating presence challenges (30s TTL).

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Challenge identifier |
| `kiosk_device_id` | `UUID` | `NOT NULL REFERENCES public.kiosk_devices(id) ON DELETE CASCADE` | Issuing kiosk device |
| `station_id` | `UUID` | `NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE` | Associated station |
| `challenge_hash` | `TEXT` | `NOT NULL UNIQUE` | SHA-256 hash of full dynamic token |
| `display_code` | `TEXT` | `NOT NULL` | 6-character human-readable fallback code |
| `credential_version`| `INTEGER` | `NOT NULL` | Version of kiosk secret used to mint challenge |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now())` | Mint timestamp |
| `expires_at` | `TIMESTAMPTZ` | `NOT NULL` | Challenge expiration timestamp (created_at + 30s) |

---

### 4.3 `public.attendance_presence_proofs`
Ephemeral single-use presence proof tokens (60s TTL) bound to employee and action.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Proof record identifier |
| `station_id` | `UUID` | `NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE` | Target station |
| `employee_user_id` | `UUID` | `NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE` | Bound employee profile ID |
| `station_membership_id`| `UUID` | `NOT NULL REFERENCES public.station_memberships(id) ON DELETE CASCADE` | Employee membership ID |
| `kiosk_device_id` | `UUID` | `NOT NULL REFERENCES public.kiosk_devices(id) ON DELETE CASCADE` | Scanning kiosk device ID |
| `qr_challenge_id` | `UUID` | `NOT NULL REFERENCES public.kiosk_qr_challenges(id) ON DELETE CASCADE` | Source QR challenge |
| `action` | `TEXT` | `NOT NULL CHECK (action IN ('CHECK_IN', 'CHECK_OUT'))` | Target operation |
| `token_hash` | `TEXT` | `NOT NULL UNIQUE` | SHA-256 hash of proof token |
| `shift_preview_snapshot`| `JSONB` | `NULL` | Shift snapshot data at scan time |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now())` | Issue timestamp |
| `expires_at` | `TIMESTAMPTZ` | `NOT NULL` | Expiration timestamp (created_at + 60s) |
| `used_at` | `TIMESTAMPTZ` | `NULL` | Instant token was consumed |

---

### 4.4 `public.attendance_records`
Core attendance sessions tracking real UTC clock-in and clock-out events.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Attendance session ID |
| `station_id` | `UUID` | `NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE` | Station tenant |
| `employee_user_id` | `UUID` | `NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE` | Employee user ID |
| `station_membership_id`| `UUID` | `NOT NULL REFERENCES public.station_memberships(id) ON DELETE CASCADE` | Employee membership ID |
| `work_schedule_shift_id`| `UUID` | `NULL REFERENCES public.work_schedule_shifts(id) ON DELETE SET NULL` | Scheduled shift reference |
| `shift_assignment_id` | `UUID` | `NULL REFERENCES public.shift_assignments(id) ON DELETE SET NULL` | Specific assignment reference |
| `shift_name_snapshot` | `TEXT` | `NULL` | Shift name frozen at check-in |
| `schedule_version_at_check_in`| `INTEGER`| `NULL` | Schedule version frozen at check-in |
| `check_in_time` | `TIMESTAMPTZ` | `NOT NULL` | Authoritative check-in instant |
| `check_out_time` | `TIMESTAMPTZ` | `NULL` | Authoritative check-out instant |
| `worked_minutes` | `INTEGER` | `NULL` | Computed real UTC elapsed minutes |
| `late_minutes` | `INTEGER` | `NOT NULL DEFAULT 0` | Lateness duration past station grace |
| `status` | `public.attendance_status` | `NOT NULL DEFAULT 'OPEN'` | `'OPEN'`, `'COMPLETED'`, `'CORRECTED'` |
| `verification_method` | `public.attendance_verification_method` | `NOT NULL DEFAULT 'QR_ONLY'` | Verification provenance |
| `check_in_kiosk_device_id`| `UUID` | `NOT NULL REFERENCES public.kiosk_devices(id)` | Device where check-in occurred |
| `check_out_kiosk_device_id`| `UUID`| `NULL REFERENCES public.kiosk_devices(id)` | Device where check-out occurred |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now())` | Creation timestamp |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now())` | Modification timestamp |

**Storage Invariant**:
```sql
CREATE UNIQUE INDEX uq_attendance_single_open_session 
ON public.attendance_records (employee_user_id) 
WHERE check_out_time IS NULL;
```

---

### 4.5 `public.attendance_corrections`
Immutable audit ledger recording all post-event manual modifications to attendance records.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Correction entry ID |
| `attendance_record_id` | `UUID` | `NOT NULL REFERENCES public.attendance_records(id) ON DELETE CASCADE` | Modified attendance row |
| `station_id` | `UUID` | `NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE` | Station tenant |
| `actor_user_id` | `UUID` | `NOT NULL REFERENCES public.profiles(id)` | Admin actor profile ID |
| `original_check_in` | `TIMESTAMPTZ` | `NOT NULL` | Check-in time before edit |
| `original_check_out` | `TIMESTAMPTZ` | `NULL` | Check-out time before edit |
| `original_worked_minutes`| `INTEGER` | `NULL` | Worked duration before edit |
| `new_check_in` | `TIMESTAMPTZ` | `NOT NULL` | Check-in time after edit |
| `new_check_out` | `TIMESTAMPTZ` | `NOT NULL` | Check-out time after edit |
| `new_worked_minutes` | `INTEGER` | `NOT NULL` | Worked duration after edit |
| `reason` | `TEXT` | `NOT NULL` | Mandatory administrative justification ($\ge 3$ chars) |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now())` | Audit timestamp |

---

### 4.6 `public.attendance_rate_limit_attempts`
Sliding window rate limiting tracker protecting against kiosk authentication and QR scan brute force attempts.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Attempt record ID |
| `actor_id` | `UUID` | `NULL REFERENCES public.profiles(id) ON DELETE CASCADE` | Requesting user ID (for QR scans) |
| `target_identifier` | `TEXT` | `NOT NULL` | Device identifier or scan code |
| `action` | `TEXT` | `NOT NULL` | `'KIOSK_AUTH'` or `'QR_SCAN'` |
| `is_success` | `BOOLEAN` | `NOT NULL DEFAULT false` | Result of attempt |
| `attempted_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now())` | Attempt timestamp |

---

## 5. Identity Verification & Biometric Gate Domain (Phase 5 — Migration 007)

### 5.1 Enums
- `public.identity_verification_mode`: `'DISABLED'`, `'CHECK_IN_ONLY'`, `'CHECK_IN_AND_CHECK_OUT'`
- `public.identity_profile_status`: `'NOT_ENROLLED'`, `'PENDING'`, `'ACTIVE'`, `'REVOKED'`, `'FAILED'`
- `public.enrollment_session_status`: `'PENDING'`, `'COMPLETED'`, `'EXPIRED'`, `'CANCELLED'`, `'FAILED'`
- `public.identity_verification_result`: `'VERIFIED'`, `'NOT_VERIFIED'`, `'INCONCLUSIVE'`

---

### 5.2 `public.employee_identity_profiles`
Stores employee biometric assurance status, server-authoritative consent, and opaque provider subject references. Zero raw images or embeddings are stored.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Profile record ID |
| `employee_user_id` | `UUID` | `NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE` | Target user |
| `provider` | `TEXT` | `NOT NULL` | Biometric provider identifier |
| `provider_subject_id` | `TEXT` | `NULL UNIQUE` | Opaque non-reversible subject reference |
| `status` | `public.identity_profile_status` | `NOT NULL DEFAULT 'PENDING'` | Lifecycle state |
| `notice_version` | `TEXT` | `NOT NULL DEFAULT 'v1.0'` | Privacy notice version consented to |
| `consented_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now())` | Timestamp consent was recorded |
| `enrolled_at` | `TIMESTAMPTZ` | `NULL` | Timestamp active enrollment was finalized |
| `revoked_at` | `TIMESTAMPTZ` | `NULL` | Timestamp profile was revoked |
| `last_verified_at` | `TIMESTAMPTZ` | `NULL` | Timestamp of most recent successful verification |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now())` | Creation timestamp |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now())` | Modification timestamp |

---

### 5.3 `public.identity_enrollment_sessions`
Ephemeral server-authoritative biometric enrollment challenge sessions (15-minute TTL).

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Session ID |
| `employee_user_id` | `UUID` | `NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE` | Enrolling employee |
| `provider` | `TEXT` | `NOT NULL` | Selected provider |
| `provider_session_id` | `TEXT` | `NOT NULL UNIQUE` | Cryptographic session challenge |
| `status` | `public.enrollment_session_status` | `NOT NULL DEFAULT 'PENDING'` | Session state |
| `notice_version` | `TEXT` | `NOT NULL` | Disclosed notice version |
| `expires_at` | `TIMESTAMPTZ` | `NOT NULL` | Ephemeral expiration instant |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now())` | Creation timestamp |

---

### 5.4 `public.identity_verification_attempts`
Audit log of biometric verification attempts with categorical failure logging and zero biometric score/vector storage.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Attempt record ID |
| `employee_user_id` | `UUID` | `NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE` | Verified employee |
| `station_id` | `UUID` | `NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE` | Station tenant |
| `presence_proof_id` | `UUID` | `NOT NULL REFERENCES public.attendance_presence_proofs(id) ON DELETE CASCADE` | Associated presence challenge |
| `provider` | `TEXT` | `NOT NULL` | Identity provider |
| `provider_session_id` | `TEXT` | `NOT NULL UNIQUE` | Provider verification challenge |
| `result` | `public.identity_verification_result` | `NOT NULL DEFAULT 'INCONCLUSIVE'` | Categorical result |
| `failure_category` | `TEXT` | `NULL` | Category (`FACE_MISMATCH`, `LIVENESS_FAILED`, etc.) |
| `is_override` | `BOOLEAN` | `NOT NULL DEFAULT false` | Whether generated via admin override |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now())` | Attempt creation instant |
| `completed_at` | `TIMESTAMPTZ` | `NULL` | Completion instant |

---

### 5.5 `public.identity_verification_proofs`
Single-use cryptographic identity tokens (120s TTL) consumed atomically during attendance check-in and check-out.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Proof record ID |
| `token_hash` | `TEXT` | `NOT NULL UNIQUE` | SHA-256 hash of plaintext identity proof token |
| `verification_attempt_id`| `UUID` | `NOT NULL REFERENCES public.identity_verification_attempts(id) ON DELETE CASCADE` | Authoritative verification attempt |
| `employee_user_id` | `UUID` | `NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE` | Bound employee |
| `station_id` | `UUID` | `NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE` | Bound station |
| `presence_proof_id` | `UUID` | `NOT NULL REFERENCES public.attendance_presence_proofs(id) ON DELETE CASCADE` | Bound presence challenge |
| `action` | `public.attendance_action` | `NOT NULL` | Bound action (`CHECK_IN` or `CHECK_OUT`) |
| `expires_at` | `TIMESTAMPTZ` | `NOT NULL` | Token expiration timestamp (120s TTL) |
| `used_at` | `TIMESTAMPTZ` | `NULL` | Single-use consumption timestamp |
| `is_override` | `BOOLEAN` | `NOT NULL DEFAULT false` | Manager override flag |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now())` | Proof minting timestamp |

---

## 6. Notifications, Operational Alerts & Transactional Outbox (Phase 6)

### 6.1 `public.notification_events`
Authoritative domain event ledger.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Event ID |
| `station_id` | `UUID` | `NULL REFERENCES public.stations(id) ON DELETE CASCADE` | Station tenant |
| `event_type` | `public.notification_event_type` | `NOT NULL` | Typed event classification |
| `aggregate_type`| `TEXT` | `NOT NULL` | Target table (e.g. `attendance_records`) |
| `aggregate_id` | `UUID` | `NULL` | Target record UUID |
| `actor_user_id` | `UUID` | `NULL REFERENCES public.profiles(id) ON DELETE SET NULL` | Performing user |
| `occurred_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | Event instant |
| `payload` | `JSONB` | `NOT NULL DEFAULT '{}'::jsonb` | Sanitized domain payload (<= 16KB) |
| `deduplication_key` | `TEXT` | `NOT NULL UNIQUE` | Uniqueness defense against duplicate emissions |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | Event insertion instant |

---

### 6.2 `public.notifications`
User-facing durable inbox.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Notification ID |
| `recipient_user_id` | `UUID` | `NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE` | Target recipient |
| `station_id` | `UUID` | `NULL REFERENCES public.stations(id) ON DELETE CASCADE` | Station context |
| `event_id` | `UUID` | `NOT NULL REFERENCES public.notification_events(id) ON DELETE CASCADE` | Source event link |
| `category` | `public.notification_category` | `NOT NULL` | Operational category |
| `event_type` | `TEXT` | `NOT NULL` | Specific event code |
| `priority` | `public.notification_priority` | `NOT NULL DEFAULT 'NORMAL'` | Alert priority |
| `title_key` | `TEXT` | `NOT NULL` | ARB localization title key |
| `body_key` | `TEXT` | `NOT NULL` | ARB localization body key |
| `render_data` | `JSONB` | `NOT NULL DEFAULT '{}'::jsonb` | Template dynamic variables |
| `action_type` | `TEXT` | `NULL` | Deep link action identifier |
| `action_data` | `JSONB` | `NOT NULL DEFAULT '{}'::jsonb` | Deep link route payload |
| `is_mandatory` | `BOOLEAN` | `NOT NULL DEFAULT false` | Mandatory security/compliance flag |
| `read_at` | `TIMESTAMPTZ` | `NULL` | Recipient read timestamp |
| `seen_at` | `TIMESTAMPTZ` | `NULL` | Recipient display timestamp |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | Inbox delivery instant |

---

### 6.3 `public.notification_preferences`
Per-user notification delivery matrix.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Preference ID |
| `user_id` | `UUID` | `NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE` | Target user |
| `category` | `public.notification_category` | `NOT NULL` | Category key |
| `in_app_enabled`| `BOOLEAN` | `NOT NULL DEFAULT true` | In-app channel toggle |
| `push_enabled` | `BOOLEAN` | `NOT NULL DEFAULT true` | Push notification toggle |
| `email_enabled`| `BOOLEAN` | `NOT NULL DEFAULT false` | Email channel toggle |
| `sms_enabled` | `BOOLEAN` | `NOT NULL DEFAULT false` | SMS channel toggle |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | Creation instant |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | Last update instant |

---

### 6.4 `public.notification_delivery_jobs`
Transactional outbox delivery queue.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Delivery Job ID |
| `notification_id` | `UUID` | `NOT NULL REFERENCES public.notifications(id) ON DELETE CASCADE` | Bound notification |
| `recipient_user_id` | `UUID` | `NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE` | Recipient |
| `channel` | `public.delivery_channel` | `NOT NULL` | `PUSH`, `EMAIL`, or `SMS` |
| `status` | `public.delivery_status` | `NOT NULL DEFAULT 'PENDING'` | Lifecycle state |
| `attempt_count` | `INTEGER` | `NOT NULL DEFAULT 0` | Current attempts (0..5) |
| `next_attempt_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | Scheduled dispatch time |
| `provider` | `TEXT` | `NOT NULL DEFAULT 'MOCK_PROVIDER'` | Target dispatch adapter |
| `provider_message_id`| `TEXT` | `NULL` | Provider reference identifier |
| `last_error_category`| `TEXT` | `NULL` | Sanitized error code |
| `locked_at` | `TIMESTAMPTZ` | `NULL` | Lease acquisition timestamp |
| `locked_by` | `TEXT` | `NULL` | Worker identifier |
| `lease_expires_at` | `TIMESTAMPTZ` | `NULL` | Lease timeout deadline |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | Job creation instant |
| `delivered_at` | `TIMESTAMPTZ` | `NULL` | Delivery completion instant |
| `failed_at` | `TIMESTAMPTZ` | `NULL` | Permanent failure instant |

---

### 6.5 `public.notification_delivery_attempts`
Append-only delivery attempt ledger.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Attempt ID |
| `delivery_job_id` | `UUID` | `NOT NULL REFERENCES public.notification_delivery_jobs(id) ON DELETE CASCADE` | Parent job |
| `attempt_number` | `INTEGER` | `NOT NULL` | Attempt index (1..5) |
| `provider` | `TEXT` | `NOT NULL` | Dispatch adapter |
| `started_at` | `TIMESTAMPTZ` | `NOT NULL` | Attempt start instant |
| `finished_at` | `TIMESTAMPTZ` | `NOT NULL` | Attempt completion instant |
| `outcome` | `TEXT` | `NOT NULL` | `SUCCESS`, `TEMPORARY_FAILURE`, `PERMANENT_FAILURE` |
| `error_category` | `TEXT` | `NULL` | Sanitized error category |
| `provider_response_code`| `TEXT`| `NULL` | HTTP/status response code |

---

### 6.6 `public.notification_devices`
Push notification device registry with SHA-256 token hashing and secure worker dispatch token storage.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Device ID |
| `user_id` | `UUID` | `NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE` | Device owner |
| `platform` | `TEXT` | `NOT NULL` | `ios`, `android`, `web`, `macos`, `windows` |
| `provider` | `TEXT` | `NOT NULL` | `apns`, `fcm`, `webpush`, `mock` |
| `device_token_hash`| `TEXT` | `NOT NULL` | SHA-256 hash of device push token |
| `encrypted_device_token`| `TEXT` | `NULL` | Raw push registration token (service_role restricted) |
| `device_label` | `TEXT` | `NOT NULL DEFAULT 'Device'` | Human readable device label |
| `is_active` | `BOOLEAN` | `NOT NULL DEFAULT true` | Active delivery status |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | Registration instant |
| `last_seen_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | Last active timestamp |
| `revoked_at` | `TIMESTAMPTZ` | `NULL` | Device revocation instant |

---

### 6.7 `public.kiosk_health_states`
Authoritative kiosk connection transition ledger with incident tracking.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `kiosk_device_id` | `UUID` | `PRIMARY KEY REFERENCES public.kiosk_devices(id) ON DELETE CASCADE` | Kiosk device |
| `station_id` | `UUID` | `NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE` | Station tenant |
| `current_status` | `TEXT` | `NOT NULL DEFAULT 'ONLINE'` | `ONLINE` or `OFFLINE` |
| `incident_id` | `UUID` | `NOT NULL DEFAULT gen_random_uuid()` | Authoritative incident identifier for deduplication |
| `transition_count`| `INTEGER` | `NOT NULL DEFAULT 1` | Monotonic transition counter |
| `last_transition_at`| `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | Last state transition |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | Last update timestamp |

---

## 7. Worked Hours Analytics & Operational Reporting (Phase 7)

### 7.1 Server-Authoritative Reporting RPCs (Migration 011)

| RPC Name | Access Level | Description |
| :--- | :--- | :--- |
| `get_my_attendance_summary(p_from, p_to, p_station_id)` | Authenticated User | Personal aggregate worked minutes, shift counts, lateness, and active session. |
| `get_my_attendance_history(p_from, p_to, p_station_id, p_status_filter, p_limit, p_offset)` | Authenticated User | Paginated personal attendance shift history with status filters. |
| `get_station_attendance_summary(p_station_id, p_from, p_to)` | Shift Manager / Admin | Station-wide aggregate KPIs (total minutes, late rate, repeated lateness, active workforce). |
| `get_station_employee_attendance_summary(p_station_id, p_from, p_to, p_search, p_sort_by, p_sort_order, p_limit, p_offset)` | Shift Manager / Admin | Per-employee aggregated metrics with search, sorting, and pagination. |
| `get_station_daily_attendance_report(p_station_id, p_date)` | Shift Manager / Admin | Daily operational board with scheduled shifts, attendee rosters, and walk-ins. |
| `get_station_employee_attendance_detail(p_station_id, p_employee_user_id, p_from, p_to)` | Shift Manager / Admin | Single employee period drilldown with complete chronological correction ledger. |

### 7.2 Performance Indexes (Migration 011)

```sql
-- Reporting & operational date index
CREATE INDEX idx_attendance_records_station_op_date_status
    ON public.attendance_records (station_id, operational_date, status);

-- Employee history index
CREATE INDEX idx_attendance_records_user_op_date
    ON public.attendance_records (user_id, operational_date DESC);

-- Station employee detail index
CREATE INDEX idx_attendance_records_station_user_op_date
    ON public.attendance_records (station_id, user_id, operational_date DESC);

-- Active open session partial index
CREATE INDEX idx_attendance_records_open_sessions
    ON public.attendance_records (station_id, user_id)
    WHERE check_out_time IS NULL;

-- Late shifts partial index
CREATE INDEX idx_attendance_records_status_late
    ON public.attendance_records (station_id, is_late)
    WHERE is_late = true;

-- Work schedule shift lookup
CREATE INDEX idx_attendance_records_shift_id
    ON public.attendance_records (work_schedule_shift_id)
    WHERE work_schedule_shift_id IS NOT NULL;

-- Correction ledger ordered history
CREATE INDEX idx_attendance_corrections_record_id_created
    ON public.attendance_corrections (attendance_record_id, created_at DESC);
```

---

## 8. Server-Side Exports, Audit Center & Station Governance (Phase 8)

### 8.1 `public.report_exports`
Transactional state machine ledger for server-side report generations.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Export Request ID |
| `station_id` | `UUID` | `NULL REFERENCES public.stations(id) ON DELETE CASCADE` | Station tenant context |
| `requested_by` | `UUID` | `NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE` | Requester profile |
| `export_type` | `TEXT` | `NOT NULL` | `MY_ATTENDANCE_HISTORY`, `STATION_ATTENDANCE_SUMMARY`, `STATION_EMPLOYEE_WORKED_HOURS`, `DAILY_ATTENDANCE_REPORT`, `ATTENDANCE_CORRECTION_LEDGER`, `PUBLISHED_SCHEDULE`, `EMPLOYEE_DIRECTORY`, `AVAILABILITY_OVERVIEW` |
| `format` | `TEXT` | `NOT NULL DEFAULT 'CSV'` | `CSV` or `PDF` |
| `status` | `TEXT` | `NOT NULL DEFAULT 'PENDING'` | `PENDING`, `PROCESSING`, `COMPLETED`, `FAILED`, `EXPIRED` |
| `filter_payload` | `JSONB` | `NOT NULL DEFAULT '{}'::jsonb` | Parameter bounds ($\le 8\text{KB}$) |
| `file_path` | `TEXT` | `NULL` | Storage bucket object key |
| `row_count` | `INTEGER` | `NOT NULL DEFAULT 0` | Total records in export |
| `error_message` | `TEXT` | `NULL` | Sanitized failure reason |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now())` | Creation instant |
| `completed_at` | `TIMESTAMPTZ` | `NULL` | Completion instant |
| `expires_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now() + interval '24 hours')` | Expiration instant |

### 8.2 `public.audit_logs` (Hardened Immutable Schema)
Compliance-grade immutable operational log.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Audit Log ID |
| `station_id` | `UUID` | `NULL REFERENCES public.stations(id) ON DELETE SET NULL` | Station tenant context |
| `actor_id` | `UUID` | `NULL REFERENCES public.profiles(id) ON DELETE SET NULL` | Actor profile |
| `action` | `TEXT` | `NOT NULL` | Operational event code |
| `target_type` | `TEXT` | `NOT NULL` | Target entity category |
| `target_id` | `TEXT` | `NULL` | Target entity identifier |
| `metadata` | `JSONB` | `NOT NULL DEFAULT '{}'::jsonb` | Recursive secret-sanitized payload |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT timezone('utc'::text, now())` | Immutable event timestamp |

### 8.3 Phase 8 Performance & Deduplication Indexes

```sql
-- Audit Center composite search index
CREATE INDEX IF NOT EXISTS idx_audit_logs_station_created 
ON public.audit_logs (station_id, created_at DESC);

-- Audit Center action filtering index
CREATE INDEX IF NOT EXISTS idx_audit_logs_station_action 
ON public.audit_logs (station_id, action, created_at DESC);

-- Export state machine queue index
CREATE INDEX IF NOT EXISTS idx_report_exports_status_station
ON public.report_exports (status, station_id, created_at DESC);

-- Export user history & rate limiting index
CREATE INDEX IF NOT EXISTS idx_report_exports_requested_by_created
ON public.report_exports (requested_by, created_at DESC);

-- Export idempotency lookup index
CREATE INDEX IF NOT EXISTS idx_report_exports_idempotency
ON public.report_exports (station_id, requested_by, export_type, format, created_at DESC);
```

### 8.4 Phase 8 Operational RPCs

| RPC Name | Access Level | Description |
| :--- | :--- | :--- |
| `request_report_export` | Role-verified Member | Validates rate limit ($15/5\text{m}$), payload bounds, checks idempotency (30s window), enqueues export row. |
| `claim_report_export` | Authenticated / Service Role | Row-locked atomic state transition from `PENDING` to `PROCESSING`. |
| `get_report_export_dataset` | Authenticated / Service Role | O(N) single-pass `jsonb_agg` dataset retrieval across all 8 report types. |
| `generate_report_export_csv` | Authenticated / Service Role | Generates UTF-8 BOM CSV with formula injection defense and transitions export to `COMPLETED`. |
| `admin_query_audit_logs` | Station Admin | Paginated, secret-sanitized query of station audit events with search filtering. |
| `admin_update_station` | Station Admin | Governs station timezone (IANA), grace windows, and deactivation safeguards (`P0082`). |
| `admin_cleanup_station_exports` | Station Admin | Station-scoped purge of expired export metadata. |
| `get_station_system_health` | Station Admin | Real-time station telemetry (kiosk fleet health and 24h export queue metrics). |
| `admin_get_station_members` | Station Admin | Member roster with securely resolved emails from `auth.users`. |
| `admin_update_employee_profile` | Station Admin | Updates profile with E.164 phone normalization and unique code enforcement. |
| `admin_update_membership` | Station Admin (EMPLOYEE↔SHIFT_MANAGER only) or Platform Admin | Updates member role/status; Station Admin cannot touch `ADMIN` (`P00105`); last-active-admin (`P0001`). |
| `platform_create_station` | Platform Admin | Transactional station provisioning with unique code and optional idempotency key. |
| `platform_assign_station_admin` | Platform Admin | Grants station `ADMIN` membership. |
| `platform_remove_station_admin` | Platform Admin | Demotes/removes station `ADMIN` with last-admin protection. |
| `platform_list_stations` | Platform Admin | Aggregate station summaries (no per-employee row explosion). |
| `platform_get_overview` | Platform Admin | Network-level counts without employee PII. |
| `cleanup_expired_data` | Service Role Only | Global automated maintenance purging stale challenges and marking expired exports. |





