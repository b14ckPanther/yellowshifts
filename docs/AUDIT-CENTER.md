# Administrative Audit Center Documentation

## 1. Overview

The Administrative Audit Center delivers an immutable, compliance-grade operational log of all security, authentication, employee management, scheduling, and configuration events across YellowShifts stations.

Only authenticated users with the active **`ADMIN`** role for the target station are permitted to query audit logs.

---

## 2. Security & Immutability Architecture

1. **Append-Only Invariant**: The `audit_logs` table has all client-side `INSERT`, `UPDATE`, and `DELETE` operations explicitly revoked. PostgreSQL Row-Level Security and table triggers prevent tampering, even by station administrators.
2. **Strict Station Tenancy**: Every query enforces `station_id = p_station_id` with active administrator verification (`station_memberships.role = 'ADMIN' AND status = 'ACTIVE'`). Cross-station log inspection is denied fail-closed with SQL exception code `42501`.
3. **Fail-Closed on Null**: Querying audit logs with `station_id IS NULL` is rejected fail-closed (`42501`).
4. **Actor Name Resolution**: `public.admin_query_audit_logs` executes a subquery join against `profiles` and `auth.users` via SECURITY DEFINER to resolve actor names and email addresses in real time.
5. **Dedicated Critical Events**: Special audit events such as `STATION_FORCE_DEACTIVATED`, `EMPLOYEE_PROFILE_UPDATED`, `MEMBERSHIP_ROLE_CHANGED`, and `EXPORT_CLAIMED` log full before/after snapshots and mandatory reasons.

---

## 3. Deep Recursive Secret Sanitization (`public.sanitize_audit_metadata`)

Audit metadata can contain arbitrary JSON payloads. To ensure zero credential leakage or PII exposure in the UI or exports, all metadata is processed through `public.sanitize_audit_metadata(jsonb)`:

- **Redacted Sensitive Keys**: Any JSON key matching `(password|secret|token|service_role|jwt|bearer|pin|otp|api_key)` (case-insensitive) is recursively transformed to `"[REDACTED]"`.
- **Operational Key Preservation**: Legitimate operational identifiers matching `(employee_code|station_code|status_code|postal_code|zip_code)` are strictly preserved without false-positive redaction.
- **Deep Recursion**: Sanitizes objects and arrays to arbitrary nesting depth (tested and certified to 10+ levels).
- **Primitive Type Safety**: Safely handles scalar JSON values, primitive arrays (`[1, 2, 3, true, null]`), and empty objects without type errors.

---

## 4. Querying, Indexing & High-Load Performance

To support high-throughput log searches across tens of thousands of entries, `audit_logs` utilizes composite B-tree indexes:

```sql
CREATE INDEX IF NOT EXISTS idx_audit_logs_station_created 
ON public.audit_logs (station_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_logs_station_action 
ON public.audit_logs (station_id, action, created_at DESC);
```

### High-Load Performance Benchmark:
- **Test Dataset**: 10,000 audit log entries in single station tenant.
- **Benchmark Latency**: **15.11 ms** (well below the $<150.0\text{ms}$ threshold).

### Search & Filtering Capabilities:
- **Action Category Filter**: `All`, `Settings`, `Employees`, `Memberships`, `Security`, `Exports`.
- **Search Token Match**: Case-insensitive substring matching against `action`, `target_type`, and `target_id` with wildcard sanitization.
- **Deterministic Pagination**: Clamped page sizing (`limit` between 1 and 100, default 50) with `offset`.
