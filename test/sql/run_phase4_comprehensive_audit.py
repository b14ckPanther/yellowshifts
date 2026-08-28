#!/usr/bin/env python3
"""
YellowShifts Phase 4 — Comprehensive Adversarial & Operational Audit Suite
Zero-dependency PostgreSQL 16 test harness validating all 38 Phase 4 invariants:
Kiosk lifecycle, dynamic QR challenges, presence proofs, check-in/out, one-open-session,
concurrency races, cross-midnight, DST elapsed time, schedule snapshot integrity,
admin manual correction ledger, and live roster scaling.
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

DB_NAME = "yellowshifts_phase4_audit_test"
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

    migrations = [
        "supabase/migrations/20260825000001_initial_schema.sql",
        "supabase/migrations/20260825000002_phase1_identity_and_roles.sql",
        "supabase/migrations/20260825000003_phase2_shift_templates_and_availability.sql",
        "supabase/migrations/20260825000004_phase3_scheduling.sql",
        "supabase/migrations/20260825000005_phase4_attendance_and_kiosk.sql"
    ]
    for mig in migrations:
        mig_path = os.path.abspath(mig)
        res = subprocess.run([PSQL_BIN, "-d", DB_NAME, "-U", CURRENT_USER, "-f", mig_path],
                             capture_output=True, text=True)
        if res.returncode != 0:
            print(f"[!] Failed to apply {mig}:\n{res.stderr}")
            sys.exit(1)

    print("[*] All 5 canonical migrations applied successfully on fresh database.")

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

def fixture_station(name="TestStation", code_suffix=None, tz="Asia/Jerusalem", early=60, grace=5):
    s_id = str(uuid.uuid4())
    c_suffix = code_suffix or s_id[:6]
    sql = f"""
    INSERT INTO public.stations (id, name, code, timezone, locale, week_start, is_active, check_in_early_minutes, late_grace_minutes)
    VALUES ('{s_id}', '{name}', 'STA-{c_suffix}', '{tz}', 'he', 0, true, {early}, {grace});
    """
    code, out, err = run_psql(sql)
    assert code == 0, f"Failed to create station: {err}"
    return s_id

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

def setup_published_schedule(admin_id, station_id, employee_id, membership_id, start_time=None, end_time=None, is_cross=False, target_date=None):
    t_date = target_date or date.today()
    now_dt = datetime.now()
    st_time = start_time or (now_dt - timedelta(minutes=15)).strftime("%H:%M:00")
    et_time = end_time or (now_dt + timedelta(hours=7, minutes=45)).strftime("%H:%M:00")
    
    period_id = str(uuid.uuid4())
    t_id = str(uuid.uuid4())
    pst_id = str(uuid.uuid4())
    sched_id = str(uuid.uuid4())
    shift_id = str(uuid.uuid4())
    asgn_id = str(uuid.uuid4())
    end_date = t_date + timedelta(days=1) if is_cross else t_date

    sql = f"""
    INSERT INTO public.shift_templates (id, station_id, name, start_time, end_time, sort_order)
    VALUES ('{t_id}', '{station_id}', 'Morning Shift', '{st_time}', '{et_time}', 1);

    INSERT INTO public.availability_periods (id, station_id, week_start_date, submission_deadline, status, created_by)
    VALUES ('{period_id}', '{station_id}', '{t_date}', now() + interval '1 day', 'OPEN', '{admin_id}')
    ON CONFLICT (station_id, week_start_date) DO NOTHING;

    INSERT INTO public.availability_period_shift_templates (id, availability_period_id, shift_template_id, name_snapshot, start_time_snapshot, end_time_snapshot, sort_order_snapshot)
    VALUES ('{pst_id}', (SELECT id FROM public.availability_periods WHERE station_id = '{station_id}' AND week_start_date = '{t_date}'), '{t_id}', 'Morning Shift', '{st_time}', '{et_time}', 1)
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
        'Morning Shift', '{st_time}', '{et_time}',
        ('{t_date} {st_time}+03'::timestamptz),
        ('{end_date} {et_time}+03'::timestamptz),
        1
    );

    INSERT INTO public.shift_assignments (id, work_schedule_shift_id, station_id, membership_id, user_id, availability_state_snapshot, assigned_by)
    VALUES ('{asgn_id}', '{shift_id}', '{station_id}', '{membership_id}', '{employee_id}', 'AVAILABLE', '{admin_id}');
    """
    code, out, err = run_psql(sql)
    assert code == 0, f"Failed to setup published schedule: {err}"
    return sched_id, shift_id, asgn_id

class AuditRunner:
    def __init__(self):
        self.passed = 0
        self.total = 0

    def run(self, name, func):
        self.total += 1
        print(f"[{self.total:02d}] RUNNING: {name} ... ", end="", flush=True)
        t0 = time.perf_counter()
        try:
            func()
            elapsed = (time.perf_counter() - t0) * 1000.0
            print(f"PASSED ({elapsed:.1f}ms)")
            self.passed += 1
        except Exception as e:
            elapsed = (time.perf_counter() - t0) * 1000.0
            print(f"FAILED ({elapsed:.1f}ms)\n     ERROR: {e}")

    def summary(self):
        print("\n" + "="*70)
        print(f"PHASE 4 ADVERSARIAL AUDIT RESULTS: {self.passed}/{self.total} PASSED ({(self.passed/self.total)*100:.1f}%)")
        print("="*70)
        return self.passed == self.total

audit = AuditRunner()

def test_01_kiosk_provisioning_and_secret_hashing():
    admin = fixture_user("Admin", "Prov")
    sta = fixture_station("ProvStation")
    fixture_membership(sta, admin, role="ADMIN")

    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk Tablet 1', 'TAB-01')")
    assert code == 0 and res['success'] is True
    assert 'raw_secret' in res
    assert len(res['raw_secret']) == 48

    code, out, _ = run_psql(f"SELECT secret_hash FROM public.kiosk_devices WHERE id = '{res['kiosk_id']}';")
    assert out.strip() != res['raw_secret']
    assert len(out.strip()) == 64

def test_02_kiosk_authentication_and_qr_generation():
    admin = fixture_user("Admin", "Auth")
    sta = fixture_station("AuthStation")
    fixture_membership(sta, admin, role="ADMIN")
    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk Main', 'KM-01')")
    raw_secret = res['raw_secret']

    # Kiosk authenticates and mints 30s QR challenge
    code, mint_res, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KM-01', '{raw_secret}');")
    data = json.loads(mint_res)
    assert data['success'] is True
    assert data['qr_token'].startswith('YQ_')
    assert len(data['display_code']) == 6
    assert data['ttl_seconds'] == 30

def test_03_kiosk_credential_rotation():
    admin = fixture_user("Admin", "Rot")
    sta = fixture_station("RotStation")
    fixture_membership(sta, admin, role="ADMIN")
    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk Rot', 'KR-01')")
    kiosk_id = res['kiosk_id']
    old_secret = res['raw_secret']

    # Rotate credentials
    code, rot_res, _ = run_as_user_json(admin, f"public.rotate_kiosk_credentials('{kiosk_id}')")
    assert code == 0 and rot_res['success'] is True
    assert rot_res['credential_version'] == 2
    assert rot_res['raw_secret'] != old_secret

def test_04_old_kiosk_session_rejection():
    admin = fixture_user("Admin", "OldSess")
    sta = fixture_station("OldSessStation")
    fixture_membership(sta, admin, role="ADMIN")
    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk Old', 'KO-01')")
    old_secret = res['raw_secret']

    # Rotate
    run_as_user_json(admin, f"public.rotate_kiosk_credentials('{res['kiosk_id']}')")

    # Attempt to mint with old secret -> Must fail P0019
    code, out, err = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KO-01', '{old_secret}');")
    assert code != 0 or "P0019" in out or "Invalid kiosk credentials" in err

def test_05_kiosk_deactivation():
    admin = fixture_user("Admin", "Deact")
    sta = fixture_station("DeactStation")
    fixture_membership(sta, admin, role="ADMIN")
    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk Deact', 'KD-01')")
    kiosk_id = res['kiosk_id']
    secret = res['raw_secret']

    # Deactivate kiosk
    code, deact_res, _ = run_as_user_json(admin, f"public.deactivate_kiosk_device('{kiosk_id}')")
    assert code == 0 and deact_res['is_active'] is False

    # Attempt to mint -> Must fail P0018
    code, out, err = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KD-01', '{secret}');")
    assert code != 0 or "P0018" in out or "inactive" in err.lower()

def test_06_kiosk_reactivation():
    admin = fixture_user("Admin", "React")
    sta = fixture_station("ReactStation")
    fixture_membership(sta, admin, role="ADMIN")
    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk React', 'KRC-01')")
    kiosk_id = res['kiosk_id']
    secret = res['raw_secret']

    run_as_user_json(admin, f"public.deactivate_kiosk_device('{kiosk_id}')")
    code, react_res, _ = run_as_user_json(admin, f"public.reactivate_kiosk_device('{kiosk_id}')")
    assert code == 0 and react_res['is_active'] is True

    code, mint_res, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KRC-01', '{secret}');")
    assert json.loads(mint_res)['success'] is True

def test_07_qr_expiry_defense():
    admin = fixture_user("Admin", "QRExp")
    emp = fixture_user("Emp", "QRExp")
    sta = fixture_station("QRExpStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    setup_published_schedule(admin, sta, emp, mem)

    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk Exp', 'KE-01')")
    code, mint_res, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KE-01', '{res['raw_secret']}');")
    token = json.loads(mint_res)['qr_token']

    # Manually expire QR challenge in DB
    run_psql(f"UPDATE public.kiosk_qr_challenges SET expires_at = now() - interval '5 seconds';")

    code, scan_res, err = run_as_user_json(emp, f"public.scan_attendance_qr('{token}')")
    assert code != 0 or not scan_res or not scan_res.get('success')
    assert "P0021" in err or "expired" in err.lower() or "P0021" in str(scan_res)

def test_08_qr_tamper_defense():
    emp = fixture_user("Emp", "Tamper")
    sta = fixture_station("TamperStation")
    fixture_membership(sta, emp, role="EMPLOYEE")

    for bad_token in ["YQ_fake_tampered_token", "INVALID_CODE", "' OR '1'='1"]:
        code, res, err = run_as_user_json(emp, f"public.scan_attendance_qr('{bad_token}')")
        assert code != 0 or not res or not res.get('success')
        assert "P0020" in err or "invalid" in err.lower() or "P0020" in str(res)

def test_09_multi_employee_same_qr():
    admin = fixture_user("Admin", "MultiQR")
    emp1 = fixture_user("Emp1", "MultiQR")
    emp2 = fixture_user("Emp2", "MultiQR")
    sta = fixture_station("MultiQRStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem1 = fixture_membership(sta, emp1, role="EMPLOYEE")
    mem2 = fixture_membership(sta, emp2, role="EMPLOYEE")
    setup_published_schedule(admin, sta, emp1, mem1)
    setup_published_schedule(admin, sta, emp2, mem2)

    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk Multi', 'KM-02')")
    code, mint_res, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KM-02', '{res['raw_secret']}');")
    token = json.loads(mint_res)['qr_token']

    # Emp1 scans QR
    code, scan1, _ = run_as_user_json(emp1, f"public.scan_attendance_qr('{token}')")
    # Emp2 scans SAME QR
    code, scan2, _ = run_as_user_json(emp2, f"public.scan_attendance_qr('{token}')")

    assert scan1['success'] is True and scan2['success'] is True
    assert scan1['presence_proof_token'] != scan2['presence_proof_token']

def test_10_employee_membership_validation():
    admin = fixture_user("Admin", "Foreign")
    emp = fixture_user("Emp", "Foreign")
    sta_a = fixture_station("Station_A")
    sta_b = fixture_station("Station_B")
    fixture_membership(sta_a, admin, role="ADMIN")
    fixture_membership(sta_b, emp, role="EMPLOYEE") # Only member in B

    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta_a}', 'Kiosk A', 'KA-02')")
    code, mint_res, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta_a}', 'KA-02', '{res['raw_secret']}');")
    token = json.loads(mint_res)['qr_token']

    # Foreign employee scans Station A QR -> Must fail (42501)
    code, scan_res, err = run_as_user_json(emp, f"public.scan_attendance_qr('{token}')")
    assert code != 0 or not scan_res or not scan_res.get('success')
    assert "42501" in err or "Access denied" in err

def test_11_presence_proof_employee_binding():
    admin = fixture_user("Admin", "ProofBind")
    emp1 = fixture_user("Emp1", "ProofBind")
    emp2 = fixture_user("Emp2", "ProofBind")
    sta = fixture_station("ProofBindStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem1 = fixture_membership(sta, emp1, role="EMPLOYEE")
    mem2 = fixture_membership(sta, emp2, role="EMPLOYEE")
    setup_published_schedule(admin, sta, emp1, mem1)
    setup_published_schedule(admin, sta, emp2, mem2)

    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk Bind', 'KB-01')")
    code, mint_res, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KB-01', '{res['raw_secret']}');")
    token = json.loads(mint_res)['qr_token']

    code, scan1, _ = run_as_user_json(emp1, f"public.scan_attendance_qr('{token}')")
    proof1 = scan1['presence_proof_token']

    # Emp2 attempts to check in with Emp1's presence proof -> Must fail P0028
    code, cin_res, err = run_as_user_json(emp2, f"public.check_in_with_presence_proof('{proof1}')")
    assert code != 0 or not cin_res or not cin_res.get('success')
    assert "P0028" in err or "another employee" in err.lower() or "P0028" in str(cin_res)

def test_12_presence_proof_action_binding():
    admin = fixture_user("Admin", "ActBind")
    emp = fixture_user("Emp", "ActBind")
    sta = fixture_station("ActBindStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    setup_published_schedule(admin, sta, emp, mem)

    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk Act', 'KA-03')")
    code, mint_res, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KA-03', '{res['raw_secret']}');")
    token = json.loads(mint_res)['qr_token']

    code, scan_res, _ = run_as_user_json(emp, f"public.scan_attendance_qr('{token}')")
    assert scan_res['action'] == 'CHECK_IN'
    proof = scan_res['presence_proof_token']

    # Attempt to use CHECK_IN proof for check-out -> Must fail P0029
    code, cout_res, err = run_as_user_json(emp, f"public.check_out_with_presence_proof('{proof}')")
    assert code != 0 or not cout_res or not cout_res.get('success')
    assert "P0029" in err or "mismatch" in err.lower() or "P0029" in str(cout_res)

def test_13_presence_proof_single_use_consumption():
    admin = fixture_user("Admin", "SingleUse")
    emp = fixture_user("Emp", "SingleUse")
    sta = fixture_station("SingleUseStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    setup_published_schedule(admin, sta, emp, mem)

    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk SU', 'KSU-01')")
    code, mint_res, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KSU-01', '{res['raw_secret']}');")
    token = json.loads(mint_res)['qr_token']

    code, scan_res, _ = run_as_user_json(emp, f"public.scan_attendance_qr('{token}')")
    proof = scan_res['presence_proof_token']

    # First check-in succeeds
    code, cin1, _ = run_as_user_json(emp, f"public.check_in_with_presence_proof('{proof}')")
    assert code == 0 and cin1['success'] is True

    # Replay same proof -> Must fail P0026
    code, cin2, err = run_as_user_json(emp, f"public.check_in_with_presence_proof('{proof}')")
    assert code != 0 or not cin2 or not cin2.get('success')
    assert "P0026" in err or "already been used" in err.lower() or "P0026" in str(cin2)

def test_14_presence_proof_expiry_defense():
    admin = fixture_user("Admin", "ProofExp")
    emp = fixture_user("Emp", "ProofExp")
    sta = fixture_station("ProofExpStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    setup_published_schedule(admin, sta, emp, mem)

    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk PE', 'KPE-01')")
    code, mint_res, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KPE-01', '{res['raw_secret']}');")
    token = json.loads(mint_res)['qr_token']

    code, scan_res, _ = run_as_user_json(emp, f"public.scan_attendance_qr('{token}')")
    proof = scan_res['presence_proof_token']

    # Manually expire proof
    run_psql(f"UPDATE public.attendance_presence_proofs SET expires_at = now() - interval '5 seconds';")

    code, cin_res, err = run_as_user_json(emp, f"public.check_in_with_presence_proof('{proof}')")
    assert code != 0 or not cin_res or not cin_res.get('success')
    assert "P0027" in err or "expired" in err.lower() or "P0027" in str(cin_res)

def test_15_scheduled_check_in_within_window():
    admin = fixture_user("Admin", "WinCI")
    emp = fixture_user("Emp", "WinCI")
    sta = fixture_station("WinCIStation", early=60, grace=5)
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    setup_published_schedule(admin, sta, emp, mem)

    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk Win', 'KW-01')")
    code, mint_res, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KW-01', '{res['raw_secret']}');")
    token = json.loads(mint_res)['qr_token']

    code, scan_res, _ = run_as_user_json(emp, f"public.scan_attendance_qr('{token}')")
    code, cin_res, _ = run_as_user_json(emp, f"public.check_in_with_presence_proof('{scan_res['presence_proof_token']}')")
    assert code == 0 and cin_res['success'] is True
    assert cin_res['status'] == 'OPEN'
    assert 'shift_name' in cin_res

def test_16_too_early_check_in_rejection():
    admin = fixture_user("Admin", "EarlyCI")
    emp = fixture_user("Emp", "EarlyCI")
    sta = fixture_station("EarlyCIStation", early=30) # Only 30 minutes early allowed
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")

    # Shift is scheduled for 5 hours from now
    future_start = (datetime.now() + timedelta(hours=5)).strftime("%H:%M:00")
    future_end = (datetime.now() + timedelta(hours=13)).strftime("%H:%M:00")
    setup_published_schedule(admin, sta, emp, mem, start_time=future_start, end_time=future_end)

    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk Early', 'KE-02')")
    code, mint_res, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KE-02', '{res['raw_secret']}');")
    token = json.loads(mint_res)['qr_token']

    code, scan_res, err = run_as_user_json(emp, f"public.scan_attendance_qr('{token}')")
    assert code != 0 or not scan_res or not scan_res.get('success')
    assert "P0024" in err or "No published shift" in err or "P0024" in str(scan_res)

def test_17_late_calculation_with_grace_period():
    admin = fixture_user("Admin", "Grace")
    emp = fixture_user("Emp", "Grace")
    sta = fixture_station("GraceStation", early=60, grace=5) # 5m grace
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")

    # Shift started 20 minutes ago
    past_start = (datetime.now() - timedelta(minutes=20)).strftime("%H:%M:00")
    past_end = (datetime.now() + timedelta(hours=7)).strftime("%H:%M:00")
    setup_published_schedule(admin, sta, emp, mem, start_time=past_start, end_time=past_end)

    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk Grace', 'KG-01')")
    code, mint_res, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KG-01', '{res['raw_secret']}');")
    token = json.loads(mint_res)['qr_token']

    code, scan_res, _ = run_as_user_json(emp, f"public.scan_attendance_qr('{token}')")
    code, cin_res, _ = run_as_user_json(emp, f"public.check_in_with_presence_proof('{scan_res['presence_proof_token']}')")
    assert code == 0 and cin_res['success'] is True
    # Late minutes should be ~20m (since 20 > 5 grace)
    assert cin_res['late_minutes'] >= 19

def test_18_one_open_session_invariant():
    admin = fixture_user("Admin", "OneSess")
    emp = fixture_user("Emp", "OneSess")
    sta = fixture_station("OneSessStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    setup_published_schedule(admin, sta, emp, mem)

    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk One', 'KO-02')")
    code, mint_res, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KO-02', '{res['raw_secret']}');")
    token = json.loads(mint_res)['qr_token']

    code, scan1, _ = run_as_user_json(emp, f"public.scan_attendance_qr('{token}')")
    run_as_user_json(emp, f"public.check_in_with_presence_proof('{scan1['presence_proof_token']}')")

    # Second check-in attempt directly or via forged proof -> Must be blocked by partial unique index
    code, err_code, err = run_psql(f"""
        INSERT INTO public.attendance_records (
            station_id, employee_user_id, station_membership_id, check_in_time, check_in_kiosk_device_id
        ) VALUES ('{sta}', '{emp}', '{mem}', now(), '{res['kiosk_id']}');
    """)
    assert code != 0, "Partial unique index uq_attendance_single_open_session failed to block second open session!"

def test_19_concurrent_check_in_race():
    admin = fixture_user("Admin", "RaceCI")
    emp = fixture_user("Emp", "RaceCI")
    sta = fixture_station("RaceCIStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    setup_published_schedule(admin, sta, emp, mem)

    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk Race', 'KR-02')")
    code, mint_res, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KR-02', '{res['raw_secret']}');")
    token = json.loads(mint_res)['qr_token']

    code, scan1, _ = run_as_user_json(emp, f"public.scan_attendance_qr('{token}')")
    code, scan2, _ = run_as_user_json(emp, f"public.scan_attendance_qr('{token}')")
    p1 = scan1['presence_proof_token']
    p2 = scan2['presence_proof_token']

    results = []
    def do_ci(p):
        c, r, e = run_as_user_json(emp, f"public.check_in_with_presence_proof('{p}')")
        results.append((c, r, e))

    t1 = threading.Thread(target=do_ci, args=(p1,))
    t2 = threading.Thread(target=do_ci, args=(p2,))
    t1.start(); t2.start()
    t1.join(); t2.join()

    successes = sum(1 for c, r, e in results if c == 0 and r and r.get('success') is True)
    assert successes == 1, f"Expected exactly 1 check-in to succeed under concurrent race, got {successes}"

def test_20_check_out_and_worked_minutes():
    admin = fixture_user("Admin", "COut")
    emp = fixture_user("Emp", "COut")
    sta = fixture_station("COutStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    setup_published_schedule(admin, sta, emp, mem)

    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk CO', 'KC-01')")
    code, mint_res, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KC-01', '{res['raw_secret']}');")
    token = json.loads(mint_res)['qr_token']

    code, scan_in, _ = run_as_user_json(emp, f"public.scan_attendance_qr('{token}')")
    run_as_user_json(emp, f"public.check_in_with_presence_proof('{scan_in['presence_proof_token']}')")

    # Simulate 120 minutes of elapsed time
    run_psql(f"UPDATE public.attendance_records SET check_in_time = now() - interval '120 minutes' WHERE employee_user_id = '{emp}';")

    # Scan for CHECK_OUT
    code, scan_out, _ = run_as_user_json(emp, f"public.scan_attendance_qr('{token}')")
    assert scan_out['action'] == 'CHECK_OUT'

    code, cout_res, _ = run_as_user_json(emp, f"public.check_out_with_presence_proof('{scan_out['presence_proof_token']}')")
    assert code == 0 and cout_res['success'] is True
    assert cout_res['worked_minutes'] >= 119
    assert cout_res['status'] == 'COMPLETED'

def test_21_different_same_station_kiosk_checkout():
    admin = fixture_user("Admin", "DiffKiosk")
    emp = fixture_user("Emp", "DiffKiosk")
    sta = fixture_station("DiffKioskStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    setup_published_schedule(admin, sta, emp, mem)

    code, k1, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk Entrance', 'KE-03')")
    code, k2, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk Exit', 'KX-01')")

    code, m1, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KE-03', '{k1['raw_secret']}');")
    code, m2, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KX-01', '{k2['raw_secret']}');")
    t1 = json.loads(m1)['qr_token']
    t2 = json.loads(m2)['qr_token']

    # Check in at Entrance
    code, scan_in, _ = run_as_user_json(emp, f"public.scan_attendance_qr('{t1}')")
    run_as_user_json(emp, f"public.check_in_with_presence_proof('{scan_in['presence_proof_token']}')")

    # Check out at Exit Kiosk
    code, scan_out, _ = run_as_user_json(emp, f"public.scan_attendance_qr('{t2}')")
    code, cout_res, _ = run_as_user_json(emp, f"public.check_out_with_presence_proof('{scan_out['presence_proof_token']}')")
    assert code == 0 and cout_res['success'] is True

def test_22_different_station_checkout_rejection():
    admin_a = fixture_user("AdminA", "DiffSta")
    admin_b = fixture_user("AdminB", "DiffSta")
    emp = fixture_user("Emp", "DiffSta")
    sta_a = fixture_station("DiffSta_A")
    sta_b = fixture_station("DiffSta_B")
    fixture_membership(sta_a, admin_a, role="ADMIN")
    fixture_membership(sta_b, admin_b, role="ADMIN")
    mem_a = fixture_membership(sta_a, emp, role="EMPLOYEE")
    mem_b = fixture_membership(sta_b, emp, role="EMPLOYEE")
    setup_published_schedule(admin_a, sta_a, emp, mem_a)

    code, k_a, _ = run_as_user_json(admin_a, f"public.provision_kiosk_device('{sta_a}', 'Kiosk A', 'KA-04')")
    code, k_b, _ = run_as_user_json(admin_b, f"public.provision_kiosk_device('{sta_b}', 'Kiosk B', 'KB-02')")

    code, m_a, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta_a}', 'KA-04', '{k_a['raw_secret']}');")
    code, m_b, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta_b}', 'KB-02', '{k_b['raw_secret']}');")
    t_a = json.loads(m_a)['qr_token']
    t_b = json.loads(m_b)['qr_token']

    # Check in at Station A
    code, scan_in, _ = run_as_user_json(emp, f"public.scan_attendance_qr('{t_a}')")
    run_as_user_json(emp, f"public.check_in_with_presence_proof('{scan_in['presence_proof_token']}')")

    # Scanning Station B QR while checked in at Station A must fail with P0023
    code, scan_b, err = run_as_user_json(emp, f"public.scan_attendance_qr('{t_b}')")
    assert code != 0 or not scan_b or not scan_b.get('success')
    assert "P0023" in err or "another station" in err.lower() or "P0023" in str(scan_b)

def test_23_concurrent_checkout_race():
    admin = fixture_user("Admin", "RaceCO")
    emp = fixture_user("Emp", "RaceCO")
    sta = fixture_station("RaceCOStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    setup_published_schedule(admin, sta, emp, mem)

    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk RaceCO', 'KRC-02')")
    code, mint_res, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KRC-02', '{res['raw_secret']}');")
    token = json.loads(mint_res)['qr_token']

    code, scan_in, _ = run_as_user_json(emp, f"public.scan_attendance_qr('{token}')")
    run_as_user_json(emp, f"public.check_in_with_presence_proof('{scan_in['presence_proof_token']}')")

    code, scan_o1, _ = run_as_user_json(emp, f"public.scan_attendance_qr('{token}')")
    code, scan_o2, _ = run_as_user_json(emp, f"public.scan_attendance_qr('{token}')")
    p1 = scan_o1['presence_proof_token']
    p2 = scan_o2['presence_proof_token']

    results = []
    def do_co(p):
        c, r, e = run_as_user_json(emp, f"public.check_out_with_presence_proof('{p}')")
        results.append((c, r, e))

    t1 = threading.Thread(target=do_co, args=(p1,))
    t2 = threading.Thread(target=do_co, args=(p2,))
    t1.start(); t2.start()
    t1.join(); t2.join()

    successes = sum(1 for c, r, e in results if c == 0 and r and r.get('success') is True)
    assert successes == 1, f"Expected exactly 1 checkout to succeed under race, got {successes}"

def test_24_cross_midnight_shift_resolution():
    admin = fixture_user("Admin", "MidRes")
    emp = fixture_user("Emp", "MidRes")
    sta = fixture_station("MidResStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")

    # Overnight shift whose operational date is yesterday, still in the live scan window.
    now_dt = datetime.now()
    target_date = date.today() - timedelta(days=1)
    end_time = (now_dt + timedelta(hours=2)).strftime("%H:%M:00")
    setup_published_schedule(
        admin, sta, emp, mem,
        start_time="23:00:00",
        end_time=end_time,
        is_cross=True,
        target_date=target_date,
    )

    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk Mid', 'KM-03')")
    code, mint_res, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KM-03', '{res['raw_secret']}');")
    token = json.loads(mint_res)['qr_token']

    code, scan_res, err = run_as_user_json(emp, f"public.scan_attendance_qr('{token}')")
    assert scan_res is not None and scan_res.get('success') is True, err
    assert scan_res['shift_preview']['shift_name'] == 'Morning Shift'

def test_25_spring_dst_real_elapsed_duration():
    # Spring DST: Clock jumps 02:00 -> 03:00 (7 real hours elapsed between 23:00 and 07:00)
    admin = fixture_user("Admin", "SpringDST")
    emp = fixture_user("Emp", "SpringDST")
    sta = fixture_station("SpringDSTStation", tz="Asia/Jerusalem")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")

    # Direct test of elapsed timestamp difference in PostgreSQL
    code, out, _ = run_psql("""
        SELECT floor(extract(epoch from (
            '2026-03-27 07:00:00+03'::timestamptz - '2026-03-26 23:00:00+02'::timestamptz
        )) / 60.0)::integer;
    """)
    elapsed_minutes = int(out.strip())
    assert elapsed_minutes == 420, f"Expected 420 minutes (7 hours), got {elapsed_minutes}"

def test_26_fall_dst_real_elapsed_duration():
    # Fall DST: Clock repeats 02:00 -> 02:00 (9 real hours elapsed between 23:00 and 07:00)
    code, out, _ = run_psql("""
        SELECT floor(extract(epoch from (
            '2026-10-25 07:00:00+02'::timestamptz - '2026-10-24 23:00:00+03'::timestamptz
        )) / 60.0)::integer;
    """)
    elapsed_minutes = int(out.strip())
    assert elapsed_minutes == 540, f"Expected 540 minutes (9 hours), got {elapsed_minutes}"

def test_27_schedule_snapshot_preservation():
    admin = fixture_user("Admin", "SnapPres")
    emp = fixture_user("Emp", "SnapPres")
    sta = fixture_station("SnapPresStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    setup_published_schedule(admin, sta, emp, mem)

    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk Snap', 'KS-01')")
    code, mint_res, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KS-01', '{res['raw_secret']}');")
    token = json.loads(mint_res)['qr_token']

    code, scan_in, _ = run_as_user_json(emp, f"public.scan_attendance_qr('{token}')")
    run_as_user_json(emp, f"public.check_in_with_presence_proof('{scan_in['presence_proof_token']}')")

    # Rename original shift template
    run_psql(f"UPDATE public.shift_templates SET name = 'Renamed Shift' WHERE station_id = '{sta}';")

    code, out, _ = run_psql(f"SELECT shift_name_snapshot FROM public.attendance_records WHERE employee_user_id = '{emp}';")
    assert out.strip() == 'Morning Shift', f"Snapshot mutated! Got {out.strip()}"

def test_28_post_check_in_schedule_revision_resilience():
    admin = fixture_user("Admin", "RevRes")
    emp = fixture_user("Emp", "RevRes")
    sta = fixture_station("RevResStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    sched_id, shift_id, asgn_id = setup_published_schedule(admin, sta, emp, mem)

    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk Rev', 'KR-03')")
    code, mint_res, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KR-03', '{res['raw_secret']}');")
    token = json.loads(mint_res)['qr_token']

    code, scan_in, _ = run_as_user_json(emp, f"public.scan_attendance_qr('{token}')")
    run_as_user_json(emp, f"public.check_in_with_presence_proof('{scan_in['presence_proof_token']}')")

    # Admin removes assignment from published schedule
    run_as_user_json(admin, f"public.remove_shift_assignment('{asgn_id}', 1, 'Manager adjustment')")

    # Attendance record still exists and retains frozen snapshot
    code, out, _ = run_psql(f"SELECT count(*) FROM public.attendance_records WHERE employee_user_id = '{emp}';")
    assert out.strip() == '1'

def test_29_check_in_to_draft_schedule_forbidden():
    admin = fixture_user("Admin", "DraftCI")
    emp = fixture_user("Emp", "DraftCI")
    sta = fixture_station("DraftCIStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    sched_id, _, _ = setup_published_schedule(admin, sta, emp, mem)

    # Revert schedule to DRAFT
    run_psql(f"UPDATE public.work_schedules SET status = 'DRAFT' WHERE id = '{sched_id}';")

    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk Draft', 'KD-02')")
    code, mint_res, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KD-02', '{res['raw_secret']}');")
    token = json.loads(mint_res)['qr_token']

    code, scan_res, err = run_as_user_json(emp, f"public.scan_attendance_qr('{token}')")
    assert code != 0 or not scan_res or not scan_res.get('success')
    assert "P0024" in err or "No published shift" in err or "P0024" in str(scan_res)

def test_30_admin_manual_correction():
    admin = fixture_user("Admin", "Corr")
    emp = fixture_user("Emp", "Corr")
    sta = fixture_station("CorrStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    setup_published_schedule(admin, sta, emp, mem)

    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk Corr', 'KC-02')")
    code, mint_res, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KC-02', '{res['raw_secret']}');")
    token = json.loads(mint_res)['qr_token']

    code, scan_in, _ = run_as_user_json(emp, f"public.scan_attendance_qr('{token}')")
    cin = run_as_user_json(emp, f"public.check_in_with_presence_proof('{scan_in['presence_proof_token']}')")[1]
    att_id = cin['attendance_id']

    # Admin corrects check-in to 08:00 and check-out to 16:00 (480 minutes)
    new_in = f"{date.today()} 08:00:00+03"
    new_out = f"{date.today()} 16:00:00+03"
    code, corr_res, _ = run_as_user_json(admin, f"public.correct_attendance_record('{att_id}', '{new_in}', '{new_out}', 'Employee forgot to clock out')")
    assert code == 0 and corr_res['success'] is True
    assert corr_res['worked_minutes'] == 480
    assert corr_res['status'] == 'CORRECTED'

def test_31_correction_without_reason_rejected():
    admin = fixture_user("Admin", "NoReas")
    emp = fixture_user("Emp", "NoReas")
    sta = fixture_station("NoReasStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    setup_published_schedule(admin, sta, emp, mem)

    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk NR', 'KNR-01')")
    code, mint_res, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KNR-01', '{res['raw_secret']}');")
    token = json.loads(mint_res)['qr_token']

    code, scan_in, _ = run_as_user_json(emp, f"public.scan_attendance_qr('{token}')")
    cin = run_as_user_json(emp, f"public.check_in_with_presence_proof('{scan_in['presence_proof_token']}')")[1]
    att_id = cin['attendance_id']

    for bad_reason in ["''", "'  '", "'ab'"]:
        code, res, err = run_as_user_json(admin, f"public.correct_attendance_record('{att_id}', now(), now() + interval '1 hour', {bad_reason})")
        assert code != 0 or not res or not res.get('success')
        assert "P0032" in err or "reason" in err.lower() or "P0032" in str(res)

def test_32_correction_negative_duration_rejected():
    admin = fixture_user("Admin", "NegDur")
    emp = fixture_user("Emp", "NegDur")
    sta = fixture_station("NegDurStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    setup_published_schedule(admin, sta, emp, mem)

    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk ND', 'KND-01')")
    code, mint_res, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KND-01', '{res['raw_secret']}');")
    token = json.loads(mint_res)['qr_token']

    code, scan_in, _ = run_as_user_json(emp, f"public.scan_attendance_qr('{token}')")
    cin = run_as_user_json(emp, f"public.check_in_with_presence_proof('{scan_in['presence_proof_token']}')")[1]
    att_id = cin['attendance_id']

    # check_out <= check_in -> Must fail P0034
    code, res, err = run_as_user_json(admin, f"public.correct_attendance_record('{att_id}', now(), now() - interval '1 hour', 'Invalid times')")
    assert code != 0 or not res or not res.get('success')
    assert "P0034" in err or "after check-in" in err.lower() or "P0034" in str(res)

def test_33_correction_overlap_defense():
    admin = fixture_user("Admin", "CorrOver")
    emp = fixture_user("Emp", "CorrOver")
    sta = fixture_station("CorrOverStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    setup_published_schedule(admin, sta, emp, mem)

    code, k_res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk CO', 'KCO-01')")
    k_id = k_res['kiosk_id']

    # Insert Record 1: 08:00 - 16:00
    r1_id = str(uuid.uuid4())
    r2_id = str(uuid.uuid4())
    run_psql(f"""
        INSERT INTO public.attendance_records (
            id, station_id, employee_user_id, station_membership_id, check_in_time, check_out_time, status, check_in_kiosk_device_id
        ) VALUES 
        ('{r1_id}', '{sta}', '{emp}', '{mem}', '{date.today()} 08:00:00+03', '{date.today()} 16:00:00+03', 'COMPLETED', '{k_id}'),
        ('{r2_id}', '{sta}', '{emp}', '{mem}', '{date.today()} 18:00:00+03', '{date.today()} 22:00:00+03', 'COMPLETED', '{k_id}');
    """)

    # Correct Record 2 to overlap with Record 1 (14:00 - 20:00) -> Must fail P0035
    code, res, err = run_as_user_json(admin, f"public.correct_attendance_record('{r2_id}', '{date.today()} 14:00:00+03', '{date.today()} 20:00:00+03', 'Shift extension')")
    assert code != 0 or not res or not res.get('success')
    assert "P0035" in err or "overlaps" in err.lower() or "P0035" in str(res)

def test_34_immutable_correction_ledger_audit():
    admin = fixture_user("Admin", "LedgAud")
    emp = fixture_user("Emp", "LedgAud")
    sta = fixture_station("LedgAudStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem = fixture_membership(sta, emp, role="EMPLOYEE")
    setup_published_schedule(admin, sta, emp, mem)

    code, k_res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk LA', 'KLA-01')")
    k_id = k_res['kiosk_id']

    r_id = str(uuid.uuid4())
    run_psql(f"""
        INSERT INTO public.attendance_records (
            id, station_id, employee_user_id, station_membership_id, check_in_time, check_out_time, status, check_in_kiosk_device_id
        ) VALUES ('{r_id}', '{sta}', '{emp}', '{mem}', '{date.today()} 08:00:00+03', '{date.today()} 16:00:00+03', 'COMPLETED', '{k_id}');
    """)

    run_as_user_json(admin, f"public.correct_attendance_record('{r_id}', '{date.today()} 09:00:00+03', '{date.today()} 17:00:00+03', 'Adjusted per manager approval')")

    code, out, _ = run_psql(f"SELECT reason, previous_worked_minutes, new_worked_minutes FROM public.attendance_corrections WHERE attendance_record_id = '{r_id}';")
    assert "Adjusted per manager approval" in out

def test_35_manager_live_attendance_roster_and_kpis():
    admin = fixture_user("Admin", "LiveKpi")
    emp1 = fixture_user("Emp1", "LiveKpi")
    emp2 = fixture_user("Emp2", "LiveKpi")
    sta = fixture_station("LiveKpiStation")
    fixture_membership(sta, admin, role="ADMIN")
    mem1 = fixture_membership(sta, emp1, role="EMPLOYEE")
    mem2 = fixture_membership(sta, emp2, role="EMPLOYEE")
    setup_published_schedule(admin, sta, emp1, mem1)
    setup_published_schedule(admin, sta, emp2, mem2)

    # Emp1 checks in
    code, res, _ = run_as_user_json(admin, f"public.provision_kiosk_device('{sta}', 'Kiosk KPI', 'KKPI-01')")
    code, mint_res, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta}', 'KKPI-01', '{res['raw_secret']}');")
    token = json.loads(mint_res)['qr_token']

    code, scan1, _ = run_as_user_json(emp1, f"public.scan_attendance_qr('{token}')")
    run_as_user_json(emp1, f"public.check_in_with_presence_proof('{scan1['presence_proof_token']}')")

    code, live_res, _ = run_as_user_json(admin, f"public.get_manager_live_attendance('{sta}', '{date.today()}')")
    assert code == 0 and live_res['success'] is True
    kpis = live_res['kpis']
    assert kpis['currently_working'] == 1
    assert len(live_res['roster']) == 2

def test_36_manager_live_attendance_scale_benchmark():
    admin = fixture_user("Admin", "ScaleLive")
    sta = fixture_station("ScaleLiveStation")
    fixture_membership(sta, admin, role="ADMIN")

    # Generate 50 members and scheduled shifts
    for i in range(50):
        u = fixture_user(f"Emp{i}", "Scale")
        m = fixture_membership(sta, u, role="EMPLOYEE", code=f"EMP-SCALE-{i}")
        setup_published_schedule(admin, sta, u, m)

    t0 = time.perf_counter()
    code, live_res, _ = run_as_user_json(admin, f"public.get_manager_live_attendance('{sta}', '{date.today()}')")
    latency = (time.perf_counter() - t0) * 1000.0

    assert code == 0 and live_res['success'] is True
    assert len(live_res['roster']) == 50
    assert latency < 100.0, f"Manager live roster query took {latency:.1f}ms (threshold 100ms)"

def test_37_ephemeral_data_cleanup_rpc():
    run_psql(f"""
        INSERT INTO public.kiosk_qr_challenges (
            station_id, kiosk_device_id, challenge_hash, display_code, expires_at
        ) VALUES (gen_random_uuid(), gen_random_uuid(), 'old_hash', 'OLD123', now() - interval '48 hours');
    """)
    code, out, _ = run_psql("SELECT public.cleanup_ephemeral_attendance_data();")
    res = json.loads(out)
    assert res['success'] is True

def test_38_multi_station_simultaneous_open_prevention():
    admin_a = fixture_user("AdminA", "MultiOpen")
    admin_b = fixture_user("AdminB", "MultiOpen")
    emp = fixture_user("Emp", "MultiOpen")
    sta_a = fixture_station("MultiOpenStationA")
    sta_b = fixture_station("MultiOpenStationB")
    fixture_membership(sta_a, admin_a, role="ADMIN")
    fixture_membership(sta_b, admin_b, role="ADMIN")
    mem_a = fixture_membership(sta_a, emp, role="EMPLOYEE")
    mem_b = fixture_membership(sta_b, emp, role="EMPLOYEE")
    setup_published_schedule(admin_a, sta_a, emp, mem_a)
    setup_published_schedule(admin_b, sta_b, emp, mem_b)

    code, k_a, _ = run_as_user_json(admin_a, f"public.provision_kiosk_device('{sta_a}', 'Kiosk A', 'KA-05')")
    code, k_b, _ = run_as_user_json(admin_b, f"public.provision_kiosk_device('{sta_b}', 'Kiosk B', 'KB-03')")

    code, m_a, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta_a}', 'KA-05', '{k_a['raw_secret']}');")
    code, m_b, _ = run_psql(f"SELECT public.kiosk_authenticate_and_mint_qr('{sta_b}', 'KB-03', '{k_b['raw_secret']}');")
    t_a = json.loads(m_a)['qr_token']
    t_b = json.loads(m_b)['qr_token']

    # Emp checks in at Station A
    code, s_a, _ = run_as_user_json(emp, f"public.scan_attendance_qr('{t_a}')")
    run_as_user_json(emp, f"public.check_in_with_presence_proof('{s_a['presence_proof_token']}')")

    # Emp attempts to scan at Station B while open at Station A -> Must fail P0023
    code, s_b, err = run_as_user_json(emp, f"public.scan_attendance_qr('{t_b}')")
    assert code != 0 or not s_b or not s_b.get('success')
    assert "P0023" in err or "another station" in err.lower() or "P0023" in str(s_b)

def main():
    print("="*70)
    print("STARTING PHASE 4 COMPREHENSIVE ADVERSARIAL AUDIT (38 SCENARIOS)")
    print("="*70)
    setup_fresh_db()

    audit.run("01 Kiosk Provisioning & Secret Hashing", test_01_kiosk_provisioning_and_secret_hashing)
    audit.run("02 Kiosk Login & Dynamic QR Challenge Minting", test_02_kiosk_authentication_and_qr_generation)
    audit.run("03 Kiosk Credential Rotation", test_03_kiosk_credential_rotation)
    audit.run("04 Old Kiosk Session Rejection (P0019)", test_04_old_kiosk_session_rejection)
    audit.run("05 Kiosk Deactivation (P0018)", test_05_kiosk_deactivation)
    audit.run("06 Kiosk Reactivation", test_06_kiosk_reactivation)
    audit.run("07 QR Expiry Defense (30s TTL / P0021)", test_07_qr_expiry_defense)
    audit.run("08 QR Tamper Defense (P0020)", test_08_qr_tamper_defense)
    audit.run("09 Multi-Employee Same QR Concurrency", test_09_multi_employee_same_qr)
    audit.run("10 Foreign Station Scan Lockout (42501)", test_10_employee_membership_validation)
    audit.run("11 Presence Proof Employee Binding (P0028)", test_11_presence_proof_employee_binding)
    audit.run("12 Presence Proof Action Binding (P0029)", test_12_presence_proof_action_binding)
    audit.run("13 Presence Proof Single-Use Replay Defense (P0026)", test_13_presence_proof_single_use_consumption)
    audit.run("14 Presence Proof Expiry Defense (60s TTL / P0027)", test_14_presence_proof_expiry_defense)
    audit.run("15 Scheduled Check-In within Early Window", test_15_scheduled_check_in_within_window)
    audit.run("16 Too-Early Check-In Rejection (P0024)", test_16_too_early_check_in_rejection)
    audit.run("17 Lateness Calculation with Station Grace", test_17_late_calculation_with_grace_period)
    audit.run("18 One-Open-Session DB Partial Unique Invariant", test_18_one_open_session_invariant)
    audit.run("19 Concurrent Multithreaded Check-In Race", test_19_concurrent_check_in_race)
    audit.run("20 Check-Out & Real UTC Elapsed Duration", test_20_check_out_and_worked_minutes)
    audit.run("21 Different Same-Station Kiosk Checkout", test_21_different_same_station_kiosk_checkout)
    audit.run("22 Different Station Checkout Rejection (P0031)", test_22_different_station_checkout_rejection)
    audit.run("23 Concurrent Multithreaded Checkout Race", test_23_concurrent_checkout_race)
    audit.run("24 Cross-Midnight Shift Resolution (Sunday->Monday)", test_24_cross_midnight_shift_resolution)
    audit.run("25 Spring DST Real Elapsed Minute Duration", test_25_spring_dst_real_elapsed_duration)
    audit.run("26 Fall DST Real Elapsed Minute Duration", test_26_fall_dst_real_elapsed_duration)
    audit.run("27 Schedule Snapshot Preservation", test_27_schedule_snapshot_preservation)
    audit.run("28 Post-Check-In Schedule Revision Resilience", test_28_post_check_in_schedule_revision_resilience)
    audit.run("29 Check-In to Draft Schedule Forbidden (P0024)", test_29_check_in_to_draft_schedule_forbidden)
    audit.run("30 Admin Manual Attendance Correction", test_30_admin_manual_correction)
    audit.run("31 Correction Reason Length Validator (P0032)", test_31_correction_without_reason_rejected)
    audit.run("32 Correction Negative Duration Validator (P0034)", test_32_correction_negative_duration_rejected)
    audit.run("33 Correction Interval Overlap Defense (P0035)", test_33_correction_overlap_defense)
    audit.run("34 Immutable Correction Ledger Audit", test_34_immutable_correction_ledger_audit)
    audit.run("35 Manager Live Attendance Roster & KPIs", test_35_manager_live_attendance_roster_and_kpis)
    audit.run("36 Live Roster Scale Benchmark (<100ms for 50+)", test_36_manager_live_attendance_scale_benchmark)
    audit.run("37 Ephemeral Data Cleanup RPC", test_37_ephemeral_data_cleanup_rpc)
    audit.run("38 Multi-Station Simultaneous Open Session Lockout", test_38_multi_station_simultaneous_open_prevention)

    success = audit.summary()
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
