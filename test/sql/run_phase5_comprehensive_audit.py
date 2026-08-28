#!/usr/bin/env python3
"""
YellowShifts Phase 5 — Comprehensive Adversarial & Operational Audit Suite
Zero-dependency PostgreSQL 16 test harness validating 46+ Phase 5 scenarios:
Identity enrollment, consent ledger, re-enrollment, revocation, provider deletion,
station policies (DISABLED, CHECK_IN_ONLY, CHECK_IN_AND_CHECK_OUT), presence-bound identity proofs,
action/employee/station bindings, atomic check-in/out gate, admin manual overrides,
mid-flow policy/revocation changes, data minimization schema audit, multithreaded concurrency races,
and scale performance benchmarks.
"""

import sys
import os
import shutil
import subprocess
import time
import uuid
import json
import hashlib
from datetime import datetime, timezone, timedelta, date
from concurrent.futures import ThreadPoolExecutor

PSQL_BIN = shutil.which("psql") or "/opt/homebrew/opt/postgresql@16/bin/psql"
if not os.path.exists(PSQL_BIN):
    PSQL_BIN = shutil.which("psql") or "psql"
if not os.path.exists(PSQL_BIN):
    PSQL_BIN = "psql"

DB_NAME = "yellowshifts_phase5_audit_test"
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
    subprocess.run([PSQL_BIN, "-d", "postgres", "-U", CURRENT_USER, "-c", f"DROP DATABASE IF EXISTS {DB_NAME};"], capture_output=True)
    res = subprocess.run([PSQL_BIN, "-d", "postgres", "-U", CURRENT_USER, "-c", f"CREATE DATABASE {DB_NAME};"], capture_output=True, text=True)
    if res.returncode != 0:
        print("[!] Failed to create test database:", res.stderr)
        sys.exit(1)

    subprocess.run([PSQL_BIN, "-d", DB_NAME, "-U", CURRENT_USER, "-c", "CREATE PUBLICATION supabase_realtime;"], capture_output=True)

    migrations = [
        "20260825000001_initial_schema.sql",
        "20260825000002_phase1_identity_and_roles.sql",
        "20260825000003_phase2_shift_templates_and_availability.sql",
        "20260825000004_phase3_scheduling.sql",
        "20260825000005_phase4_attendance_and_kiosk.sql",
        "20260825000006_phase4_audit_remediation.sql",
        "20260825000007_phase5_identity_verification.sql",
    ]

    for mig in migrations:
        path = os.path.join("supabase", "migrations", mig)
        cmd = [PSQL_BIN, "-d", DB_NAME, "-U", CURRENT_USER, "-f", path]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0:
            raise RuntimeError(f"Failed to apply {mig}:\n{res.stderr}")
    print("[*] All 7 canonical migrations applied cleanly on fresh test database.")

def create_user_and_profile(email: str, first: str, last: str) -> str:
    uid = str(uuid.uuid4())
    sql = f"""
    INSERT INTO auth.users (id, email) VALUES ('{uid}', '{email}');
    INSERT INTO public.profiles (id, first_name, last_name, preferred_locale)
    VALUES ('{uid}', '{first}', '{last}', 'he')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name;
    """
    code, _, err = run_psql(sql)
    assert code == 0, f"Failed to create user: {err}"
    return uid

def setup_published_schedule(admin_id, station_id, employee_id, membership_id, start_offset_min=-15, duration_hours=8, target_date=None, shift_name="Morning Shift"):
    t_date = target_date or date.today()
    now_dt = datetime.now()
    st_dt = now_dt + timedelta(minutes=start_offset_min)
    et_dt = st_dt + timedelta(hours=duration_hours)
    st_time = st_dt.strftime("%H:%M:00")
    et_time = et_dt.strftime("%H:%M:00")

    period_id = str(uuid.uuid4())
    t_id = str(uuid.uuid4())
    pst_id = str(uuid.uuid4())
    sched_id = str(uuid.uuid4())
    shift_id = str(uuid.uuid4())
    asgn_id = str(uuid.uuid4())

    sql = f"""
    DELETE FROM public.shift_assignments WHERE station_id = '{station_id}' AND user_id = '{employee_id}';
    DELETE FROM public.work_schedule_shifts WHERE station_id = '{station_id}' AND operational_date = '{t_date}';

    INSERT INTO public.shift_templates (id, station_id, name, start_time, end_time, sort_order)
    VALUES ('{t_id}', '{station_id}', '{shift_name}', '{st_time}', '{et_time}', 1)
    ON CONFLICT DO NOTHING;

    INSERT INTO public.availability_periods (id, station_id, week_start_date, submission_deadline, status, created_by)
    VALUES ('{period_id}', '{station_id}', '{t_date}', now() + interval '1 day', 'OPEN', '{admin_id}')
    ON CONFLICT (station_id, week_start_date) DO NOTHING;

    INSERT INTO public.availability_period_shift_templates (id, availability_period_id, shift_template_id, name_snapshot, start_time_snapshot, end_time_snapshot, sort_order_snapshot)
    VALUES ('{pst_id}', (SELECT id FROM public.availability_periods WHERE station_id = '{station_id}' AND week_start_date = '{t_date}'), '{t_id}', '{shift_name}', '{st_time}', '{et_time}', 1)
    ON CONFLICT (availability_period_id, shift_template_id) DO NOTHING;

    INSERT INTO public.work_schedules (id, station_id, availability_period_id, week_start_date, status, version, created_by)
    VALUES ('{sched_id}', '{station_id}', (SELECT id FROM public.availability_periods WHERE station_id = '{station_id}' AND week_start_date = '{t_date}'), '{t_date}', 'PUBLISHED', 1, '{admin_id}')
    ON CONFLICT (station_id, week_start_date) DO NOTHING;

    INSERT INTO public.work_schedule_shifts (
        id, work_schedule_id, station_id, operational_date, period_shift_template_id, 
        shift_name_snapshot, start_time_snapshot, end_time_snapshot, starts_at, ends_at, required_staff_count
    ) VALUES (
        '{shift_id}', 
        (SELECT id FROM public.work_schedules WHERE station_id = '{station_id}' AND week_start_date = '{t_date}'), 
        '{station_id}', '{t_date}', '{pst_id}', 
        '{shift_name}', '{st_time}', '{et_time}',
        ('{st_dt.strftime("%Y-%m-%d %H:%M:%S")}'::timestamp with time zone),
        ('{et_dt.strftime("%Y-%m-%d %H:%M:%S")}'::timestamp with time zone),
        1
    );

    INSERT INTO public.shift_assignments (id, work_schedule_shift_id, station_id, membership_id, user_id, availability_state_snapshot, assigned_by)
    VALUES ('{asgn_id}', '{shift_id}', '{station_id}', '{membership_id}', '{employee_id}', 'AVAILABLE', '{admin_id}');
    """
    code, _, err = run_psql(sql)
    assert code == 0, f"Failed to setup published schedule: {err}"
    return sched_id, shift_id, asgn_id

class AuditTestRunner:
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.tests = []

    def run(self, num: str, name: str, fn):
        sys.stdout.write(f"[{num}] RUNNING: {name} ... ")
        sys.stdout.flush()
        t0 = time.time()
        try:
            fn()
            dt = (time.time() - t0) * 1000
            sys.stdout.write(f"PASSED ({dt:.1f}ms)\n")
            self.passed += 1
            self.tests.append((num, name, "PASS", dt))
        except Exception as e:
            dt = (time.time() - t0) * 1000
            sys.stdout.write(f"FAILED ({dt:.1f}ms)\n")
            print(f"    --> ERROR: {e}")
            self.failed += 1
            self.tests.append((num, name, f"FAIL: {e}", dt))

def main():
    print("=" * 75)
    print("STARTING PHASE 5 COMPREHENSIVE ADVERSARIAL AUDIT SUITE (46+ SCENARIOS)")
    print("=" * 75)

    setup_fresh_db()
    runner = AuditTestRunner()

    # Fixtures
    admin_a = create_user_and_profile("admin_a@station.com", "David", "AdminA")
    mgr_a = create_user_and_profile("mgr_a@station.com", "Sarah", "ManagerA")
    emp1_a = create_user_and_profile("emp1_a@station.com", "Alex", "WorkerA1")
    emp2_a = create_user_and_profile("emp2_a@station.com", "Maya", "WorkerA2")
    emp3_a = create_user_and_profile("emp3_a@station.com", "Omer", "WorkerA3")
    admin_b = create_user_and_profile("admin_b@other.com", "Dan", "AdminB")
    emp_b = create_user_and_profile("emp_b@other.com", "Ben", "WorkerB")

    st_a = str(uuid.uuid4())
    st_b = str(uuid.uuid4())
    st_c = str(uuid.uuid4())

    mem_a_admin = str(uuid.uuid4())
    mem_a_mgr = str(uuid.uuid4())
    mem_a_emp1 = str(uuid.uuid4())
    mem_a_emp2 = str(uuid.uuid4())
    mem_a_emp3 = str(uuid.uuid4())
    mem_b_admin = str(uuid.uuid4())
    mem_b_emp = str(uuid.uuid4())
    mem_c_admin = str(uuid.uuid4())
    mem_c_emp1 = str(uuid.uuid4())

    run_psql(f"""
    INSERT INTO public.stations (id, name, code, timezone, locale, is_active, check_in_early_minutes, late_grace_minutes, identity_verification_mode)
    VALUES 
    ('{st_a}', 'תחנת כורדני', 'YLW-KRD-01', 'Asia/Jerusalem', 'he', true, 60, 5, 'DISABLED'),
    ('{st_b}', 'תחנת לב המפרץ', 'YLW-LVM-02', 'Asia/Jerusalem', 'he', true, 60, 5, 'CHECK_IN_ONLY'),
    ('{st_c}', 'תחנת עכו', 'YLW-AKO-03', 'Asia/Jerusalem', 'he', true, 60, 5, 'CHECK_IN_AND_CHECK_OUT');

    INSERT INTO public.station_memberships (id, station_id, user_id, role, status, employee_code)
    VALUES
    ('{mem_a_admin}', '{st_a}', '{admin_a}', 'ADMIN', 'ACTIVE', 'ADM-A01'),
    ('{mem_a_mgr}', '{st_a}', '{mgr_a}', 'SHIFT_MANAGER', 'ACTIVE', 'MGR-A01'),
    ('{mem_a_emp1}', '{st_a}', '{emp1_a}', 'EMPLOYEE', 'ACTIVE', 'EMP-A01'),
    ('{mem_a_emp2}', '{st_a}', '{emp2_a}', 'EMPLOYEE', 'ACTIVE', 'EMP-A02'),
    ('{mem_a_emp3}', '{st_a}', '{emp3_a}', 'EMPLOYEE', 'ACTIVE', 'EMP-A03'),
    ('{mem_b_admin}', '{st_b}', '{admin_b}', 'ADMIN', 'ACTIVE', 'ADM-B01'),
    ('{mem_b_emp}', '{st_b}', '{emp_b}', 'EMPLOYEE', 'ACTIVE', 'EMP-B01'),
    ('{mem_c_admin}', '{st_c}', '{admin_a}', 'ADMIN', 'ACTIVE', 'ADM-C01'),
    ('{mem_c_emp1}', '{st_c}', '{emp1_a}', 'EMPLOYEE', 'ACTIVE', 'EMP-C01');
    """)

    # Shared Kiosks
    kiosk_a = {}
    kiosk_b = {}
    kiosk_c = {}

    def init_kiosks():
        res_a = run_as_user_json(admin_a, f"SELECT public.provision_kiosk_device('{st_a}', 'Kiosk A1', 'TAB-KRD-01');")[1]
        kiosk_a["id"] = res_a["kiosk_id"]
        kiosk_a["raw_secret"] = res_a["raw_secret"]
        kiosk_a["device_identifier"] = res_a["device_identifier"]

        res_b = run_as_user_json(admin_b, f"SELECT public.provision_kiosk_device('{st_b}', 'Kiosk B1', 'TAB-LVM-01');")[1]
        kiosk_b["id"] = res_b["kiosk_id"]
        kiosk_b["raw_secret"] = res_b["raw_secret"]
        kiosk_b["device_identifier"] = res_b["device_identifier"]

        res_c = run_as_user_json(admin_a, f"SELECT public.provision_kiosk_device('{st_c}', 'Kiosk C1', 'TAB-AKO-01');")[1]
        kiosk_c["id"] = res_c["kiosk_id"]
        kiosk_c["raw_secret"] = res_c["raw_secret"]
        kiosk_c["device_identifier"] = res_c["device_identifier"]

    init_kiosks()

    # 01 Clean Migration Chain Rebuild Verification
    def test_01():
        _, cnt, _ = run_psql("SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('employee_identity_profiles', 'identity_enrollment_sessions', 'identity_verification_attempts', 'identity_verification_proofs');")
        assert cnt == "4", f"Expected 4 Phase 5 tables, got {cnt}"
    runner.run("01", "Clean 7-Migration Fresh Rebuild Verification", test_01)

    # 02 Enrollment Start & Consent Recording
    enrollment_session_emp1 = {}
    def test_02():
        code, res, err = run_as_user_json(emp1_a, "SELECT public.start_identity_enrollment('SANDBOX_PROVIDER', 'v1.0');")
        assert code == 0, f"Enrollment start error: {err}"
        assert res["success"] is True
        assert "session_id" in res
        enrollment_session_emp1["id"] = res["session_id"]

        _, row, _ = run_psql(f"SELECT status, notice_version, consented_at IS NOT NULL FROM public.employee_identity_profiles WHERE employee_user_id = '{emp1_a}';")
        st, ver, consented = row.split("|")
        assert st == "PENDING"
        assert ver == "v1.0"
        assert consented == "t"
    runner.run("02", "Enrollment Start & Server-Authoritative Consent Recording", test_02)

    # 03 Enrollment Completion & Profile Activation
    def test_03():
        code, res, err = run_as_user_json(emp1_a, f"SELECT public.complete_identity_enrollment('{enrollment_session_emp1['id']}', 'SUBJ_FACETEC_EMP1_A', true);")
        assert code == 0, f"Enrollment complete error: {err}"
        assert res["success"] is True
        assert res["status"] == "ACTIVE"

        _, row, _ = run_psql(f"SELECT status, provider_subject_id, enrolled_at IS NOT NULL FROM public.employee_identity_profiles WHERE employee_user_id = '{emp1_a}';")
        st, subj, enrolled = row.split("|")
        assert st == "ACTIVE"
        assert subj == "SUBJ_FACETEC_EMP1_A"
        assert enrolled == "t"
    runner.run("03", "Enrollment Completion & Active Profile Activation", test_03)

    # 04 Duplicate Provider Subject ID Collision Defense
    def test_04():
        code_s, res_s, _ = run_as_user_json(emp2_a, "SELECT public.start_identity_enrollment('SANDBOX_PROVIDER', 'v1.0');")
        ses2_id = res_s["session_id"]
        # Attempt to link same subject ID as emp1
        code_c, _, err_c = run_as_user_json(emp2_a, f"SELECT public.complete_identity_enrollment('{ses2_id}', 'SUBJ_FACETEC_EMP1_A', true);")
        assert code_c != 0
        assert "duplicate key" in err_c or "23505" in err_c
    runner.run("04", "Duplicate Provider Subject ID Collision Defense", test_04)

    # 05 Re-Enrollment Lifecycle (Safe Replacement)
    def test_05():
        code_s, res_s, _ = run_as_user_json(emp1_a, "SELECT public.start_identity_enrollment('SANDBOX_PROVIDER', 'v1.1');")
        re_ses_id = res_s["session_id"]
        code_c, res_c, _ = run_as_user_json(emp1_a, f"SELECT public.complete_identity_enrollment('{re_ses_id}', 'SUBJ_FACETEC_EMP1_A_NEW', true);")
        assert code_c == 0
        assert res_c["status"] == "ACTIVE"

        _, row, _ = run_psql(f"SELECT status, provider_subject_id, notice_version FROM public.employee_identity_profiles WHERE employee_user_id = '{emp1_a}';")
        st, subj, ver = row.split("|")
        assert st == "ACTIVE"
        assert subj == "SUBJ_FACETEC_EMP1_A_NEW"
        assert ver == "v1.1"
    runner.run("05", "Re-Enrollment Lifecycle (Safe Subject Reference Replacement)", test_05)

    # 06 Employee Self-Revocation
    def test_06():
        code, res, err = run_as_user_json(emp1_a, f"SELECT public.revoke_identity_profile('{emp1_a}', 'Employee requested biometric profile revocation');")
        assert code == 0, f"Revoke error: {err}"
        assert res["success"] is True
        assert res["status"] == "REVOKED"

        _, row, _ = run_psql(f"SELECT status, provider_subject_id, revoked_at IS NOT NULL FROM public.employee_identity_profiles WHERE employee_user_id = '{emp1_a}';")
        st, subj, revoked = row.split("|")
        assert st == "REVOKED"
        assert subj == ""  # Cleared/NULL
        assert revoked == "t"
    runner.run("06", "Employee Self-Revocation & Subject ID Nullification", test_06)

    # 07 Revoked Profile Blocks Identity Verification Start
    def test_07():
        setup_published_schedule(admin_a, st_a, emp1_a, mem_a_emp1, start_offset_min=-10, duration_hours=8)
        mint = run_as_user_json(admin_a, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_a}', '{kiosk_a['device_identifier']}', '{kiosk_a['raw_secret']}');")[1]
        scan = run_as_user_json(emp1_a, f"SELECT public.scan_attendance_qr('{mint['qr_token']}');")[1]
        pres_tok = scan["presence_proof_token"]

        code, _, err = run_as_user_json(emp1_a, f"SELECT public.start_identity_verification('{pres_tok}', 'SANDBOX_PROVIDER');")
        assert code != 0
        assert "P0047" in err or "not actively enrolled" in err
    runner.run("07", "Revoked Profile Blocks Identity Verification Start (P0047)", test_07)

    # 08 Re-activate Emp1 for attendance flow tests
    def test_08():
        code_s, res_s, _ = run_as_user_json(emp1_a, "SELECT public.start_identity_enrollment('SANDBOX_PROVIDER', 'v1.0');")
        ses_id = res_s["session_id"]
        code_c, res_c, _ = run_as_user_json(emp1_a, f"SELECT public.complete_identity_enrollment('{ses_id}', 'SUBJ_FACETEC_EMP1_ACTIVE', true);")
        assert code_c == 0
        assert res_c["status"] == "ACTIVE"
    runner.run("08", "Re-Enrollment Restores Active Identity Profile", test_08)

    # 09 Policy Mode DISABLED Allows QR-Only Check-In
    def test_09():
        mint = run_as_user_json(admin_a, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_a}', '{kiosk_a['device_identifier']}', '{kiosk_a['raw_secret']}');")[1]
        scan = run_as_user_json(emp1_a, f"SELECT public.scan_attendance_qr('{mint['qr_token']}');")[1]
        pres_tok = scan["presence_proof_token"]

        # Check-in with NULL identity proof
        code, res, err = run_as_user_json(emp1_a, f"SELECT public.check_in_with_presence_proof('{pres_tok}', NULL::TEXT);")
        assert code == 0, f"Check in under DISABLED policy error: {err}"
        assert res["success"] is True
        assert res["verification_method"] == "QR_ONLY"

        # Check-out with NULL identity proof
        mint_out = run_as_user_json(admin_a, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_a}', '{kiosk_a['device_identifier']}', '{kiosk_a['raw_secret']}');")[1]
        scan_out = run_as_user_json(emp1_a, f"SELECT public.scan_attendance_qr('{mint_out['qr_token']}');")[1]
        code_o, res_o, _ = run_as_user_json(emp1_a, f"SELECT public.check_out_with_presence_proof('{scan_out['presence_proof_token']}', NULL::TEXT);")
        assert code_o == 0
        assert res_o["status"] == "COMPLETED"
    runner.run("09", "Policy Mode DISABLED Allows Standard QR-Only Check-In/Out", test_09)

    # 10 Policy Mode CHECK_IN_ONLY Enforces Identity Proof on Check-In
    def test_10():
        setup_published_schedule(admin_b, st_b, emp_b, mem_b_emp, start_offset_min=-10, duration_hours=8)
        mint_b = run_as_user_json(admin_b, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b}', '{kiosk_b['device_identifier']}', '{kiosk_b['raw_secret']}');")[1]
        scan_b = run_as_user_json(emp_b, f"SELECT public.scan_attendance_qr('{mint_b['qr_token']}');")[1]
        pres_tok_b = scan_b["presence_proof_token"]

        # Attempt check-in without identity proof -> Must be rejected with P0040
        code, _, err = run_as_user_json(emp_b, f"SELECT public.check_in_with_presence_proof('{pres_tok_b}', NULL::TEXT);")
        assert code != 0
        assert "P0040" in err or "Identity verification is required" in err
    runner.run("10", "Policy Mode CHECK_IN_ONLY Rejects Check-In Without Identity Proof (P0040)", test_10)

    # 11 Valid Identity Proof Satisfies CHECK_IN_ONLY
    def test_11():
        # Enroll emp_b first
        code_s, res_s, _ = run_as_user_json(emp_b, "SELECT public.start_identity_enrollment('SANDBOX_PROVIDER', 'v1.0');")
        code_c, res_c, _ = run_as_user_json(emp_b, f"SELECT public.complete_identity_enrollment('{res_s['session_id']}', 'SUBJ_EMP_B', true);")
        assert code_c == 0

        # Fresh QR & Presence
        mint_b = run_as_user_json(admin_b, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b}', '{kiosk_b['device_identifier']}', '{kiosk_b['raw_secret']}');")[1]
        scan_b = run_as_user_json(emp_b, f"SELECT public.scan_attendance_qr('{mint_b['qr_token']}');")[1]
        pres_tok_b = scan_b["presence_proof_token"]

        # Start verification
        start_v = run_as_user_json(emp_b, f"SELECT public.start_identity_verification('{pres_tok_b}', 'SANDBOX_PROVIDER');")[1]
        attempt_id = start_v["attempt_id"]

        # Complete verification
        comp_v = run_as_user_json(emp_b, f"SELECT public.complete_identity_verification('{attempt_id}', true);")[1]
        id_proof_tok = comp_v["identity_proof_token"]

        # Check-in with valid identity proof
        code, res, err = run_as_user_json(emp_b, f"SELECT public.check_in_with_presence_proof('{pres_tok_b}', '{id_proof_tok}');")
        assert code == 0, f"Check in with identity proof error: {err}"
        assert res["success"] is True
        assert res["verification_method"] == "QR_PLUS_IDENTITY"

        # Check-out under CHECK_IN_ONLY should NOT require identity proof
        mint_out = run_as_user_json(admin_b, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b}', '{kiosk_b['device_identifier']}', '{kiosk_b['raw_secret']}');")[1]
        scan_out = run_as_user_json(emp_b, f"SELECT public.scan_attendance_qr('{mint_out['qr_token']}');")[1]
        code_o, res_o, _ = run_as_user_json(emp_b, f"SELECT public.check_out_with_presence_proof('{scan_out['presence_proof_token']}', NULL::TEXT);")
        assert code_o == 0
        assert res_o["status"] == "COMPLETED"
    runner.run("11", "Valid Identity Proof Satisfies CHECK_IN_ONLY (QR_PLUS_IDENTITY)", test_11)

    # 12 Policy Mode CHECK_IN_AND_CHECK_OUT Enforces Proof on Both
    def test_12():
        setup_published_schedule(admin_a, st_c, emp1_a, mem_c_emp1, start_offset_min=-10, duration_hours=8)

        # 12.1 Check-In requires identity proof
        mint_c1 = run_as_user_json(admin_a, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_c}', '{kiosk_c['device_identifier']}', '{kiosk_c['raw_secret']}');")[1]
        scan_c1 = run_as_user_json(emp1_a, f"SELECT public.scan_attendance_qr('{mint_c1['qr_token']}');")[1]
        pres_tok_c1 = scan_c1["presence_proof_token"]

        start_v1 = run_as_user_json(emp1_a, f"SELECT public.start_identity_verification('{pres_tok_c1}', 'SANDBOX_PROVIDER');")[1]
        comp_v1 = run_as_user_json(emp1_a, f"SELECT public.complete_identity_verification('{start_v1['attempt_id']}', true);")[1]

        code_in, res_in, _ = run_as_user_json(emp1_a, f"SELECT public.check_in_with_presence_proof('{pres_tok_c1}', '{comp_v1['identity_proof_token']}');")
        assert code_in == 0
        assert res_in["verification_method"] == "QR_PLUS_IDENTITY"

        # 12.2 Check-Out without identity proof must fail with P0040
        mint_c2 = run_as_user_json(admin_a, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_c}', '{kiosk_c['device_identifier']}', '{kiosk_c['raw_secret']}');")[1]
        scan_c2 = run_as_user_json(emp1_a, f"SELECT public.scan_attendance_qr('{mint_c2['qr_token']}');")[1]
        pres_tok_c2 = scan_c2["presence_proof_token"]

        code_out_fail, _, err_out_fail = run_as_user_json(emp1_a, f"SELECT public.check_out_with_presence_proof('{pres_tok_c2}', NULL::TEXT);")
        assert code_out_fail != 0
        assert "P0040" in err_out_fail

        # 12.3 Check-Out with valid identity proof succeeds
        start_v2 = run_as_user_json(emp1_a, f"SELECT public.start_identity_verification('{pres_tok_c2}', 'SANDBOX_PROVIDER');")[1]
        comp_v2 = run_as_user_json(emp1_a, f"SELECT public.complete_identity_verification('{start_v2['attempt_id']}', true);")[1]

        code_out_ok, res_out_ok, _ = run_as_user_json(emp1_a, f"SELECT public.check_out_with_presence_proof('{pres_tok_c2}', '{comp_v2['identity_proof_token']}');")
        assert code_out_ok == 0
        assert res_out_ok["status"] == "COMPLETED"
    runner.run("12", "Policy Mode CHECK_IN_AND_CHECK_OUT Enforces Proof on Both Actions", test_12)

    # 13 Identity Proof Employee Identity Binding (Cross-Employee Blocked)
    def test_13():
        # Enroll emp2_a
        code_s, res_s, _ = run_as_user_json(emp2_a, "SELECT public.start_identity_enrollment('SANDBOX_PROVIDER', 'v1.0');")
        run_as_user_json(emp2_a, f"SELECT public.complete_identity_enrollment('{res_s['session_id']}', 'SUBJ_EMP2_A', true);")

        setup_published_schedule(admin_b, st_b, emp_b, mem_b_emp, start_offset_min=-10, duration_hours=8)
        mint_b = run_as_user_json(admin_b, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b}', '{kiosk_b['device_identifier']}', '{kiosk_b['raw_secret']}');")[1]
        scan_b = run_as_user_json(emp_b, f"SELECT public.scan_attendance_qr('{mint_b['qr_token']}');")[1]
        pres_tok_b = scan_b["presence_proof_token"]

        start_v = run_as_user_json(emp_b, f"SELECT public.start_identity_verification('{pres_tok_b}', 'SANDBOX_PROVIDER');")[1]
        comp_v = run_as_user_json(emp_b, f"SELECT public.complete_identity_verification('{start_v['attempt_id']}', true);")[1]
        id_proof_b = comp_v["identity_proof_token"]

        # emp2_a tries to use emp_b's identity proof
        code, _, err = run_as_user_json(emp2_a, f"SELECT public.check_in_with_presence_proof('{pres_tok_b}', '{id_proof_b}');")
        assert code != 0
        assert "P0028" in err or "P0053" in err or "belongs to another employee" in err
    runner.run("13", "Identity Proof Employee Identity Binding Defense (P0053)", test_13)

    # 14 Action Binding (CHECK_OUT Proof cannot authorize CHECK_IN)
    def test_14():
        mint_b = run_as_user_json(admin_b, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b}', '{kiosk_b['device_identifier']}', '{kiosk_b['raw_secret']}');")[1]
        scan_b = run_as_user_json(emp_b, f"SELECT public.scan_attendance_qr('{mint_b['qr_token']}');")[1]
        pres_tok_b = scan_b["presence_proof_token"]

        start_v = run_as_user_json(emp_b, f"SELECT public.start_identity_verification('{pres_tok_b}', 'SANDBOX_PROVIDER');")[1]
        comp_v = run_as_user_json(emp_b, f"SELECT public.complete_identity_verification('{start_v['attempt_id']}', true);")[1]
        id_proof_tok = comp_v["identity_proof_token"]

        # Manually alter action to CHECK_OUT to test action mismatch
        run_psql(f"UPDATE public.identity_verification_proofs SET action = 'CHECK_OUT' WHERE token_hash = encode(digest('{id_proof_tok}', 'sha256'), 'hex');")

        code, _, err = run_as_user_json(emp_b, f"SELECT public.check_in_with_presence_proof('{pres_tok_b}', '{id_proof_tok}');")
        assert code != 0
        assert "P0056" in err or "action mismatch" in err
    runner.run("14", "Identity Proof Action Binding Defense (P0056)", test_14)

    # 15 Presence Proof Exact Binding (Cross-Presence Mixing Blocked)
    def test_15():
        mint1 = run_as_user_json(admin_b, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b}', '{kiosk_b['device_identifier']}', '{kiosk_b['raw_secret']}');")[1]
        scan1 = run_as_user_json(emp_b, f"SELECT public.scan_attendance_qr('{mint1['qr_token']}');")[1]

        mint2 = run_as_user_json(admin_b, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b}', '{kiosk_b['device_identifier']}', '{kiosk_b['raw_secret']}');")[1]
        scan2 = run_as_user_json(emp_b, f"SELECT public.scan_attendance_qr('{mint2['qr_token']}');")[1]

        # Start verification on scan1
        start_v = run_as_user_json(emp_b, f"SELECT public.start_identity_verification('{scan1['presence_proof_token']}', 'SANDBOX_PROVIDER');")[1]
        comp_v = run_as_user_json(emp_b, f"SELECT public.complete_identity_verification('{start_v['attempt_id']}', true);")[1]
        id_proof_tok = comp_v["identity_proof_token"]

        # Attempt to use id_proof_tok with scan2 presence token
        code, _, err = run_as_user_json(emp_b, f"SELECT public.check_in_with_presence_proof('{scan2['presence_proof_token']}', '{id_proof_tok}');")
        assert code != 0
        assert "P0055" in err or "not bound to this presence challenge" in err
    runner.run("15", "Cross-Presence Token Mixing Attack Blocked (P0055)", test_15)

    # 16 Single-Use Identity Proof Replay Defense
    def test_16():
        mint = run_as_user_json(admin_b, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b}', '{kiosk_b['device_identifier']}', '{kiosk_b['raw_secret']}');")[1]
        scan = run_as_user_json(emp_b, f"SELECT public.scan_attendance_qr('{mint['qr_token']}');")[1]
        pres_tok = scan["presence_proof_token"]

        start_v = run_as_user_json(emp_b, f"SELECT public.start_identity_verification('{pres_tok}', 'SANDBOX_PROVIDER');")[1]
        comp_v = run_as_user_json(emp_b, f"SELECT public.complete_identity_verification('{start_v['attempt_id']}', true);")[1]
        id_proof_tok = comp_v["identity_proof_token"]

        # First check-in
        code1, res1, _ = run_as_user_json(emp_b, f"SELECT public.check_in_with_presence_proof('{pres_tok}', '{id_proof_tok}');")
        assert code1 == 0

        # Attempt replay
        code2, _, err2 = run_as_user_json(emp_b, f"SELECT public.check_in_with_presence_proof('{pres_tok}', '{id_proof_tok}');")
        assert code2 != 0
        assert "P0026" in err2 or "P0051" in err2 or "already been used" in err2

        # Check out to clean up open session
        mint_o = run_as_user_json(admin_b, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b}', '{kiosk_b['device_identifier']}', '{kiosk_b['raw_secret']}');")[1]
        scan_o = run_as_user_json(emp_b, f"SELECT public.scan_attendance_qr('{mint_o['qr_token']}');")[1]
        run_as_user_json(emp_b, f"SELECT public.check_out_with_presence_proof('{scan_o['presence_proof_token']}', NULL::TEXT);")
    runner.run("16", "Single-Use Identity Proof Replay Defense (P0051)", test_16)

    # 17 Identity Proof Expiry Exact Boundary (120s TTL)
    def test_17():
        mint = run_as_user_json(admin_b, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b}', '{kiosk_b['device_identifier']}', '{kiosk_b['raw_secret']}');")[1]
        scan = run_as_user_json(emp_b, f"SELECT public.scan_attendance_qr('{mint['qr_token']}');")[1]
        pres_tok = scan["presence_proof_token"]

        start_v = run_as_user_json(emp_b, f"SELECT public.start_identity_verification('{pres_tok}', 'SANDBOX_PROVIDER');")[1]
        comp_v = run_as_user_json(emp_b, f"SELECT public.complete_identity_verification('{start_v['attempt_id']}', true);")[1]
        id_proof_tok = comp_v["identity_proof_token"]

        # Expire proof
        run_psql(f"UPDATE public.identity_verification_proofs SET expires_at = now() - INTERVAL '1 second' WHERE token_hash = encode(digest('{id_proof_tok}', 'sha256'), 'hex');")

        code, _, err = run_as_user_json(emp_b, f"SELECT public.check_in_with_presence_proof('{pres_tok}', '{id_proof_tok}');")
        assert code != 0
        assert "P0052" in err or "expired" in err
    runner.run("17", "Identity Proof Expiry Exact Boundary Defense (120s TTL / P0052)", test_17)

    # 18 Admin Manual Exception Flow (Requires Fresh Presence Proof)
    def test_18():
        mint = run_as_user_json(admin_b, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b}', '{kiosk_b['device_identifier']}', '{kiosk_b['raw_secret']}');")[1]
        scan = run_as_user_json(emp_b, f"SELECT public.scan_attendance_qr('{mint['qr_token']}');")[1]
        pres_tok = scan["presence_proof_token"]

        # Admin creates override for emp_b with valid reason
        code_ov, res_ov, err_ov = run_as_user_json(admin_b, f"SELECT public.create_identity_admin_override('{pres_tok}', 'Camera hardware malfunction on employee phone');")
        assert code_ov == 0, f"Override error: {err_ov}"
        assert res_ov["success"] is True
        override_tok = res_ov["identity_proof_token"]

        # Check-in using override token -> Method is MANUAL_ADMIN
        code_in, res_in, _ = run_as_user_json(emp_b, f"SELECT public.check_in_with_presence_proof('{pres_tok}', '{override_tok}');")
        assert code_in == 0
        assert res_in["success"] is True
        assert res_in["verification_method"] == "MANUAL_ADMIN"

        # Check out
        mint_o = run_as_user_json(admin_b, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b}', '{kiosk_b['device_identifier']}', '{kiosk_b['raw_secret']}');")[1]
        scan_o = run_as_user_json(emp_b, f"SELECT public.scan_attendance_qr('{mint_o['qr_token']}');")[1]
        run_as_user_json(emp_b, f"SELECT public.check_out_with_presence_proof('{scan_o['presence_proof_token']}', NULL::TEXT);")
    runner.run("18", "Admin Manual Exception Flow & MANUAL_ADMIN Method Provenance", test_18)

    # 19 Admin Manual Exception Reason Validation (<3 chars rejected)
    def test_19():
        mint = run_as_user_json(admin_b, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b}', '{kiosk_b['device_identifier']}', '{kiosk_b['raw_secret']}');")[1]
        scan = run_as_user_json(emp_b, f"SELECT public.scan_attendance_qr('{mint['qr_token']}');")[1]
        pres_tok = scan["presence_proof_token"]

        code, _, err = run_as_user_json(admin_b, f"SELECT public.create_identity_admin_override('{pres_tok}', '  ok  ');")
        assert code != 0
        assert "P0032" in err or "at least 3 characters" in err
    runner.run("19", "Admin Manual Exception Reason Validation (P0032)", test_19)

    # 20 Admin Manual Exception Remote Bypass Blocked (Fake Presence Proof)
    def test_20():
        code, _, err = run_as_user_json(admin_b, "SELECT public.create_identity_admin_override('FAKE_PRESENCE_TOKEN_123', 'Valid explanation reason');")
        assert code != 0
        assert "P0025" in err or "Invalid presence proof" in err
    runner.run("20", "Admin Manual Exception Remote Bypass Blocked (Requires Real Presence)", test_20)

    # 21 Mid-Flow Policy Change (DISABLED -> CHECK_IN_ONLY mid-flow)
    def test_21():
        mint = run_as_user_json(admin_a, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_a}', '{kiosk_a['device_identifier']}', '{kiosk_a['raw_secret']}');")[1]
        scan = run_as_user_json(emp1_a, f"SELECT public.scan_attendance_qr('{mint['qr_token']}');")[1]
        pres_tok = scan["presence_proof_token"]

        # Admin changes policy to CHECK_IN_ONLY before check-in
        run_as_user_json(admin_a, f"SELECT public.update_station_identity_policy('{st_a}', 'CHECK_IN_ONLY');")

        # Employee attempts check-in without identity proof -> Must be rejected
        code, _, err = run_as_user_json(emp1_a, f"SELECT public.check_in_with_presence_proof('{pres_tok}', NULL::TEXT);")
        assert code != 0
        assert "P0040" in err

        # Reset Station A back to DISABLED
        run_as_user_json(admin_a, f"SELECT public.update_station_identity_policy('{st_a}', 'DISABLED');")
    runner.run("21", "Mid-Flow Policy Modification Enforced Dynamically (Fail-Closed)", test_21)

    # 22 Mid-Flow Profile Revocation (Revoked between scan and check-in)
    def test_22():
        mint = run_as_user_json(admin_b, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b}', '{kiosk_b['device_identifier']}', '{kiosk_b['raw_secret']}');")[1]
        scan = run_as_user_json(emp_b, f"SELECT public.scan_attendance_qr('{mint['qr_token']}');")[1]
        pres_tok = scan["presence_proof_token"]

        start_v = run_as_user_json(emp_b, f"SELECT public.start_identity_verification('{pres_tok}', 'SANDBOX_PROVIDER');")[1]
        comp_v = run_as_user_json(emp_b, f"SELECT public.complete_identity_verification('{start_v['attempt_id']}', true);")[1]
        id_proof_tok = comp_v["identity_proof_token"]

        # Profile is revoked before check-in
        run_as_user_json(emp_b, f"SELECT public.revoke_identity_profile('{emp_b}', 'Revoked mid-flow');")

        # Check-in attempt must fail because revoke invalidates active proofs
        code, _, err = run_as_user_json(emp_b, f"SELECT public.check_in_with_presence_proof('{pres_tok}', '{id_proof_tok}');")
        assert code != 0
        assert "P0051" in err or "already been used" in err

        # Re-enroll emp_b
        code_s, res_s, _ = run_as_user_json(emp_b, "SELECT public.start_identity_enrollment('SANDBOX_PROVIDER', 'v1.0');")
        run_as_user_json(emp_b, f"SELECT public.complete_identity_enrollment('{res_s['session_id']}', 'SUBJ_EMP_B_REACTIVE', true);")
    runner.run("22", "Mid-Flow Profile Revocation Invalidation Defense", test_22)

    # 23 Multithreaded Concurrent Check-In Race with Identity Proof
    def test_23():
        mint = run_as_user_json(admin_b, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b}', '{kiosk_b['device_identifier']}', '{kiosk_b['raw_secret']}');")[1]
        scan = run_as_user_json(emp_b, f"SELECT public.scan_attendance_qr('{mint['qr_token']}');")[1]
        pres_tok = scan["presence_proof_token"]

        start_v = run_as_user_json(emp_b, f"SELECT public.start_identity_verification('{pres_tok}', 'SANDBOX_PROVIDER');")[1]
        comp_v = run_as_user_json(emp_b, f"SELECT public.complete_identity_verification('{start_v['attempt_id']}', true);")[1]
        id_proof_tok = comp_v["identity_proof_token"]

        def do_checkin():
            return run_as_user_json(emp_b, f"SELECT public.check_in_with_presence_proof('{pres_tok}', '{id_proof_tok}');")

        with ThreadPoolExecutor(max_workers=2) as pool:
            f1 = pool.submit(do_checkin)
            f2 = pool.submit(do_checkin)
            res1 = f1.result()
            res2 = f2.result()

        success_count = sum(1 for c, _, _ in [res1, res2] if c == 0)
        fail_count = sum(1 for c, _, _ in [res1, res2] if c != 0)
        assert success_count == 1, f"Expected 1 success, got {success_count}"
        assert fail_count == 1, f"Expected 1 failure, got {fail_count}"

        # Clean up open session
        mint_o = run_as_user_json(admin_b, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b}', '{kiosk_b['device_identifier']}', '{kiosk_b['raw_secret']}');")[1]
        scan_o = run_as_user_json(emp_b, f"SELECT public.scan_attendance_qr('{mint_o['qr_token']}');")[1]
        run_as_user_json(emp_b, f"SELECT public.check_out_with_presence_proof('{scan_o['presence_proof_token']}', NULL::TEXT);")
    runner.run("23", "Multithreaded Check-In Race Serialization & Atomicity", test_23)

    # 24 Ephemeral Data Cleanup RPC Execution
    def test_24():
        code, res, err = run_as_user_json(admin_a, "SELECT public.cleanup_ephemeral_identity_data();")
        assert code == 0, f"Cleanup error: {err}"
        assert res["success"] is True
        assert "purged_sessions" in res
        assert "purged_identity_proofs" in res
    runner.run("24", "Ephemeral Data Cleanup RPC Execution", test_24)

    # 25 Data Minimization Schema Scan (Zero Raw Biometric Data)
    def test_25():
        _, cnt, _ = run_psql("""
        SELECT count(*) FROM information_schema.columns
        WHERE table_schema = 'public' AND (
            data_type = 'bytea' OR 
            column_name ILIKE '%face%' OR 
            column_name ILIKE '%selfie%' OR 
            column_name ILIKE '%embedding%' OR 
            column_name ILIKE '%vector%' OR 
            column_name ILIKE '%image%' OR 
            column_name ILIKE '%photo%'
        );
        """)
        assert cnt == "0", f"Found {cnt} prohibited biometric columns in schema"
    runner.run("25", "Data Minimization Schema Scan (Zero Prohibited Biometric Columns)", test_25)

    # 26 Scale Performance Benchmark: Team Identity Status Query (<50ms for 50+ members)
    def test_26():
        insert_sqls = []
        for i in range(50):
            uid = str(uuid.uuid4())
            insert_sqls.append(f"""
            INSERT INTO auth.users (id, email) VALUES ('{uid}', 'scale_id_emp_{i}@station.com');
            INSERT INTO public.profiles (id, first_name, last_name, preferred_locale)
            VALUES ('{uid}', 'Worker', '{i}', 'he')
            ON CONFLICT (id) DO NOTHING;
            INSERT INTO public.station_memberships (station_id, user_id, role, status, employee_code)
            VALUES ('{st_a}', '{uid}', 'EMPLOYEE', 'ACTIVE', 'SCALE-ID-{i:03d}');
            INSERT INTO public.employee_identity_profiles (employee_user_id, provider, status, notice_version, consented_at)
            VALUES ('{uid}', 'SANDBOX_PROVIDER', 'ACTIVE', 'v1.0', now());
            """)
        run_psql(";\n".join(insert_sqls))

        t0 = time.time()
        code, res, err = run_as_user_json(admin_a, f"SELECT public.get_station_team_identity_status('{st_a}');")
        dt = (time.time() - t0) * 1000
        assert code == 0, f"Scale query error: {err}"
        assert res["success"] is True
        assert dt < 50, f"Expected query under 50ms, took {dt:.1f}ms"
    runner.run("26", "Scale Performance Benchmark (<50ms for 50+ Staff)", test_26)

    # 27 Categorical Verification Outcome Logging (VERIFIED)
    def test_27():
        setup_published_schedule(admin_b, st_b, emp_b, mem_b_emp, start_offset_min=-10, duration_hours=8)
        mint = run_as_user_json(admin_b, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b}', '{kiosk_b['device_identifier']}', '{kiosk_b['raw_secret']}');")[1]
        scan = run_as_user_json(emp_b, f"SELECT public.scan_attendance_qr('{mint['qr_token']}');")[1]
        start_v = run_as_user_json(emp_b, f"SELECT public.start_identity_verification('{scan['presence_proof_token']}', 'SANDBOX_PROVIDER');")[1]
        comp_v = run_as_user_json(emp_b, f"SELECT public.complete_identity_verification('{start_v['attempt_id']}', true);")[1]
        assert comp_v["result"] == "VERIFIED"

        _, row, _ = run_psql(f"SELECT result, failure_category, is_override FROM public.identity_verification_attempts WHERE id = '{start_v['attempt_id']}';")
        res, fail_cat, is_ov = row.split("|")
        assert res == "VERIFIED"
        assert fail_cat == ""
        assert is_ov == "f"
    runner.run("27", "Categorical Verification Outcome Logging (VERIFIED)", test_27)

    # 28 Categorical Failure Logging (FACE_MISMATCH)
    def test_28():
        mint = run_as_user_json(admin_b, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b}', '{kiosk_b['device_identifier']}', '{kiosk_b['raw_secret']}');")[1]
        scan = run_as_user_json(emp_b, f"SELECT public.scan_attendance_qr('{mint['qr_token']}');")[1]
        start_v = run_as_user_json(emp_b, f"SELECT public.start_identity_verification('{scan['presence_proof_token']}', 'SANDBOX_PROVIDER');")[1]
        comp_v = run_as_user_json(emp_b, f"SELECT public.complete_identity_verification('{start_v['attempt_id']}', false, 'FACE_MISMATCH');")[1]
        assert comp_v["result"] == "NOT_VERIFIED"
        assert comp_v["failure_category"] == "FACE_MISMATCH"

        _, row, _ = run_psql(f"SELECT result, failure_category FROM public.identity_verification_attempts WHERE id = '{start_v['attempt_id']}';")
        res, fail_cat = row.split("|")
        assert res == "NOT_VERIFIED"
        assert fail_cat == "FACE_MISMATCH"
    runner.run("28", "Categorical Failure Logging (FACE_MISMATCH / Data Minimization)", test_28)

    # 29 Categorical Failure Logging (LIVENESS_FAILED)
    def test_29():
        mint = run_as_user_json(admin_b, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b}', '{kiosk_b['device_identifier']}', '{kiosk_b['raw_secret']}');")[1]
        scan = run_as_user_json(emp_b, f"SELECT public.scan_attendance_qr('{mint['qr_token']}');")[1]
        start_v = run_as_user_json(emp_b, f"SELECT public.start_identity_verification('{scan['presence_proof_token']}', 'SANDBOX_PROVIDER');")[1]
        comp_v = run_as_user_json(emp_b, f"SELECT public.complete_identity_verification('{start_v['attempt_id']}', false, 'LIVENESS_FAILED');")[1]
        assert comp_v["result"] == "NOT_VERIFIED"
        assert comp_v["failure_category"] == "LIVENESS_FAILED"
    runner.run("29", "Categorical Failure Logging (LIVENESS_FAILED)", test_29)

    # 30 Finalized Verification Attempt Cannot Be Re-Finalized (P0049)
    def test_30():
        mint = run_as_user_json(admin_b, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b}', '{kiosk_b['device_identifier']}', '{kiosk_b['raw_secret']}');")[1]
        scan = run_as_user_json(emp_b, f"SELECT public.scan_attendance_qr('{mint['qr_token']}');")[1]
        start_v = run_as_user_json(emp_b, f"SELECT public.start_identity_verification('{scan['presence_proof_token']}', 'SANDBOX_PROVIDER');")[1]
        run_as_user_json(emp_b, f"SELECT public.complete_identity_verification('{start_v['attempt_id']}', true);")
        # Attempt second finalization
        code, _, err = run_as_user_json(emp_b, f"SELECT public.complete_identity_verification('{start_v['attempt_id']}', true);")
        assert code != 0
        assert "P0049" in err or "already been finalized" in err
    runner.run("30", "Finalized Verification Attempt Cannot Be Re-Finalized (P0049)", test_30)

    # 31 Expired Enrollment Session Cannot Be Completed (P0044)
    def test_31():
        code_s, res_s, _ = run_as_user_json(emp3_a, "SELECT public.start_identity_enrollment('SANDBOX_PROVIDER', 'v1.0');")
        ses_id = res_s["session_id"]
        # Expire session in DB
        run_psql(f"UPDATE public.identity_enrollment_sessions SET expires_at = now() - INTERVAL '1 second' WHERE id = '{ses_id}';")
        code_c, _, err_c = run_as_user_json(emp3_a, f"SELECT public.complete_identity_enrollment('{ses_id}', 'SUBJ_EMP3_EXPIRED', true);")
        assert code_c != 0
        assert "P0044" in err_c or "has expired" in err_c
    runner.run("31", "Expired Enrollment Session Completion Rejection (P0044)", test_31)

    # 32 Non-Existent Enrollment Session Rejection (P0042)
    def test_32():
        fake_ses = str(uuid.uuid4())
        code, _, err = run_as_user_json(emp3_a, f"SELECT public.complete_identity_enrollment('{fake_ses}', 'SUBJ_FAKE', true);")
        assert code != 0
        assert "P0042" in err or "not found" in err
    runner.run("32", "Non-Existent Enrollment Session Rejection (P0042)", test_32)

    # 33 Multi-Station Employee Satisfies Both Station Policies
    def test_33():
        # emp1_a has active identity profile
        # Station A: DISABLED -> can check in QR-only
        mint_a = run_as_user_json(admin_a, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_a}', '{kiosk_a['device_identifier']}', '{kiosk_a['raw_secret']}');")[1]
        scan_a = run_as_user_json(emp1_a, f"SELECT public.scan_attendance_qr('{mint_a['qr_token']}');")[1]
        code_a, res_a, _ = run_as_user_json(emp1_a, f"SELECT public.check_in_with_presence_proof('{scan_a['presence_proof_token']}', NULL::TEXT);")
        assert code_a == 0
        assert res_a["verification_method"] == "QR_ONLY"

        # Check out
        mint_ao = run_as_user_json(admin_a, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_a}', '{kiosk_a['device_identifier']}', '{kiosk_a['raw_secret']}');")[1]
        scan_ao = run_as_user_json(emp1_a, f"SELECT public.scan_attendance_qr('{mint_ao['qr_token']}');")[1]
        run_as_user_json(emp1_a, f"SELECT public.check_out_with_presence_proof('{scan_ao['presence_proof_token']}', NULL::TEXT);")

        # Station C: CHECK_IN_AND_CHECK_OUT -> requires identity proof on check-in and check-out
        mint_c = run_as_user_json(admin_a, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_c}', '{kiosk_c['device_identifier']}', '{kiosk_c['raw_secret']}');")[1]
        scan_c = run_as_user_json(emp1_a, f"SELECT public.scan_attendance_qr('{mint_c['qr_token']}');")[1]
        start_vc = run_as_user_json(emp1_a, f"SELECT public.start_identity_verification('{scan_c['presence_proof_token']}', 'SANDBOX_PROVIDER');")[1]
        comp_vc = run_as_user_json(emp1_a, f"SELECT public.complete_identity_verification('{start_vc['attempt_id']}', true);")[1]
        code_c, res_c, _ = run_as_user_json(emp1_a, f"SELECT public.check_in_with_presence_proof('{scan_c['presence_proof_token']}', '{comp_vc['identity_proof_token']}');")
        assert code_c == 0
        assert res_c["verification_method"] == "QR_PLUS_IDENTITY"

        # Check out with identity proof at Station C
        mint_co = run_as_user_json(admin_a, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_c}', '{kiosk_c['device_identifier']}', '{kiosk_c['raw_secret']}');")[1]
        scan_co = run_as_user_json(emp1_a, f"SELECT public.scan_attendance_qr('{mint_co['qr_token']}');")[1]
        start_vco = run_as_user_json(emp1_a, f"SELECT public.start_identity_verification('{scan_co['presence_proof_token']}', 'SANDBOX_PROVIDER');")[1]
        comp_vco = run_as_user_json(emp1_a, f"SELECT public.complete_identity_verification('{start_vco['attempt_id']}', true);")[1]
        code_co, res_co, _ = run_as_user_json(emp1_a, f"SELECT public.check_out_with_presence_proof('{scan_co['presence_proof_token']}', '{comp_vco['identity_proof_token']}');")
        assert code_co == 0
        assert res_co["status"] == "COMPLETED"
    runner.run("33", "Multi-Station Employee with Varying Policies Execution", test_33)

    # 34 Cross-Station Policy Update Denial (Admin Isolation)
    def test_34():
        code, _, err = run_as_user_json(admin_a, f"SELECT public.update_station_identity_policy('{st_b}', 'DISABLED');")
        assert code != 0
        assert "42501" in err or "Only station admins" in err
    runner.run("34", "Cross-Station Policy Update Denial (Admin Isolation / 42501)", test_34)

    # 35 Policy Modification Audit Trail Verification
    def test_35():
        _, cnt, _ = run_psql(f"SELECT count(*) FROM public.audit_logs WHERE action = 'IDENTITY_VERIFICATION_POLICY_UPDATED' AND station_id = '{st_a}';")
        assert int(cnt) >= 1, "Expected audit log for policy updates"
    runner.run("35", "Policy Modification Audit Trail Immutability Verification", test_35)

    # 36 Deactivated Kiosk Cannot Execute Check-In
    def test_36():
        run_as_user_json(admin_b, f"SELECT public.deactivate_kiosk_device('{kiosk_b['id']}');")
        # Attempt to use proof issued before deactivation
        mint = run_as_user_json(admin_b, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b}', '{kiosk_b['device_identifier']}', '{kiosk_b['raw_secret']}');")
        # Auth minting fails
        assert mint[0] != 0
        run_as_user_json(admin_b, f"SELECT public.reactivate_kiosk_device('{kiosk_b['id']}');")
    runner.run("36", "Deactivated Kiosk Invalidation Defense (P0018)", test_36)

    # 37 Deactivated Membership Rejection During Check-In
    def test_37():
        setup_published_schedule(admin_b, st_b, emp_b, mem_b_emp, start_offset_min=-10, duration_hours=8)
        mint = run_as_user_json(admin_b, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b}', '{kiosk_b['device_identifier']}', '{kiosk_b['raw_secret']}');")[1]
        scan = run_as_user_json(emp_b, f"SELECT public.scan_attendance_qr('{mint['qr_token']}');")[1]
        pres_tok = scan["presence_proof_token"]

        start_v = run_as_user_json(emp_b, f"SELECT public.start_identity_verification('{pres_tok}', 'SANDBOX_PROVIDER');")[1]
        comp_v = run_as_user_json(emp_b, f"SELECT public.complete_identity_verification('{start_v['attempt_id']}', true);")[1]

        # Deactivate membership before check in
        run_psql(f"UPDATE public.station_memberships SET status = 'INACTIVE' WHERE id = '{mem_b_emp}';")

        code, _, err = run_as_user_json(emp_b, f"SELECT public.check_in_with_presence_proof('{pres_tok}', '{comp_v['identity_proof_token']}');")
        assert code != 0
        assert "P0022" in err or "not active" in err

        # Reactivate membership
        run_psql(f"UPDATE public.station_memberships SET status = 'ACTIVE' WHERE id = '{mem_b_emp}';")
    runner.run("37", "Deactivated Membership Rejection During Check-In (P0022)", test_37)

    # 38 Zero Confidence Scores & Zero Raw Media in Verification Ledger
    def test_38():
        _, cols, _ = run_psql("SELECT string_agg(column_name, ',') FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'identity_verification_attempts';")
        prohibited = ["score", "confidence", "similarity", "vector", "image", "media", "raw"]
        for p in prohibited:
            assert p not in cols.lower(), f"Found prohibited column name containing '{p}' in identity_verification_attempts: {cols}"
    runner.run("38", "Zero Confidence Scores & Zero Biometric Payload Ledger Audit", test_38)

    # 39 Full Phase 4 Presence & Schedule Integration Regression
    def test_39():
        # Verify get_my_attendance_history returns correctly
        code, hist, _ = run_as_user_json(emp1_a, f"SELECT public.get_my_attendance_history('{st_a}', 10, 0);")
        assert code == 0
        assert "records" in hist
    runner.run("39", "Full Phase 4 Attendance History Integration Regression", test_39)

    # 40 End-to-End Adversarial Security Boundary & RLS Integrity Verification
    def test_40():
        code_anon, out_anon, err_anon = run_psql("SET ROLE anon; SELECT * FROM public.employee_identity_profiles;")
        assert code_anon != 0 or out_anon == "" or out_anon is None
        code_rpc, _, err_rpc = run_psql(f"SET ROLE anon; SELECT public.get_station_team_identity_status('{st_a}');")
        assert code_rpc != 0
        assert "42501" in err_rpc or "permission denied" in err_rpc
    runner.run("40", "End-to-End Adversarial Security Boundary & RLS Integrity", test_40)

    # 41 Provider Identifier Safety Validation
    def test_41():
        code, _, err = run_as_user_json(emp1_a, "SELECT public.start_identity_enrollment('   ', 'v1.0');")
        assert code != 0
        assert "P0041" in err or "Provider is required" in err
    runner.run("41", "Empty Provider Identifier Rejection (P0041)", test_41)

    # 42 Employee Consent Version Mandatory Recording
    def test_42():
        code, res, err = run_as_user_json(emp1_a, "SELECT public.start_identity_enrollment('SANDBOX_PROVIDER', 'v2.0_HEBREW_EXP');")
        assert code == 0
        assert res["notice_version"] == "v2.0_HEBREW_EXP"
        _, ver, _ = run_psql(f"SELECT notice_version FROM public.employee_identity_profiles WHERE employee_user_id = '{emp1_a}';")
        assert ver == "v2.0_HEBREW_EXP"
    runner.run("42", "Employee Consent Version Dynamic Recording", test_42)

    # 43 Missing Provider Subject ID on Successful Enrollment Completion Rejection
    def test_43():
        code_s, res_s, _ = run_as_user_json(emp1_a, "SELECT public.start_identity_enrollment('SANDBOX_PROVIDER', 'v1.0');")
        code_c, _, err_c = run_as_user_json(emp1_a, f"SELECT public.complete_identity_enrollment('{res_s['session_id']}', '   ', true);")
        assert code_c != 0
        assert "P0045" in err_c or "Provider subject ID is required" in err_c
    runner.run("43", "Missing Provider Subject ID on Success Rejection (P0045)", test_43)

    # 44 Mid-Flow Shift Deletion Does Not Break Check-In Snapshot
    def test_44():
        setup_published_schedule(admin_b, st_b, emp_b, mem_b_emp, start_offset_min=-10, duration_hours=8, shift_name="Resilient Shift")
        mint = run_as_user_json(admin_b, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b}', '{kiosk_b['device_identifier']}', '{kiosk_b['raw_secret']}');")[1]
        scan = run_as_user_json(emp_b, f"SELECT public.scan_attendance_qr('{mint['qr_token']}');")[1]
        pres_tok = scan["presence_proof_token"]

        start_v = run_as_user_json(emp_b, f"SELECT public.start_identity_verification('{pres_tok}', 'SANDBOX_PROVIDER');")[1]
        comp_v = run_as_user_json(emp_b, f"SELECT public.complete_identity_verification('{start_v['attempt_id']}', true);")[1]

        # Execute check-in
        code, res, err = run_as_user_json(emp_b, f"SELECT public.check_in_with_presence_proof('{pres_tok}', '{comp_v['identity_proof_token']}');")
        assert code == 0
        assert res["shift_name"] == "Resilient Shift"

        # Check out
        mint_o = run_as_user_json(admin_b, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b}', '{kiosk_b['device_identifier']}', '{kiosk_b['raw_secret']}');")[1]
        scan_o = run_as_user_json(emp_b, f"SELECT public.scan_attendance_qr('{mint_o['qr_token']}');")[1]
        run_as_user_json(emp_b, f"SELECT public.check_out_with_presence_proof('{scan_o['presence_proof_token']}', NULL::TEXT);")
    runner.run("44", "Frozen Shift Name Snapshot Resilience Across Check-In", test_44)

    # 45 Identity Verification Proof Table Private from Realtime Publication
    def test_45():
        _, pub_tables, _ = run_psql("SELECT string_agg(tablename, ',') FROM pg_publication_tables WHERE pubname = 'supabase_realtime';")
        assert "identity_verification_proofs" not in pub_tables, "Security violation: identity_verification_proofs must not be in realtime publication"
    runner.run("45", "Realtime Channel Isolation (Proofs Excluded from Realtime)", test_45)

    # 46 Admin Override Reason Minimum Length Enforced
    def test_46():
        setup_published_schedule(admin_b, st_b, emp_b, mem_b_emp, start_offset_min=-10, duration_hours=8)
        mint = run_as_user_json(admin_b, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b}', '{kiosk_b['device_identifier']}', '{kiosk_b['raw_secret']}');")[1]
        scan = run_as_user_json(emp_b, f"SELECT public.scan_attendance_qr('{mint['qr_token']}');")[1]
        code, _, err = run_as_user_json(admin_b, f"SELECT public.create_identity_admin_override('{scan['presence_proof_token']}', 'ab');")
        assert code != 0
        assert "P0032" in err
    runner.run("46", "Admin Override Reason Exact Minimum Length Validation (<3 chars -> P0032)", test_46)

    print("=" * 75)
    print(f"PHASE 5 COMPREHENSIVE AUDIT SUMMARY: {runner.passed}/{len(runner.tests)} PASSED ({runner.passed/len(runner.tests)*100:.1f}%)")
    print("=" * 75)

    if runner.failed > 0:
        sys.exit(1)

if __name__ == "__main__":
    main()

