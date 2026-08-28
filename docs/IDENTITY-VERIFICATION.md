# YellowShifts Phase 5: Identity Verification & Biometric Gate Architecture

## 1. Executive Summary

Phase 5 introduces an optional, privacy-first biometric identity assurance gate to the YellowShifts platform. Built strictly on top of the Phase 4 cryptographic station presence foundation, Phase 5 enforces identity verification without ever storing raw face images, video frames, vector templates, or facial embeddings in PostgreSQL or cloud object storage.

```
+-----------------------------------------------------------------------------------+
|                            PHASE 5 IDENTITY LIFECYCLE                             |
+-----------------------------------------------------------------------------------+
|                                                                                   |
|   1. STATION POLICY: [ DISABLED | CHECK_IN_ONLY | CHECK_IN_AND_CHECK_OUT ]        |
|                                                                                   |
|   2. EMPLOYEE ENROLLMENT (Self-Service with Consent v1.0)                         |
|      start_identity_enrollment() -> Local Liveness -> complete_identity_enrollment()|
|      * Server stores ONLY opaque provider_subject_id (No images/embeddings)       |
|                                                                                   |
|   3. STATION PRESENCE SCAN (Phase 4 Foundation)                                  |
|      Scan Kiosk Rotating QR -> attendance_presence_proofs (60s TTL)              |
|                                                                                   |
|   4. IDENTITY VERIFICATION GATE                                                   |
|      start_identity_verification(presence_proof_token)                            |
|        |                                                                          |
|        v                                                                          |
|      Local Liveness & Face Matching on Device (Sandbox / Enterprise SDK)          |
|        |                                                                          |
|        v                                                                          |
|      complete_identity_verification(attempt_id, is_verified)                      |
|        |                                                                          |
|        v                                                                          |
|      identity_verification_proofs (120s TTL, Bound to Employee+Station+Action)   |
|                                                                                   |
|   5. ATOMIC CHECK-IN / CHECK-OUT EXECUTION                                        |
|      check_in_with_presence_proof(presence_token, identity_token)                 |
|      * Atomically consumes Presence Proof + Identity Proof with FOR UPDATE locks  |
|      * Sets verification_method = 'QR_PLUS_IDENTITY' (or 'MANUAL_ADMIN')         |
|                                                                                   |
+-----------------------------------------------------------------------------------+
```

---

## 2. Security Invariants & Zero Silent Downgrade

| Invariant ID | Rule | Description |
|---|---|---|
| **INV-P5-01** | **Data Minimization** | Database schema strictly forbids `bytea`, image payloads, embedding arrays, or similarity score columns. |
| **INV-P5-02** | **Fail-Closed in Production** | In production (`APP_ENV=production`), if identity verification is required and only sandbox providers exist, attendance must fail closed with a configuration error. |
| **INV-P5-03** | **Single-Use Identity Tokens** | `identity_verification_proofs` are single-use (`used_at IS NULL`), expire within 60–120 seconds, and are strictly bound to `(employee_user_id, station_id, presence_proof_id, action)`. |
| **INV-P5-04** | **Cross-Token Mixing Defense** | An identity proof token generated for presence proof $A$ cannot be presented with presence proof $B$. |
| **INV-P5-05** | **Identity Isolation** | Profile $A$ cannot authorize check-in for employee $B$, even on the same station. |
| **INV-P5-06** | **Action Binding** | A `CHECK_OUT` identity proof cannot authorize a `CHECK_IN` action. |
| **INV-P5-07** | **Atomic Lock Serialization** | Check-in RPC executes row-level `FOR UPDATE` locks on the presence proof, identity proof, and user profile simultaneously. |
| **INV-P5-08** | **Admin Manual Exception** | Manager overrides require in-person fresh station presence challenge and mandatory reason ($\ge 3$ characters), marking provenance as `MANUAL_ADMIN`. |

---

## 3. Database Schema Overview (Migration 007)

### Enums
- `identity_verification_mode`: `DISABLED`, `CHECK_IN_ONLY`, `CHECK_IN_AND_CHECK_OUT`
- `identity_profile_status`: `NOT_ENROLLED`, `PENDING`, `ACTIVE`, `REVOKED`, `FAILED`
- `enrollment_session_status`: `PENDING`, `COMPLETED`, `EXPIRED`, `CANCELLED`, `FAILED`
- `identity_verification_result`: `VERIFIED`, `NOT_VERIFIED`, `INCONCLUSIVE`

### Core Tables
1. **`stations.identity_verification_mode`**: Configurable per station by station admins.
2. **`employee_identity_profiles`**: Contains employee consent, notice version, enrollment timestamp, and opaque `provider_subject_id`.
3. **`identity_enrollment_sessions`**: Ephemeral enrollment challenges (15-minute TTL).
4. **`identity_verification_attempts`**: Audit trail of verification attempts with categorical failure codes (`FACE_MISMATCH`, `LIVENESS_FAILED`, `CAMERA_UNAVAILABLE`).
5. **`identity_verification_proofs`**: High-security, single-use proof ledger (120s TTL) consumed atomically during attendance recording.
6. **`attendance_records.identity_verification_proof_id`**: Foreign key linking attendance to the authoritative verification proof.

---

## 4. Error Code Reference

| Error Code | Meaning |
|---|---|
| `P0040` | Station identity policy requires biometric verification proof |
| `P0041` | Provider identifier is required |
| `P0042` | Enrollment session not found |
| `P0043` | Enrollment session is not pending |
| `P0044` | Enrollment session has expired |
| `P0045` | Provider subject identifier is required on success |
| `P0046` | Active identity profile already exists for this subject ID |
| `P0047` | Identity profile is revoked or inactive |
| `P0048` | Verification attempt not found |
| `P0049` | Verification attempt has already been finalized |
| `P0050` | Invalid identity verification proof token |
| `P0051` | Identity verification proof has already been used |
| `P0052` | Identity verification proof has expired |
| `P0053` | Identity verification proof belongs to another employee |
| `P0054` | Identity verification proof belongs to another station |
| `P0055` | Identity verification proof is not bound to this presence challenge |
| `P0056` | Identity verification proof action mismatch |
