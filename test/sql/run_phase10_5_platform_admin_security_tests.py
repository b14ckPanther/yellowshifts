#!/usr/bin/env python3
"""
YellowShifts Phase 10.5 — Platform Administration Security Invariant Suite
"""

import os
import sys
import json
import uuid
import shutil
import subprocess

DB_NAME = "yellowshifts_phase10_5_security_tests"
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
    if not clean_sql.upper().startswith(("SELECT", "INSERT", "UPDATE", "DELETE")):
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
        parsed = json.loads(result_lines[-1])
        return 0, parsed, ""
    except Exception:
        raw = result_lines[-1]
        if raw in ("t", "true"):
            return 0, True, ""
        if raw in ("f", "false"):
            return 0, False, ""
        return 0, raw, ""

def run_as_anon_json(sql: str, db: str = DB_NAME) -> tuple[int, any, str]:
    clean_sql = sql.strip().rstrip(';')
    if not clean_sql.upper().startswith(("SELECT", "INSERT", "UPDATE", "DELETE")):
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
        parsed = json.loads(result_lines[-1])
        return 0, parsed, ""
    except Exception:
        raw = result_lines[-1]
        if raw in ("t", "true"):
            return 0, True, ""
        if raw in ("f", "false"):
            return 0, False, ""
        return 0, raw, ""

def setup_db():
    print(f"[*] Rebuilding isolated Phase 10.5 security test database: {DB_NAME}...")
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

    migration_files = sorted([f for f in os.listdir(MIGRATIONS_DIR) if f.endswith('.sql')])
    for mf in migration_files:
        path = os.path.join(MIGRATIONS_DIR, mf)
        code, _, err = run_psql_file(path)
        if code != 0:
            print(f"[!] Migration {mf} failed:\n{err}")
            sys.exit(1)
    print("[+] Canonical migrations including 018 applied cleanly.")

def main():
    setup_db()
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

    u_platform = str(uuid.uuid4())
    u_platform_inactive = str(uuid.uuid4())
    u_admin_a = str(uuid.uuid4())
    u_admin_a2 = str(uuid.uuid4())
    u_mgr_a = str(uuid.uuid4())
    u_emp_a = str(uuid.uuid4())
    u_admin_b = str(uuid.uuid4())
    u_emp_b = str(uuid.uuid4())
    sta_a = str(uuid.uuid4())
    sta_b = str(uuid.uuid4())

    seed = f"""
    INSERT INTO auth.users (id, email) VALUES
    ('{u_platform}', 'platform@yellowshifts.local'),
    ('{u_platform_inactive}', 'platform.inactive@yellowshifts.local'),
    ('{u_admin_a}', 'admin.a@yellowshifts.local'),
    ('{u_admin_a2}', 'admin.a2@yellowshifts.local'),
    ('{u_mgr_a}', 'mgr.a@yellowshifts.local'),
    ('{u_emp_a}', 'emp.a@yellowshifts.local'),
    ('{u_admin_b}', 'admin.b@yellowshifts.local'),
    ('{u_emp_b}', 'emp.b@yellowshifts.local');

    INSERT INTO public.profiles (id, first_name, last_name) VALUES
    ('{u_platform}', 'Plat', 'Form'),
    ('{u_platform_inactive}', 'Inactive', 'Plat'),
    ('{u_admin_a}', 'Admin', 'Alpha'),
    ('{u_admin_a2}', 'Admin', 'AlphaTwo'),
    ('{u_mgr_a}', 'Mgr', 'Alpha'),
    ('{u_emp_a}', 'Emp', 'Alpha'),
    ('{u_admin_b}', 'Admin', 'Beta'),
    ('{u_emp_b}', 'Emp', 'Beta')
    ON CONFLICT (id) DO UPDATE SET
      first_name = EXCLUDED.first_name,
      last_name = EXCLUDED.last_name;

    INSERT INTO public.stations (id, name, code, is_active) VALUES
    ('{sta_a}', 'Station Alpha', 'STA-A', true),
    ('{sta_b}', 'Station Beta', 'STA-B', true);

    INSERT INTO public.station_memberships (station_id, user_id, role, status) VALUES
    ('{sta_a}', '{u_admin_a}', 'ADMIN', 'ACTIVE'),
    ('{sta_a}', '{u_admin_a2}', 'ADMIN', 'ACTIVE'),
    ('{sta_a}', '{u_mgr_a}', 'SHIFT_MANAGER', 'ACTIVE'),
    ('{sta_a}', '{u_emp_a}', 'EMPLOYEE', 'ACTIVE'),
    ('{sta_b}', '{u_admin_b}', 'ADMIN', 'ACTIVE'),
    ('{sta_b}', '{u_emp_b}', 'EMPLOYEE', 'ACTIVE');

    INSERT INTO public.platform_admins (user_id, is_active) VALUES
    ('{u_platform}', true),
    ('{u_platform_inactive}', false);
    """
    code, _, err = run_psql(seed)
    if code != 0:
        print(f"[!] Seed failed: {err}")
        sys.exit(1)

    print("\n--- PHASE 10.5 PLATFORM ADMIN SECURITY ---")

    code, res, err = run_as_anon_json("public.get_platform_schema_version()")
    assert_test("Schema version is 20260825000019", code == 0 and res.get("schema_version") == "20260825000019", str(res))
    assert_test("Platform version is 1.0.5", res.get("platform_version") == "1.0.5", str(res))

    code, res, err = run_as_anon_json("public.is_platform_admin()")
    assert_test("ANON is not platform admin", code == 0 and res is False, f"{res} {err}")

    code, res, err = run_as_user_json(u_emp_a, "public.is_platform_admin()")
    assert_test("EMPLOYEE is not platform admin", code == 0 and res is False, str(res))

    code, res, err = run_as_user_json(u_admin_a, "public.is_platform_admin()")
    assert_test("Station ADMIN is not platform admin", code == 0 and res is False, str(res))

    code, res, err = run_as_user_json(u_platform, "public.is_platform_admin()")
    assert_test("Active PLATFORM_ADMIN is recognized", code == 0 and res is True, str(res))

    code, res, err = run_as_user_json(u_platform_inactive, "public.is_platform_admin()")
    assert_test("Inactive PLATFORM_ADMIN is denied", code == 0 and res is False, str(res))

    code, res, err = run_as_user_json(u_emp_a, "public.platform_list_stations()")
    assert_test("EMPLOYEE cannot list all stations", code != 0, err)

    code, res, err = run_as_user_json(u_admin_a, "public.platform_list_stations()")
    assert_test("Station ADMIN cannot list all stations via platform RPC", code != 0, err)

    code, res, err = run_as_user_json(u_platform_inactive, "public.platform_list_stations()")
    assert_test("Inactive platform admin cannot list stations", code != 0, err)

    code, res, err = run_as_user_json(u_platform, "public.platform_list_stations()")
    assert_test("PLATFORM_ADMIN can list stations", code == 0 and isinstance(res, list) and len(res) >= 2, str(res))

    code, res, err = run_as_user_json(u_emp_a, f"public.platform_create_station('Hack','HACK-1')")
    assert_test("EMPLOYEE cannot create station", code != 0, err)

    code, res, err = run_as_user_json(u_admin_a, f"public.platform_create_station('Hack','HACK-2')")
    assert_test("Station ADMIN cannot create station", code != 0, err)

    code, res, err = run_as_user_json(u_platform, f"public.platform_create_station('Gamma','STA-G','Asia/Jerusalem','he',0,true,'{u_emp_b}'::uuid,'idem-gamma-1')")
    assert_test("PLATFORM_ADMIN can create station", code == 0 and res.get("success") is True, f"{res} {err}")
    gamma_id = res.get("station_id") if isinstance(res, dict) else None

    code, res2, err = run_as_user_json(u_platform, f"public.platform_create_station('Gamma2','STA-G2','Asia/Jerusalem','he',0,true,'{u_emp_b}'::uuid,'idem-gamma-1')")
    assert_test("Idempotent station create returns original station", code == 0 and res2.get("idempotent") is True and res2.get("station_id") == gamma_id, str(res2))

    code, res, err = run_as_user_json(u_platform, f"public.platform_create_station('Dup','STA-A')")
    assert_test("Duplicate station code is rejected", code != 0 and ("P00106" in err or "already exists" in err.lower()), err)

    mem_emp = run_psql(f"SELECT id FROM public.station_memberships WHERE user_id='{u_emp_a}' AND station_id='{sta_a}';")[1]
    code, res, err = run_as_user_json(u_emp_a, f"public.admin_update_membership('{sta_a}'::uuid,'{mem_emp}'::uuid,'SHIFT_MANAGER','ACTIVE')")
    assert_test("EMPLOYEE cannot self-promote to SHIFT_MANAGER", code != 0, err)

    code, res, err = run_as_user_json(u_emp_a, f"public.admin_update_membership('{sta_a}'::uuid,'{mem_emp}'::uuid,'ADMIN','ACTIVE')")
    assert_test("EMPLOYEE cannot self-promote to ADMIN", code != 0, err)

    code, res, err = run_as_user_json(u_mgr_a, f"public.admin_update_membership('{sta_a}'::uuid,'{mem_emp}'::uuid,'ADMIN','ACTIVE')")
    assert_test("SHIFT_MANAGER cannot make others ADMIN", code != 0, err)

    mem_mgr = run_psql(f"SELECT id FROM public.station_memberships WHERE user_id='{u_mgr_a}' AND station_id='{sta_a}';")[1]
    code, res, err = run_as_user_json(u_admin_a, f"public.admin_update_membership('{sta_a}'::uuid,'{mem_emp}'::uuid,'SHIFT_MANAGER','ACTIVE')")
    assert_test("ADMIN can promote EMPLOYEE to SHIFT_MANAGER", code == 0 and res.get("role") == "SHIFT_MANAGER", str(res))

    code, res, err = run_as_user_json(u_admin_a, f"public.admin_update_membership('{sta_a}'::uuid,'{mem_emp}'::uuid,'EMPLOYEE','ACTIVE')")
    assert_test("ADMIN can demote SHIFT_MANAGER to EMPLOYEE", code == 0 and res.get("role") == "EMPLOYEE", str(res))

    code, res, err = run_as_user_json(u_admin_a, f"public.admin_update_membership('{sta_a}'::uuid,'{mem_emp}'::uuid,'ADMIN','ACTIVE')")
    assert_test("ADMIN cannot assign ADMIN", code != 0 and "P00105" in err, err)

    mem_admin_a2 = run_psql(f"SELECT id FROM public.station_memberships WHERE user_id='{u_admin_a2}' AND station_id='{sta_a}';")[1]
    code, res, err = run_as_user_json(u_admin_a, f"public.admin_update_membership('{sta_a}'::uuid,'{mem_admin_a2}'::uuid,'EMPLOYEE','ACTIVE')")
    assert_test("ADMIN cannot demote another ADMIN", code != 0 and "P00105" in err, err)

    code, res, err = run_as_user_json(u_admin_a, f"INSERT INTO public.platform_admins(user_id,is_active) VALUES ('{u_admin_a}', true) RETURNING user_id")
    assert_test("Station ADMIN cannot insert platform_admins", code != 0, err)

    code, res, err = run_as_user_json(u_emp_a, f"INSERT INTO public.station_memberships (station_id,user_id,role,status) VALUES ('{sta_b}','{u_emp_a}','ADMIN','ACTIVE') RETURNING id")
    assert_test("EMPLOYEE cannot insert ADMIN membership via table", code != 0, err)

    code, res, err = run_as_user_json(u_admin_a, f"UPDATE public.station_memberships SET role='ADMIN' WHERE id='{mem_emp}' RETURNING role")
    assert_test("Station ADMIN cannot UPDATE membership to ADMIN via table", code != 0 and "P00105" in err, err)

    code, res, err = run_as_user_json(u_platform, f"public.platform_assign_station_admin('{sta_b}'::uuid,'{u_emp_b}'::uuid)")
    assert_test("PLATFORM_ADMIN can assign ADMIN", code == 0 and res.get("success") is True, str(res))

    code, cnt, _ = run_psql(f"SELECT COUNT(*) FROM public.station_memberships WHERE user_id='{u_platform}'")
    assert_test("PLATFORM_ADMIN has zero station_memberships rows", cnt == "0", cnt)

    code, res, err = run_as_user_json(u_admin_a, f"public.platform_assign_station_admin('{sta_b}'::uuid,'{u_emp_a}'::uuid)")
    assert_test("Station ADMIN cannot assign ADMIN via platform RPC", code != 0, err)

    code, res, err = run_as_user_json(u_admin_a, f"public.admin_update_station('{sta_b}'::uuid,'Hacked','STA-B','Asia/Jerusalem','he',0,true,5,15,false,NULL)")
    # After is_station_admin includes platform only; station admin of A is still not admin of B
    assert_test("Admin Alpha cannot update Station Beta", code != 0, err)

    code, res, err = run_as_user_json(u_platform, f"public.is_station_admin('{sta_a}'::uuid,'{u_platform}'::uuid)")
    assert_test("PLATFORM_ADMIN can_administer station without membership", code == 0 and res is True, str(res))

    code, res, err = run_as_user_json(u_platform, f"public.platform_remove_station_admin('{sta_a}'::uuid,'{u_admin_a2}'::uuid,'Replacement coverage')")
    assert_test("PLATFORM_ADMIN can remove extra ADMIN", code == 0, f"{res} {err}")

    code, res, err = run_as_user_json(u_platform, f"public.platform_remove_station_admin('{sta_a}'::uuid,'{u_admin_a}'::uuid,'Would leave zero')")
    assert_test("Last active ADMIN cannot be removed on active station", code != 0 and "P0001" in err, err)

    code, res, err = run_as_user_json(u_admin_a, f"SELECT COUNT(*) FROM public.audit_logs WHERE station_id='{sta_b}'")
    # RLS: admin A should not see beta audits (is_station_admin for B is false for admin A)
    assert_test("Station Admin Alpha cannot browse Beta audit logs", code == 0 and str(res) in ("0", 0), str(res))

    code, res, err = run_as_user_json(u_platform, f"public.platform_query_audit_logs('{sta_a}'::uuid,NULL,NULL,NULL,NULL,50,0)")
    assert_test("PLATFORM_ADMIN can query platform audit logs", code == 0 and isinstance(res, dict), str(res))

    code, sp, _ = run_psql("""
    SELECT COUNT(*) FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname='platform_create_station'
      AND p.proconfig @> ARRAY['search_path=public, pg_temp'];
    """)
    assert_test("platform_create_station has pinned search_path", sp == "1", sp)

    print(f"\n[+] Phase 10.5 security: {passed}/{total} passed")
    sys.exit(0 if passed == total else 1)

if __name__ == "__main__":
    main()
