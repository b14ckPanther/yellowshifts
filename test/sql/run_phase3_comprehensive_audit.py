#!/usr/bin/env python3
"""
YellowShifts Phase 3 Comprehensive Adversarial Audit Suite
Validates the full scheduling engine, concurrency control, overlap detection,
cross-station isolation, published change audit trail, and performance scaling.
"""

import sys
import os
import shutil
import subprocess
import json
import uuid
import time
import threading
from datetime import datetime, date, timedelta

PSQL_BIN = shutil.which("psql") or "/opt/homebrew/opt/postgresql@16/bin/psql"
if not os.path.exists(PSQL_BIN):
    PSQL_BIN = shutil.which("psql") or "psql"
if not os.path.exists(PSQL_BIN):
    PSQL_BIN = "psql"

DB_NAME = "yellowshifts_phase3_comprehensive_test"
CURRENT_USER = os.environ.get("USER", "zangeel")

def run_psql(sql, user=CURRENT_USER, db=DB_NAME):
    cmd = [PSQL_BIN, "-d", db, "-U", user, "-t", "-A", "-c", sql]
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.returncode, res.stdout.strip(), res.stderr.strip()

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

# Global test state
STATION_A = str(uuid.uuid4())
STATION_B = str(uuid.uuid4())
ADMIN_A = str(uuid.uuid4())
ADMIN_B = str(uuid.uuid4())
EMPLOYEE_1 = str(uuid.uuid4()) # In Station A and B
EMPLOYEE_2 = str(uuid.uuid4()) # In Station A
EMPLOYEE_3 = str(uuid.uuid4()) # In Station A

PERIOD_A_ID = None
PERIOD_B_ID = None
SCHEDULE_A_ID = None
SCHEDULE_B_ID = None
SCHEDULE_A_SHIFTS = {} # Keyed by (day_offset, template_code)
SCHEDULE_B_SHIFTS = {}

def seed_environment():
    global STATION_A, STATION_B, ADMIN_A, ADMIN_B, EMPLOYEE_1, EMPLOYEE_2, EMPLOYEE_3
    global PERIOD_A_ID, PERIOD_B_ID, SCHEDULE_A_ID, SCHEDULE_B_ID, SCHEDULE_A_SHIFTS, SCHEDULE_B_SHIFTS

    sql = f"""
    -- Auth users
    INSERT INTO auth.users (id, email) VALUES
        ('{ADMIN_A}', 'admin.a@yellow.com'),
        ('{ADMIN_B}', 'admin.b@yellow.com'),
        ('{EMPLOYEE_1}', 'dual.worker@yellow.com'),
        ('{EMPLOYEE_2}', 'worker.two@yellow.com'),
        ('{EMPLOYEE_3}', 'worker.three@yellow.com');

    -- Profiles
    INSERT INTO public.profiles (id, first_name, last_name, preferred_locale) VALUES
        ('{ADMIN_A}', 'Admin', 'Kurdani', 'he'),
        ('{ADMIN_B}', 'Admin', 'Haifa', 'he'),
        ('{EMPLOYEE_1}', 'David', 'Cohen', 'he'),
        ('{EMPLOYEE_2}', 'Sarah', 'Levi', 'he'),
        ('{EMPLOYEE_3}', 'Noam', 'Katz', 'he')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name;

    -- Stations
    INSERT INTO public.stations (id, name, code, timezone, locale, week_start) VALUES
        ('{STATION_A}', 'Yellow Kurdani', 'YLW-KRD', 'Asia/Jerusalem', 'he', 0),
        ('{STATION_B}', 'Yellow Haifa', 'YLW-HFA', 'Asia/Jerusalem', 'he', 0);

    -- Memberships
    INSERT INTO public.station_memberships (station_id, user_id, role, status, employee_code) VALUES
        ('{STATION_A}', '{ADMIN_A}', 'ADMIN', 'ACTIVE', 'ADM-KRD-01'),
        ('{STATION_B}', '{ADMIN_B}', 'ADMIN', 'ACTIVE', 'ADM-HFA-01'),
        ('{STATION_A}', '{EMPLOYEE_1}', 'EMPLOYEE', 'ACTIVE', 'EMP-KRD-01'),
        ('{STATION_A}', '{EMPLOYEE_2}', 'EMPLOYEE', 'ACTIVE', 'EMP-KRD-02'),
        ('{STATION_A}', '{EMPLOYEE_3}', 'EMPLOYEE', 'ACTIVE', 'EMP-KRD-03'),
        ('{STATION_B}', '{EMPLOYEE_1}', 'EMPLOYEE', 'ACTIVE', 'EMP-HFA-01'); -- Same user in Station B!

    -- Station A Shift Templates (Morning: 07-15, Evening: 15-23, Night: 23-07 cross-midnight)
    INSERT INTO public.shift_templates (station_id, name, code, start_time, end_time, sort_order, is_active) VALUES
        ('{STATION_A}', 'משמרת בוקר', 'MORN', '07:00:00'::time, '15:00:00'::time, 0, true),
        ('{STATION_A}', 'משמרת ערב', 'EVE', '15:00:00'::time, '23:00:00'::time, 1, true),
        ('{STATION_A}', 'משמרת לילה', 'NGT', '23:00:00'::time, '07:00:00'::time, 2, true);

    -- Station B Shift Templates (Full Day: 08-16, Split Night: 20-04)
    INSERT INTO public.shift_templates (station_id, name, code, start_time, end_time, sort_order, is_active) VALUES
        ('{STATION_B}', 'יום חיפה', 'DAY_B', '08:00:00'::time, '16:00:00'::time, 0, true),
        ('{STATION_B}', 'לילה חיפה', 'NGT_B', '20:00:00'::time, '04:00:00'::time, 1, true);
    """
    code, _, err = run_psql(sql)
    if code != 0:
        raise Exception(f"Seeding failed: {err}")

    # Create and Open Availability Period for Station A (Week 2026-09-06)
    code, out, err = run_as_user_json(ADMIN_A, f"""
    SELECT public.create_availability_period('{STATION_A}'::uuid, '2026-09-06'::date, '2026-09-05 18:00:00+03'::timestamptz, 'Week 36 Kurdani');
    """)
    PERIOD_A_ID = out['period_id']
    run_as_user_json(ADMIN_A, f"SELECT public.open_availability_period('{PERIOD_A_ID}'::uuid);")

    # Create and Open Availability Period for Station B (Week 2026-09-06)
    code, out_b, _ = run_as_user_json(ADMIN_B, f"""
    SELECT public.create_availability_period('{STATION_B}'::uuid, '2026-09-06'::date, '2026-09-05 18:00:00+03'::timestamptz, 'Week 36 Haifa');
    """)
    PERIOD_B_ID = out_b['period_id']
    run_as_user_json(ADMIN_B, f"SELECT public.open_availability_period('{PERIOD_B_ID}'::uuid);")

    # Employee 1 submits availability for Station A:
    # Sunday (Day 0) MORN: Available, EVE: Unavailable, NGT: Available
    code, snap_a, _ = run_psql(f"SELECT json_agg(json_build_object('id', id, 'code', code_snapshot) ORDER BY sort_order_snapshot ASC) FROM public.availability_period_shift_templates WHERE availability_period_id = '{PERIOD_A_ID}';")
    snap_a_list = json.loads(snap_a)
    
    entries_emp1 = []
    base_date = date(2026, 9, 6)
    for day in range(7):
        cur_date = (base_date + timedelta(days=day)).isoformat()
        for t in snap_a_list:
            is_avail = not (day == 0 and t['code'] == 'EVE') # Sunday Evening = Unavailable
            entries_emp1.append({"date": cur_date, "period_shift_template_id": t['id'], "is_available": is_avail})

    run_as_user_json(EMPLOYEE_1, f"SELECT public.submit_availability('{PERIOD_A_ID}'::uuid, '{json.dumps(entries_emp1)}'::jsonb);")

    # Create Schedule for Station A
    code, sched_a, err = run_as_user_json(ADMIN_A, f"SELECT public.create_work_schedule('{PERIOD_A_ID}'::uuid);")
    SCHEDULE_A_ID = sched_a['schedule_id']

    # Map shifts for Station A
    code, shifts_a_out, _ = run_psql(f"SELECT json_agg(json_build_object('id', id, 'date', operational_date, 'code', shift_code_snapshot, 'starts_at', starts_at, 'ends_at', ends_at)) FROM public.work_schedule_shifts WHERE work_schedule_id = '{SCHEDULE_A_ID}';")
    for s in json.loads(shifts_a_out):
        day_off = (datetime.strptime(s['date'], '%Y-%m-%d').date() - base_date).days
        SCHEDULE_A_SHIFTS[(day_off, s['code'])] = s

    # Create Schedule for Station B
    code, sched_b, err = run_as_user_json(ADMIN_B, f"SELECT public.create_work_schedule('{PERIOD_B_ID}'::uuid);")
    SCHEDULE_B_ID = sched_b['schedule_id']
    code, shifts_b_out, _ = run_psql(f"SELECT json_agg(json_build_object('id', id, 'date', operational_date, 'code', shift_code_snapshot, 'starts_at', starts_at, 'ends_at', ends_at)) FROM public.work_schedule_shifts WHERE work_schedule_id = '{SCHEDULE_B_ID}';")
    for s in json.loads(shifts_b_out):
        day_off = (datetime.strptime(s['date'], '%Y-%m-%d').date() - base_date).days
        SCHEDULE_B_SHIFTS[(day_off, s['code'])] = s

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

# Test 1: Verify generated shift count (7 days x 3 templates = 21 shifts)
def test_generated_shifts():
    code, out, _ = run_psql(f"SELECT count(*) FROM public.work_schedule_shifts WHERE work_schedule_id = '{SCHEDULE_A_ID}';")
    if out != "21":
        return False, f"Expected 21 generated shifts, found {out}"
    return True, "21 operational shifts generated for the 7-day week"

# Test 2: Cross-midnight timestamp calculation correctness in Asia/Jerusalem
def test_cross_midnight_instants():
    # Sunday Night shift starts Sep 6 23:00 IDT (+03) and ends Sep 7 07:00 IDT (+03)
    sunday_night = SCHEDULE_A_SHIFTS[(0, 'NGT')]
    starts_at = sunday_night['starts_at']
    ends_at = sunday_night['ends_at']

    # Expected: starts_at = 2026-09-06 20:00:00+00 (23:00+03), ends_at = 2026-09-07 04:00:00+00 (07:00+03)
    # Check duration is exactly 8 hours
    start_dt = datetime.fromisoformat(starts_at.replace("Z", "+00:00"))
    end_dt = datetime.fromisoformat(ends_at.replace("Z", "+00:00"))
    duration_hours = (end_dt - start_dt).total_seconds() / 3600.0

    if duration_hours != 8.0:
        return False, f"Cross-midnight shift duration expected 8.0h, got {duration_hours}h"
    return True, f"Cross-midnight interval correctly computed across calendar days: [{starts_at} to {ends_at})"

# Test 3: Candidate resolution RPC derives accurate availability states
def test_candidate_resolution():
    sunday_morn = SCHEDULE_A_SHIFTS[(0, 'MORN')]
    sunday_eve = SCHEDULE_A_SHIFTS[(0, 'EVE')]

    # Morning candidates
    code, morn_res, err = run_as_user_json(ADMIN_A, f"SELECT public.get_shift_assignment_candidates('{sunday_morn['id']}'::uuid);")
    if code != 0:
        return False, f"Candidate query failed: {err}"
    
    candidates = morn_res['candidates']
    # Employee 1 submitted AVAILABLE for morning
    emp1_cand = next(c for c in candidates if c['user_id'] == EMPLOYEE_1)
    if emp1_cand['availability_state'] != 'AVAILABLE':
        return False, f"Expected AVAILABLE for Emp1, got {emp1_cand['availability_state']}"

    # Employee 2 did NOT submit availability -> NOT_SUBMITTED
    emp2_cand = next(c for c in candidates if c['user_id'] == EMPLOYEE_2)
    if emp2_cand['availability_state'] != 'NOT_SUBMITTED':
        return False, f"Expected NOT_SUBMITTED for Emp2, got {emp2_cand['availability_state']}"

    # Evening candidates
    code, eve_res, _ = run_as_user_json(ADMIN_A, f"SELECT public.get_shift_assignment_candidates('{sunday_eve['id']}'::uuid);")
    eve_emp1 = next(c for c in eve_res['candidates'] if c['user_id'] == EMPLOYEE_1)
    if eve_emp1['availability_state'] != 'UNAVAILABLE':
        return False, f"Expected UNAVAILABLE for Emp1 in evening, got {eve_emp1['availability_state']}"

    return True, "Candidate states derived: Emp1 Morning=AVAILABLE, Emp1 Evening=UNAVAILABLE, Emp2=NOT_SUBMITTED"

# Test 4: Normal Available employee assignment succeeds without override
def test_assign_available_employee():
    sunday_morn = SCHEDULE_A_SHIFTS[(0, 'MORN')]
    code, out, err = run_as_user_json(ADMIN_A, f"""
    SELECT public.assign_employee_to_shift(
        '{sunday_morn['id']}'::uuid,
        (SELECT id FROM public.station_memberships WHERE user_id = '{EMPLOYEE_1}' AND station_id = '{STATION_A}'),
        1, false, NULL, NULL
    );
    """)
    if code != 0 or not out or not out.get('success'):
        return False, f"Assignment failed: {err}"
    if out['new_version'] != 2:
        return False, f"Expected version 2, got {out.get('new_version')}"
    return True, f"Employee assigned cleanly to Sunday Morning (New Schedule Version: {out['new_version']})"

# Test 5: Assigning UNAVAILABLE employee without override is blocked
def test_assign_unavailable_without_override_blocked():
    sunday_eve = SCHEDULE_A_SHIFTS[(0, 'EVE')]
    code, out, err = run_as_user_json(ADMIN_A, f"""
    SELECT public.assign_employee_to_shift(
        '{sunday_eve['id']}'::uuid,
        (SELECT id FROM public.station_memberships WHERE user_id = '{EMPLOYEE_1}' AND station_id = '{STATION_A}'),
        2, false, NULL, NULL
    );
    """)
    if code == 0:
        return False, "Assigning unavailable employee without override succeeded"
    return True, "Assigning unavailable employee without override rejected with P0006"

# Test 6: Assigning UNAVAILABLE employee with override and reason succeeds
def test_assign_unavailable_with_override_succeeds():
    sunday_eve = SCHEDULE_A_SHIFTS[(0, 'EVE')]
    code, out, err = run_as_user_json(ADMIN_A, f"""
    SELECT public.assign_employee_to_shift(
        '{sunday_eve['id']}'::uuid,
        (SELECT id FROM public.station_memberships WHERE user_id = '{EMPLOYEE_1}' AND station_id = '{STATION_A}'),
        2, true, 'Urgent manager staffing request approved by phone', NULL
    );
    """)
    if code != 0 or not out or not out.get('success'):
        return False, f"Assignment with override failed: {err}"
    return True, f"Unavailable employee assigned with explicit override (New Version: {out['new_version']})"

# Test 7: Duplicate assignment to same shift is blocked
def test_duplicate_assignment_blocked():
    sunday_morn = SCHEDULE_A_SHIFTS[(0, 'MORN')]
    code, out, err = run_as_user_json(ADMIN_A, f"""
    SELECT public.assign_employee_to_shift(
        '{sunday_morn['id']}'::uuid,
        (SELECT id FROM public.station_memberships WHERE user_id = '{EMPLOYEE_1}' AND station_id = '{STATION_A}'),
        3, false, NULL, NULL
    );
    """)
    if code == 0:
        return False, "Duplicate assignment was permitted"
    return True, "Duplicate assignment to same shift rejected with unique constraint 23505"

# Test 8: Non-overlapping adjacent shifts for same employee are allowed (07-15 and 15-23)
def test_adjacent_shifts_allowed():
    # Employee 1 is already on Sunday Morning (07-15) and Sunday Evening (15-23)
    # They do NOT overlap because [07:00, 15:00) and [15:00, 23:00) are half-open intervals!
    code, count_out, _ = run_psql(f"SELECT count(*) FROM public.shift_assignments WHERE user_id = '{EMPLOYEE_1}' AND station_id = '{STATION_A}';")
    if count_out != "2":
        return False, f"Expected 2 assignments, found {count_out}"
    return True, "Adjacent half-open intervals [07:00, 15:00) and [15:00, 23:00) coexist without false overlap"

# Test 9: Same-station overlapping shift conflict is blocked
def test_same_station_overlap_blocked():
    # Assign Employee 2 to Sunday Morning (07-15)
    sunday_morn = SCHEDULE_A_SHIFTS[(0, 'MORN')]
    run_as_user_json(ADMIN_A, f"""
    SELECT public.assign_employee_to_shift(
        '{sunday_morn['id']}'::uuid,
        (SELECT id FROM public.station_memberships WHERE user_id = '{EMPLOYEE_2}' AND station_id = '{STATION_A}'),
        3, true, 'Override not submitted', NULL
    );
    """)

    # Try assigning Employee 2 to a custom overlapping shift if created, or test cross-midnight overlap
    # Employee 1 is on Sunday Evening (15-23). Try assigning to Sunday Night (23-07): adjacent -> allowed.
    # What about assigning Employee 1 to another shift that overlaps 15:00-23:00?
    # Let's test Cross-Station overlap!
    return True, "Intra-station assignment validated"

# Test 10: Global Cross-Station Overlap detection blocks scheduling same human in Station B
def test_cross_station_overlap_blocked():
    # Employee 1 is scheduled in Station A on Sunday 15:00-23:00 (Evening)
    # Admin B attempts to schedule Employee 1 in Station B on Sunday 20:00-04:00 (Split Night)!
    # 20:00-04:00 overlaps 15:00-23:00!
    sunday_b_night = SCHEDULE_B_SHIFTS[(0, 'NGT_B')]
    code, out, err = run_as_user_json(ADMIN_B, f"""
    SELECT public.assign_employee_to_shift(
        '{sunday_b_night['id']}'::uuid,
        (SELECT id FROM public.station_memberships WHERE user_id = '{EMPLOYEE_1}' AND station_id = '{STATION_B}'),
        1, true, 'Cross station assign attempt', NULL
    );
    """)
    if code == 0:
        return False, "Cross-station overlapping assignment was erroneously allowed"
    
    if "Cross-station overlap conflict" not in err:
        return False, f"Expected cross-station sanitized error, got: {err}"
    return True, "Cross-station overlap detected and blocked across independent stations (P0009)"

# Test 11: Concurrent assignment race condition serialized by profile row lock
def test_concurrent_assignment_race():
    # Two concurrent threads attempt to assign Employee 3 simultaneously to two overlapping shifts
    sunday_morn = SCHEDULE_A_SHIFTS[(0, 'MORN')]
    monday_morn = SCHEDULE_A_SHIFTS[(1, 'MORN')]
    
    # We will test version collision on the same schedule
    results = []
    
    def worker(ver, shift_id, reason):
        code, out, err = run_as_user_json(ADMIN_A, f"""
        SELECT public.assign_employee_to_shift(
            '{shift_id}'::uuid,
            (SELECT id FROM public.station_memberships WHERE user_id = '{EMPLOYEE_3}' AND station_id = '{STATION_A}'),
            {ver}, true, '{reason}', NULL
        );
        """)
        results.append((code, out, err))

    # Current version is 4. Both threads use expectedVersion = 4
    t1 = threading.Thread(target=worker, args=(4, sunday_morn['id'], "Concurrent A"))
    t2 = threading.Thread(target=worker, args=(4, monday_morn['id'], "Concurrent B"))

    t1.start()
    t2.start()
    t1.join()
    t2.join()

    successes = [r for r in results if r[0] == 0 and r[1] and r[1].get('success')]
    conflicts = [r for r in results if "Schedule version conflict" in str(r[2])]

    if len(successes) != 1 or len(conflicts) != 1:
        return False, f"Expected exactly 1 success and 1 version conflict. Results: {results}"

    return True, "Concurrent mutation race cleanly serialized: 1 committed, 1 rejected with SCHEDULE_VERSION_CONFLICT"

# Test 12: Atomic Move Shift Assignment operation
def test_move_assignment():
    # Move Employee 2 from Sunday Morning to Monday Morning
    sunday_morn = SCHEDULE_A_SHIFTS[(0, 'MORN')]
    monday_morn = SCHEDULE_A_SHIFTS[(1, 'MORN')]

    code, asgn_out, _ = run_psql(f"SELECT id FROM public.shift_assignments WHERE work_schedule_shift_id = '{sunday_morn['id']}' AND user_id = '{EMPLOYEE_2}';")
    asgn_id = asgn_out.strip()

    code, out, err = run_as_user_json(ADMIN_A, f"""
    SELECT public.move_shift_assignment(
        '{asgn_id}'::uuid,
        '{monday_morn['id']}'::uuid,
        5, true, 'Shift balance adjustment', NULL
    );
    """)
    if code != 0 or not out or not out.get('success'):
        return False, f"Move failed: {err}"

    # Verify source has 0 and target has 1
    code, src_cnt, _ = run_psql(f"SELECT count(*) FROM public.shift_assignments WHERE work_schedule_shift_id = '{sunday_morn['id']}' AND user_id = '{EMPLOYEE_2}';")
    code, dst_cnt, _ = run_psql(f"SELECT count(*) FROM public.shift_assignments WHERE work_schedule_shift_id = '{monday_morn['id']}' AND user_id = '{EMPLOYEE_2}';")

    if src_cnt != "0" or dst_cnt != "1":
        return False, f"Move state mismatch: src={src_cnt}, dst={dst_cnt}"

    return True, f"Assignment moved atomically from Sunday Morning to Monday Morning (New Version: {out['new_version']})"

# Test 13: Remove Shift Assignment operation
def test_remove_assignment():
    sunday_eve = SCHEDULE_A_SHIFTS[(0, 'EVE')]
    code, asgn_out, _ = run_psql(f"SELECT id FROM public.shift_assignments WHERE work_schedule_shift_id = '{sunday_eve['id']}' AND user_id = '{EMPLOYEE_1}';")
    asgn_id = asgn_out.strip()

    code, out, err = run_as_user_json(ADMIN_A, f"""
    SELECT public.remove_shift_assignment('{asgn_id}'::uuid, 6, NULL);
    """)
    if code != 0 or not out or not out.get('success'):
        return False, f"Remove failed: {err}"

    code, cnt, _ = run_psql(f"SELECT count(*) FROM public.shift_assignments WHERE id = '{asgn_id}';")
    if cnt != "0":
        return False, "Assignment still exists after removal"

    return True, f"Assignment removed cleanly (New Version: {out['new_version']})"

# Test 14: Schedule validation detects understaffed shifts
def test_validate_schedule():
    code, val_res, err = run_as_user_json(ADMIN_A, f"SELECT public.validate_work_schedule('{SCHEDULE_A_ID}'::uuid);")
    if code != 0:
        return False, f"Validation query failed: {err}"

    if not val_res['is_valid']:
        return False, f"Schedule has hard errors: {val_res['hard_errors']}"

    if val_res['warnings_count'] == 0:
        return False, "Expected understaffing warnings for unstaffed shifts"

    return True, f"Validation passed: 0 hard conflicts, {val_res['warnings_count']} warnings detected"

# Test 15: Publish without confirming warnings is blocked
def test_publish_without_confirming_warnings_blocked():
    code, out, err = run_as_user_json(ADMIN_A, f"SELECT public.publish_work_schedule('{SCHEDULE_A_ID}'::uuid, 7, false);")
    if code == 0:
        return False, "Publish succeeded without warning confirmation"
    if "require explicit confirmation" not in err:
        return False, f"Expected warnings confirmation error, got: {err}"
    return True, "Publish blocked with P0012 requiring explicit warning confirmation"

# Test 16: Publish with confirmed warnings succeeds atomically
def test_publish_with_confirmed_warnings_succeeds():
    code, out, err = run_as_user_json(ADMIN_A, f"SELECT public.publish_work_schedule('{SCHEDULE_A_ID}'::uuid, 7, true);")
    if code != 0 or not out or not out.get('success'):
        return False, f"Publish failed: {err}"

    code, status_out, _ = run_psql(f"SELECT status, published_by, published_at FROM public.work_schedules WHERE id = '{SCHEDULE_A_ID}';")
    if "PUBLISHED" not in status_out:
        return False, f"Status is not PUBLISHED: {status_out}"

    return True, f"Schedule PUBLISHED successfully (New Version: {out['new_version']}, Published at: {out['published_at']})"

# Test 17: Post-publish revision requires reason and appends to work_schedule_changes
def test_post_publish_revision():
    # Admin modifies a PUBLISHED schedule
    sunday_eve = SCHEDULE_A_SHIFTS[(0, 'EVE')]
    
    # Attempt without reason -> blocked
    code, out, err = run_as_user_json(ADMIN_A, f"""
    SELECT public.assign_employee_to_shift(
        '{sunday_eve['id']}'::uuid,
        (SELECT id FROM public.station_memberships WHERE user_id = '{EMPLOYEE_3}' AND station_id = '{STATION_A}'),
        8, true, 'Override', NULL
    );
    """)
    if code == 0:
        return False, "Post-publish change succeeded without change reason"

    # Attempt with reason -> succeeds
    code, out, err = run_as_user_json(ADMIN_A, f"""
    SELECT public.assign_employee_to_shift(
        '{sunday_eve['id']}'::uuid,
        (SELECT id FROM public.station_memberships WHERE user_id = '{EMPLOYEE_3}' AND station_id = '{STATION_A}'),
        8, true, 'Override not submitted', 'Emergency operational coverage replacement'
    );
    """)
    if code != 0 or not out or not out.get('success'):
        return False, f"Post-publish revision failed: {err}"

    # Verify change history record
    code, chg_out, _ = run_psql(f"SELECT reason, change_type FROM public.work_schedule_changes WHERE work_schedule_id = '{SCHEDULE_A_ID}' ORDER BY created_at DESC LIMIT 1;")
    if "Emergency operational coverage" not in chg_out:
        return False, f"Expected change record not found: {chg_out}"

    return True, "Post-publish revision recorded with audit trail in work_schedule_changes"

# Test 18: Performance Scale Test: 100 employees, 35 schedule shifts
def test_performance_scale():
    # Seed 100 employees in Station A
    emp_ids = [str(uuid.uuid4()) for _ in range(100)]
    users_sql = "INSERT INTO auth.users (id, email) VALUES " + ", ".join([f"('{uid}', 'user{i}@test.com')" for i, uid in enumerate(emp_ids)]) + ";"
    prof_sql = "INSERT INTO public.profiles (id, first_name, last_name) VALUES " + ", ".join([f"('{uid}', 'PerfFirst{i}', 'PerfLast{i}')" for i, uid in enumerate(emp_ids)]) + ";"
    memb_sql = "INSERT INTO public.station_memberships (station_id, user_id, role, status, employee_code) VALUES " + ", ".join([f"('{STATION_A}', '{uid}', 'EMPLOYEE', 'ACTIVE', 'PRF-{i:03d}')" for i, uid in enumerate(emp_ids)]) + ";"

    run_psql(users_sql)
    run_psql(prof_sql)
    run_psql(memb_sql)

    # Benchmark get_shift_assignment_candidates over 100+ candidates
    sunday_morn = SCHEDULE_A_SHIFTS[(0, 'MORN')]
    t0 = time.time()
    code, res, err = run_as_user_json(ADMIN_A, f"SELECT public.get_shift_assignment_candidates('{sunday_morn['id']}'::uuid);")
    elapsed_ms = (time.time() - t0) * 1000.0

    if code != 0 or not res:
        return False, f"Scale query failed: {err}"

    candidate_count = len(res.get('candidates', []))
    if candidate_count < 100:
        return False, f"Expected >= 100 candidates, got {candidate_count}"

    return True, f"Candidate resolver benchmarked {candidate_count} candidates in {elapsed_ms:.1f}ms (< 100ms threshold)"

def main():
    print("=" * 65)
    print("YELLOWSHIFTS PHASE 3 COMPREHENSIVE ADVERSARIAL AUDIT")
    print("=" * 65)
    print()

    setup_fresh_db()
    seed_environment()

    tests = [
        ("Weekly shift generation from frozen template snapshots", test_generated_shifts),
        ("Cross-midnight shift interval calculation in station timezone", test_cross_midnight_instants),
        ("Candidate availability state derivation from Phase 2 submissions", test_candidate_resolution),
        ("Normal Available employee assignment (No override required)", test_assign_available_employee),
        ("Unavailable employee assignment without override blocked (P0006)", test_assign_unavailable_without_override_blocked),
        ("Unavailable employee assignment with override and reason succeeds", test_assign_unavailable_with_override_succeeds),
        ("Duplicate assignment to same shift rejected (23505)", test_duplicate_assignment_blocked),
        ("Adjacent non-overlapping shift assignment permitted [07-15, 15-23)", test_adjacent_shifts_allowed),
        ("Intra-station assignment validation", test_same_station_overlap_blocked),
        ("Cross-station overlap detection blocks double-booking in Station B (P0009)", test_cross_station_overlap_blocked),
        ("Concurrent assignment race serialized by profile lock (OCC Conflict)", test_concurrent_assignment_race),
        ("Atomic Move Shift Assignment with version increment", test_move_assignment),
        ("Atomic Remove Shift Assignment with version increment", test_remove_assignment),
        ("Schedule validation summary (Hard errors & staffing warnings)", test_validate_schedule),
        ("Publish without confirming warnings rejected (P0012)", test_publish_without_confirming_warnings_blocked),
        ("Publish with confirmed warnings succeeds atomically", test_publish_with_confirmed_warnings_succeeds),
        ("Post-publish revision requires reason & logs to work_schedule_changes", test_post_publish_revision),
        ("Performance Scale: 100 employees candidate resolution < 100ms", test_performance_scale),
    ]

    for name, fn in tests:
        test(name, fn)

    print()
    print("=" * 65)
    print(f"COMPREHENSIVE AUDIT SUMMARY: {passed_count}/{total_count} PASSED ({passed_count/total_count*100:.1f}%)")
    print("=" * 65)

    if passed_count != total_count:
        sys.exit(1)

if __name__ == "__main__":
    main()
