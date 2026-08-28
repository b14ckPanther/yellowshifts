#!/usr/bin/env python3
"""
YellowShifts Phase 3 — Production-Grade Independent Adversarial Audit Suite V2
Zero-dependency PostgreSQL 16 test harness running 45 adversarial attack scenarios.
"""

import sys
import os
import shutil
import subprocess
import json
import uuid
import time
import threading
import traceback
from datetime import datetime, date, timedelta

PSQL_BIN = shutil.which("psql") or "/opt/homebrew/opt/postgresql@16/bin/psql"
if not os.path.exists(PSQL_BIN):
    PSQL_BIN = shutil.which("psql") or "psql"
if not os.path.exists(PSQL_BIN):
    PSQL_BIN = "psql"

DB_NAME = "yellowshifts_phase3_audit_v2_test"
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

    # Apply canonical migrations 001 -> 002 -> 003 -> 004
    migrations = [
        "supabase/migrations/20260825000001_initial_schema.sql",
        "supabase/migrations/20260825000002_phase1_identity_and_roles.sql",
        "supabase/migrations/20260825000003_phase2_shift_templates_and_availability.sql",
        "supabase/migrations/20260825000004_phase3_scheduling.sql"
    ]
    for mig in migrations:
        mig_path = os.path.abspath(mig)
        if not os.path.exists(mig_path):
            print(f"[!] Migration file not found: {mig_path}")
            sys.exit(1)
        res = subprocess.run([PSQL_BIN, "-d", DB_NAME, "-U", CURRENT_USER, "-f", mig_path],
                             capture_output=True, text=True)
        if res.returncode != 0:
            print(f"[!] Failed to apply {mig}:\n{res.stderr}")
            sys.exit(1)

    print("[*] All 4 canonical migrations applied successfully on fresh database.")

# Fixture Creators
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

def fixture_period_with_templates(station_id, week_start, templates, creator_id):
    p_id = str(uuid.uuid4())
    sql = f"""
    INSERT INTO public.availability_periods (id, station_id, week_start_date, status, submission_deadline, created_by)
    VALUES ('{p_id}', '{station_id}', '{week_start}', 'OPEN', '{week_start} 18:00:00+00', '{creator_id}');
    """
    for idx, (tname, tcode, start_t, end_t) in enumerate(templates):
        tmpl_id = str(uuid.uuid4())
        snap_id = str(uuid.uuid4())
        c_code = f"'{tcode}'" if tcode else "NULL"
        sql += f"""
        INSERT INTO public.shift_templates (id, station_id, name, code, start_time, end_time, sort_order)
        VALUES ('{tmpl_id}', '{station_id}', '{tname}', {c_code}, '{start_t}', '{end_t}', {idx});

        INSERT INTO public.availability_period_shift_templates 
        (id, availability_period_id, shift_template_id, name_snapshot, code_snapshot, start_time_snapshot, end_time_snapshot, sort_order_snapshot)
        VALUES ('{snap_id}', '{p_id}', '{tmpl_id}', '{tname}', {c_code}, '{start_t}', '{end_t}', {idx});
        """
    code, out, err = run_psql(sql)
    assert code == 0, f"Failed to create period: {err}"
    return p_id

class TestRunner:
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.total = 0
        self.results = []

    def run(self, name, test_func):
        self.total += 1
        print(f"[{self.total:02d}] RUNNING: {name} ... ", end="", flush=True)
        t0 = time.perf_counter()
        try:
            test_func()
            elapsed = (time.perf_counter() - t0) * 1000.0
            print(f"PASSED ({elapsed:.1f}ms)")
            self.passed += 1
            self.results.append((name, True, f"{elapsed:.1f}ms", None))
        except Exception as e:
            elapsed = (time.perf_counter() - t0) * 1000.0
            print(f"FAILED ({elapsed:.1f}ms)")
            tb = traceback.format_exc()
            print(f"     ERROR: {e}\n{tb}")
            self.failed += 1
            self.results.append((name, False, f"{elapsed:.1f}ms", f"{e}\n{tb}"))

    def summary(self):
        print("\n" + "="*70)
        print(f"PHASE 3 ADVERSARIAL AUDIT V2 RESULTS: {self.passed}/{self.total} PASSED ({(self.passed/self.total)*100:.1f}%)")
        print("="*70)
        if self.failed > 0:
            print("\nFAILED TESTS SUMMARY:")
            for name, passed, el, err in self.results:
                if not passed:
                    print(f"  - {name}")
        return self.failed == 0

runner = TestRunner()

# ====================================================================
# TEST SCENARIOS
# ====================================================================

def test_01_clean_migration_chain():
    code, out, err = run_psql("""
        SELECT table_name FROM information_schema.tables 
        WHERE table_schema = 'public' 
          AND table_name IN ('work_schedules', 'work_schedule_shifts', 'shift_assignments', 'work_schedule_changes');
    """)
    assert code == 0
    tables = [t.strip() for t in out.split("\n") if t.strip()]
    assert len(tables) == 4, f"Expected 4 tables, got {tables}"

def test_02_migration_enums():
    code, out, err = run_psql("SELECT typname FROM pg_type WHERE typname IN ('work_schedule_status', 'schedule_change_type');")
    assert code == 0
    enums = [e.strip() for e in out.split("\n") if e.strip()]
    assert len(enums) == 2, f"Expected 2 enums, got {enums}"

def test_03_arbitrary_template_generation():
    admin = fixture_user("Admin", "N")
    for n in [1, 2, 3, 5, 10]:
        sta = fixture_station(f"StationN_{n}")
        fixture_membership(sta, admin, role="ADMIN")
        templates = [(f"Shift {i}", f"S{i}", f"{(i*2)%24:02d}:00", f"{(i*2+2)%24:02d}:00") for i in range(n)]
        per = fixture_period_with_templates(sta, "2026-09-06", templates, admin)
        
        code, res, err = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
        assert code == 0, f"create_work_schedule failed: {err}"
        assert res['success'] is True
        assert res['generated_shifts_count'] == 7 * n, f"Expected {7*n} shifts, got {res['generated_shifts_count']}"

def test_04_frozen_template_snapshot_integrity():
    admin = fixture_user("Admin", "Frozen")
    sta = fixture_station("FrozenStation")
    fixture_membership(sta, admin, role="ADMIN")
    
    # 1. Create period with templates (creates live template and frozen snapshot)
    per = fixture_period_with_templates(sta, "2026-09-06", [("Original Morning", "MORN", "07:00", "15:00")], admin)
    
    # 2. Create schedule
    code, res, err = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    assert code == 0
    sched_id = res['schedule_id']
    
    # 3. Mutate live template in shift_templates
    run_psql(f"UPDATE public.shift_templates SET name = 'Mutated Early', start_time = '05:00' WHERE station_id = '{sta}' AND code = 'MORN';")
    
    # 4. Verify schedule shifts retain original frozen snapshot
    code, res, err = run_as_user_json(admin, f"public.get_schedule_details('{sched_id}')")
    assert code == 0
    for s in res['shifts']:
        assert s['shift_name'] == 'Original Morning'
        assert s['start_time'] == '07:00:00'

def test_05_same_station_exact_duplicate_overlap():
    admin = fixture_user("Admin", "Dup")
    emp = fixture_user("Emp", "Dup")
    sta = fixture_station("DupStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [("Morning", "MORN", "07:00", "15:00")], admin)
    code, res, err = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    
    code, out, err = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{sched_id}' LIMIT 1;")
    shift_id = out.strip()
    
    # First assignment
    code, res, err = run_as_user_json(admin, f"public.assign_employee_to_shift('{shift_id}', '{mem}', 1, true, 'Approved')")
    assert code == 0 and res['success'] is True
    
    # Duplicate assignment on same shift -> Must fail
    code, res, err = run_as_user_json(admin, f"public.assign_employee_to_shift('{shift_id}', '{mem}', 2, true, 'Dup')")
    assert code != 0 or not res or not res.get('success')
    assert "23505" in err or "already assigned" in err

def test_06_same_station_partial_overlap():
    admin = fixture_user("Admin", "PartOver")
    emp = fixture_user("Emp", "PartOver")
    sta = fixture_station("PartOverlapStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [
        ("Shift 1", "S1", "08:00", "16:00"),
        ("Shift 2", "S2", "12:00", "20:00")
    ], admin)
    code, res, err = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    
    code, out, err = run_psql(f"""
        SELECT id FROM public.work_schedule_shifts 
        WHERE work_schedule_id = '{sched_id}' AND operational_date = '2026-09-06'
        ORDER BY start_time_snapshot ASC;
    """)
    s_ids = [s.strip() for s in out.split("\n") if s.strip()]
    s1, s2 = s_ids[0], s_ids[1]
    
    # Assign S1
    code, res, err = run_as_user_json(admin, f"public.assign_employee_to_shift('{s1}', '{mem}', 1, true, 'Approved')")
    assert code == 0
    
    # Assign S2 (Overlaps 12:00-16:00) -> Must fail with P0008
    code, res, err = run_as_user_json(admin, f"public.assign_employee_to_shift('{s2}', '{mem}', 2, true, 'Approved')")
    assert code != 0 or not res or not res.get('success')
    assert "P0008" in err or "Overlapping" in err

def test_07_adjacent_non_overlap():
    admin = fixture_user("Admin", "Adj")
    emp = fixture_user("Emp", "Adj")
    sta = fixture_station("AdjStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [
        ("Morning", "MORN", "07:00", "15:00"),
        ("Evening", "EVE", "15:00", "23:00")
    ], admin)
    code, res, err = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    
    code, out, err = run_psql(f"""
        SELECT id FROM public.work_schedule_shifts 
        WHERE work_schedule_id = '{sched_id}' AND operational_date = '2026-09-06'
        ORDER BY start_time_snapshot ASC;
    """)
    s_ids = [s.strip() for s in out.split("\n") if s.strip()]
    morn, eve = s_ids[0], s_ids[1]
    
    # Assign Morning [07:00, 15:00)
    code, res, err = run_as_user_json(admin, f"public.assign_employee_to_shift('{morn}', '{mem}', 1, true, 'Approved')")
    assert code == 0
    
    # Assign Evening [15:00, 23:00) -> Exact half-open boundary, MUST succeed
    code, res, err = run_as_user_json(admin, f"public.assign_employee_to_shift('{eve}', '{mem}', 2, true, 'Approved')")
    assert code == 0 and res['success'] is True

def test_08_cross_midnight_overlap():
    admin = fixture_user("Admin", "CrossMid")
    emp = fixture_user("Emp", "CrossMid")
    sta = fixture_station("CrossMidStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [
        ("Night", "NIGHT", "23:00", "07:00"),
        ("Morning", "MORN", "06:00", "14:00")
    ], admin)
    code, res, err = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    
    # Sunday Night (2026-09-06 23:00 to 2026-09-07 07:00)
    code, out, err = run_psql(f"""
        SELECT id FROM public.work_schedule_shifts 
        WHERE work_schedule_id = '{sched_id}' AND operational_date = '2026-09-06' AND shift_name_snapshot = 'Night';
    """)
    sun_night = out.strip()
    
    # Monday Morning (2026-09-07 06:00 to 2026-09-07 14:00)
    code, out, err = run_psql(f"""
        SELECT id FROM public.work_schedule_shifts 
        WHERE work_schedule_id = '{sched_id}' AND operational_date = '2026-09-07' AND shift_name_snapshot = 'Morning';
    """)
    mon_morn = out.strip()
    
    # Assign Sunday Night
    code, res, err = run_as_user_json(admin, f"public.assign_employee_to_shift('{sun_night}', '{mem}', 1, true, 'Approved')")
    assert code == 0
    
    # Assign Monday Morning (Overlaps 06:00-07:00) -> Must fail
    code, res, err = run_as_user_json(admin, f"public.assign_employee_to_shift('{mon_morn}', '{mem}', 2, true, 'Approved')")
    assert code != 0 or not res or not res.get('success')
    assert "P0008" in err or "Overlapping" in err

def test_09_cross_station_overlap():
    admin_a = fixture_user("AdminA", "StA")
    admin_b = fixture_user("AdminB", "StB")
    emp = fixture_user("Shared", "Worker")
    
    sta_a = fixture_station("AlphaStation")
    sta_b = fixture_station("BetaStation")
    fixture_membership(sta_a, admin_a, role="ADMIN")
    fixture_membership(sta_b, admin_b, role="ADMIN")
    mem_a = fixture_membership(sta_a, emp, role="EMPLOYEE")
    mem_b = fixture_membership(sta_b, emp, role="EMPLOYEE")
    
    per_a = fixture_period_with_templates(sta_a, "2026-09-06", [("Afternoon A", "AFT_A", "14:00", "22:00")], admin_a)
    per_b = fixture_period_with_templates(sta_b, "2026-09-06", [("Evening B", "EVE_B", "18:00", "02:00")], admin_b)
    
    code, res_a, _ = run_as_user_json(admin_a, f"public.create_work_schedule('{per_a}')")
    code, res_b, _ = run_as_user_json(admin_b, f"public.create_work_schedule('{per_b}')")
    
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{res_a['schedule_id']}' LIMIT 1;")
    shift_a = out.strip()
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{res_b['schedule_id']}' LIMIT 1;")
    shift_b = out.strip()
    
    # Assign at Station A
    code, res, err = run_as_user_json(admin_a, f"public.assign_employee_to_shift('{shift_a}', '{mem_a}', 1, true, 'Approved')")
    assert code == 0
    
    # Assign at Station B (Overlaps 18:00 to 22:00) -> Must fail with P0009
    code, res, err = run_as_user_json(admin_b, f"public.assign_employee_to_shift('{shift_b}', '{mem_b}', 1, true, 'Approved')")
    assert code != 0 or not res or not res.get('success')
    assert "P0009" in err or "Cross-station" in err

def test_10_cross_station_privacy():
    admin_a = fixture_user("AdminA", "Privacy")
    admin_b = fixture_user("AdminB", "Privacy")
    emp = fixture_user("Shared", "Privacy")
    
    sta_a = fixture_station("SecretStationA")
    sta_b = fixture_station("SecretStationB")
    fixture_membership(sta_a, admin_a, role="ADMIN")
    fixture_membership(sta_b, admin_b, role="ADMIN")
    mem_a = fixture_membership(sta_a, emp, role="EMPLOYEE")
    mem_b = fixture_membership(sta_b, emp, role="EMPLOYEE")
    
    per_a = fixture_period_with_templates(sta_a, "2026-09-06", [("Top Secret Shift A", "SEC_A", "10:00", "18:00")], admin_a)
    per_b = fixture_period_with_templates(sta_b, "2026-09-06", [("Top Secret Shift B", "SEC_B", "12:00", "20:00")], admin_b)
    
    code, res_a, _ = run_as_user_json(admin_a, f"public.create_work_schedule('{per_a}')")
    code, res_b, _ = run_as_user_json(admin_b, f"public.create_work_schedule('{per_b}')")
    
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{res_a['schedule_id']}' LIMIT 1;")
    shift_a = out.strip()
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{res_b['schedule_id']}' LIMIT 1;")
    shift_b = out.strip()
    
    # Assign at Station A
    run_as_user_json(admin_a, f"public.assign_employee_to_shift('{shift_a}', '{mem_a}', 1, true, 'Approved')")
    
    # Candidate query at Station B
    code, res, err = run_as_user_json(admin_b, f"public.get_shift_assignment_candidates('{shift_b}')")
    assert code == 0, f"get_shift_assignment_candidates failed: {err}"
    cand = next((c for c in res['candidates'] if c['membership_id'] == mem_b), None)
    assert cand is not None, "Candidate not found in candidate list"
    assert cand['conflict_state'] == 'CROSS_STATION_OVERLAP', f"Expected CROSS_STATION_OVERLAP, got {cand.get('conflict_state')}"
    
    # Attempt assignment at Station B -> Error must NOT leak Station A details
    code, res, err = run_as_user_json(admin_b, f"public.assign_employee_to_shift('{shift_b}', '{mem_b}', 1, true, 'Approved')")
    assert code != 0, "Cross-station assignment should have failed"
    assert "SecretStationA" not in err, f"Leaked foreign station name in: {err}"
    assert "Top Secret Shift A" not in err, f"Leaked foreign shift name in: {err}"
    assert "P0009" in err or "Cross-station" in err

def test_11_concurrent_cross_station_assignment_race():
    admin_a = fixture_user("AdminA", "Race")
    admin_b = fixture_user("AdminB", "Race")
    emp = fixture_user("Shared", "RaceEmp")
    
    sta_a = fixture_station("RaceStationA")
    sta_b = fixture_station("RaceStationB")
    fixture_membership(sta_a, admin_a, role="ADMIN")
    fixture_membership(sta_b, admin_b, role="ADMIN")
    mem_a = fixture_membership(sta_a, emp, role="EMPLOYEE")
    mem_b = fixture_membership(sta_b, emp, role="EMPLOYEE")
    
    per_a = fixture_period_with_templates(sta_a, "2026-09-06", [("Shift A", "SA", "10:00", "18:00")], admin_a)
    per_b = fixture_period_with_templates(sta_b, "2026-09-06", [("Shift B", "SB", "10:00", "18:00")], admin_b)
    
    code, res_a, _ = run_as_user_json(admin_a, f"public.create_work_schedule('{per_a}')")
    code, res_b, _ = run_as_user_json(admin_b, f"public.create_work_schedule('{per_b}')")
    
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{res_a['schedule_id']}' LIMIT 1;")
    shift_a = out.strip()
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{res_b['schedule_id']}' LIMIT 1;")
    shift_b = out.strip()
    
    results = []
    def worker(admin_id, s_id, m_id):
        c, r, e = run_as_user_json(admin_id, f"public.assign_employee_to_shift('{s_id}', '{m_id}', 1, true, 'Race')")
        results.append((c == 0 and r and r.get('success') is True, e))
        
    t1 = threading.Thread(target=worker, args=(admin_a, shift_a, mem_a))
    t2 = threading.Thread(target=worker, args=(admin_b, shift_b, mem_b))
    t1.start(); t2.start()
    t1.join(); t2.join()
    
    successes = [r for r in results if r[0] is True]
    failures = [r for r in results if r[0] is False]
    assert len(successes) == 1, f"Expected exactly 1 success, got {len(successes)}"
    assert len(failures) == 1, f"Expected exactly 1 failure, got {len(failures)}"

def test_12_repeated_cross_station_races():
    for _ in range(5):
        test_11_concurrent_cross_station_assignment_race()

def test_13_occ_assign_vs_assign():
    admin = fixture_user("Admin", "OCC1")
    emp1 = fixture_user("Emp1", "OCC1")
    emp2 = fixture_user("Emp2", "OCC1")
    sta = fixture_station("OCC1Station")
    fixture_membership(sta, admin, role="ADMIN")
    mem1 = fixture_membership(sta, emp1, role="EMPLOYEE")
    mem2 = fixture_membership(sta, emp2, role="EMPLOYEE")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [("Shift", "S", "07:00", "15:00")], admin)
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{sched_id}' LIMIT 1;")
    shift_id = out.strip()
    
    results = []
    def worker(m_id):
        c, r, e = run_as_user_json(admin, f"public.assign_employee_to_shift('{shift_id}', '{m_id}', 1, true, 'OCC')")
        results.append((c == 0 and r and r.get('success') is True, e))
        
    t1 = threading.Thread(target=worker, args=(mem1,))
    t2 = threading.Thread(target=worker, args=(mem2,))
    t1.start(); t2.start()
    t1.join(); t2.join()
    
    assert len([r for r in results if r[0] is True]) == 1
    assert len([r for r in results if r[0] is False]) == 1

def test_14_occ_assign_vs_remove():
    admin = fixture_user("Admin", "OCC2")
    emp1 = fixture_user("Emp1", "OCC2")
    emp2 = fixture_user("Emp2", "OCC2")
    sta = fixture_station("OCC2Station")
    fixture_membership(sta, admin, role="ADMIN")
    mem1 = fixture_membership(sta, emp1, role="EMPLOYEE")
    mem2 = fixture_membership(sta, emp2, role="EMPLOYEE")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [("Shift", "S", "07:00", "15:00")], admin)
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{sched_id}' LIMIT 1;")
    shift_id = out.strip()
    
    # Init assignment at version 1 (version becomes 2)
    code, res, _ = run_as_user_json(admin, f"public.assign_employee_to_shift('{shift_id}', '{mem1}', 1, true, 'Init')")
    asgn_id = res['assignment_id']
    
    results = []
    def worker_rem():
        c, r, e = run_as_user_json(admin, f"public.remove_shift_assignment('{asgn_id}', 2)")
        results.append((c == 0 and r and r.get('success') is True, e))
    def worker_asgn():
        c, r, e = run_as_user_json(admin, f"public.assign_employee_to_shift('{shift_id}', '{mem2}', 2, true, 'Assign')")
        results.append((c == 0 and r and r.get('success') is True, e))
        
    t1 = threading.Thread(target=worker_rem)
    t2 = threading.Thread(target=worker_asgn)
    t1.start(); t2.start()
    t1.join(); t2.join()
    
    assert len([r for r in results if r[0] is True]) == 1
    assert len([r for r in results if r[0] is False]) == 1

def test_15_occ_move_vs_move():
    admin = fixture_user("Admin", "OCC3")
    emp = fixture_user("Emp", "OCC3")
    sta = fixture_station("OCC3Station")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [
        ("S1", "S1", "07:00", "11:00"),
        ("S2", "S2", "11:00", "15:00"),
        ("S3", "S3", "15:00", "19:00")
    ], admin)
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{sched_id}' ORDER BY start_time_snapshot ASC;")
    s_ids = [s.strip() for s in out.split("\n") if s.strip()]
    s1, s2, s3 = s_ids[0], s_ids[1], s_ids[2]
    
    code, res, _ = run_as_user_json(admin, f"public.assign_employee_to_shift('{s1}', '{mem}', 1, true, 'Init')")
    asgn_id = res['assignment_id']
    
    results = []
    def worker_move(target_id):
        c, r, e = run_as_user_json(admin, f"public.move_shift_assignment('{asgn_id}', '{target_id}', 2, true, 'Move')")
        results.append((c == 0 and r and r.get('success') is True, e))
        
    t1 = threading.Thread(target=worker_move, args=(s2,))
    t2 = threading.Thread(target=worker_move, args=(s3,))
    t1.start(); t2.start()
    t1.join(); t2.join()
    
    assert len([r for r in results if r[0] is True]) == 1
    assert len([r for r in results if r[0] is False]) == 1

def test_16_occ_move_vs_remove():
    admin = fixture_user("Admin", "OCC4")
    emp = fixture_user("Emp", "OCC4")
    sta = fixture_station("OCC4Station")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [("S1", "S1", "07:00", "15:00"), ("S2", "S2", "15:00", "23:00")], admin)
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{sched_id}' ORDER BY start_time_snapshot ASC;")
    s_ids = [s.strip() for s in out.split("\n") if s.strip()]
    s1, s2 = s_ids[0], s_ids[1]
    
    code, res, _ = run_as_user_json(admin, f"public.assign_employee_to_shift('{s1}', '{mem}', 1, true, 'Init')")
    asgn_id = res['assignment_id']
    
    results = []
    def worker_move():
        c, r, e = run_as_user_json(admin, f"public.move_shift_assignment('{asgn_id}', '{s2}', 2, true, 'Move')")
        results.append((c == 0 and r and r.get('success') is True, e))
    def worker_rem():
        c, r, e = run_as_user_json(admin, f"public.remove_shift_assignment('{asgn_id}', 2)")
        results.append((c == 0 and r and r.get('success') is True, e))
        
    t1 = threading.Thread(target=worker_move)
    t2 = threading.Thread(target=worker_rem)
    t1.start(); t2.start()
    t1.join(); t2.join()
    
    assert len([r for r in results if r[0] is True]) == 1
    assert len([r for r in results if r[0] is False]) == 1

def test_17_occ_staffing_vs_publish():
    admin = fixture_user("Admin", "OCC5")
    sta = fixture_station("OCC5Station")
    fixture_membership(sta, admin, role="ADMIN")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [("Shift", "S", "07:00", "15:00")], admin)
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{sched_id}' LIMIT 1;")
    shift_id = out.strip()
    
    results = []
    def worker_staff():
        c, r, e = run_as_user_json(admin, f"public.update_schedule_shift_staffing('{shift_id}', 2, 1)")
        results.append((c == 0 and r and r.get('success') is True, e))
    def worker_pub():
        c, r, e = run_as_user_json(admin, f"public.publish_work_schedule('{sched_id}', 1, true)")
        results.append((c == 0 and r and r.get('success') is True, e))
        
    t1 = threading.Thread(target=worker_staff)
    t2 = threading.Thread(target=worker_pub)
    t1.start(); t2.start()
    t1.join(); t2.join()
    
    assert len([r for r in results if r[0] is True]) == 1
    assert len([r for r in results if r[0] is False]) == 1

def test_18_occ_double_publish():
    admin = fixture_user("Admin", "OCC6")
    sta = fixture_station("OCC6Station")
    fixture_membership(sta, admin, role="ADMIN")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [("Shift", "S", "07:00", "15:00")], admin)
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    
    results = []
    def worker_pub():
        c, r, e = run_as_user_json(admin, f"public.publish_work_schedule('{sched_id}', 1, true)")
        results.append((c == 0 and r and r.get('success') is True, e))
        
    t1 = threading.Thread(target=worker_pub)
    t2 = threading.Thread(target=worker_pub)
    t1.start(); t2.start()
    t1.join(); t2.join()
    
    assert len([r for r in results if r[0] is True]) == 1
    assert len([r for r in results if r[0] is False]) == 1

def test_19_failed_mutation_version_preservation():
    admin = fixture_user("Admin", "VerPres")
    emp = fixture_user("Emp", "VerPres")
    sta = fixture_station("VerPresStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [("Shift", "S", "07:00", "15:00")], admin)
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{sched_id}' LIMIT 1;")
    shift_id = out.strip()
    
    # Attempt invalid assignment (bad override reason)
    run_as_user_json(admin, f"public.assign_employee_to_shift('{shift_id}', '{mem}', 1, true, 'a')")
    
    code, out, _ = run_psql(f"SELECT version FROM public.work_schedules WHERE id = '{sched_id}';")
    assert int(out.strip()) == 1, "Version incremented on failed mutation!"

def test_20_move_rollback_atomicity():
    admin = fixture_user("Admin", "Atomicity")
    emp1 = fixture_user("Emp1", "Atomicity")
    emp2 = fixture_user("Emp2", "Atomicity")
    sta = fixture_station("AtomicityStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem1 = fixture_membership(sta, emp1, role="EMPLOYEE")
    mem2 = fixture_membership(sta, emp2, role="EMPLOYEE")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [("S1", "S1", "07:00", "15:00"), ("S2", "S2", "07:00", "15:00")], admin)
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{sched_id}' ORDER BY start_time_snapshot ASC;")
    s_ids = [s.strip() for s in out.split("\n") if s.strip()]
    s1, s2 = s_ids[0], s_ids[1]
    
    code, res1, _ = run_as_user_json(admin, f"public.assign_employee_to_shift('{s1}', '{mem1}', 1, true, 'Init')")
    asgn1 = res1['assignment_id']
    run_as_user_json(admin, f"public.assign_employee_to_shift('{s2}', '{mem2}', 2, true, 'Init')")
    
    # Attempt invalid move (bad override reason)
    code, res, err = run_as_user_json(admin, f"public.move_shift_assignment('{asgn1}', '{s2}', 3, true, 'ab')")
    assert code != 0
    
    # Verify asgn1 is still assigned to s1
    code, out, _ = run_psql(f"SELECT work_schedule_shift_id FROM public.shift_assignments WHERE id = '{asgn1}';")
    assert out.strip() == s1, "Source assignment was removed during failed move!"

def test_21_unavailable_without_override():
    admin = fixture_user("Admin", "Unavail")
    emp = fixture_user("Emp", "Unavail")
    sta = fixture_station("UnavailStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [("Morning", "MORN", "07:00", "15:00")], admin)
    code, out, _ = run_psql(f"SELECT id FROM public.availability_period_shift_templates WHERE availability_period_id = '{per}';")
    tmpl_id = out.strip()
    
    sub_id = str(uuid.uuid4())
    run_psql(f"""
        INSERT INTO public.availability_submissions (id, availability_period_id, membership_id, status)
        VALUES ('{sub_id}', '{per}', '{mem}', 'SUBMITTED');
        INSERT INTO public.availability_entries (submission_id, period_shift_template_id, date, is_available)
        VALUES ('{sub_id}', '{tmpl_id}', '2026-09-06', false);
    """)
    
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{sched_id}' LIMIT 1;")
    shift_id = out.strip()
    
    # Assign without override -> Must fail
    code, res, err = run_as_user_json(admin, f"public.assign_employee_to_shift('{shift_id}', '{mem}', 1, false)")
    assert code != 0 or (res and res.get('success') is False), f"Expected error or success=false, got code={code}, res={res}"
    assert "P0006" in err or (res and "P0006" in str(res)) or "UNAVAILABLE" in err or "override" in err.lower()

def test_22_invalid_override_reason():
    admin = fixture_user("Admin", "ReasonTest")
    emp = fixture_user("Emp", "ReasonTest")
    sta = fixture_station("ReasonStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [("Morning", "MORN", "07:00", "15:00")], admin)
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{sched_id}' LIMIT 1;")
    shift_id = out.strip()
    
    for r in ["NULL", "''", "'   '", "E'\\n\\t'", "'ab'"]:
        code, res, err = run_as_user_json(admin, f"public.assign_employee_to_shift('{shift_id}', '{mem}', 1, true, {r})")
        assert code != 0 or (res and res.get('success') is False), f"Expected failure for reason {r}, got {res}"
        assert "P0007" in err or "reason" in err.lower() or "P0007" in str(res)

def test_23_not_submitted_semantics():
    admin = fixture_user("Admin", "NotSub")
    emp = fixture_user("Emp", "NotSub")
    sta = fixture_station("NotSubStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [("Morning", "MORN", "07:00", "15:00")], admin)
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{sched_id}' LIMIT 1;")
    shift_id = out.strip()
    
    # Without override -> Fails
    code, res, err = run_as_user_json(admin, f"public.assign_employee_to_shift('{shift_id}', '{mem}', 1, false)")
    assert code != 0 or (res and res.get('success') is False), f"Expected failure without override, got {res}"
    assert "P0006" in err or "NOT_SUBMITTED" in err or "override" in err.lower() or "P0006" in str(res)
    
    # With override -> Succeeds
    code, res, err = run_as_user_json(admin, f"public.assign_employee_to_shift('{shift_id}', '{mem}', 1, true, 'Phone call confirmed')")
    assert code == 0 and res['success'] is True

def test_24_availability_drift_detection():
    admin = fixture_user("Admin", "Drift")
    emp = fixture_user("Emp", "Drift")
    sta = fixture_station("DriftStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [("Morning", "MORN", "07:00", "15:00")], admin)
    code, out, _ = run_psql(f"SELECT id FROM public.availability_period_shift_templates WHERE availability_period_id = '{per}';")
    tmpl_id = out.strip()
    
    sub_id = str(uuid.uuid4())
    run_psql(f"""
        INSERT INTO public.availability_submissions (id, availability_period_id, membership_id, status)
        VALUES ('{sub_id}', '{per}', '{mem}', 'SUBMITTED');
        INSERT INTO public.availability_entries (submission_id, period_shift_template_id, date, is_available)
        VALUES ('{sub_id}', '{tmpl_id}', '2026-09-06', true);
    """)
    
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{sched_id}' LIMIT 1;")
    shift_id = out.strip()
    
    # Assign employee
    run_as_user_json(admin, f"public.assign_employee_to_shift('{shift_id}', '{mem}', 1, false)")
    
    # Employee changes availability to UNAVAILABLE
    run_psql(f"UPDATE public.availability_entries SET is_available = false WHERE submission_id = '{sub_id}';")
    
    # Validate -> Must detect AVAILABILITY_DRIFT warning
    code, res, err = run_as_user_json(admin, f"public.validate_work_schedule('{sched_id}')")
    assert code == 0
    drift = [w for w in res['warnings'] if w['code'] == 'AVAILABILITY_DRIFT']
    assert len(drift) == 1

def test_25_inactive_membership_pre_publish():
    admin = fixture_user("Admin", "InactPre")
    emp = fixture_user("Emp", "InactPre")
    sta = fixture_station("InactPreStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [("Morning", "MORN", "07:00", "15:00")], admin)
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{sched_id}' LIMIT 1;")
    shift_id = out.strip()
    
    run_as_user_json(admin, f"public.assign_employee_to_shift('{shift_id}', '{mem}', 1, true, 'Pre')")
    
    # Deactivate employee
    run_psql(f"UPDATE public.station_memberships SET status = 'INACTIVE' WHERE id = '{mem}';")
    
    # Validate -> Hard error
    code, res, err = run_as_user_json(admin, f"public.validate_work_schedule('{sched_id}')")
    assert code == 0
    assert res['is_valid'] is False
    assert any(e['code'] == 'INACTIVE_MEMBERSHIP' for e in res['hard_errors'])
    
    # Publish -> Fails with P0011
    code, res, err = run_as_user_json(admin, f"public.publish_work_schedule('{sched_id}', 2, true)")
    assert code != 0 or (res and res.get('success') is False), f"Expected publish failure, got code={code}, res={res}"
    assert "P0011" in err or "inactive" in err.lower() or "P0011" in str(res)

def test_26_suspended_membership_pre_publish():
    admin = fixture_user("Admin", "SuspPre")
    emp = fixture_user("Emp", "SuspPre")
    sta = fixture_station("SuspPreStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [("Morning", "MORN", "07:00", "15:00")], admin)
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{sched_id}' LIMIT 1;")
    shift_id = out.strip()
    
    run_as_user_json(admin, f"public.assign_employee_to_shift('{shift_id}', '{mem}', 1, true, 'Pre')")
    run_psql(f"UPDATE public.station_memberships SET status = 'SUSPENDED' WHERE id = '{mem}';")
    
    code, res, err = run_as_user_json(admin, f"public.validate_work_schedule('{sched_id}')")
    assert code == 0 and res['is_valid'] is False

def test_27_direct_assignment_insert_bypass():
    emp = fixture_user("Attacker", "DirectInsert")
    sta = fixture_station("DirectBypass1")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    
    code, res, err = run_as_user_json(emp, f"""
        INSERT INTO public.shift_assignments 
        (work_schedule_shift_id, station_id, membership_id, user_id, availability_state_snapshot, assigned_by)
        VALUES ('{uuid.uuid4()}', '{sta}', '{mem}', '{emp}', 'AVAILABLE', '{emp}');
    """)
    assert code != 0, "Direct table insert was not blocked by RLS"

def test_28_direct_schedule_publish_bypass():
    admin = fixture_user("Admin", "DirectPub")
    emp = fixture_user("Attacker", "DirectPub")
    sta = fixture_station("DirectBypass2")
    fixture_membership(sta, admin, role="ADMIN")
    fixture_membership(sta, emp, role="EMPLOYEE")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [("Morning", "MORN", "07:00", "15:00")], admin)
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    
    # Employee tries to force status = 'PUBLISHED'
    code, res, err = run_as_user_json(emp, f"UPDATE public.work_schedules SET status = 'PUBLISHED' WHERE id = '{sched_id}' RETURNING id;")
    assert code != 0 or not res, "Direct status update was not blocked by RLS"

def test_29_direct_version_mutation_bypass():
    admin = fixture_user("Admin", "DirectVer")
    emp = fixture_user("Attacker", "DirectVer")
    sta = fixture_station("DirectBypass3")
    fixture_membership(sta, admin, role="ADMIN")
    fixture_membership(sta, emp, role="EMPLOYEE")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [("Morning", "MORN", "07:00", "15:00")], admin)
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    
    code, res, err = run_as_user_json(emp, f"UPDATE public.work_schedules SET version = 999 WHERE id = '{sched_id}' RETURNING id;")
    assert code != 0 or not res

def test_30_ledger_forgery_attempt():
    emp = fixture_user("Attacker", "Forge")
    sta = fixture_station("DirectBypass4")
    fixture_membership(sta, emp, role="EMPLOYEE")
    
    code, res, err = run_as_user_json(emp, f"""
        INSERT INTO public.work_schedule_changes 
        (work_schedule_id, station_id, version_before, version_after, change_type, actor_id, reason)
        VALUES ('{uuid.uuid4()}', '{sta}', 1, 2, 'PUBLISHED', '{emp}', 'Fake');
    """)
    assert code != 0

def test_31_ledger_mutation_deletion_attempt():
    admin = fixture_user("Admin", "LedgerMod")
    sta = fixture_station("LedgerModStation")
    fixture_membership(sta, admin, role="ADMIN")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [("Morning", "MORN", "07:00", "15:00")], admin)
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    run_as_user_json(admin, f"public.publish_work_schedule('{sched_id}', 1, true)")
    
    code, res, err = run_as_user_json(admin, f"DELETE FROM public.work_schedule_changes WHERE work_schedule_id = '{sched_id}' RETURNING id;")
    assert code != 0 or not res, "Audit ledger rows were directly deleted!"

def test_32_schedule_creation_race():
    admin = fixture_user("Admin", "SchedRace")
    sta = fixture_station("SchedRaceStation")
    fixture_membership(sta, admin, role="ADMIN")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [("Morning", "MORN", "07:00", "15:00")], admin)
    
    results = []
    def worker():
        c, r, e = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
        results.append((c == 0 and r and r.get('success') is True, e))
        
    t1 = threading.Thread(target=worker)
    t2 = threading.Thread(target=worker)
    t1.start(); t2.start()
    t1.join(); t2.join()
    
    assert len([r for r in results if r[0] is True]) == 1
    assert len([r for r in results if r[0] is False]) == 1

def test_33_candidate_search_sanitization():
    admin = fixture_user("Admin", "SearchSan")
    sta = fixture_station("SearchSanStation")
    fixture_membership(sta, admin, role="ADMIN")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [("Morning", "MORN", "07:00", "15:00")], admin)
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{sched_id}' LIMIT 1;")
    shift_id = out.strip()
    
    attacks = [
        "'; DROP TABLE public.profiles; --",
        "%' OR 1=1 --",
        "\\\\\\",
        "%%%___%%%",
        "אנס כורדני",
        "A"*1000
    ]
    for q in attacks:
        safe_q = q.replace("'", "''")
        code, res, err = run_as_user_json(admin, f"public.get_shift_assignment_candidates('{shift_id}', '{safe_q}')")
        assert code == 0 and 'candidates' in res

def test_34_candidate_filter_correctness():
    admin = fixture_user("Admin", "Filters")
    emp1 = fixture_user("Avail", "Emp")
    emp2 = fixture_user("Unavail", "Emp")
    emp3 = fixture_user("NotSub", "Emp")
    sta = fixture_station("FilterStation")
    
    fixture_membership(sta, admin, role="ADMIN")
    mem1 = fixture_membership(sta, emp1, role="EMPLOYEE")
    mem2 = fixture_membership(sta, emp2, role="EMPLOYEE")
    mem3 = fixture_membership(sta, emp3, role="EMPLOYEE")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [("Morning", "MORN", "07:00", "15:00")], admin)
    code, out, _ = run_psql(f"SELECT id FROM public.availability_period_shift_templates WHERE availability_period_id = '{per}';")
    tmpl_id = out.strip()
    
    sub1 = str(uuid.uuid4())
    sub2 = str(uuid.uuid4())
    run_psql(f"""
        INSERT INTO public.availability_submissions (id, availability_period_id, membership_id, status) VALUES ('{sub1}', '{per}', '{mem1}', 'SUBMITTED');
        INSERT INTO public.availability_entries (submission_id, period_shift_template_id, date, is_available) VALUES ('{sub1}', '{tmpl_id}', '2026-09-06', true);
        INSERT INTO public.availability_submissions (id, availability_period_id, membership_id, status) VALUES ('{sub2}', '{per}', '{mem2}', 'SUBMITTED');
        INSERT INTO public.availability_entries (submission_id, period_shift_template_id, date, is_available) VALUES ('{sub2}', '{tmpl_id}', '2026-09-06', false);
    """)
    
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{sched_id}' LIMIT 1;")
    shift_id = out.strip()
    
    code, res, _ = run_as_user_json(admin, f"public.get_shift_assignment_candidates('{shift_id}', NULL, 'AVAILABLE')")
    assert all(c['availability_state'] == 'AVAILABLE' for c in res['candidates']) and len(res['candidates']) == 1
    
    code, res, _ = run_as_user_json(admin, f"public.get_shift_assignment_candidates('{shift_id}', NULL, 'UNAVAILABLE')")
    assert all(c['availability_state'] == 'UNAVAILABLE' for c in res['candidates']) and len(res['candidates']) == 1
    
    code, res, _ = run_as_user_json(admin, f"public.get_shift_assignment_candidates('{shift_id}', NULL, 'NOT_SUBMITTED')")
    assert any(c['membership_id'] == mem3 for c in res['candidates'])

def test_35_candidate_scale_benchmark():
    admin = fixture_user("Admin", "Scale")
    sta = fixture_station("ScaleStation")
    fixture_membership(sta, admin, role="ADMIN")
    
    # Bulk insert 100 users
    sql_auth = []
    sql_users = []
    sql_mems = []
    for i in range(100):
        u_id = str(uuid.uuid4())
        sql_auth.append(f"('{u_id}', 'scale.worker{i}.{u_id[:6]}@yellow.com')")
        sql_users.append(f"('{u_id}', 'Worker{i}', 'Scale{i}', 'he')")
        sql_mems.append(f"('{uuid.uuid4()}', '{sta}', '{u_id}', 'EMPLOYEE', 'ACTIVE')")
        
    run_psql(f"INSERT INTO auth.users (id, email) VALUES {','.join(sql_auth)};")
    run_psql(f"INSERT INTO public.profiles (id, first_name, last_name, preferred_locale) VALUES {','.join(sql_users)};")
    run_psql(f"INSERT INTO public.station_memberships (id, station_id, user_id, role, status) VALUES {','.join(sql_mems)};")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [("Morning", "MORN", "07:00", "15:00")], admin)
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{sched_id}' LIMIT 1;")
    shift_id = out.strip()
    
    t0 = time.perf_counter()
    code, res, _ = run_as_user_json(admin, f"public.get_shift_assignment_candidates('{shift_id}')")
    t_query = (time.perf_counter() - t0) * 1000.0
    
    assert code == 0
    assert len(res['candidates']) >= 100
    assert t_query < 100.0, f"Query took {t_query:.1f}ms (>100ms)"

def test_36_dst_spring_transition():
    admin = fixture_user("Admin", "SpringDST")
    sta = fixture_station("SpringDSTStation", tz="Asia/Jerusalem")
    fixture_membership(sta, admin, role="ADMIN")
    
    per = fixture_period_with_templates(sta, "2026-03-22", [("Morning", "MORN", "07:00", "15:00"), ("Night", "NIGHT", "23:00", "07:00")], admin)
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    
    code, out, _ = run_psql(f"SELECT starts_at, ends_at FROM public.work_schedule_shifts WHERE work_schedule_id = '{sched_id}';")
    for line in out.split("\n"):
        if not line.strip(): continue
        starts_at, ends_at = line.split("|")
        assert ends_at > starts_at

def test_37_dst_fall_transition():
    admin = fixture_user("Admin", "FallDST")
    sta = fixture_station("FallDSTStation", tz="America/New_York")
    fixture_membership(sta, admin, role="ADMIN")
    
    per = fixture_period_with_templates(sta, "2026-11-01", [("Day", "DAY", "09:00", "17:00"), ("Night", "NIGHT", "23:00", "07:00")], admin)
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    
    code, out, _ = run_psql(f"SELECT starts_at, ends_at FROM public.work_schedule_shifts WHERE work_schedule_id = '{sched_id}';")
    for line in out.split("\n"):
        if not line.strip(): continue
        starts_at, ends_at = line.split("|")
        assert ends_at > starts_at

def test_38_cross_midnight_across_timezones():
    admin = fixture_user("Admin", "TZ")
    for tz in ["Europe/Berlin", "Asia/Jerusalem", "America/New_York", "Asia/Tokyo"]:
        sta = fixture_station(f"TZStation_{tz.replace('/', '_')}", tz=tz)
        fixture_membership(sta, admin, role="ADMIN")
        per = fixture_period_with_templates(sta, "2026-09-06", [("CrossMidnight", "CM", "22:30", "06:30")], admin)
        code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
        sched_id = res['schedule_id']
        
        code, out, _ = run_psql(f"SELECT starts_at, ends_at FROM public.work_schedule_shifts WHERE work_schedule_id = '{sched_id}';")
        for line in out.split("\n"):
            if not line.strip(): continue
            starts_at, ends_at = line.split("|")
            assert ends_at > starts_at

def test_39_employee_draft_invisibility():
    admin = fixture_user("Admin", "DraftVis")
    emp = fixture_user("Emp", "DraftVis")
    sta = fixture_station("DraftVisStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [("Morning", "MORN", "07:00", "15:00")], admin)
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{sched_id}' LIMIT 1;")
    shift_id = out.strip()
    
    run_as_user_json(admin, f"public.assign_employee_to_shift('{shift_id}', '{mem}', 1, true, 'Draft')")
    
    # Query get_my_shifts on DRAFT
    code, res, _ = run_as_user_json(emp, f"public.get_my_shifts('{sta}', '2026-09-06')")
    assert code == 0
    assert res['has_published_schedule'] is False
    assert len(res['shifts']) == 0
    
    # Direct select on shift_assignments returns 0 rows
    code, res, _ = run_as_user_json(emp, f"SELECT id FROM public.shift_assignments WHERE station_id = '{sta}';")
    assert not res

def test_40_employee_foreign_assignment_invisibility():
    admin_a = fixture_user("AdminA", "VisA")
    admin_b = fixture_user("AdminB", "VisB")
    emp_a = fixture_user("EmpA", "VisA")
    emp_b = fixture_user("EmpB", "VisB")
    
    sta_a = fixture_station("VisStationA")
    sta_b = fixture_station("VisStationB")
    fixture_membership(sta_a, admin_a, role="ADMIN")
    fixture_membership(sta_b, admin_b, role="ADMIN")
    mem_a = fixture_membership(sta_a, emp_a, role="EMPLOYEE")
    mem_b = fixture_membership(sta_b, emp_b, role="EMPLOYEE")
    
    per_a = fixture_period_with_templates(sta_a, "2026-09-06", [("Shift A", "SA", "07:00", "15:00")], admin_a)
    per_b = fixture_period_with_templates(sta_b, "2026-09-06", [("Shift B", "SB", "07:00", "15:00")], admin_b)
    
    code, res_a, _ = run_as_user_json(admin_a, f"public.create_work_schedule('{per_a}')")
    code, res_b, _ = run_as_user_json(admin_b, f"public.create_work_schedule('{per_b}')")
    
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{res_a['schedule_id']}' LIMIT 1;")
    run_as_user_json(admin_a, f"public.assign_employee_to_shift('{out.strip()}', '{mem_a}', 1, true, 'Init')")
    run_as_user_json(admin_a, f"public.publish_work_schedule('{res_a['schedule_id']}', 2, true)")
    
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{res_b['schedule_id']}' LIMIT 1;")
    run_as_user_json(admin_b, f"public.assign_employee_to_shift('{out.strip()}', '{mem_b}', 1, true, 'Init')")
    run_as_user_json(admin_b, f"public.publish_work_schedule('{res_b['schedule_id']}', 2, true)")
    
    # emp_a queries Station B -> Must be rejected (not a member)
    code, res, err = run_as_user_json(emp_a, f"public.get_my_shifts('{sta_b}', '2026-09-06')")
    assert code != 0 or (res and res.get('success') is False), f"Expected rejection for non-member, got {res}"
    assert "42501" in err or "permission" in err.lower() or "not a member" in err.lower()

def test_41_published_revision_reason_required():
    admin = fixture_user("Admin", "PubRev")
    emp = fixture_user("Emp", "PubRev")
    sta = fixture_station("PubRevStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [("Morning", "MORN", "07:00", "15:00")], admin)
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    run_as_user_json(admin, f"public.publish_work_schedule('{sched_id}', 1, true)")
    
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{sched_id}' LIMIT 1;")
    shift_id = out.strip()
    
    # Mutating PUBLISHED schedule without change_reason -> Fails with P0010
    code, res, err = run_as_user_json(admin, f"public.assign_employee_to_shift('{shift_id}', '{mem}', 2, true, 'Override', NULL)")
    assert code != 0 or (res and res.get('success') is False), f"Expected failure without change_reason, got {res}"
    assert "P0010" in err or "reason" in err.lower() or "P0010" in str(res)
    
    # With change_reason -> Succeeds and logs
    code, res, err = run_as_user_json(admin, f"public.assign_employee_to_shift('{shift_id}', '{mem}', 2, true, 'Override', 'Worker replacement')")
    assert code == 0 and res['success'] is True
    
    code, out, _ = run_psql(f"SELECT reason FROM public.work_schedule_changes WHERE work_schedule_id = '{sched_id}' AND change_type = 'ASSIGNMENT_ADDED';")
    assert out.strip() == 'Worker replacement'

def test_42_original_publication_metadata_immutability():
    admin = fixture_user("Admin", "PubMeta")
    emp = fixture_user("Emp", "PubMeta")
    sta = fixture_station("PubMetaStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [("Morning", "MORN", "07:00", "15:00")], admin)
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    run_as_user_json(admin, f"public.publish_work_schedule('{sched_id}', 1, true)")
    
    code, out, _ = run_psql(f"SELECT published_at, published_by FROM public.work_schedules WHERE id = '{sched_id}';")
    orig_time, orig_by = out.strip().split("|")
    assert orig_by == admin
    
    # Post-publish edit
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{sched_id}' LIMIT 1;")
    run_as_user_json(admin, f"public.assign_employee_to_shift('{out.strip()}', '{mem}', 2, true, 'Override', 'Post edit')")
    
    code, out, _ = run_psql(f"SELECT published_at, published_by, version FROM public.work_schedules WHERE id = '{sched_id}';")
    curr_time, curr_by, ver = out.strip().split("|")
    assert curr_time == orig_time
    assert curr_by == orig_by
    assert int(ver) == 3

def test_43_anonymous_access_lockout():
    for tbl in ['work_schedules', 'work_schedule_shifts', 'shift_assignments', 'work_schedule_changes']:
        code, out, err = run_psql(f"""
            SET LOCAL ROLE anon;
            SELECT count(*) FROM public.{tbl};
        """)
        # If code != 0, it was locked out by permission denied. If code == 0, count must be 0.
        if code == 0:
            lines = [l.strip() for l in out.split("\n") if l.strip()]
            assert lines[-1] == '0', f"Anonymous query returned rows on {tbl}: {lines[-1]}"
        else:
            assert "permission denied" in err or "42501" in err, f"Unexpected error on anon query: {err}"

def test_44_security_definer_grants_and_search_path():
    code, out, err = run_psql("""
        SELECT p.proname, p.prosecdef, p.proconfig::text
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
          AND p.proname IN (
              'create_work_schedule', 'get_schedule_details', 'get_shift_assignment_candidates',
              'assign_employee_to_shift', 'remove_shift_assignment', 'move_shift_assignment',
              'update_schedule_shift_staffing', 'validate_work_schedule', 'publish_work_schedule',
              'get_my_shifts'
          );
    """)
    assert code == 0
    lines = [l.strip() for l in out.split("\n") if l.strip()]
    assert len(lines) == 10, f"Expected 10 RPCs, got {len(lines)}"
    for line in lines:
        name, secdef, config = line.split("|")
        assert secdef == 't', f"{name} is not SECURITY DEFINER"
        assert "search_path=public, pg_temp" in config, f"{name} missing search_path: {config}"

def test_45_archive_lifecycle():
    admin = fixture_user("Admin", "Archive")
    emp = fixture_user("Emp", "Archive")
    sta = fixture_station("ArchiveStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    
    per = fixture_period_with_templates(sta, "2026-09-06", [("Morning", "MORN", "07:00", "15:00")], admin)
    code, res, _ = run_as_user_json(admin, f"public.create_work_schedule('{per}')")
    sched_id = res['schedule_id']
    code, out, _ = run_psql(f"SELECT id FROM public.work_schedule_shifts WHERE work_schedule_id = '{sched_id}' LIMIT 1;")
    shift_id = out.strip()
    
    run_psql(f"UPDATE public.work_schedules SET status = 'ARCHIVED' WHERE id = '{sched_id}';")
    
    code, res, err = run_as_user_json(admin, f"public.assign_employee_to_shift('{shift_id}', '{mem}', 1, true, 'Arch')")
    assert code != 0 and "ARCHIVED" in err

def main():
    print("="*70)
    print("STARTING PHASE 3 INDEPENDENT ADVERSARIAL AUDIT V2 (45 SCENARIOS)")
    print("="*70)
    setup_fresh_db()
    
    runner.run("01 Clean Migration Chain Verification", test_01_clean_migration_chain)
    runner.run("02 Migration History & Enums", test_02_migration_enums)
    runner.run("03 Arbitrary Template Generation (N=1,2,3,5,10)", test_03_arbitrary_template_generation)
    runner.run("04 Frozen Template Snapshot Integrity vs Live Edits", test_04_frozen_template_snapshot_integrity)
    runner.run("05 Same-Station Exact Duplicate Assignment Defense", test_05_same_station_exact_duplicate_overlap)
    runner.run("06 Same-Station Partial Overlap Defense", test_06_same_station_partial_overlap)
    runner.run("07 Adjacent Shift Non-Overlap Allowed", test_07_adjacent_non_overlap)
    runner.run("08 Cross-Midnight Shift Overlap Defense", test_08_cross_midnight_overlap)
    runner.run("09 Multi-Station Overlap Prevention", test_09_cross_station_overlap)
    runner.run("10 Cross-Station Privacy & Sanitization", test_10_cross_station_privacy)
    runner.run("11 Concurrent Cross-Station Assignment Race", test_11_concurrent_cross_station_assignment_race)
    runner.run("12 Repeated Cross-Station Race Loops", test_12_repeated_cross_station_races)
    runner.run("13 OCC: Assign vs Assign Race", test_13_occ_assign_vs_assign)
    runner.run("14 OCC: Assign vs Remove Race", test_14_occ_assign_vs_remove)
    runner.run("15 OCC: Move vs Move Race", test_15_occ_move_vs_move)
    runner.run("16 OCC: Move vs Remove Race", test_16_occ_move_vs_remove)
    runner.run("17 OCC: Staffing vs Publish Race", test_17_occ_staffing_vs_publish)
    runner.run("18 OCC: Double Publish Race", test_18_occ_double_publish)
    runner.run("19 Failed Mutation Version Preservation", test_19_failed_mutation_version_preservation)
    runner.run("20 Move Rollback Atomicity", test_20_move_rollback_atomicity)
    runner.run("21 Unavailable Without Override Blocked", test_21_unavailable_without_override)
    runner.run("22 Invalid Override Reason Sanitization", test_22_invalid_override_reason)
    runner.run("23 Not-Submitted Availability Semantics", test_23_not_submitted_semantics)
    runner.run("24 Pre-Publish Availability Drift Detection", test_24_availability_drift_detection)
    runner.run("25 Inactive Membership Pre-Publish Lockout", test_25_inactive_membership_pre_publish)
    runner.run("26 Suspended Membership Pre-Publish Lockout", test_26_suspended_membership_pre_publish)
    runner.run("27 Direct Assignment Insert Bypass Attack", test_27_direct_assignment_insert_bypass)
    runner.run("28 Direct Schedule Publish Bypass Attack", test_28_direct_schedule_publish_bypass)
    runner.run("29 Direct Version Mutation Bypass Attack", test_29_direct_version_mutation_bypass)
    runner.run("30 Ledger Forgery Attack", test_30_ledger_forgery_attempt)
    runner.run("31 Ledger Mutation / Deletion Attack", test_31_ledger_mutation_deletion_attempt)
    runner.run("32 Schedule Creation Concurrency Race", test_32_schedule_creation_race)
    runner.run("33 Candidate Search SQL Injection & Wildcard Attack", test_33_candidate_search_sanitization)
    runner.run("34 Candidate Filter Correctness", test_34_candidate_filter_correctness)
    runner.run("35 Candidate Scale Benchmark (100+ members <100ms)", test_35_candidate_scale_benchmark)
    runner.run("36 Timezone & DST Spring Transition", test_36_dst_spring_transition)
    runner.run("37 Timezone & DST Fall Transition", test_37_dst_fall_transition)
    runner.run("38 Cross-Midnight Across Multiple Timezones", test_38_cross_midnight_across_timezones)
    runner.run("39 Employee Draft Invisibility", test_39_employee_draft_invisibility)
    runner.run("40 Employee Foreign Assignment Invisibility", test_40_employee_foreign_assignment_invisibility)
    runner.run("41 Published Revision Reason Required", test_41_published_revision_reason_required)
    runner.run("42 Original Publication Metadata Immutability", test_42_original_publication_metadata_immutability)
    runner.run("43 Anonymous Access Lockout", test_43_anonymous_access_lockout)
    runner.run("44 SECURITY DEFINER Grants & Search Path", test_44_security_definer_grants_and_search_path)
    runner.run("45 Archive Lifecycle & Mutation Lockout", test_45_archive_lifecycle)

    success = runner.summary()
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
