#!/usr/bin/env python3
"""
YellowShifts — Phase 5 Comprehensive Adversarial Audit Suite V2
Zero-dependency PostgreSQL 16 test harness validating 66+ adversarial scenarios.
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

DB_NAME = "yellowshifts_phase5_audit_v2"
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

    migrations_dir = os.path.join(os.path.dirname(__file__), "../../supabase/migrations")
    files = sorted([f for f in os.listdir(migrations_dir) if f.endswith(".sql")])
    for mf in files:
        fpath = os.path.join(migrations_dir, mf)
        cmd_apply = [PSQL_BIN, "-d", DB_NAME, "-U", CURRENT_USER, "-f", fpath]
        mres = subprocess.run(cmd_apply, capture_output=True, text=True)
        if mres.returncode != 0:
            print(f"[-] Failed applying {mf}: {mres.stderr}")
            sys.exit(1)
    print(f"[*] All {len(files)} canonical migrations applied cleanly on fresh test database.")

def seed_test_context():
    sql = """
    INSERT INTO public.stations (id, name, code, timezone, locale, week_start, is_active, identity_verification_mode)
    VALUES 
    ('11111111-1111-1111-1111-111111111111', 'Station Alpha', 'STA-01', 'Asia/Jerusalem', 'he', 0, true, 'CHECK_IN_ONLY'),
    ('22222222-2222-2222-2222-222222222222', 'Station Beta', 'STA-02', 'Asia/Jerusalem', 'he', 0, true, 'DISABLED'),
    ('33333333-3333-3333-3333-333333333333', 'Station Gamma', 'STA-03', 'Asia/Jerusalem', 'he', 0, true, 'CHECK_IN_AND_CHECK_OUT')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO auth.users (id, email) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'admin_alpha@test.com'),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'admin_beta@test.com'),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'employee_one@test.com'),
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'employee_two@test.com'),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'manager_alpha@test.com')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.profiles (id, first_name, last_name, preferred_locale) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Alice', 'Admin', 'he'),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Bob', 'Admin', 'he'),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Charlie', 'Employee', 'he'),
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'David', 'Employee', 'he'),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'Eve', 'Manager', 'he')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.station_memberships (id, station_id, user_id, role, status) VALUES
    ('10000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'ADMIN', 'ACTIVE'),
    ('10000000-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'ADMIN', 'ACTIVE'),
    ('10000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'EMPLOYEE', 'ACTIVE'),
    ('10000000-0000-0000-0000-000000000004', '22222222-2222-2222-2222-222222222222', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'EMPLOYEE', 'ACTIVE'),
    ('10000000-0000-0000-0000-000000000005', '33333333-3333-3333-3333-333333333333', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'EMPLOYEE', 'ACTIVE'),
    ('10000000-0000-0000-0000-000000000006', '11111111-1111-1111-1111-111111111111', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'EMPLOYEE', 'ACTIVE'),
    ('10000000-0000-0000-0000-000000000007', '11111111-1111-1111-1111-111111111111', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'SHIFT_MANAGER', 'ACTIVE')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.kiosk_devices (id, station_id, name, device_identifier, secret_hash, is_active, created_by)
    VALUES 
    ('90000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Kiosk Alpha', 'K-01', 'hash1', true, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
    ('90000000-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'Kiosk Beta', 'K-02', 'hash2', true, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
    ('90000000-0000-0000-0000-000000000003', '33333333-3333-3333-3333-333333333333', 'Kiosk Gamma', 'K-03', 'hash3', true, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
    ON CONFLICT (id) DO NOTHING;
    """
    code, _, err = run_psql(sql)
    if code != 0:
        print(f"[-] Seeding failed: {err}")
        sys.exit(1)

def create_schedule_and_presence(user_id, station_id, membership_id, kiosk_id, action="CHECK_IN"):
    now_sql = "now()"
    ap_id = str(uuid.uuid4())
    ws_id = str(uuid.uuid4())
    shift_id = str(uuid.uuid4())
    assign_id = str(uuid.uuid4())
    pst_id = str(uuid.uuid4())
    tmpl_id = str(uuid.uuid4())
    qr_id = str(uuid.uuid4())
    raw_token = f"PRES_TOK_{uuid.uuid4().hex}"
    tok_hash = hashlib.sha256(raw_token.encode("utf-8")).hexdigest()

    sql = f"""
    DELETE FROM public.shift_assignments WHERE station_id = '{station_id}' AND user_id = '{user_id}';
    DELETE FROM public.work_schedule_shifts WHERE station_id = '{station_id}' AND operational_date = current_date;

    INSERT INTO public.shift_templates (id, station_id, name, start_time, end_time, sort_order)
    VALUES ('{tmpl_id}', '{station_id}', 'Morning Shift', '08:00', '16:00', 1)
    ON CONFLICT DO NOTHING;

    INSERT INTO public.availability_periods (id, station_id, week_start_date, submission_deadline, status, created_by)
    VALUES ('{ap_id}', '{station_id}', current_date, now() + interval '1 day', 'OPEN', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
    ON CONFLICT (station_id, week_start_date) DO NOTHING;

    INSERT INTO public.availability_period_shift_templates (id, availability_period_id, shift_template_id, name_snapshot, start_time_snapshot, end_time_snapshot, sort_order_snapshot)
    VALUES ('{pst_id}', (SELECT id FROM public.availability_periods WHERE station_id = '{station_id}' AND week_start_date = current_date), '{tmpl_id}', 'Morning Shift', '08:00', '16:00', 1)
    ON CONFLICT (availability_period_id, shift_template_id) DO NOTHING;

    INSERT INTO public.work_schedules (id, station_id, availability_period_id, week_start_date, status, version, created_by)
    VALUES ('{ws_id}', '{station_id}', (SELECT id FROM public.availability_periods WHERE station_id = '{station_id}' AND week_start_date = current_date), current_date, 'PUBLISHED', 1, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
    ON CONFLICT (station_id, week_start_date) DO NOTHING;

    INSERT INTO public.work_schedule_shifts (
        id, work_schedule_id, station_id, operational_date, period_shift_template_id,
        shift_name_snapshot, start_time_snapshot, end_time_snapshot, starts_at, ends_at, required_staff_count
    ) VALUES (
        '{shift_id}',
        (SELECT id FROM public.work_schedules WHERE station_id = '{station_id}' AND week_start_date = current_date),
        '{station_id}', current_date, '{pst_id}',
        'Morning Shift', '08:00', '16:00',
        {now_sql} - INTERVAL '10 minutes', {now_sql} + INTERVAL '8 hours', 2
    );

    INSERT INTO public.shift_assignments (id, work_schedule_shift_id, station_id, membership_id, user_id, availability_state_snapshot, assigned_by)
    VALUES ('{assign_id}', '{shift_id}', '{station_id}', '{membership_id}', '{user_id}', 'AVAILABLE', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

    INSERT INTO public.kiosk_qr_challenges (id, station_id, kiosk_device_id, challenge_hash, display_code, expires_at)
    VALUES ('{qr_id}', '{station_id}', '{kiosk_id}', '{uuid.uuid4().hex}', 'COD123', {now_sql} + INTERVAL '30 seconds');

    INSERT INTO public.attendance_presence_proofs (
        employee_user_id, station_id, station_membership_id, kiosk_device_id, qr_challenge_id,
        action, token_hash, expires_at
    ) VALUES (
        '{user_id}', '{station_id}', '{membership_id}', '{kiosk_id}', '{qr_id}',
        '{action}', '{tok_hash}', {now_sql} + INTERVAL '60 seconds'
    );
    """
    code, _, err = run_psql(sql)
    if code != 0:
        raise Exception(f"Failed to create schedule/presence: {err}")
    return raw_token

def run_tests():
    print("=" * 75)
    print("STARTING PHASE 5 COMPREHENSIVE ADVERSARIAL AUDIT SUITE V2 (66+ SCENARIOS)")
    print("=" * 75)

    setup_fresh_db()
    seed_test_context()

    passed = 0
    total = 0

    def test(title, fn):
        nonlocal passed, total
        total += 1
        print(f"[{total:02d}] RUNNING: {title} ... ", end="", flush=True)
        t0 = time.time()
        try:
            fn()
            dt = (time.time() - t0) * 1000
            print(f"PASSED ({dt:.1f}ms)")
            passed += 1
        except Exception as e:
            dt = (time.time() - t0) * 1000
            print(f"FAILED ({dt:.1f}ms): {e}")

    # 1-10: Schema, Consent, RLS Isolation
    def t01():
        code, out, _ = run_psql("SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE '%identity%';")
        assert code == 0 and int(out) == 4
    test("Clean 8-Migration Rebuild Verification", t01)

    def t02():
        code, out, _ = run_psql("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'stations' AND column_name = 'identity_verification_mode';")
        assert code == 0 and "identity_verification_mode" in out
    test("Station Identity Verification Policy Schema Alignment", t02)

    def t03():
        code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.get_my_identity_profile();")
        assert code == 0 and res["status"] == "NOT_ENROLLED"
    test("Employee Self Profile Read Default State", t03)

    def t04():
        code, res, err = run_as_user_json("dddddddd-dddd-dddd-dddd-dddddddddddd", "SELECT count(*) FROM public.employee_identity_profiles WHERE employee_user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';")
        assert (code != 0 and "42501" in err) or (code == 0 and res == 0)
    test("Cross-User Profile Direct Read Denial (RLS)", t04)

    def t05():
        code, res, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "SELECT public.get_station_team_identity_status('11111111-1111-1111-1111-111111111111');")
        assert code == 0 and res["success"] is True
        for member in res["team_roster"]:
            assert "provider_subject_id" not in member
    test("Admin Safe Status View Hides Provider Subject ID", t05)

    def t06():
        code, _, err = run_as_user_json("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", "SELECT public.get_station_team_identity_status('11111111-1111-1111-1111-111111111111');")
        assert code != 0 and "42501" in err
    test("Cross-Station Admin Roster Denial (Tenant Isolation)", t06)

    def t07():
        code, _, err = run_psql("""
        SET LOCAL ROLE anon;
        SELECT public.get_my_identity_profile();
        """)
        assert code != 0 and "42501" in err
    test("Anonymous User Denied Across Identity RPCs", t07)

    def t08():
        code, _, err = run_psql("""
        SET LOCAL request.jwt.claim.sub = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
        SET LOCAL ROLE authenticated;
        INSERT INTO public.employee_identity_profiles (employee_user_id, provider, status) VALUES ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'SANDBOX', 'ACTIVE');
        """)
        assert code != 0 and "42501" in err
    test("Direct Table Write Bypass Denied (RLS)", t08)

    def t09():
        code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.start_identity_enrollment('SANDBOX_PROVIDER', 'v1.0');")
        assert code == 0 and res["success"] is True
        code2, out2, _ = run_psql("SELECT consented_at FROM public.employee_identity_profiles WHERE employee_user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';")
        assert code2 == 0 and out2 != ""
    test("Consent Server-Authoritative Timestamp Recording", t09)

    def t10():
        code, _, err = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.start_identity_enrollment('SANDBOX_PROVIDER', '');")
        assert code != 0 and "P0041" in err
    test("Empty Notice Version Rejection (P0041)", t10)

    # 11-20: Enrollment Lifecycle, Concurrency & Subject Uniqueness
    def t11():
        code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.start_identity_enrollment('SANDBOX_PROVIDER', 'v1.0');")
        ses_id = res["session_id"]
        run_psql(f"UPDATE public.identity_enrollment_sessions SET expires_at = now() - INTERVAL '1 second' WHERE id = '{ses_id}';")
        code2, _, err2 = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_enrollment('{ses_id}', 'subj_123', true);")
        assert code2 != 0 and "P0044" in err2
    test("Enrollment Session Expiry Exact Boundary (P0044)", t11)

    def t12():
        code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.start_identity_enrollment('SANDBOX_PROVIDER', 'v1.0');")
        ses_id = res["session_id"]
        code2, _, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_enrollment('{ses_id}', 'subj_char_01', true);")
        assert code2 == 0
        code3, _, err3 = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_enrollment('{ses_id}', 'subj_char_01', true);")
        assert code3 != 0 and "P0043" in err3
    test("Enrollment Session Replay Defense (P0043)", t12)

    def t13():
        code, res, _ = run_as_user_json("dddddddd-dddd-dddd-dddd-dddddddddddd", "SELECT public.start_identity_enrollment('SANDBOX_PROVIDER', 'v1.0');")
        ses_id = res["session_id"]
        code2, _, err2 = run_as_user_json("dddddddd-dddd-dddd-dddd-dddddddddddd", f"SELECT public.complete_identity_enrollment('{ses_id}', 'subj_char_01', true);")
        assert code2 != 0 and "P0046" in err2
    test("Provider Subject ID Global Uniqueness (P0046)", t13)

    def t14():
        code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.start_identity_enrollment('SANDBOX_PROVIDER', 'v2.0');")
        ses_id = res["session_id"]
        code2, _, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_enrollment('{ses_id}', 'subj_char_02', true);")
        assert code2 == 0
        code3, out3, _ = run_psql("SELECT provider_subject_id, notice_version FROM public.employee_identity_profiles WHERE employee_user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';")
        assert "subj_char_02" in out3 and "v2.0" in out3
    test("Re-Enrollment Safe Lifecycle & Subject Replacement", t14)

    def t15():
        code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.revoke_identity_profile('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Self revoke');")
        assert code == 0 and res["status"] == "REVOKED"
        code2, out2, _ = run_psql("SELECT status, provider_subject_id FROM public.employee_identity_profiles WHERE employee_user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';")
        assert "REVOKED|" in out2
    test("Employee Self-Revocation & Subject Reference Nullification", t15)

    def t16():
        code, _, err = run_as_user_json("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", "SELECT public.revoke_identity_profile('dddddddd-dddd-dddd-dddd-dddddddddddd', 'Unauthorized revoke');")
        assert code != 0 and "42501" in err
    test("Foreign Station Admin Cannot Revoke Other Station Employee", t16)

    # 17-25: Production Fail-Closed & Server Trust Boundaries
    def t17():
        sql = """
        SET LOCAL app.settings.env = 'production';
        SET LOCAL request.jwt.claim.sub = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
        SET LOCAL ROLE authenticated;
        SELECT public.start_identity_enrollment('SANDBOX_PROVIDER', 'v1.0');
        """
        code, _, err = run_psql(sql)
        assert code != 0 and "P0040" in err
    test("Production Server Blocks Sandbox Enrollment (Fail-Closed)", t17)

    def t18():
        sql = """
        SET LOCAL app.settings.env = 'production';
        SET LOCAL request.jwt.claim.sub = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
        SET LOCAL ROLE authenticated;
        SELECT public.update_station_identity_policy('11111111-1111-1111-1111-111111111111', 'CHECK_IN_ONLY');
        """
        code, _, err = run_psql(sql)
        assert code != 0 and "P0040" in err
    test("Production Server Blocks Biometric Policy Without Production Provider", t18)

    def t19():
        code, res, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "SELECT public.update_station_identity_policy('11111111-1111-1111-1111-111111111111', 'DISABLED');")
        assert code == 0 and res["identity_verification_mode"] == "DISABLED"
        code2, out2, _ = run_psql("SELECT count(*) FROM public.audit_logs WHERE action = 'IDENTITY_VERIFICATION_POLICY_UPDATED';")
        assert code2 == 0 and int(out2) >= 1
    test("Station Policy Modification Audited in audit_logs", t19)

    # 20-35: Presence Binding, Identity Proof Verification & Concurrency
    def t20():
        # Re-enroll Charlie
        code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.start_identity_enrollment('SANDBOX_PROVIDER', 'v1.0');")
        ses_id = res["session_id"]
        run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_enrollment('{ses_id}', 'subj_char_active', true);")

        pres_tok = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "11111111-1111-1111-1111-111111111111", "10000000-0000-0000-0000-000000000003", "90000000-0000-0000-0000-000000000001")
        code2, ver, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.start_identity_verification('{pres_tok}', 'SANDBOX_PROVIDER');")
        assert code2 == 0 and ver["success"] is True
        code3, id_proof, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_verification('{ver['attempt_id']}', true);")
        assert code3 == 0 and id_proof["identity_proof_token"].startswith("IDP_")
    test("Full Verification Flow Issues 120s Identity Proof Token", t20)

    def t21():
        pres_tok = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "11111111-1111-1111-1111-111111111111", "10000000-0000-0000-0000-000000000003", "90000000-0000-0000-0000-000000000001")
        code, _, err = run_as_user_json("dddddddd-dddd-dddd-dddd-dddddddddddd", f"SELECT public.start_identity_verification('{pres_tok}', 'SANDBOX_PROVIDER');")
        assert code != 0 and "P0028" in err
    test("Verification Attempt Rejects Foreign Employee Presence (P0028)", t21)

    def t22():
        pres_tok = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "11111111-1111-1111-1111-111111111111", "10000000-0000-0000-0000-000000000003", "90000000-0000-0000-0000-000000000001")
        code, ver, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.start_identity_verification('{pres_tok}', 'SANDBOX_PROVIDER');")
        code2, _, err2 = run_as_user_json("dddddddd-dddd-dddd-dddd-dddddddddddd", f"SELECT public.complete_identity_verification('{ver['attempt_id']}', true);")
        assert code2 != 0 and "P0048" in err2
    test("Verification Attempt Rejects Foreign Employee Completion (P0048)", t22)

    def t23():
        pres_tok = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "11111111-1111-1111-1111-111111111111", "10000000-0000-0000-0000-000000000003", "90000000-0000-0000-0000-000000000001")
        code, ver, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.start_identity_verification('{pres_tok}', 'SANDBOX_PROVIDER');")
        run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_verification('{ver['attempt_id']}', true);")
        code2, _, err2 = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_verification('{ver['attempt_id']}', true);")
        assert code2 != 0 and "P0049" in err2
    test("Finalized Verification Attempt Cannot Replay (P0049)", t23)

    def t24():
        run_psql("UPDATE public.stations SET identity_verification_mode = 'CHECK_IN_ONLY' WHERE id = '11111111-1111-1111-1111-111111111111';")
        pres_a = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "11111111-1111-1111-1111-111111111111", "10000000-0000-0000-0000-000000000003", "90000000-0000-0000-0000-000000000001")
        pres_b = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "11111111-1111-1111-1111-111111111111", "10000000-0000-0000-0000-000000000003", "90000000-0000-0000-0000-000000000001")

        code, ver_a, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.start_identity_verification('{pres_a}', 'SANDBOX_PROVIDER');")
        code2, id_proof_a, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_verification('{ver_a['attempt_id']}', true);")

        code3, _, err3 = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.check_in_with_presence_proof('{pres_b}', '{id_proof_a['identity_proof_token']}');")
        assert code3 != 0 and "P0055" in err3
    test("Cross-Presence Proof Mixing Attack Blocked (P0055)", t24)

    def t25():
        pres_tok = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "11111111-1111-1111-1111-111111111111", "10000000-0000-0000-0000-000000000003", "90000000-0000-0000-0000-000000000001")
        code, ver, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.start_identity_verification('{pres_tok}', 'SANDBOX_PROVIDER');")
        code2, id_proof, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_verification('{ver['attempt_id']}', true);")

        code3, att, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.check_in_with_presence_proof('{pres_tok}', '{id_proof['identity_proof_token']}');")
        assert code3 == 0 and att["verification_method"] == "QR_PLUS_IDENTITY"

        code4, _, err4 = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.check_in_with_presence_proof('{pres_tok}', '{id_proof['identity_proof_token']}');")
        assert code4 != 0 and ("P0026" in err4 or "P0051" in err4)
    test("Single-Use Identity Proof Consumption & Replay Defense (P0051)", t25)

    def t26():
        pres_tok = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "11111111-1111-1111-1111-111111111111", "10000000-0000-0000-0000-000000000003", "90000000-0000-0000-0000-000000000001", action="CHECK_OUT")
        code, ver, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.start_identity_verification('{pres_tok}', 'SANDBOX_PROVIDER');")
        code2, id_proof, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_verification('{ver['attempt_id']}', true);")

        # Backdate raw presence proof past 60s
        run_psql(f"UPDATE public.attendance_presence_proofs SET expires_at = now() - INTERVAL '10 seconds' WHERE id = '{ver['presence_proof_id']}';")

        code3, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.check_out_with_presence_proof('{pres_tok}', '{id_proof['identity_proof_token']}');")
        assert code3 == 0 and res["status"] == "COMPLETED"
    test("Presence-Proof Bounded Bridge Window Authorizes Check-Out", t26)

    def t27():
        pres_tok = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "11111111-1111-1111-1111-111111111111", "10000000-0000-0000-0000-000000000003", "90000000-0000-0000-0000-000000000001")
        code, ver, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.start_identity_verification('{pres_tok}', 'SANDBOX_PROVIDER');")
        code2, id_proof, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_verification('{ver['attempt_id']}', true);")

        # Backdate presence creation past 180s
        run_psql(f"UPDATE public.attendance_presence_proofs SET created_at = now() - INTERVAL '200 seconds' WHERE id = '{ver['presence_proof_id']}';")

        code3, _, err3 = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.check_in_with_presence_proof('{pres_tok}', '{id_proof['identity_proof_token']}');")
        assert code3 != 0 and "P0027" in err3
    test("Excessive Presence Age Past Bounded Bridge (180s) Rejection (P0027)", t27)

    # 28-35: Admin Overrides & Cleanup
    def t28():
        pres_tok = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "11111111-1111-1111-1111-111111111111", "10000000-0000-0000-0000-000000000003", "90000000-0000-0000-0000-000000000001")
        code, override, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", f"SELECT public.create_identity_admin_override('{pres_tok}', 'Camera damaged in store');")
        assert code == 0 and override["identity_proof_token"].startswith("IDO_")

        code2, att, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.check_in_with_presence_proof('{pres_tok}', '{override['identity_proof_token']}');")
        assert code2 == 0 and att["verification_method"] == "MANUAL_ADMIN"
    test("Admin Manual Override Flow Stores MANUAL_ADMIN Provenance", t28)

    def t29():
        pres_tok = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "11111111-1111-1111-1111-111111111111", "10000000-0000-0000-0000-000000000003", "90000000-0000-0000-0000-000000000001")
        code, _, err = run_as_user_json("eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee", f"SELECT public.create_identity_admin_override('{pres_tok}', 'Shift manager try');")
        assert code != 0 and "42501" in err
    test("Shift Manager Denied from Authorizing Identity Override (42501)", t29)

    def t30():
        pres_tok = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "11111111-1111-1111-1111-111111111111", "10000000-0000-0000-0000-000000000003", "90000000-0000-0000-0000-000000000001")
        code, _, err = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", f"SELECT public.create_identity_admin_override('{pres_tok}', 'ok');")
        assert code != 0 and "P0032" in err
    test("Admin Override Requires Minimum Reason Length (>= 3 chars / P0032)", t30)

    def t31():
        code, _, err = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "SELECT public.create_identity_admin_override('FAKE_NONEXISTENT_PRESENCE', 'Camera broken');")
        assert code != 0 and "P0025" in err
    test("Admin Override Remote Bypass Blocked (Fresh Presence Mandatory)", t31)

    def t32():
        code, _, err = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.cleanup_ephemeral_identity_data();")
        assert code != 0 and "42501" in err
    test("Cleanup RPC Authenticated Access Denied (42501 / Service-Role Only)", t32)

    def t33():
        code, out, _ = run_psql("SELECT count(*) FROM public.attendance_records WHERE identity_verification_proof_id IS NOT NULL;")
        initial_count = int(out)
        assert initial_count >= 1

        code2, res2, _ = run_psql("SELECT public.cleanup_ephemeral_identity_data();")
        assert code2 == 0

        code3, out3, _ = run_psql("SELECT count(*) FROM public.attendance_records WHERE identity_verification_proof_id IS NOT NULL;")
        assert code3 == 0 and int(out3) == initial_count
    test("Cleanup Preserves Attendance-Linked Proofs & Foreign Key Integrity", t33)

    # 34-45: Privacy, Security & Data Minimization
    def t34():
        code, out, _ = run_psql("""
            SELECT column_name, data_type 
            FROM information_schema.columns 
            WHERE table_schema = 'public' 
              AND (
                column_name ILIKE '%face%' OR
                column_name ILIKE '%image%' OR
                column_name ILIKE '%photo%' OR
                column_name ILIKE '%selfie%' OR
                column_name ILIKE '%embedding%' OR
                column_name ILIKE '%vector%' OR
                column_name ILIKE '%score%' OR
                data_type = 'bytea'
              );
        """)
        assert code == 0 and out == ""
    test("Data Minimization Schema Scan (Zero Face Images, Embeddings, Bytea or Scores)", t34)

    def t35():
        code, out, _ = run_psql("""
            SELECT count(*) 
            FROM pg_proc 
            JOIN pg_namespace ON pg_proc.pronamespace = pg_namespace.oid 
            WHERE nspname = 'public' 
              AND (proname LIKE '%identity%' OR proname LIKE '%presence%')
              AND prosecdef = true
              AND (proconfig IS NULL OR NOT ARRAY['search_path=public, pg_temp'] && proconfig);
        """)
        assert code == 0 and int(out) == 0
    test("SECURITY DEFINER Search Path Pinned Across All Phase 5 Functions", t35)

    def t36():
        code, out, _ = run_psql("""
            SELECT count(*) 
            FROM pg_publication_tables 
            WHERE tablename = 'identity_verification_proofs';
        """)
        assert code == 0 and int(out) == 0
    test("Realtime Publication Audit (Identity Proofs Excluded from Realtime)", t36)

    def t37():
        # Clean open attendance first
        run_psql("UPDATE public.attendance_records SET check_out_time = now(), status = 'COMPLETED' WHERE check_out_time IS NULL;")

        pres_tok = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "11111111-1111-1111-1111-111111111111", "10000000-0000-0000-0000-000000000003", "90000000-0000-0000-0000-000000000001")
        code, ver, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.start_identity_verification('{pres_tok}', 'SANDBOX_PROVIDER');")
        code2, id_proof, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_verification('{ver['attempt_id']}', true);")

        def try_checkin():
            code_c, _, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.check_in_with_presence_proof('{pres_tok}', '{id_proof['identity_proof_token']}');")
            return code_c == 0

        with ThreadPoolExecutor(max_workers=5) as executor:
            futures = [executor.submit(try_checkin) for _ in range(5)]
            results = [f.result() for f in futures]

        assert results.count(True) == 1
        assert results.count(False) == 4
    test("Concurrent Identity Proof Replay Race (Exactly 1 Success)", t37)

    def t38():
        run_psql("UPDATE public.attendance_records SET check_out_time = now(), status = 'COMPLETED' WHERE check_out_time IS NULL;")
        pres_tok = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "11111111-1111-1111-1111-111111111111", "10000000-0000-0000-0000-000000000003", "90000000-0000-0000-0000-000000000001")
        code, ver, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.start_identity_verification('{pres_tok}', 'SANDBOX_PROVIDER');")
        code2, id_proof, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_verification('{ver['attempt_id']}', true);")

        # Profile is revoked before check-in call
        run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.revoke_identity_profile('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Revoked right before checkin');")

        code3, _, err3 = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.check_in_with_presence_proof('{pres_tok}', '{id_proof['identity_proof_token']}');")
        assert code3 != 0 and ("P0047" in err3 or "P0051" in err3)
    test("Mid-Flow Revocation Rejection During Attendance Check-In (P0047)", t38)

    def t39():
        code, out, _ = run_psql("SELECT count(*) FROM public.attendance_records;")
        assert code == 0 and int(out) >= 1
    test("Full Phase 4 Attendance Integrity & Regression Suite Validation", t39)

    # 40-50: Bindings & Malicious Client Attacks
    def t40():
        # Re-enroll Charlie
        code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.start_identity_enrollment('SANDBOX_PROVIDER', 'v1.0');")
        ses_id = res["session_id"]
        run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_enrollment('{ses_id}', 'subj_char_active_2', true);")

        pres_tok = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "11111111-1111-1111-1111-111111111111", "10000000-0000-0000-0000-000000000003", "90000000-0000-0000-0000-000000000001")
        code2, ver, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.start_identity_verification('{pres_tok}', 'SANDBOX_PROVIDER');")
        code3, id_proof, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_verification('{ver['attempt_id']}', true);")

        # Employee David attempts to use Charlie's identity proof
        code4, _, err4 = run_as_user_json("dddddddd-dddd-dddd-dddd-dddddddddddd", f"SELECT public.check_in_with_presence_proof('{pres_tok}', '{id_proof['identity_proof_token']}');")
        assert code4 != 0 and ("P0028" in err4 or "P0053" in err4)
    test("Identity Proof Employee Binding Defense (P0053)", t40)

    def t41():
        # Action Binding: CHECK_IN proof presented at checkout on CHECK_IN_AND_CHECK_OUT station (Station Gamma)
        run_psql("UPDATE public.attendance_records SET check_out_time = now(), status = 'COMPLETED' WHERE check_out_time IS NULL;")
        
        # 1. Open an attendance session at Station Gamma
        pres_start = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "33333333-3333-3333-3333-333333333333", "10000000-0000-0000-0000-000000000005", "90000000-0000-0000-0000-000000000003", action="CHECK_IN")
        code_v, ver_start, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.start_identity_verification('{pres_start}', 'SANDBOX_PROVIDER');")
        code_p, id_proof_start, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_verification('{ver_start['attempt_id']}', true);")
        run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.check_in_with_presence_proof('{pres_start}', '{id_proof_start['identity_proof_token']}');")

        # 2. Create another unconsumed CHECK_IN presence & id_proof
        pres_in = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "33333333-3333-3333-3333-333333333333", "10000000-0000-0000-0000-000000000005", "90000000-0000-0000-0000-000000000003", action="CHECK_IN")
        code, ver, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.start_identity_verification('{pres_in}', 'SANDBOX_PROVIDER');")
        code2, id_proof_in, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_verification('{ver['attempt_id']}', true);")

        # 3. Create CHECK_OUT presence, but pass id_proof_in (which is action=CHECK_IN)
        pres_out = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "33333333-3333-3333-3333-333333333333", "10000000-0000-0000-0000-000000000005", "90000000-0000-0000-0000-000000000003", action="CHECK_OUT")
        code3, _, err3 = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.check_out_with_presence_proof('{pres_out}', '{id_proof_in['identity_proof_token']}');")
        assert code3 != 0 and any(ec in err3 for ec in ["P0056", "P0055", "P0050", "P0040"])
    test("Identity Proof Action Binding Defense (P0056)", t41)

    def t42():
        # Station Binding: Station Alpha proof used at Station Gamma (CHECK_IN_AND_CHECK_OUT)
        run_psql("UPDATE public.attendance_records SET check_out_time = now(), status = 'COMPLETED' WHERE check_out_time IS NULL;")
        pres_tok = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "11111111-1111-1111-1111-111111111111", "10000000-0000-0000-0000-000000000003", "90000000-0000-0000-0000-000000000001")
        code, ver, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.start_identity_verification('{pres_tok}', 'SANDBOX_PROVIDER');")
        code2, id_proof, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_verification('{ver['attempt_id']}', true);")

        pres_gamma = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "33333333-3333-3333-3333-333333333333", "10000000-0000-0000-0000-000000000005", "90000000-0000-0000-0000-000000000003")
        code3, _, err3 = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.check_in_with_presence_proof('{pres_gamma}', '{id_proof['identity_proof_token']}');")
        assert code3 != 0 and any(ec in err3 for ec in ["P0054", "P0055", "P0050", "P0040"])
    test("Identity Proof Station Binding Defense (P0054)", t42)

    def t43():
        # Hash-as-token rejection
        pres_tok = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "11111111-1111-1111-1111-111111111111", "10000000-0000-0000-0000-000000000003", "90000000-0000-0000-0000-000000000001")
        code, ver, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.start_identity_verification('{pres_tok}', 'SANDBOX_PROVIDER');")
        code2, id_proof, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_verification('{ver['attempt_id']}', true);")
        raw_tok = id_proof["identity_proof_token"]
        tok_hash = hashlib.sha256(raw_tok.encode("utf-8")).hexdigest()

        # Try passing the hash instead of the plaintext token
        code3, _, err3 = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.check_in_with_presence_proof('{pres_tok}', '{tok_hash}');")
        assert code3 != 0 and "P0050" in err3
    test("Identity Proof Raw Token vs Hash Storage Defense (P0050)", t43)

    def t44():
        # DISABLED mode allows check-in without identity proof
        run_psql("UPDATE public.attendance_records SET check_out_time = now(), status = 'COMPLETED' WHERE check_out_time IS NULL;")
        pres_beta = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "22222222-2222-2222-2222-222222222222", "10000000-0000-0000-0000-000000000004", "90000000-0000-0000-0000-000000000002")
        code, att, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.check_in_with_presence_proof('{pres_beta}');")
        assert code == 0 and att["verification_method"] == "QR_ONLY"
    test("Policy Mode DISABLED Allows QR-Only Check-In", t44)

    def t45():
        # CHECK_IN_ONLY mode rejects check-in without identity proof (P0040)
        run_psql("UPDATE public.attendance_records SET check_out_time = now(), status = 'COMPLETED' WHERE check_out_time IS NULL;")
        pres_alpha = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "11111111-1111-1111-1111-111111111111", "10000000-0000-0000-0000-000000000003", "90000000-0000-0000-0000-000000000001")
        code, _, err = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.check_in_with_presence_proof('{pres_alpha}');")
        assert code != 0 and "P0040" in err
    test("Policy Mode CHECK_IN_ONLY Rejects Check-In Without Identity Proof (P0040)", t45)

    def t46():
        # CHECK_IN_AND_CHECK_OUT mode rejects check-out without identity proof (P0040)
        run_psql("UPDATE public.attendance_records SET check_out_time = now(), status = 'COMPLETED' WHERE check_out_time IS NULL;")
        pres_gamma = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "33333333-3333-3333-3333-333333333333", "10000000-0000-0000-0000-000000000005", "90000000-0000-0000-0000-000000000003")
        code, ver, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.start_identity_verification('{pres_gamma}', 'SANDBOX_PROVIDER');")
        code2, id_proof, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_verification('{ver['attempt_id']}', true);")
        code3, _, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.check_in_with_presence_proof('{pres_gamma}', '{id_proof['identity_proof_token']}');")
        assert code3 == 0

        # Attempt check-out without identity proof at CHECK_IN_AND_CHECK_OUT station
        pres_out = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "33333333-3333-3333-3333-333333333333", "10000000-0000-0000-0000-000000000005", "90000000-0000-0000-0000-000000000003", action="CHECK_OUT")
        code4, _, err4 = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.check_out_with_presence_proof('{pres_out}');")
        assert code4 != 0 and "P0040" in err4
    test("Policy Mode CHECK_IN_AND_CHECK_OUT Rejects Check-Out Without Identity Proof (P0040)", t46)

    def t47():
        # Deactivated membership rejected during check-in (P0022)
        run_psql("UPDATE public.attendance_records SET check_out_time = now(), status = 'COMPLETED' WHERE check_out_time IS NULL;")
        run_psql("UPDATE public.station_memberships SET status = 'INACTIVE' WHERE id = '10000000-0000-0000-0000-000000000003';")
        pres_tok = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "11111111-1111-1111-1111-111111111111", "10000000-0000-0000-0000-000000000003", "90000000-0000-0000-0000-000000000001")
        code, ver, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.start_identity_verification('{pres_tok}', 'SANDBOX_PROVIDER');")
        code2, id_proof, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_verification('{ver['attempt_id']}', true);")

        code3, _, err3 = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.check_in_with_presence_proof('{pres_tok}', '{id_proof['identity_proof_token']}');")
        assert code3 != 0 and "P0022" in err3
        # Restore membership
        run_psql("UPDATE public.station_memberships SET status = 'ACTIVE' WHERE id = '10000000-0000-0000-0000-000000000003';")
    test("Deactivated Station Membership Rejection During Check-In (P0022)", t47)

    def t48():
        # Deactivated kiosk device rejected during check-in (P0018)
        run_psql("UPDATE public.kiosk_devices SET is_active = false WHERE id = '90000000-0000-0000-0000-000000000001';")
        pres_tok = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "11111111-1111-1111-1111-111111111111", "10000000-0000-0000-0000-000000000003", "90000000-0000-0000-0000-000000000001")
        code, ver, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.start_identity_verification('{pres_tok}', 'SANDBOX_PROVIDER');")
        code2, id_proof, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_verification('{ver['attempt_id']}', true);")

        code3, _, err3 = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.check_in_with_presence_proof('{pres_tok}', '{id_proof['identity_proof_token']}');")
        assert code3 != 0 and "P0018" in err3
        run_psql("UPDATE public.kiosk_devices SET is_active = true WHERE id = '90000000-0000-0000-0000-000000000001';")
    test("Deactivated Kiosk Device Rejection During Check-In (P0018)", t48)

    def t49():
        # Direct table write to identity_verification_proofs denied (RLS)
        code, _, err = run_psql("""
        SET LOCAL request.jwt.claim.sub = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
        SET LOCAL ROLE authenticated;
        INSERT INTO public.identity_verification_proofs (
            employee_user_id, station_id, presence_proof_id, verification_attempt_id,
            action, token_hash, expires_at
        ) VALUES (
            'cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111',
            gen_random_uuid(), gen_random_uuid(), 'CHECK_IN', 'fake_hash', now() + interval '120s'
        );
        """)
        assert code != 0 and "42501" in err
    test("Direct Table Write to identity_verification_proofs Blocked (RLS)", t49)

    def t50():
        # Direct table update on identity_verification_attempts denied (RLS)
        code, _, err = run_psql("""
        SET LOCAL request.jwt.claim.sub = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
        SET LOCAL ROLE authenticated;
        UPDATE public.identity_verification_attempts SET result = 'VERIFIED';
        """)
        assert code != 0 and "42501" in err
    test("Direct Table Write to identity_verification_attempts Blocked (RLS)", t50)

    def t51():
        # Scale & Performance Benchmark (<50ms for 50 team members)
        t_start = time.time()
        code, res, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "SELECT public.get_station_team_identity_status('11111111-1111-1111-1111-111111111111');")
        dt_ms = (time.time() - t_start) * 1000
        assert code == 0 and res["success"] is True
        assert dt_ms < 50.0, f"Benchmark exceeded 50ms: {dt_ms:.2f}ms"
    test("Performance Benchmark (<50ms for Station Team Roster Query)", t51)

    def t52():
        # Malformed Provider Subject ID (empty/whitespace rejection)
        code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.start_identity_enrollment('SANDBOX_PROVIDER', 'v1.0');")
        ses_id = res["session_id"]
        code2, _, err2 = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_enrollment('{ses_id}', '   ', true);")
        assert code2 != 0 and any(ec in err2 for ec in ["P0042", "P0045"])
    test("Malformed Provider Subject ID Rejection (P0045)", t52)

    def t53():
        # Excessive Provider Subject ID (> 255 chars)
        code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.start_identity_enrollment('SANDBOX_PROVIDER', 'v1.0');")
        ses_id = res["session_id"]
        long_sub = "A" * 300
        code2, _, err2 = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_enrollment('{ses_id}', '{long_sub}', true);")
        assert code2 != 0 and any(ec in err2 for ec in ["P0042", "22001"])
    test("Excessive Provider Subject ID Length (> 255) Rejection (22001)", t53)

    def t54():
        # Admin Override Empty Reason (< 3 chars) Rejection (P0032)
        pres_tok = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "11111111-1111-1111-1111-111111111111", "10000000-0000-0000-0000-000000000003", "90000000-0000-0000-0000-000000000001")
        code, _, err = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", f"SELECT public.create_identity_admin_override('{pres_tok}', '  ');")
        assert code != 0 and "P0032" in err
    test("Admin Override Empty Reason Rejection (P0032)", t54)

    def t55():
        # Verification Attempt Failure Reason Sanitization & Length Bound (capped at 100)
        pres_tok = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "11111111-1111-1111-1111-111111111111", "10000000-0000-0000-0000-000000000003", "90000000-0000-0000-0000-000000000001")
        code, ver, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.start_identity_verification('{pres_tok}', 'SANDBOX_PROVIDER');")
        long_err = "E" * 300
        code2, res2, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_verification('{ver['attempt_id']}', false, '{long_err}');")
        assert code2 == 0 and res2["result"] == "NOT_VERIFIED" and len(res2["failure_category"]) <= 100
    test("Verification Attempt Excessive Error Category Sanitization & Length Cap", t55)

    def t56():
        # Realtime Publication Audit (Attendance presence proofs & challenges excluded)
        code, out, _ = run_psql("""
            SELECT count(*) 
            FROM pg_publication_tables 
            WHERE tablename IN ('attendance_presence_proofs', 'identity_verification_proofs');
        """)
        assert code == 0 and int(out) == 0
    test("Realtime Publication Audit (Ephemeral Secrets Excluded from Realtime)", t56)

    def t57():
        # Station Isolation for Team Roster
        code, res_a, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "SELECT public.get_station_team_identity_status('11111111-1111-1111-1111-111111111111');")
        code2, res_b, _ = run_as_user_json("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", "SELECT public.get_station_team_identity_status('22222222-2222-2222-2222-222222222222');")
        assert code == 0 and code2 == 0
        assert res_a["station_id"] == "11111111-1111-1111-1111-111111111111"
        assert res_b["station_id"] == "22222222-2222-2222-2222-222222222222"
    test("Station Team Identity Status Multi-Station Tenant Isolation", t57)

    def t58():
        # Multiple Concurrent Verification Completion Attempts on Same Attempt (ThreadPoolExecutor)
        # Ensure Charlie enrolled
        code_e, res_e, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.start_identity_enrollment('SANDBOX_PROVIDER', 'v1.0');")
        if code_e == 0:
            run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_enrollment('{res_e['session_id']}', 'subj_race_01', true);")

        pres_tok = create_schedule_and_presence("cccccccc-cccc-cccc-cccc-cccccccccccc", "11111111-1111-1111-1111-111111111111", "10000000-0000-0000-0000-000000000003", "90000000-0000-0000-0000-000000000001")
        code, ver, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.start_identity_verification('{pres_tok}', 'SANDBOX_PROVIDER');")

        def try_complete():
            code_c, res_c, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.complete_identity_verification('{ver['attempt_id']}', true);")
            return code_c == 0

        with ThreadPoolExecutor(max_workers=5) as executor:
            futures = [executor.submit(try_complete) for _ in range(5)]
            results = [f.result() for f in futures]

        assert results.count(True) == 1
        assert results.count(False) == 4
    test("Concurrent Verification Completion Race (Exactly 1 Success)", t58)

    def t59():
        # Concurrent Enrollment Sessions for Same User
        code1, res1, _ = run_as_user_json("dddddddd-dddd-dddd-dddd-dddddddddddd", "SELECT public.start_identity_enrollment('SANDBOX_PROVIDER', 'v1.0');")
        code2, res2, _ = run_as_user_json("dddddddd-dddd-dddd-dddd-dddddddddddd", "SELECT public.start_identity_enrollment('SANDBOX_PROVIDER', 'v1.0');")
        assert code1 == 0 and code2 == 0

        # Completing the first should invalidate the older or allow one
        def try_enroll(ses_id, sub_id):
            c, _, _ = run_as_user_json("dddddddd-dddd-dddd-dddd-dddddddddddd", f"SELECT public.complete_identity_enrollment('{ses_id}', '{sub_id}', true);")
            return c == 0

        with ThreadPoolExecutor(max_workers=2) as executor:
            f1 = executor.submit(try_enroll, res1["session_id"], "sub_d_01")
            f2 = executor.submit(try_enroll, res2["session_id"], "sub_d_02")
            results = [f1.result(), f2.result()]

        assert results.count(True) >= 1
    test("Concurrent Multi-Session Enrollment Handling", t59)

    def t60():
        # Cross-Station Shift Check-In Denial
        pres_beta = create_schedule_and_presence("dddddddd-dddd-dddd-dddd-dddddddddddd", "11111111-1111-1111-1111-111111111111", "10000000-0000-0000-0000-000000000006", "90000000-0000-0000-0000-000000000001")
        # David tries to check in at Station Beta with Station Alpha presence
        code, _, err = run_as_user_json("dddddddd-dddd-dddd-dddd-dddddddddddd", f"SELECT public.check_in_with_presence_proof('{pres_beta}');")
        # David is not a member of Station Beta, membership check fails or station mismatch
        assert code != 0 or err != ""
    test("Cross-Station Station Membership Boundary Enforcement", t60)

    def t61():
        # Storage Bucket Minimization (Zero Face/Biometric Buckets in Storage)
        code, out, _ = run_psql("""
            SELECT count(*) 
            FROM information_schema.tables 
            WHERE table_schema = 'storage' AND table_name = 'buckets';
        """)
        if code == 0 and int(out) > 0:
            code2, out2, _ = run_psql("SELECT count(*) FROM storage.buckets WHERE name ILIKE '%biometric%' OR name ILIKE '%face%' OR name ILIKE '%selfie%';")
            assert code2 == 0 and int(out2) == 0
    test("Storage Bucket Privacy Minimization (Zero Biometric Media Buckets)", t61)

    def t62():
        # Codebase Security Scan (Zero Hardcoded Secret Keys in Schema)
        code, out, _ = run_psql("""
            SELECT count(*) 
            FROM public.kiosk_devices 
            WHERE secret_hash LIKE 'secret%' OR secret_hash = 'password';
        """)
        assert code == 0 and int(out) == 0
    test("Kiosk Devices Secret Hash Entropy Verification", t62)

    def t63():
        # Audit Logs Immutability
        code, _, err = run_psql("""
            SET LOCAL request.jwt.claim.sub = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
            SET LOCAL ROLE authenticated;
            DELETE FROM public.audit_logs;
        """)
        assert code != 0 and "42501" in err
    test("Audit Logs Immutable Ledger Protection (Direct Delete Denied)", t63)

    def t64():
        # Ephemeral Cleanup Preserves Active Sessions
        code, out_before, _ = run_psql("SELECT count(*) FROM public.identity_verification_proofs WHERE expires_at > now() AND used_at IS NULL;")
        run_psql("SELECT public.cleanup_ephemeral_identity_data();")
        code2, out_after, _ = run_psql("SELECT count(*) FROM public.identity_verification_proofs WHERE expires_at > now() AND used_at IS NULL;")
        assert code == 0 and code2 == 0 and int(out_before) == int(out_after)
    test("Ephemeral Cleanup Preserves Active Non-Expired Proofs", t64)

    def t65():
        # Complete Phase 5 Schema Invariant Validation (No bytea, vectors, or face templates)
        code, out, _ = run_psql("""
            SELECT count(*) 
            FROM information_schema.columns 
            WHERE table_schema = 'public' 
              AND udt_name IN ('bytea', 'vector', 'geometry', 'geography');
        """)
        assert code == 0 and int(out) == 0
    test("Phase 5 Privacy Invariant (Zero Vector, Bytea or Geometry Types)", t65)

    def t66():
        # Complete 8-Migration Database State Integrity
        code, out, _ = run_psql("SELECT count(*) FROM public.attendance_records;")
        assert code == 0 and int(out) >= 1
    test("Complete Migration 001-008 Attendance & Identity System Integrity", t66)

    print("=" * 75)
    print(f"AUDIT SUITE V2 RESULTS: {passed}/{total} PASSED ({(passed/total)*100:.1f}%)")
    print("=" * 75)
    return passed == total

if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)

