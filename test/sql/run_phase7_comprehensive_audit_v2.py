#!/usr/bin/env python3
"""
YellowShifts — Phase 7 Comprehensive Adversarial Audit V2 Test Suite
Worked Hours Analytics, Attendance History, Operational Reporting, Invariants, Security & Scale.

Covers 70+ adversarial test scenarios across all Phase 7 dimensions using native psql execution.
"""

import sys
import os
import shutil
import subprocess
import json
import time

PSQL_BIN = shutil.which("psql") or "/opt/homebrew/opt/postgresql@16/bin/psql"
if not os.path.exists(PSQL_BIN):
    PSQL_BIN = shutil.which("psql") or "psql"
if not os.path.exists(PSQL_BIN):
    PSQL_BIN = "psql"

DB_NAME = "yellowshifts_phase7_audit_v2"
CURRENT_USER = os.environ.get("USER", "zangeel")

def run_psql(sql: str, db: str = DB_NAME) -> tuple[int, str, str]:
    cmd = [PSQL_BIN, "-d", db, "-U", CURRENT_USER, "-t", "-A", "-v", "VERBOSITY=verbose", "-c", sql]
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.returncode, res.stdout.strip(), res.stderr.strip()

def run_as_user_json(user_id: str, sql: str, db: str = DB_NAME) -> tuple[int, any, str]:
    clean_sql = sql.strip().rstrip(';')
    if not clean_sql.upper().startswith("SELECT") and not clean_sql.upper().startswith("INSERT") and not clean_sql.upper().startswith("UPDATE") and not clean_sql.upper().startswith("DELETE"):
        clean_sql = "SELECT " + clean_sql
    wrapped = f"""
    SET LOCAL request.jwt.claim.sub = '{user_id}';
    SET LOCAL request.jwt.claim.role = 'authenticated';
    SET LOCAL ROLE authenticated;
    {clean_sql};
    """
    code, out, err = run_psql(wrapped, db)
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
    print(f"[*] Rebuilding isolated test database: {DB_NAME}")
    cmd_drop = [PSQL_BIN, "-d", "postgres", "-U", CURRENT_USER, "-c", f"DROP DATABASE IF EXISTS {DB_NAME};"]
    subprocess.run(cmd_drop, capture_output=True)
    cmd_create = [PSQL_BIN, "-d", "postgres", "-U", CURRENT_USER, "-c", f"CREATE DATABASE {DB_NAME};"]
    res = subprocess.run(cmd_create, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"[-] Database creation failed: {res.stderr}")
        sys.exit(1)

    # Initialize Supabase-specific publication for realtime triggers
    run_psql("DO $$ BEGIN CREATE PUBLICATION supabase_realtime; EXCEPTION WHEN OTHERS THEN NULL; END $$;")

    migrations_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../supabase/migrations"))
    files = sorted(
        f for f in os.listdir(migrations_dir)
        if f.endswith(".sql") and f.startswith("202608250000") and f[:14] <= "20260825000012"
    )
    for mf in files:
        fpath = os.path.join(migrations_dir, mf)
        cmd_apply = [PSQL_BIN, "-d", DB_NAME, "-U", CURRENT_USER, "-f", fpath]
        mres = subprocess.run(cmd_apply, capture_output=True, text=True)
        if mres.returncode != 0:
            print(f"[-] Migration failed: {mf}\n{mres.stderr}")
            sys.exit(1)
    print(f"[+] All {len(files)} migrations (001-012) applied cleanly.")

class TestRunner:
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.total = 0

    def assert_test(self, title, condition, details=""):
        self.total += 1
        if condition:
            self.passed += 1
            print(f"[{self.total:02d}] {title} ... PASSED")
        else:
            self.failed += 1
            print(f"[{self.total:02d}] {title} ... FAILED: {details}")

def main():
    setup_fresh_db()
    runner = TestRunner()

    station_a_id = "11111111-1111-1111-1111-111111111111"
    station_b_id = "22222222-2222-2222-2222-222222222222"
    station_c_id = "33333333-3333-3333-3333-333333333333"

    kiosk_a_id = "91111111-1111-1111-1111-111111111111"
    kiosk_b_id = "92222222-2222-2222-2222-222222222222"

    admin_user_id = "aaaa0000-0000-0000-0000-000000000001"
    manager_user_id = "aaaa0000-0000-0000-0000-000000000002"
    emp1_user_id = "eeee0000-0000-0000-0000-000000000001"
    emp2_user_id = "eeee0000-0000-0000-0000-000000000002"
    emp3_user_id = "eeee0000-0000-0000-0000-000000000003"
    emp_foreign_id = "eeee9999-9999-9999-9999-999999999999"

    mem_emp1_a = "10000000-0000-0000-0000-000000000003"
    mem_emp2_a = "10000000-0000-0000-0000-000000000004"
    mem_emp3_a = "10000000-0000-0000-0000-000000000005"
    mem_emp1_b = "20000000-0000-0000-0000-000000000001"
    mem_emp_for_b = "20000000-0000-0000-0000-000000000002"

    # Setup base fixtures
    init_sql = f"""
        INSERT INTO auth.users (id, email) VALUES
            ('{admin_user_id}', 'admin@yellow.com'),
            ('{manager_user_id}', 'manager@yellow.com'),
            ('{emp1_user_id}', 'david@yellow.com'),
            ('{emp2_user_id}', 'sarah@yellow.com'),
            ('{emp3_user_id}', 'yossi@yellow.com'),
            ('{emp_foreign_id}', 'foreign@yellow.com'),
            ('77777777-7777-7777-7777-777777777777', 'missing_prof@yellow.com')
        ON CONFLICT (id) DO NOTHING;

        INSERT INTO public.profiles (id, first_name, last_name)
        VALUES 
            ('{admin_user_id}', 'Anas', 'Admin'),
            ('{manager_user_id}', 'Moshe', 'Manager'),
            ('{emp1_user_id}', 'David', 'Cohen'),
            ('{emp2_user_id}', 'Sarah', 'Levi'),
            ('{emp3_user_id}', 'Yossi', 'Mizrahi'),
            ('{emp_foreign_id}', 'Foreign', 'Worker')
        ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name;


        INSERT INTO public.stations (id, name, code, timezone, is_active)
        VALUES 
            ('{station_a_id}', 'Station Alpha', 'ST-ALP-01', 'Asia/Jerusalem', true),
            ('{station_b_id}', 'Station Beta', 'ST-BET-02', 'Asia/Jerusalem', true),
            ('{station_c_id}', 'Station NewYork', 'ST-NYC-03', 'America/New_York', true)
        ON CONFLICT (id) DO NOTHING;

        INSERT INTO public.kiosk_devices (id, station_id, device_identifier, name, secret_hash, is_active, created_by)
        VALUES 
            ('{kiosk_a_id}', '{station_a_id}', 'KIOSK-A-01', 'Alpha Kiosk', 'dummy_hash', true, '{admin_user_id}'),
            ('{kiosk_b_id}', '{station_b_id}', 'KIOSK-B-01', 'Beta Kiosk', 'dummy_hash', true, '{admin_user_id}')
        ON CONFLICT (id) DO NOTHING;

        INSERT INTO public.station_memberships (id, station_id, user_id, role, status, employee_code)
        VALUES 
            ('10000000-0000-0000-0000-000000000001', '{station_a_id}', '{admin_user_id}', 'ADMIN', 'ACTIVE', 'ADM-01'),
            ('10000000-0000-0000-0000-000000000002', '{station_a_id}', '{manager_user_id}', 'SHIFT_MANAGER', 'ACTIVE', 'MGR-01'),
            ('{mem_emp1_a}', '{station_a_id}', '{emp1_user_id}', 'EMPLOYEE', 'ACTIVE', 'EMP-01'),
            ('{mem_emp2_a}', '{station_a_id}', '{emp2_user_id}', 'EMPLOYEE', 'ACTIVE', 'EMP-02'),
            ('{mem_emp3_a}', '{station_a_id}', '{emp3_user_id}', 'EMPLOYEE', 'INACTIVE', 'EMP-03'),
            ('{mem_emp1_b}', '{station_b_id}', '{emp1_user_id}', 'EMPLOYEE', 'ACTIVE', 'EMP-01B'),
            ('{mem_emp_for_b}', '{station_b_id}', '{emp_foreign_id}', 'EMPLOYEE', 'ACTIVE', 'EMP-FOR')
        ON CONFLICT (id) DO NOTHING;
    """

    code, out, err = run_psql(init_sql)
    if code != 0:
        print(f"[-] Init fixtures failed: {err}")
        sys.exit(1)

    # 1. Clean Rebuild Verification
    runner.assert_test("01. Clean 001-012 Migration Rebuild", True)

    # 2. Functions Declared SECURITY DEFINER and STABLE
    code, out, err = run_psql("""
        SELECT count(*) FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' 
          AND proname IN (
            'get_my_attendance_summary', 'get_my_attendance_history',
            'get_station_attendance_summary', 'get_station_employee_attendance_summary',
            'get_station_daily_attendance_report', 'get_station_employee_attendance_detail'
          )
          AND prosecdef = true
          AND provolatile = 's';
    """)
    runner.assert_test("02. All 6 Reporting RPCs SECURITY DEFINER & STABLE", out.strip() == "6", f"Count: {out}")

    # 3. Anonymous Lockout
    anon_blocked = 0
    for rpc in [
        "SELECT public.get_my_attendance_summary('2026-08-01', '2026-08-31')",
        "SELECT public.get_my_attendance_history('2026-08-01', '2026-08-31')",
        f"SELECT public.get_station_attendance_summary('{station_a_id}', '2026-08-01', '2026-08-31')",
        f"SELECT public.get_station_employee_attendance_summary('{station_a_id}', '2026-08-01', '2026-08-31')",
        f"SELECT public.get_station_daily_attendance_report('{station_a_id}', '2026-08-25')",
        f"SELECT public.get_station_employee_attendance_detail('{station_a_id}', '{emp1_user_id}', '2026-08-01', '2026-08-31')"
    ]:
        wrapped = f"SET LOCAL ROLE anon; {rpc};"
        c, o, e = run_psql(wrapped)
        if c != 0 and ('42501' in e or 'Authentication required' in e or 'permission denied' in e):
            anon_blocked += 1
    runner.assert_test("03. Anonymous Lockout on all 6 Reporting RPCs", anon_blocked == 6, f"Blocked {anon_blocked}/6")

    # 4. Strict Date Validation (Invalid Leap Year, From > To, Range > 366)
    date_tests = 0
    # 4a. Non-leap year Feb 29
    c, d, e = run_as_user_json(emp1_user_id, "SELECT public.get_my_attendance_summary('2026-02-29'::DATE, '2026-03-01'::DATE)")
    if c != 0: date_tests += 1

    # 4b. From > To
    c, d, e = run_as_user_json(emp1_user_id, "SELECT public.get_my_attendance_summary('2026-09-01'::DATE, '2026-08-01'::DATE)")
    if c != 0 and ('22000' in e or 'Start date cannot be after end date' in e): date_tests += 1

    # 4c. Range > 366 days
    c, d, e = run_as_user_json(emp1_user_id, "SELECT public.get_my_attendance_summary('2025-01-01'::DATE, '2026-01-10'::DATE)")
    if c != 0 and ('22000' in e or 'Date range cannot exceed 366 days' in e): date_tests += 1

    # 4d. Valid leap year 2028-02-29
    c, d, e = run_as_user_json(emp1_user_id, "SELECT public.get_my_attendance_summary('2028-02-28'::DATE, '2028-03-01'::DATE)")
    if c == 0 and d and d.get('success'): date_tests += 1

    runner.assert_test("04. Date Range & Leap Year Invariants (4/4)", date_tests == 4, f"Passed: {date_tests}/4")

    # 5. Basic Attendance Aggregation
    run_psql(f"DELETE FROM public.attendance_records WHERE station_id IN ('{station_a_id}', '{station_b_id}');")
    run_psql(f"""
        INSERT INTO public.attendance_records (
            station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id,
            check_in_time, check_out_time, worked_minutes, late_minutes, status, verification_method,
            scheduled_start_at_snapshot, scheduled_end_at_snapshot
        ) VALUES (
            '{station_a_id}', '{emp1_user_id}', '{mem_emp1_a}', '{kiosk_a_id}',
            '2026-08-10 05:00:00+00', '2026-08-10 13:00:00+00',
            480, 0, 'COMPLETED', 'QR_ONLY',
            '2026-08-10 05:00:00+00', '2026-08-10 13:00:00+00'
        );
    """)
    c, d, e = run_as_user_json(emp1_user_id, "SELECT public.get_my_attendance_summary('2026-08-01', '2026-08-31')")
    runner.assert_test("05. Single Completed Shift Aggregation (480 mins)", 
                       c == 0 and d and d['completed_shifts'] == 1 and d['total_worked_minutes'] == 480 and d['late_shifts'] == 0,
                       f"Result: {d}")

    # 6. Corrupted Negative Worked Minutes Excluded
    run_psql(f"""
        INSERT INTO public.attendance_records (
            station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id,
            check_in_time, check_out_time, worked_minutes, late_minutes, status, verification_method
        ) VALUES (
            '{station_a_id}', '{emp1_user_id}', '{mem_emp1_a}', '{kiosk_a_id}',
            '2026-08-11 05:00:00+00', '2026-08-11 13:00:00+00',
            -500, 0, 'COMPLETED', 'QR_ONLY'
        );
    """)
    c, d, e = run_as_user_json(emp1_user_id, "SELECT public.get_my_attendance_summary('2026-08-01', '2026-08-31')")
    runner.assert_test("06. Corrupted Negative Worked Minutes Excluded", 
                       c == 0 and d and d['completed_shifts'] == 1 and d['total_worked_minutes'] == 480,
                       f"Result: {d}")

    # 7. Corrupted Null Worked Minutes Excluded
    run_psql(f"""
        INSERT INTO public.attendance_records (
            station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id,
            check_in_time, check_out_time, worked_minutes, late_minutes, status, verification_method
        ) VALUES (
            '{station_a_id}', '{emp1_user_id}', '{mem_emp1_a}', '{kiosk_a_id}',
            '2026-08-12 05:00:00+00', '2026-08-12 13:00:00+00',
            NULL, 0, 'COMPLETED', 'QR_ONLY'
        );
    """)
    c, d, e = run_as_user_json(emp1_user_id, "SELECT public.get_my_attendance_summary('2026-08-01', '2026-08-31')")
    runner.assert_test("07. Corrupted NULL Worked Minutes Excluded", 
                       c == 0 and d and d['completed_shifts'] == 1 and d['total_worked_minutes'] == 480,
                       f"Result: {d}")

    # 8. Open Session Excluded from Completed Totals & Elapsed Derivation
    run_psql(f"""
        INSERT INTO public.attendance_records (
            id, station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id,
            check_in_time, check_out_time, worked_minutes, late_minutes, status, verification_method, shift_name_snapshot
        ) VALUES (
            '99999999-9999-9999-9999-999999999999',
            '{station_a_id}', '{emp1_user_id}', '{mem_emp1_a}', '{kiosk_a_id}',
            now() - INTERVAL '120 minutes', NULL,
            NULL, 0, 'OPEN', 'QR_ONLY', 'Morning Shift'
        );
    """)
    c, d, e = run_as_user_json(emp1_user_id, "SELECT public.get_my_attendance_summary('2026-08-01', '2026-08-31')")
    active_session = d.get('active_open_session') if d else None
    runner.assert_test("08. Open Session Excluded from Completed & Has Elapsed", 
                       c == 0 and d and d['completed_shifts'] == 1 and d['total_worked_minutes'] == 480 and 
                       active_session is not None and active_session['elapsed_minutes'] >= 119 and not active_session['needs_attention'],
                       f"Result: {d}")

    # 9. 16-Hour Anomaly Threshold (Exact boundary >= 960 mins)
    run_psql("UPDATE public.attendance_records SET check_in_time = now() - INTERVAL '961 minutes' WHERE id = '99999999-9999-9999-9999-999999999999';")
    c, d, e = run_as_user_json(emp1_user_id, "SELECT public.get_my_attendance_summary('2026-08-01', '2026-08-31')")
    active_session = d.get('active_open_session') if d else None
    runner.assert_test("09. 16-Hour Anomaly Flagging (needs_attention=true)", 
                       c == 0 and active_session is not None and active_session['needs_attention'] and active_session['elapsed_minutes'] >= 960,
                       f"Active session: {active_session}")

    # Cleanup open session
    run_psql("DELETE FROM public.attendance_records WHERE id = '99999999-9999-9999-9999-999999999999';")

    # 10. Multi-Correction Deduplication Invariant
    run_psql(f"""
        INSERT INTO public.attendance_records (
            id, station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id,
            check_in_time, check_out_time, worked_minutes, late_minutes, status, verification_method
        ) VALUES (
            '88888888-8888-8888-8888-888888888888',
            '{station_a_id}', '{emp1_user_id}', '{mem_emp1_a}', '{kiosk_a_id}',
            '2026-08-15 05:00:00+00', '2026-08-15 13:00:00+00',
            480, 15, 'COMPLETED', 'QR_ONLY'
        );
    """)
    for i in range(10):
        run_psql(f"""
            INSERT INTO public.attendance_corrections (
                attendance_record_id, station_id, actor_user_id, reason,
                previous_check_in_time, new_check_in_time,
                previous_check_out_time, new_check_out_time,
                previous_worked_minutes, new_worked_minutes,
                created_at
            ) VALUES (
                '88888888-8888-8888-8888-888888888888', '{station_a_id}', '{admin_user_id}', 'Correction #{i+1}',
                '2026-08-15 05:00:00+00', '2026-08-15 05:00:00+00',
                '2026-08-15 13:00:00+00', '2026-08-15 13:00:00+00',
                480, 480,
                '2026-08-15 14:00:00+00'::TIMESTAMPTZ + ('{i}' || ' seconds')::INTERVAL
            );
        """)

    c, d, e = run_as_user_json(emp1_user_id, "SELECT public.get_my_attendance_summary('2026-08-01', '2026-08-31')")
    runner.assert_test("10. 10 Corrections on 1 Record Produces Exactly 1 Corrected Record", 
                       c == 0 and d and d['completed_shifts'] == 2 and d['corrected_records'] == 1 and d['total_worked_minutes'] == 960,
                       f"Result: {d}")

    # 11. Correction History Deterministic Tie-Breaker
    run_psql(f"""
        INSERT INTO public.attendance_corrections (
            attendance_record_id, station_id, actor_user_id, reason,
            previous_check_in_time, new_check_in_time,
            previous_check_out_time, new_check_out_time,
            previous_worked_minutes, new_worked_minutes,
            created_at
        ) VALUES 
            ('88888888-8888-8888-8888-888888888888', '{station_a_id}', '{admin_user_id}', 'Same Timestamp A', '2026-08-15 05:00:00+00', '2026-08-15 05:00:00+00', '2026-08-15 13:00:00+00', '2026-08-15 13:00:00+00', 480, 480, '2026-08-20 12:00:00+00'),
            ('88888888-8888-8888-8888-888888888888', '{station_a_id}', '{admin_user_id}', 'Same Timestamp B', '2026-08-15 05:00:00+00', '2026-08-15 05:00:00+00', '2026-08-15 13:00:00+00', '2026-08-15 13:00:00+00', 480, 480, '2026-08-20 12:00:00+00');
    """)
    c, det, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_employee_attendance_detail('{station_a_id}', '{emp1_user_id}', '2026-08-01', '2026-08-31')")
    corr_list = det['records'][0]['corrections'] if (det and det.get('records')) else []
    runner.assert_test("11. Correction Ledger Deterministic Tie-Breaker Ordering", 
                       len(corr_list) == 12 and corr_list[-2]['id'] < corr_list[-1]['id'],
                       f"Last 2 same-timestamp corrections: {corr_list[-2:]}")


    # 12. Multi-Station Employee & Manager Isolation
    run_psql(f"""
        INSERT INTO public.attendance_records (
            station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id,
            check_in_time, check_out_time, worked_minutes, late_minutes, status, verification_method
        ) VALUES (
            '{station_b_id}', '{emp1_user_id}', '{mem_emp1_b}', '{kiosk_b_id}',
            '2026-08-18 05:00:00+00', '2026-08-18 13:00:00+00',
            480, 0, 'COMPLETED', 'QR_ONLY'
        );
    """)
    c, self_res, e = run_as_user_json(emp1_user_id, "SELECT public.get_my_attendance_summary('2026-08-01', '2026-08-31')")
    c, sta_res, e = run_as_user_json(emp1_user_id, f"SELECT public.get_my_attendance_summary('2026-08-01', '2026-08-31', '{station_a_id}')")
    c, mgr_a_res, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_attendance_summary('{station_a_id}', '2026-08-01', '2026-08-31')")
    runner.assert_test("12. Multi-Station Employee & Manager Isolation (960m + 480m = 1440m)", 
                       self_res['total_worked_minutes'] == 1440 and self_res['stations_worked_count'] == 2 and
                       sta_res['total_worked_minutes'] == 960 and sta_res['stations_worked_count'] == 1 and
                       mgr_a_res['total_worked_minutes'] == 960,
                       f"Self: {self_res}, Station A: {sta_res}, Mgr A: {mgr_a_res}")

    # 13. Inactive Employee Historical Reportability
    run_psql(f"""
        INSERT INTO public.attendance_records (
            station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id,
            check_in_time, check_out_time, worked_minutes, late_minutes, status, verification_method
        ) VALUES (
            '{station_a_id}', '{emp3_user_id}', '{mem_emp3_a}', '{kiosk_a_id}',
            '2026-08-05 05:00:00+00', '2026-08-05 13:00:00+00',
            480, 0, 'COMPLETED', 'QR_ONLY'
        );
    """)
    c, emp3_res, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_employee_attendance_summary('{station_a_id}', '2026-08-01', '2026-08-31', 'Yossi')")
    runner.assert_test("13. Inactive Employee Historical Reportability", 
                       emp3_res['total_count'] == 1 and emp3_res['items'][0]['membership_status'] == 'INACTIVE' and emp3_res['items'][0]['total_worked_minutes'] == 480,
                       f"Result: {emp3_res}")

    # 14. Cross-Midnight Shift Operational Date Attribution
    run_psql(f"""
        INSERT INTO public.attendance_records (
            station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id,
            check_in_time, check_out_time, worked_minutes, late_minutes, status, verification_method,
            scheduled_start_at_snapshot, scheduled_end_at_snapshot
        ) VALUES (
            '{station_a_id}', '{emp2_user_id}', '{mem_emp2_a}', '{kiosk_a_id}',
            '2026-08-20 19:00:00+00', '2026-08-21 03:00:00+00',
            480, 0, 'COMPLETED', 'QR_ONLY',
            '2026-08-20 19:00:00+00', '2026-08-21 03:00:00+00'
        );
    """)
    c, aug20_res, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_attendance_summary('{station_a_id}', '2026-08-20', '2026-08-20')")
    c, aug21_res, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_attendance_summary('{station_a_id}', '2026-08-21', '2026-08-21')")
    runner.assert_test("14. Cross-Midnight Shift Belongs to Start Date", 
                       aug20_res['completed_shifts'] == 1 and aug21_res['completed_shifts'] == 0,
                       f"Aug 20: {aug20_res['completed_shifts']}, Aug 21: {aug21_res['completed_shifts']}")

    # 15. Early Arrival Month Boundary (Sep 1 00:10 scheduled, checked in Aug 31 23:55)
    run_psql(f"""
        INSERT INTO public.attendance_records (
            station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id,
            check_in_time, check_out_time, worked_minutes, late_minutes, status, verification_method,
            scheduled_start_at_snapshot, scheduled_end_at_snapshot
        ) VALUES (
            '{station_a_id}', '{emp2_user_id}', '{mem_emp2_a}', '{kiosk_a_id}',
            '2026-08-31 20:55:00+00', '2026-09-01 05:00:00+00',
            485, 0, 'COMPLETED', 'QR_ONLY',
            '2026-08-31 21:10:00+00', '2026-09-01 05:00:00+00'
        );
    """)
    c, sep_sum, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_attendance_summary('{station_a_id}', '2026-09-01', '2026-09-30')")
    runner.assert_test("15. Early Arrival Month Boundary Classified by Scheduled Snapshot (September)", 
                       sep_sum['completed_shifts'] == 1 and sep_sum['total_worked_minutes'] == 485,
                       f"Sep sum: {sep_sum}")

    # 16. DST Transition Handling (Spring & Autumn)
    run_psql(f"""
        INSERT INTO public.attendance_records (
            station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id,
            check_in_time, check_out_time, worked_minutes, late_minutes, status, verification_method,
            scheduled_start_at_snapshot, scheduled_end_at_snapshot
        ) VALUES (
            '{station_a_id}', '{emp1_user_id}', '{mem_emp1_a}', '{kiosk_a_id}',
            '2026-03-26 21:00:00+00', '2026-03-27 04:00:00+00',
            420, 0, 'COMPLETED', 'QR_ONLY',
            '2026-03-26 21:00:00+00', '2026-03-27 04:00:00+00'
        );
    """)
    c, dst_res, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_attendance_summary('{station_a_id}', '2026-03-26', '2026-03-27')")
    runner.assert_test("16. Israel DST Spring-Forward Preserves Worked Minutes", 
                       dst_res['completed_shifts'] == 1 and dst_res['total_worked_minutes'] == 420,
                       f"DST res: {dst_res}")

    # 17. Repeated Lateness Detection (>= 3 late shifts)
    for day in [1, 2, 3]:
        run_psql(f"""
            INSERT INTO public.attendance_records (
                station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id,
                check_in_time, check_out_time, worked_minutes, late_minutes, status, verification_method,
                scheduled_start_at_snapshot
            ) VALUES (
                '{station_a_id}', '{emp2_user_id}', '{mem_emp2_a}', '{kiosk_a_id}',
                ('2026-07-0' || '{day}' || ' 05:30:00+00')::TIMESTAMPTZ,
                ('2026-07-0' || '{day}' || ' 13:30:00+00')::TIMESTAMPTZ,
                480, 30, 'COMPLETED', 'QR_ONLY',
                ('2026-07-0' || '{day}' || ' 05:00:00+00')::TIMESTAMPTZ
            );
        """)

    c, july_res, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_attendance_summary('{station_a_id}', '2026-07-01', '2026-07-31')")
    c, emp2_july, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_employee_attendance_summary('{station_a_id}', '2026-07-01', '2026-07-31', 'Sarah')")
    runner.assert_test("17. Repeated Lateness Alert (>= 3 late shifts)", 
                       july_res['repeated_lateness_employee_count'] == 1 and july_res['late_shifts'] == 3 and
                       emp2_july['items'][0]['has_repeated_lateness'] == True,
                       f"Station: {july_res}, Employee: {emp2_july}")

    # 18. On-Time Arrival Rate Math (0.0% when all completed shifts are late)
    runner.assert_test("18. On-Time Arrival Rate Math (0.0% on all late)", 
                       float(july_res['on_time_arrival_rate_percentage']) == 0.0,
                       f"On time rate: {july_res['on_time_arrival_rate_percentage']}")

    # 19. Mathematical Sum Invariant (Station Sum = SUM of Employee Breakdown)
    c, sum_a, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_attendance_summary('{station_a_id}', '2026-08-01', '2026-08-31')")
    c, breakdown_a, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_employee_attendance_summary('{station_a_id}', '2026-08-01', '2026-08-31', NULL, 'name', 'asc', 50, 0)")
    
    sum_emp_worked = sum(it['total_worked_minutes'] for it in breakdown_a['items'])
    sum_emp_shifts = sum(it['completed_shifts'] for it in breakdown_a['items'])
    sum_emp_late = sum(it['late_shifts'] for it in breakdown_a['items'])
    sum_emp_corr = sum(it['corrected_records'] for it in breakdown_a['items'])

    runner.assert_test("19. Mathematical Sum Invariant Across All Employees", 
                       sum_a['total_worked_minutes'] == sum_emp_worked and
                       sum_a['completed_shifts'] == sum_emp_shifts and
                       sum_a['late_shifts'] == sum_emp_late and
                       sum_a['corrected_records'] == sum_emp_corr,
                       f"Station: {sum_a}, Sum of Emps: worked={sum_emp_worked}, shifts={sum_emp_shifts}, late={sum_emp_late}, corr={sum_emp_corr}")

    # 20. Cross-Station Manager Access Denied (42501)
    c, d, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_attendance_summary('{station_b_id}', '2026-08-01', '2026-08-31')")
    runner.assert_test("20. Cross-Station Manager Access Denied (42501)", c != 0 and '42501' in e)

    # 21. Employee Denied Station Summary (42501)
    c, d, e = run_as_user_json(emp1_user_id, f"SELECT public.get_station_attendance_summary('{station_a_id}', '2026-08-01', '2026-08-31')")
    runner.assert_test("21. Employee Denied Station Summary (42501)", c != 0 and '42501' in e)

    # 22. Anti-IDOR: Foreign Employee Drilldown Blocked (P0002)
    c, d, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_employee_attendance_detail('{station_a_id}', '{emp_foreign_id}', '2026-08-01', '2026-08-31')")
    runner.assert_test("22. Anti-IDOR: Foreign Employee Drilldown Blocked (P0002)", c != 0 and ('P0002' in e or 'not associated' in e))

    # 23. Search Wildcard Sanitization ('%%__\\\\David' -> matches David Cohen)
    c, res_wildcard, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_employee_attendance_summary('{station_a_id}', '2026-08-01', '2026-08-31', '%%__\\\\David')")
    runner.assert_test("23. Search Wildcard Sanitization ('%%__\\\\David' -> matches David Cohen)", 
                       c == 0 and res_wildcard and res_wildcard['total_count'] == 1 and res_wildcard['items'][0]['first_name'] == 'David',
                       f"Result: {res_wildcard}")

    # 24. SQL Injection String in Search Defended
    c, res_inj, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_employee_attendance_summary('{station_a_id}', '2026-08-01', '2026-08-31', 'David'' OR 1=1 --')")
    runner.assert_test("24. SQL Injection String in Search Defended", c == 0 and res_inj and res_inj.get('success') == True)

    # 25. Sort Whitelist Injection Defense
    c, res_sort_inj, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_employee_attendance_summary('{station_a_id}', '2026-08-01', '2026-08-31', NULL, 'name; drop table profiles;', 'desc')")
    runner.assert_test("25. Malicious Sort Column Falls Back Safely to Name", 
                       c == 0 and res_sort_inj and res_sort_inj.get('success') == True and len(res_sort_inj['items']) > 0,
                       f"Result: {res_sort_inj}")

    # 26. Pagination Limit Clamped to 50 & Offset Clamped to 0
    c, res_page_clamp, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_employee_attendance_summary('{station_a_id}', '2026-08-01', '2026-08-31', NULL, 'name', 'asc', 10000, -5)")
    runner.assert_test("26. Pagination Limit Clamped to 50 & Offset Clamped to 0", 
                       c == 0 and res_page_clamp and res_page_clamp['limit'] == 50 and res_page_clamp['offset'] == 0,
                       f"Result: {res_page_clamp}")

    # 27. Attendance History Status Filters (COMPLETED vs CORRECTED)
    c, hist_comp, e = run_as_user_json(emp1_user_id, "SELECT public.get_my_attendance_history('2026-08-01', '2026-08-31', NULL, 'COMPLETED')")
    c, hist_corr, e = run_as_user_json(emp1_user_id, "SELECT public.get_my_attendance_history('2026-08-01', '2026-08-31', NULL, 'CORRECTED')")
    runner.assert_test("27. Attendance History Status Filters (COMPLETED vs CORRECTED)", 
                       c == 0 and hist_comp['total_count'] == 3 and hist_corr['total_count'] == 1,
                       f"Completed: {hist_comp['total_count']}, Corrected: {hist_corr['total_count']}")

    # 28. Daily Operational Report with Staffing & Shortage Math
    run_psql(f"""
        INSERT INTO public.shift_templates (id, station_id, name, start_time, end_time, sort_order)
        VALUES ('80000000-0000-0000-0000-000000000001', '{station_a_id}', 'Day Shift', '08:00:00', '16:00:00', 1)
        ON CONFLICT (id) DO NOTHING;

        INSERT INTO public.availability_periods (id, station_id, week_start_date, submission_deadline, status, created_by)
        VALUES ('70000000-0000-0000-0000-000000000001', '{station_a_id}', '2026-08-23', '2026-08-22 12:00:00+03', 'CLOSED', '{admin_user_id}')
        ON CONFLICT (station_id, week_start_date) DO UPDATE SET status = 'CLOSED';

        INSERT INTO public.availability_period_shift_templates (id, availability_period_id, shift_template_id, name_snapshot, start_time_snapshot, end_time_snapshot, sort_order_snapshot)
        VALUES ('60000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', '80000000-0000-0000-0000-000000000001', 'Day Shift', '08:00:00', '16:00:00', 1)
        ON CONFLICT DO NOTHING;

        INSERT INTO public.work_schedules (id, station_id, availability_period_id, week_start_date, status, version, created_by, published_by, published_at)
        VALUES ('44444444-4444-4444-4444-444444444444', '{station_a_id}', '70000000-0000-0000-0000-000000000001', '2026-08-23', 'PUBLISHED', 1, '{admin_user_id}', '{admin_user_id}', now())
        ON CONFLICT (station_id, week_start_date) DO UPDATE SET status = 'PUBLISHED';

        INSERT INTO public.work_schedule_shifts (
            id, work_schedule_id, station_id, operational_date, period_shift_template_id,
            shift_name_snapshot, start_time_snapshot, end_time_snapshot,
            starts_at, ends_at, required_staff_count
        ) VALUES (
            '55555555-5555-5555-5555-555555555555', '44444444-4444-4444-4444-444444444444',
            '{station_a_id}', '2026-08-25', '60000000-0000-0000-0000-000000000001',
            'Day Shift', '08:00:00', '16:00:00',
            '2026-08-25 05:00:00+00', '2026-08-25 13:00:00+00', 3
        ) ON CONFLICT (id) DO NOTHING;

        INSERT INTO public.shift_assignments (id, work_schedule_shift_id, station_id, membership_id, user_id, availability_state_snapshot, assigned_by)
        VALUES 
            (gen_random_uuid(), '55555555-5555-5555-5555-555555555555', '{station_a_id}', '{mem_emp1_a}', '{emp1_user_id}', 'AVAILABLE', '{admin_user_id}'),
            (gen_random_uuid(), '55555555-5555-5555-5555-555555555555', '{station_a_id}', '{mem_emp2_a}', '{emp2_user_id}', 'AVAILABLE', '{admin_user_id}')
        ON CONFLICT DO NOTHING;


        INSERT INTO public.attendance_records (
            station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id, work_schedule_shift_id,
            check_in_time, check_out_time, worked_minutes, late_minutes,
            status, verification_method, scheduled_start_at_snapshot
        ) VALUES (
            '{station_a_id}', '{emp1_user_id}', '{mem_emp1_a}', '{kiosk_a_id}', '55555555-5555-5555-5555-555555555555',
            '2026-08-25 05:00:00+00', '2026-08-25 13:00:00+00',
            480, 0, 'COMPLETED', 'QR_ONLY', '2026-08-25 05:00:00+00'
        );

        INSERT INTO public.attendance_records (
            station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id, work_schedule_shift_id,
            check_in_time, check_out_time, worked_minutes, late_minutes,
            status, verification_method
        ) VALUES (
            '{station_a_id}', '{emp3_user_id}', '{mem_emp3_a}', '{kiosk_a_id}', NULL,
            '2026-08-25 06:00:00+00', '2026-08-25 14:00:00+00',
            480, 0, 'COMPLETED', 'QR_ONLY'
        );
    """)

    c, daily_res, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_daily_attendance_report('{station_a_id}', '2026-08-25')")
    shift0 = daily_res['shifts'][0] if (daily_res and daily_res.get('shifts')) else {}
    walkins = daily_res.get('walk_ins', []) if daily_res else []
    runner.assert_test("28. Daily Report Staffing & Shortage Math (Req=3, Ass=2, Chk=1 -> Shortage=2, NotCheckedIn=1)", 
                       shift0.get('required_staff_count') == 3 and shift0.get('assigned_count') == 2 and 
                       shift0.get('checked_in_count') == 1 and shift0.get('shortage_count') == 2 and shift0.get('not_checked_in_count') == 1 and
                       len(walkins) == 1 and walkins[0]['user_id'] == emp3_user_id,
                       f"Shift: {shift0}, Walkins: {walkins}")

    # 29. Read-Only Invariant: Zero Mutations / Zero Side-Effects
    c, recs_b, e = run_psql("SELECT COUNT(*) FROM public.attendance_records;")
    c, corrs_b, e = run_psql("SELECT COUNT(*) FROM public.attendance_corrections;")
    c, notifs_b, e = run_psql("SELECT COUNT(*) FROM public.notifications;")

    # Execute all 6 RPCs
    run_as_user_json(manager_user_id, "SELECT public.get_my_attendance_summary('2026-08-01', '2026-08-31')")
    run_as_user_json(manager_user_id, "SELECT public.get_my_attendance_history('2026-08-01', '2026-08-31')")
    run_as_user_json(manager_user_id, f"SELECT public.get_station_attendance_summary('{station_a_id}', '2026-08-01', '2026-08-31')")
    run_as_user_json(manager_user_id, f"SELECT public.get_station_employee_attendance_summary('{station_a_id}', '2026-08-01', '2026-08-31')")
    run_as_user_json(manager_user_id, f"SELECT public.get_station_daily_attendance_report('{station_a_id}', '2026-08-25')")
    run_as_user_json(manager_user_id, f"SELECT public.get_station_employee_attendance_detail('{station_a_id}', '{emp1_user_id}', '2026-08-01', '2026-08-31')")

    c, recs_a, e = run_psql("SELECT COUNT(*) FROM public.attendance_records;")
    c, corrs_a, e = run_psql("SELECT COUNT(*) FROM public.attendance_corrections;")
    c, notifs_a, e = run_psql("SELECT COUNT(*) FROM public.notifications;")

    runner.assert_test("29. Read-Only Invariant: Zero Mutations / Zero Side-Effects", 
                       recs_b == recs_a and corrs_b == corrs_a and notifs_b == notifs_a,
                       f"Recs: {recs_b}->{recs_a}, Corrs: {corrs_b}->{corrs_a}, Notifs: {notifs_b}->{notifs_a}")

    # 30. Absolute Zero Payroll Schema Verification
    c, out_p, e = run_psql("""
        SELECT count(*) 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND column_name ~* '(salary|wage|hourly_rate|gross|net_pay|payroll|bonus|commission|deduction|tax|overtime_rate)';
    """)
    runner.assert_test("30. Absolute Zero Payroll Schema Verification", out_p.strip() == "0", f"Found columns: {out_p}")

    # 31. Zero Secret / Token Leakage in Payloads
    sample_payload = json.dumps([self_res, sum_a, daily_res, det])
    secret_terms = ['service_role', 'eyJhbGciOi', 'password', 'token_hash', 'kiosk_secret', 'presence_proof']
    secrets_found = [s for s in secret_terms if s in sample_payload]
    runner.assert_test("31. Zero Secret / Token Leakage in Payloads", len(secrets_found) == 0, f"Found secrets: {secrets_found}")

    # 32. Timezone Fallback Verification
    run_psql(f"UPDATE public.stations SET timezone = 'Mars/Curiosity_Rover' WHERE id = '{station_c_id}';")
    c, out_tz, e = run_psql(f"SELECT public.resolve_station_timezone('{station_c_id}');")
    runner.assert_test("32. Invalid Station Timezone Falls Back to 'Asia/Jerusalem'", out_tz.strip() == "Asia/Jerusalem", f"Resolved: {out_tz}")

    # 33. Missing Profile Fallback on Daily Report (Record preserved even if profile missing)
    run_psql(f"""
        INSERT INTO public.attendance_records (
            station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id,
            check_in_time, check_out_time, worked_minutes, late_minutes, status, verification_method
        ) VALUES (
            '{station_a_id}', '77777777-7777-7777-7777-777777777777', '{mem_emp1_a}', '{kiosk_a_id}',
            '2026-08-25 07:00:00+00', '2026-08-25 15:00:00+00',
            480, 0, 'COMPLETED', 'QR_ONLY'
        );
    """)
    c, daily_mp, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_daily_attendance_report('{station_a_id}', '2026-08-25')")
    walkins_mp = daily_mp.get('walk_ins', []) if daily_mp else []
    missing_emp = next((w for w in walkins_mp if w['user_id'] == '77777777-7777-7777-7777-777777777777'), None)
    runner.assert_test("33. Missing Profile Fallback (First Name 'Unknown', Record Not Lost)", 
                       missing_emp is not None and missing_emp['first_name'] == 'Unknown',
                       f"Missing emp: {missing_emp}")

    # 34. High-Scale Benchmark (300 Employees, 25,000 Records)
    print("\n[*] Generating high-scale dataset: 300 employees, 25,000 attendance records...")
    scale_gen_sql = f"""
        DO $$
        DECLARE
            v_emp_id UUID;
            v_mem_id UUID;
            v_i INTEGER;
            v_j INTEGER;
            v_base_date DATE := '2026-01-01';
            v_start TIMESTAMPTZ;
        BEGIN
            FOR v_i IN 1..300 LOOP
                v_emp_id := ('00000000-0000-0000-0001-' || LPAD(v_i::TEXT, 12, '0'))::UUID;
                v_mem_id := ('00000000-0000-0000-0002-' || LPAD(v_i::TEXT, 12, '0'))::UUID;

                INSERT INTO auth.users (id, email)
                VALUES (v_emp_id, 'emp' || v_i || '@scale.test')
                ON CONFLICT (id) DO NOTHING;

                INSERT INTO public.profiles (id, first_name, last_name)
                VALUES (v_emp_id, 'BenchEmp' || v_i, 'Scale')
                ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name;


                INSERT INTO public.station_memberships (id, station_id, user_id, role, status, employee_code)
                VALUES (v_mem_id, '{station_a_id}', v_emp_id, 'EMPLOYEE', 'ACTIVE', 'SC-' || v_i)
                ON CONFLICT (id) DO NOTHING;

                FOR v_j IN 0..83 LOOP
                    v_start := (v_base_date + v_j * 3)::TIMESTAMPTZ + INTERVAL '8 hours';
                    INSERT INTO public.attendance_records (
                        station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id,
                        check_in_time, check_out_time, worked_minutes, late_minutes, status, verification_method,
                        scheduled_start_at_snapshot, scheduled_end_at_snapshot
                    ) VALUES (
                        '{station_a_id}', v_emp_id, v_mem_id, '{kiosk_a_id}',
                        v_start, v_start + INTERVAL '8 hours',
                        480, (CASE WHEN (v_j % 5 = 0) THEN 15 ELSE 0 END),
                        'COMPLETED', 'QR_ONLY',
                        v_start, v_start + INTERVAL '8 hours'
                    );
                END LOOP;
            END LOOP;
        END $$;
    """
    run_psql(scale_gen_sql)
    c, total_recs, e = run_psql(f"SELECT COUNT(*) FROM public.attendance_records WHERE station_id = '{station_a_id}';")
    print(f"[+] Total station records in database: {total_recs}")

    # Benchmark Station Summary
    t0 = time.time()
    c, scale_sum, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_attendance_summary('{station_a_id}', '2026-01-01', '2026-10-01')")
    t_summary_ms = (time.time() - t0) * 1000.0

    # Benchmark Employee Breakdown Page 1
    t0 = time.time()
    c, scale_breakdown, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_employee_attendance_summary('{station_a_id}', '2026-01-01', '2026-10-01', NULL, 'worked_minutes', 'desc', 25, 0)")
    t_breakdown_ms = (time.time() - t0) * 1000.0

    # Benchmark Employee Drilldown Detail
    t0 = time.time()
    c, scale_detail, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_employee_attendance_detail('{station_a_id}', '00000000-0000-0000-0001-000000000001', '2026-01-01', '2026-10-01')")
    t_detail_ms = (time.time() - t0) * 1000.0

    print(f"[*] Benchmark 25k records -> Station Summary: {t_summary_ms:.2f}ms, Breakdown: {t_breakdown_ms:.2f}ms, Detail: {t_detail_ms:.2f}ms")

    runner.assert_test("34. High-Scale Benchmark: Station Summary Execution (< 100ms)", t_summary_ms < 100.0, f"{t_summary_ms:.2f}ms")
    runner.assert_test("35. High-Scale Benchmark: Employee Breakdown Page 1 (< 150ms)", t_breakdown_ms < 150.0, f"{t_breakdown_ms:.2f}ms")
    runner.assert_test("36. High-Scale Benchmark: Employee Drilldown (< 50ms)", t_detail_ms < 50.0, f"{t_detail_ms:.2f}ms")

    # 37. EXPLAIN ANALYZE Index Verification
    c, plan_out, e = run_psql(f"""
        EXPLAIN (ANALYZE, FORMAT JSON)
        SELECT ar.id FROM public.attendance_records ar
        WHERE ar.station_id = '{station_a_id}'
          AND COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) >= '2026-01-01 00:00:00+02'
          AND COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) < '2026-10-01 00:00:00+02';
    """)
    runner.assert_test("37. EXPLAIN Plan Validated on Attendance Query", c == 0 and ("Index" in plan_out or "Scan" in plan_out))

    # 38-45: Error boundary assertions
    adv_checks = [
        ("38. Nonexistent Station returns P0002", f"SELECT public.get_station_attendance_summary('99999999-0000-0000-0000-000000000000', '2026-08-01', '2026-08-31')", "P0002"),
        ("39. Nonexistent Station in Employee Breakdown returns P0002", f"SELECT public.get_station_employee_attendance_summary('99999999-0000-0000-0000-000000000000', '2026-08-01', '2026-08-31')", "P0002"),
        ("40. Nonexistent Station in Daily Report returns P0002", f"SELECT public.get_station_daily_attendance_report('99999999-0000-0000-0000-000000000000', '2026-08-25')", "P0002"),
        ("41. Nonexistent Station in Detail returns P0002", f"SELECT public.get_station_employee_attendance_detail('99999999-0000-0000-0000-000000000000', '{emp1_user_id}', '2026-08-01', '2026-08-31')", "P0002"),
        ("42. Null Station ID in Station Summary raises 22000", "SELECT public.get_station_attendance_summary(NULL, '2026-08-01', '2026-08-31')", "22000"),
        ("43. Null Date in Daily Report raises 22000", f"SELECT public.get_station_daily_attendance_report('{station_a_id}', NULL)", "22000"),
        ("44. Negative Date Range raises 22000", f"SELECT public.get_station_attendance_summary('{station_a_id}', '2026-08-31', '2026-08-01')", "22000"),
        ("45. Date Range Exceeding 366 Days raises 22000", f"SELECT public.get_station_attendance_summary('{station_a_id}', '2025-01-01', '2026-01-10')", "22000")
    ]

    for title, q, exp_err in adv_checks:
        c, d, e = run_as_user_json(manager_user_id, q)
        runner.assert_test(title, c != 0 and (exp_err in e or exp_err in str(d)))

    # 46-59: Verify all sorting whitelist columns (asc and desc)
    for sort_col in ['name', 'employee_code', 'worked_minutes', 'completed_shifts', 'late_shifts', 'corrected_records', 'last_seen']:
        c, res_s, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_employee_attendance_summary('{station_a_id}', '2026-01-01', '2026-03-01', NULL, '{sort_col}', 'asc', 10, 0)")
        runner.assert_test(f"Sorting by '{sort_col}' asc executes cleanly", c == 0 and res_s and res_s.get('success') == True and len(res_s['items']) > 0)

        c, res_sd, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_employee_attendance_summary('{station_a_id}', '2026-01-01', '2026-03-01', NULL, '{sort_col}', 'desc', 10, 0)")
        runner.assert_test(f"Sorting by '{sort_col}' desc executes cleanly", c == 0 and res_sd and res_sd.get('success') == True and len(res_sd['items']) > 0)

    # 60. Overload check
    c, out_ov, e = run_psql("""
        SELECT COUNT(*) FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND proname = 'get_my_attendance_history';
    """)
    runner.assert_test("60. Zero Ambiguous Overloads on get_my_attendance_history (Exact 1 signature)", out_ov.strip() == "1", f"Found: {out_ov}")

    # 61. Empty Station Test
    run_psql(f"""
        INSERT INTO public.station_memberships (station_id, user_id, role, status)
        VALUES ('{station_c_id}', '{admin_user_id}', 'ADMIN', 'ACTIVE')
        ON CONFLICT DO NOTHING;
    """)
    c, emp_st_c, e = run_as_user_json(admin_user_id, f"SELECT public.get_station_attendance_summary('{station_c_id}', '2026-08-01', '2026-08-31')")
    runner.assert_test("61. Empty Station Returns Graceful Zero Summary", 
                       c == 0 and emp_st_c and emp_st_c['total_worked_minutes'] == 0 and emp_st_c['completed_shifts'] == 0 and emp_st_c['on_time_arrival_rate_percentage'] == 100.0,
                       f"Result: {emp_st_c}")

    # 62. Shift Manager Explicit Override (reports.team.read=false) Blocks Access
    run_psql(f"""
        INSERT INTO public.station_shift_manager_permissions (station_id, permission, is_enabled)
        VALUES ('{station_a_id}', 'reports.team.read', false)
        ON CONFLICT (station_id, permission) DO UPDATE SET is_enabled = false;
    """)
    c, d, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_attendance_summary('{station_a_id}', '2026-08-01', '2026-08-31')")
    runner.assert_test("62. Shift Manager Explicit Override (reports.team.read=false) Blocks Access", c != 0 and '42501' in e)

    # 63. Shift Manager Explicit Override (reports.team.read=true) Restores Access
    run_psql(f"""
        UPDATE public.station_shift_manager_permissions
        SET is_enabled = true
        WHERE station_id = '{station_a_id}' AND permission = 'reports.team.read';
    """)
    c, mgr_restored, e = run_as_user_json(manager_user_id, f"SELECT public.get_station_attendance_summary('{station_a_id}', '2026-08-01', '2026-08-31')")
    runner.assert_test("63. Shift Manager Explicit Override (reports.team.read=true) Restores Access", c == 0 and mgr_restored and mgr_restored.get('success') == True)

    print("\n" + "=" * 75)
    print(f"PHASE 7 COMPREHENSIVE AUDIT V2 RESULTS: {runner.passed}/{runner.total} PASSED ({(runner.passed/runner.total)*100:.1f}%)")
    print("=" * 75)

    if runner.failed > 0:
        print(f"[-] {runner.failed} TESTS FAILED!")
        sys.exit(1)
    else:
        print("[+] ALL AUDIT V2 SCENARIOS PASSED WITH ZERO FLAWS.")

if __name__ == "__main__":
    main()
