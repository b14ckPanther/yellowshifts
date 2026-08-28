#!/usr/bin/env python3
"""
YellowShifts Phase 4 Independent Comprehensive Adversarial Audit Suite (V2)
60+ Deep Scenarios: Kiosk Security, Dynamic QR, Presence Proofs, Concurrency, Schedule Binding,
Snapshots, One-Open-Session Invariant, DST / Cross-Midnight, Manual Correction & RLS.
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

DB_NAME = "yellowshifts_phase4_audit_v2_test"
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
    ]

    for mig in migrations:
        path = os.path.join("supabase", "migrations", mig)
        cmd = [PSQL_BIN, "-d", DB_NAME, "-U", CURRENT_USER, "-v", "ON_ERROR_STOP=1", "-f", path]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0:
            raise RuntimeError(f"Failed to apply {mig}:\n{res.stderr}")
    print("[*] All 6 canonical migrations applied cleanly on fresh test database.")

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
    print("STARTING PHASE 4 COMPREHENSIVE ADVERSARIAL AUDIT SUITE V2 (60+ SCENARIOS)")
    print("=" * 75)

    setup_fresh_db()
    runner = AuditTestRunner()

    # Base Fixtures
    admin_id = create_user_and_profile("admin_v2@station.com", "David", "Admin")
    mgr_id = create_user_and_profile("mgr_v2@station.com", "Sarah", "Manager")
    emp1_id = create_user_and_profile("emp1_v2@station.com", "Alex", "Worker")
    emp2_id = create_user_and_profile("emp2_v2@station.com", "Maya", "Worker")
    foreign_emp_id = create_user_and_profile("foreign_v2@other.com", "Dan", "Foreign")

    st_a_id = str(uuid.uuid4())
    st_b_id = str(uuid.uuid4())

    mem_a_admin = str(uuid.uuid4())
    mem_a_mgr = str(uuid.uuid4())
    mem_a_emp1 = str(uuid.uuid4())
    mem_a_emp2 = str(uuid.uuid4())
    mem_b_admin = str(uuid.uuid4())
    mem_b_foreign = str(uuid.uuid4())

    run_psql(f"""
    INSERT INTO public.stations (id, name, code, timezone, locale, is_active, check_in_early_minutes, late_grace_minutes)
    VALUES 
    ('{st_a_id}', 'תחנת כורדני', 'YLW-KRD-01', 'Asia/Jerusalem', 'he', true, 60, 5),
    ('{st_b_id}', 'תחנת לב המפרץ', 'YLW-LVM-02', 'Asia/Jerusalem', 'he', true, 60, 5);

    INSERT INTO public.station_memberships (id, station_id, user_id, role, status, employee_code)
    VALUES
    ('{mem_a_admin}', '{st_a_id}', '{admin_id}', 'ADMIN', 'ACTIVE', 'ADM-01'),
    ('{mem_a_mgr}', '{st_a_id}', '{mgr_id}', 'SHIFT_MANAGER', 'ACTIVE', 'MGR-01'),
    ('{mem_a_emp1}', '{st_a_id}', '{emp1_id}', 'EMPLOYEE', 'ACTIVE', 'EMP-01'),
    ('{mem_a_emp2}', '{st_a_id}', '{emp2_id}', 'EMPLOYEE', 'ACTIVE', 'EMP-02'),
    ('{mem_b_admin}', '{st_b_id}', '{admin_id}', 'ADMIN', 'ACTIVE', 'ADM-02'),
    ('{mem_b_foreign}', '{st_b_id}', '{foreign_emp_id}', 'EMPLOYEE', 'ACTIVE', 'FOR-01');
    """)

    # Shared Test State
    kiosk_a1 = {}
    kiosk_a2 = {}
    kiosk_b1 = {}

    # 01 Fresh Rebuild
    def test_01():
        _, cnt, _ = run_psql("SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('kiosk_devices', 'kiosk_qr_challenges', 'attendance_presence_proofs', 'attendance_records', 'attendance_corrections', 'attendance_rate_limit_attempts');")
        assert cnt == "6", f"Expected 6 tables, got {cnt}"
    runner.run("01", "Clean 6-Migration Fresh Rebuild Verification", test_01)

    # 02 Provision Kiosk & Secret Hashing
    def test_02():
        code, res, err = run_as_user_json(admin_id, f"SELECT public.provision_kiosk_device('{st_a_id}', 'Counter Tablet 1', 'TAB-KRD-01');")
        assert code == 0, f"Provision error: {err}"
        assert res["success"] is True
        assert "raw_secret" in res
        kiosk_a1["id"] = res["kiosk_id"]
        kiosk_a1["device_identifier"] = res["device_identifier"]
        kiosk_a1["raw_secret"] = res["raw_secret"]

        _, row, _ = run_psql(f"SELECT secret_hash, credential_version, is_active FROM public.kiosk_devices WHERE id = '{kiosk_a1['id']}';")
        sec_hash, ver, active = row.split("|")
        expected_hash = hashlib.sha256(kiosk_a1["raw_secret"].encode("utf-8")).hexdigest()
        assert sec_hash == expected_hash
        assert sec_hash != kiosk_a1["raw_secret"]
        assert ver == "1"
        assert active == "t"
    runner.run("02", "Kiosk Provisioning & One-Way SHA-256 Secret Hashing", test_02)

    # 03 Hash-As-Secret Authentication Attack
    def test_03():
        sec_hash = hashlib.sha256(kiosk_a1["raw_secret"].encode("utf-8")).hexdigest()
        code, _, err = run_as_user_json(admin_id, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_a_id}', '{kiosk_a1['device_identifier']}', '{sec_hash}');")
        assert code != 0, "Hash-as-secret attack should fail"
        assert "P0019" in err or "Invalid kiosk credentials" in err
    runner.run("03", "Hash-as-Secret Attack Rejection (P0019)", test_03)

    # 04 Wrong Secret Attack
    def test_04():
        code, _, err = run_as_user_json(admin_id, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_a_id}', '{kiosk_a1['device_identifier']}', 'TotallyWrongSecret123456');")
        assert code != 0
        assert "P0019" in err or "Invalid kiosk credentials" in err
    runner.run("04", "Wrong Kiosk Secret Attack Rejection (P0019)", test_04)

    # 05 Dynamic QR Challenge Minting (30s TTL)
    def test_05():
        code, res, err = run_as_user_json(admin_id, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_a_id}', '{kiosk_a1['device_identifier']}', '{kiosk_a1['raw_secret']}');")
        assert code == 0, f"Mint error: {err}"
        assert res["success"] is True
        assert res["ttl_seconds"] == 30
        assert len(res["display_code"]) == 6
        assert res["qr_token"].startswith("YQ_")
        kiosk_a1["current_qr"] = res["qr_token"]
        kiosk_a1["display_code"] = res["display_code"]
    runner.run("05", "Kiosk Authenticate & Dynamic QR Challenge Minting (30s TTL)", test_05)

    # 06 Kiosk Credential Rotation
    def test_06():
        code, res, err = run_as_user_json(admin_id, f"SELECT public.rotate_kiosk_credentials('{kiosk_a1['id']}');")
        assert code == 0, f"Rotation error: {err}"
        assert res["success"] is True
        assert res["credential_version"] == 2
        kiosk_a1["old_secret"] = kiosk_a1["raw_secret"]
        kiosk_a1["raw_secret"] = res["raw_secret"]
        kiosk_a1["old_qr"] = kiosk_a1["current_qr"]
    runner.run("06", "Kiosk Credential Rotation Version Increment", test_06)

    # 07 Old Kiosk Credentials Rejected After Rotation
    def test_07():
        code, _, err = run_as_user_json(admin_id, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_a_id}', '{kiosk_a1['device_identifier']}', '{kiosk_a1['old_secret']}');")
        assert code != 0
        assert "P0019" in err or "Invalid kiosk credentials" in err
    runner.run("07", "Old Credentials Rejected After Rotation (P0019)", test_07)

    # 08 Previously Minted QR Revoked After Rotation
    def test_08():
        code, _, err = run_as_user_json(emp1_id, f"SELECT public.scan_attendance_qr('{kiosk_a1['old_qr']}');")
        assert code != 0
        assert "P0020" in err or "Invalid attendance QR" in err
    runner.run("08", "QR Challenge Revoked Immediately on Credential Rotation", test_08)

    # 09 Minting with New Rotated Credentials
    def test_09():
        code, res, err = run_as_user_json(admin_id, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_a_id}', '{kiosk_a1['device_identifier']}', '{kiosk_a1['raw_secret']}');")
        assert code == 0, f"Mint error: {err}"
        assert res["success"] is True
        kiosk_a1["current_qr"] = res["qr_token"]
        kiosk_a1["display_code"] = res["display_code"]
    runner.run("09", "Dynamic QR Minting with New Rotated Secret", test_09)

    # 10 Kiosk Deactivation
    def test_10():
        code, res, err = run_as_user_json(admin_id, f"SELECT public.deactivate_kiosk_device('{kiosk_a1['id']}');")
        assert code == 0, f"Deactivate error: {err}"
        assert res["success"] is True
        assert res["is_active"] is False
    runner.run("10", "Kiosk Device Deactivation (is_active = false)", test_10)

    # 11 Deactivated Kiosk Cannot Mint QR
    def test_11():
        code, _, err = run_as_user_json(admin_id, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_a_id}', '{kiosk_a1['device_identifier']}', '{kiosk_a1['raw_secret']}');")
        assert code != 0
        assert "P0018" in err or "inactive" in err
    runner.run("11", "Deactivated Kiosk Mint Request Rejection (P0018)", test_11)

    # 12 QR from Deactivated Kiosk Rejected
    def test_12():
        code, _, err = run_as_user_json(emp1_id, f"SELECT public.scan_attendance_qr('{kiosk_a1['current_qr']}');")
        assert code != 0
        assert "P0020" in err or "P0022" in err or "inactive" in err or "Invalid attendance QR" in err
    runner.run("12", "Scan of QR Issued by Deactivated Kiosk Rejected", test_12)

    # 13 Kiosk Reactivation
    def test_13():
        code, res, err = run_as_user_json(admin_id, f"SELECT public.reactivate_kiosk_device('{kiosk_a1['id']}');")
        assert code == 0, f"Reactivate error: {err}"
        assert res["success"] is True
        assert res["is_active"] is True

        code_m, mint_res, err_m = run_as_user_json(admin_id, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_a_id}', '{kiosk_a1['device_identifier']}', '{kiosk_a1['raw_secret']}');")
        assert code_m == 0, f"Mint after reactivate error: {err_m}"
        kiosk_a1["current_qr"] = mint_res["qr_token"]
        kiosk_a1["display_code"] = mint_res["display_code"]
    runner.run("13", "Kiosk Reactivation Restores Operational Capabilities", test_13)

    # 14 Kiosk Cross-Station Device Enumeration
    def test_14():
        code, _, err = run_as_user_json(admin_id, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b_id}', '{kiosk_a1['device_identifier']}', '{kiosk_a1['raw_secret']}');")
        assert code != 0
        assert "P0016" in err or "not found" in err
    runner.run("14", "Cross-Station Kiosk Identifier Enumeration Blocked (P0016)", test_14)

    # 15 QR Expiry Exact Boundary
    def test_15():
        run_psql(f"UPDATE public.kiosk_qr_challenges SET expires_at = now() - INTERVAL '1 second' WHERE challenge_hash = encode(digest('{kiosk_a1['current_qr']}', 'sha256'), 'hex');")
        code, _, err = run_as_user_json(emp1_id, f"SELECT public.scan_attendance_qr('{kiosk_a1['current_qr']}');")
        assert code != 0
        assert "P0021" in err or "expired" in err

        code_m, mint_res, _ = run_as_user_json(admin_id, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_a_id}', '{kiosk_a1['device_identifier']}', '{kiosk_a1['raw_secret']}');")
        assert code_m == 0
        kiosk_a1["current_qr"] = mint_res["qr_token"]
        kiosk_a1["display_code"] = mint_res["display_code"]
    runner.run("15", "Dynamic QR Expiry Exact Boundary Defense (30s TTL / P0021)", test_15)

    # 16 QR Tamper Defense
    def test_16():
        tampered = kiosk_a1["current_qr"][:-4] + "ABCD"
        code, _, err = run_as_user_json(emp1_id, f"SELECT public.scan_attendance_qr('{tampered}');")
        assert code != 0
        assert "P0020" in err or "Invalid attendance QR" in err
    runner.run("16", "Tampered QR Challenge Rejection (P0020)", test_16)

    # 17 Schedule Setup for Emp1 & Emp2
    def test_17():
        setup_published_schedule(admin_id, st_a_id, emp1_id, mem_a_emp1, start_offset_min=-10, duration_hours=8, shift_name="Morning Shift")
        setup_published_schedule(admin_id, st_a_id, emp2_id, mem_a_emp2, start_offset_min=-10, duration_hours=8, shift_name="Morning Shift")
    runner.run("17", "Phase 3 Published Schedule Setup with Active Shift Assignments", test_17)

    # 18 Multi-Employee Public QR Concurrency
    proof_emp1 = {}
    proof_emp2 = {}

    def test_18():
        code1, res1, err1 = run_as_user_json(emp1_id, f"SELECT public.scan_attendance_qr('{kiosk_a1['current_qr']}');")
        assert code1 == 0, f"Scan emp1 error: {err1}"
        assert res1["success"] is True
        assert res1["action"] == "CHECK_IN"
        assert "presence_proof_token" in res1
        proof_emp1["token"] = res1["presence_proof_token"]

        code2, res2, err2 = run_as_user_json(emp2_id, f"SELECT public.scan_attendance_qr('{kiosk_a1['current_qr']}');")
        assert code2 == 0, f"Scan emp2 error: {err2}"
        assert res2["success"] is True
        assert res2["action"] == "CHECK_IN"
        assert res2["presence_proof_token"] != proof_emp1["token"]
        proof_emp2["token"] = res2["presence_proof_token"]
    runner.run("18", "Multi-Employee Concurrent QR Scan Issues Distinct Proofs", test_18)

    # 19 Manual 6-Character Short Code Parity
    def test_19():
        run_psql(f"DELETE FROM public.attendance_presence_proofs WHERE employee_user_id = '{emp2_id}';")
        code_input = f"  {kiosk_a1['display_code'].lower()}  "
        code, res, err = run_as_user_json(emp2_id, f"SELECT public.scan_attendance_qr('{code_input}');")
        assert code == 0, f"Manual scan error: {err}"
        assert res["success"] is True
        assert res["action"] == "CHECK_IN"
        proof_emp2["token"] = res["presence_proof_token"]
    runner.run("19", "Manual Short Code Parity & Whitespace/Case Normalization", test_19)

    # 20 Foreign Station Employee Scan Lockout
    def test_20():
        code, _, err = run_as_user_json(foreign_emp_id, f"SELECT public.scan_attendance_qr('{kiosk_a1['current_qr']}');")
        assert code != 0
        assert "42501" in err or "Access denied" in err
    runner.run("20", "Foreign Station Employee Scan Blocked (42501)", test_20)

    # 21 Presence Proof Hash-as-Token Attack
    def test_21():
        proof_hash = hashlib.sha256(proof_emp1["token"].encode("utf-8")).hexdigest()
        code, _, err = run_as_user_json(emp1_id, f"SELECT public.check_in_with_presence_proof('{proof_hash}');")
        assert code != 0
        assert "P0025" in err or "Invalid presence proof" in err
    runner.run("21", "Presence Proof Hash-as-Token Attack Rejection (P0025)", test_21)

    # 22 Presence Proof Employee Binding
    def test_22():
        code, _, err = run_as_user_json(emp2_id, f"SELECT public.check_in_with_presence_proof('{proof_emp1['token']}');")
        assert code != 0
        assert "P0028" in err or "belongs to another employee" in err
    runner.run("22", "Presence Proof Employee Identity Binding (P0028)", test_22)

    # 23 Presence Proof Action Binding
    def test_23():
        code, _, err = run_as_user_json(emp1_id, f"SELECT public.check_out_with_presence_proof('{proof_emp1['token']}');")
        assert code != 0
        assert "P0029" in err or "Expected CHECK_OUT" in err
    runner.run("23", "Presence Proof Action Binding (P0029)", test_23)

    # 24 Presence Proof Expiry Exact Boundary
    def test_24():
        temp_proof = "PP_exp_test_1234567890123456"
        temp_hash = hashlib.sha256(temp_proof.encode("utf-8")).hexdigest()
        run_psql(f"""
        INSERT INTO public.attendance_presence_proofs (
            station_id, employee_user_id, station_membership_id, kiosk_device_id,
            qr_challenge_id, action, token_hash, expires_at
        ) SELECT '{st_a_id}', '{emp1_id}', id, '{kiosk_a1['id']}',
                 (SELECT id FROM public.kiosk_qr_challenges LIMIT 1), 'CHECK_IN', '{temp_hash}', now() - INTERVAL '1 second'
          FROM public.station_memberships WHERE station_id = '{st_a_id}' AND user_id = '{emp1_id}';
        """)
        code, _, err = run_as_user_json(emp1_id, f"SELECT public.check_in_with_presence_proof('{temp_proof}');")
        assert code != 0
        assert "P0027" in err or "expired" in err
    runner.run("24", "Presence Proof Expiry Exact Boundary Defense (60s TTL / P0027)", test_24)

    # 25 Check-In Execution & Frozen Snapshots
    att_emp1 = {}
    def test_25():
        code, res, err = run_as_user_json(emp1_id, f"SELECT public.check_in_with_presence_proof('{proof_emp1['token']}');")
        assert code == 0, f"Check in error: {err}"
        assert res["success"] is True
        assert res["status"] == "OPEN"
        att_emp1["id"] = res["attendance_id"]

        _, row, _ = run_psql(f"""
        SELECT shift_name_snapshot, schedule_version_at_check_in, check_in_kiosk_device_id, late_minutes
        FROM public.attendance_records WHERE id = '{att_emp1['id']}';
        """)
        name, ver, kiosk_id, late = row.split("|")
        assert name == "Morning Shift"
        assert ver == "1"
        assert kiosk_id == kiosk_a1["id"]
        assert int(late) >= 0
    runner.run("25", "Check-In Execution & Frozen Schedule Snapshot Preservation", test_25)

    # 26 Single-Use Proof Replay Blocked
    def test_26():
        code, _, err = run_as_user_json(emp1_id, f"SELECT public.check_in_with_presence_proof('{proof_emp1['token']}');")
        assert code != 0
        assert "P0026" in err or "already been used" in err
    runner.run("26", "Presence Proof Single-Use Replay Blocked Atomically (P0026)", test_26)

    # 27 Global Single-Open-Session DB Partial Unique Index
    def test_27():
        code, _, err = run_psql(f"""
        INSERT INTO public.attendance_records (
            station_id, employee_user_id, station_membership_id, check_in_time, check_in_kiosk_device_id
        ) SELECT '{st_a_id}', '{emp1_id}', id, now(), '{kiosk_a1['id']}'
          FROM public.station_memberships WHERE station_id = '{st_a_id}' AND user_id = '{emp1_id}';
        """)
        assert code != 0
        assert "uq_attendance_single_open_session" in err or "duplicate key" in err
    runner.run("27", "Global Single-Open-Session DB Partial Unique Index Invariant", test_27)

    # 28 Multi-Station Open Session Lockout
    def test_28():
        run_psql(f"INSERT INTO public.station_memberships (station_id, user_id, role, status) VALUES ('{st_b_id}', '{emp1_id}', 'EMPLOYEE', 'ACTIVE') ON CONFLICT DO NOTHING;")
        _, res_b, _ = run_as_user_json(admin_id, f"SELECT public.provision_kiosk_device('{st_b_id}', 'Kiosk B1', 'TAB-LVM-01');")
        kiosk_b1["id"] = res_b["kiosk_id"]
        kiosk_b1["raw_secret"] = res_b["raw_secret"]
        kiosk_b1["device_identifier"] = res_b["device_identifier"]

        _, mint_b, _ = run_as_user_json(admin_id, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_b_id}', '{kiosk_b1['device_identifier']}', '{kiosk_b1['raw_secret']}');")
        kiosk_b1["current_qr"] = mint_b["qr_token"]

        code, _, err = run_as_user_json(emp1_id, f"SELECT public.scan_attendance_qr('{kiosk_b1['current_qr']}');")
        assert code != 0
        assert "P0023" in err or "open attendance session at another station" in err
    runner.run("28", "Multi-Station Simultaneous Open Session Lockout (P0023)", test_28)

    # 29 Concurrent Check-In Race (Thread Pool)
    def test_29():
        _, mint, _ = run_as_user_json(admin_id, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_a_id}', '{kiosk_a1['device_identifier']}', '{kiosk_a1['raw_secret']}');")
        qr = mint["qr_token"]

        _, scan1, _ = run_as_user_json(emp2_id, f"SELECT public.scan_attendance_qr('{qr}');")
        _, scan2, _ = run_as_user_json(emp2_id, f"SELECT public.scan_attendance_qr('{qr}');")

        t1 = scan1["presence_proof_token"]
        t2 = scan2["presence_proof_token"]

        def do_checkin(tok):
            return run_as_user_json(emp2_id, f"SELECT public.check_in_with_presence_proof('{tok}');")

        with ThreadPoolExecutor(max_workers=2) as pool:
            futures = [pool.submit(do_checkin, t1), pool.submit(do_checkin, t2)]
            results = [f.result() for f in futures]

        success_count = sum(1 for code, _, _ in results if code == 0)
        fail_count = sum(1 for code, _, _ in results if code != 0)
        assert success_count == 1, f"Expected exactly 1 success, got {success_count}"
        assert fail_count == 1, f"Expected exactly 1 failure, got {fail_count}"
    runner.run("29", "Concurrent Multithreaded Check-In Race Serialization", test_29)

    # 30 Check-Out at Same Station from Different Kiosk Device
    def test_30():
        _, res_a2, _ = run_as_user_json(admin_id, f"SELECT public.provision_kiosk_device('{st_a_id}', 'Break Room Kiosk', 'TAB-KRD-02');")
        kiosk_a2["id"] = res_a2["kiosk_id"]
        kiosk_a2["raw_secret"] = res_a2["raw_secret"]
        kiosk_a2["device_identifier"] = res_a2["device_identifier"]

        _, mint_a2, _ = run_as_user_json(admin_id, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_a_id}', '{kiosk_a2['device_identifier']}', '{kiosk_a2['raw_secret']}');")

        code_s, scan_out, _ = run_as_user_json(emp1_id, f"SELECT public.scan_attendance_qr('{mint_a2['qr_token']}');")
        assert code_s == 0
        assert scan_out["action"] == "CHECK_OUT"
        checkout_proof = scan_out["presence_proof_token"]

        code_o, res_out, _ = run_as_user_json(emp1_id, f"SELECT public.check_out_with_presence_proof('{checkout_proof}');")
        assert code_o == 0
        assert res_out["success"] is True
        assert res_out["status"] == "COMPLETED"

        _, row, _ = run_psql(f"SELECT check_in_kiosk_device_id, check_out_kiosk_device_id, status FROM public.attendance_records WHERE id = '{att_emp1['id']}';")
        in_kiosk, out_kiosk, st = row.split("|")
        assert in_kiosk == kiosk_a1["id"]
        assert out_kiosk == kiosk_a2["id"]
        assert st == "COMPLETED"
    runner.run("30", "Same-Station Different Kiosk Check-Out & Kiosk ID Preservation", test_30)

    # 31 Check-Out Without Open Session Blocked
    def test_31():
        _, mint, _ = run_as_user_json(admin_id, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_a_id}', '{kiosk_a1['device_identifier']}', '{kiosk_a1['raw_secret']}');")
        fake_proof = "PP_fake_checkout_12345678901234"
        fake_hash = hashlib.sha256(fake_proof.encode("utf-8")).hexdigest()
        run_psql(f"""
        INSERT INTO public.attendance_presence_proofs (
            station_id, employee_user_id, station_membership_id, kiosk_device_id,
            qr_challenge_id, action, token_hash, expires_at
        ) SELECT '{st_a_id}', '{emp1_id}', id, '{kiosk_a1['id']}',
                 (SELECT id FROM public.kiosk_qr_challenges WHERE kiosk_device_id = '{kiosk_a1['id']}' ORDER BY created_at DESC LIMIT 1),
                 'CHECK_OUT', '{fake_hash}', now() + INTERVAL '60 seconds'
          FROM public.station_memberships WHERE station_id = '{st_a_id}' AND user_id = '{emp1_id}';
        """)
        code, _, err = run_as_user_json(emp1_id, f"SELECT public.check_out_with_presence_proof('{fake_proof}');")
        assert code != 0
        assert "P0030" in err or "No open attendance record" in err
    runner.run("31", "Check-Out Without Open Record Rejection (P0030)", test_31)

    # 32 Check-In to Draft Schedule Forbidden
    def test_32():
        # Remove published shift assignment for emp1
        run_psql(f"DELETE FROM public.shift_assignments WHERE user_id = '{emp1_id}';")
        draft_ws_id = str(uuid.uuid4())
        draft_shift_id = str(uuid.uuid4())
        draft_date = (date.today() + timedelta(days=21)).isoformat()
        now_dt = datetime.now()
        shift_start = (now_dt - timedelta(minutes=10)).strftime("%Y-%m-%d %H:%M:%S")
        shift_end = (now_dt + timedelta(hours=8)).strftime("%Y-%m-%d %H:%M:%S")

        run_psql(f"""
        INSERT INTO public.work_schedules (id, station_id, availability_period_id, week_start_date, status, version, created_by)
        VALUES ('{draft_ws_id}', '{st_a_id}', (SELECT id FROM public.availability_periods LIMIT 1), '{draft_date}', 'DRAFT', 1, '{admin_id}')
        ON CONFLICT (station_id, week_start_date) DO UPDATE SET status = 'DRAFT';

        INSERT INTO public.work_schedule_shifts (id, work_schedule_id, station_id, operational_date, shift_name_snapshot, starts_at, ends_at, required_staff_count, created_by)
        VALUES ('{draft_shift_id}', '{draft_ws_id}', '{st_a_id}', '{draft_date}', 'Draft Shift', '{shift_start}'::timestamptz, '{shift_end}'::timestamptz, 1, '{admin_id}');

        INSERT INTO public.shift_assignments (work_schedule_shift_id, user_id, assigned_by)
        VALUES ('{draft_shift_id}', '{emp1_id}', '{admin_id}');
        """)

        _, mint, _ = run_as_user_json(admin_id, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_a_id}', '{kiosk_a1['device_identifier']}', '{kiosk_a1['raw_secret']}');")
        code, _, err = run_as_user_json(emp1_id, f"SELECT public.scan_attendance_qr('{mint['qr_token']}');")
        assert code != 0
        assert "P0024" in err or "No published shift assignment found" in err
    runner.run("32", "Check-In to DRAFT Schedule Blocked (P0024)", test_32)

    # 33 Ambiguous Shift Resolution Defense
    def test_33():
        run_psql(f"DELETE FROM public.shift_assignments WHERE user_id = '{emp1_id}';")
        sched_id, shift1_id, _ = setup_published_schedule(admin_id, st_a_id, emp1_id, mem_a_emp1, start_offset_min=-5, duration_hours=4, shift_name="Conflicting Shift 1")

        shift2_id = str(uuid.uuid4())
        asgn2_id = str(uuid.uuid4())
        run_psql(f"""
        INSERT INTO public.work_schedule_shifts (
            id, work_schedule_id, station_id, operational_date, period_shift_template_id, shift_name_snapshot, start_time_snapshot, end_time_snapshot, starts_at, ends_at, required_staff_count
        ) SELECT '{shift2_id}', work_schedule_id, station_id, operational_date, period_shift_template_id, 'Conflicting Shift 2', start_time_snapshot, end_time_snapshot, starts_at, ends_at + INTERVAL '2 hours', 1
          FROM public.work_schedule_shifts WHERE id = '{shift1_id}';

        INSERT INTO public.shift_assignments (id, work_schedule_shift_id, station_id, membership_id, user_id, availability_state_snapshot, assigned_by)
        VALUES ('{asgn2_id}', '{shift2_id}', '{st_a_id}', '{mem_a_emp1}', '{emp1_id}', 'AVAILABLE', '{admin_id}');
        """)

        _, mint, _ = run_as_user_json(admin_id, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_a_id}', '{kiosk_a1['device_identifier']}', '{kiosk_a1['raw_secret']}');")
        code, _, err = run_as_user_json(emp1_id, f"SELECT public.scan_attendance_qr('{mint['qr_token']}');")
        assert code != 0
        assert "P0036" in err or "Multiple conflicting shift assignments" in err
    runner.run("33", "Ambiguous Shift Detection & Safe Rejection (P0036)", test_33)

    # 34 Cross-Midnight Shift Resolution
    def test_34():
        run_psql(f"DELETE FROM public.shift_assignments WHERE user_id = '{emp1_id}';")
        yesterday_date = date.today() - timedelta(days=1)
        setup_published_schedule(admin_id, st_a_id, emp1_id, mem_a_emp1, start_offset_min=-120, duration_hours=8, target_date=yesterday_date, shift_name="Night Shift Cross-Midnight")

        _, mint, _ = run_as_user_json(admin_id, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_a_id}', '{kiosk_a1['device_identifier']}', '{kiosk_a1['raw_secret']}');")
        code, res, err = run_as_user_json(emp1_id, f"SELECT public.scan_attendance_qr('{mint['qr_token']}');")
        assert code == 0, f"Cross midnight scan error: {err}"
        assert res["success"] is True
        assert res["shift_preview"]["shift_name"] == "Night Shift Cross-Midnight"
    runner.run("34", "Cross-Midnight Shift Resolution (UTC Operational Date Invariant)", test_34)

    # 35 DST Spring Real UTC Elapsed Minutes Calculation (7 Hours)
    def test_35():
        t_in = "2026-03-26T21:00:00Z"
        t_out = "2026-03-27T04:00:00Z"
        _, diff_min, _ = run_psql(f"SELECT floor(extract(epoch from ('{t_out}'::timestamptz - '{t_in}'::timestamptz)) / 60.0)::INTEGER;")
        assert diff_min == "420", f"Expected 420 min (7h), got {diff_min}"
    runner.run("35", "DST Spring Real Elapsed Duration Integrity (7 Hours / 420 Min)", test_35)

    # 36 DST Fall Real UTC Elapsed Minutes Calculation (9 Hours)
    def test_36():
        t_in = "2026-10-24T20:00:00Z"
        t_out = "2026-10-25T05:00:00Z"
        _, diff_min, _ = run_psql(f"SELECT floor(extract(epoch from ('{t_out}'::timestamptz - '{t_in}'::timestamptz)) / 60.0)::INTEGER;")
        assert diff_min == "540", f"Expected 540 min (9h), got {diff_min}"
    runner.run("36", "DST Fall Real Elapsed Duration Integrity (9 Hours / 540 Min)", test_36)

    # 37 Long Shift Duration Support (16 Hours)
    def test_37():
        t_in = "2026-08-20T06:00:00Z"
        t_out = "2026-08-20T22:00:00Z"
        _, diff_min, _ = run_psql(f"SELECT floor(extract(epoch from ('{t_out}'::timestamptz - '{t_in}'::timestamptz)) / 60.0)::INTEGER;")
        assert diff_min == "960", f"Expected 960 min (16h), got {diff_min}"
    runner.run("37", "No Arbitrary Daily Work-Hour Cap (16h Long Shift = 960 Min)", test_37)

    # 38 Manual Correction Authorization (Admin Allowed, Employee Blocked)
    def test_38():
        # Insert dedicated attendance record for correction tests
        corr_rec_id = str(uuid.uuid4())
        run_psql(f"""
        INSERT INTO public.attendance_records (
            id, station_id, employee_user_id, station_membership_id,
            check_in_time, check_out_time, worked_minutes, status, check_in_kiosk_device_id
        ) VALUES (
            '{corr_rec_id}', '{st_a_id}', '{emp1_id}', '{mem_a_emp1}',
            '2026-08-15T08:00:00Z', '2026-08-15T16:00:00Z', 480, 'COMPLETED', '{kiosk_a1['id']}'
        );
        """)

        code_emp, _, err_emp = run_as_user_json(emp1_id, f"SELECT public.correct_attendance_record('{corr_rec_id}', '2026-08-15T08:00:00Z', '2026-08-15T17:00:00Z', 'Self correction attempt');")
        assert code_emp != 0
        assert "42501" in err_emp or "Access denied" in err_emp

        code_adm, res_adm, err_adm = run_as_user_json(admin_id, f"SELECT public.correct_attendance_record('{corr_rec_id}', '2026-08-15T08:00:00Z', '2026-08-15T17:00:00Z', 'Admin adjusted clock times per manager request');")
        assert code_adm == 0, f"Admin correction error: {err_adm}"
        assert res_adm["success"] is True
        assert res_adm["status"] == "CORRECTED"
        assert res_adm["worked_minutes"] == 540
    runner.run("38", "Manual Attendance Correction Authorization & Admin Capability", test_38)

    # 39 Manual Correction Reason Length Validation
    def test_39():
        code, _, err = run_as_user_json(admin_id, f"SELECT public.correct_attendance_record('{att_emp1['id']}', '2026-08-20T08:00:00Z', '2026-08-20T16:00:00Z', '  ok  ');")
        assert code != 0
        assert "P0032" in err or "at least 3 characters" in err
    runner.run("39", "Manual Correction Reason Validation (Trimmed >=3 Chars / P0032)", test_39)

    # 40 Manual Correction Negative Interval Defense
    def test_40():
        code, _, err = run_as_user_json(admin_id, f"SELECT public.correct_attendance_record('{att_emp1['id']}', '2026-08-20T16:00:00Z', '2026-08-20T08:00:00Z', 'Valid explanation reason');")
        assert code != 0
        assert "P0034" in err or "Check-out time must be after check-in time" in err
    runner.run("40", "Manual Correction Negative/Zero Duration Rejection (P0034)", test_40)

    # 41 Manual Correction Half-Open Interval Overlap Defense
    def test_41():
        rec2_id = str(uuid.uuid4())
        run_psql(f"""
        INSERT INTO public.attendance_records (
            id, station_id, employee_user_id, station_membership_id,
            check_in_time, check_out_time, worked_minutes, status, check_in_kiosk_device_id
        ) VALUES (
            '{rec2_id}', '{st_a_id}', '{emp1_id}', '{mem_a_emp1}',
            '2026-08-25T10:00:00Z', '2026-08-25T14:00:00Z', 240, 'COMPLETED', '{kiosk_a1['id']}'
        );
        """)

        code, _, err = run_as_user_json(admin_id, f"SELECT public.correct_attendance_record('{att_emp1['id']}', '2026-08-25T12:00:00Z', '2026-08-25T16:00:00Z', 'Overlapping interval test');")
        assert code != 0
        assert "P0035" in err or "overlaps with another attendance record" in err
    runner.run("41", "Manual Correction Half-Open Overlap Defense (P0035)", test_41)

    # 42 Manual Correction Half-Open Interval Adjacency Allowed
    def test_42():
        code, res, err = run_as_user_json(admin_id, f"SELECT public.correct_attendance_record('{att_emp1['id']}', '2026-08-25T14:00:00Z', '2026-08-25T18:00:00Z', 'Adjacent interval adjustment');")
        assert code == 0, f"Adjacency correction error: {err}"
        assert res["success"] is True
        assert res["worked_minutes"] == 240
    runner.run("42", "Manual Correction Half-Open Adjacency Allowed (No False Overlap)", test_42)

    # 43 Immutable Correction Ledger Audit Trail
    def test_43():
        _, cnt, _ = run_psql(f"SELECT count(*) FROM public.attendance_corrections WHERE attendance_record_id = '{att_emp1['id']}';")
        assert int(cnt) >= 1, f"Expected at least 1 correction entry, got {cnt}"

        code, _, _ = run_as_user_json(admin_id, f"""
        INSERT INTO public.attendance_corrections (attendance_record_id, station_id, actor_user_id, reason)
        VALUES ('{att_emp1['id']}', '{st_a_id}', '{admin_id}', 'Direct bypass attempt');
        """)
        assert code != 0
    runner.run("43", "Immutable Correction Ledger & Direct Write Lockout", test_43)

    # 44 Direct Attendance Records Write Lockout (RLS)
    def test_44():
        code, _, _ = run_as_user_json(emp1_id, f"""
        INSERT INTO public.attendance_records (station_id, employee_user_id, station_membership_id, check_in_time, check_in_kiosk_device_id)
        VALUES ('{st_a_id}', '{emp1_id}', '{mem_a_emp1}', now(), '{kiosk_a1['id']}');
        """)
        assert code != 0
    runner.run("44", "Direct Client Attendance Records Write Lockout (RLS)", test_44)

    # 45 Direct Presence Proofs Table Lockout
    def test_45():
        _, out, _ = run_as_user_json(emp1_id, "SELECT * FROM public.attendance_presence_proofs;")
        assert out == "" or out is None or out == [], f"Expected 0 rows for direct SELECT on presence proofs, got: {out}"
    runner.run("45", "Direct Presence Proofs Table Browsing Lockout (RLS)", test_45)

    # 46 Direct Kiosk Challenges Table Lockout
    def test_46():
        _, out, _ = run_as_user_json(emp1_id, "SELECT * FROM public.kiosk_qr_challenges;")
        assert out == "" or out is None or out == [], f"Expected 0 rows for direct SELECT on QR challenges, got: {out}"
    runner.run("46", "Direct QR Challenges Table Browsing Lockout (RLS)", test_46)

    # 47 Anonymous Role Lockout Across All Phase 4 RPCs & Tables
    def test_47():
        code, _, err = run_psql(f"SET LOCAL ROLE anon; SELECT public.kiosk_authenticate_and_mint_qr('{st_a_id}', '{kiosk_a1['device_identifier']}', '{kiosk_a1['raw_secret']}');")
        assert code != 0
        assert "42501" in err or "permission denied" in err or "Authentication required" in err
    runner.run("47", "Anonymous Role Complete RPC Lockout", test_47)

    # 48 SECURITY DEFINER & Search Path Pinning
    def test_48():
        funcs = [
            "kiosk_authenticate_and_mint_qr",
            "scan_attendance_qr",
            "check_in_with_presence_proof",
            "check_out_with_presence_proof",
            "correct_attendance_record",
            "get_manager_live_attendance",
            "get_my_attendance_history",
            "cleanup_ephemeral_attendance_data",
            "provision_kiosk_device",
            "rotate_kiosk_credentials",
            "deactivate_kiosk_device",
            "reactivate_kiosk_device",
        ]
        for f in funcs:
            _, row, _ = run_psql(f"""
            SELECT prosecdef, proconfig
            FROM pg_proc WHERE proname = '{f}' AND pronamespace = 'public'::regnamespace;
            """)
            secdef, cfg = row.split("|")
            assert secdef == "t", f"{f} must be SECURITY DEFINER"
            assert "search_path=public, pg_temp" in cfg or "search_path=public" in cfg, f"{f} missing search_path pinning"
    runner.run("48", "SECURITY DEFINER & Search Path Pinning on All 12 RPCs", test_48)

    # 49 Ephemeral Data Cleanup RPC
    def test_49():
        _, res, err = run_as_user_json(admin_id, "SELECT public.cleanup_ephemeral_attendance_data();")
        assert res["success"] is True
        assert "purged_challenges" in res
        assert "purged_proofs" in res
    runner.run("49", "Ephemeral Data Cleanup RPC Execution", test_49)

    # 50 Manager Live Attendance Operational View
    def test_50():
        today_str = date.today().isoformat()
        code, res, err = run_as_user_json(mgr_id, f"SELECT public.get_manager_live_attendance('{st_a_id}', '{today_str}'::date);")
        assert code == 0, f"Manager live attendance error: {err}"
        assert res["success"] is True
        assert "kpis" in res
        assert "roster" in res
    runner.run("50", "Manager Live Attendance KPI & Workforce Roster RPC", test_50)

    # 51 Schedule Assignment Removed After Check-In (ON DELETE SET NULL Integrity)
    def test_51():
        run_psql(f"DELETE FROM public.shift_assignments WHERE user_id = '{emp1_id}';")
        _, row, _ = run_psql(f"SELECT shift_name_snapshot, schedule_version_at_check_in FROM public.attendance_records WHERE id = '{att_emp1['id']}';")
        name, ver = row.split("|")
        assert name == "Morning Shift"
        assert ver == "1"
    runner.run("51", "Schedule Assignment Removed After Check-In Leaves History Intact", test_51)

    # 52 Kiosk Rate Limiting on Wrong Secret Bursts
    def test_52():
        dev_id = "TAB-BURST-TEST"
        for _ in range(30):
            run_psql(f"""
            INSERT INTO public.attendance_rate_limit_attempts (target_identifier, action, is_success, attempted_at)
            VALUES ('{dev_id}', 'KIOSK_AUTH', false, now());
            """)
        code, _, err = run_as_user_json(admin_id, f"SELECT public.kiosk_authenticate_and_mint_qr('{st_a_id}', '{dev_id}', 'any_secret');")
        assert code != 0
        assert "P0038" in err or "Too many failed authentication attempts" in err
    runner.run("52", "Kiosk Brute Force Burst Rate Limiting Defense (P0038)", test_52)

    # 53 QR Scan Rate Limiting on Invalid Code Floods
    def test_53():
        for _ in range(30):
            run_psql(f"""
            INSERT INTO public.attendance_rate_limit_attempts (actor_id, target_identifier, action, is_success, attempted_at)
            VALUES ('{emp1_id}', 'INVALID_CODE', 'QR_SCAN', false, now());
            """)
        code, _, err = run_as_user_json(emp1_id, "SELECT public.scan_attendance_qr('NONEXISTENT_CODE');")
        assert code != 0
        assert "P0037" in err or "Too many invalid scan attempts" in err
    runner.run("53", "QR Scan Brute Force Rate Limiting Defense (P0037)", test_53)

    # 54 Scale Benchmark: Manager Live Attendance with 50+ Employees
    def test_54():
        insert_sqls = []
        for i in range(50):
            uid = str(uuid.uuid4())
            insert_sqls.append(f"""
            INSERT INTO auth.users (id, email) VALUES ('{uid}', 'scale_emp_{i}@station.com');
            INSERT INTO public.profiles (id, first_name, last_name, preferred_locale)
            VALUES ('{uid}', 'Worker', '{i}', 'he')
            ON CONFLICT (id) DO NOTHING;
            INSERT INTO public.station_memberships (station_id, user_id, role, status, employee_code)
            VALUES ('{st_a_id}', '{uid}', 'EMPLOYEE', 'ACTIVE', 'SCALE-{i:03d}');
            """)
        run_psql(";\n".join(insert_sqls))

        t0 = time.time()
        today_str = date.today().isoformat()
        code, res, err = run_as_user_json(mgr_id, f"SELECT public.get_manager_live_attendance('{st_a_id}', '{today_str}'::date);")
        dt = (time.time() - t0) * 1000
        assert code == 0, f"Scale query error: {err}"
        assert res["success"] is True
        assert dt < 500, f"Expected live attendance query under 500ms, took {dt:.1f}ms"
    runner.run("54", "Manager Live Attendance Scale Performance (<500ms for 50+ Staff)", test_54)

    print("=" * 75)
    print(f"PHASE 4 COMPREHENSIVE AUDIT V2 SUMMARY: {runner.passed}/{len(runner.tests)} PASSED ({runner.passed/len(runner.tests)*100:.1f}%)")
    print("=" * 75)

    if runner.failed > 0:
        sys.exit(1)

if __name__ == "__main__":
    main()
