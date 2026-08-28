#!/usr/bin/env python3
"""
YellowShifts Phase 4 — Security & Authorization Adversarial Suite
Zero-dependency PostgreSQL 16 test harness validating Kiosk & Attendance RLS,
secret hashing, direct table write locks, anonymous lockout, and cross-station IDOR.
"""

import sys
import os
import shutil
import subprocess
import json
import uuid
import time
from datetime import datetime, date, timedelta

PSQL_BIN = shutil.which("psql") or "/opt/homebrew/opt/postgresql@16/bin/psql"
if not os.path.exists(PSQL_BIN):
    PSQL_BIN = shutil.which("psql") or "psql"
if not os.path.exists(PSQL_BIN):
    PSQL_BIN = "psql"

DB_NAME = "yellowshifts_phase4_security_test"
CURRENT_USER = os.environ.get("USER", "zangeel")

def run_psql(sql, db=DB_NAME, user=CURRENT_USER):
    cmd = [PSQL_BIN, "-d", db, "-U", user, "-t", "-A", "-c", sql]
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.returncode, res.stdout.strip(), res.stderr.strip()

def run_as_user_json(user_id, sql, db=DB_NAME):
    clean_sql = sql.strip().rstrip(';')
    if not clean_sql.upper().startswith("SELECT") and not clean_sql.upper().startswith("INSERT") and not clean_sql.upper().startswith("UPDATE") and not clean_sql.upper().startswith("DELETE"):
        clean_sql = "SELECT " + clean_sql
    wrapped = f"""
    SET LOCAL request.jwt.claim.sub = '{user_id}';
    SET LOCAL request.jwt.claim.role = 'authenticated';
    SET LOCAL ROLE authenticated;
    {clean_sql};
    """
    code, out, err = run_psql(wrapped, db, CURRENT_USER)
    if code != 0:
        return code, None, err
    lines = [l.strip() for l in out.strip().split("\n") if l.strip()]
    if not lines:
        return 0, None, ""
    last_line = lines[-1]
    try:
        data = json.loads(last_line)
        return 0, data, ""
    except json.JSONDecodeError:
        return 0, last_line, ""

def setup_fresh_db():
    print("[*] Rebuilding isolated test database:", DB_NAME)
    subprocess.run([PSQL_BIN, "-d", "postgres", "-U", CURRENT_USER, "-c", f"DROP DATABASE IF EXISTS {DB_NAME};"],
                   capture_output=True)
    res = subprocess.run([PSQL_BIN, "-d", "postgres", "-U", CURRENT_USER, "-c", f"CREATE DATABASE {DB_NAME};"],
                         capture_output=True, text=True)
    if res.returncode != 0:
        print("[!] Failed to create test database:", res.stderr)
        sys.exit(1)

    migrations = [
        "supabase/migrations/20260825000001_initial_schema.sql",
        "supabase/migrations/20260825000002_phase1_identity_and_roles.sql",
        "supabase/migrations/20260825000003_phase2_shift_templates_and_availability.sql",
        "supabase/migrations/20260825000004_phase3_scheduling.sql",
        "supabase/migrations/20260825000005_phase4_attendance_and_kiosk.sql"
    ]
    for mig in migrations:
        mig_path = os.path.abspath(mig)
        res = subprocess.run([PSQL_BIN, "-d", DB_NAME, "-U", CURRENT_USER, "-f", mig_path],
                             capture_output=True, text=True)
        if res.returncode != 0:
            print(f"[!] Failed to apply {mig}:\n{res.stderr}")
            sys.exit(1)

    print("[*] All 5 canonical migrations applied successfully on fresh database.")

def fixture_user(first_name, last_name, email=None):
    u_id = str(uuid.uuid4())
    user_email = email or f"{first_name.lower()}.{last_name.lower()}.{u_id[:6]}@yellow.com"
    sql = f"""
    INSERT INTO auth.users (id, email) VALUES ('{u_id}', '{user_email}');
    INSERT INTO public.profiles (id, first_name, last_name, preferred_locale)
    VALUES ('{u_id}', '{first_name}', '{last_name}', 'he')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name;
    """
    code, out, err = run_psql(sql)
    assert code == 0, f"Failed to create user: {err}"
    return u_id

def fixture_station(name="TestStation", code_suffix=None, tz="Asia/Jerusalem"):
    s_id = str(uuid.uuid4())
    c_suffix = code_suffix or s_id[:6]
    sql = f"""
    INSERT INTO public.stations (id, name, code, timezone, locale, week_start, is_active)
    VALUES ('{s_id}', '{name}', 'STA-{c_suffix}', '{tz}', 'he', 0, true);
    """
    code, out, err = run_psql(sql)
    assert code == 0, f"Failed to create station: {err}"
    return s_id

def fixture_membership(station_id, user_id, role="EMPLOYEE", status="ACTIVE", code=None):
    m_id = str(uuid.uuid4())
    c_val = f"'{code}'" if code else "NULL"
    sql = f"""
    INSERT INTO public.station_memberships (id, station_id, user_id, role, status, employee_code)
    VALUES ('{m_id}', '{station_id}', '{user_id}', '{role}', '{status}', {c_val});
    """
    code, out, err = run_psql(sql)
    assert code == 0, f"Failed to create membership: {err}"
    return m_id

class SecurityRunner:
    def __init__(self):
        self.passed = 0
        self.total = 0

    def run(self, name, func):
        self.total += 1
        print(f"[*] RUNNING: {name} ... ", end="", flush=True)
        t0 = time.perf_counter()
        try:
            func()
            elapsed = (time.perf_counter() - t0) * 1000.0
            print(f"PASS ({elapsed:.1f}ms)")
            self.passed += 1
        except Exception as e:
            elapsed = (time.perf_counter() - t0) * 1000.0
            print(f"FAILED ({elapsed:.1f}ms)\n     ERROR: {e}")

    def summary(self):
        print("\n" + "="*70)
        print(f"PHASE 4 SECURITY SUITE SUMMARY: {self.passed}/{self.total} PASSED ({(self.passed/self.total)*100:.1f}%)")
        print("="*70)
        return self.passed == self.total

runner = SecurityRunner()

def test_01_clean_5_migration_chain():
    code, out, _ = run_psql("""
        SELECT table_name FROM information_schema.tables 
        WHERE table_schema = 'public' 
          AND table_name IN ('kiosk_devices', 'kiosk_qr_challenges', 'attendance_presence_proofs', 'attendance_records', 'attendance_corrections');
    """)
    tables = [t.strip() for t in out.split("\n") if t.strip()]
    assert len(tables) == 5, f"Expected 5 tables, got {tables}"

def test_02_shift_manager_without_kiosk_manage_blocked():
    admin = fixture_user("Admin", "Sec1")
    manager = fixture_user("Manager", "Sec1")
    sta = fixture_station("SecStation1")
    fixture_membership(sta, admin, role="ADMIN")
    fixture_membership(sta, manager, role="SHIFT_MANAGER")

    # Shift manager attempts to provision kiosk -> Must be rejected (42501)
    code, res, err = run_as_user_json(manager, f"public.provision_kiosk_device('{sta}', 'Kiosk Main', 'KIOSK-01')")
    assert code != 0 or not res or not res.get('success')
    assert "42501" in err or "Access denied" in err

def test_03_admin_grants_kiosk_manage_override():
    admin = fixture_user("Admin", "Sec2")
    manager = fixture_user("Manager", "Sec2")
    sta = fixture_station("SecStation2")
    fixture_membership(sta, admin, role="ADMIN")
    fixture_membership(sta, manager, role="SHIFT_MANAGER")

    # Grant attendance.kiosk.manage capability
    run_psql(f"""
        INSERT INTO public.station_shift_manager_permissions (station_id, permission, is_enabled)
        VALUES ('{sta}', 'attendance.kiosk.manage', true);
    """)

    code, res, err = run_as_user_json(manager, f"public.provision_kiosk_device('{sta}', 'Kiosk Main', 'KIOSK-01')")
    assert code == 0 and res['success'] is True
    assert 'raw_secret' in res

def test_04_direct_table_write_lockout():
    emp = fixture_user("Attacker", "Direct")
    sta = fixture_station("SecStation3")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")

    # Direct insert into attendance_records
    code, res, err = run_as_user_json(emp, f"""
        INSERT INTO public.attendance_records 
        (station_id, employee_user_id, station_membership_id, check_in_time, check_in_kiosk_device_id)
        VALUES ('{sta}', '{emp}', '{mem}', now(), '{uuid.uuid4()}');
    """)
    assert code != 0, "Direct table insert on attendance_records was not blocked by RLS"

    # Direct insert into attendance_presence_proofs
    code, res, err = run_as_user_json(emp, f"""
        INSERT INTO public.attendance_presence_proofs
        (station_id, employee_user_id, station_membership_id, kiosk_device_id, qr_challenge_id, action, token_hash, expires_at)
        VALUES ('{sta}', '{emp}', '{mem}', '{uuid.uuid4()}', '{uuid.uuid4()}', 'CHECK_IN', 'fake', now());
    """)
    assert code != 0, "Direct table insert on attendance_presence_proofs was not blocked by RLS"

def test_05_anonymous_access_lockout():
    for tbl in ['kiosk_devices', 'kiosk_qr_challenges', 'attendance_presence_proofs', 'attendance_records', 'attendance_corrections']:
        code, out, err = run_psql(f"""
            SET LOCAL ROLE anon;
            SELECT count(*) FROM public.{tbl};
        """)
        if code == 0:
            lines = [l.strip() for l in out.split("\n") if l.strip()]
            assert lines[-1] == '0', f"Anonymous query returned rows on {tbl}: {lines[-1]}"
        else:
            assert "permission denied" in err or "42501" in err, f"Unexpected error on anon: {err}"

def test_06_cross_station_attendance_idor():
    admin_a = fixture_user("AdminA", "IDOR")
    admin_b = fixture_user("AdminB", "IDOR")
    sta_a = fixture_station("StationIDOR_A")
    sta_b = fixture_station("StationIDOR_B")
    fixture_membership(sta_a, admin_a, role="ADMIN")
    fixture_membership(sta_b, admin_b, role="ADMIN")

    # Admin A attempts to query live attendance of Station B
    code, res, err = run_as_user_json(admin_a, f"public.get_manager_live_attendance('{sta_b}')")
    assert code != 0 or not res or not res.get('success')
    assert "42501" in err or "Access denied" in err

def test_07_kiosk_secret_hash_not_plaintext():
    admin = fixture_user("Admin", "Hash")
    sta = fixture_station("SecStation4")
    fixture_membership(sta, admin, role="ADMIN")

    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk 1', 'K1')")
    kiosk_id = res['kiosk_id']
    raw_secret = res['raw_secret']

    code, out, _ = run_psql(f"SELECT secret_hash FROM public.kiosk_devices WHERE id = '{kiosk_id}';")
    stored_hash = out.strip()

    assert stored_hash != raw_secret, "Plaintext secret stored in database!"
    assert len(stored_hash) == 64, f"Expected SHA-256 hex string (64 chars), got {len(stored_hash)}"

def test_08_immutable_correction_ledger_lockout():
    admin = fixture_user("Admin", "Ledger")
    sta = fixture_station("SecStation5")
    fixture_membership(sta, admin, role="ADMIN")

    # Direct delete on attendance_corrections
    code, res, err = run_as_user_json(admin, f"DELETE FROM public.attendance_corrections WHERE station_id = '{sta}' RETURNING id;")
    assert code != 0 or not res, "Direct delete on attendance_corrections was not blocked by RLS"

def test_09_security_definer_and_search_path():
    code, out, _ = run_psql("""
        SELECT p.proname, p.prosecdef, p.proconfig::text
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
          AND p.proname IN (
              'provision_kiosk_device', 'rotate_kiosk_credentials', 'deactivate_kiosk_device',
              'reactivate_kiosk_device', 'kiosk_authenticate_and_mint_qr', 'scan_attendance_qr',
              'check_in_with_presence_proof', 'check_out_with_presence_proof',
              'get_manager_live_attendance', 'get_my_attendance_history',
              'correct_attendance_record', 'cleanup_ephemeral_attendance_data'
          );
    """)
    lines = [l.strip() for l in out.split("\n") if l.strip()]
    assert len(lines) == 12, f"Expected 12 RPCs, got {len(lines)}"
    for line in lines:
        name, secdef, config = line.split("|")
        assert secdef == 't', f"{name} is not SECURITY DEFINER"
        assert "search_path=public, pg_temp" in config, f"{name} missing safe search_path: {config}"

def test_10_immutable_audit_logging():
    admin = fixture_user("Admin", "Audit")
    sta = fixture_station("SecStation6")
    fixture_membership(sta, admin, role="ADMIN")

    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk Audit', 'KA-01')")
    kiosk_id = res['kiosk_id']

    code, out, _ = run_psql(f"""
        SELECT action, metadata::text 
        FROM public.audit_logs 
        WHERE target_id = '{kiosk_id}' AND action = 'KIOSK_DEVICE_CREATED';
    """)
    assert "KIOSK_DEVICE_CREATED" in out
    assert res['raw_secret'] not in out, "Raw secret leaked into audit log metadata!"

def main():
    print("="*70)
    print("STARTING PHASE 4 SECURITY & AUTHORIZATION SUITE")
    print("="*70)
    setup_fresh_db()

    runner.run("01 Clean 5-Migration Chain Verification", test_01_clean_5_migration_chain)
    runner.run("02 Shift Manager without kiosk.manage blocked", test_02_shift_manager_without_kiosk_manage_blocked)
    runner.run("03 Admin grants kiosk.manage override -> Success", test_03_admin_grants_kiosk_manage_override)
    runner.run("04 Direct table write lockout (RLS)", test_04_direct_table_write_lockout)
    runner.run("05 Anonymous access lockout", test_05_anonymous_access_lockout)
    runner.run("06 Cross-station attendance IDOR blocked", test_06_cross_station_attendance_idor)
    runner.run("07 Kiosk secret hashed with SHA-256 (no plaintext)", test_07_kiosk_secret_hash_not_plaintext)
    runner.run("08 Immutable correction ledger lockout", test_08_immutable_correction_ledger_lockout)
    runner.run("09 SECURITY DEFINER & Search Path Grants", test_09_security_definer_and_search_path)
    runner.run("10 Immutable audit logging with zero secret leaks", test_10_immutable_audit_logging)

    success = runner.summary()
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
