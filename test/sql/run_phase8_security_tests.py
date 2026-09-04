#!/usr/bin/env python3
"""
YellowShifts Phase 8 — Operations, Exports, Audit Center, Station Admin & Retention Security Suite
Validates 26+ authorization, sanitization, isolation, and safety invariants.
"""

import os
import sys
import json
import subprocess
import shutil

DB_NAME = "yellowshifts_phase8_security_test"
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

def setup_test_db():
    print(f"[*] Rebuilding isolated test database: {DB_NAME}")
    subprocess.run(["dropdb", "--if-exists", "-U", CURRENT_USER, DB_NAME], capture_output=True)
    subprocess.run(["createdb", "-U", CURRENT_USER, DB_NAME], check=True)
    subprocess.run([PSQL_BIN, "-d", DB_NAME, "-U", CURRENT_USER, "-c", "CREATE PUBLICATION supabase_realtime;"], capture_output=True)

    # Gather all 15 migrations in order
    migration_files = sorted([f for f in os.listdir(MIGRATIONS_DIR) if f.endswith(".sql") and f <= "20260825000015_phase8_audit_remediation.sql"])
    assert len(migration_files) >= 14, f"Expected at least 14 migrations, found {len(migration_files)}: {migration_files}"

    for mf in migration_files:
        path = os.path.join(MIGRATIONS_DIR, mf)
        cmd = [PSQL_BIN, "-v", "ON_ERROR_STOP=1", "-d", DB_NAME, "-U", CURRENT_USER, "-f", path]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0:
            print(f"Migration {mf} failed: {res.stderr}")
            sys.exit(1)

    print("[+] All 14 migrations (001-014) applied cleanly.")

def is_denied(code: int, err: str) -> bool:
    return code != 0 and ('42501' in str(err) or 'permission denied' in str(err).lower() or 'access denied' in str(err).lower() or 'denied' in str(err).lower())

def main():
    setup_test_db()
    passed = 0
    total = 0

    def test(desc, success):
        nonlocal passed, total
        total += 1
        print(f"[{total:02d}] {desc} ... {'PASSED' if success else 'FAILED'}")
        if success:
            passed += 1
        else:
            print(f"    --> FAILED TEST: {desc}")

    # Seed Fixtures
    print("\n--- Seeding Multi-Station & Role Fixtures ---")
    seed_sql = """
    INSERT INTO auth.users (id, email) VALUES 
        ('00000000-0000-0000-0000-000000000001', 'admin_a@yellowshifts.local'),
        ('00000000-0000-0000-0000-000000000002', 'manager_a@yellowshifts.local'),
        ('00000000-0000-0000-0000-000000000003', 'employee_a@yellowshifts.local'),
        ('00000000-0000-0000-0000-000000000004', 'admin_b@yellowshifts.local')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.profiles (id, first_name, last_name, phone, preferred_locale) VALUES
        ('00000000-0000-0000-0000-000000000001', 'Admin', 'Alpha', '+972501111111', 'he'),
        ('00000000-0000-0000-0000-000000000002', 'Manager', 'Alpha', '+972502222222', 'he'),
        ('00000000-0000-0000-0000-000000000003', '=SUM(A1:A10)', 'FormulaTarget', '+972503333333', 'he'),
        ('00000000-0000-0000-0000-000000000004', 'Admin', 'Bravo', '+972504444444', 'en')
    ON CONFLICT (id) DO UPDATE SET
        first_name = EXCLUDED.first_name,
        last_name = EXCLUDED.last_name,
        phone = EXCLUDED.phone,
        preferred_locale = EXCLUDED.preferred_locale;

    INSERT INTO public.stations (id, name, code, timezone, locale, is_active) VALUES
        ('10000000-0000-0000-0000-000000000001', 'Station Alpha', 'ST-A', 'Asia/Jerusalem', 'he', true),
        ('20000000-0000-0000-0000-000000000002', 'Station Bravo', 'ST-B', 'Asia/Jerusalem', 'he', true)
    ON CONFLICT (id) DO NOTHING;
        
    INSERT INTO public.station_memberships (id, station_id, user_id, role, status, employee_code)
    VALUES ('40000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'ADMIN', 'ACTIVE', 'ADM-01')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.station_memberships (id, station_id, user_id, role, status, employee_code)
    VALUES ('40000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'SHIFT_MANAGER', 'ACTIVE', 'MGR-01')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.station_memberships (id, station_id, user_id, role, status, employee_code)
    VALUES ('40000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 'EMPLOYEE', 'ACTIVE', 'EMP-01')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.station_memberships (id, station_id, user_id, role, status, employee_code)
    VALUES ('40000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000004', 'ADMIN', 'ACTIVE', 'ADM-02')
    ON CONFLICT (id) DO NOTHING;

    -- Insert Kiosk Device
    INSERT INTO public.kiosk_devices (id, station_id, name, device_identifier, secret_hash, created_by)
    VALUES ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Kiosk Front', 'KIOSK-01', 'hash123', '00000000-0000-0000-0000-000000000001')
    ON CONFLICT (id) DO NOTHING;

    -- Insert attendance record for Employee A
    INSERT INTO public.attendance_records (station_id, employee_user_id, station_membership_id, check_in_time, check_out_time, worked_minutes, status, late_minutes, check_in_kiosk_device_id)
    VALUES ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', '40000000-0000-0000-0000-000000000003',
            NOW() - INTERVAL '4 hours', NOW(), 240, 'COMPLETED', 0, '30000000-0000-0000-0000-000000000001');

    -- Insert audit log with sensitive metadata to test sanitizer
    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'TEST_ACTION', 'user', '00000000-0000-0000-0000-000000000003',
            '{"safe_key": "visible_value", "password": "SUPER_SECRET", "access_token": "JWT_SECRET", "raw_secret": "KIOSK_123"}'::jsonb);
    """
    code, _, err = run_psql(seed_sql)
    if code != 0:
        print(f"Fixture seeding failed: {err}")
        sys.exit(1)

    ADMIN_A = '00000000-0000-0000-0000-000000000001'
    MGR_A = '00000000-0000-0000-0000-000000000002'
    EMP_A = '00000000-0000-0000-0000-000000000003'
    ADMIN_B = '00000000-0000-0000-0000-000000000004'
    STATION_A = '10000000-0000-0000-0000-000000000001'
    STATION_B = '20000000-0000-0000-0000-000000000002'

    print("\n--- Suite 1: Anonymous & Role Denials ---")
    # 01: Anonymous denied export
    code, _, err = run_as_anon_json(f"SELECT public.request_report_export('{STATION_A}', 'MY_ATTENDANCE_HISTORY', 'CSV');")
    test("Anonymous denied export request (42501)", is_denied(code, err))

    # 02: Anonymous denied audit query
    code, _, err = run_as_anon_json(f"SELECT * FROM public.admin_query_audit_logs('{STATION_A}');")
    test("Anonymous denied audit center query (42501)", is_denied(code, err))

    # 03: Anonymous denied system health
    code, _, err = run_as_anon_json(f"SELECT public.get_station_system_health('{STATION_A}');")
    test("Anonymous denied system health telemetry (42501)", is_denied(code, err))

    # 04: Anonymous direct read returns 0 on report_exports
    code, out, err = run_as_anon_json("SELECT COUNT(*) FROM public.report_exports;")
    test("Anonymous direct read denied or returns 0 on report_exports", is_denied(code, err) or (code == 0 and (out == 0 or out == '0')))


    print("\n--- Suite 2: Export Engine & Capability Matrix ---")
    # 05: Employee denied station summary export
    code, _, err = run_as_user_json(EMP_A, f"SELECT public.request_report_export('{STATION_A}', 'STATION_ATTENDANCE_SUMMARY', 'CSV');")
    test("Employee denied station-wide export (42501)", is_denied(code, err))

    # 06: Employee allowed own attendance history export
    code, data, err = run_as_user_json(EMP_A, f"SELECT public.request_report_export('{STATION_A}', 'MY_ATTENDANCE_HISTORY', 'CSV');")
    emp_export_id = data.get('export_id') if isinstance(data, dict) else None
    test("Employee allowed own attendance history export", code == 0 and data and data.get('success') is True)

    # 07: Manager without capability denied station summary export (reports.station.read = false)
    run_psql(f"INSERT INTO public.station_shift_manager_permissions (station_id, permission, is_enabled) VALUES ('{STATION_A}', 'reports.station.read', false), ('{STATION_A}', 'reports.team.read', false) ON CONFLICT (station_id, permission) DO UPDATE SET is_enabled = false;")
    code, _, err = run_as_user_json(MGR_A, f"SELECT public.request_report_export('{STATION_A}', 'STATION_ATTENDANCE_SUMMARY', 'CSV');")
    test("Shift Manager without capability denied station export (42501)", is_denied(code, err))

    # 08: Manager with capability allowed station summary export
    run_psql(f"UPDATE public.station_shift_manager_permissions SET is_enabled = true WHERE station_id = '{STATION_A}' AND permission = 'reports.station.read';")
    code, data, err = run_as_user_json(MGR_A, f"SELECT public.request_report_export('{STATION_A}', 'STATION_ATTENDANCE_SUMMARY', 'CSV');")
    test("Shift Manager with capability allowed station export", code == 0 and data and data.get('success') is True)

    # 09: Admin allowed all station exports
    code, data, err = run_as_user_json(ADMIN_A, f"SELECT public.request_report_export('{STATION_A}', 'EMPLOYEE_DIRECTORY', 'CSV');")
    admin_export_id = data.get('export_id') if isinstance(data, dict) else None
    test("Admin allowed employee directory export", code == 0 and data and data.get('success') is True)

    # 10: Cross-station export IDOR denied
    code, _, err = run_as_user_json(ADMIN_B, f"SELECT public.request_report_export('{STATION_A}', 'STATION_ATTENDANCE_SUMMARY', 'CSV');")
    test("Cross-station export IDOR blocked (42501)", is_denied(code, err))

    # 11: Export metadata privacy (User B cannot read User A's export)
    code, data, _ = run_as_user_json(EMP_A, f"SELECT id FROM public.report_exports WHERE id = '{admin_export_id}';")
    test("Employee cannot read Admin's private export record (RLS)", data is None or data == '' or data == [])

    print("\n--- Suite 3: CSV Sanitization & Formula Injection Defense ---")
    # 12: CSV generator escapes formula injection (=, +, -, @)
    code, data, err = run_as_user_json(ADMIN_A, f"SELECT public.generate_report_export_csv('{admin_export_id}');")
    csv_text = data.get('csv_content', '') if isinstance(data, dict) else ''
    test("CSV formula injection escaped with leading quote ('=SUM)", code == 0 and "''=SUM(A1:A10)" in csv_text or "'=SUM" in csv_text)

    # 13: Direct escape_csv_field unit validation
    code, out, _ = run_psql("SELECT public.escape_csv_field('=1+1');")
    test("escape_csv_field prepends single quote on formula", "'=1+1" in out)

    print("\n--- Suite 4: Audit Center Security & Metadata Sanitization ---")
    # 14: Employee denied Audit Center
    code, _, err = run_as_user_json(EMP_A, f"SELECT * FROM public.admin_query_audit_logs('{STATION_A}');")
    test("Employee denied Audit Center query (42501)", is_denied(code, err))

    # 15: Shift Manager denied Audit Center
    code, _, err = run_as_user_json(MGR_A, f"SELECT * FROM public.admin_query_audit_logs('{STATION_A}');")
    test("Shift Manager denied Audit Center query (42501)", is_denied(code, err))

    # 16: Admin allowed Audit Center
    code, data, err = run_as_user_json(ADMIN_A, f"SELECT json_agg(t) FROM (SELECT * FROM public.admin_query_audit_logs('{STATION_A}')) t;")
    test("Admin allowed Audit Center query", code == 0 and data is not None)

    # 17: Cross-station Audit Center query denied
    code, _, err = run_as_user_json(ADMIN_B, f"SELECT * FROM public.admin_query_audit_logs('{STATION_A}');")
    test("Cross-station Audit Center query denied (42501)", is_denied(code, err))

    # 18: Audit metadata sanitization (zero password/token/secret leakage)
    code, data, err = run_as_user_json(ADMIN_A, f"SELECT json_agg(t) FROM (SELECT metadata FROM public.admin_query_audit_logs('{STATION_A}') WHERE action = 'TEST_ACTION') t;")
    has_safe_key = False
    has_leaked_secret = True
    is_redacted = False
    if isinstance(data, list) and len(data) > 0:
        meta = data[0].get('metadata', {})
        has_safe_key = meta.get('safe_key') == 'visible_value'
        has_leaked_secret = any(meta.get(k) in ['SUPER_SECRET', 'JWT_SECRET', 'KIOSK_123'] for k in ['password', 'access_token', 'raw_secret'])
        is_redacted = all(meta.get(k) == '[REDACTED]' for k in ['password', 'access_token', 'raw_secret'])
    test("Audit Center metadata sanitizes passwords & tokens", has_safe_key and not has_leaked_secret and is_redacted)



    # 19: Direct mutation on audit_logs revoked
    code, data, err = run_as_user_json(ADMIN_A, f"DELETE FROM public.audit_logs WHERE station_id = '{STATION_A}';")
    test("Direct DELETE on audit_logs denied to Admin (Revoke/RLS)", is_denied(code, err))

    print("\n--- Suite 5: Station Administration Expansion ---")
    # 20: Employee denied admin_update_station
    code, _, err = run_as_user_json(EMP_A, f"SELECT public.admin_update_station('{STATION_A}', 'New Name', 'ST-A', 'Asia/Jerusalem', 'he', 0, true, 5, 15);")
    test("Employee denied station update (42501)", is_denied(code, err))

    # 21: Shift Manager denied admin_update_station
    code, _, err = run_as_user_json(MGR_A, f"SELECT public.admin_update_station('{STATION_A}', 'New Name', 'ST-A', 'Asia/Jerusalem', 'he', 0, true, 5, 15);")
    test("Shift Manager denied station update (42501)", is_denied(code, err))

    # 22: Invalid IANA timezone rejected
    code, _, err = run_as_user_json(ADMIN_A, f"SELECT public.admin_update_station('{STATION_A}', 'Station Alpha', 'ST-A', 'Mars/Olympus_Mons', 'he', 0, true, 5, 15);")
    test("Invalid IANA timezone rejected (22000)", code != 0 and '22000' in str(err))

    # 23: Valid IANA timezone accepted
    code, data, err = run_as_user_json(ADMIN_A, f"SELECT public.admin_update_station('{STATION_A}', 'Station Alpha Updated', 'ST-A', 'America/New_York', 'he', 0, true, 10, 20);")
    test("Valid IANA timezone & grace windows accepted", code == 0 and data and data.get('success') is True)

    # 24: Station deactivation safety (active attendance session blocks unsafe deactivation)
    run_psql(f"INSERT INTO public.attendance_records (station_id, employee_user_id, station_membership_id, check_in_time, status, check_in_kiosk_device_id) VALUES ('{STATION_A}', '{EMP_A}', '40000000-0000-0000-0000-000000000003', NOW(), 'OPEN', '30000000-0000-0000-0000-000000000001');")
    code, _, err = run_as_user_json(ADMIN_A, f"SELECT public.admin_update_station('{STATION_A}', 'Station Alpha Updated', 'ST-A', 'America/New_York', 'he', 0, false, 10, 20, false);")
    test("Unsafe station deactivation blocked with active sessions (P0082)", code != 0 and 'P0082' in str(err))

    print("\n--- Suite 6: Data Lifecycle & Retention Invariants ---")
    # 25: Expired export blocked
    run_psql(f"UPDATE public.report_exports SET expires_at = NOW() - INTERVAL '1 minute' WHERE id = '{emp_export_id}';")
    code, _, err = run_as_user_json(EMP_A, f"SELECT public.generate_report_export_csv('{emp_export_id}');")
    test("Expired export returns P0081", code != 0 and 'P0081' in str(err))

    # 26: Cleanup engine marks expired exports without deleting attendance/audit records
    code, data, err = run_psql("SELECT public.cleanup_expired_data();")
    code_att, out_att, _ = run_psql(f"SELECT COUNT(*) FROM public.attendance_records WHERE station_id = '{STATION_A}';")
    test("cleanup_expired_data preserves 100% of historical attendance records", code == 0 and int(out_att) >= 2)

    print("\n" + "=" * 75)
    print(f"PHASE 8 SECURITY & AUTHORIZATION RESULTS: {passed}/{total} PASSED ({passed/total*100:.1f}%)")
    print("=" * 75)
    if passed != total:
        sys.exit(1)

if __name__ == "__main__":
    main()
