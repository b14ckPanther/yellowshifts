# YellowShifts — Engineering Roadmap

This roadmap defines the sequenced implementation phases for the YellowShifts workforce operations platform.

---

## Phase Overview

### Phase 0 — Greenfield Foundation & Platform Core (COMPLETED & AUDITED)
- Greenfield Flutter architecture (iOS, Android, Web).
- Multi-station PostgreSQL schema, RLS policies, and helper functions in Supabase.
- Semantic design token system derived from official station brand palette.
- Dynamic bilingual typography (Ubuntu for English, Heebo for Hebrew) with ARB localization.
- Responsive adaptive shells (Compact, Medium, Expanded).
- Riverpod state management and go_router routing with auth & station context guards.
- Zero mock data architecture connected to real Supabase tables.

---

### Phase 1 — Secure Admin Provisioning, Authentication & Station Membership Administration (COMPLETED & AUDITED)
- Server-side employee account provisioning via Edge Functions (`admin-create-employee`).
- Password reset and account activation lifecycle.
- Station Admin employee activation/disabling and membership invitation flows.
- Multi-station membership assignment and station switching enhancements.
- Audited RLS and database security boundaries.

---

### Phase 2 — Shift Templates, Operational Station Config, Manager Permissions & Availability (COMPLETED & AUDITED)
- Dynamic station-defined shift templates (daytime and cross-midnight).
- Weekly availability periods with frozen shift template snapshots.
- Granular capability overrides for Shift Managers (`shift_templates.manage`, `availability.period.open`, `schedule.manage`, `schedule.publish`).
- Employee weekly availability submission interface and touch matrix.
- Manager team availability review matrix with real-time submission progress.

---

### Phase 3 — Shift Scheduling, Assignment Engine, Draft/Publish Lifecycle, Conflict Detection & My Shifts (COMPLETED & AUDITED)
- Weekly work schedule domain generated from Phase 2 frozen availability snapshots.
- Accurate timezone and cross-midnight shift instant calculation.
- Staffing requirement tracking (`UNDERSTAFFED`, `FULLY_STAFFED`, `OVERSTAFFED`).
- Server-authoritative candidate resolution with availability and conflict state analysis.
- Multi-station global overlap prevention serialized via database profile row locking.
- Optimistic Concurrency Control (OCC) with atomic version verification.
- Atomic assignment move and remove operations.
- Pre-publish validation with hard error lockout and explicit warning confirmations.
- Post-publish revision tracking in `work_schedule_changes` with mandatory change reason.
- Employee "My Shifts" self-service view with zero draft leakage.
- Responsive Manager Schedule Builder across Compact, Medium, and Expanded viewports.

---

### Phase 4 — Live Attendance, Station Kiosk, Dynamic QR Presence Proof & Attendance Integrity (COMPLETED & AUDITED)
- Physical station kiosk provisioning with one-way SHA-256 secret hashing and zero-plaintext storage.
- 30-second dynamic rotating QR presence challenge with collision-free 6-character display fallback.
- 60-second single-use cryptographic presence proofs bound strictly to `(employee_user_id, action, station_id)`.
- Global single-open-session invariant enforced via PostgreSQL partial unique index (`uq_attendance_single_open_session`).
- Server-authoritative check-in / check-out with frozen schedule snapshots (`shift_name_snapshot`, `schedule_version_at_check_in`).
- Real UTC elapsed minutes duration calculation with zero arbitrary work caps and accurate DST handling.
- Manager live attendance KPI dashboard and realtime workforce roster with station-scoped updates.
- Admin manual attendance correction workflow with strict duration/reason validation and immutable ledger (`attendance_corrections`).
- Sliding window rate limiting defenses (`attendance_rate_limit_attempts`) protecting against kiosk auth and QR scan floods.
- Cross-platform Flutter UI (Kiosk Display, Employee Attendance, Manager Live Roster, Kiosk Devices) with 100% WASM compliance.

---

### Phase 5 — Identity Verification, Account Assurance, Optional Liveness, Privacy-First Biometric Gate & Attendance Identity Binding (COMPLETED & AUDITED)
- Privacy-first data minimization: Zero raw facial images, videos, embeddings, or vector templates stored in PostgreSQL or Supabase Storage.
- Provider abstraction with Sandbox provider failing closed in production (`APP_ENV=production`) with zero silent downgrades.
- Station-level verification policy modes: `DISABLED`, `CHECK_IN_ONLY`, `CHECK_IN_AND_CHECK_OUT`.
- Server-authoritative employee consent recording (`consented_at`, `notice_version`) and self-service revocation with subject reference nullification.
- 120-second single-use cryptographic identity proofs bound strictly to `(employee_user_id, station_id, presence_proof_id, action)`.
- Atomic gate check-in / check-out with row-level locks, recording `QR_PLUS_IDENTITY` verification method provenance.
- Station Manager in-person manual exception flow (`MANUAL_ADMIN`) requiring fresh presence token challenge and mandatory reason ($\ge 3$ characters).
- Comprehensive Flutter responsive UI (`EmployeeIdentityVerificationScreen`, `ManagerIdentityPolicyScreen`, `IdentityOverrideModal`, `CameraLivenessOverlay`).
- 100% verified across 46+ comprehensive SQL adversarial scenarios, 12 security invariant tests, 188 Flutter unit tests, and Flutter WASM production builds.

---

### Phase 6 — Notifications, Operational Alerts, Reminders, Transactional Outbox & Realtime Delivery Infrastructure (COMPLETED, ADVERSARIALLY AUDITED & CERTIFIED)
- Authoritative in-app notification inbox (`public.notifications`) and domain event ledger (`public.notification_events`).
- Transactional outbox architecture ensuring business operations commit immediately while delivery jobs decouple safely.
- Column-level immutability trigger protection (`check_notification_column_immutability`) blocking client manipulation of title, body, priority, or mandatory flags.
- Multi-station tenant isolation guaranteeing zero cross-station alert leakage for station managers and staff.
- Automatic operational alert emission for manager visibility on check-in, check-out, lateness, and missed check-in events.
- Schedule publication and revision notification integration (`SHIFT_ASSIGNED`, `SHIFT_REMOVED`, `SHIFT_CHANGED`, `SCHEDULE_REVISED`) with target-scoped recipient routing.
- Weekly availability submission reminder evaluator with deadline urgency stages and epoch-based deduplication across extensions.
- Server-authoritative kiosk health transition evaluator with 15-minute onboarding grace window and incident-scoped anti-storm deduplication (`kiosk_health_states`).
- Mandatory security/compliance alert bypass preventing opt-out of critical audit events, with guaranteed indefinite retention during cleanup.
- Keyset cursor forward pagination `(created_at, id) < (cursor_created_at, cursor_id)` with deterministic tie-breaking and client list deduplication.
- Push device registry with SHA-256 token indexing and service-role restricted raw push token storage for external provider dispatch.
- Concurrency-safe delivery worker claiming via `SELECT ... FOR UPDATE SKIP LOCKED`, lease tokens, deterministic idempotency keys, and exponential backoff retries.
- Polished, responsive Flutter notification experience (`NotificationCenterScreen`, `NotificationPreferencesScreen`, `NotificationBadgeIcon`, `NotificationTile`).
- 100% verified across 126 Phase 6 SQL scenarios (16 security + 60 comprehensive audit + 50 adversarial audit V2), 332 total SQL tests across all phases, 200 Flutter unit/widget tests, and Flutter WASM production build.

---

### Phase 7 — Worked Hours Analytics, Attendance History, Operational Reporting & Manager Insights (COMPLETED, INDEPENDENTLY AUDITED & REMEDIATED)
- Server-authoritative worked hours analytics and attendance aggregation engine (Migrations 011 & 012).
- Strict Zero Payroll Invariant: strictly operational labor metrics (minutes, completed shifts, late shifts, lateness frequency, correction counts) with zero financial/wage/tax fields.
- Authoritative source of truth in `attendance_records` (`worked_minutes >= 0`), preserving historical snapshot integrity and inactive member audit trails.
- Active open session isolation with real-time elapsed time derivation and anomaly flagging (>16 hours) without forced termination.
- 6 server-authoritative `STABLE` `SECURITY DEFINER` RPCs with `search_path = public, pg_temp` for personal attendance summaries, paginated history, station KPIs, workforce breakdowns, daily operational boards, and employee correction ledgers.
- High-performance query optimization with composite functional expression indexes (`idx_attendance_records_station_opdate`), achieving 34.45ms execution on 300-employee / 25,214-record datasets.
- Executive station KPIs: On-time arrival rate (%), repeated lateness alerts ($\ge 3$ late shifts), manual adjustment audit counts, active workforce counts, shortage counts, and unattended metrics.
- Hardened Anti-IDOR boundary, deterministic chronological ledger ordering (`ac.created_at ASC, ac.id ASC`), timezone fallback resolution, and strict date range bound validation.
- Responsive, bilingual Flutter experience across Mobile, Tablet, and Desktop (`EmployeeMyHoursScreen`, `ManagerReportsScreen`, `ActiveSessionCard`, `KpiSummaryCard`, `EmployeeBreakdownTable`, `DailyShiftBoard`, `EmployeeDetailSheet`).
- 100% verified across 109 Phase 7 SQL tests (20 security + 26 comprehensive audit + 63 adversarial audit V2), 395 total SQL tests across all phases, 215 Flutter unit/widget tests, clean `flutter analyze`, Web release production build, and 100% synchronized remote Supabase database.

---

### Phase 8 — Server-Side Exports (PDF & CSV), Administrative Audit Center, Station Governance, Data Retention & Real-Time Telemetry (COMPLETED, INDEPENDENTLY AUDITED & REMEDIATED)
- Server-side multi-format export engine supporting true binary PDFs (`%PDF-1.4`, standard A4 geometry, Hebrew visual bidi text reversal, English LTR, header/footer pagination with "Page X of Y") and UTF-8 BOM CSVs (`\uFEFF`).
- Re-authorization at generation & retrieval time (`validate_export_requester_authorization`), preventing privilege retention if demoted or revoked mid-lifecycle.
- Strict concurrency state machine (`PENDING` $\to$ `PROCESSING` $\to$ `COMPLETED` / `FAILED` / `EXPIRED`) with atomic row locking (`claim_report_export`) and 30-second idempotency caching.
- Air-tight CSV formula injection defense (`public.escape_csv_field`) neutralizes `=`, `+`, `-`, `@`, `\t`, `\r`, `\n`, `|`, `%`, leading whitespace, and fullwidth Unicode triggers (`\uFF1D`, `\uFF0B`, `\uFF0D`, `\uFF20`).
- Deep recursive secret scrubber (`public.sanitize_audit_metadata`) cleans nested JSON objects and arrays of arbitrary depth, replacing credentials (`password`, `token`, `service_role`, `jwt`, `pin`, `api_key`) with `[REDACTED]` while preserving operational identifiers (`employee_code`, `station_code`).
- Station governance and safe deactivation safeguards (`P0082`): hard block if active attendance sessions exist; force override requires mandatory $\ge 10$-character reason and logs `STATION_FORCE_DEACTIVATED`.
- Permanent data retention invariant: historical attendance records, corrections, and shift logs are never deleted. Global cleanup restricted strictly to `service_role`.
- Station administration enhancements: E.164 phone normalization, email visibility from `auth.users`, and last-active-admin protection (`P0001`).
- Real-time station telemetry (`get_station_system_health`) reporting kiosk fleet status and 24h export queue activity.
- High-load performance benchmarks: 10,000 audit logs queried in **15.11ms** (<150ms); 5,000 export dataset rows aggregated via C-speed `jsonb_agg` in **27.95ms** (<500ms).
- Responsive Flutter experience across Compact, Medium, and Expanded viewports (`AuditCenterScreen`, `StationSettingsScreen`, `ExportModal`, `EmployeeManagementScreen`).
- 100% verified across 135 Phase 8 SQL scenarios (26 security + 23 admin CRUD + 22 benchmark + 64 comprehensive adversarial audit V2), 485+ total SQL tests across all phases, 239 Flutter unit/widget tests, clean `flutter analyze`, Web release build, Web WASM dry-run, and 100% synchronized remote Supabase database and Edge Functions.

---

### Phase 9 — Production Startup Lifecycle, Schema Compatibility, Semantic Versioning & Reliability Hardening (COMPLETED & CERTIFIED)
- Server-authoritative platform schema compatibility lifecycle (`get_platform_schema_version`).
- Rigorous SemVer 2.0.0 client precedence evaluator (`SemanticVersion`) preventing lexicographical sorting bugs (`1.9.0` vs `1.10.0`).
- Connectivity-aware startup state machine with `StartupPhase.clientOutdated` and `StartupPhase.schemaIncompatible` error boundaries and update CTAs.
- Privileged background operational recovery (`recover_stuck_operational_jobs()`) restricted strictly to `service_role` (`42501` enforcement), reclaiming zombie report exports (>30m) and stuck notification leases (>15m).
- Safe system maintenance audit logging resolving `actor_id` cleanly for background worker cron tasks without user profiles.
- Station system health telemetry (`get_station_system_health`) reporting kiosk online/offline status, export activity, stale sessions, identity verification attempts, and storage bucket health without leaking secrets or tokens.
- Additive Migration 017 applied cleanly without altering canonical migrations 001–016.
- 100% verified across 57 Phase 9 V2 adversarial scenarios, 23 security tests, 271 Flutter tests, clean `flutter analyze`, Web release and WASM builds.

---

### Phase 10 — Production Deployment, Infrastructure & Go-Live Readiness (COMPLETED & CERTIFIED)
- Formal production environment contract with fail-closed validation (`AppConfig.validateConfig`).
- Release identity integration (`1.0.0+10`, minimum schema version `20260825000017`).
- GitHub Actions CI pipeline ([`.github/workflows/ci.yml`](../.github/workflows/ci.yml)) with automated static analysis, Dart formatting, Flutter tests, Web builds, WASM compilation, SQL regression suites, bundle secret scanning, and zero-payroll verification.
- Automated client bundle secret leak scanner (`scripts/audit_bundle_secrets.py`) and zero-payroll scanner (`scripts/verify_zero_payroll.py`).
- Automated disaster recovery database restore drill (`scripts/restore_drill.py`) proving 100% schema reproducibility across 33 public tables.
- Complete operational runbooks: Backup & Restore (`docs/BACKUP_AND_RESTORE.md`), Monitoring & Alerting (`docs/MONITORING_AND_ALERTING.md`), Web Security Headers (`docs/WEB_SECURITY_HEADERS.md`), Kiosk Operations (`docs/KIOSK_OPERATIONS.md`), Production Support (`docs/PRODUCTION_SUPPORT.md`), Data Retention (`docs/DATA_RETENTION.md`), Release Checklist (`docs/PRODUCTION_RELEASE_CHECKLIST.md`), and Pilot Readiness (`docs/PILOT_READINESS.md`).
- 100% verified across 77 Phase 10 comprehensive adversarial audit scenarios, 26 Phase 10 security tests, 13 cross-phase SQL test suites, 277 Flutter tests, and synchronized remote Supabase environment.

---

### Phase 10 Independent Adversarial Audit & Remediation (COMPLETED & CERTIFIED)
- Independent certification of the existing station-scoped architecture prior to platform administration.

---

### Phase 10.5 — Platform Administration, Station Provisioning & Global Operations (INDEPENDENTLY CERTIFIED — READY FOR PRE-PILOT SETUP)
- Global `PLATFORM_ADMIN` stored in `public.platform_admins`, separate from `station_memberships`.
- In-app station provisioning (`platform-create-station`) and Station Manager assignment/removal.
- Server-side rule: Station Admin may only change `EMPLOYEE` ↔ `SHIFT_MANAGER` (`P00105`).
- Dedicated Platform Administration UI (`/platform`) with operating-station context.
- Independent Phase 10.5 audit completed: [`docs/PHASE-10-5-INDEPENDENT-AUDIT.md`](PHASE-10-5-INDEPENDENT-AUDIT.md).

---

## Next Milestone: Pre-Pilot Setup, then Controlled Real-Station Pilot

The following remain **pending** (not started, not complete):

1. **Controlled Real-Station Pilot**
2. **Final Production Certification**
