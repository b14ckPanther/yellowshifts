#!/usr/bin/env python3
"""
YellowShifts Phase 10.5 — Independent engineering audit suite.

This is NOT a wrapper of the implementation security/comprehensive suites.
It independently proves the authorization, isolation, provisioning, grant,
and schema-version claims that certification depends on.
"""

import json
import os
import shutil
import subprocess
import sys
import uuid

DB_NAME = "yellowshifts_phase10_5_independent_audit"
PSQL_BIN = shutil.which("psql") or "/opt/homebrew/bin/psql"
CURRENT_USER = os.getenv("USER", "postgres")
MIGRATIONS_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "supabase", "migrations")
)


def run_psql(sql: str, db: str = DB_NAME) -> tuple[int, str, str]:
    cmd = [
        PSQL_BIN, "-d", db, "-U", CURRENT_USER,
        "-v", "VERBOSITY=verbose", "-v", "ON_ERROR_STOP=1", "-A", "-t",
    ]
    res = subprocess.run(cmd, input=sql, capture_output=True, text=True)
    return res.returncode, res.stdout.strip(), res.stderr.strip()


def run_psql_file(filepath: str, db: str = DB_NAME) -> tuple[int, str, str]:
    cmd = [
        PSQL_BIN, "-d", db, "-U", CURRENT_USER,
        "-v", "VERBOSITY=verbose", "-v", "ON_ERROR_STOP=1", "-f", filepath,
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.returncode, res.stdout.strip(), res.stderr.strip()


def _parse_result(stdout: str):
    lines = [line.strip() for line in stdout.strip().split("\n") if line.strip()]
    result_lines = [l for l in lines if l not in ("BEGIN", "COMMIT", "SET")]
    if not result_lines:
        return None
    raw = result_lines[-1]
    try:
        return json.loads(raw)
    except Exception:
        if raw in ("t", "true"):
            return True
        if raw in ("f", "false"):
            return False
        return raw


def run_as(role: str, user_id: str, sql: str) -> tuple[int, object, str]:
    clean_sql = sql.strip().rstrip(";")
    if not clean_sql.upper().startswith(("SELECT", "INSERT", "UPDATE", "DELETE")):
        clean_sql = "SELECT " + clean_sql
    jwt_role = "anon" if role == "anon" else "authenticated"
    jwt_sub = "" if role == "anon" else user_id
    wrapped = f"""
    BEGIN;
    SET LOCAL request.jwt.claim.sub = '{jwt_sub}';
    SET LOCAL request.jwt.claim.role = '{jwt_role}';
    SET LOCAL ROLE {role};
    {clean_sql};
    COMMIT;
    """
    code, out, err = run_psql(wrapped)
    if code != 0:
        return code, None, err
    return 0, _parse_result(out), ""


def setup_db():
    print(f"[*] Rebuilding isolated independent audit database: {DB_NAME}...")
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

    migration_files = sorted(f for f in os.listdir(MIGRATIONS_DIR) if f.endswith(".sql"))
    for mf in migration_files:
        path = os.path.join(MIGRATIONS_DIR, mf)
        code, _, err = run_psql_file(path)
        if code != 0:
            print(f"[!] Migration {mf} failed:\n{err}")
            sys.exit(1)
    print(f"[+] Applied {len(migration_files)} migrations (including 018/019).")


def main():
    setup_db()
    passed = 0
    total = 0

    def ok(name: str, condition: bool, details: str = ""):
        nonlocal passed, total
        total += 1
        if condition:
            passed += 1
            print(f"  [PASS] {total:02d}: {name}")
        else:
            print(f"  [FAIL] {total:02d}: {name} - {details}")

    u_pa = str(uuid.uuid4())
    u_pa2 = str(uuid.uuid4())
    u_pa_off = str(uuid.uuid4())
    u_aa = str(uuid.uuid4())
    u_aa2 = str(uuid.uuid4())
    u_ma = str(uuid.uuid4())
    u_ea = str(uuid.uuid4())
    u_ab = str(uuid.uuid4())
    u_eb = str(uuid.uuid4())
    u_multi = str(uuid.uuid4())
    sta_a = str(uuid.uuid4())
    sta_b = str(uuid.uuid4())

    seed = f"""
    INSERT INTO auth.users (id, email) VALUES
    ('{u_pa}', 'pa.active@yellowshifts.audit'),
    ('{u_pa2}', 'pa.two@yellowshifts.audit'),
    ('{u_pa_off}', 'pa.off@yellowshifts.audit'),
    ('{u_aa}', 'admin.alpha@yellowshifts.audit'),
    ('{u_aa2}', 'admin.alpha2@yellowshifts.audit'),
    ('{u_ma}', 'mgr.alpha@yellowshifts.audit'),
    ('{u_ea}', 'emp.alpha@yellowshifts.audit'),
    ('{u_ab}', 'admin.beta@yellowshifts.audit'),
    ('{u_eb}', 'emp.beta@yellowshifts.audit'),
    ('{u_multi}', 'multi@yellowshifts.audit');

    INSERT INTO public.profiles (id, first_name, last_name) VALUES
    ('{u_pa}', 'Plat', 'One'),
    ('{u_pa2}', 'Plat', 'Two'),
    ('{u_pa_off}', 'Plat', 'Off'),
    ('{u_aa}', 'Admin', 'Alpha'),
    ('{u_aa2}', 'Admin', 'AlphaTwo'),
    ('{u_ma}', 'Mgr', 'Alpha'),
    ('{u_ea}', 'Emp', 'Alpha'),
    ('{u_ab}', 'Admin', 'Beta'),
    ('{u_eb}', 'Emp', 'Beta'),
    ('{u_multi}', 'Multi', 'Station')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name;

    INSERT INTO public.stations (id, name, code, is_active) VALUES
    ('{sta_a}', 'Station Alpha', 'AUD-A', true),
    ('{sta_b}', 'Station Beta', 'AUD-B', true);

    INSERT INTO public.station_memberships (station_id, user_id, role, status) VALUES
    ('{sta_a}', '{u_aa}', 'ADMIN', 'ACTIVE'),
    ('{sta_a}', '{u_aa2}', 'ADMIN', 'ACTIVE'),
    ('{sta_a}', '{u_ma}', 'SHIFT_MANAGER', 'ACTIVE'),
    ('{sta_a}', '{u_ea}', 'EMPLOYEE', 'ACTIVE'),
    ('{sta_b}', '{u_ab}', 'ADMIN', 'ACTIVE'),
    ('{sta_b}', '{u_eb}', 'EMPLOYEE', 'ACTIVE'),
    ('{sta_a}', '{u_multi}', 'EMPLOYEE', 'ACTIVE'),
    ('{sta_b}', '{u_multi}', 'EMPLOYEE', 'ACTIVE');

    INSERT INTO public.platform_admins (user_id, is_active) VALUES
    ('{u_pa}', true),
    ('{u_pa2}', true),
    ('{u_pa_off}', false);
    """
    code, _, err = run_psql(seed)
    if code != 0:
        print(f"[!] Seed failed: {err}")
        sys.exit(1)

    mem_ea = run_psql(
        f"SELECT id FROM public.station_memberships WHERE user_id='{u_ea}' AND station_id='{sta_a}';"
    )[1]
    mem_ma = run_psql(
        f"SELECT id FROM public.station_memberships WHERE user_id='{u_ma}' AND station_id='{sta_a}';"
    )[1]
    mem_aa2 = run_psql(
        f"SELECT id FROM public.station_memberships WHERE user_id='{u_aa2}' AND station_id='{sta_a}';"
    )[1]
    mem_aa = run_psql(
        f"SELECT id FROM public.station_memberships WHERE user_id='{u_aa}' AND station_id='{sta_a}';"
    )[1]
    mem_ab = run_psql(
        f"SELECT id FROM public.station_memberships WHERE user_id='{u_ab}' AND station_id='{sta_b}';"
    )[1]

    print("\n--- PHASE 10.5 INDEPENDENT AUDIT ---")

    # --- Schema / version ---
    code, res, err = run_as("anon", "", "public.get_platform_schema_version()")
    ok("schema version is 20260825000019", code == 0 and res.get("schema_version") == "20260825000019", str(res))
    ok("platform version is 1.0.5", code == 0 and res.get("platform_version") == "1.0.5", str(res))
    ok("min compatible client is 1.0.0", code == 0 and res.get("min_compatible_client_version") == "1.0.0", str(res))
    ok("schema status HEALTHY", code == 0 and res.get("status") == "HEALTHY", str(res))

    # --- is_platform_admin identity ---
    code, res, err = run_as("anon", "", "public.is_platform_admin()")
    ok("ANON is_platform_admin is false", code == 0 and res is False, f"{res} {err}")

    code, res, err = run_as("authenticated", u_ea, "public.is_platform_admin()")
    ok("EMPLOYEE is_platform_admin is false", code == 0 and res is False, str(res))

    code, res, err = run_as("authenticated", u_ma, "public.is_platform_admin()")
    ok("SHIFT_MANAGER is_platform_admin is false", code == 0 and res is False, str(res))

    code, res, err = run_as("authenticated", u_aa, "public.is_platform_admin()")
    ok("Station ADMIN is_platform_admin is false", code == 0 and res is False, str(res))

    code, res, err = run_as("authenticated", u_pa_off, "public.is_platform_admin()")
    ok("inactive PLATFORM_ADMIN is_platform_admin is false", code == 0 and res is False, str(res))

    code, res, err = run_as("authenticated", u_pa, "public.is_platform_admin()")
    ok("active PLATFORM_ADMIN is_platform_admin is true", code == 0 and res is True, str(res))

    code, res, err = run_as("authenticated", u_ea, f"public.is_platform_admin('{u_pa}'::uuid)")
    ok("EMPLOYEE cannot impersonate PA by supplying PA uuid", code == 0 and res is False, str(res))

    code, res, err = run_as("authenticated", u_aa, f"public.is_platform_admin('{u_pa}'::uuid)")
    ok("Station ADMIN cannot impersonate PA by supplying PA uuid", code == 0 and res is False, str(res))

    code, res, err = run_as("authenticated", u_pa, f"public.is_platform_admin('{u_ea}'::uuid)")
    ok("active PA remains true even if a foreign uuid is supplied", code == 0 and res is True, str(res))

    code, res, err = run_as("authenticated", u_pa_off, f"public.is_platform_admin('{u_pa}'::uuid)")
    ok("inactive PA remains false even if an active PA uuid is supplied", code == 0 and res is False, str(res))

    # --- PA oracle / is_station_admin blast-radius restriction ---
    code, res, err = run_as("authenticated", u_ea, f"public.is_station_admin('{sta_a}'::uuid,'{u_pa}'::uuid)")
    ok("EMPLOYEE cannot detect PA via is_station_admin oracle", code == 0 and res is False, str(res))

    code, res, err = run_as("authenticated", u_aa, f"public.is_station_admin('{sta_b}'::uuid,'{u_pa}'::uuid)")
    ok("Station ADMIN cannot detect PA via is_station_admin on another station", code == 0 and res is False, str(res))

    code, res, err = run_as("authenticated", u_pa, f"public.is_station_admin('{sta_a}'::uuid,'{u_pa}'::uuid)")
    ok("PA can_administer a station without membership when probing self", code == 0 and res is True, str(res))

    code, res, err = run_as("authenticated", u_pa_off, f"public.is_station_admin('{sta_a}'::uuid,'{u_pa_off}'::uuid)")
    ok("inactive PA is_station_admin is false", code == 0 and res is False, str(res))

    code, res, err = run_as("authenticated", u_aa, f"public.is_station_admin('{sta_a}'::uuid,'{u_aa}'::uuid)")
    ok("Station ADMIN Alpha is admin of Alpha", code == 0 and res is True, str(res))

    code, res, err = run_as("authenticated", u_aa, f"public.is_station_admin('{sta_b}'::uuid,'{u_aa}'::uuid)")
    ok("Station ADMIN Alpha is not admin of Beta", code == 0 and res is False, str(res))

    code, res, err = run_as(
        "authenticated", u_ea,
        f"public.has_station_permission('{sta_a}'::uuid,'{u_pa}'::uuid,'schedule.manage')",
    )
    ok("EMPLOYEE cannot probe PA via has_station_permission", code == 0 and res is False, str(res))

    code, res, err = run_as(
        "authenticated", u_pa,
        f"public.has_station_permission('{sta_b}'::uuid,'{u_pa}'::uuid,'schedule.manage')",
    )
    ok("PA has_station_permission for self without membership", code == 0 and res is True, str(res))

    # --- Grants ---
    exec_internal = run_psql(
        "SELECT has_function_privilege('authenticated', 'public._active_platform_admin(uuid)', 'EXECUTE');"
    )[1]
    ok("authenticated cannot EXECUTE _active_platform_admin", exec_internal in ("f", "false"), exec_internal)

    exec_anon_internal = run_psql(
        "SELECT has_function_privilege('anon', 'public._active_platform_admin(uuid)', 'EXECUTE');"
    )[1]
    ok("anon cannot EXECUTE _active_platform_admin", exec_anon_internal in ("f", "false"), exec_anon_internal)

    tbl_pa = run_psql(
        "SELECT has_table_privilege('authenticated', 'public.platform_admins', 'INSERT');"
    )[1]
    ok("authenticated cannot INSERT platform_admins", tbl_pa in ("f", "false"), tbl_pa)

    tbl_keys = run_psql(
        "SELECT has_table_privilege('authenticated', 'public.platform_provisioning_keys', 'SELECT');"
    )[1]
    ok("authenticated cannot SELECT platform_provisioning_keys", tbl_keys in ("f", "false"), tbl_keys)

    tbl_keys_ins = run_psql(
        "SELECT has_table_privilege('authenticated', 'public.platform_provisioning_keys', 'INSERT');"
    )[1]
    ok("authenticated cannot INSERT platform_provisioning_keys", tbl_keys_ins in ("f", "false"), tbl_keys_ins)

    recov = run_psql(
        "SELECT has_function_privilege('authenticated', 'public.recover_stuck_operational_jobs()', 'EXECUTE');"
    )[1]
    ok("authenticated cannot EXECUTE recover_stuck_operational_jobs", recov in ("f", "false"), recov)

    # --- Direct table / RPC bypass ---
    code, res, err = run_as(
        "authenticated", u_aa,
        f"INSERT INTO public.platform_admins(user_id,is_active) VALUES ('{u_aa}', true) RETURNING user_id",
    )
    ok("Station ADMIN cannot insert platform_admins", code != 0, err)

    code, res, err = run_as(
        "authenticated", u_ea,
        f"INSERT INTO public.platform_admins(user_id,is_active) VALUES ('{u_ea}', true) RETURNING user_id",
    )
    ok("EMPLOYEE cannot insert platform_admins", code != 0, err)

    code, res, err = run_as(
        "authenticated", u_aa,
        f"UPDATE public.platform_admins SET is_active=false WHERE user_id='{u_pa}' RETURNING user_id",
    )
    ok("Station ADMIN cannot deactivate a Platform Admin row", code != 0, err)

    code, res, err = run_as(
        "authenticated", u_ea,
        f"DELETE FROM public.platform_admins WHERE user_id='{u_pa}' RETURNING user_id",
    )
    ok("EMPLOYEE cannot delete Platform Admin rows", code != 0, err)

    code, res, err = run_as("authenticated", u_ea, "SELECT COUNT(*) FROM public.platform_admins")
    ok("EMPLOYEE RLS/grants hide platform_admins", code != 0 or str(res) in ("0", 0), f"{res} {err}")

    code, res, err = run_as(
        "authenticated", u_ea,
        f"INSERT INTO public.station_memberships (station_id,user_id,role,status) VALUES ('{sta_b}','{u_ea}','ADMIN','ACTIVE') RETURNING id",
    )
    ok("EMPLOYEE cannot INSERT ADMIN membership on Beta", code != 0, err)

    code, res, err = run_as(
        "authenticated", u_aa,
        f"UPDATE public.station_memberships SET role='ADMIN' WHERE id='{mem_ea}' RETURNING role",
    )
    ok("Station ADMIN cannot UPDATE membership to ADMIN (P00105)", code != 0 and "P00105" in err, err)

    code, res, err = run_as(
        "authenticated", u_aa,
        f"UPDATE public.station_memberships SET role='SHIFT_MANAGER' WHERE id='{mem_aa2}' RETURNING role",
    )
    ok("Station ADMIN cannot demote another ADMIN via table (P00105)", code != 0 and "P00105" in err, err)

    code, res, err = run_as(
        "authenticated", u_aa,
        f"DELETE FROM public.station_memberships WHERE id='{mem_aa2}' RETURNING id",
    )
    ok("Station ADMIN cannot DELETE another ADMIN membership (P00105)", code != 0 and "P00105" in err, err)

    # --- RPC role escalation ---
    code, res, err = run_as(
        "authenticated", u_ea,
        f"public.admin_update_membership('{sta_a}'::uuid,'{mem_ea}'::uuid,'ADMIN','ACTIVE')",
    )
    ok("EMPLOYEE cannot self-promote to ADMIN", code != 0, err)

    code, res, err = run_as(
        "authenticated", u_ea,
        f"public.admin_update_membership('{sta_a}'::uuid,'{mem_ea}'::uuid,'SHIFT_MANAGER','ACTIVE')",
    )
    ok("EMPLOYEE cannot self-promote to SHIFT_MANAGER", code != 0, err)

    code, res, err = run_as(
        "authenticated", u_ma,
        f"public.admin_update_membership('{sta_a}'::uuid,'{mem_ea}'::uuid,'ADMIN','ACTIVE')",
    )
    ok("SHIFT_MANAGER cannot grant ADMIN", code != 0, err)

    code, res, err = run_as(
        "authenticated", u_aa,
        f"public.admin_update_membership('{sta_a}'::uuid,'{mem_ea}'::uuid,'ADMIN','ACTIVE')",
    )
    ok("Station ADMIN cannot grant ADMIN via RPC (P00105)", code != 0 and "P00105" in err, err)

    code, res, err = run_as(
        "authenticated", u_aa,
        f"public.admin_update_membership('{sta_a}'::uuid,'{mem_aa2}'::uuid,'EMPLOYEE','ACTIVE')",
    )
    ok("Station ADMIN cannot demote ADMIN to EMPLOYEE (P00105)", code != 0 and "P00105" in err, err)

    code, res, err = run_as(
        "authenticated", u_aa,
        f"public.admin_update_membership('{sta_a}'::uuid,'{mem_aa2}'::uuid,'SHIFT_MANAGER','ACTIVE')",
    )
    ok("Station ADMIN cannot demote ADMIN to SHIFT_MANAGER (P00105)", code != 0 and "P00105" in err, err)

    code, res, err = run_as(
        "authenticated", u_aa,
        f"public.admin_update_membership('{sta_a}'::uuid,'{mem_ea}'::uuid,'SHIFT_MANAGER','ACTIVE')",
    )
    ok("Station ADMIN can promote EMPLOYEE to SHIFT_MANAGER", code == 0 and res.get("role") == "SHIFT_MANAGER", str(res))

    code, res, err = run_as(
        "authenticated", u_aa,
        f"public.admin_update_membership('{sta_a}'::uuid,'{mem_ea}'::uuid,'EMPLOYEE','ACTIVE')",
    )
    ok("Station ADMIN can demote SHIFT_MANAGER to EMPLOYEE", code == 0 and res.get("role") == "EMPLOYEE", str(res))

    # --- Cross-station ---
    code, res, err = run_as(
        "authenticated", u_aa,
        f"public.admin_update_membership('{sta_b}'::uuid,'{mem_ab}'::uuid,'SHIFT_MANAGER','ACTIVE')",
    )
    ok("Admin Alpha cannot mutate Beta memberships", code != 0, err)

    code, res, err = run_as(
        "authenticated", u_aa,
        f"public.platform_assign_station_admin('{sta_b}'::uuid,'{u_ea}'::uuid)",
    )
    ok("Station ADMIN cannot use platform_assign_station_admin", code != 0, err)

    code, res, err = run_as(
        "authenticated", u_multi,
        f"public.admin_update_membership('{sta_b}'::uuid,'{mem_ab}'::uuid,'SHIFT_MANAGER','ACTIVE')",
    )
    ok("multi-station EMPLOYEE cannot manage Beta ADMIN", code != 0, err)

    code, res, err = run_as("authenticated", u_ea, f"SELECT COUNT(*) FROM public.audit_logs WHERE station_id='{sta_b}'")
    ok("Employee Alpha cannot browse Beta audit_logs", code == 0 and str(res) in ("0", 0), str(res))

    # --- PLATFORM_ADMIN approved paths ---
    code, res, err = run_as(
        "authenticated", u_pa,
        f"public.platform_assign_station_admin('{sta_b}'::uuid,'{u_eb}'::uuid)",
    )
    ok("PLATFORM_ADMIN can assign station ADMIN", code == 0 and res.get("success") is True, str(res))

    pa_memberships = run_psql(f"SELECT COUNT(*) FROM public.station_memberships WHERE user_id='{u_pa}'")[1]
    ok("PLATFORM_ADMIN has zero station_memberships", pa_memberships == "0", pa_memberships)

    code, res, err = run_as(
        "authenticated", u_pa,
        f"public.platform_remove_station_admin('{sta_a}'::uuid,'{u_aa2}'::uuid,'Independent audit extra-admin removal')",
    )
    ok("PLATFORM_ADMIN can remove extra ADMIN", code == 0 and (res is None or res.get("success") is True or isinstance(res, dict)), f"{res} {err}")

    code, res, err = run_as(
        "authenticated", u_pa,
        f"public.platform_remove_station_admin('{sta_a}'::uuid,'{u_aa}'::uuid,'Would leave zero admins')",
    )
    ok("last active ADMIN cannot be removed on an active station (P0001)", code != 0 and "P0001" in err, err)

    # --- Inactive PA ---
    code, res, err = run_as("authenticated", u_pa_off, "public.platform_list_stations()")
    ok("inactive PA cannot list stations", code != 0, err)

    code, res, err = run_as(
        "authenticated", u_pa_off,
        f"public.platform_create_station('ShouldFail','FAIL-1')",
    )
    ok("inactive PA cannot create stations", code != 0, err)

    code, res, err = run_as(
        "authenticated", u_pa_off,
        f"public.platform_assign_station_admin('{sta_a}'::uuid,'{u_ea}'::uuid)",
    )
    ok("inactive PA cannot assign station ADMIN", code != 0, err)

    # --- Provisioning / idempotency / keys ---
    code, res, err = run_as(
        "authenticated", u_aa,
        "public.platform_create_station('Hacked','HACK-AA')",
    )
    ok("Station ADMIN cannot create stations", code != 0, err)

    code, res, err = run_as(
        "authenticated", u_ea,
        "public.platform_create_station('Hacked','HACK-EA')",
    )
    ok("EMPLOYEE cannot create stations", code != 0, err)

    code, created, err = run_as(
        "authenticated", u_pa,
        f"public.platform_create_station('Gamma','AUD-G','Asia/Jerusalem','he',0,true,'{u_eb}'::uuid,'idem-audit-gamma-1')",
    )
    ok("PLATFORM_ADMIN can create a station with idempotency key", created is not None and created.get("success") is True, f"{created} {err}")
    gamma_id = created.get("station_id") if isinstance(created, dict) else None

    code, retry, err = run_as(
        "authenticated", u_pa,
        f"public.platform_create_station('GammaRetry','AUD-G2','Asia/Jerusalem','he',0,true,'{u_eb}'::uuid,'idem-audit-gamma-1')",
    )
    ok(
        "same-caller idempotent retry returns original station",
        code == 0 and retry.get("idempotent") is True and retry.get("station_id") == gamma_id,
        str(retry),
    )

    code, res, err = run_as(
        "authenticated", u_pa2,
        f"public.platform_create_station('Stolen','AUD-STOLEN','Asia/Jerusalem','he',0,true,NULL,'idem-audit-gamma-1')",
    )
    ok("different PA cannot reuse another caller's idempotency key (P00107)", code != 0 and "P00107" in err, err)

    code, res, err = run_as(
        "authenticated", u_pa,
        "public.platform_create_station('DupCode','AUD-A')",
    )
    ok("duplicate station code is rejected (P00106)", code != 0 and ("P00106" in err or "already exists" in err.lower()), err)

    code, res, err = run_as(
        "authenticated", u_pa,
        "public.platform_create_station('Whitespace','  aud-w  ')",
    )
    ok("station code is normalized (trim/case) and created", code == 0 and res.get("code") == "AUD-W", str(res))

    code, res, err = run_as(
        "authenticated", u_pa,
        "public.platform_create_station('WhitespaceDup','AUD-W')",
    )
    ok("normalized duplicate code is rejected", code != 0 and "P00106" in err, err)

    code, res, err = run_as("authenticated", u_pa, "SELECT public.normalize_station_code('  ab_1 ')")
    ok("normalize_station_code trims and uppercases", code == 0 and res == "AB_1", str(res))

    # --- Lookup ---
    code, res, err = run_as("authenticated", u_aa, "public.platform_lookup_user_by_email('emp.alpha@yellowshifts.audit')")
    ok("Station ADMIN cannot lookup users by email", code != 0, err)

    code, res, err = run_as("authenticated", u_ea, "public.platform_lookup_user_by_email('admin.alpha@yellowshifts.audit')")
    ok("EMPLOYEE cannot lookup users by email", code != 0, err)

    code, res, err = run_as("authenticated", u_pa, "public.platform_lookup_user_by_email('EMP.ALPHA@yellowshifts.audit')")
    ok(
        "PA lookup is case-insensitive and returns minimum fields",
        code == 0 and res.get("found") is True and res.get("user_id") == u_ea
        and "encrypted_password" not in res and "raw_user_meta_data" not in res,
        str(res),
    )

    code, res, err = run_as("authenticated", u_pa, "public.platform_lookup_user_by_email('missing@yellowshifts.audit')")
    ok("PA lookup of unknown email returns found=false without extra fields", code == 0 and res.get("found") is False, str(res))

    # --- Lifecycle / last-admin / audit ---
    mem_count_before = run_psql(f"SELECT COUNT(*) FROM public.station_memberships WHERE station_id='{sta_b}'")[1]
    code, res, err = run_as(
        "authenticated", u_pa,
        f"public.platform_set_station_active('{sta_b}'::uuid,false,'Independent audit deactivation',false)",
    )
    ok("PLATFORM_ADMIN can deactivate a station with a reason", code == 0, f"{res} {err}")
    mem_count_after = run_psql(f"SELECT COUNT(*) FROM public.station_memberships WHERE station_id='{sta_b}'")[1]
    ok("station deactivation does not delete memberships", mem_count_before == mem_count_after, f"{mem_count_before}->{mem_count_after}")
    still_exists = run_psql(f"SELECT COUNT(*) FROM public.stations WHERE id='{sta_b}'")[1]
    ok("station deactivation does not delete the station row", still_exists == "1", still_exists)

    code, res, err = run_as(
        "authenticated", u_pa,
        f"public.platform_set_station_active('{sta_b}'::uuid,true,'Independent audit reactivation',false)",
    )
    ok("PLATFORM_ADMIN can reactivate a station", code == 0, f"{res} {err}")

    code, res, err = run_as(
        "authenticated", u_aa,
        f"public.platform_set_station_active('{sta_a}'::uuid,false,'not allowed',false)",
    )
    ok("Station ADMIN cannot deactivate via platform_set_station_active", code != 0, err)

    code, res, err = run_as(
        "authenticated", u_pa,
        f"public.platform_query_audit_logs(NULL,NULL,NULL,NULL,NULL,9999,0)",
    )
    ok(
        "platform_query_audit_logs caps limit at 100",
        code == 0 and isinstance(res, dict) and res.get("limit") == 100 and len(res.get("entries") or []) <= 100,
        str(res)[:400] if res else err,
    )

    code, res, err = run_as(
        "authenticated", u_aa,
        f"public.platform_query_audit_logs('{sta_a}'::uuid,NULL,NULL,NULL,NULL,50,0)",
    )
    ok("Station ADMIN cannot use platform_query_audit_logs", code != 0, err)

    code, res, err = run_as("authenticated", u_pa, "public.platform_get_overview()")
    ok("PLATFORM_ADMIN can read platform overview", code == 0 and isinstance(res, dict) and "total_stations" in res, str(res)[:300])

    code, res, err = run_as("authenticated", u_aa, "public.platform_get_overview()")
    ok("Station ADMIN cannot read platform overview", code != 0, err)

    code, res, err = run_as("authenticated", u_pa, "public.platform_list_stations()")
    ok("PLATFORM_ADMIN can list stations", code == 0 and isinstance(res, list) and len(res) >= 2, str(type(res)))

    # --- search_path ---
    for fn in (
        "_active_platform_admin",
        "is_platform_admin",
        "is_station_admin",
        "platform_create_station",
        "require_platform_admin",
        "platform_lookup_user_by_email",
        "enforce_station_admin_role_authority",
    ):
        sp = run_psql(f"""
        SELECT COUNT(*) FROM pg_proc p
        JOIN pg_namespace n ON n.oid=p.pronamespace
        WHERE n.nspname='public' AND p.proname='{fn}'
          AND p.prosecdef = true
          AND p.proconfig @> ARRAY['search_path=public, pg_temp'];
        """)[1]
        ok(f"{fn} SECURITY DEFINER has pinned search_path", sp != "0", sp)

    unpinned = run_psql("""
    SELECT COUNT(*) FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.prosecdef = true
      AND (p.proconfig IS NULL OR NOT p.proconfig @> ARRAY['search_path=public, pg_temp']);
    """)[1]
    ok("no public SECURITY DEFINER function lacks pinned search_path", unpinned == "0", unpinned)

    print(f"\n[+] Phase 10.5 independent audit: {passed}/{total} passed")
    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
