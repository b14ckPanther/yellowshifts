# YellowShifts — Production Backup & Restore Strategy

## 1. Executive Summary

Data integrity and disaster resilience in YellowShifts are anchored on PostgreSQL logical and physical backup capabilities, immutable schema migrations, and automated restore drill testing.

---

## 2. Backup Architecture & Policies

| Backup Type | Mechanism | Frequency | Retention | Scope | Responsible Entity |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Point-in-Time Recovery (PITR)** | PostgreSQL Write-Ahead Logs (WAL) via Supabase Pro/Enterprise | Continuous (every minute) | 7 to 30 days | Entire PostgreSQL Database | Supabase Platform Infrastructure |
| **Daily Logical Snapshot** | Automated `pg_dump` snapshot | Every 24 hours (02:00 UTC) | 30 days | All Schemas (`public`, `auth`, `storage`) | Automated Scheduled Pipeline |
| **Pre-Migration Snapshot** | Manual / CLI snapshot prior to deploying schema migrations | Ad-hoc (before `supabase db push`) | Retained until release verified | Full Database State | Deployment Operator |
| **Storage Object Backup** | Multi-zone replica / cross-region bucket replication | Continuous | Configured retention | Storage Buckets (`reports`, `profiles`) | Storage Infrastructure |

---

## 3. Automated Restore Drill Automation

**Proven locally:** schema reconstruction from files in `supabase/migrations/` via [`scripts/restore_drill.py`](../scripts/restore_drill.py). **Not proven:** restore of a real production backup into a new instance.

The restore drill applies **every** SQL file in `supabase/migrations/`, including `20260828000001_fix_kiosk_audit_log_columns.sql`. That file is source-controlled and **not deployed** to the linked remote project (audit decision: KIOSK FIX SAFE TO DEFER). Local reconstruction from Git is therefore not identical to the remote applied set (`001`–`019`).

A backup is only as reliable as its tested restoration. YellowShifts includes an automated restore drill script:

```bash
python3 scripts/restore_drill.py
```

### Verification Steps Executed:
1. Provisions an isolated fresh PostgreSQL database.
2. Instantiates all canonical migrations monotonically (`001` through `latest`).
3. Probes the public schema version endpoint (`get_platform_schema_version`).
4. Reconstructs all 33 public tables and associated partial unique indexes.
5. Executes the service-role maintenance recovery routine (`recover_stuck_operational_jobs`).

---

## 4. Production Disaster Recovery Procedure

### Scenario A: Accidental Data Corruption or Malformed Update
1. Identify the exact UTC timestamp prior to the corruption incident from `public.audit_logs`.
2. Access the Supabase Dashboard -> Database -> Backups.
3. Select Point-in-Time Recovery (PITR) and specify target UTC timestamp.
4. Execute restore to a new target instance or restore in-place during an approved maintenance window.
5. Verify schema compatibility endpoint:
   ```bash
   curl -s -X POST 'https://<PROJECT_URL>/rest/v1/rpc/get_platform_schema_version'
   ```

### Scenario B: Full Database Re-provisioning
1. Provision a fresh PostgreSQL database instance.
2. Apply all canonical migrations:
   ```bash
   supabase db push
   ```
3. Restore data tables using `pg_restore` (excluding schema definitions to preserve migration tracking).
4. Run the post-deployment smoke test suite.
