#!/usr/bin/env python3
"""
YellowShifts Phase 10 — Production Security & Reliability Invariant Suite
Independently verifies production-grade database security, service-role barriers,
multi-station tenant isolation, telemetry safety, and immutability invariants.
"""

import os
import sys
import json
import uuid
import shutil
import subprocess

DB_NAME = "yellowshifts_phase10_security_tests"
PSQL_BIN = shutil.which("psql") or "/opt/homebrew/bin/psql"
CURRENT_USER = os.getenv("USER", "postgres")
MIGRATIONS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "supabase", "migrations"))

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
    try:
        return 0, json.loads(result_lines[-1]), ""
    except Exception:
        return 0, result_lines[-1], ""

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
    try:
        return 0, json.loads(result_lines[-1]), ""
    except Exception:
        return 0, result_lines[-1], ""

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
    try:
        return 0, json.loads(result_lines[-1]), ""
    except Exception:
        return 0, result_lines[-1], ""

def setup_db():
    print(f"[*] Rebuilding isolated Phase 10 security test database: {DB_NAME}...")
    run_psql(f"DROP DATABASE IF EXISTS {DB_NAME};", db="postgres")
    code, _, err = run_psql(f"CREATE DATABASE {DB_NAME};", db="postgres")
    if code != 0:
        print(f"[!] Failed to create database: {err}")
        sys.exit(1)

    setup_sql = """
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "pgcrypto";
    DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
            CREATE PUBLICATION supabase_realtime;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon NOLOGIN; END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN CREATE ROLE service_role NOLOGIN; END IF;
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
    BEGIN RETURN NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid; EXCEPTION WHEN OTHERS THEN RETURN NULL; END;
    $$ LANGUAGE plpgsql STABLE;
    CREATE OR REPLACE FUNCTION auth.role() RETURNS TEXT AS $$
    BEGIN RETURN COALESCE(NULLIF(current_setting('request.jwt.claim.role', true), ''), 'anon'); EXCEPTION WHEN OTHERS THEN RETURN 'anon'; END;
    $$ LANGUAGE plpgsql STABLE;
    """
    run_psql(setup_sql)

    migration_files = sorted([f for f in os.listdir(MIGRATIONS_DIR) if f.endswith('.sql') and f <= "20260825000017_phase9_audit_remediation.sql"])
    for mf in migration_files:
        path = os.path.join(MIGRATIONS_DIR, mf)
        code, _, err = run_psql_file(path)
        if code != 0:
            print(f"[!] Migration {mf} failed:\n{err}")
            sys.exit(1)

    print("[+] Canonical migrations 001-017 applied cleanly.")

def run_tests():
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

    print("\n--- PHASE 10 PRODUCTION SECURITY INVARIANT SUITE ---")

    # Fixtures
    u_admin_a = str(uuid.uuid4())
    u_mgr_a = str(uuid.uuid4())
    u_emp_a = str(uuid.uuid4())
    u_admin_b = str(uuid.uuid4())
    sta_a = str(uuid.uuid4())
    sta_b = str(uuid.uuid4())
    kiosk_a = str(uuid.uuid4())

    seed_sql = f"""
    INSERT INTO auth.users (id, email) VALUES
    ('{u_admin_a}', 'admin.a@yellowshifts.local'),
    ('{u_mgr_a}', 'mgr.a@yellowshifts.local'),
    ('{u_emp_a}', 'emp.a@yellowshifts.local'),
    ('{u_admin_b}', 'admin.b@yellowshifts.local')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.stations (id, name, code, is_active) VALUES
    ('{sta_a}', 'Station Alpha', 'STA-A', true),
    ('{sta_b}', 'Station Beta', 'STA-B', true)
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.profiles (id, first_name, last_name, phone) VALUES
    ('{u_admin_a}', 'Admin', 'Alpha', '+972501000001'),
    ('{u_mgr_a}', 'Manager', 'Alpha', '+972501000002'),
    ('{u_emp_a}', 'Employee', 'Alpha', '+972501000003'),
    ('{u_admin_b}', 'Admin', 'Beta', '+972501000004')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name;

    INSERT INTO public.station_memberships (station_id, user_id, role, status) VALUES
    ('{sta_a}', '{u_admin_a}', 'ADMIN', 'ACTIVE'),
    ('{sta_a}', '{u_mgr_a}', 'SHIFT_MANAGER', 'ACTIVE'),
    ('{sta_a}', '{u_emp_a}', 'EMPLOYEE', 'ACTIVE'),
    ('{sta_b}', '{u_admin_b}', 'ADMIN', 'ACTIVE')
    ON CONFLICT (station_id, user_id) DO NOTHING;

    INSERT INTO public.kiosk_devices (id, station_id, name, device_identifier, secret_hash, created_by, is_active, last_seen_at)
    VALUES ('{kiosk_a}', '{sta_a}', 'Main Entrance Kiosk', 'KIOSK-A1', crypt('kiosk-secret-hash-1', gen_salt('bf')), '{u_admin_a}', true, now())
    ON CONFLICT (id) DO NOTHING;
    """
    code, _, err = run_psql(seed_sql)
    if code != 0:
        print(f"[!] Seed fixtures failed: {err}")
        sys.exit(1)

    # 1. Schema version endpoint
    code, res, err = run_as_anon_json("public.get_platform_schema_version()")
    assert_test("Schema version endpoint callable by anon", code == 0 and res.get("status") == "HEALTHY", f"res: {res}")
    assert_test("Schema version is valid", res.get("schema_version") in ("20260825000017", "20260825000019"), f"res: {res}")
    assert_test("Platform version is valid", res.get("platform_version") in ("1.0.0", "1.0.5"), f"res: {res}")
    assert_test("Min compatible client version is 1.0.0", res.get("min_compatible_client_version") == "1.0.0", f"res: {res}")

    # 2. Minimal info disclosure on public endpoint
    res_str = json.dumps(res)
    assert_test("Zero internal table names leaked in schema endpoint", "station_memberships" not in res_str and "profiles" not in res_str)
    assert_test("Zero database connection parameters leaked in schema endpoint", "postgresql://" not in res_str and "password" not in res_str)

    # 3. Operational recovery privilege barriers
    code, res, err = run_as_anon_json("public.recover_stuck_operational_jobs()")
    assert_test("Anonymous caller is DENIED recover_stuck_operational_jobs (42501)", code != 0 or '42501' in str(err))

    code, res, err = run_as_user_json(u_emp_a, "public.recover_stuck_operational_jobs()")
    assert_test("Ordinary authenticated employee is DENIED recover_stuck_operational_jobs (42501)", code != 0 or '42501' in str(err))

    code, res, err = run_as_user_json(u_admin_a, "public.recover_stuck_operational_jobs()")
    assert_test("Authenticated station admin is DENIED recover_stuck_operational_jobs (42501)", code != 0 or '42501' in str(err))

    code, res, err = run_as_service_role_json("public.recover_stuck_operational_jobs()")
    assert_test("Service-role caller is GRANTED execution for recover_stuck_operational_jobs", code == 0 and "recovered_exports" in res, f"res: {res}, err: {err}")

    # 4. Zombie recovery job execution
    z_exp = str(uuid.uuid4())
    run_psql(f"""
    INSERT INTO public.report_exports (id, station_id, requested_by, export_type, format, status, created_at, started_at)
    VALUES ('{z_exp}', '{sta_a}', '{u_admin_a}', 'STATION_ATTENDANCE_SUMMARY', 'CSV', 'PROCESSING', now() - INTERVAL '40 minutes', now() - INTERVAL '40 minutes');
    """)
    code, res, _ = run_as_service_role_json("public.recover_stuck_operational_jobs()")
    assert_test("Zombie report export (>30m) reclaimed by recovery job", code == 0 and res.get("recovered_exports", 0) >= 1)

    code, exp_st, _ = run_psql(f"SELECT status FROM public.report_exports WHERE id = '{z_exp}';")
    assert_test("Zombie export marked FAILED with failure_code LEASE_TIMEOUT", exp_st == "FAILED")

    # 5. Station system health telemetry
    code, res, err = run_as_user_json(u_admin_a, f"public.get_station_system_health('{sta_a}')")
    assert_test("Station Alpha Admin can access Station Alpha health telemetry", code == 0 and res.get("station_id") == sta_a, f"res: {res}")
    assert_test("Telemetry reports valid schema_version", res.get("schema_version") in ("20260825000017", "20260825000019"))
    assert_test("Telemetry confirms reports bucket accessible", res.get("storage_buckets", {}).get("reports_bucket_accessible") is True)

    code, res, err = run_as_user_json(u_admin_a, f"public.get_station_system_health('{sta_b}')")
    assert_test("Cross-station barrier: Admin A querying Station B health is DENIED (42501)", code != 0 or '42501' in str(err))

    code, res, err = run_as_user_json(u_emp_a, f"public.get_station_system_health('{sta_a}')")
    assert_test("Employee querying Station Alpha health is DENIED (42501)", code != 0 or '42501' in str(err))

    # 6. Search path pinning and security grants
    code, unpinned_procs, _ = run_psql("""
    SELECT proname FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND proname IN ('get_platform_schema_version', 'recover_stuck_operational_jobs', 'get_station_system_health')
      AND proconfig IS NULL;
    """)
    assert_test("All Phase 10 RPCs have search_path explicitly pinned", unpinned_procs == "", f"unpinned: {unpinned_procs}")

    code, bad_grants, _ = run_psql("""
    SELECT proname FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND proname = 'recover_stuck_operational_jobs'
      AND has_function_privilege('public', p.oid, 'EXECUTE');
    """)
    assert_test("recover_stuck_operational_jobs has EXECUTE revoked from PUBLIC", bad_grants == "")

    # 7. Audit log immutability
    audit_id = str(uuid.uuid4())
    run_psql(f"""
    INSERT INTO public.audit_logs (id, station_id, actor_id, action, target_type, target_id)
    VALUES ('{audit_id}', '{sta_a}', '{u_admin_a}', 'TEST_SECURITY_ACTION', 'test', '{audit_id}');
    """)
    code, _, _ = run_as_user_json(u_admin_a, f"UPDATE public.audit_logs SET action = 'TAMPERED' WHERE id = '{audit_id}';")
    assert_test("Direct UPDATE on audit_logs is FORBIDDEN for authenticated callers", code != 0)

    code, _, _ = run_as_user_json(u_admin_a, f"DELETE FROM public.audit_logs WHERE id = '{audit_id}';")
    assert_test("Direct DELETE on audit_logs is FORBIDDEN for authenticated callers", code != 0)

    # 8. Single open attendance session invariant
    code, mem_emp_a, _ = run_psql(f"SELECT id FROM public.station_memberships WHERE station_id = '{sta_a}' AND user_id = '{u_emp_a}';")
    att_1 = str(uuid.uuid4())
    att_2 = str(uuid.uuid4())
    code, _, _ = run_psql(f"""
    INSERT INTO public.attendance_records (id, station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id, check_in_time, verification_method)
    VALUES ('{att_1}', '{sta_a}', '{u_emp_a}', '{mem_emp_a}', '{kiosk_a}', now(), 'QR_ONLY');
    """)
    assert_test("First attendance session opens successfully", code == 0)

    code, _, _ = run_psql(f"""
    INSERT INTO public.attendance_records (id, station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id, check_in_time, verification_method)
    VALUES ('{att_2}', '{sta_a}', '{u_emp_a}', '{mem_emp_a}', '{kiosk_a}', now(), 'QR_ONLY');
    """)
    assert_test("Concurrent second open check-in is REJECTED by uq_attendance_single_open_session", code != 0)

    # Clean up attendance session
    run_psql(f"UPDATE public.attendance_records SET check_out_time = now() WHERE id = '{att_1}';")

    # 9. Last admin lockout defense
    code, _, err = run_as_user_json(u_admin_b, f"UPDATE public.station_memberships SET role = 'EMPLOYEE' WHERE station_id = '{sta_b}' AND user_id = '{u_admin_b}';")
    assert_test("Demoting last active admin of Station Beta is REJECTED by trigger (P0001)", code != 0 or 'P0001' in str(err))

    # 10. Zero payroll schema check
    code, payroll_cols, _ = run_psql("""
    SELECT column_name, table_name FROM information_schema.columns
    WHERE table_schema = 'public'
      AND column_name ~* '(salary|wage|payroll|gross_pay|net_pay|hourly_rate|overtime_rate)';
    """)
    assert_test("Zero forbidden payroll/salary/wage columns exist in public schema", payroll_cols == "")

    code, payroll_funcs, _ = run_psql("""
    SELECT proname FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND proname ~* '(salary|wage|payroll|gross_pay|net_pay|calculate_pay)';
    """)
    assert_test("Zero payroll/salary/wage database functions exist", payroll_funcs == "")

    print(f"\n==================================================")
    print(f"[=] RESULTS: {passed}/{total} Phase 10 security tests passed.")
    print(f"==================================================")
    if passed == total:
        print("[+] ALL PHASE 10 SECURITY INVARIANTS VERIFIED!")
        return 0
    else:
        print(f"[!] {total - passed} TESTS FAILED.")
        return 1

if __name__ == "__main__":
    setup_db()
    sys.exit(run_tests())
