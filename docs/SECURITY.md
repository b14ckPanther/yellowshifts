# YellowShifts — Security & Threat Model

This document outlines the security controls, cryptographic mechanisms, Row Level Security (RLS) enforcement, rate limiting, secret management guidelines, and threat mitigation strategies across all system phases (Phases 1 through 8).

---

## 1. Zero-Trust Architecture & Threat Invariants

1. **Client Untrusted by Default**:
   The Flutter application runs in untrusted client environments (mobile smartphones, station kiosk tablets, desktop web browsers). Any direct database query or RPC call is treated as potentially adversarial.
2. **Zero GPS Authority**:
   Physical presence verification relies strictly on optical line-of-sight challenge scanning. No GPS coordinates, geofences, or location permissions are trusted as attendance authority.
3. **One-Way Cryptographic Credentials**:
   Kiosk device passwords/secrets are stored solely as one-way SHA-256 hashes (`secret_hash`). Raw plaintext secrets are generated once during provisioning or rotation and are never persisted.
4. **Ephemeral Two-Step Presence Cryptography**:
   - **Dynamic QR Challenge**: 30-second TTL dynamic rotating token (`kiosk_qr_challenges`). Uniqueness and expiration are verified on scan.
   - **Single-Use Presence Proof**: 60-second TTL token (`attendance_presence_proofs`) bound strictly to `(employee_user_id, action, station_id)`. Consumed atomically with row-level locks (`FOR UPDATE`) preventing replay attacks.
5. **Global Single-Open-Session Invariant**:
   Enforced at the PostgreSQL storage engine level via a partial unique index:
   ```sql
   CREATE UNIQUE INDEX uq_attendance_single_open_session 
   ON public.attendance_records (employee_user_id) 
   WHERE check_out_time IS NULL;
   ```
6. **Immutable Historical Audit Ledger**:
   - Live schedule assignments freeze shift template snapshots.
   - Attendance check-in freezes shift details and device IDs.
   - Adjustments append immutable records to `public.attendance_corrections`.
   - Client-side `INSERT`, `UPDATE`, `DELETE` are revoked from `public.audit_logs`.
7. **Rate Limiting Protection**:
   - Kiosk authentication: 30 / 5 minutes.
   - QR scan: 30 / 1 minute.
   - Report export requests: 15 / 5 minutes (`42901`).
8. **SECURITY DEFINER & Search Path Pinning**:
   All operational RPC functions execute with `SECURITY DEFINER` and `SET search_path = public, pg_temp` to prevent search-path hijacking attacks. Public/anonymous roles are stripped of execute permissions except where a fail-closed boolean is required (`is_platform_admin`, `get_platform_schema_version`).
9. **Platform Admin is not service_role**:
   Flutter continues to use the public anon key. `PLATFORM_ADMIN` is a database authorization scope. Privileged provisioning uses Edge Functions with server-side service role secrets only.
10. **Station Admin cannot mint Station Admin**:
    Grant/revoke of station `ADMIN` is restricted to active Platform Admins (`P00105`) at trigger, RPC, and Edge Function layers.

---

## 2. Threat Scenarios & Mitigations Matrix

| Threat Scenario | Vector | Mitigation Mechanism | Error / Status |
| :--- | :--- | :--- | :--- |
| **Kiosk Credential Theft via Database Dump** | Attacker reads `kiosk_devices` table | Secrets are hashed with SHA-256 (`secret_hash`). Raw secret cannot be derived. | Non-invertible Hash |
| **Hash-as-Secret Bypass Attack** | Attacker intercepts `secret_hash` and submits it to RPC | RPC computes `digest(p_secret, 'sha256')`. Supplying the hash results in double-hashing and rejection. | `P0019` |
| **Old Kiosk Session Replay After Rotation** | Attacker attempts to use rotated kiosk credential | Credential rotation increments `credential_version` and invalidates all prior QR challenges immediately. | `P0019` / `P0020` |
| **Deactivated Kiosk Mint Attack** | Compromised kiosk attempts to mint challenges | RPC explicitly asserts `kiosk_devices.is_active = true`. | `P0018` |
| **QR Code Photograph / Forwarding Attack** | Employee photographs QR on kiosk and sends it to remote colleague | Dynamic QR challenge has 30-second TTL. Presence proof has 60-second TTL and requires employee user ID authentication. | `P0021` / `P0027` |
| **Cross-Employee Proof Theft** | Employee A scans QR and sends proof token to Employee B | Proof token is bound to `employee_user_id`. When Employee B calls RPC, user ID mismatch triggers instant rejection. | `P0028` |
| **Proof Action Swapping Attack** | Employee attempts to use a `CHECK_IN` proof token to execute `CHECK_OUT` | Proof record explicitly specifies `action`. Check-out RPC requires `action = 'CHECK_OUT'`. | `P0029` |
| **Proof Double-Spend / Concurrency Race** | Employee submits duplicate check-in requests in parallel threads | Proof row is locked with `SELECT ... FOR UPDATE` and checked for `used_at IS NOT NULL`. Exactly 1 succeeds; second is rejected. | `P0026` |
| **Multi-Station Clock-In Double-Booking** | Employee attempts to clock in at Station B while open at Station A | Partial unique index and pre-check detect existing open record globally across all stations. | `P0023` |
| **Unauthorized Attendance Records Forgery** | Employee attempts direct `INSERT` on `attendance_records` | Table RLS allows direct `SELECT` only for own records. Direct `INSERT`/`UPDATE` denied to client roles. | `42501` |
| **Manual Correction Audit Ledger Tampering** | Admin attempts direct `UPDATE` or `DELETE` on `attendance_corrections` | RLS denies all direct `INSERT`, `UPDATE`, `DELETE` operations. Ledger writes only occur via `correct_attendance_record` RPC. | `42501` |
| **Correction Negative/Zero Interval Forgery** | Admin sets check-out time before check-in time | RPC asserts `p_new_check_out > p_new_check_in` (minimum 1 second). | `P0034` |
| **Correction Overlap Forgery** | Admin adjusts record to overlap with another completed record | RPC checks half-open interval overlap `(p_new_check_in < check_out_time AND check_in_time < p_new_check_out)`. | `P0035` |
| **CSV Formula Injection Attack** | Attacker embeds `=cmd\|' /C calc'` in employee name or notes | `public.escape_csv_field` strips whitespace, detects triggers (`=+\-@\t\r\n\|%\uFF1D\uFF0B\uFF0D\uFF20`), prepends `'`, and quotes. | Neutralized CSV |
| **Deep Metadata Secret Leakage** | Deep JSON objects contain passwords, tokens, or JWTs | `public.sanitize_audit_metadata` recursively sanitizes 10+ levels of objects and arrays, replacing secrets with `[REDACTED]`. | Zero Secret Leaks |
| **Mid-Lifecycle Demotion Privilege Retainment** | Admin requested sensitive export, got demoted before generation | `validate_export_requester_authorization` re-verifies caller membership and role capability dynamically at generation time. | `42501` |
| **Cross-Station Export Claim IDOR** | Foreign admin attempts to claim or generate Station A export | Server verifies caller has active membership and admin role at the target station. | `42501` |
| **Export Concurrency Double-Generation Race** | Multiple workers attempt to claim the same pending export | `claim_report_export` executes atomic `SELECT ... FOR UPDATE` and transitions status to `PROCESSING`. | Exactly 1 Worker |
| **Unsafe Station Deactivation Attack** | Admin deactivates station with open clocked-in sessions | Database detects active sessions (`check_out_time IS NULL`) and raises `P0082`. Overriding requires reason $\ge 10$ chars. | `P0082` / `22000` |
| **Export Flooding & DoS Attack** | Automated script spams `request_report_export` | Database rate limiter rejects callers with $>15$ requests per 5 minutes. Large filter payloads ($>8\text{KB}$) rejected. | `42901` / `22000` |
| **Last-Admin Station Lockdown Attack** | Admin attempts to demote or deactivate the last admin | Trigger `prevent_last_admin_demotion` blocks the update fail-closed. | `P0001` |
| **Direct Audit Log Tampering** | Authenticated client executes `INSERT`, `UPDATE`, or `DELETE` on `audit_logs` | Table mutations revoked; table level RLS denies client modification. | `42501` |
| **Expired Export Download Bypass** | Client attempts to download export after 24h expiration | Database and Edge Function check `expires_at <= now()` and raise `P0081`. | `P0081` |
| **Zero Payroll & Wage Leakage** | Client attempts to access wage, hourly rate, or salary fields | Zero financial or payroll columns exist in the database model, analytical RPCs, or export datasets. | Absolute Invariant |
