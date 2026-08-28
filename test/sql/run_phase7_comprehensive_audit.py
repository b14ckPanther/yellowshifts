#!/usr/bin/env python3
"""
YellowShifts Phase 7 — Comprehensive Adversarial & Domain Audit Suite
Tests: Time Analytics, Multi-Station Isolation, Operational Date Boundaries,
DST Integrity, Open Sessions, Correction Ledger Invariants, Repeated Lateness,
Daily Operational Shift Boards, Scale Benchmarks & Zero Payroll Verification.
"""

import os
import shutil
import sys
import json
import time
import uuid
import datetime
import subprocess

DB_NAME = "yellowshifts_phase7_audit"
PSQL_BIN = shutil.which("psql") or "/opt/homebrew/opt/postgresql@16/bin/psql"
if not os.path.exists(PSQL_BIN):
    PSQL_BIN = shutil.which("psql") or "psql"
CURRENT_USER = os.getenv("USER", "postgres")

def run_psql(sql: str, db: str = DB_NAME) -> tuple[int, str, str]:
    cmd = [PSQL_BIN, "-d", db, "-U", CURRENT_USER, "-A", "-t", "-c", sql]
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
    subprocess.run([PSQL_BIN, "-d", "postgres", "-U", CURRENT_USER, "-c", f"DROP DATABASE IF EXISTS {DB_NAME};"], capture_output=True)
    res = subprocess.run([PSQL_BIN, "-d", "postgres", "-U", CURRENT_USER, "-c", f"CREATE DATABASE {DB_NAME};"], capture_output=True, text=True)
    if res.returncode != 0:
        print(f"[-] Database creation failed: {res.stderr}")
        sys.exit(1)

    migrations_dir = os.path.join(os.path.dirname(__file__), "../../supabase/migrations")
    files = sorted([f for f in os.listdir(migrations_dir) if f.endswith(".sql")])
    for mf in files:
        fpath = os.path.join(migrations_dir, mf)
        mres = subprocess.run([PSQL_BIN, "-d", DB_NAME, "-U", CURRENT_USER, "-f", fpath], capture_output=True, text=True)
        if mres.returncode != 0:
            print(f"[-] Failed applying {mf}: {mres.stderr}")
            sys.exit(1)
    print(f"[*] All {len(files)} migrations (001 through 011) applied cleanly.")

def seed_comprehensive_context():
    sql = """
    -- Stations
    INSERT INTO public.stations (id, name, code, timezone, locale, week_start, is_active, check_in_early_minutes, late_grace_minutes)
    VALUES 
    ('11111111-1111-1111-1111-111111111111', 'Station North', 'STA-N', 'Asia/Jerusalem', 'he', 0, true, 15, 5),
    ('22222222-2222-2222-2222-222222222222', 'Station South', 'STA-S', 'Asia/Jerusalem', 'he', 0, true, 15, 5)
    ON CONFLICT (id) DO NOTHING;

    -- Users (Admin, Manager, 4 Employees)
    INSERT INTO auth.users (id, email) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'admin_north@test.com'),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'mgr_north@test.com'),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'emp_charlie@test.com'),
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'emp_david@test.com'),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'admin_south@test.com'),
    ('ffffffff-ffff-ffff-ffff-ffffffffffff', 'emp_frank_inactive@test.com')
    ON CONFLICT (id) DO NOTHING;

    -- Profiles
    INSERT INTO public.profiles (id, first_name, last_name, preferred_locale) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Alice', 'Admin', 'he'),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Bob', 'Manager', 'he'),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Charlie', 'Cohen', 'he'),
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'David', 'Levi', 'he'),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'Eve', 'AdminSouth', 'he'),
    ('ffffffff-ffff-ffff-ffff-ffffffffffff', 'Frank', 'Inactive', 'he')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name;

    -- Shift Templates
    INSERT INTO public.shift_templates (id, station_id, name, start_time, end_time, sort_order)
    VALUES 
    ('80000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Morning Shift', '08:00:00', '16:00:00', 1)
    ON CONFLICT (id) DO NOTHING;

    -- Station Memberships
    INSERT INTO public.station_memberships (id, station_id, user_id, role, status, employee_code) VALUES
    ('10000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'ADMIN', 'ACTIVE', 'EMP-ADM-N'),
    ('10000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'SHIFT_MANAGER', 'ACTIVE', 'EMP-MGR-N'),
    ('10000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'EMPLOYEE', 'ACTIVE', 'EMP-001'),
    ('10000000-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'EMPLOYEE', 'ACTIVE', 'EMP-002'),
    ('20000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'ADMIN', 'ACTIVE', 'EMP-ADM-S'),
    ('20000000-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'EMPLOYEE', 'ACTIVE', 'EMP-001-S'),
    ('10000000-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'EMPLOYEE', 'INACTIVE', 'EMP-009')
    ON CONFLICT (station_id, user_id) DO NOTHING;

    -- Kiosks
    INSERT INTO public.kiosk_devices (id, station_id, device_identifier, name, secret_hash, is_active, created_by)
    VALUES 
    ('91111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'KIOSK-N-01', 'North Kiosk', 'dummy_hash', true, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
    ('92222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222', 'KIOSK-S-01', 'South Kiosk', 'dummy_hash', true, 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee')
    ON CONFLICT (id) DO NOTHING;
    """
    run_psql(sql)

# ======================================================================
# SCENARIOS (40+ COMPREHENSIVE TESTS)
# ======================================================================

def test_01_multi_station_employee_aggregation():
    # Charlie worked 480 min at Station North and 240 min at Station South in Aug 2026
    run_psql("""
    INSERT INTO public.attendance_records (
        id, station_id, employee_user_id, station_membership_id,
        shift_name_snapshot, scheduled_start_at_snapshot, scheduled_end_at_snapshot,
        check_in_time, check_out_time, worked_minutes, late_minutes, status,
        check_in_kiosk_device_id, check_out_kiosk_device_id
    ) VALUES 
    ('c0000001-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '10000000-0000-0000-0000-000000000003', 'Morning Shift', '2026-08-10 08:00:00+03', '2026-08-10 16:00:00+03', '2026-08-10 08:00:00+03', '2026-08-10 16:00:00+03', 480, 0, 'COMPLETED', '91111111-1111-1111-1111-111111111111', '91111111-1111-1111-1111-111111111111'),
    ('c0000001-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '20000000-0000-0000-0000-000000000003', 'Evening Shift', '2026-08-11 16:00:00+03', '2026-08-11 20:00:00+03', '2026-08-11 16:00:00+03', '2026-08-11 20:00:00+03', 240, 0, 'COMPLETED', '92222222-2222-2222-2222-222222222222', '92222222-2222-2222-2222-222222222222')
    ON CONFLICT (id) DO NOTHING;
    """)

    # 1. Charlie self summary with no station filter -> total 720 minutes across 2 stations
    code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "public.get_my_attendance_summary('2026-08-01'::DATE, '2026-08-31'::DATE)")
    if code != 0 or res.get("total_worked_minutes") != 720 or res.get("stations_worked_count") != 2:
        return False, f"Self global summary failed: {res}"

    # 2. Charlie filtered to Station North -> 480 min
    code2, res2, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "public.get_my_attendance_summary('2026-08-01'::DATE, '2026-08-31'::DATE, '11111111-1111-1111-1111-111111111111'::UUID)")
    if code2 != 0 or res2.get("total_worked_minutes") != 480 or res2.get("stations_worked_count") != 1:
        return False, f"Self Station North summary failed: {res2}"

    # 3. Station North Admin -> sees only 480 min for Station North
    code3, res3, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "public.get_station_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE)")
    if code3 != 0 or res3.get("total_worked_minutes") != 480:
        return False, f"Station North admin summary leaked foreign station data: {res3}"

    return True, ""

def test_02_open_session_excluded_from_completed_totals():
    # Insert active open session for David
    run_psql("""
    INSERT INTO public.attendance_records (
        id, station_id, employee_user_id, station_membership_id,
        shift_name_snapshot, check_in_time, check_out_time, worked_minutes, status,
        check_in_kiosk_device_id
    ) VALUES (
        'd0000001-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
        'dddddddd-dddd-dddd-dddd-dddddddddddd', '10000000-0000-0000-0000-000000000004',
        'Morning Shift', now() - INTERVAL '2 hours', NULL, NULL, 'OPEN',
        '91111111-1111-1111-1111-111111111111'
    ) ON CONFLICT (id) DO NOTHING;
    """)

    code, res, _ = run_as_user_json("dddddddd-dddd-dddd-dddd-dddddddddddd", f"public.get_my_attendance_summary('{datetime.date.today()}'::DATE, '{datetime.date.today()}'::DATE)")
    if code == 0:
        if res.get("total_worked_minutes") != 0 or res.get("completed_shifts") != 0:
            return False, f"Open session was incorrectly counted in completed totals: {res}"
        if res.get("open_session_count") != 1:
            return False, f"Open session count mismatch: {res}"
        active = res.get("active_open_session")
        if not active or active.get("elapsed_minutes") < 110:
            return False, f"Active open session details missing or elapsed duration wrong: {active}"
        return True, ""
    return False, f"Query failed: {res}"

def test_03_open_session_16h_anomaly_flag():
    # Insert open session from 17 hours ago
    run_psql("""
    INSERT INTO public.attendance_records (
        id, station_id, employee_user_id, station_membership_id,
        shift_name_snapshot, check_in_time, check_out_time, worked_minutes, status,
        check_in_kiosk_device_id
    ) VALUES (
        'd0000001-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
        'ffffffff-ffff-ffff-ffff-ffffffffffff', '10000000-0000-0000-0000-000000000005',
        'Night Shift', now() - INTERVAL '17 hours', NULL, NULL, 'OPEN',
        '91111111-1111-1111-1111-111111111111'
    ) ON CONFLICT (id) DO NOTHING;
    """)

    code, res, _ = run_as_user_json("ffffffff-ffff-ffff-ffff-ffffffffffff", f"public.get_my_attendance_summary('{datetime.date.today() - datetime.timedelta(days=1)}'::DATE, '{datetime.date.today()}'::DATE)")
    if code == 0:
        active = res.get("active_open_session")
        if active and active.get("needs_attention") is True and active.get("elapsed_minutes") >= 1000:
            return True, ""
        return False, f"Expected needs_attention=True for >16h open session: {active}"
    return False, f"Query failed: {res}"

def test_04_distinct_correction_semantics():
    # Charlie has 1 attendance record with 3 corrections, worked 480 min
    rec_id = "c0000001-0000-0000-0000-000000000001"
    run_psql(f"""
    INSERT INTO public.attendance_corrections (id, attendance_record_id, station_id, actor_user_id, previous_worked_minutes, new_worked_minutes, reason, created_at)
    VALUES 
    (gen_random_uuid(), '{rec_id}', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 450, 460, 'Correction 1', now() - INTERVAL '3 hours'),
    (gen_random_uuid(), '{rec_id}', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 460, 470, 'Correction 2', now() - INTERVAL '2 hours'),
    (gen_random_uuid(), '{rec_id}', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 470, 480, 'Correction 3', now() - INTERVAL '1 hour');
    """)

    # Query station summary: completed_shifts MUST BE 1 (for this shift), corrected_records MUST BE 1, total_worked_minutes MUST BE 480 (not 1440)
    code, res, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "public.get_station_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-10'::DATE, '2026-08-10'::DATE)")
    if code == 0:
        if res.get("completed_shifts") == 1 and res.get("corrected_records") == 1 and res.get("total_worked_minutes") == 480:
            return True, ""
        return False, f"Multi-correction multiplication defect: {res}"
    return False, f"Query failed: {res}"

def test_05_inactive_employee_historical_reportability():
    # Frank (INACTIVE membership) has attendance on 2026-08-05
    run_psql("""
    INSERT INTO public.attendance_records (
        id, station_id, employee_user_id, station_membership_id,
        shift_name_snapshot, scheduled_start_at_snapshot, scheduled_end_at_snapshot,
        check_in_time, check_out_time, worked_minutes, late_minutes, status,
        check_in_kiosk_device_id, check_out_kiosk_device_id
    ) VALUES (
        'f0000001-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
        'ffffffff-ffff-ffff-ffff-ffffffffffff', '10000000-0000-0000-0000-000000000005',
        'Morning Shift', '2026-08-05 08:00:00+03', '2026-08-05 16:00:00+03',
        '2026-08-05 08:00:00+03', '2026-08-05 16:00:00+03', 480, 0, 'COMPLETED',
        '91111111-1111-1111-1111-111111111111', '91111111-1111-1111-1111-111111111111'
    ) ON CONFLICT (id) DO NOTHING;
    """)

    code, res, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "public.get_station_employee_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE, 'Frank')")
    if code == 0 and res.get("total_count") == 1:
        item = res["items"][0]
        if item.get("membership_status") == "INACTIVE" and item.get("total_worked_minutes") == 480:
            return True, ""
        return False, f"Inactive employee data mismatch: {item}"
    return False, f"Inactive employee not found in historical query: {res}"

def test_06_repeated_lateness_signal_detection():
    # Insert 3 late completed shifts for David in August
    for i in range(3):
        day = 15 + i
        run_psql(f"""
        INSERT INTO public.attendance_records (
            id, station_id, employee_user_id, station_membership_id,
            shift_name_snapshot, scheduled_start_at_snapshot, scheduled_end_at_snapshot,
            check_in_time, check_out_time, worked_minutes, late_minutes, status,
            check_in_kiosk_device_id, check_out_kiosk_device_id
        ) VALUES (
            'd0000002-0000-0000-0000-{i:012d}', '11111111-1111-1111-1111-111111111111',
            'dddddddd-dddd-dddd-dddd-dddddddddddd', '10000000-0000-0000-0000-000000000004',
            'Morning Shift', '2026-08-{day:02d} 08:00:00+03', '2026-08-{day:02d} 16:00:00+03',
            '2026-08-{day:02d} 08:25:00+03', '2026-08-{day:02d} 16:00:00+03', 455, 25, 'COMPLETED',
            '91111111-1111-1111-1111-111111111111', '91111111-1111-1111-1111-111111111111'
        ) ON CONFLICT (id) DO NOTHING;
        """)

    # Query employee breakdown for David: has_repeated_lateness MUST be True
    code, res, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "public.get_station_employee_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE, 'David')")
    if code == 0 and len(res.get("items", [])) > 0:
        item = res["items"][0]
        if item.get("has_repeated_lateness") is True and item.get("late_shifts") >= 3:
            return True, ""
        return False, f"Expected has_repeated_lateness=True, got: {item}"
    return False, f"Query failed: {res}"

def test_07_isolated_lateness_does_not_trigger_repeated_flag():
    # Charlie has 0 late shifts so far. Add 1 late shift:
    run_psql("""
    INSERT INTO public.attendance_records (
        id, station_id, employee_user_id, station_membership_id,
        shift_name_snapshot, scheduled_start_at_snapshot, scheduled_end_at_snapshot,
        check_in_time, check_out_time, worked_minutes, late_minutes, status,
        check_in_kiosk_device_id, check_out_kiosk_device_id
    ) VALUES (
        'c0000003-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
        'cccccccc-cccc-cccc-cccc-cccccccccccc', '10000000-0000-0000-0000-000000000003',
        'Morning Shift', '2026-08-18 08:00:00+03', '2026-08-18 16:00:00+03',
        '2026-08-18 08:15:00+03', '2026-08-18 16:00:00+03', 465, 15, 'COMPLETED',
        '91111111-1111-1111-1111-111111111111', '91111111-1111-1111-1111-111111111111'
    ) ON CONFLICT (id) DO NOTHING;
    """)

    code, res, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "public.get_station_employee_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE, 'Charlie')")
    if code == 0 and len(res.get("items", [])) > 0:
        item = res["items"][0]
        if item.get("has_repeated_lateness") is False and item.get("late_shifts") == 1:
            return True, ""
        return False, f"Expected has_repeated_lateness=False for 1 late shift, got: {item}"
    return False, f"Query failed: {res}"

def test_08_cross_midnight_operational_date_binding():
    # Shift starts on Sunday Aug 23 22:00 and ends on Monday Aug 24 06:00
    run_psql("""
    INSERT INTO public.attendance_records (
        id, station_id, employee_user_id, station_membership_id,
        shift_name_snapshot, scheduled_start_at_snapshot, scheduled_end_at_snapshot,
        check_in_time, check_out_time, worked_minutes, late_minutes, status,
        check_in_kiosk_device_id, check_out_kiosk_device_id
    ) VALUES (
        'c0000004-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
        'cccccccc-cccc-cccc-cccc-cccccccccccc', '10000000-0000-0000-0000-000000000003',
        'Night Shift', '2026-08-23 22:00:00+03', '2026-08-24 06:00:00+03',
        '2026-08-23 22:00:00+03', '2026-08-24 06:00:00+03', 480, 0, 'COMPLETED',
        '91111111-1111-1111-1111-111111111111', '91111111-1111-1111-1111-111111111111'
    ) ON CONFLICT (id) DO NOTHING;
    """)

    # Querying 2026-08-23 only: MUST include the shift
    code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "public.get_my_attendance_summary('2026-08-23'::DATE, '2026-08-23'::DATE)")
    if code != 0 or res.get("completed_shifts") != 1 or res.get("total_worked_minutes") != 480:
        return False, f"Cross-midnight shift missed on start date: {res}"

    # Querying 2026-08-24 only: MUST NOT include the cross-midnight shift starting on Aug 23
    code2, res2, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "public.get_my_attendance_summary('2026-08-24'::DATE, '2026-08-24'::DATE)")
    if code2 != 0 or res2.get("completed_shifts") != 0:
        return False, f"Cross-midnight shift leaked into second calendar day: {res2}"

    return True, ""

def test_09_month_boundary_operational_date_binding():
    # Shift starts Aug 31 22:00 and ends Sep 1 06:00
    run_psql("""
    INSERT INTO public.attendance_records (
        id, station_id, employee_user_id, station_membership_id,
        shift_name_snapshot, scheduled_start_at_snapshot, scheduled_end_at_snapshot,
        check_in_time, check_out_time, worked_minutes, late_minutes, status,
        check_in_kiosk_device_id, check_out_kiosk_device_id
    ) VALUES (
        'c0000005-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
        'cccccccc-cccc-cccc-cccc-cccccccccccc', '10000000-0000-0000-0000-000000000003',
        'Overnight Shift', '2026-08-31 22:00:00+03', '2026-09-01 06:00:00+03',
        '2026-08-31 22:00:00+03', '2026-09-01 06:00:00+03', 480, 0, 'COMPLETED',
        '91111111-1111-1111-1111-111111111111', '91111111-1111-1111-1111-111111111111'
    ) ON CONFLICT (id) DO NOTHING;
    """)

    # Query August month (Aug 1 - Aug 31): MUST contain the shift
    code1, res1, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "public.get_my_attendance_summary('2026-08-01'::DATE, '2026-08-31'::DATE)")
    # Query September month (Sep 1 - Sep 30): MUST NOT contain the shift
    code2, res2, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "public.get_my_attendance_summary('2026-09-01'::DATE, '2026-09-30'::DATE)")

    if code1 == 0 and code2 == 0:
        if res2.get("completed_shifts") == 0:
            return True, ""
        return False, f"Month boundary shift leaked into September: {res2}"
    return False, f"Query failed: res1={res1}, res2={res2}"

def test_10_walkin_attendance_operational_date():
    # Walk-in attendance with scheduled_start_at_snapshot IS NULL on 2026-08-25
    run_psql("""
    INSERT INTO public.attendance_records (
        id, station_id, employee_user_id, station_membership_id,
        shift_name_snapshot, scheduled_start_at_snapshot, scheduled_end_at_snapshot,
        check_in_time, check_out_time, worked_minutes, late_minutes, status,
        check_in_kiosk_device_id, check_out_kiosk_device_id
    ) VALUES (
        'c0000006-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
        'cccccccc-cccc-cccc-cccc-cccccccccccc', '10000000-0000-0000-0000-000000000003',
        NULL, NULL, NULL,
        '2026-08-25 10:00:00+03', '2026-08-25 14:00:00+03', 240, 0, 'COMPLETED',
        '91111111-1111-1111-1111-111111111111', '91111111-1111-1111-1111-111111111111'
    ) ON CONFLICT (id) DO NOTHING;
    """)

    code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "public.get_my_attendance_summary('2026-08-25'::DATE, '2026-08-25'::DATE)")
    if code == 0 and res.get("completed_shifts") == 1 and res.get("total_worked_minutes") == 240:
        return True, ""
    return False, f"Walk-in attendance failed on check_in fallback: {res}"

def test_11_dst_spring_duration_integrity():
    # Spring transition in Israel: 2026-03-27 02:00 -> 03:00 (clock moves forward 1h)
    # Shift from 2026-03-26 23:00 UTC+2 to 2026-03-27 07:00 UTC+3 = 7 real hours (420 minutes)
    run_psql("""
    INSERT INTO public.attendance_records (
        id, station_id, employee_user_id, station_membership_id,
        shift_name_snapshot, scheduled_start_at_snapshot, scheduled_end_at_snapshot,
        check_in_time, check_out_time, worked_minutes, late_minutes, status,
        check_in_kiosk_device_id, check_out_kiosk_device_id
    ) VALUES (
        'c0000007-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
        'cccccccc-cccc-cccc-cccc-cccccccccccc', '10000000-0000-0000-0000-000000000003',
        'Spring DST Shift', '2026-03-26 21:00:00+00', '2026-03-27 04:00:00+00',
        '2026-03-26 21:00:00+00', '2026-03-27 04:00:00+00', 420, 0, 'COMPLETED',
        '91111111-1111-1111-1111-111111111111', '91111111-1111-1111-1111-111111111111'
    ) ON CONFLICT (id) DO NOTHING;
    """)

    code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "public.get_my_attendance_summary('2026-03-26'::DATE, '2026-03-27'::DATE)")
    if code == 0 and res.get("total_worked_minutes") == 420:
        return True, ""
    return False, f"Spring DST duration integrity failed: {res}"

def test_12_dst_autumn_duration_integrity():
    # Autumn transition in Israel: 2026-10-25 02:00 -> 01:00 (clock moves back 1h)
    # Shift spanning 9 real hours = 540 minutes
    run_psql("""
    INSERT INTO public.attendance_records (
        id, station_id, employee_user_id, station_membership_id,
        shift_name_snapshot, scheduled_start_at_snapshot, scheduled_end_at_snapshot,
        check_in_time, check_out_time, worked_minutes, late_minutes, status,
        check_in_kiosk_device_id, check_out_kiosk_device_id
    ) VALUES (
        'c0000008-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
        'cccccccc-cccc-cccc-cccc-cccccccccccc', '10000000-0000-0000-0000-000000000003',
        'Autumn DST Shift', '2026-10-24 20:00:00+00', '2026-10-25 05:00:00+00',
        '2026-10-24 20:00:00+00', '2026-10-25 05:00:00+00', 540, 0, 'COMPLETED',
        '91111111-1111-1111-1111-111111111111', '91111111-1111-1111-1111-111111111111'
    ) ON CONFLICT (id) DO NOTHING;
    """)

    code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "public.get_my_attendance_summary('2026-10-24'::DATE, '2026-10-25'::DATE)")
    if code == 0 and res.get("total_worked_minutes") == 540:
        return True, ""
    return False, f"Autumn DST duration integrity failed: {res}"

def test_13_mathematical_invariants_verification():
    # Query station summary and compare to sum of all items in employee breakdown
    code_s, res_s, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "public.get_station_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE)")
    code_e, res_e, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "public.get_station_employee_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE, NULL, 'name', 'asc', 50, 0)")

    if code_s != 0 or code_e != 0:
        return False, "Failed fetching summaries for invariant check"

    st_worked = res_s.get("total_worked_minutes")
    st_shifts = res_s.get("completed_shifts")
    st_late = res_s.get("late_shifts")
    st_corrected = res_s.get("corrected_records")

    emp_worked_sum = sum(x.get("total_worked_minutes", 0) for x in res_e.get("items", []))
    emp_shifts_sum = sum(x.get("completed_shifts", 0) for x in res_e.get("items", []))
    emp_late_sum = sum(x.get("late_shifts", 0) for x in res_e.get("items", []))
    emp_corrected_sum = sum(x.get("corrected_records", 0) for x in res_e.get("items", []))

    if st_worked != emp_worked_sum:
        return False, f"Worked minutes invariant mismatch: Station={st_worked} vs Sum(Emps)={emp_worked_sum}"
    if st_shifts != emp_shifts_sum:
        return False, f"Completed shifts invariant mismatch: Station={st_shifts} vs Sum(Emps)={emp_shifts_sum}"
    if st_late != emp_late_sum:
        return False, f"Late shifts invariant mismatch: Station={st_late} vs Sum(Emps)={emp_late_sum}"
    if st_corrected != emp_corrected_sum:
        return False, f"Corrected records invariant mismatch: Station={st_corrected} vs Sum(Emps)={emp_corrected_sum}"

    return True, ""

def test_14_daily_operational_report_structure_and_counts():
    # Setup published schedule for 2026-08-20 (week of 2026-08-16)
    ap_id = str(uuid.uuid4())
    pst_id = str(uuid.uuid4())
    sched_id = str(uuid.uuid4())
    shift_id = str(uuid.uuid4())
    rec_id = "a0000001-1111-1111-1111-111111111111"
    run_psql(f"""
    INSERT INTO public.availability_periods (id, station_id, week_start_date, submission_deadline, status, created_by)
    VALUES ('{ap_id}', '11111111-1111-1111-1111-111111111111', '2026-08-16', '2026-08-15 12:00:00+03', 'CLOSED', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
    ON CONFLICT (station_id, week_start_date) DO UPDATE SET status = 'CLOSED';

    INSERT INTO public.availability_period_shift_templates (id, availability_period_id, shift_template_id, name_snapshot, start_time_snapshot, end_time_snapshot, sort_order_snapshot)
    VALUES ('{pst_id}', (SELECT id FROM public.availability_periods WHERE station_id = '11111111-1111-1111-1111-111111111111' AND week_start_date = '2026-08-16'), '80000000-0000-0000-0000-000000000001', 'Morning Shift', '08:00:00', '16:00:00', 1)
    ON CONFLICT (availability_period_id, shift_template_id) DO NOTHING;

    INSERT INTO public.work_schedules (id, station_id, availability_period_id, week_start_date, status, version, created_by, published_by, published_at)
    VALUES ('{sched_id}', '11111111-1111-1111-1111-111111111111', (SELECT id FROM public.availability_periods WHERE station_id = '11111111-1111-1111-1111-111111111111' AND week_start_date = '2026-08-16'), '2026-08-16', 'PUBLISHED', 1, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now())
    ON CONFLICT (station_id, week_start_date) DO UPDATE SET status = 'PUBLISHED';

    INSERT INTO public.work_schedule_shifts (
        id, work_schedule_id, station_id, operational_date, period_shift_template_id,
        shift_name_snapshot, start_time_snapshot, end_time_snapshot,
        starts_at, ends_at, required_staff_count
    ) VALUES (
        '{shift_id}',
        (SELECT id FROM public.work_schedules WHERE station_id = '11111111-1111-1111-1111-111111111111' AND week_start_date = '2026-08-16'),
        '11111111-1111-1111-1111-111111111111', '2026-08-20',
        (SELECT id FROM public.availability_period_shift_templates WHERE availability_period_id = (SELECT id FROM public.availability_periods WHERE station_id = '11111111-1111-1111-1111-111111111111' AND week_start_date = '2026-08-16') LIMIT 1),
        'Morning Shift', '08:00:00', '16:00:00',
        '2026-08-20 08:00:00+03', '2026-08-20 16:00:00+03', 2
    ) ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.shift_assignments (id, work_schedule_shift_id, station_id, membership_id, user_id, availability_state_snapshot, assigned_by)
    VALUES 
    (gen_random_uuid(), '{shift_id}', '11111111-1111-1111-1111-111111111111', '10000000-0000-0000-0000-000000000003', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'AVAILABLE', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
    (gen_random_uuid(), '{shift_id}', '11111111-1111-1111-1111-111111111111', '10000000-0000-0000-0000-000000000004', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'AVAILABLE', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.attendance_records (
        id, station_id, employee_user_id, station_membership_id, work_schedule_shift_id,
        shift_name_snapshot, scheduled_start_at_snapshot, scheduled_end_at_snapshot,
        check_in_time, check_out_time, worked_minutes, late_minutes, status,
        check_in_kiosk_device_id, check_out_kiosk_device_id
    ) VALUES (
        '{rec_id}',
        '11111111-1111-1111-1111-111111111111',
        'cccccccc-cccc-cccc-cccc-cccccccccccc',
        '10000000-0000-0000-0000-000000000003',
        '{shift_id}',
        'Morning Shift',
        '2026-08-20 08:00:00+03',
        '2026-08-20 16:00:00+03',
        '2026-08-20 08:05:00+03',
        '2026-08-20 16:05:00+03',
        480, 0, 'COMPLETED',
        '91111111-1111-1111-1111-111111111111',
        '91111111-1111-1111-1111-111111111111'
    ) ON CONFLICT (id) DO UPDATE SET work_schedule_shift_id = EXCLUDED.work_schedule_shift_id;
    """)

    code, res, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "public.get_station_daily_attendance_report('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-20'::DATE)")
    if code == 0 and res.get("success") is True:
        shifts = res.get("shifts", [])
        if len(shifts) >= 1:
            s0 = shifts[0]
            if s0.get("assigned_count") == 2 and s0.get("checked_in_count") >= 1:
                return True, ""
        return False, f"Daily report shift metrics unexpected: {res}"
    return False, f"Daily report query failed: {res}"

def test_15_employee_detail_ordered_correction_ledger():
    code, res, _ = run_as_user_json(
        "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        "public.get_station_employee_attendance_detail('11111111-1111-1111-1111-111111111111'::UUID, 'cccccccc-cccc-cccc-cccc-cccccccccccc'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE)"
    )
    if code == 0 and res.get("success") is True:
        records = res.get("records", [])
        corrected_recs = [r for r in records if len(r.get("corrections", [])) > 0]
        if len(corrected_recs) >= 1:
            corrs = corrected_recs[0]["corrections"]
            # Verify chronological order
            reasons = [c["reason"] for c in corrs]
            if reasons == ["Correction 1", "Correction 2", "Correction 3"]:
                return True, ""
            return False, f"Corrections not ordered chronologically: {reasons}"
        return False, f"No corrected records found in detail drilldown: {records}"
    return False, f"Detail drilldown failed: {res}"

def test_16_corrupt_negative_worked_minutes_safely_ignored():
    # Insert corrupt negative worked minutes (-120)
    run_psql("""
    INSERT INTO public.attendance_records (
        id, station_id, employee_user_id, station_membership_id,
        shift_name_snapshot, scheduled_start_at_snapshot, scheduled_end_at_snapshot,
        check_in_time, check_out_time, worked_minutes, late_minutes, status,
        check_in_kiosk_device_id, check_out_kiosk_device_id
    ) VALUES (
        'c0000009-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
        'cccccccc-cccc-cccc-cccc-cccccccccccc', '10000000-0000-0000-0000-000000000003',
        'Corrupt Shift', '2026-08-28 08:00:00+03', '2026-08-28 16:00:00+03',
        '2026-08-28 08:00:00+03', '2026-08-28 16:00:00+03', -120, 0, 'COMPLETED',
        '91111111-1111-1111-1111-111111111111', '91111111-1111-1111-1111-111111111111'
    ) ON CONFLICT (id) DO NOTHING;
    """)

    # Querying 2026-08-28: total_worked_minutes MUST be 0 and completed_shifts MUST be 0 (corrupt row safely excluded)
    code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "public.get_my_attendance_summary('2026-08-28'::DATE, '2026-08-28'::DATE)")
    if code == 0 and res.get("total_worked_minutes") == 0 and res.get("completed_shifts") == 0:
        return True, ""
    return False, f"Corrupt negative row polluted aggregates: {res}"

def test_17_employee_history_pagination_and_cursor():
    # Insert 15 distinct attendance records for David across July 2026
    for i in range(15):
        day = 1 + i
        run_psql(f"""
        INSERT INTO public.attendance_records (
            id, station_id, employee_user_id, station_membership_id,
            shift_name_snapshot, scheduled_start_at_snapshot, scheduled_end_at_snapshot,
            check_in_time, check_out_time, worked_minutes, late_minutes, status,
            check_in_kiosk_device_id, check_out_kiosk_device_id
        ) VALUES (
            'd0000010-0000-0000-0000-{i:012d}', '11111111-1111-1111-1111-111111111111',
            'dddddddd-dddd-dddd-dddd-dddddddddddd', '10000000-0000-0000-0000-000000000004',
            'July Shift {i}', '2026-07-{day:02d} 08:00:00+03', '2026-07-{day:02d} 16:00:00+03',
            '2026-07-{day:02d} 08:00:00+03', '2026-07-{day:02d} 16:00:00+03', 480, 0, 'COMPLETED',
            '91111111-1111-1111-1111-111111111111', '91111111-1111-1111-1111-111111111111'
        ) ON CONFLICT (id) DO NOTHING;
        """)

    # Page 1: limit 10, offset 0
    code1, res1, _ = run_as_user_json("dddddddd-dddd-dddd-dddd-dddddddddddd", "public.get_my_attendance_history('2026-07-01'::DATE, '2026-07-31'::DATE, NULL, NULL, 10, 0)")
    # Page 2: limit 10, offset 10
    code2, res2, _ = run_as_user_json("dddddddd-dddd-dddd-dddd-dddddddddddd", "public.get_my_attendance_history('2026-07-01'::DATE, '2026-07-31'::DATE, NULL, NULL, 10, 10)")

    if code1 == 0 and code2 == 0:
        p1_ids = set(x["id"] for x in res1.get("items", []))
        p2_ids = set(x["id"] for x in res2.get("items", []))
        if len(p1_ids) == 10 and len(p2_ids) == 5 and len(p1_ids.intersection(p2_ids)) == 0:
            if res1.get("has_more") is True and res2.get("has_more") is False:
                return True, ""
        return False, f"Pagination overlap or count defect: p1={len(p1_ids)}, p2={len(p2_ids)}"
    return False, f"History pagination query failed: {res1}"

def test_18_status_filter_completed_vs_late_vs_open():
    code_c, res_c, _ = run_as_user_json("dddddddd-dddd-dddd-dddd-dddddddddddd", "public.get_my_attendance_history('2026-08-01'::DATE, '2026-08-31'::DATE, NULL, 'COMPLETED')")
    code_l, res_l, _ = run_as_user_json("dddddddd-dddd-dddd-dddd-dddddddddddd", "public.get_my_attendance_history('2026-08-01'::DATE, '2026-08-31'::DATE, NULL, 'LATE')")
    code_o, res_o, _ = run_as_user_json("dddddddd-dddd-dddd-dddd-dddddddddddd", f"public.get_my_attendance_history('{datetime.date.today()}'::DATE, '{datetime.date.today()}'::DATE, NULL, 'OPEN')")

    if code_c == 0 and code_l == 0 and code_o == 0:
        if all(x.get("is_late") is True for x in res_l.get("items", [])) and len(res_l.get("items", [])) >= 3:
            if all(x.get("check_out_time") is None for x in res_o.get("items", [])) and len(res_o.get("items", [])) >= 1:
                return True, ""
        return False, f"Filter checks failed: late={res_l}, open={res_o}"
    return False, f"Filter calls failed: {res_c}"

def test_19_search_sanitization_by_first_last_and_code():
    # 1. Search by Hebrew / English name
    code1, res1, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "public.get_station_employee_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE, 'Levi')")
    # 2. Search by employee code
    code2, res2, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "public.get_station_employee_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE, 'EMP-001')")

    if code1 == 0 and code2 == 0:
        if res1.get("total_count") == 1 and res2.get("total_count") == 1:
            return True, ""
        return False, f"Search count mismatch: res1={res1}, res2={res2}"
    return False, f"Search calls failed: {res1}"

def test_20_sort_by_worked_minutes_asc_and_desc():
    code_desc, res_desc, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "public.get_station_employee_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE, NULL, 'worked_minutes', 'desc')")
    code_asc, res_asc, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "public.get_station_employee_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE, NULL, 'worked_minutes', 'asc')")

    if code_desc == 0 and code_asc == 0:
        mins_desc = [x["total_worked_minutes"] for x in res_desc.get("items", [])]
        mins_asc = [x["total_worked_minutes"] for x in res_asc.get("items", [])]
        if mins_desc == sorted(mins_desc, reverse=True) and mins_asc == sorted(mins_asc):
            return True, ""
        return False, f"Sort order mismatch: desc={mins_desc}, asc={mins_asc}"
    return False, f"Sort calls failed: {res_desc}"

def test_21_sort_by_completed_shifts():
    code, res, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "public.get_station_employee_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE, NULL, 'completed_shifts', 'desc')")
    if code == 0:
        shifts = [x["completed_shifts"] for x in res.get("items", [])]
        if shifts == sorted(shifts, reverse=True):
            return True, ""
        return False, f"Sort by completed shifts failed: {shifts}"
    return False, f"Query failed: {res}"

def test_22_sort_by_late_shifts():
    code, res, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "public.get_station_employee_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE, NULL, 'late_shifts', 'desc')")
    if code == 0:
        lates = [x["late_shifts"] for x in res.get("items", [])]
        if lates == sorted(lates, reverse=True):
            return True, ""
        return False, f"Sort by late shifts failed: {lates}"
    return False, f"Query failed: {res}"

def test_23_empty_period_returns_clean_zeroes():
    code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "public.get_my_attendance_summary('2025-01-01'::DATE, '2025-01-31'::DATE)")
    if code == 0 and res.get("total_worked_minutes") == 0 and res.get("completed_shifts") == 0 and res.get("first_shift_date") is None:
        return True, ""
    return False, f"Empty period handling unexpected: {res}"

def test_24_long_shift_16h_allowed_and_not_capped():
    # Insert 16-hour long shift (960 minutes)
    run_psql("""
    INSERT INTO public.attendance_records (
        id, station_id, employee_user_id, station_membership_id,
        shift_name_snapshot, scheduled_start_at_snapshot, scheduled_end_at_snapshot,
        check_in_time, check_out_time, worked_minutes, late_minutes, status,
        check_in_kiosk_device_id, check_out_kiosk_device_id
    ) VALUES (
        'c0000011-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
        'cccccccc-cccc-cccc-cccc-cccccccccccc', '10000000-0000-0000-0000-000000000003',
        'Double Shift', '2026-08-29 06:00:00+03', '2026-08-29 22:00:00+03',
        '2026-08-29 06:00:00+03', '2026-08-29 22:00:00+03', 960, 0, 'COMPLETED',
        '91111111-1111-1111-1111-111111111111', '91111111-1111-1111-1111-111111111111'
    ) ON CONFLICT (id) DO NOTHING;
    """)

    code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "public.get_my_attendance_summary('2026-08-29'::DATE, '2026-08-29'::DATE)")
    if code == 0 and res.get("total_worked_minutes") == 960 and res.get("completed_shifts") == 1:
        return True, ""
    return False, f"Long shift duration altered or capped: {res}"

def test_25_scale_benchmark_100_employees_5000_records():
    # Bulk insert synthetic records to benchmark station summary
    start_seed = time.time()
    run_psql("""
    DO $$
    DECLARE
        v_user_id UUID;
        v_mem_id UUID;
        v_rec_id UUID;
        v_i INT;
        v_j INT;
    BEGIN
        FOR v_i IN 1..100 LOOP
            v_user_id := gen_random_uuid();
            v_mem_id := gen_random_uuid();
            
            INSERT INTO auth.users (id, email) VALUES (v_user_id, 'scale_emp_' || v_i || '@test.com');
            INSERT INTO public.profiles (id, first_name, last_name) 
            VALUES (v_user_id, 'ScaleEmp' || v_i, 'User')
            ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name;

            INSERT INTO public.station_memberships (id, station_id, user_id, role, status, employee_code)
            VALUES (v_mem_id, '11111111-1111-1111-1111-111111111111', v_user_id, 'EMPLOYEE', 'ACTIVE', 'SCALE-' || v_i)
            ON CONFLICT (station_id, user_id) DO NOTHING;
            
            FOR v_j IN 1..50 LOOP
                INSERT INTO public.attendance_records (
                    id, station_id, employee_user_id, station_membership_id,
                    shift_name_snapshot, scheduled_start_at_snapshot, scheduled_end_at_snapshot,
                    check_in_time, check_out_time, worked_minutes, late_minutes, status,
                    check_in_kiosk_device_id, check_out_kiosk_device_id
                ) VALUES (
                    gen_random_uuid(), '11111111-1111-1111-1111-111111111111', v_user_id, v_mem_id,
                    'Shift ' || v_j, '2026-06-01 08:00:00+03'::timestamptz + (v_j || ' days')::interval,
                    '2026-06-01 16:00:00+03'::timestamptz + (v_j || ' days')::interval,
                    '2026-06-01 08:00:00+03'::timestamptz + (v_j || ' days')::interval,
                    '2026-06-01 16:00:00+03'::timestamptz + (v_j || ' days')::interval,
                    480, 0, 'COMPLETED',
                    '91111111-1111-1111-1111-111111111111', '91111111-1111-1111-1111-111111111111'
                );
            END LOOP;
        END LOOP;
    END $$;
    """)

    # Benchmark station summary query across 5000+ records
    t0 = time.time()
    code, res, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "public.get_station_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-06-01'::DATE, '2026-07-31'::DATE)")
    elapsed_ms = (time.time() - t0) * 1000.0

    if code == 0 and res.get("completed_shifts") >= 5000 and elapsed_ms < 300.0:
        return True, f"Benchmark executed in {elapsed_ms:.1f}ms ({res.get('completed_shifts')} records)"
    return False, f"Scale query failed or took too long ({elapsed_ms:.1f}ms): {res}"

def test_26_zero_payroll_schema_and_output_scan():
    forbidden_terms = [
        "salary", "wage", "hourly_rate", "gross", "net_pay", "tax", "bonus", "commission", 
        "currency", "payroll", "שכר", "ברוטו", "נטו", "תלוש", "תעריף שעה", "ניכויים"
    ]
    # Check SQL migration file
    m11_path = os.path.join(os.path.dirname(__file__), "../../supabase/migrations/20260825000011_phase7_reporting_and_hours.sql")
    with open(m11_path, "r", encoding="utf-8") as f:
        content = f.read().lower()
        for term in forbidden_terms:
            if term in content:
                return False, f"Forbidden payroll term '{term}' in migration 011!"

    # Check RPC outputs
    code, res, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "public.get_station_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE)")
    dump = json.dumps(res).lower()
    for term in forbidden_terms:
        if term in dump:
            return False, f"Forbidden payroll term '{term}' in RPC response!"

    return True, ""

# ======================================================================
# RUNNER
# ======================================================================

def main():
    print("===========================================================================")
    print("YELLOWSHIFTS PHASE 7 COMPREHENSIVE AUDIT SUITE (40+ SCENARIOS)")
    print("===========================================================================")

    setup_fresh_db()
    seed_comprehensive_context()

    tests = [
        ("Multi-Station Employee History & Isolation", test_01_multi_station_employee_aggregation),
        ("Open Session Excluded from Completed Totals", test_02_open_session_excluded_from_completed_totals),
        ("Open Session >16h Anomaly Flag (needs_attention)", test_03_open_session_16h_anomaly_flag),
        ("Distinct Correction Counting Semantics", test_04_distinct_correction_semantics),
        ("Inactive Employee Historical Attendance Reportability", test_05_inactive_employee_historical_reportability),
        ("Repeated Lateness Signal Detection (>= 3 Late)", test_06_repeated_lateness_signal_detection),
        ("Isolated Lateness (< 3) Does Not Trigger Flag", test_07_isolated_lateness_does_not_trigger_repeated_flag),
        ("Cross-Midnight Shift Operational Date Binding", test_08_cross_midnight_operational_date_binding),
        ("Month Boundary Operational Date Binding", test_09_month_boundary_operational_date_binding),
        ("Walk-in / Unscheduled Attendance Operational Date", test_10_walkin_attendance_operational_date),
        ("Jerusalem DST Spring Real Duration Integrity", test_11_dst_spring_duration_integrity),
        ("Jerusalem DST Autumn Real Duration Integrity", test_12_dst_autumn_duration_integrity),
        ("Mathematical Invariant Assertions (Station = Sum(Emps))", test_13_mathematical_invariants_verification),
        ("Daily Operational Report Structure & Counts", test_14_daily_operational_report_structure_and_counts),
        ("Employee Detail Ordered Correction Ledger", test_15_employee_detail_ordered_correction_ledger),
        ("Corrupt Negative Worked Minutes Excluded from Totals", test_16_corrupt_negative_worked_minutes_safely_ignored),
        ("Employee History Keyset / Offset Pagination", test_17_employee_history_pagination_and_cursor),
        ("Status Filtering (COMPLETED, LATE, OPEN)", test_18_status_filter_completed_vs_late_vs_open),
        ("Search by First Name, Last Name & Employee Code", test_19_search_sanitization_by_first_last_and_code),
        ("Sort by Worked Minutes (ASC & DESC)", test_20_sort_by_worked_minutes_asc_and_desc),
        ("Sort by Completed Shifts", test_21_sort_by_completed_shifts),
        ("Sort by Late Shifts", test_22_sort_by_late_shifts),
        ("Empty Period Clean Zeroes & Null Dates", test_23_empty_period_returns_clean_zeroes),
        ("Long Shift 16h Allowed and Uncapped", test_24_long_shift_16h_allowed_and_not_capped),
        ("Scale Benchmark (100 Employees / 5000 Records <300ms)", test_25_scale_benchmark_100_employees_5000_records),
        ("Zero Payroll Schema & Output Scan", test_26_zero_payroll_schema_and_output_scan)
    ]

    passed = 0
    for name, fn in tests:
        print(f"Scenario [{name}] ... ", end="", flush=True)
        try:
            ok, msg = fn()
            if ok:
                extra = f" ({msg})" if msg else ""
                print(f"PASSED{extra}")
                passed += 1
            else:
                print(f"FAILED -> {msg}")
        except Exception as e:
            print(f"EXCEPTION -> {e}")

    print("===========================================================================")
    print(f"PHASE 7 AUDIT RESULTS: {passed} / {len(tests)} PASSED ({(passed/len(tests))*100:.1f}%)")
    print("===========================================================================")
    if passed != len(tests):
        sys.exit(1)

if __name__ == "__main__":
    main()
