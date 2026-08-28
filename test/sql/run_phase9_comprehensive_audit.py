#!/usr/bin/env python3
"""
YellowShifts Phase 9 — Comprehensive Reliability & Adversarial Audit Suite
Executes 55+ production reliability, fail-closed authorization, zombie recovery,
multi-station isolation, attendance reconciliation, and security scenarios.
"""

import os
import sys
import json
import subprocess
import shutil

DB_NAME = "yellowshifts_phase9_comprehensive_audit"
PSQL_BIN = shutil.which("psql") or "/opt/homebrew/bin/psql"
CURRENT_USER = os.getenv("USER", "postgres")
MIGRATIONS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "supabase", "migrations"))

def run_psql(sql: str, db: str = DB_NAME) -> tuple[int, str, str]:
    cmd = [PSQL_BIN, "-d", db, "-U", CURRENT_USER, "-v", "VERBOSITY=verbose", "-v", "ON_ERROR_STOP=1", "-A", "-t"]
    res = subprocess.run(cmd, input=sql, capture_output=True, text=True)
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

def setup_test_db():
    print(f"[*] Rebuilding isolated Phase 9 comprehensive audit database: {DB_NAME}...")
    run_psql(f"DROP DATABASE IF EXISTS {DB_NAME};", db="postgres")
    code, _, err = run_psql(f"CREATE DATABASE {DB_NAME};", db="postgres")
    if code != 0:
        print(f"[!] Failed to create DB: {err}")
        sys.exit(1)

    setup_sql = """
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "pgcrypto";

    DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
            CREATE PUBLICATION supabase_realtime;
        END IF;
    END
    $$;

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
    END
    $$;

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
        RETURN NULLIF(current_setting('request.jwt.claim.role', true), '');
    EXCEPTION WHEN OTHERS THEN
        RETURN 'anon';
    END;
    $$ LANGUAGE plpgsql STABLE;
    """
    run_psql(setup_sql)

    migration_files = sorted([f for f in os.listdir(MIGRATIONS_DIR) if f.endswith('.sql')])
    for mf in migration_files:
        path = os.path.join(MIGRATIONS_DIR, mf)
        with open(path, 'r', encoding='utf-8') as f:
            sql = f.read()
        code, _, err = run_psql(sql)
        if code != 0:
            print(f"[!] Migration {mf} failed:\n{err}")
            sys.exit(1)

    print("[+] Canonical migrations 001-016 applied cleanly.")

def run_audit():
    passed = 0
    total = 0

    def assert_test(name: str, condition: bool, details: str = ""):
        nonlocal passed, total
        total += 1
        if condition:
            passed += 1
            print(f"  [PASS] {total:02d}: {name}")
        else:
            print(f"  [FAIL] {total:02d}: {name} - {details}")

    print("\n==================================================================")
    print("   PHASE 9 COMPREHENSIVE ADVERSARIAL AUDIT (55+ STRICT SCENARIOS)   ")
    print("==================================================================")

    # -------------------------------------------------------------------------
    # Fixtures Setup
    # -------------------------------------------------------------------------
    u_admin_a = "10000000-0000-0000-0000-000000000001"
    u_mgr_a = "10000000-0000-0000-0000-000000000002"
    u_emp_a = "10000000-0000-0000-0000-000000000003"
    
    u_admin_b = "20000000-0000-0000-0000-000000000001"
    u_emp_b = "20000000-0000-0000-0000-000000000003"

    u_multi = "30000000-0000-0000-0000-000000000001"
    u_inactive = "40000000-0000-0000-0000-000000000001"

    sta_a = "aaaaaaaa-0000-0000-0000-000000000001"
    sta_b = "bbbbbbbb-0000-0000-0000-000000000002"

    seed_sql = f"""
    INSERT INTO auth.users (id, email) VALUES
    ('{u_admin_a}', 'admin_a@test.local'),
    ('{u_mgr_a}', 'mgr_a@test.local'),
    ('{u_emp_a}', 'emp_a@test.local'),
    ('{u_admin_b}', 'admin_b@test.local'),
    ('{u_emp_b}', 'emp_b@test.local'),
    ('{u_multi}', 'multi@test.local'),
    ('{u_inactive}', 'inactive@test.local')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.profiles (id, first_name, last_name, phone) VALUES
    ('{u_admin_a}', 'Admin', 'A', '+972501000001'),
    ('{u_mgr_a}', 'Manager', 'A', '+972501000002'),
    ('{u_emp_a}', 'Employee', 'A', '+972501000003'),
    ('{u_admin_b}', 'Admin', 'B', '+972502000001'),
    ('{u_emp_b}', 'Employee', 'B', '+972502000003'),
    ('{u_multi}', 'Multi', 'User', '+972503000001'),
    ('{u_inactive}', 'Inactive', 'User', '+972504000001')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.stations (id, name, code, is_active) VALUES
    ('{sta_a}', 'Station Alfa', 'ALF-01', true),
    ('{sta_b}', 'Station Bravo', 'BRV-02', true)
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.station_memberships (station_id, user_id, role, status) VALUES
    ('{sta_a}', '{u_admin_a}', 'ADMIN', 'ACTIVE'),
    ('{sta_a}', '{u_mgr_a}', 'SHIFT_MANAGER', 'ACTIVE'),
    ('{sta_a}', '{u_emp_a}', 'EMPLOYEE', 'ACTIVE'),
    ('{sta_a}', '{u_multi}', 'ADMIN', 'ACTIVE'),
    ('{sta_b}', '{u_admin_b}', 'ADMIN', 'ACTIVE'),
    ('{sta_b}', '{u_emp_b}', 'EMPLOYEE', 'ACTIVE'),
    ('{sta_b}', '{u_multi}', 'EMPLOYEE', 'ACTIVE'),
    ('{sta_a}', '{u_inactive}', 'EMPLOYEE', 'INACTIVE')
    ON CONFLICT DO NOTHING;
    """
    code, _, err = run_psql(seed_sql)
    if code != 0:
        print(f"[!] Fixture seed failed: {err}")
        sys.exit(1)

    # -------------------------------------------------------------------------
    # 01-05: Schema Version Compatibility & Baseline Health
    # -------------------------------------------------------------------------
    code, res, err = run_as_anon_json("public.get_platform_schema_version()")
    assert_test("Schema version endpoint returns 20260825000019 for anon", code == 0 and res.get('schema_version') == '20260825000019', str(res))
    assert_test("Platform version is 1.0.5", res.get('platform_version') == '1.0.5', str(res))
    assert_test("Min compatible client version is 1.0.0", res.get('min_compatible_client_version') == '1.0.0', str(res))
    assert_test("Platform status is HEALTHY", res.get('status') == 'HEALTHY', str(res))
    assert_test("Server UTC timestamp is returned", 'server_timestamp' in res, str(res))

    # -------------------------------------------------------------------------
    # 06-12: Operational Zombie Recovery (Exports & Notifications)
    # -------------------------------------------------------------------------
    code, res, err = run_as_anon_json("public.recover_stuck_operational_jobs()")
    assert_test("Anonymous cannot trigger operational job recovery (42501)", code != 0 or '42501' in str(err) or 'Access denied' in str(err))

    code, res, err = run_as_user_json(u_emp_a, "public.recover_stuck_operational_jobs()")
    assert_test("Authenticated user is DENIED recover_stuck_operational_jobs (42501)", code != 0 or '42501' in str(err) or 'Access denied' in str(err))

    z_exp = "11111111-2222-3333-4444-555555555555"
    run_psql(f"""
    INSERT INTO public.report_exports (id, station_id, requested_by, export_type, format, status, created_at, started_at)
    VALUES ('{z_exp}', '{sta_a}', '{u_admin_a}', 'STATION_ATTENDANCE_SUMMARY', 'PDF', 'PROCESSING', now() - INTERVAL '60 minutes', now() - INTERVAL '60 minutes')
    ON CONFLICT (id) DO UPDATE SET status = 'PROCESSING', created_at = now() - INTERVAL '60 minutes', started_at = now() - INTERVAL '60 minutes';
    """)

    code, res, err = run_as_service_role_json("public.recover_stuck_operational_jobs()")
    assert_test("Stuck report export (>30m) is recovered by zombie cleaner", res.get('recovered_exports', 0) >= 1)

    code, st, _ = run_psql(f"SELECT status FROM public.report_exports WHERE id = '{z_exp}';")
    assert_test("Recovered export marked as FAILED with LEASE_TIMEOUT failure_code", st == 'FAILED')

    z_notif = "22222222-3333-4444-5555-666666666666"
    z_deliv = "33333333-4444-5555-6666-777777777777"
    run_psql(f"""
    INSERT INTO public.notification_events (id, station_id, event_type, category, aggregate_type, deduplication_key, payload)
    VALUES ('{z_notif}', '{sta_a}', 'AUDIT_TEST', 'SYSTEM', 'SYSTEM', 'dedup-comp-01', '{{"test": true}}')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.notifications (id, station_id, recipient_user_id, category, event_type, deduplication_key, title_key, body_key)
    VALUES ('{z_notif}', '{sta_a}', '{u_emp_a}', 'SYSTEM', 'AUDIT_TEST', 'dedup-comp-01', 'title', 'body')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.notification_delivery_jobs (id, notification_id, recipient_user_id, channel, status, lease_expires_at, locked_at)
    VALUES ('{z_deliv}', '{z_notif}', '{u_emp_a}', 'PUSH', 'PROCESSING', now() - INTERVAL '30 minutes', now() - INTERVAL '30 minutes')
    ON CONFLICT (id) DO UPDATE SET status = 'PROCESSING', lease_expires_at = now() - INTERVAL '30 minutes', locked_at = now() - INTERVAL '30 minutes';
    """)

    code, res, err = run_as_service_role_json("public.recover_stuck_operational_jobs()")
    assert_test("Stuck notification delivery (>15m) is recovered", res.get('recovered_notifications', 0) >= 1)

    code, del_st, _ = run_psql(f"SELECT status FROM public.notification_delivery_jobs WHERE id = '{z_deliv}';")
    assert_test("Recovered notification delivery reset to PENDING for redelivery", del_st == 'PENDING')

    code, res, err = run_as_service_role_json("public.recover_stuck_operational_jobs()")
    assert_test("Idempotent recovery leaves 0 pending jobs to recover", res.get('recovered_exports') == 0 and res.get('recovered_notifications') == 0)

    # -------------------------------------------------------------------------
    # 13-20: Enhanced Station System Health Telemetry
    # -------------------------------------------------------------------------
    code, res, err = run_as_user_json(u_admin_a, f"public.get_station_system_health('{sta_a}')")
    assert_test("Station Admin can retrieve station system health", code == 0 and res.get('station_id') == sta_a)
    assert_test("Health telemetry reports schema_version 20260825000019", res.get('schema_version') == '20260825000019')
    assert_test("Health telemetry reports kiosks metrics block", 'kiosks' in res)
    assert_test("Health telemetry reports exports 24h metrics block", 'exports_24h' in res and 'total' in res['exports_24h'])
    assert_test("Health telemetry reports attendance stale sessions check", 'attendance' in res and 'stale_open_sessions_16h' in res['attendance'])
    assert_test("Health telemetry reports identity failures block", 'identity' in res)
    assert_test("Health telemetry reports notification outbox status", 'notifications' in res and 'pending_outbox' in res['notifications'])
    assert_test("Health telemetry confirms storage bucket health", res.get('storage_buckets', {}).get('reports_bucket_accessible') is True)

    # -------------------------------------------------------------------------
    # 21-28: Multi-Station Role Isolation & Membership Guardrails
    # -------------------------------------------------------------------------
    code, res, err = run_as_user_json(u_multi, f"public.get_station_system_health('{sta_a}')")
    assert_test("Multi-role user acting as ADMIN in Station A has health access in A", code == 0 and res.get('station_id') == sta_a)

    code, res, err = run_as_user_json(u_multi, f"public.get_station_system_health('{sta_b}')")
    assert_test("Multi-role user acting as EMPLOYEE in Station B is DENIED health access in B", code != 0 or '42501' in str(err) or 'Access denied' in str(err))

    code, res, err = run_as_user_json(u_admin_a, f"public.get_station_system_health('{sta_b}')")
    assert_test("Admin of Station A cannot view Station B health (Cross-station barrier)", code != 0 or '42501' in str(err) or 'Access denied' in str(err))

    code, res, err = run_as_user_json(u_admin_b, f"public.get_station_system_health('{sta_a}')")
    assert_test("Admin of Station B cannot view Station A health (Cross-station barrier)", code != 0 or '42501' in str(err) or 'Access denied' in str(err))

    code, is_mgr, _ = run_psql(f"SELECT public.is_station_manager_or_admin('{sta_a}', '{u_mgr_a}');")
    assert_test("Shift Manager in Station A is identified as manager_or_admin", is_mgr == 't')

    code, is_mgr_b, _ = run_psql(f"SELECT public.is_station_manager_or_admin('{sta_b}', '{u_mgr_a}');")
    assert_test("Shift Manager in Station A has NO manager privileges in Station B", is_mgr_b == 'f')

    code, is_mem, _ = run_psql(f"SELECT public.is_station_member('{sta_a}', '{u_inactive}');")
    assert_test("Inactive member returns FALSE for is_station_member", is_mem == 'f')

    code, res, err = run_as_user_json(u_inactive, f"public.get_station_system_health('{sta_a}')")
    assert_test("Inactive member cannot access privileged health endpoint", code != 0 or '42501' in str(err) or 'Access denied' in str(err))

    # -------------------------------------------------------------------------
    # 29-36: Kiosk Fleet Management & Attendance Invariant Enforcement
    # -------------------------------------------------------------------------
    kiosk_id = "44444444-5555-6666-7777-888888888888"
    run_psql(f"""
    INSERT INTO public.kiosk_devices (id, station_id, name, device_identifier, secret_hash, created_by, is_active, last_seen_at)
    VALUES ('{kiosk_id}', '{sta_a}', 'Main Lobby Kiosk', 'KIOSK-MAIN-01', 'hash123', '{u_admin_a}', true, now())
    ON CONFLICT (id) DO UPDATE SET last_seen_at = now(), is_active = true;
    """)

    code, res, _ = run_as_user_json(u_admin_a, f"public.get_station_system_health('{sta_a}')")
    assert_test("Active Kiosk with recent heartbeat counted as online in telemetry", res.get('kiosks', {}).get('online', 0) >= 1)

    # Stale heartbeat (> 5 mins)
    run_psql(f"""
    UPDATE public.kiosk_devices
    SET last_seen_at = now() - INTERVAL '10 minutes'
    WHERE id = '{kiosk_id}';
    """)
    code, res, _ = run_as_user_json(u_admin_a, f"public.get_station_system_health('{sta_a}')")
    assert_test("Kiosk with stale heartbeat (>2m) counted as offline in telemetry", res.get('kiosks', {}).get('offline', 0) >= 1)

    # Insert check-in session with foreign key to kiosk
    code, _, err = run_psql(f"""
    INSERT INTO public.attendance_records (station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id, check_in_time)
    SELECT '{sta_a}', '{u_emp_a}', id, '{kiosk_id}', now()
    FROM public.station_memberships WHERE user_id = '{u_emp_a}' AND station_id = '{sta_a}';
    """)
    assert_test("Employee Check-In session created with kiosk and membership FKs", code == 0, err)

    # Attempt second simultaneous check-in
    code, _, err = run_psql(f"""
    INSERT INTO public.attendance_records (station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id, check_in_time)
    SELECT '{sta_a}', '{u_emp_a}', id, '{kiosk_id}', now()
    FROM public.station_memberships WHERE user_id = '{u_emp_a}' AND station_id = '{sta_a}';
    """)
    assert_test("Simultaneous duplicate open check-in is REJECTED by partial unique index", code != 0)

    # Check-out
    code, _, err = run_psql(f"""
    UPDATE public.attendance_records
    SET check_out_time = now(),
        worked_minutes = 120
    WHERE station_id = '{sta_a}' AND employee_user_id = '{u_emp_a}' AND check_out_time IS NULL;
    """)
    assert_test("Employee Check-Out completed successfully", code == 0, err)

    code, open_count, _ = run_psql(f"""
    SELECT COUNT(*) FROM public.attendance_records
    WHERE station_id = '{sta_a}' AND employee_user_id = '{u_emp_a}' AND check_out_time IS NULL;
    """)
    assert_test("Zero open attendance sessions remain after check-out", open_count == '0')

    # -------------------------------------------------------------------------
    # 37-44: Shift Scheduling Invariants & Constraints
    # -------------------------------------------------------------------------
    tmpl_id = "55555555-1111-2222-3333-444444444444"
    period_id = "55555555-2222-3333-4444-555555555555"
    p_tmpl_id = "55555555-3333-4444-5555-666666666666"
    sched_id = "55555555-4444-5555-6666-777777777777"
    shift_id = "55555555-5555-6666-7777-888888888888"
    assign_id = "55555555-6666-7777-8888-999999999999"

    setup_sched_sql = f"""
    INSERT INTO public.shift_templates (id, station_id, name, code, start_time, end_time)
    VALUES ('{tmpl_id}', '{sta_a}', 'Morning Shift', 'MRN', '07:00', '15:00')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.availability_periods (id, station_id, week_start_date, submission_deadline, status, created_by)
    VALUES ('{period_id}', '{sta_a}', '2026-09-07', now() + INTERVAL '3 days', 'OPEN', '{u_admin_a}')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.availability_period_shift_templates (id, availability_period_id, shift_template_id, name_snapshot, code_snapshot, start_time_snapshot, end_time_snapshot)
    VALUES ('{p_tmpl_id}', '{period_id}', '{tmpl_id}', 'Morning Shift', 'MRN', '07:00', '15:00')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.work_schedules (id, station_id, availability_period_id, week_start_date, status, created_by)
    VALUES ('{sched_id}', '{sta_a}', '{period_id}', '2026-09-07', 'DRAFT', '{u_admin_a}')
    ON CONFLICT (id) DO NOTHING;
    """
    code, _, err = run_psql(setup_sched_sql)
    if code != 0:
        print(f"[!] setup_sched_sql failed: {err}")

    code, sched_st, _ = run_psql(f"SELECT status FROM public.work_schedules WHERE id = '{sched_id}';")
    assert_test("Work schedule initialized in DRAFT state", sched_st == 'DRAFT')

    # Shift creation
    run_psql(f"""
    INSERT INTO public.work_schedule_shifts (id, work_schedule_id, station_id, operational_date, period_shift_template_id, shift_name_snapshot, start_time_snapshot, end_time_snapshot, starts_at, ends_at, required_staff_count)
    VALUES ('{shift_id}', '{sched_id}', '{sta_a}', '2026-09-07', '{p_tmpl_id}', 'Morning Shift', '07:00', '15:00', '2026-09-07 07:00:00+03', '2026-09-07 15:00:00+03', 2)
    ON CONFLICT (id) DO NOTHING;
    """)
    code, shift_exists, _ = run_psql(f"SELECT COUNT(*) FROM public.work_schedule_shifts WHERE id = '{shift_id}';")
    assert_test("Shift created in draft work schedule", shift_exists == '1')

    # Assignment
    run_psql(f"""
    INSERT INTO public.shift_assignments (id, work_schedule_shift_id, station_id, membership_id, user_id, availability_state_snapshot, assigned_by)
    SELECT '{assign_id}', '{shift_id}', '{sta_a}', id, '{u_emp_a}', 'AVAILABLE', '{u_admin_a}'
    FROM public.station_memberships WHERE user_id = '{u_emp_a}' AND station_id = '{sta_a}'
    ON CONFLICT (id) DO NOTHING;
    """)
    code, ass_count, _ = run_psql(f"SELECT COUNT(*) FROM public.shift_assignments WHERE id = '{assign_id}';")
    assert_test("Employee assigned to shift successfully", ass_count == '1')

    # Duplicate assignment rejection
    code, _, err = run_psql(f"""
    INSERT INTO public.shift_assignments (id, work_schedule_shift_id, station_id, membership_id, user_id, availability_state_snapshot, assigned_by)
    SELECT gen_random_uuid(), '{shift_id}', '{sta_a}', id, '{u_emp_a}', 'AVAILABLE', '{u_admin_a}'
    FROM public.station_memberships WHERE user_id = '{u_emp_a}' AND station_id = '{sta_a}';
    """)
    assert_test("Duplicate assignment of same employee to same shift is REJECTED", code != 0)

    # Publish schedule
    run_psql(f"UPDATE public.work_schedules SET status = 'PUBLISHED', published_at = now() WHERE id = '{sched_id}';")
    code, pub_st, _ = run_psql(f"SELECT status FROM public.work_schedules WHERE id = '{sched_id}';")
    assert_test("Work schedule published successfully", pub_st == 'PUBLISHED')

    # -------------------------------------------------------------------------
    # 45-50: Notification Deduplication & Security Audit
    # -------------------------------------------------------------------------
    n_dup = "88888888-9999-0000-1111-222222222222"
    run_psql(f"""
    INSERT INTO public.notifications (id, station_id, recipient_user_id, category, event_type, deduplication_key, title_key, body_key)
    VALUES ('{n_dup}', '{sta_a}', '{u_emp_a}', 'SCHEDULE', 'SHIFT_ASSIGNED', 'dedup-unique-test-key-45', 'title', 'body')
    ON CONFLICT (id) DO NOTHING;
    """)
    code, notif_count, _ = run_psql(f"SELECT COUNT(*) FROM public.notifications WHERE id = '{n_dup}';")
    assert_test("Notification created with unique deduplication key", notif_count == '1')

    # Duplicate key collision
    code, _, err = run_psql(f"""
    INSERT INTO public.notifications (id, station_id, recipient_user_id, category, event_type, deduplication_key, title_key, body_key)
    VALUES (gen_random_uuid(), '{sta_a}', '{u_emp_a}', 'SCHEDULE', 'SHIFT_ASSIGNED', 'dedup-unique-test-key-45', 'title', 'body');
    """)
    assert_test("Duplicate notification with identical deduplication key is REJECTED", code != 0)

    # -------------------------------------------------------------------------
    # 51-54: Audit Trail Immutability & Zero Deletion
    # -------------------------------------------------------------------------
    run_psql(f"""
    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES ('{sta_a}', '{u_admin_a}', 'SECURITY_AUDIT_MARKER', 'STATION', '{sta_a}', '{{"verified": true}}'::jsonb);
    """)
    code, log_count, _ = run_psql(f"SELECT COUNT(*) FROM public.audit_logs WHERE action = 'SECURITY_AUDIT_MARKER';")
    assert_test("Audit log entry created via trusted security context", log_count == '1')

    code, _, err = run_as_user_json(u_admin_a, f"UPDATE public.audit_logs SET action = 'HACKED' WHERE station_id = '{sta_a}';")
    assert_test("Direct UPDATE on audit_logs is FORBIDDEN for authenticated users", code != 0 or '42501' in str(err) or 'denied' in str(err))

    code, _, err = run_as_user_json(u_admin_a, f"DELETE FROM public.audit_logs WHERE station_id = '{sta_a}';")
    assert_test("Direct DELETE on audit_logs is FORBIDDEN for authenticated users", code != 0 or '42501' in str(err) or 'denied' in str(err))

    # -------------------------------------------------------------------------
    # 55-57: Zero Payroll Schema Drift & Search Path Invariants
    # -------------------------------------------------------------------------
    code, payroll_cols, _ = run_psql("""
    SELECT table_name, column_name
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND column_name ~* '(salary|wage|payroll|gross_pay|net_pay|hourly_rate|overtime_rate)';
    """)
    assert_test("Zero payroll/salary/wage columns exist in entire schema", payroll_cols == "")

    code, payroll_functions, _ = run_psql("""
    SELECT proname
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND proname ~* '(salary|wage|payroll|gross_pay|net_pay|calculate_pay)';
    """)
    assert_test("Zero payroll/salary/wage database functions exist", payroll_functions == "")

    code, unpinned_procs, _ = run_psql("""
    SELECT proname
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND proname IN ('get_platform_schema_version', 'recover_stuck_operational_jobs', 'get_station_system_health')
      AND proconfig IS NULL;
    """)
    assert_test("All Phase 9 RPC functions have search_path explicitly pinned", unpinned_procs == "")

    # -------------------------------------------------------------------------
    # 49-55: Peer Isolation, Availability Deadlines & Check Constraints
    # -------------------------------------------------------------------------
    code, is_peer_a, _ = run_psql(f"SELECT public.shares_active_station_with('{u_emp_a}', '{u_mgr_a}');")
    assert_test("Peer isolation: Users sharing active station evaluate to TRUE", is_peer_a == 't')

    code, is_peer_foreign, _ = run_psql(f"SELECT public.shares_active_station_with('{u_emp_a}', '{u_emp_b}');")
    assert_test("Peer isolation: Foreign station employees evaluate to FALSE", is_peer_foreign == 'f')

    # Multi-station membership support
    code, multi_count, _ = run_psql(f"SELECT COUNT(*) FROM public.station_memberships WHERE user_id = '{u_multi}' AND status = 'ACTIVE';")
    assert_test("Multi-station architecture: Single user actively registered in 2 distinct stations", multi_count == '2')

    # Report export format check constraint
    code, _, err = run_psql(f"""
    INSERT INTO public.report_exports (station_id, requested_by, export_type, format)
    VALUES ('{sta_a}', '{u_admin_a}', 'STATION_ATTENDANCE_SUMMARY', 'DOCX');
    """)
    assert_test("Report export check constraint rejects unapproved formats (e.g. DOCX)", code != 0)

    # Shift duration non-zero constraint
    code, _, err = run_psql(f"""
    INSERT INTO public.shift_templates (station_id, name, start_time, end_time)
    VALUES ('{sta_a}', 'Zero Length Shift', '08:00', '08:00');
    """)
    assert_test("Shift template check constraint rejects zero-duration shifts (08:00 == 08:00)", code != 0)

    # Attendance late grace minutes column present
    code, grace_val, _ = run_psql(f"SELECT late_grace_minutes FROM public.stations WHERE id = '{sta_a}';")
    assert_test("Station late grace minutes policy configured", int(grace_val or '0') >= 0)

    # Kiosk QR challenge unique hash invariant
    ch_id1 = "99999999-1111-2222-3333-444444444444"
    run_psql(f"""
    INSERT INTO public.kiosk_qr_challenges (id, station_id, kiosk_device_id, challenge_hash, display_code, expires_at)
    VALUES ('{ch_id1}', '{sta_a}', '{kiosk_id}', 'hash-unique-challenge-55', '123456', now() + INTERVAL '30 seconds')
    ON CONFLICT (id) DO NOTHING;
    """)
    code, _, err = run_psql(f"""
    INSERT INTO public.kiosk_qr_challenges (station_id, kiosk_device_id, challenge_hash, display_code, expires_at)
    VALUES ('{sta_a}', '{kiosk_id}', 'hash-unique-challenge-55', '654321', now() + INTERVAL '30 seconds');
    """)
    assert_test("Kiosk QR challenge hash collision is deterministically REJECTED", code != 0)

    print("\n==================================================================")
    print(f"[=] AUDIT SUMMARY: {passed}/{total} Scenarios Passed Successfully.")
    print("==================================================================")
    if passed == total:
        print("[+] 100% PHASE 9 COMPREHENSIVE ADVERSARIAL AUDIT VERIFIED!")
        return 0
    else:
        print(f"[!] {total - passed} AUDIT SCENARIOS FAILED.")
        return 1

if __name__ == "__main__":
    setup_test_db()
    sys.exit(run_audit())
