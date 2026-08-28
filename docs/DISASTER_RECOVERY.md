# YellowShifts — Disaster Recovery & Incident Response Guide

## 1. Overview & Recovery Objectives

This document provides step-by-step procedures for handling critical system outages, network partitions, backend failures, and data corruption scenarios.

- **Recovery Point Objective (RPO)**: < 1 minute (Continuous write replication + immutable audit trail).
- **Recovery Time Objective (RTO)**: < 15 minutes for Edge Function & Database failovers.

---

## 2. Failure Scenarios & Standard Operating Procedures

### Scenario A: Supabase Gateway Outage or Network Disconnection
**Symptoms**: Client displays red banner "Offline — Read Only" / `LucideIcons.wifiOff`. Kiosk QR displays blur with "Kiosk Disconnected from Network".

**Client-Side Resilience**:
- Read-only data cached in local browser state allows viewing scheduled shifts and historical logs.
- Attendance mutations fail-closed with localized user feedback.
- When network connectivity returns, `ConnectivityNotifier` automatically transitions through `reconnecting` -> `online` without requiring full browser reload.

**Operator Action**:
1. Check Supabase status page (`status.supabase.com`).
2. Verify database connection pooling (PgBouncer port 6543 vs direct 5432).
3. If gateway is unresponsive, restart the connection pool via Supabase dashboard.

---

### Scenario B: Stuck Background Jobs (Report Exports / Notifications)
**Symptoms**: Export status remains in `PROCESSING` indefinitely or notification delivery queue accumulates.

**Resolution Action**:
Execute the automated recovery RPC via database console or CLI:
```sql
SELECT public.recover_stuck_operational_jobs();
```
- Automatically resets any notification delivery jobs older than 15 minutes to `PENDING`.
- Automatically terminates any report export running longer than 30 minutes with `FAILED` status and `LEASE_TIMEOUT` code.

---

### Scenario C: Kiosk Device Compromise or Lost Tablet
**Symptoms**: A physical kiosk device is lost, stolen, or suspected of tampering.

**Resolution Action (Immediate Admin Action)**:
1. Log into YellowShifts Admin Portal.
2. Navigate to **Station Settings -> Kiosk Devices**.
3. Select the affected device and click **Deactivate Kiosk Device** or rotate its credentials.
4. Database immediately updates `is_active = false` and increments `credential_version`.
5. All future QR challenge requests from that device are rejected immediately (`P0020 / 42501`).

---

### Scenario D: Accidental Station Deactivation
**Safety Invariant**: The database enforces strict invariant `P0082`: A station CANNOT be deactivated if there are currently open attendance sessions or scheduled shifts within active windows.

**Re-Activation Procedure**:
```sql
UPDATE public.stations
SET is_active = true,
    updated_at = now()
WHERE id = '<station-uuid>';
```

---

### Scenario E: Last Admin Lockout Protection
**Safety Invariant**: Database trigger `prevent_last_admin_demotion` enforces `P0001`: An administrator cannot be deleted, demoted, or deactivated if they are the sole remaining active admin of that station.

**Emergency Break-Glass Procedure (Service Role Only)**:
If all admins lose access to their email accounts, provision a new administrator using privileged service role credentials:
```sql
INSERT INTO public.station_memberships (station_id, user_id, role, status)
VALUES ('<station-uuid>', '<new-user-uuid>', 'ADMIN', 'ACTIVE')
ON CONFLICT (station_id, user_id)
DO UPDATE SET role = 'ADMIN', status = 'ACTIVE';
```
