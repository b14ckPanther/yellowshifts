#!/usr/bin/env python3
import os
import sys
import subprocess
import json

DB_NAME = "yellowshifts_nfc_url_tests"
MIGRATIONS_DIR = os.path.join(os.path.dirname(__file__), "../../supabase/migrations")
PSQL_BIN = "psql"
CURRENT_USER = os.environ.get("USER", "postgres")

def run_psql(sql: str, db: str = DB_NAME) -> tuple[int, str, str]:
    cmd = [PSQL_BIN, "-d", db, "-U", CURRENT_USER, "-v", "ON_ERROR_STOP=1", "-A", "-t"]
    res = subprocess.run(cmd, input=sql, capture_output=True, text=True)
    return res.returncode, res.stdout.strip(), res.stderr.strip()

def run_as_role(role: str, uid: str, sql: str, db: str = DB_NAME) -> tuple[int, any, str]:
    clean_sql = sql.strip().rstrip(';')
    if not clean_sql.upper().startswith(("SELECT", "INSERT", "UPDATE", "DELETE")):
        clean_sql = "SELECT " + clean_sql
    wrapped = f"""
    BEGIN;
    SET LOCAL request.jwt.claim.sub = '{uid}';
    SET LOCAL request.jwt.claim.role = '{role}';
    SET LOCAL ROLE {role};
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
        return 0, result_lines[-1], ""

def setup_db():
    print(f"[*] Rebuilding test database: {DB_NAME}...")
    run_psql(f"DROP DATABASE IF EXISTS {DB_NAME};", db="postgres")
    run_psql(f"CREATE DATABASE {DB_NAME};", db="postgres")

    setup_sql = """
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
        with open(path, 'r', encoding='utf-8') as f:
            sql = f.read()
        code, _, err = run_psql(sql)
        if code != 0:
            print(f"[!] Migration {mf} failed:\n{err}")
            sys.exit(1)
    print(f"[+] Applied all {len(migration_files)} canonical migrations.")

def main():
    setup_db()
    passed = 0
    total = 0

    def assert_test(desc: str, condition: bool, details: str = ""):
        nonlocal passed, total
        total += 1
        if condition:
            passed += 1
            print(f"  [PASS] {total:02d}: {desc}")
        else:
            print(f"  [FAIL] {total:02d}: {desc} -> {details}")

    # Seed test users and stations
    u_admin = "11111111-1111-1111-1111-111111111111"
    u_emp_a = "22222222-2222-2222-2222-222222222222"
    u_emp_b = "33333333-3333-3333-3333-333333333333"

    sta_alpha = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
    sta_beta  = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"

    seed_sql = f"""
    INSERT INTO auth.users (id, email) VALUES
        ('{u_admin}', 'admin@alpha.test'),
        ('{u_emp_a}', 'emp.a@alpha.test'),
        ('{u_emp_b}', 'emp.b@beta.test');

    UPDATE public.profiles SET first_name = 'Station', last_name = 'Admin' WHERE id = '{u_admin}';
    UPDATE public.profiles SET first_name = 'Alice', last_name = 'Alpha' WHERE id = '{u_emp_a}';
    UPDATE public.profiles SET first_name = 'Bob', last_name = 'Beta' WHERE id = '{u_emp_b}';

    INSERT INTO public.stations (id, name, code, is_active, timezone, locale) VALUES
        ('{sta_alpha}', 'Station Alpha', 'ST-ALPHA', true, 'Asia/Jerusalem', 'he'),
        ('{sta_beta}', 'Station Beta', 'ST-BETA', true, 'Asia/Jerusalem', 'he');

    INSERT INTO public.station_memberships (station_id, user_id, role, status) VALUES
        ('{sta_alpha}', '{u_admin}', 'ADMIN', 'ACTIVE'),
        ('{sta_alpha}', '{u_emp_a}', 'EMPLOYEE', 'ACTIVE'),
        ('{sta_beta}', '{u_emp_b}', 'EMPLOYEE', 'ACTIVE');
    """
    code, _, err = run_psql(seed_sql)
    if code != 0:
        print(f"[!] Seed failed: {err}")
        sys.exit(1)

    print("\n--- NFC URL ATTENDANCE ARCHITECTURE SECURITY & LOGIC TESTS ---")

    # 1. Provision NFC tag for Station Alpha
    code, res, err = run_as_role("authenticated", u_admin, f"public.provision_station_nfc_tag('{sta_alpha}', 'Entrance Main Tag')")
    assert_test("Admin can provision NFC tag for Station Alpha", code == 0 and res is not None and "token" in res, str(res))
    
    tag_id = res.get("id") if res else None
    tag_token = res.get("token") if res else ""
    nfc_url = res.get("nfc_url") if res else ""

    assert_test("Token is 64 hex characters (high entropy)", len(tag_token) == 64, tag_token)
    assert_test("NFC URL format is /nfc/t/<token>", nfc_url == f"/nfc/t/{tag_token}", nfc_url)

    # 2. Unauthenticated punch is rejected
    code, res, err = run_as_role("anon", "", f"public.nfc_process_attendance('{tag_token}')")
    assert_test("Anonymous punch is rejected", code != 0, err)

    # 3. Unauthorized employee (Bob from Beta) attempts to punch on Alpha tag
    code, res, err = run_as_role("authenticated", u_emp_b, f"public.nfc_process_attendance('{tag_token}')")
    assert_test("Unauthorized employee from Station Beta rejected on Alpha tag", code != 0 and "P0023" in err, err)

    # 4. Authorized employee (Alice) performs CHECK-IN on Station Alpha tag
    code, res, err = run_as_role("authenticated", u_emp_a, f"public.nfc_process_attendance('{tag_token}')")
    assert_test("Alice punches on Alpha tag -> CHECK_IN", code == 0 and res.get("action") == "CHECK_IN" and res.get("status") == "OPEN", str(res) if code == 0 else err)
    att_id = res.get("attendance_id") if res else None

    # 5. Rapid duplicate punch within 10s is blocked
    code, res, err = run_as_role("authenticated", u_emp_a, f"public.nfc_process_attendance('{tag_token}')")
    assert_test("Rapid duplicate punch within 10s is blocked", code != 0 and "P0028" in err, err)

    # Simulate 1 hour passing on attendance record
    run_psql(f"UPDATE public.attendance_records SET check_in_time = now() - INTERVAL '1 hour' WHERE id = '{att_id}';")

    # 6. Alice taps Alpha tag again -> CHECK-OUT
    code, res, err = run_as_role("authenticated", u_emp_a, f"public.nfc_process_attendance('{tag_token}')")
    assert_test("Alice punches again after shift -> CHECK_OUT", code == 0 and res.get("action") == "CHECK_OUT" and res.get("status") == "COMPLETED" and res.get("worked_minutes") >= 60, str(res) if code == 0 else err)

    # 7. Rapid duplicate check-in within 10s is blocked
    code, res, err = run_as_role("authenticated", u_emp_a, f"public.nfc_process_attendance('{tag_token}')")
    assert_test("Rapid duplicate check-in within 10s after checkout is blocked", code != 0 and "P0028" in err, err)

    # 8. Invalid / non-existent token is rejected safely with generic error
    code, res, err = run_as_role("authenticated", u_emp_a, "public.nfc_process_attendance('0000000000000000000000000000000000000000000000000000000000000000')")
    assert_test("Invalid token rejected with generic P0020 error", code != 0 and "P0020" in err, err)

    # 9. Admin regenerates tag token
    code, res, err = run_as_role("authenticated", u_admin, f"public.regenerate_station_nfc_tag('{tag_id}')")
    assert_test("Admin can regenerate tag token", code == 0 and res.get("token") != tag_token, str(res) if code == 0 else err)
    new_token = res.get("token") if res else ""

    # 10. Old token is now rejected
    code, res, err = run_as_role("authenticated", u_emp_a, f"public.nfc_process_attendance('{tag_token}')")
    assert_test("Old invalidated token is rejected", code != 0 and "P0020" in err, err)

    # Advance time to clear cooldown
    run_psql(f"UPDATE public.attendance_records SET updated_at = now() - INTERVAL '1 minute', check_out_time = now() - INTERVAL '1 minute' WHERE id = '{att_id}';")

    # 11. New token works cleanly for Check-In
    code, res, err = run_as_role("authenticated", u_emp_a, f"public.nfc_process_attendance('{new_token}')")
    assert_test("New token successfully performs CHECK_IN", code == 0 and res.get("action") == "CHECK_IN", str(res) if code == 0 else err)

    # 12. Deactivated tag is rejected
    run_psql(f"UPDATE public.station_nfc_tags SET is_active = false WHERE id = '{tag_id}';")
    code, res, err = run_as_role("authenticated", u_emp_a, f"public.nfc_process_attendance('{new_token}')")
    assert_test("Deactivated tag is rejected (P0021)", code != 0 and "P0021" in err, err)

    # 13. Reactivate tag
    run_psql(f"UPDATE public.station_nfc_tags SET is_active = true WHERE id = '{tag_id}';")

    # 14. Inactive station is rejected
    run_psql(f"UPDATE public.stations SET is_active = false WHERE id = '{sta_alpha}';")
    code, res, err = run_as_role("authenticated", u_emp_a, f"public.nfc_process_attendance('{new_token}')")
    assert_test("Inactive station tag is rejected (P0022)", code != 0 and "P0022" in err, err)

    print(f"\n[+] NFC URL security tests: {passed}/{total} passed")
    if passed == total:
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()
