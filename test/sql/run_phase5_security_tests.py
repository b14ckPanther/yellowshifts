#!/usr/bin/env python3
"""
YellowShifts Phase 5 — Identity Verification Security Test Suite
12 Core Security Invariants:
1. Profile self-read
2. Cross-user profile direct read denial (RLS)
3. Admin station team status visibility
4. Cross-station team status denial (RLS / Tenant Isolation)
5. Direct identity proof table insert/write lockout (RLS)
6. Direct attempt table mutation lockout (RLS)
7. Policy update admin-only enforcement
8. Shift manager policy change rejection (42501)
9. Anonymous role complete lockout across identity RPCs
10. Provider subject ID column privacy / hiding
11. Direct attendance identity field forgery denied
12. Audit log anti-forgery
"""

import sys
import os
import shutil
import subprocess
import time
import uuid
import json

PSQL_BIN = shutil.which("psql") or "/opt/homebrew/opt/postgresql@16/bin/psql"
if not os.path.exists(PSQL_BIN):
    PSQL_BIN = shutil.which("psql") or "psql"
if not os.path.exists(PSQL_BIN):
    PSQL_BIN = "psql"

DB_NAME = "yellowshifts_phase5_security_test"
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

def main():
    print("=" * 75)
    print("STARTING PHASE 5 SECURITY INVARIANTS TEST SUITE (12 TESTS)")
    print("=" * 75)

    setup_fresh_db()

    # Fixtures
    admin_a = create_user_and_profile("admin_sec_a@station.com", "David", "AdminA")
    mgr_a = create_user_and_profile("mgr_sec_a@station.com", "Sarah", "ManagerA")
    emp1_a = create_user_and_profile("emp1_sec_a@station.com", "Alex", "WorkerA")
    emp2_a = create_user_and_profile("emp2_sec_a@station.com", "Maya", "WorkerA")
    admin_b = create_user_and_profile("admin_sec_b@other.com", "Dan", "AdminB")
    emp_b = create_user_and_profile("emp_sec_b@other.com", "Ben", "WorkerB")

    st_a = str(uuid.uuid4())
    st_b = str(uuid.uuid4())

    run_psql(f"""
    INSERT INTO public.stations (id, name, code, timezone, locale, is_active, identity_verification_mode)
    VALUES 
    ('{st_a}', 'תחנת כורדני', 'YLW-KRD-01', 'Asia/Jerusalem', 'he', true, 'DISABLED'),
    ('{st_b}', 'תחנת לב המפרץ', 'YLW-LVM-02', 'Asia/Jerusalem', 'he', true, 'DISABLED');

    INSERT INTO public.station_memberships (station_id, user_id, role, status, employee_code)
    VALUES
    ('{st_a}', '{admin_a}', 'ADMIN', 'ACTIVE', 'ADM-A01'),
    ('{st_a}', '{mgr_a}', 'SHIFT_MANAGER', 'ACTIVE', 'MGR-A01'),
    ('{st_a}', '{emp1_a}', 'EMPLOYEE', 'ACTIVE', 'EMP-A01'),
    ('{st_a}', '{emp2_a}', 'EMPLOYEE', 'ACTIVE', 'EMP-A02'),
    ('{st_b}', '{admin_b}', 'ADMIN', 'ACTIVE', 'ADM-B01'),
    ('{st_b}', '{emp_b}', 'EMPLOYEE', 'ACTIVE', 'EMP-B01');
    """)

    passed = 0
    total = 0

    def run_test(num, name, fn):
        nonlocal passed, total
        total += 1
        sys.stdout.write(f"[{num:02d}] RUNNING: {name} ... ")
        sys.stdout.flush()
        t0 = time.time()
        try:
            fn()
            dt = (time.time() - t0) * 1000
            sys.stdout.write(f"PASSED ({dt:.1f}ms)\n")
            passed += 1
        except Exception as e:
            dt = (time.time() - t0) * 1000
            sys.stdout.write(f"FAILED ({dt:.1f}ms)\n")
            print(f"    --> ERROR: {e}")

    # 1 Profile Self-Read
    def test_01():
        # Enroll emp1_a
        code_s, res_s, _ = run_as_user_json(emp1_a, "SELECT public.start_identity_enrollment('SANDBOX_PROVIDER', 'v1.0');")
        assert code_s == 0
        ses_id = res_s["session_id"]

        code_c, res_c, _ = run_as_user_json(emp1_a, f"SELECT public.complete_identity_enrollment('{ses_id}', 'SUBJ_EMP1_001', true);")
        assert code_c == 0
        assert res_c["status"] == "ACTIVE"

        # Query via RPC
        code_p, res_p, _ = run_as_user_json(emp1_a, "SELECT public.get_my_identity_profile();")
        assert code_p == 0
        assert res_p["enrolled"] is True
        assert res_p["status"] == "ACTIVE"
        assert res_p["notice_version"] == "v1.0"
    run_test(1, "Profile Self-Read via get_my_identity_profile RPC", test_01)

    # 2 Cross-User Profile Direct Read Denial
    def test_02():
        code, out, _ = run_as_user_json(emp2_a, f"SELECT * FROM public.employee_identity_profiles WHERE employee_user_id = '{emp1_a}';")
        assert out == "" or out is None or out == [], f"Expected 0 rows for cross-user profile read, got: {out}"
    run_test(2, "Cross-User Profile Direct Read Denial (RLS)", test_02)

    # 3 Admin Station Team Status Visibility
    def test_03():
        code, res, _ = run_as_user_json(admin_a, f"SELECT public.get_station_team_identity_status('{st_a}');")
        assert code == 0
        assert res["success"] is True
        roster = res["team_roster"]
        emp1_entry = next((e for e in roster if e["user_id"] == emp1_a), None)
        assert emp1_entry is not None
        assert emp1_entry["identity_status"] == "ACTIVE"
        # Ensure provider_subject_id is NOT in the returned roster
        assert "provider_subject_id" not in emp1_entry
    run_test(3, "Admin Station Team Status Visibility & Subject ID Protection", test_03)

    # 4 Cross-Station Team Status Denial
    def test_04():
        code, _, err = run_as_user_json(admin_b, f"SELECT public.get_station_team_identity_status('{st_a}');")
        assert code != 0
        assert "42501" in err or "Access denied" in err
    run_test(4, "Cross-Station Team Status Denial (Tenant Isolation)", test_04)

    # 5 Direct Identity Proof Table Insert/Write Lockout
    def test_05():
        code, _, _ = run_as_user_json(emp1_a, f"""
        INSERT INTO public.identity_verification_proofs (
            employee_user_id, station_id, presence_proof_id, verification_attempt_id,
            action, token_hash, expires_at
        ) VALUES (
            '{emp1_a}', '{st_a}', gen_random_uuid(), gen_random_uuid(),
            'CHECK_IN', 'forged_hash_123', now() + INTERVAL '120 seconds'
        );
        """)
        assert code != 0
    run_test(5, "Direct Identity Proof Table Write Lockout (RLS)", test_05)

    # 6 Direct Attempt Table Mutation Lockout
    def test_06():
        code, _, _ = run_as_user_json(emp1_a, f"""
        INSERT INTO public.identity_verification_attempts (
            employee_user_id, station_id, presence_proof_id, provider, result
        ) VALUES (
            '{emp1_a}', '{st_a}', gen_random_uuid(), 'FORGED_PROVIDER', 'VERIFIED'
        );
        """)
        assert code != 0
    run_test(6, "Direct Attempt Table Write Lockout (RLS)", test_06)

    # 7 Policy Update Admin-Only Enforcement
    def test_07():
        code, res, _ = run_as_user_json(admin_a, f"SELECT public.update_station_identity_policy('{st_a}', 'CHECK_IN_ONLY');")
        assert code == 0
        assert res["success"] is True
        assert res["identity_verification_mode"] == "CHECK_IN_ONLY"
    run_test(7, "Policy Update Admin-Only Enforcement", test_07)

    # 8 Shift Manager Policy Change Rejection
    def test_08():
        code, _, err = run_as_user_json(mgr_a, f"SELECT public.update_station_identity_policy('{st_a}', 'DISABLED');")
        assert code != 0
        assert "42501" in err or "Only station admins" in err
    run_test(8, "Shift Manager Policy Change Rejection (42501)", test_08)

    # 9 Anonymous Role Complete Lockout Across Identity RPCs
    def test_09():
        code, _, err = run_psql("SET LOCAL ROLE anon; SELECT public.start_identity_enrollment('SANDBOX_PROVIDER');")
        assert code != 0
        assert "42501" in err or "permission denied" in err or "Authentication required" in err
    run_test(9, "Anonymous Role Complete Lockout Across Identity RPCs", test_09)

    # 10 Provider Subject ID Column Privacy
    def test_10():
        # Even manager cannot directly read provider_subject_id from other employees
        code, out, _ = run_as_user_json(mgr_a, f"SELECT provider_subject_id FROM public.employee_identity_profiles WHERE employee_user_id = '{emp1_a}';")
        assert out == "" or out is None or out == [], f"Expected 0 rows for direct subject ID read by manager, got: {out}"
    run_test(10, "Provider Subject ID Column Privacy (Zero Biometric ID Leakage)", test_10)

    # 11 Direct Attendance Identity Field Forgery Denied
    def test_11():
        # Employee cannot update attendance_records directly to attach identity_verification_proof_id
        code, _, _ = run_as_user_json(emp1_a, f"""
        UPDATE public.attendance_records
        SET identity_verification_proof_id = gen_random_uuid()
        WHERE employee_user_id = '{emp1_a}';
        """)
        assert code != 0
    run_test(11, "Direct Attendance Identity Field Forgery Denied (RLS)", test_11)

    # 12 Audit Log Anti-Forgery
    def test_12():
        code, _, _ = run_as_user_json(admin_a, f"""
        INSERT INTO public.audit_logs (station_id, actor_id, action, resource_type, resource_id)
        VALUES ('{st_a}', '{admin_a}', 'FORGED_AUDIT_LOG', 'test', 'test_123');
        """)
        assert code != 0
    run_test(12, "Audit Log Direct Client Write Lockout (Anti-Forgery)", test_12)

    print("=" * 75)
    print(f"PHASE 5 SECURITY TEST RESULTS: {passed}/{total} PASSED ({passed/total*100:.1f}%)")
    print("=" * 75)

    if passed != total:
        sys.exit(1)

if __name__ == "__main__":
    main()
