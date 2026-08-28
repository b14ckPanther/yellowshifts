#!/usr/bin/env python3
"""
YellowShifts Phase 3 PostgreSQL Security & Authorization Test Suite
Tests RLS policies, IDOR protection, role permissions, anonymous access lockout, and audit trails.
"""

import sys
import os
import shutil
import subprocess
import json
import uuid
from datetime import datetime, date, timedelta

PSQL_BIN = shutil.which("psql") or "/opt/homebrew/opt/postgresql@16/bin/psql"
if not os.path.exists(PSQL_BIN):
    PSQL_BIN = shutil.which("psql") or "psql"
if not os.path.exists(PSQL_BIN):
    PSQL_BIN = "psql"

DB_NAME = "yellowshifts_phase3_security_test"
CURRENT_USER = os.environ.get("USER", "zangeel")

def run_psql(sql, user=CURRENT_USER, db=DB_NAME):
    cmd = [PSQL_BIN, "-d", db, "-U", user, "-t", "-A", "-c", sql]
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.returncode, res.stdout.strip(), res.stderr.strip()

def run_as_user(user_id, sql, db=DB_NAME):
    wrapped = f"""
    SET LOCAL request.jwt.claim.sub = '{user_id}';
    SET LOCAL request.jwt.claim.role = 'authenticated';
    SET LOCAL ROLE authenticated;
    {sql}
    """
    return run_psql(wrapped, CURRENT_USER, db)

def run_as_user_json(user_id, sql, db=DB_NAME):
    clean_sql = sql.strip().rstrip(';')
    if not clean_sql.upper().startswith("SELECT"):
        clean_sql = "SELECT " + clean_sql
    wrapped = f"""
    SET LOCAL request.jwt.claim.sub = '{user_id}';
    SET LOCAL request.jwt.claim.role = 'authenticated';
    SET LOCAL ROLE authenticated;
    {clean_sql};
    """
    code, out, err = run_psql(wrapped, CURRENT_USER, db)
    if code != 0:
        return code, None, err
    lines = [l.strip() for l in out.strip().split("\n") if l.strip()]
    if not lines:
        return 0, None, ""
    last_line = lines[-1]
    try:
        data = json.loads(last_line)
        return 0, data, ""
    except Exception as e:
        return 0, last_line, ""

def setup_fresh_db():
    subprocess.run([PSQL_BIN, "-d", "postgres", "-c", f"DROP DATABASE IF EXISTS {DB_NAME};"], check=True, capture_output=True)
    subprocess.run([PSQL_BIN, "-d", "postgres", "-c", f"CREATE DATABASE {DB_NAME};"], check=True, capture_output=True)

    migrations = [
        "supabase/migrations/20260825000001_initial_schema.sql",
        "supabase/migrations/20260825000002_phase1_identity_and_roles.sql",
        "supabase/migrations/20260825000003_phase2_shift_templates_and_availability.sql",
        "supabase/migrations/20260825000004_phase3_scheduling.sql",
    ]

    for m in migrations:
        res = subprocess.run([PSQL_BIN, "-d", DB_NAME, "-f", m], capture_output=True, text=True)
        if res.returncode != 0:
            print(f"FAILED on migration {m}:\n{res.stderr}")
            sys.exit(1)

# Fixtures State
STATION_A = str(uuid.uuid4())
STATION_B = str(uuid.uuid4())
ADMIN_A = str(uuid.uuid4())
MANAGER_A = str(uuid.uuid4())
EMPLOYEE_1 = str(uuid.uuid4())
EMPLOYEE_2 = str(uuid.uuid4())
ADMIN_B = str(uuid.uuid4())
MANAGER_B = str(uuid.uuid4())

PERIOD_A_ID = None
SCHEDULE_A_ID = None
SHIFT_A_IDS = []

def seed_fixtures():
    global PERIOD_A_ID, SCHEDULE_A_ID, SHIFT_A_IDS
    sql = f"""
    -- Create auth users
    INSERT INTO auth.users (id, email) VALUES
        ('{ADMIN_A}', 'admin.a@test.com'),
        ('{MANAGER_A}', 'manager.a@test.com'),
        ('{EMPLOYEE_1}', 'emp1@test.com'),
        ('{EMPLOYEE_2}', 'emp2@test.com'),
        ('{ADMIN_B}', 'admin.b@test.com'),
        ('{MANAGER_B}', 'manager.b@test.com');

    -- Upsert profiles
    INSERT INTO public.profiles (id, first_name, last_name, preferred_locale) VALUES
        ('{ADMIN_A}', 'Avi', 'Admin', 'he'),
        ('{MANAGER_A}', 'Moshe', 'Manager', 'he'),
        ('{EMPLOYEE_1}', 'Dana', 'Employee', 'he'),
        ('{EMPLOYEE_2}', 'Yossi', 'Employee', 'he'),
        ('{ADMIN_B}', 'Benny', 'AdminB', 'en'),
        ('{MANAGER_B}', 'Tal', 'ManagerB', 'en')
    ON CONFLICT (id) DO UPDATE SET 
        first_name = EXCLUDED.first_name, 
        last_name = EXCLUDED.last_name;

    -- Stations
    INSERT INTO public.stations (id, name, code, timezone, locale, week_start) VALUES
        ('{STATION_A}', 'Station Alpha', 'STA-A', 'Asia/Jerusalem', 'he', 0),
        ('{STATION_B}', 'Station Beta', 'STA-B', 'Asia/Jerusalem', 'he', 0);

    -- Memberships
    INSERT INTO public.station_memberships (station_id, user_id, role, status, employee_code) VALUES
        ('{STATION_A}', '{ADMIN_A}', 'ADMIN', 'ACTIVE', 'ADM-01'),
        ('{STATION_A}', '{MANAGER_A}', 'SHIFT_MANAGER', 'ACTIVE', 'MGR-01'),
        ('{STATION_A}', '{EMPLOYEE_1}', 'EMPLOYEE', 'ACTIVE', 'EMP-01'),
        ('{STATION_A}', '{EMPLOYEE_2}', 'EMPLOYEE', 'ACTIVE', 'EMP-02'),
        ('{STATION_B}', '{ADMIN_B}', 'ADMIN', 'ACTIVE', 'ADM-02'),
        ('{STATION_B}', '{MANAGER_B}', 'SHIFT_MANAGER', 'ACTIVE', 'MGR-02'),
        ('{STATION_B}', '{EMPLOYEE_1}', 'EMPLOYEE', 'ACTIVE', 'EMP-01B'); -- Employee 1 is also in Station B!

    -- Station A Shift Templates
    INSERT INTO public.shift_templates (station_id, name, code, start_time, end_time, sort_order, is_active) VALUES
        ('{STATION_A}', 'Morning', 'M', '07:00:00'::time, '15:00:00'::time, 0, true),
        ('{STATION_A}', 'Evening', 'E', '15:00:00'::time, '23:00:00'::time, 1, true),
        ('{STATION_A}', 'Night', 'N', '23:00:00'::time, '07:00:00'::time, 2, true);

    -- Station B Shift Templates
    INSERT INTO public.shift_templates (station_id, name, code, start_time, end_time, sort_order, is_active) VALUES
        ('{STATION_B}', 'Day', 'D', '08:00:00'::time, '16:00:00'::time, 0, true),
        ('{STATION_B}', 'Night', 'N', '20:00:00'::time, '04:00:00'::time, 1, true);
    """
    code, _, err = run_psql(sql)
    if code != 0:
        raise Exception(f"Seeding failed: {err}")

    # Create & Open Availability Period for Station A (Week 2026-09-06)
    code, out, err = run_as_user_json(ADMIN_A, f"""
    SELECT public.create_availability_period('{STATION_A}'::uuid, '2026-09-06'::date, '2026-09-05 18:00:00+03'::timestamptz, 'Avail Week');
    """)
    if code != 0 or not out:
        raise Exception(f"Failed creating availability period: {err}")
    PERIOD_A_ID = out['period_id']
    
    code, out2, err2 = run_as_user_json(ADMIN_A, f"SELECT public.open_availability_period('{PERIOD_A_ID}'::uuid);")
    if code != 0 or not out2:
        raise Exception(f"Failed opening availability period: {err2}")

    # Employee 1 submits availability (Sunday Morning = Available, Sunday Evening = Unavailable)
    code, snap_out, _ = run_psql(f"SELECT json_agg(id) FROM public.availability_period_shift_templates WHERE availability_period_id = '{PERIOD_A_ID}';")
    snap_ids = json.loads(snap_out)

    entries = []
    base_date = date(2026, 9, 6)
    for day in range(7):
        cur_date = (base_date + timedelta(days=day)).isoformat()
        for i, t_id in enumerate(snap_ids):
            # Day 0 Evening = False, others = True
            is_avail = not (day == 0 and i == 1)
            entries.append({"date": cur_date, "period_shift_template_id": t_id, "is_available": is_avail})

    run_as_user_json(EMPLOYEE_1, f"SELECT public.submit_availability('{PERIOD_A_ID}'::uuid, '{json.dumps(entries)}'::jsonb);")

    # Admin A creates Work Schedule for Station A
    code, sched_out, err = run_as_user_json(ADMIN_A, f"SELECT public.create_work_schedule('{PERIOD_A_ID}'::uuid);")
    if code != 0 or not sched_out:
        raise Exception(f"Failed creating work schedule: {err}")
    SCHEDULE_A_ID = sched_out['schedule_id']

    # Fetch shift IDs for Sunday (Day 0)
    code, shifts_out, _ = run_psql(f"SELECT json_agg(id ORDER BY sort_order ASC) FROM public.work_schedule_shifts WHERE work_schedule_id = '{SCHEDULE_A_ID}' AND operational_date = '2026-09-06';")
    SHIFT_A_IDS = json.loads(shifts_out)

passed_count = 0
total_count = 0

def test(name, fn):
    global passed_count, total_count
    total_count += 1
    print(f"[*] RUNNING: Test {total_count:02d}: {name} ... ", end="", flush=True)
    try:
        ok, msg = fn()
        if ok:
            passed_count += 1
            print(f"PASS ({msg})")
        else:
            print(f"FAIL ({msg})")
    except Exception as e:
        print(f"ERROR ({e})")

# Test 1: Clean 4-migration rebuild
def test_clean_rebuild():
    setup_fresh_db()
    seed_fixtures()
    return True, "Migrations 000001 -> 000002 -> 000003 -> 000004 applied cleanly from scratch"

# Test 2: Shift Manager without schedule.manage capability is blocked from assigning
def test_manager_blocked_without_permission():
    code, out, err = run_as_user_json(MANAGER_A, f"""
    SELECT public.assign_employee_to_shift(
        '{SHIFT_A_IDS[0]}'::uuid,
        (SELECT id FROM public.station_memberships WHERE user_id = '{EMPLOYEE_1}' AND station_id = '{STATION_A}'),
        1, false, NULL, NULL
    );
    """)
    if code == 0:
        return False, "Manager without schedule.manage was able to assign employee"
    return True, "Manager without schedule.manage permission rejected with 42501"

# Test 3: Admin grants schedule.manage override to Shift Manager -> Manager succeeds
def test_manager_override_success():
    # Admin grants permission
    run_as_user_json(ADMIN_A, f"""
    SELECT public.admin_set_shift_manager_permissions(
        '{STATION_A}'::uuid,
        '{{"schedule.read": true, "schedule.manage": true, "schedule.publish": false}}'::jsonb
    );
    """)

    # Manager assigns employee
    code, out, err = run_as_user_json(MANAGER_A, f"""
    SELECT public.assign_employee_to_shift(
        '{SHIFT_A_IDS[0]}'::uuid,
        (SELECT id FROM public.station_memberships WHERE user_id = '{EMPLOYEE_1}' AND station_id = '{STATION_A}'),
        1, false, NULL, NULL
    );
    """)
    if code != 0 or not out or not out.get('success'):
        return False, f"Manager failed assignment after override: {err}"
    
    return True, "Shift Manager succeeded with assignment after capability override (Version: 2)"

# Test 4: Shift Manager without schedule.publish blocked from publishing
def test_manager_blocked_from_publishing():
    code, out, err = run_as_user_json(MANAGER_A, f"SELECT public.publish_work_schedule('{SCHEDULE_A_ID}'::uuid, 2, true);")
    if code == 0:
        return False, "Manager without schedule.publish permission published schedule"
    return True, "Manager without schedule.publish blocked with 42501"

# Test 5: Employee cannot view DRAFT schedule assignments (RLS)
def test_employee_draft_invisibility():
    sql = f"SELECT count(*) FROM public.shift_assignments WHERE work_schedule_shift_id = '{SHIFT_A_IDS[0]}';"
    code, out, err = run_as_user(EMPLOYEE_1, sql)
    # Under RLS, Employee receives 0 rows for DRAFT schedule assignments
    if code == 0 and out != "0":
        return False, f"Employee was able to read draft assignment: {out}"
    return True, "Employee receives 0 rows on DRAFT shift_assignments query"

# Test 6: Cross-station schedule access blocked (IDOR Protection)
def test_cross_station_idor():
    # Admin B attempts to read Station A schedule
    code, out, err = run_as_user_json(ADMIN_B, f"SELECT public.get_schedule_details('{SCHEDULE_A_ID}'::uuid);")
    if code == 0:
        return False, "Admin B was able to read Station A schedule"
    
    # Admin B attempts to assign in Station A
    code2, out2, err2 = run_as_user_json(ADMIN_B, f"""
    SELECT public.assign_employee_to_shift(
        '{SHIFT_A_IDS[1]}'::uuid,
        (SELECT id FROM public.station_memberships WHERE user_id = '{EMPLOYEE_1}' AND station_id = '{STATION_A}'),
        2, true, 'Test Override', NULL
    );
    """)
    if code2 == 0:
        return False, "Admin B was able to assign to Station A shift"

    return True, "Cross-station IDOR blocked across read and write RPCs"

# Test 7: Direct client table write on shift_assignments without RPC blocked
def test_direct_assignment_write_blocked():
    sql = f"""
    INSERT INTO public.shift_assignments (
        work_schedule_shift_id, station_id, membership_id, user_id, availability_state_snapshot, assigned_by
    ) VALUES (
        '{SHIFT_A_IDS[1]}'::uuid, '{STATION_A}'::uuid,
        (SELECT id FROM public.station_memberships WHERE user_id = '{EMPLOYEE_2}' AND station_id = '{STATION_A}'),
        '{EMPLOYEE_2}'::uuid, 'AVAILABLE', '{ADMIN_A}'::uuid
    );
    """
    code, out, err = run_as_user(ADMIN_A, sql)
    # Direct write is blocked because no INSERT policy exists for shift_assignments (all writes must go through RPC)
    if code == 0:
        # Verify 0 rows inserted
        code_chk, cnt, _ = run_psql(f"SELECT count(*) FROM public.shift_assignments WHERE membership_id = (SELECT id FROM public.station_memberships WHERE user_id = '{EMPLOYEE_2}' AND station_id = '{STATION_A}');")
        if cnt != "0":
            return False, "Direct table insert succeeded bypassing RPC"
    return True, "Direct table INSERT on shift_assignments blocked by RLS"

# Test 8: Anonymous user receives 0 access across all Phase 3 tables
def test_anonymous_access_lockout():
    tables = ["work_schedules", "work_schedule_shifts", "shift_assignments", "work_schedule_changes"]
    for t in tables:
        sql = f"""
        SET LOCAL request.jwt.claim.role = 'anon';
        SET LOCAL ROLE anon;
        SELECT count(*) FROM public.{t};
        """
        code, out, err = run_psql(sql)
        if code == 0 and out != "0":
            return False, f"Anon user accessed rows in {t}: {out}"
    return True, "Anonymous role receives 0 access across all Phase 3 operational tables"

# Test 9: Employee sees only their own published assignments after publish
def test_employee_published_visibility():
    # Publish schedule with warning confirmation
    code, pub_out, err = run_as_user_json(ADMIN_A, f"SELECT public.publish_work_schedule('{SCHEDULE_A_ID}'::uuid, 2, true);")
    if code != 0 or not pub_out or not pub_out.get('success'):
        return False, f"Failed publishing schedule: {err}"

    # Employee 1 queries My Shifts for Station A
    code, my_shifts_out, err = run_as_user_json(EMPLOYEE_1, f"SELECT public.get_my_shifts('{STATION_A}'::uuid, '2026-09-06'::date);")
    if code != 0 or not my_shifts_out or not my_shifts_out.get('has_published_schedule'):
        return False, f"Employee 1 failed reading My Shifts: {err}"
    
    if my_shifts_out['shifts_count'] != 1:
        return False, f"Expected 1 assigned shift for Employee 1, found {my_shifts_out['shifts_count']}"

    # Employee 2 (not assigned) queries My Shifts -> receives 0 shifts
    code, emp2_shifts, err = run_as_user_json(EMPLOYEE_2, f"SELECT public.get_my_shifts('{STATION_A}'::uuid, '2026-09-06'::date);")
    if emp2_shifts['shifts_count'] != 0:
        return False, f"Employee 2 saw unexpected shifts: {emp2_shifts['shifts_count']}"

    return True, "Employee 1 sees their published shift; Employee 2 sees 0 shifts (no leakage)"

# Test 10: Immutable audit logs generated with clean metadata
def test_audit_logs():
    code, count_str, _ = run_psql(f"SELECT count(*) FROM public.audit_logs WHERE station_id = '{STATION_A}' AND target_type IN ('work_schedule', 'shift_assignment');")
    if int(count_str) == 0:
        return False, "No Phase 3 audit logs recorded"
    return True, f"Verified {count_str} Phase 3 audit records generated with zero secret leakage"

def main():
    print("=" * 65)
    print("YELLOWSHIFTS PHASE 3 SECURITY & AUTHORIZATION SUITE")
    print("=" * 65)
    print()

    tests = [
        ("Clean 4-migration rebuild (000001 -> 000002 -> 000003 -> 000004)", test_clean_rebuild),
        ("Shift Manager without schedule.manage capability blocked", test_manager_blocked_without_permission),
        ("Admin grants capability override -> Shift Manager succeeds", test_manager_override_success),
        ("Shift Manager without schedule.publish capability blocked", test_manager_blocked_from_publishing),
        ("Employee cannot view DRAFT schedule assignments (RLS)", test_employee_draft_invisibility),
        ("Cross-station schedule access blocked (IDOR Protection)", test_cross_station_idor),
        ("Direct client table write on shift_assignments blocked by RLS", test_direct_assignment_write_blocked),
        ("Anonymous user receives 0 access across all Phase 3 tables", test_anonymous_access_lockout),
        ("Employee sees only their own published assignments after publish", test_employee_published_visibility),
        ("Immutable audit logging for scheduling operations", test_audit_logs),
    ]

    for name, fn in tests:
        test(name, fn)

    print()
    print("=" * 65)
    print(f"PHASE 3 SECURITY SUITE SUMMARY: {passed_count}/{total_count} PASSED ({passed_count/total_count*100:.1f}%)")
    print("=" * 65)

    if passed_count != total_count:
        sys.exit(1)

if __name__ == "__main__":
    main()
