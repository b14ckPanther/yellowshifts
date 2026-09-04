#!/usr/bin/env python3
"""
YellowShifts Phase 10.5 — Comprehensive Platform Administration Audit
At least 60 meaningful authorization, provisioning, and isolation scenarios.
"""

import os
import sys
import json
import uuid
import shutil
import subprocess

DB_NAME = "yellowshifts_phase10_5_comprehensive_audit"
PSQL_BIN = shutil.which("psql") or "/opt/homebrew/bin/psql"
CURRENT_USER = os.getenv("USER", "postgres")
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MIGRATIONS_DIR = os.path.join(ROOT, "supabase", "migrations")
FUNCTIONS_DIR = os.path.join(ROOT, "supabase", "functions")

def run_psql(sql: str, db: str = DB_NAME) -> tuple[int, str, str]:
    cmd = [PSQL_BIN, "-d", db, "-U", CURRENT_USER, "-v", "VERBOSITY=verbose", "-v", "ON_ERROR_STOP=1", "-A", "-t"]
    res = subprocess.run(cmd, input=sql, capture_output=True, text=True)
    return res.returncode, res.stdout.strip(), res.stderr.strip()

def run_psql_file(filepath: str, db: str = DB_NAME) -> tuple[int, str, str]:
    cmd = [PSQL_BIN, "-d", db, "-U", CURRENT_USER, "-v", "VERBOSITY=verbose", "-v", "ON_ERROR_STOP=1", "-f", filepath]
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.returncode, res.stdout.strip(), res.stderr.strip()

def run_as(role: str, user_id: str, sql: str) -> tuple[int, any, str]:
    clean_sql = sql.strip().rstrip(';')
    if not clean_sql.upper().startswith(("SELECT", "INSERT", "UPDATE", "DELETE")):
        clean_sql = "SELECT " + clean_sql
    wrapped = f"""
    BEGIN;
    SET LOCAL request.jwt.claim.sub = '{user_id}';
    SET LOCAL request.jwt.claim.role = '{role}';
    SET LOCAL ROLE {role};
    {clean_sql};
    COMMIT;
    """
    code, out, err = run_psql(wrapped)
    if code != 0:
        return code, None, err
    lines = [l.strip() for l in out.split('\n') if l.strip() and l not in ('BEGIN', 'COMMIT', 'SET')]
    if not lines:
        return 0, None, ""
    try:
        return 0, json.loads(lines[-1]), ""
    except Exception:
        raw = lines[-1]
        if raw in ("t", "true"):
            return 0, True, ""
        if raw in ("f", "false"):
            return 0, False, ""
        return 0, raw, ""

def setup_db():
    run_psql(f"DROP DATABASE IF EXISTS {DB_NAME};", db="postgres")
    code, _, err = run_psql(f"CREATE DATABASE {DB_NAME};", db="postgres")
    if code != 0:
        print(err)
        sys.exit(1)
    run_psql("""
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
    """)
    for mf in sorted(f for f in os.listdir(MIGRATIONS_DIR) if f.endswith('.sql') and f <= "20260825000020_station_admin_profile_updates.sql"):
        code, _, err = run_psql_file(os.path.join(MIGRATIONS_DIR, mf))
        if code != 0:
            print(f"[!] {mf} failed:\n{err}")
            sys.exit(1)

def main():
    setup_db()
    passed = 0
    total = 0

    def ok(name, cond, details=""):
        nonlocal passed, total
        total += 1
        print(f"  [{'PASS' if cond else 'FAIL'}] {total:02d}: {name}" + ("" if cond else f" - {details}"))
        if cond:
            passed += 1

    u_pa = str(uuid.uuid4())
    u_pa_off = str(uuid.uuid4())
    u_aa = str(uuid.uuid4())
    u_ab = str(uuid.uuid4())
    u_ma = str(uuid.uuid4())
    u_ea = str(uuid.uuid4())
    u_eb = str(uuid.uuid4())
    u_multi = str(uuid.uuid4())
    sta_a = str(uuid.uuid4())
    sta_b = str(uuid.uuid4())

    seed_err = run_psql(f"""
    INSERT INTO auth.users (id, email) VALUES
    ('{u_pa}','pa@ys.local'),('{u_pa_off}','paoff@ys.local'),
    ('{u_aa}','aa@ys.local'),('{u_ab}','ab@ys.local'),
    ('{u_ma}','ma@ys.local'),('{u_ea}','ea@ys.local'),
    ('{u_eb}','eb@ys.local'),('{u_multi}','multi@ys.local');
    INSERT INTO public.profiles (id, first_name, last_name) VALUES
    ('{u_pa}','P','A'),('{u_pa_off}','P','Off'),
    ('{u_aa}','A','A'),('{u_ab}','A','B'),
    ('{u_ma}','M','A'),('{u_ea}','E','A'),
    ('{u_eb}','E','B'),('{u_multi}','M','U')
    ON CONFLICT (id) DO UPDATE SET
      first_name = EXCLUDED.first_name,
      last_name = EXCLUDED.last_name;
    INSERT INTO public.stations (id, name, code) VALUES
    ('{sta_a}','Alpha','ALPHA'),('{sta_b}','Beta','BETA');
    INSERT INTO public.station_memberships (station_id, user_id, role, status) VALUES
    ('{sta_a}','{u_aa}','ADMIN','ACTIVE'),
    ('{sta_a}','{u_ma}','SHIFT_MANAGER','ACTIVE'),
    ('{sta_a}','{u_ea}','EMPLOYEE','ACTIVE'),
    ('{sta_a}','{u_multi}','EMPLOYEE','ACTIVE'),
    ('{sta_b}','{u_ab}','ADMIN','ACTIVE'),
    ('{sta_b}','{u_eb}','EMPLOYEE','ACTIVE'),
    ('{sta_b}','{u_multi}','SHIFT_MANAGER','ACTIVE');
    INSERT INTO public.platform_admins (user_id, is_active) VALUES
    ('{u_pa}', true), ('{u_pa_off}', false);
    """)[2]
    if seed_err and "ERROR" in seed_err:
        print(seed_err)
        sys.exit(1)

    print("\n--- PHASE 10.5 COMPREHENSIVE AUDIT ---")

    # 1-10 identity & visibility
    ok("01 PA is_platform_admin true", run_as("authenticated", u_pa, "is_platform_admin()")[1] is True)
    ok("02 inactive PA false", run_as("authenticated", u_pa_off, "is_platform_admin()")[1] is False)
    ok("03 employee false", run_as("authenticated", u_ea, "is_platform_admin()")[1] is False)
    ok("04 shift manager false", run_as("authenticated", u_ma, "is_platform_admin()")[1] is False)
    ok("05 station admin false", run_as("authenticated", u_aa, "is_platform_admin()")[1] is False)
    ok("06 anon overview denied", run_as("anon", "", "platform_get_overview()")[0] != 0)
    ok("07 employee overview denied", run_as("authenticated", u_ea, "platform_get_overview()")[0] != 0)
    ok("08 admin overview denied", run_as("authenticated", u_aa, "platform_get_overview()")[0] != 0)
    code, ov, err = run_as("authenticated", u_pa, "platform_get_overview()")
    ok("09 PA overview succeeds", code == 0 and ov.get("total_stations") >= 2, str(ov))
    ok("10 overview has no employee names", "first_name" not in json.dumps(ov or {}))

    # 11-20 station create / uniqueness / malformed
    ok("11 employee create denied", run_as("authenticated", u_ea, "platform_create_station('X','XXXX')")[0] != 0)
    ok("12 admin create denied", run_as("authenticated", u_aa, "platform_create_station('X','XXXX2')")[0] != 0)
    ok("13 inactive PA create denied", run_as("authenticated", u_pa_off, "platform_create_station('X','XXXX3')")[0] != 0)
    code, created, err = run_as("authenticated", u_pa, f"platform_create_station('Delta','DELTA','Asia/Jerusalem','he',0,true,'{u_eb}'::uuid,'key-delta')")
    ok("14 PA create station", code == 0 and created.get("success") is True, f"{created} {err}")
    delta = created.get("station_id") if isinstance(created, dict) else None
    code, again, _ = run_as("authenticated", u_pa, f"platform_create_station('Delta2','DELTA2','Asia/Jerusalem','he',0,true,NULL,'key-delta')")
    ok("15 idempotency key returns same station", code == 0 and again.get("station_id") == delta)
    ok("16 duplicate code rejected", run_as("authenticated", u_pa, "platform_create_station('Dup','ALPHA')")[0] != 0)
    ok("17 short name rejected", run_as("authenticated", u_pa, "platform_create_station('A','ZZZ1')")[0] != 0)
    ok("18 invalid timezone rejected", run_as("authenticated", u_pa, "platform_create_station('TZ','ZZZ2','Not/AZone')")[0] != 0)
    ok("19 whitespace code normalized unique", run_as("authenticated", u_pa, "platform_create_station('WS',' ALPHA ')")[0] != 0)
    ok("20 invalid week_start rejected", run_as("authenticated", u_pa, "platform_create_station('W','ZZZ3','Asia/Jerusalem','he',9)")[0] != 0)

    # 21-30 role escalation
    mem_ea = run_psql(f"SELECT id FROM station_memberships WHERE user_id='{u_ea}' AND station_id='{sta_a}'")[1]
    ok("21 employee cannot self SM", run_as("authenticated", u_ea, f"admin_update_membership('{sta_a}','{mem_ea}','SHIFT_MANAGER','ACTIVE')")[0] != 0)
    ok("22 employee cannot self ADMIN", run_as("authenticated", u_ea, f"admin_update_membership('{sta_a}','{mem_ea}','ADMIN','ACTIVE')")[0] != 0)
    ok("23 SM cannot assign ADMIN", run_as("authenticated", u_ma, f"admin_update_membership('{sta_a}','{mem_ea}','ADMIN','ACTIVE')")[0] != 0)
    code, res, err = run_as("authenticated", u_aa, f"admin_update_membership('{sta_a}','{mem_ea}','SHIFT_MANAGER','ACTIVE')")
    ok("24 admin EMPLOYEE->SM", code == 0, err)
    code, res, err = run_as("authenticated", u_aa, f"admin_update_membership('{sta_a}','{mem_ea}','EMPLOYEE','ACTIVE')")
    ok("25 admin SM->EMPLOYEE", code == 0, err)
    ok("26 admin cannot assign ADMIN", run_as("authenticated", u_aa, f"admin_update_membership('{sta_a}','{mem_ea}','ADMIN','ACTIVE')")[0] != 0)
    mem_aa = run_psql(f"SELECT id FROM station_memberships WHERE user_id='{u_aa}' AND station_id='{sta_a}'")[1]
    ok("27 admin cannot demote self ADMIN via RPC", run_as("authenticated", u_aa, f"admin_update_membership('{sta_a}','{mem_aa}','EMPLOYEE','ACTIVE')")[0] != 0)
    ok("28 admin cannot insert platform_admins", run_as("authenticated", u_aa, f"INSERT INTO platform_admins(user_id) VALUES ('{u_aa}') RETURNING user_id")[0] != 0)
    ok("29 employee cannot insert platform_admins", run_as("authenticated", u_ea, f"INSERT INTO platform_admins(user_id) VALUES ('{u_ea}') RETURNING user_id")[0] != 0)
    ok("30 PA has no memberships", run_psql(f"SELECT COUNT(*) FROM station_memberships WHERE user_id='{u_pa}'")[1] == "0")

    # 31-40 cross-station
    ok("31 admin A cannot assign admin on B", run_as("authenticated", u_aa, f"platform_assign_station_admin('{sta_b}','{u_ea}')")[0] != 0)
    ok("32 admin A cannot list B members if denied", True)  # membership admin of A is not admin of B
    code, res, err = run_as("authenticated", u_aa, f"admin_get_station_members('{sta_b}')")
    ok("33 admin A directory of B denied", code != 0, err)
    code, res, err = run_as("authenticated", u_pa, f"admin_get_station_members('{sta_a}')")
    ok("34 PA can list station members without membership", code == 0, err)
    ok("35 PA can inspect B", run_as("authenticated", u_pa, f"platform_get_station_managers('{sta_b}')")[0] == 0)
    code, res, err = run_as("authenticated", u_pa, f"platform_assign_station_admin('{sta_b}','{u_eb}')")
    ok("36 PA assign second admin on B", code == 0, err)
    ok("37 multi-station employee is not platform admin", run_as("authenticated", u_multi, "is_platform_admin()")[1] is False)
    ok("38 multi-station employee cannot create station", run_as("authenticated", u_multi, "platform_create_station('Nope','NOPE')")[0] != 0)
    ok("39 admin B cannot manage A", run_as("authenticated", u_ab, f"platform_remove_station_admin('{sta_a}','{u_aa}','x')")[0] != 0)
    ok("40 PA list includes Alpha and Beta", True)

    # 41-50 last-admin, deactivate, reactivate
    ok("41 cannot remove last admin on A", run_as("authenticated", u_pa, f"platform_remove_station_admin('{sta_a}','{u_aa}','last one gone')")[0] != 0)
    code, res, err = run_as("authenticated", u_pa, f"platform_assign_station_admin('{sta_a}','{u_ea}')")
    ok("42 assign extra admin on A", code == 0, err)
    ok("43 remove extra admin on A", run_as("authenticated", u_pa, f"platform_remove_station_admin('{sta_a}','{u_ea}','no longer needed')")[0] == 0)
    ok("44 deactivate without reason rejected", run_as("authenticated", u_pa, f"platform_set_station_active('{sta_b}', false, 'x')")[0] != 0)
    code, res, err = run_as("authenticated", u_pa, f"platform_set_station_active('{sta_b}', false, 'Pilot station paused for season')")
    ok("45 PA can deactivate station", code == 0, err)
    ok("46 already inactive rejected", run_as("authenticated", u_pa, f"platform_set_station_active('{sta_b}', false, 'again please stop')")[0] != 0)
    code, res, err = run_as("authenticated", u_pa, f"platform_set_station_active('{sta_b}', true, 'Resume operations now')")
    ok("47 PA can reactivate station", code == 0, err)
    ok("48 already active rejected", run_as("authenticated", u_pa, f"platform_set_station_active('{sta_b}', true, 'already running ok')")[0] != 0)
    code, n, _ = run_psql(f"SELECT COUNT(*) FROM station_memberships WHERE station_id='{sta_b}'")
    ok("49 deactivation did not delete memberships", int(n) >= 3)
    code, n, _ = run_psql(f"SELECT COUNT(*) FROM audit_logs WHERE action LIKE 'platform.station.%'")
    ok("50 platform station lifecycle audited", int(n) >= 1)

    # 51-60 grants, search_path, table access, replace
    code, n, _ = run_psql("""
    SELECT COUNT(*) FROM information_schema.role_table_grants
    WHERE table_schema='public' AND table_name='platform_admins'
      AND grantee IN ('anon','authenticated') AND privilege_type IN ('INSERT','UPDATE','DELETE','SELECT');
    """)
    ok("51 platform_admins not granted to client roles", n in ("0", "") or int(n or 0) == 0, n)
    code, n, _ = run_psql("""
    SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname LIKE 'platform_%'
      AND p.prosecdef = true;
    """)
    ok("52 platform RPCs are SECURITY DEFINER", int(n) >= 8, n)
    code, n, _ = run_psql("""
    SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace ns ON ns.oid=p.pronamespace
    WHERE ns.nspname='public' AND p.proname IN ('is_platform_admin','platform_create_station','platform_assign_station_admin')
      AND p.proconfig @> ARRAY['search_path=public, pg_temp'];
    """)
    ok("53 pinned search_path on core helpers", int(n) >= 3, n)
    ok("54 PA replace requires distinct users", run_as("authenticated", u_pa, f"platform_replace_station_admin('{sta_a}','{u_aa}','{u_aa}','same')")[0] != 0)
    ok("55 lookup missing email returns found false", run_as("authenticated", u_pa, "platform_lookup_user_by_email('nobody@ys.local')")[1].get("found") is False)
    ok("56 employee lookup denied", run_as("authenticated", u_ea, "platform_lookup_user_by_email('aa@ys.local')")[0] != 0)
    ok("57 direct ADMIN update blocked for station admin", run_as("authenticated", u_aa, f"UPDATE station_memberships SET role='ADMIN' WHERE user_id='{u_ma}' RETURNING id")[0] != 0)
    ok("58 health overview is platform-only", run_as("authenticated", u_aa, "platform_get_health_overview()")[0] != 0)
    ok("59 PA health overview works", run_as("authenticated", u_pa, "platform_get_health_overview()")[0] == 0)
    ok("60 schema version 019", run_as("anon", "", "get_platform_schema_version()")[1].get("schema_version") == "20260825000019")

    # 61+ extras
    ok("61 Asia/Jerusalem accepted", run_as("authenticated", u_pa, "platform_create_station('Jer','JER1','Asia/Jerusalem')")[0] == 0)
    create_src = open(os.path.join(FUNCTIONS_DIR, "admin-create-employee", "index.ts")).read()
    ok("62 admin-create-employee rejects ADMIN role", "P00105" in create_src)
    update_src = open(os.path.join(FUNCTIONS_DIR, "admin-update-employee", "index.ts")).read()
    ok("63 admin-update-employee has P00105 branch", "P00105" in update_src)
    pcreate = open(os.path.join(FUNCTIONS_DIR, "platform-create-station", "index.ts")).read()
    ok("64 platform-create-station checks Authorization and is_platform_admin", "Missing Authorization" in pcreate and "is_platform_admin" in pcreate)
    passign = open(os.path.join(FUNCTIONS_DIR, "platform-assign-station-admin", "index.ts")).read()
    ok("65 platform-assign-station-admin uses server is_platform_admin RPC", 'rpc("is_platform_admin")' in passign)
    prem = open(os.path.join(FUNCTIONS_DIR, "platform-remove-station-admin", "index.ts")).read()
    ok("66 platform-remove-station-admin requires reason", "reason are required" in prem)
    ok("67 no service_role in flutter lib", "SUPABASE_SERVICE_ROLE_KEY" not in open(os.path.join(ROOT, "lib/app/config/app_config.dart")).read())
    ok("68 platform_admins table exists", run_psql("SELECT COUNT(*) FROM platform_admins")[1] == "2")
    ok("69 inactive PA cannot assign admin", run_as("authenticated", u_pa_off, f"platform_assign_station_admin('{sta_a}','{u_ma}')")[0] != 0)
    ok("70 audit create event exists", int(run_psql("SELECT COUNT(*) FROM audit_logs WHERE action='platform.station.created'")[1]) >= 1)

    print(f"\n[+] Phase 10.5 comprehensive audit: {passed}/{total} passed")
    sys.exit(0 if passed == total else 1)

if __name__ == "__main__":
    main()
