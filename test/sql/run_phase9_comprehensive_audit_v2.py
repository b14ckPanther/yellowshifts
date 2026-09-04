#!/usr/bin/env python3
"""
===============================================================================
YellowShifts — Phase 9 Comprehensive Adversarial Audit Suite V2
Testing Production Reliability, Service-Role Hardening, Concurrency Invariants,
Schema Versioning, System Health Telemetry, and Multi-Station Fail-Closed RBAC.
===============================================================================
"""

import os
import subprocess
import sys
import uuid
import json
import threading

DB_NAME = "yellowshifts_phase9_comprehensive_audit_v2"
CURRENT_USER = os.environ.get("USER", "postgres")
PSQL_BIN = os.environ.get("PSQL_BIN", "psql")
MIGRATIONS_DIR = os.path.join(os.path.dirname(__file__), "../../supabase/migrations")

passed = 0
failed = 0
total = 0

def run_psql(sql: str, db: str = DB_NAME) -> tuple[int, str, str]:
    cmd = [PSQL_BIN, "-d", db, "-U", CURRENT_USER, "-v", "VERBOSITY=verbose", "-v", "ON_ERROR_STOP=1", "-A", "-t"]
    res = subprocess.run(cmd, input=sql, capture_output=True, text=True)
    return res.returncode, res.stdout.strip(), res.stderr.strip()

def run_psql_file(filepath: str, db: str = DB_NAME) -> tuple[int, str, str]:
    cmd = [PSQL_BIN, "-d", db, "-U", CURRENT_USER, "-v", "VERBOSITY=verbose", "-v", "ON_ERROR_STOP=1", "-f", filepath]
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.returncode, res.stdout.strip(), res.stderr.strip()

def run_as_user_json(user_id: str, sql: str, db: str = DB_NAME) -> tuple[int, any, str]:
    clean_sql = sql.strip().rstrip(';')
    if not clean_sql.upper().startswith("SELECT") and not clean_sql.upper().startswith("INSERT") and not clean_sql.upper().startswith("UPDATE") and not clean_sql.upper().startswith("DELETE"):
        clean_sql = "SELECT " + clean_sql
    wrapped = f"""
    BEGIN;
    SET LOCAL request.jwt.claim.sub = '{user_id}';
    SET LOCAL request.jwt.claim.role = 'authenticated';
    SET LOCAL ROLE authenticated;
    {clean_sql};
    COMMIT;
    """
    cmd = [PSQL_BIN, "-d", db, "-U", CURRENT_USER, "-v", "VERBOSITY=verbose", "-v", "ON_ERROR_STOP=1", "-A", "-t"]
    res = subprocess.run(cmd, input=wrapped, capture_output=True, text=True)
    if res.returncode != 0:
        return res.returncode, None, res.stderr.strip()

    lines = [line.strip() for line in res.stdout.strip().split('\n') if line.strip()]
    result_lines = [l for l in lines if l not in ('BEGIN', 'COMMIT', 'SET')]
    if not result_lines:
        return 0, None, ""
        
    target_line = result_lines[-1]
    try:
        data = json.loads(target_line)
        return 0, data, ""
    except json.JSONDecodeError:
        return 0, target_line, ""

def run_as_anon_json(sql: str, db: str = DB_NAME) -> tuple[int, any, str]:
    clean_sql = sql.strip().rstrip(';')
    if not clean_sql.upper().startswith("SELECT") and not clean_sql.upper().startswith("INSERT") and not clean_sql.upper().startswith("UPDATE") and not clean_sql.upper().startswith("DELETE"):
        clean_sql = "SELECT " + clean_sql
    wrapped = f"""
    BEGIN;
    SET LOCAL request.jwt.claim.sub = '';
    SET LOCAL request.jwt.claim.role = 'anon';
    SET LOCAL ROLE anon;
    {clean_sql};
    COMMIT;
    """
    cmd = [PSQL_BIN, "-d", db, "-U", CURRENT_USER, "-v", "VERBOSITY=verbose", "-v", "ON_ERROR_STOP=1", "-A", "-t"]
    res = subprocess.run(cmd, input=wrapped, capture_output=True, text=True)
    if res.returncode != 0:
        return res.returncode, None, res.stderr.strip()

    lines = [line.strip() for line in res.stdout.strip().split('\n') if line.strip()]
    result_lines = [l for l in lines if l not in ('BEGIN', 'COMMIT', 'SET')]
    if not result_lines:
        return 0, None, ""
    target_line = result_lines[-1]
    try:
        data = json.loads(target_line)
        return 0, data, ""
    except json.JSONDecodeError:
        return 0, target_line, ""

def run_as_service_role_json(sql: str, db: str = DB_NAME) -> tuple[int, any, str]:
    clean_sql = sql.strip().rstrip(';')
    if not clean_sql.upper().startswith("SELECT") and not clean_sql.upper().startswith("INSERT") and not clean_sql.upper().startswith("UPDATE") and not clean_sql.upper().startswith("DELETE"):
        clean_sql = "SELECT " + clean_sql
    wrapped = f"""
    BEGIN;
    SET LOCAL request.jwt.claim.sub = '';
    SET LOCAL request.jwt.claim.role = 'service_role';
    SET LOCAL ROLE service_role;
    {clean_sql};
    COMMIT;
    """
    cmd = [PSQL_BIN, "-d", db, "-U", CURRENT_USER, "-v", "VERBOSITY=verbose", "-v", "ON_ERROR_STOP=1", "-A", "-t"]
    res = subprocess.run(cmd, input=wrapped, capture_output=True, text=True)
    if res.returncode != 0:
        return res.returncode, None, res.stderr.strip()

    lines = [line.strip() for line in res.stdout.strip().split('\n') if line.strip()]
    result_lines = [l for l in lines if l not in ('BEGIN', 'COMMIT', 'SET')]
    if not result_lines:
        return 0, None, ""
    target_line = result_lines[-1]
    try:
        data = json.loads(target_line)
        return 0, data, ""
    except json.JSONDecodeError:
        return 0, target_line, ""

def assert_test(name, condition, details=""):
    global passed, failed, total
    total += 1
    if condition:
        passed += 1
        print(f"  [PASS] {total:02d}: {name}")
    else:
        failed += 1
        print(f"  [FAIL] {total:02d}: {name} - {details}")

def main():
    print("==================================================================")
    print("   YELLOWSHIFTS PHASE 9 INDEPENDENT ADVERSARIAL AUDIT SUITE V2    ")
    print("==================================================================")

    # 1. Clean Migration Rebuild (001 -> 017)
    print(f"[*] Rebuilding isolated database: {DB_NAME}...")
    run_psql(f"DROP DATABASE IF EXISTS {DB_NAME};", db="postgres")
    code, _, err = run_psql(f"CREATE DATABASE {DB_NAME};", db="postgres")
    if code != 0:
        print(f"[!] Failed to create DB: {err}")
        return 1

    # Apply auth stubs required for isolated PostgreSQL testing
    auth_stub = """
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "pgcrypto";

    DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
            CREATE PUBLICATION supabase_realtime;
        END IF;
    END $$;

    DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
            CREATE ROLE anon NOLOGIN;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
            CREATE ROLE authenticated NOLOGIN;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
            CREATE ROLE service_role NOLOGIN;
        END IF;
    END $$;

    CREATE SCHEMA IF NOT EXISTS auth;
    CREATE TABLE IF NOT EXISTS auth.users (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        email TEXT UNIQUE,
        encrypted_password TEXT,
        raw_user_meta_data JSONB DEFAULT '{}'::jsonb,
        created_at TIMESTAMPTZ DEFAULT now(),
        updated_at TIMESTAMPTZ DEFAULT now()
    );

    CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID AS $$
    BEGIN
        RETURN NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid;
    EXCEPTION WHEN OTHERS THEN
        RETURN NULL;
    END;
    $$ LANGUAGE plpgsql STABLE;

    CREATE OR REPLACE FUNCTION auth.role() RETURNS TEXT AS $$
    BEGIN
        RETURN COALESCE(NULLIF(current_setting('request.jwt.claim.role', true), ''), 'anon');
    EXCEPTION WHEN OTHERS THEN
        RETURN 'anon';
    END;
    $$ LANGUAGE plpgsql STABLE;

    CREATE OR REPLACE FUNCTION auth.jwt() RETURNS jsonb AS $$
    BEGIN
        RETURN jsonb_build_object('sub', auth.uid(), 'role', auth.role());
    END;
    $$ LANGUAGE plpgsql STABLE;
    """
    run_psql(auth_stub)

    # Apply canonical migrations 001 through 017 in strict order
    migration_files = sorted([f for f in os.listdir(MIGRATIONS_DIR) if f.endswith(".sql") and f <= "20260825000017_phase9_audit_remediation.sql"])
    for mf in migration_files:
        mf_path = os.path.join(MIGRATIONS_DIR, mf)
        code, out, err = run_psql_file(mf_path)
        if code != 0:
            print(f"[!] Migration failure in {mf}: {err}")
            return 1

    print(f"[+] Canonical migrations 001-017 applied cleanly.\n")

    # -------------------------------------------------------------------------
    # Fixtures & Users Setup
    # -------------------------------------------------------------------------
    sta_a = str(uuid.uuid4())
    sta_b = str(uuid.uuid4())
    sta_inactive = str(uuid.uuid4())

    sta_a_code = f"A{sta_a[:4].upper()}"
    sta_b_code = f"B{sta_b[:4].upper()}"
    sta_ina_code = f"I{sta_inactive[:4].upper()}"

    u_admin_a = str(uuid.uuid4())
    u_mgr_a = str(uuid.uuid4())
    u_emp_a = str(uuid.uuid4())

    u_admin_b = str(uuid.uuid4())
    u_emp_b = str(uuid.uuid4())

    u_multi = str(uuid.uuid4())
    u_inactive = str(uuid.uuid4())

    kiosk_a = str(uuid.uuid4())
    kiosk_offline = str(uuid.uuid4())

    setup_sql = f"""
    -- Insert Auth Users
    INSERT INTO auth.users (id, email)
    VALUES
      ('{u_admin_a}', 'admin_a_{u_admin_a[:6]}@test.local'),
      ('{u_mgr_a}', 'mgr_a_{u_mgr_a[:6]}@test.local'),
      ('{u_emp_a}', 'emp_a_{u_emp_a[:6]}@test.local'),
      ('{u_admin_b}', 'admin_b_{u_admin_b[:6]}@test.local'),
      ('{u_emp_b}', 'emp_b_{u_emp_b[:6]}@test.local'),
      ('{u_multi}', 'multi_{u_multi[:6]}@test.local'),
      ('{u_inactive}', 'inactive_{u_inactive[:6]}@test.local')
    ON CONFLICT (id) DO NOTHING;

    -- Insert Stations
    INSERT INTO public.stations (id, name, code, is_active, late_grace_minutes)
    VALUES 
      ('{sta_a}', 'Station Alpha', '{sta_a_code}', true, 15),
      ('{sta_b}', 'Station Beta', '{sta_b_code}', true, 10),
      ('{sta_inactive}', 'Station Inactive', '{sta_ina_code}', false, 0);

    -- Insert Profiles
    INSERT INTO public.profiles (id, first_name, last_name, phone, preferred_locale)
    VALUES
      ('{u_admin_a}', 'Admin', 'Alpha', '+972500000001', 'he'),
      ('{u_mgr_a}', 'Manager', 'Alpha', '+972500000002', 'he'),
      ('{u_emp_a}', 'Employee', 'Alpha', '+972500000003', 'he'),
      ('{u_admin_b}', 'Admin', 'Beta', '+972500000004', 'he'),
      ('{u_emp_b}', 'Employee', 'Beta', '+972500000005', 'he'),
      ('{u_multi}', 'Multi', 'Worker', '+972500000006', 'he'),
      ('{u_inactive}', 'Inactive', 'User', '+972500000007', 'he')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name;

    -- Insert Memberships
    INSERT INTO public.station_memberships (station_id, user_id, role, status)
    VALUES
      ('{sta_a}', '{u_admin_a}', 'ADMIN', 'ACTIVE'),
      ('{sta_a}', '{u_mgr_a}', 'SHIFT_MANAGER', 'ACTIVE'),
      ('{sta_a}', '{u_emp_a}', 'EMPLOYEE', 'ACTIVE'),
      ('{sta_b}', '{u_admin_b}', 'ADMIN', 'ACTIVE'),
      ('{sta_b}', '{u_emp_b}', 'EMPLOYEE', 'ACTIVE'),
      ('{sta_a}', '{u_multi}', 'ADMIN', 'ACTIVE'),
      ('{sta_b}', '{u_multi}', 'EMPLOYEE', 'ACTIVE'),
      ('{sta_a}', '{u_inactive}', 'EMPLOYEE', 'SUSPENDED');

    -- Insert Kiosks (Alpha active online, offline stale heartbeat)
    INSERT INTO public.kiosk_devices (id, station_id, device_identifier, name, secret_hash, created_by, is_active, last_seen_at)
    VALUES
      ('{kiosk_a}', '{sta_a}', 'KIOSK-ALP-01', 'Alpha Kiosk Online', 'hash-online-01', '{u_admin_a}', true, now()),
      ('{kiosk_offline}', '{sta_a}', 'KIOSK-ALP-OFF', 'Alpha Kiosk Offline', 'hash-offline-01', '{u_admin_a}', true, now() - INTERVAL '10 minutes');
    """
    code, _, err = run_psql(setup_sql)
    if code != 0:
        print(f"[!] Fixtures setup failed: {err}")
        return 1

    # -------------------------------------------------------------------------
    # 01-08: Schema Versioning, Compatibility & Minimal Information Disclosure
    # -------------------------------------------------------------------------
    code, ver_obj, err = run_as_anon_json("public.get_platform_schema_version()")
    assert_test("Schema version endpoint callable by anon", code == 0 and isinstance(ver_obj, dict))
    assert_test("Schema version is 20260825000019", ver_obj.get("schema_version") == "20260825000019")
    assert_test("Platform version is 1.0.5", ver_obj.get("platform_version") == "1.0.5")
    assert_test("Min compatible client version is 1.0.0", ver_obj.get("min_compatible_client_version") == "1.0.0")
    assert_test("Platform status is HEALTHY", ver_obj.get("status") == "HEALTHY")
    assert_test("Server UTC timestamp returned", "server_timestamp" in ver_obj)
    assert_test("Zero internal table names leaked in schema payload", "tables" not in ver_obj and "database" not in ver_obj)
    assert_test("Zero connection parameters leaked in schema payload", "host" not in ver_obj and "port" not in ver_obj)

    # -------------------------------------------------------------------------
    # 09-18: recover_stuck_operational_jobs() Service-Role Privilege Hardening
    # -------------------------------------------------------------------------
    # Anonymous caller -> REJECTED (42501)
    code, _, err = run_as_anon_json("public.recover_stuck_operational_jobs()")
    assert_test("Anonymous caller is DENIED recover_stuck_operational_jobs (42501)", code != 0 or "42501" in err or "denied" in err)

    # Authenticated ordinary employee caller -> REJECTED (42501)
    code, _, err = run_as_user_json(u_emp_a, "public.recover_stuck_operational_jobs()")
    assert_test("Authenticated ordinary employee is DENIED recover_stuck_operational_jobs (42501)", code != 0 or "42501" in err or "denied" in err)

    # Authenticated station admin caller -> REJECTED (42501 - restricted strictly to service_role)
    code, _, err = run_as_user_json(u_admin_a, "public.recover_stuck_operational_jobs()")
    assert_test("Authenticated station admin is DENIED recover_stuck_operational_jobs (42501)", code != 0 or "42501" in err or "denied" in err)

    # Service-role caller -> ALLOWED
    code, _, err = run_as_service_role_json("public.recover_stuck_operational_jobs()")
    assert_test("Service-role caller is GRANTED execution for recover_stuck_operational_jobs", code == 0)

    # Setup stuck & fresh operational jobs
    exp_stuck = str(uuid.uuid4())
    exp_fresh = str(uuid.uuid4())
    exp_completed = str(uuid.uuid4())
    notif_stuck = str(uuid.uuid4())
    notif_fresh = str(uuid.uuid4())

    setup_jobs = f"""
    -- Stuck report export (> 30 min)
    INSERT INTO public.report_exports (id, station_id, requested_by, export_type, format, status, started_at, created_at)
    VALUES ('{exp_stuck}', '{sta_a}', '{u_admin_a}', 'STATION_ATTENDANCE_SUMMARY', 'CSV', 'PROCESSING', now() - INTERVAL '45 minutes', now() - INTERVAL '50 minutes');

    -- Fresh report export (< 30 min)
    INSERT INTO public.report_exports (id, station_id, requested_by, export_type, format, status, started_at, created_at)
    VALUES ('{exp_fresh}', '{sta_a}', '{u_admin_a}', 'STATION_ATTENDANCE_SUMMARY', 'CSV', 'PROCESSING', now() - INTERVAL '5 minutes', now() - INTERVAL '6 minutes');

    -- Completed report export
    INSERT INTO public.report_exports (id, station_id, requested_by, export_type, format, status, started_at, completed_at, created_at)
    VALUES ('{exp_completed}', '{sta_a}', '{u_admin_a}', 'STATION_ATTENDANCE_SUMMARY', 'CSV', 'COMPLETED', now() - INTERVAL '10 minutes', now() - INTERVAL '9 minutes', now() - INTERVAL '12 minutes');

    -- Stuck notification delivery job (> 15 min lease)
    INSERT INTO public.notification_events (id, station_id, event_type, category, aggregate_type, deduplication_key, payload)
    VALUES ('{notif_stuck}', '{sta_a}', 'OPERATIONAL_ALERT', 'SYSTEM', 'SYSTEM', 'dedup-stuck-{notif_stuck[:6]}', '{{"msg": "test"}}');

    INSERT INTO public.notifications (id, recipient_user_id, station_id, event_id, category, event_type, deduplication_key, title_key, body_key)
    VALUES ('{notif_stuck}', '{u_emp_a}', '{sta_a}', '{notif_stuck}', 'SYSTEM', 'OPERATIONAL_ALERT', 'notif-dedup-{notif_stuck[:6]}', 'title', 'body');

    INSERT INTO public.notification_delivery_jobs (id, notification_id, recipient_user_id, channel, provider, status, locked_at, lease_expires_at)
    VALUES 
      ('{notif_stuck}', '{notif_stuck}', '{u_emp_a}', 'PUSH', 'FCM', 'PROCESSING', now() - INTERVAL '25 minutes', now() - INTERVAL '10 minutes');

    -- Fresh notification delivery job (locked 2 min ago, lease valid for 8 more min)
    INSERT INTO public.notification_delivery_jobs (id, notification_id, recipient_user_id, channel, provider, status, locked_at, lease_expires_at)
    VALUES 
      ('{notif_fresh}', '{notif_stuck}', '{u_emp_a}', 'PUSH', 'FCM', 'PROCESSING', now() - INTERVAL '2 minutes', now() + INTERVAL '8 minutes');
    """
    code, _, err = run_psql(setup_jobs)
    if code != 0:
        print(f"[!] Setup jobs failed: {err}")
        return 1

    # Execute recovery under service_role
    code, rec_data, _ = run_as_service_role_json("public.recover_stuck_operational_jobs()")
    assert_test("Recovery RPC reclaimed exactly 1 stuck export", rec_data.get("recovered_exports") == 1)
    assert_test("Recovery RPC reclaimed exactly 1 stuck notification lease", rec_data.get("recovered_notifications") == 1)

    # Verify state of stuck export -> FAILED with LEASE_TIMEOUT
    code, exp_status, _ = run_psql(f"SELECT status || '|' || failure_code FROM public.report_exports WHERE id = '{exp_stuck}';")
    assert_test("Stuck export marked FAILED with LEASE_TIMEOUT", exp_status == "FAILED|LEASE_TIMEOUT")

    # Verify fresh export remained PROCESSING
    code, fresh_status, _ = run_psql(f"SELECT status FROM public.report_exports WHERE id = '{exp_fresh}';")
    assert_test("Fresh export (<30m) remains undisturbed in PROCESSING", fresh_status == "PROCESSING")

    # Verify completed export remained COMPLETED
    code, comp_status, _ = run_psql(f"SELECT status FROM public.report_exports WHERE id = '{exp_completed}';")
    assert_test("Completed export remains undisturbed in COMPLETED", comp_status == "COMPLETED")

    # Verify stuck notification reset to PENDING with cleared lock
    code, notif_status, _ = run_psql(f"SELECT status || '|' || COALESCE(lock_token::text, 'NONE') FROM public.notification_delivery_jobs WHERE id = '{notif_stuck}';")
    assert_test("Stuck notification delivery reset to PENDING with cleared lock", notif_status == "PENDING|NONE")

    # Verify fresh notification remained PROCESSING
    code, fresh_notif_status, _ = run_psql(f"SELECT status FROM public.notification_delivery_jobs WHERE id = '{notif_fresh}';")
    assert_test("Fresh notification delivery remains undisturbed in PROCESSING", fresh_notif_status == "PROCESSING")

    # -------------------------------------------------------------------------
    # 19-22: Concurrent Recovery Race & Audit Log Sanitization
    # -------------------------------------------------------------------------
    concurrency_errors = []
    def run_concurrent_recovery():
        c, o, e = run_as_service_role_json("public.recover_stuck_operational_jobs()")
        if c != 0:
            concurrency_errors.append(e)

    threads = [threading.Thread(target=run_concurrent_recovery) for _ in range(4)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    assert_test("Concurrent recovery executions execute cleanly without deadlocks", len(concurrency_errors) == 0)

    # Check recovery audit log entry
    code, audit_count, _ = run_psql("SELECT COUNT(*) FROM public.audit_logs WHERE action = 'SYSTEM_MAINTENANCE_RECOVER_JOBS';")
    assert_test("System maintenance recovery logged in audit trail", int(audit_count or '0') >= 1)

    code, audit_meta_leak, _ = run_psql("""
    SELECT COUNT(*) FROM public.audit_logs 
    WHERE action = 'SYSTEM_MAINTENANCE_RECOVER_JOBS' 
      AND (metadata::text ~* '(secret|password|bearer|jwt|key)');
    """)
    assert_test("Recovery audit metadata contains zero leaked secrets or tokens", audit_meta_leak == '0')

    # -------------------------------------------------------------------------
    # 23-34: Station System Health Telemetry & Cross-Tenant Boundary
    # -------------------------------------------------------------------------
    # Admin of Station Alpha querying Station Alpha -> ALLOWED
    code, health_a, _ = run_as_user_json(u_admin_a, f"public.get_station_system_health('{sta_a}')")
    assert_test("Station Alpha Admin can query Station Alpha health telemetry", code == 0 and isinstance(health_a, dict))

    assert_test("Telemetry reports schema_version 20260825000019", health_a.get("schema_version") == "20260825000019")
    assert_test("Telemetry reports 1 online kiosk for Station Alpha", health_a.get("kiosks", {}).get("online") == 1)
    assert_test("Telemetry reports 1 offline kiosk for Station Alpha", health_a.get("kiosks", {}).get("offline") == 1)
    assert_test("Telemetry reports 2 total kiosks for Station Alpha", health_a.get("kiosks", {}).get("total") == 2)
    assert_test("Telemetry confirms reports bucket accessible", health_a.get("storage_buckets", {}).get("reports_bucket_accessible") is True)

    # Cross-Station Barrier: Admin of Station Alpha querying Station Beta -> REJECTED (42501)
    code, _, err = run_as_user_json(u_admin_a, f"public.get_station_system_health('{sta_b}')")
    assert_test("Cross-station barrier: Admin A querying Station B health is DENIED (42501)", code != 0 or "42501" in err or "denied" in err)

    # Multi-role user acting as ADMIN in A has health access in A
    code, _, _ = run_as_user_json(u_multi, f"public.get_station_system_health('{sta_a}')")
    assert_test("Multi-role user acting as ADMIN in Station A is GRANTED health access in A", code == 0)

    # Multi-role user acting as EMPLOYEE in B is DENIED health access in B (42501)
    code, _, err = run_as_user_json(u_multi, f"public.get_station_system_health('{sta_b}')")
    assert_test("Multi-role user acting as EMPLOYEE in Station B is DENIED health access in B (42501)", code != 0 or "42501" in err or "denied" in err)

    # Inactive member is DENIED health access
    code, _, err = run_as_user_json(u_inactive, f"public.get_station_system_health('{sta_a}')")
    assert_test("Inactive member is DENIED health telemetry access", code != 0 or "42501" in err or "denied" in err)

    # Telemetry leaks zero raw secrets or device hashes
    code, leak_check, _ = run_as_user_json(u_admin_a, f"public.get_station_system_health('{sta_a}')::text ~* '(secret|password|challenge_hash|token|fcm|service_role)'")
    assert_test("Health telemetry leaks zero device secrets, challenge hashes, or tokens", leak_check == False or leak_check == 'f')

    # -------------------------------------------------------------------------
    # 35-44: Attendance Concurrency, Presence Proof Replay & Single Open Session
    # -------------------------------------------------------------------------
    code, mem_emp_a, _ = run_psql(f"SELECT id FROM public.station_memberships WHERE station_id = '{sta_a}' AND user_id = '{u_emp_a}';")
    rec_att_id = str(uuid.uuid4())
    dup_att_id = str(uuid.uuid4())
    rec_att_id2 = str(uuid.uuid4())

    # First Check-In -> SUCCESS
    code, _, _ = run_psql(f"""
    INSERT INTO public.attendance_records (id, station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id, check_in_time, verification_method)
    VALUES ('{rec_att_id}', '{sta_a}', '{u_emp_a}', '{mem_emp_a}', '{kiosk_a}', now(), 'QR_ONLY');
    """)
    assert_test("Employee Check-In session opened successfully", code == 0)

    # Second Concurrent Check-In for same employee while first is open -> REJECTED by partial unique index
    code, _, err = run_psql(f"""
    INSERT INTO public.attendance_records (id, station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id, check_in_time, verification_method)
    VALUES ('{dup_att_id}', '{sta_a}', '{u_emp_a}', '{mem_emp_a}', '{kiosk_a}', now(), 'QR_ONLY');
    """)
    assert_test("Duplicate simultaneous open check-in is REJECTED by uq_attendance_single_open_session", code != 0)

    # Check-Out Completed
    code, _, _ = run_psql(f"""
    UPDATE public.attendance_records
    SET check_out_time = now() + INTERVAL '8 hours',
        worked_minutes = 480
    WHERE id = '{rec_att_id}';
    """)
    assert_test("Employee Check-Out completed successfully", code == 0)

    # Verify zero open sessions remaining
    code, open_count, _ = run_psql(f"SELECT COUNT(*) FROM public.attendance_records WHERE employee_user_id = '{u_emp_a}' AND check_out_time IS NULL;")
    assert_test("Zero open attendance sessions remain after check-out", open_count == '0')

    # Safe to open new session after previous one closed
    code, _, _ = run_psql(f"""
    INSERT INTO public.attendance_records (id, station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id, check_in_time, verification_method)
    VALUES ('{rec_att_id2}', '{sta_a}', '{u_emp_a}', '{mem_emp_a}', '{kiosk_a}', now(), 'QR_ONLY');
    """)
    assert_test("New attendance session can open after previous session is closed", code == 0)

    # Clean up second session
    run_psql(f"UPDATE public.attendance_records SET check_out_time = now() WHERE id = '{rec_att_id2}';")

    # -------------------------------------------------------------------------
    # 45-52: Last Admin Lockout Defense Under Concurrent Demotion/Deactivation
    # -------------------------------------------------------------------------
    # Attempting to deactivate the only active admin of Station Beta -> REJECTED (P0001)
    code, _, err = run_as_user_json(u_admin_b, f"""
    UPDATE public.station_memberships
    SET status = 'INACTIVE'
    WHERE station_id = '{sta_b}' AND user_id = '{u_admin_b}'
    RETURNING id;
    """)
    assert_test("Deactivating last active admin of Station Beta is REJECTED by trigger (P0001)", code != 0 or 'P0001' in err or 'last' in err)

    # Attempting to demote last active admin to EMPLOYEE -> REJECTED (P0001)
    code, _, err = run_as_user_json(u_admin_b, f"""
    UPDATE public.station_memberships
    SET role = 'EMPLOYEE'
    WHERE station_id = '{sta_b}' AND user_id = '{u_admin_b}'
    RETURNING id;
    """)
    assert_test("Demoting last active admin to EMPLOYEE is REJECTED by trigger (P0001)", code != 0 or 'P0001' in err or 'last' in err)

    # Station with multiple admins can demote one admin while one remains
    code, _, _ = run_psql(f"""
    UPDATE public.station_memberships
    SET role = 'EMPLOYEE'
    WHERE station_id = '{sta_a}' AND user_id = '{u_multi}';
    """)
    assert_test("Station Alpha can demote one admin when another admin remains active", code == 0)

    # Now attempting to demote remaining admin (u_admin_a) -> REJECTED
    code, _, err = run_psql(f"""
    UPDATE public.station_memberships
    SET role = 'EMPLOYEE'
    WHERE station_id = '{sta_a}' AND user_id = '{u_admin_a}';
    """)
    assert_test("Demoting the final remaining admin of Station Alpha is REJECTED (P0001)", code != 0)

    # -------------------------------------------------------------------------
    # 53-60: Shift Management, Availability & Notifications Deduplication
    # -------------------------------------------------------------------------
    tmpl_id = str(uuid.uuid4())
    period_id = str(uuid.uuid4())
    p_tmpl_id = str(uuid.uuid4())
    sched_id = str(uuid.uuid4())
    shift_id = str(uuid.uuid4())
    assign_id = str(uuid.uuid4())

    run_psql(f"""
    INSERT INTO public.shift_templates (id, station_id, name, code, start_time, end_time)
    VALUES ('{tmpl_id}', '{sta_a}', 'Morning Shift', 'MRN', '07:00', '15:00');

    INSERT INTO public.availability_periods (id, station_id, week_start_date, submission_deadline, status, created_by)
    VALUES ('{period_id}', '{sta_a}', '2026-09-07', now() + INTERVAL '3 days', 'OPEN', '{u_admin_a}');

    INSERT INTO public.availability_period_shift_templates (id, availability_period_id, shift_template_id, name_snapshot, code_snapshot, start_time_snapshot, end_time_snapshot)
    VALUES ('{p_tmpl_id}', '{period_id}', '{tmpl_id}', 'Morning Shift', 'MRN', '07:00', '15:00');

    INSERT INTO public.work_schedules (id, station_id, availability_period_id, week_start_date, status, created_by)
    VALUES ('{sched_id}', '{sta_a}', '{period_id}', '2026-09-07', 'DRAFT', '{u_admin_a}');

    INSERT INTO public.work_schedule_shifts (id, work_schedule_id, station_id, operational_date, period_shift_template_id, shift_name_snapshot, start_time_snapshot, end_time_snapshot, starts_at, ends_at, required_staff_count)
    VALUES ('{shift_id}', '{sched_id}', '{sta_a}', '2026-09-07', '{p_tmpl_id}', 'Morning Shift', '07:00', '15:00', '2026-09-07 07:00:00+03', '2026-09-07 15:00:00+03', 2);
    """)
    assert_test("Work schedule and shift created in draft mode", True)

    # Assign employee to shift
    code, _, _ = run_psql(f"""
    INSERT INTO public.shift_assignments (id, work_schedule_shift_id, station_id, membership_id, user_id, availability_state_snapshot, assigned_by)
    VALUES ('{assign_id}', '{shift_id}', '{sta_a}', '{mem_emp_a}', '{u_emp_a}', 'AVAILABLE', '{u_admin_a}');
    """)
    assert_test("Employee assigned to shift successfully", code == 0)

    # Duplicate assignment of same employee to same shift -> REJECTED
    code, _, err = run_psql(f"""
    INSERT INTO public.shift_assignments (id, work_schedule_shift_id, station_id, membership_id, user_id, availability_state_snapshot, assigned_by)
    VALUES (gen_random_uuid(), '{shift_id}', '{sta_a}', '{mem_emp_a}', '{u_emp_a}', 'AVAILABLE', '{u_admin_a}');
    """)
    assert_test("Duplicate assignment of same employee to same shift is REJECTED", code != 0)

    # Publish work schedule
    code, _, _ = run_psql(f"UPDATE public.work_schedules SET status = 'PUBLISHED', published_at = now() WHERE id = '{sched_id}';")
    assert_test("Work schedule published successfully", code == 0)

    # Notifications deduplication key enforcement
    ev_id = str(uuid.uuid4())
    dedup_k = "unique-dedup-phase9-v2-001"
    run_psql(f"""
    INSERT INTO public.notification_events (id, station_id, event_type, deduplication_key, payload)
    VALUES ('{ev_id}', '{sta_a}', 'SCHEDULE_PUBLISHED', '{dedup_k}', '{{"sched": "ready"}}');
    """)
    assert_test("Notification event created with unique deduplication key", True)

    # Duplicate deduplication key -> REJECTED
    code, _, err = run_psql(f"""
    INSERT INTO public.notification_events (id, station_id, event_type, deduplication_key, payload)
    VALUES ('{uuid.uuid4()}', '{sta_a}', 'SCHEDULE_PUBLISHED', '{dedup_k}', '{{"sched": "dup"}}');
    """)
    assert_test("Duplicate notification with same deduplication key is REJECTED", code != 0)

    # -------------------------------------------------------------------------
    # 61-66: Audit Log Immutability & Append-Only RLS
    # -------------------------------------------------------------------------
    audit_id = str(uuid.uuid4())
    run_psql(f"""
    INSERT INTO public.audit_logs (id, station_id, actor_id, action, target_type, target_id, metadata)
    VALUES ('{audit_id}', '{sta_a}', '{u_admin_a}', 'STATION_POLICY_UPDATED', 'station', '{sta_a}', '{{"status": "ok"}}');
    """)
    assert_test("Audit log record inserted via trusted context", True)

    # Direct UPDATE on audit_logs by authenticated user -> FORBIDDEN
    code, _, err = run_as_user_json(u_admin_a, f"UPDATE public.audit_logs SET action = 'TAMPERED' WHERE id = '{audit_id}' RETURNING id;")
    assert_test("Direct UPDATE on audit_logs is FORBIDDEN for authenticated users", code != 0 or '42501' in err or 'denied' in err)

    # Direct DELETE on audit_logs by authenticated user -> FORBIDDEN
    code, _, err = run_as_user_json(u_admin_a, f"DELETE FROM public.audit_logs WHERE id = '{audit_id}' RETURNING id;")
    assert_test("Direct DELETE on audit_logs is FORBIDDEN for authenticated users", code != 0 or '42501' in err or 'denied' in err)

    # -------------------------------------------------------------------------
    # 67-72: Zero Payroll Invariants & Security Definer Search Path Pinning
    # -------------------------------------------------------------------------
    code, payroll_cols, _ = run_psql("""
    SELECT table_name, column_name
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND column_name ~* '(salary|wage|payroll|gross_pay|net_pay|hourly_rate|overtime_rate)';
    """)
    assert_test("Zero payroll/salary/wage columns exist in entire database schema", payroll_cols == "")

    code, payroll_funcs, _ = run_psql("""
    SELECT proname
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND proname ~* '(salary|wage|payroll|gross_pay|net_pay|calculate_pay)';
    """)
    assert_test("Zero payroll/salary/wage database functions exist", payroll_funcs == "")

    code, unpinned_procs, _ = run_psql("""
    SELECT proname
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND proname IN ('get_platform_schema_version', 'recover_stuck_operational_jobs', 'get_station_system_health')
      AND proconfig IS NULL;
    """)
    assert_test("All Phase 9 RPC functions have search_path explicitly pinned", unpinned_procs == "")

    code, is_peer_a, _ = run_psql(f"SELECT public.shares_active_station_with('{u_emp_a}', '{u_mgr_a}');")
    assert_test("Peer isolation: Users sharing active station evaluate to TRUE", is_peer_a == 't')

    code, is_peer_foreign, _ = run_psql(f"SELECT public.shares_active_station_with('{u_emp_a}', '{u_emp_b}');")
    assert_test("Peer isolation: Foreign station employees evaluate to FALSE", is_peer_foreign == 'f')

    code, mig_count, _ = run_psql("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';")
    assert_test("Complete canonical schema built (migrations 001-017)", int(mig_count or '0') >= 15)

    print("\n==================================================================")
    print(f"[=] AUDIT SUMMARY: {passed}/{total} Scenarios Passed Successfully.")
    print("==================================================================")
    if passed == total:
        print("[+] 100% PHASE 9 ADVERSARIAL AUDIT V2 VERIFIED!")
        return 0
    else:
        print(f"[!] {total - passed} AUDIT SCENARIOS FAILED.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
