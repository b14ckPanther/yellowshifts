#!/usr/bin/env python3
"""
YellowShifts Phase 7 — Security & Authorization Test Suite
Validates RLS enforcement, role boundaries, tenant isolation, search/sort sanitization,
date boundary guards, read-only guarantees, and zero payroll / secret leakage.
"""

import os
import shutil
import sys
import json
import subprocess
import uuid
import datetime

DB_NAME = "yellowshifts_phase7_security"
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

def run_as_anon_json(sql: str, db: str = DB_NAME) -> tuple[int, any, str]:
    clean_sql = sql.strip().rstrip(';')
    if not clean_sql.upper().startswith("SELECT"):
        clean_sql = "SELECT " + clean_sql
    wrapped = f"""
    SET LOCAL request.jwt.claim.sub = '';
    SET LOCAL request.jwt.claim.role = 'anon';
    SET LOCAL ROLE anon;
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

def setup_test_db():
    print(f"[*] Rebuilding isolated test database: {DB_NAME}")
    subprocess.run([PSQL_BIN, "-d", "postgres", "-U", CURRENT_USER, "-c", f"DROP DATABASE IF EXISTS {DB_NAME};"], capture_output=True)
    res = subprocess.run([PSQL_BIN, "-d", "postgres", "-U", CURRENT_USER, "-c", f"CREATE DATABASE {DB_NAME};"], capture_output=True, text=True)
    if res.returncode != 0:
        print(f"[-] Database creation failed: {res.stderr}")
        sys.exit(1)

    migrations_dir = os.path.join(os.path.dirname(__file__), "../../supabase/migrations")
    files = sorted([f for f in os.listdir(migrations_dir) if f.endswith(".sql") and f <= "20260825000012_phase7_audit_remediation.sql"])
    for mf in files:
        fpath = os.path.join(migrations_dir, mf)
        mres = subprocess.run([PSQL_BIN, "-d", DB_NAME, "-U", CURRENT_USER, "-f", fpath], capture_output=True, text=True)
        if mres.returncode != 0:
            print(f"[-] Failed applying {mf}: {mres.stderr}")
            sys.exit(1)
    print(f"[*] All {len(files)} migrations (001 through 011) applied cleanly.")

def seed_security_context():
    sql = """
    -- Stations
    INSERT INTO public.stations (id, name, code, timezone, locale, week_start, is_active, check_in_early_minutes, late_grace_minutes)
    VALUES 
    ('11111111-1111-1111-1111-111111111111', 'Station North', 'STA-N', 'Asia/Jerusalem', 'he', 0, true, 15, 5),
    ('22222222-2222-2222-2222-222222222222', 'Station South', 'STA-S', 'Asia/Jerusalem', 'he', 0, true, 15, 5)
    ON CONFLICT (id) DO NOTHING;

    -- Users
    INSERT INTO auth.users (id, email) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'admin_north@test.com'),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'mgr_north@test.com'),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'emp_charlie@test.com'),
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'emp_david@test.com'),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'admin_south@test.com'),
    ('ffffffff-ffff-ffff-ffff-ffffffffffff', 'inactive_mgr@test.com')
    ON CONFLICT (id) DO NOTHING;

    -- Profiles
    INSERT INTO public.profiles (id, first_name, last_name, preferred_locale) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Alice', 'Admin', 'he'),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Bob', 'Manager', 'he'),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Charlie', 'Worker', 'he'),
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'David', 'Worker', 'he'),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'Eve', 'AdminSouth', 'he'),
    ('ffffffff-ffff-ffff-ffff-ffffffffffff', 'Frank', 'InactiveMgr', 'he')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name;

    -- Station Memberships
    INSERT INTO public.station_memberships (id, station_id, user_id, role, status, employee_code) VALUES
    ('10000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'ADMIN', 'ACTIVE', 'EMP-ADM-N'),
    ('10000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'SHIFT_MANAGER', 'ACTIVE', 'EMP-MGR-N'),
    ('10000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'EMPLOYEE', 'ACTIVE', 'EMP-001'),
    ('10000000-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'EMPLOYEE', 'ACTIVE', 'EMP-002'),
    ('20000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'ADMIN', 'ACTIVE', 'EMP-ADM-S'),
    ('10000000-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'SHIFT_MANAGER', 'INACTIVE', 'EMP-MGR-INACT')
    ON CONFLICT (station_id, user_id) DO NOTHING;

    -- Kiosk Devices
    INSERT INTO public.kiosk_devices (id, station_id, device_identifier, name, secret_hash, is_active, created_by)
    VALUES 
    ('91111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'KIOSK-N-01', 'North Kiosk', 'dummy_hash', true, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
    ('92222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222', 'KIOSK-S-01', 'South Kiosk', 'dummy_hash', true, 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee')
    ON CONFLICT (id) DO NOTHING;

    -- Seed completed attendance record for Charlie at Station North
    INSERT INTO public.attendance_records (
        id, station_id, employee_user_id, station_membership_id,
        shift_name_snapshot, scheduled_start_at_snapshot, scheduled_end_at_snapshot,
        check_in_time, check_out_time, worked_minutes, late_minutes, status,
        check_in_kiosk_device_id, check_out_kiosk_device_id
    ) VALUES (
        'a0000001-1111-1111-1111-111111111111',
        '11111111-1111-1111-1111-111111111111',
        'cccccccc-cccc-cccc-cccc-cccccccccccc',
        '10000000-0000-0000-0000-000000000003',
        'Morning Shift',
        '2026-08-20 08:00:00+03',
        '2026-08-20 16:00:00+03',
        '2026-08-20 08:05:00+03',
        '2026-08-20 16:05:00+03',
        480, 0, 'COMPLETED',
        '91111111-1111-1111-1111-111111111111',
        '91111111-1111-1111-1111-111111111111'
    ) ON CONFLICT (id) DO NOTHING;
    """
    run_psql(sql)

# ======================================================================
# SCENARIOS
# ======================================================================

def test_01_schema_and_indexes():
    code, out, _ = run_psql("""
    SELECT indexname FROM pg_indexes 
    WHERE tablename = 'attendance_records' AND indexname LIKE '%sched_start%';
    """)
    if code == 0 and "idx_attendance_records_station_sched_start" in out:
        return True, ""
    return False, f"Missing scheduled_start index: {out}"

def test_02_anon_access_denied():
    rpc_calls = [
        "public.get_my_attendance_summary('2026-08-01'::DATE, '2026-08-31'::DATE)",
        "public.get_my_attendance_history('2026-08-01'::DATE, '2026-08-31'::DATE)",
        "public.get_station_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE)",
        "public.get_station_employee_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE)",
        "public.get_station_daily_attendance_report('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-20'::DATE)",
        "public.get_station_employee_attendance_detail('11111111-1111-1111-1111-111111111111'::UUID, 'cccccccc-cccc-cccc-cccc-cccccccccccc'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE)"
    ]
    for rpc in rpc_calls:
        code, _, err = run_as_anon_json(rpc)
        if code == 0:
            return False, f"Anon was permitted to call {rpc}"
        if "42501" not in err and "permission denied" not in err.lower() and "authentication required" not in err.lower():
            return False, f"Unexpected error for anon on {rpc}: {err}"
    return True, ""

def test_03_employee_self_summary_allowed():
    code, res, err = run_as_user_json(
        "cccccccc-cccc-cccc-cccc-cccccccccccc",
        "public.get_my_attendance_summary('2026-08-01'::DATE, '2026-08-31'::DATE)"
    )
    if code == 0 and res.get("success") is True and res.get("total_worked_minutes") == 480:
        return True, ""
    return False, f"Employee self summary failed: code={code}, err={err}, res={res}"

def test_04_employee_station_summary_denied():
    code, _, err = run_as_user_json(
        "cccccccc-cccc-cccc-cccc-cccccccccccc",
        "public.get_station_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE)"
    )
    if code != 0 and ("42501" in err or "access denied" in err.lower()):
        return True, ""
    return False, f"Employee was allowed to query station summary! code={code}, err={err}"

def test_05_employee_employee_breakdown_denied():
    code, _, err = run_as_user_json(
        "cccccccc-cccc-cccc-cccc-cccccccccccc",
        "public.get_station_employee_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE)"
    )
    if code != 0 and ("42501" in err or "access denied" in err.lower()):
        return True, ""
    return False, f"Employee was allowed to query employee breakdown! code={code}, err={err}"

def test_06_employee_daily_report_denied():
    code, _, err = run_as_user_json(
        "cccccccc-cccc-cccc-cccc-cccccccccccc",
        "public.get_station_daily_attendance_report('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-20'::DATE)"
    )
    if code != 0 and ("42501" in err or "access denied" in err.lower()):
        return True, ""
    return False, f"Employee was allowed to query daily report! code={code}, err={err}"

def test_07_employee_cross_user_drilldown_denied():
    code, _, err = run_as_user_json(
        "cccccccc-cccc-cccc-cccc-cccccccccccc",
        "public.get_station_employee_attendance_detail('11111111-1111-1111-1111-111111111111'::UUID, 'dddddddd-dddd-dddd-dddd-dddddddddddd'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE)"
    )
    if code != 0 and ("42501" in err or "access denied" in err.lower()):
        return True, ""
    return False, f"Employee Charlie was allowed to drill down on David! code={code}, err={err}"

def test_08_employee_own_drilldown_allowed():
    code, res, err = run_as_user_json(
        "cccccccc-cccc-cccc-cccc-cccccccccccc",
        "public.get_station_employee_attendance_detail('11111111-1111-1111-1111-111111111111'::UUID, 'cccccccc-cccc-cccc-cccc-cccccccccccc'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE)"
    )
    if code == 0 and res.get("success") is True and len(res.get("records", [])) >= 1:
        return True, ""
    return False, f"Employee own drilldown failed: code={code}, err={err}, res={res}"

def test_09_shift_manager_station_summary_allowed():
    code, res, err = run_as_user_json(
        "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
        "public.get_station_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE)"
    )
    if code == 0 and res.get("success") is True and res.get("total_worked_minutes") == 480:
        return True, ""
    return False, f"Shift manager station summary failed: code={code}, err={err}, res={res}"

def test_10_shift_manager_cross_station_summary_denied():
    code, _, err = run_as_user_json(
        "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
        "public.get_station_attendance_summary('22222222-2222-2222-2222-222222222222'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE)"
    )
    if code != 0 and ("42501" in err or "access denied" in err.lower()):
        return True, ""
    return False, f"Manager North accessed Station South summary! code={code}, err={err}"

def test_11_shift_manager_cross_station_drilldown_denied():
    code, _, err = run_as_user_json(
        "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
        "public.get_station_employee_attendance_detail('22222222-2222-2222-2222-222222222222'::UUID, 'cccccccc-cccc-cccc-cccc-cccccccccccc'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE)"
    )
    if code != 0 and ("42501" in err or "access denied" in err.lower()):
        return True, ""
    return False, f"Manager North drilled down on Station South! code={code}, err={err}"

def test_12_admin_own_station_allowed():
    code, res, err = run_as_user_json(
        "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        "public.get_station_employee_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE)"
    )
    if code == 0 and res.get("success") is True and len(res.get("items", [])) >= 1:
        return True, ""
    return False, f"Admin own station query failed: code={code}, err={err}, res={res}"

def test_13_admin_cross_station_denied():
    code, _, err = run_as_user_json(
        "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        "public.get_station_employee_attendance_summary('22222222-2222-2222-2222-222222222222'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE)"
    )
    if code != 0 and ("42501" in err or "access denied" in err.lower()):
        return True, ""
    return False, f"Admin North accessed Station South! code={code}, err={err}"

def test_14_inactive_manager_denied():
    code, _, err = run_as_user_json(
        "ffffffff-ffff-ffff-ffff-ffffffffffff",
        "public.get_station_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-01'::DATE, '2026-08-31'::DATE)"
    )
    if code != 0 and ("42501" in err or "access denied" in err.lower()):
        return True, ""
    return False, f"Inactive manager was granted access! code={code}, err={err}"

def test_15_invalid_date_range_rejections():
    # 1. from > to
    code1, _, err1 = run_as_user_json(
        "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        "public.get_station_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-31'::DATE, '2026-08-01'::DATE)"
    )
    if code1 == 0 or ("Start date cannot be after end date" not in err1 and "22000" not in err1):
        return False, f"from > to was not rejected: {err1}"

    # 2. range > 366 days
    code2, _, err2 = run_as_user_json(
        "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        "public.get_station_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2024-01-01'::DATE, '2026-08-01'::DATE)"
    )
    if code2 == 0 or ("Date range cannot exceed 366 days" not in err2 and "22000" not in err2):
        return False, f"overlong range > 366 days was not rejected: {err2}"

    return True, ""

def test_16_sql_wildcard_injection_sanitization():
    # Search with wildcards and quotes
    code, res, err = run_as_user_json(
        "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        "public.get_station_employee_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-01', '2026-08-31', '%_''\"--')"
    )
    if code == 0 and res.get("success") is True:
        return True, ""
    return False, f"Search injection caused error: code={code}, err={err}, res={res}"

def test_17_sort_whitelist_safety():
    # Attempt SQL injection through sort_by parameter
    code, res, err = run_as_user_json(
        "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        "public.get_station_employee_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-01', '2026-08-31', NULL, 'name; DROP TABLE public.stations;--', 'desc')"
    )
    if code == 0 and res.get("success") is True:
        # Verify table still exists
        code2, out2, _ = run_psql("SELECT count(*) FROM public.stations;")
        if code2 == 0 and int(out2.strip()) >= 2:
            return True, ""
    return False, f"Sort injection attack had unexpected behavior: {err}"

def test_18_pagination_clamping():
    code, res, _ = run_as_user_json(
        "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        "public.get_station_employee_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-01', '2026-08-31', NULL, 'name', 'asc', 500, -10)"
    )
    if code == 0 and res.get("limit") == 50 and res.get("offset") == 0:
        return True, ""
    return False, f"Pagination limit clamping failed: {res}"

def test_19_read_only_guarantee():
    # Count rows in key tables before and after calling all reporting RPCs
    before_counts, _, _ = run_psql("""
    SELECT 
        (SELECT count(*) FROM public.attendance_records) || '|' ||
        (SELECT count(*) FROM public.attendance_corrections) || '|' ||
        (SELECT count(*) FROM public.notification_events) || '|' ||
        (SELECT count(*) FROM public.audit_logs);
    """)

    # Execute all 6 RPCs
    run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "public.get_my_attendance_summary('2026-08-01', '2026-08-31')")
    run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "public.get_my_attendance_history('2026-08-01', '2026-08-31')")
    run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "public.get_station_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-01', '2026-08-31')")
    run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "public.get_station_employee_attendance_summary('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-01', '2026-08-31')")
    run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "public.get_station_daily_attendance_report('11111111-1111-1111-1111-111111111111'::UUID, '2026-08-20')")
    run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "public.get_station_employee_attendance_detail('11111111-1111-1111-1111-111111111111'::UUID, 'cccccccc-cccc-cccc-cccc-cccccccccccc'::UUID, '2026-08-01', '2026-08-31')")

    after_counts, _, _ = run_psql("""
    SELECT 
        (SELECT count(*) FROM public.attendance_records) || '|' ||
        (SELECT count(*) FROM public.attendance_corrections) || '|' ||
        (SELECT count(*) FROM public.notification_events) || '|' ||
        (SELECT count(*) FROM public.audit_logs);
    """)

    if before_counts == after_counts:
        return True, ""
    return False, f"Reporting mutated database state! before={before_counts}, after={after_counts}"

def test_20_zero_payroll_and_secret_absence():
    code, res, _ = run_as_user_json(
        "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        "public.get_station_employee_attendance_detail('11111111-1111-1111-1111-111111111111'::UUID, 'cccccccc-cccc-cccc-cccc-cccccccccccc'::UUID, '2026-08-01', '2026-08-31')"
    )
    if code != 0:
        return False, f"Detail call failed: {res}"
    
    dump = json.dumps(res).lower()
    forbidden_terms = [
        "salary", "wage", "hourly_rate", "gross", "net_pay", "tax", "bonus", "commission", 
        "currency", "$", "€", "₪", "שכר", "תלוש", "תעריף",
        "secret_hash", "provider_subject_id", "device_token", "encrypted_device_token"
    ]
    for term in forbidden_terms:
        if term in dump:
            return False, f"Forbidden term '{term}' found in reporting payload!"
    return True, ""

# ======================================================================
# RUNNER
# ======================================================================

def main():
    print("===========================================================================")
    print("YELLOWSHIFTS PHASE 7 SECURITY & AUTHORIZATION TEST SUITE")
    print("===========================================================================")

    setup_test_db()
    seed_security_context()

    tests = [
        ("Phase 7 Migration Schema & Index Optimization", test_01_schema_and_indexes),
        ("Anonymous Access Denied Across All 6 RPCs (42501)", test_02_anon_access_denied),
        ("Employee Self Summary Query Allowed", test_03_employee_self_summary_allowed),
        ("Employee Station Summary Query Denied (42501)", test_04_employee_station_summary_denied),
        ("Employee Station Employee Breakdown Denied (42501)", test_05_employee_employee_breakdown_denied),
        ("Employee Station Daily Report Denied (42501)", test_06_employee_daily_report_denied),
        ("Employee Cross-User Drilldown Denied (42501)", test_07_employee_cross_user_drilldown_denied),
        ("Employee Own Drilldown Detail Allowed", test_08_employee_own_drilldown_allowed),
        ("Shift Manager Station Summary Allowed", test_09_shift_manager_station_summary_allowed),
        ("Shift Manager Cross-Station Summary Denied (42501)", test_10_shift_manager_cross_station_summary_denied),
        ("Shift Manager Cross-Station Employee Drilldown Denied", test_11_shift_manager_cross_station_drilldown_denied),
        ("Station Admin Authorized for Own Station Reports", test_12_admin_own_station_allowed),
        ("Station Admin Cross-Station Access Denied (Tenant Isolation)", test_13_admin_cross_station_denied),
        ("Inactive Manager Authorization Revoked (42501)", test_14_inactive_manager_denied),
        ("Invalid Date Range Rejection (from > to, >366 days / 22000)", test_15_invalid_date_range_rejections),
        ("Search String SQL & Wildcard Injection Sanitization", test_16_sql_wildcard_injection_sanitization),
        ("Sort Key Whitelist Safety (Drop Injection Neutralized)", test_17_sort_whitelist_safety),
        ("Pagination Bounds & Limit Clamping (1..50)", test_18_pagination_clamping),
        ("Strict Read-Only Guarantee (Zero Domain Row Mutation)", test_19_read_only_guarantee),
        ("Zero Payroll Fields & Zero Secret Leakage Scan", test_20_zero_payroll_and_secret_absence)
    ]

    passed = 0
    for name, fn in tests:
        print(f"Scenario [{name}] ... ", end="", flush=True)
        try:
            ok, err = fn()
            if ok:
                print("PASSED")
                passed += 1
            else:
                print(f"FAILED -> {err}")
        except Exception as e:
            print(f"EXCEPTION -> {e}")

    print("===========================================================================")
    print(f"PHASE 7 SECURITY RESULTS: {passed} / {len(tests)} PASSED ({(passed/len(tests))*100:.1f}%)")
    print("===========================================================================")
    if passed != len(tests):
        sys.exit(1)

if __name__ == "__main__":
    main()
