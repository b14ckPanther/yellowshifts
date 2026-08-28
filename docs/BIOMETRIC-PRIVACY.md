# YellowShifts Phase 5: Biometric Privacy & Data Minimization Architecture

## 1. Core Privacy Principles

YellowShifts adheres to strict **Data Minimization by Architecture** principles across all biometric and identity verification workflows.

### 1.1 Zero Raw Biometric Ingestion
- **PostgreSQL Database**: Contains zero `bytea`, vector embedding arrays, image URLs, or camera frames.
- **Supabase Storage**: No storage buckets exist or are permitted for raw selfies or face images.
- **Client Processing**: All face detection, active/passive liveness checks, and optical feature comparisons occur entirely inside ephemeral memory on the client device or via certified hardware biometrics.

### 1.2 Opaque Provider Subject Identifiers
- When an employee enrolls in biometric assurance, the identity provider returns a pseudo-random, one-way opaque reference ID (e.g. `sbx_subj_1787687...`).
- This subject identifier cannot be reverse-engineered to reconstruct the user's face or physical characteristics.

---

## 2. Consent & Notice Versioning

- **Server-Authoritative Consent**: Biometric enrollment requires explicit user consent before a session is opened.
- **Notice Version Tracking**: The exact version of the privacy disclosure (e.g., `v1.0`, `v2.0_HEBREW_EXP`) is recorded in `employee_identity_profiles.notice_version` and timestamped in `consented_at`.
- **Informed Revocation**: Employees can revoke their biometric profile at any time from the app UI without administrative approval.

```sql
-- Revocation zeroizes the provider reference and marks profile REVOKED
UPDATE public.employee_identity_profiles
SET status = 'REVOKED',
    revoked_at = now(),
    provider_subject_id = NULL
WHERE employee_user_id = auth.uid();
```

---

## 3. Ephemeral Session Cleanup

- **Enrollment Sessions**: Expire automatically after 15 minutes.
- **Presence Proofs**: Expire after 60 seconds.
- **Identity Proofs**: Expire after 120 seconds.
- **Automatic Sweeper RPC**: `cleanup_ephemeral_identity_data()` automatically purges expired tokens and temporary session records.

---

## 4. Regulatory & Enterprise Compliance

| Requirement | Implementation in YellowShifts |
|---|---|
| **GDPR Art. 9 (Special Category Data)** | Explicit opt-in consent recorded; zero centralized raw biometrics stored. |
| **Right to Erasure (GDPR Art. 17)** | Immediate self-service revocation nullifies subject IDs and revokes all active proofs. |
| **Israeli Privacy Protection Law** | Encrypted transport, cryptographic token hashing (`sha256`), and strict row-level security (RLS) tenant isolation. |
| **Audit Provenance** | Immutable append-only audit trail records categorical verification outcomes without biometric leakage. |
