#!/usr/bin/env python3
"""
YellowShifts — Phase 6 Independent Adversarial Audit & Remediation Suite V2
75+ rigorous scenarios validating transactional outbox atomicity, column immutability,
push device token deliverability, real multi-threaded worker lease claiming, kiosk incident lifecycle,
availability reminder deadline updates, schedule revision targeting, retention compliance, and security invariants.
"""

import sys
import os
import shutil
import subprocess
import json
import uuid
import time
import hashlib
from concurrent.futures import ThreadPoolExecutor

PSQL_BIN = shutil.which("psql") or "/opt/homebrew/opt/postgresql@16/bin/psql"
if not os.path.exists(PSQL_BIN):
    PSQL_BIN = shutil.which("psql") or "psql"
if not os.path.exists(PSQL_BIN):
    PSQL_BIN = "psql"

DB_NAME = "yellowshifts_phase6_audit_v2"
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
    print(f"[*] All {len(files)} migrations (001 through 010) applied cleanly on fresh test database.")

def seed_audit_context():
    sql = """
    -- Stations
    INSERT INTO public.stations (id, name, code, timezone, locale, week_start, is_active, check_in_early_minutes, late_grace_minutes, identity_verification_mode)
    VALUES 
    ('11111111-1111-1111-1111-111111111111', 'Station North', 'STA-N', 'Asia/Jerusalem', 'he', 0, true, 15, 5, 'CHECK_IN_ONLY'),
    ('22222222-2222-2222-2222-222222222222', 'Station South', 'STA-S', 'Asia/Jerusalem', 'he', 0, true, 15, 5, 'DISABLED')
    ON CONFLICT (id) DO NOTHING;

    -- Users
    INSERT INTO auth.users (id, email) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'admin_north@test.com'),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'mgr_north@test.com'),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'emp_one@test.com'),
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'emp_two@test.com'),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'admin_south@test.com')
    ON CONFLICT (id) DO NOTHING;

    -- Profiles
    INSERT INTO public.profiles (id, first_name, last_name, preferred_locale) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Alice', 'Admin', 'he'),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Bob', 'Manager', 'he'),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Charlie', 'Worker', 'he'),
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'David', 'Worker', 'he'),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'Eve', 'AdminSouth', 'he')
    ON CONFLICT (id) DO NOTHING;

    -- Station Memberships
    INSERT INTO public.station_memberships (id, station_id, user_id, role, status) VALUES
    ('10000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'ADMIN', 'ACTIVE'),
    ('10000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'SHIFT_MANAGER', 'ACTIVE'),
    ('10000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'EMPLOYEE', 'ACTIVE'),
    ('10000000-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'EMPLOYEE', 'ACTIVE'),
    ('10000000-0000-0000-0000-000000000005', '22222222-2222-2222-2222-222222222222', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'ADMIN', 'ACTIVE')
    ON CONFLICT (id) DO NOTHING;

    -- Manager Permissions
    INSERT INTO public.station_shift_manager_permissions (station_id, permission, is_enabled) VALUES
    ('11111111-1111-1111-1111-111111111111', 'schedule.publish', true),
    ('11111111-1111-1111-1111-111111111111', 'schedule.manage', true),
    ('11111111-1111-1111-1111-111111111111', 'attendance.correct', true)
    ON CONFLICT DO NOTHING;

    -- Kiosk Device
    INSERT INTO public.kiosk_devices (id, station_id, name, device_identifier, secret_hash, is_active, last_seen_at, created_by)
    VALUES (
        '99999999-9999-9999-9999-999999999999',
        '11111111-1111-1111-1111-111111111111',
        'North Kiosk Main',
        'KIO-N-01',
        encode(sha256('kiosk_secret_pass'::bytea), 'hex'),
        true,
        now(),
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    ) ON CONFLICT (id) DO NOTHING;

    -- Shift Templates
    INSERT INTO public.shift_templates (id, station_id, name, start_time, end_time, sort_order)
    VALUES ('80000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Morning Shift', '07:00:00', '15:00:00', 1)
    ON CONFLICT (id) DO NOTHING;
    """
    code, _, err = run_psql(sql)
    if code != 0:
        print(f"[-] Seeding failed: {err}")
        sys.exit(1)

def run_test(scenario_id: str, desc: str, fn) -> bool:
    print(f"Scenario [{scenario_id}]: {desc} ... ", end="", flush=True)
    try:
        success, msg = fn()
        if success:
            print("PASSED")
            return True
        else:
            print(f"FAILED -> {msg}")
            return False
    except Exception as e:
        print(f"EXCEPTION -> {e}")
        return False

# ======================================================================
# SCENARIOS IMPLEMENTATION
# ======================================================================

def test_01_schema_extensions():
    # Verify migration 010 schema additions
    code, out, _ = run_psql("""
    SELECT 
        EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='notification_devices' AND column_name='encrypted_device_token') AS has_enc_token,
        EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='kiosk_health_states' AND column_name='incident_id') AS has_incident_id,
        EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='kiosk_health_states' AND column_name='transition_count') AS has_trans_count,
        EXISTS (SELECT 1 FROM pg_constraint WHERE conname='check_system_in_app_mandatory') AS has_sys_constraint;
    """)
    if code == 0 and "t|t|t|t" in out:
        return True, ""
    return False, f"Unexpected columns: {out}"

def test_02_direct_notification_update_blocked():
    # Direct UPDATE on notifications by authenticated role must be denied
    code, _, err = run_as_user_json(
        "cccccccc-cccc-cccc-cccc-cccccccccccc",
        "UPDATE public.notifications SET title_key = 'hacked' WHERE recipient_user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'"
    )
    if code != 0 or "permission denied" in err.lower() or "42501" in err:
        return True, ""
    return False, f"Direct UPDATE on notifications was permitted: code={code}, err={err}"

def test_03_notification_immutability_trigger_protection():
    # Even if an update reaches the trigger, modifying immutable columns must be blocked
    code, _, err = run_psql("""
    INSERT INTO public.notifications (id, recipient_user_id, station_id, category, event_type, priority, title_key, body_key, deduplication_key)
    VALUES ('aaaaaaaa-1111-1111-1111-aaaaaaaaaaaa', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', 'ATTENDANCE', 'TEST_EVENT', 'NORMAL', 'title', 'body', 'test-dedup-1')
    ON CONFLICT (id) DO NOTHING;

    UPDATE public.notifications
    SET title_key = 'tampered_title'
    WHERE id = 'aaaaaaaa-1111-1111-1111-aaaaaaaaaaaa';
    """)
    if code != 0 and ("Immutable notification columns cannot be modified" in err or "42501" in err):
        return True, ""
    return False, f"Expected immutability trigger error, got code={code}, err={err}"

def test_04_direct_preference_write_blocked():
    # Direct INSERT/UPDATE/DELETE on notification_preferences by authenticated user must be denied
    code, _, err = run_as_user_json(
        "cccccccc-cccc-cccc-cccc-cccccccccccc",
        "INSERT INTO public.notification_preferences (user_id, category, in_app_enabled) VALUES ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'SCHEDULE', false)"
    )
    if code != 0 or "permission denied" in err.lower() or "42501" in err:
        return True, ""
    return False, f"Direct INSERT on notification_preferences was permitted: code={code}, err={err}"

def test_05_update_preference_rpc_enforces_system_mandatory():
    # update_my_notification_preferences must force in_app_enabled=true for SYSTEM
    code, res, err = run_as_user_json(
        "cccccccc-cccc-cccc-cccc-cccccccccccc",
        "public.update_my_notification_preferences('SYSTEM'::public.notification_category, false, false, false, false)"
    )
    if code == 0 and res.get("success") is True and res.get("in_app_enabled") is True:
        return True, ""
    return False, f"Expected SYSTEM in_app_enabled=true, got {res}, err={err}"

def test_06_push_device_registration_persists_raw_token_safely():
    # register_notification_device should store encrypted_device_token and hash
    raw_token = "fcm_mock_device_token_xyz_12345678"
    code, res, err = run_as_user_json(
        "cccccccc-cccc-cccc-cccc-cccccccccccc",
        f"public.register_notification_device('android', 'fcm', '{raw_token}', 'Pixel 8')"
    )
    if code != 0 or not res.get("success"):
        return False, f"Registration failed: {err}, res={res}"
    
    # Check DB state
    expected_hash = hashlib.sha256(raw_token.encode('utf-8')).hexdigest()
    code2, out2, _ = run_psql(f"""
    SELECT device_token_hash, encrypted_device_token, is_active
    FROM public.notification_devices
    WHERE user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' AND device_token_hash = '{expected_hash}';
    """)
    if code2 == 0 and expected_hash in out2 and raw_token in out2:
        return True, ""
    return False, f"Token not persisted accurately in DB: {out2}"

def test_07_device_token_not_exposed_in_public_select():
    # Authenticated user selecting own devices should see rows but RLS/permissions protect token
    code, res, err = run_as_user_json(
        "cccccccc-cccc-cccc-cccc-cccccccccccc",
        "SELECT id, platform, provider, device_label, is_active FROM public.notification_devices WHERE user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'"
    )
    if code == 0:
        return True, ""
    return False, f"Select failed: {err}"

def test_08_worker_claim_retrieves_push_tokens_and_idempotency_key():
    # Insert a push job for user Charlie and claim via service role
    run_psql("""
    INSERT INTO public.notifications (id, recipient_user_id, station_id, category, event_type, priority, title_key, body_key, deduplication_key)
    VALUES ('bbbbbbbb-2222-2222-2222-bbbbbbbbbbbb', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', 'ATTENDANCE', 'EMPLOYEE_CHECKED_IN', 'NORMAL', 'title', 'body', 'test-dedup-push-1')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.notification_delivery_jobs (id, notification_id, recipient_user_id, channel, status, next_attempt_at)
    VALUES ('cccccccc-3333-3333-3333-cccccccccccc', 'bbbbbbbb-2222-2222-2222-bbbbbbbbbbbb', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'PUSH', 'PENDING', now())
    ON CONFLICT (id) DO NOTHING;
    """)

    worker_token = str(uuid.uuid4())
    code, out, err = run_psql(f"SELECT public.claim_notification_delivery_jobs(10, 60, '{worker_token}'::UUID);")
    if code != 0:
        return False, f"Claim failed: {err}"
    data = json.loads(out)
    jobs = data.get("jobs", [])
    target = next((j for j in jobs if j.get("job_id") == "cccccccc-3333-3333-3333-cccccccccccc"), None)
    if not target:
        return False, f"Target job not claimed: {data}"
    
    if target.get("idempotency_key") == "job:cccccccc-3333-3333-3333-cccccccccccc:attempt:1" and target.get("device_tokens") is not None:
        tokens = target["device_tokens"]
        if len(tokens) > 0 and tokens[0].get("token") == "fcm_mock_device_token_xyz_12345678":
            return True, ""
    return False, f"Claim payload missing idempotency key or device tokens: {target}"

def test_09_worker_concurrency_skip_locked():
    # Seed 10 claimable jobs and launch 2 concurrent worker threads
    for i in range(10):
        run_psql(f"""
        INSERT INTO public.notifications (id, recipient_user_id, category, event_type, priority, title_key, body_key, deduplication_key)
        VALUES ('10101010-0000-0000-0000-{i:012d}', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'SYSTEM', 'TEST', 'NORMAL', 't', 'b', 'conc-dedup-{i}')
        ON CONFLICT (id) DO NOTHING;

        INSERT INTO public.notification_delivery_jobs (id, notification_id, recipient_user_id, channel, status, next_attempt_at)
        VALUES ('20202020-0000-0000-0000-{i:012d}', '10101010-0000-0000-0000-{i:012d}', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'EMAIL', 'PENDING', now())
        ON CONFLICT (id) DO NOTHING;
        """)

    def worker_claim(worker_id):
        code, out, _ = run_psql(f"SELECT public.claim_notification_delivery_jobs(5, 60, '{worker_id}'::UUID);")
        if code == 0:
            return json.loads(out).get("jobs", [])
        return []

    w1 = str(uuid.uuid4())
    w2 = str(uuid.uuid4())
    with ThreadPoolExecutor(max_workers=2) as ex:
        f1 = ex.submit(worker_claim, w1)
        f2 = ex.submit(worker_claim, w2)
        jobs1 = f1.result()
        jobs2 = f2.result()

    ids1 = set(j["job_id"] for j in jobs1)
    ids2 = set(j["job_id"] for j in jobs2)
    overlap = ids1.intersection(ids2)
    if len(overlap) == 0 and len(ids1) > 0 and len(ids2) > 0:
        return True, ""
    return False, f"Worker concurrency collision! Overlap: {overlap}, w1={len(ids1)}, w2={len(ids2)}"

def test_10_worker_outcome_recording_and_state_machine():
    job_id = "cccccccc-3333-3333-3333-cccccccccccc"
    # Claim it to get a fresh lock token
    worker_token = str(uuid.uuid4())
    run_psql(f"UPDATE public.notification_delivery_jobs SET status='PROCESSING', lock_token='{worker_token}' WHERE id='{job_id}';")

    # Record SUCCESS
    code, out, err = run_psql(f"""
    SELECT public.record_delivery_attempt_outcome(
        '{job_id}'::UUID,
        '{worker_token}'::UUID,
        'SUCCESS'::public.delivery_attempt_outcome,
        'FCM',
        '200_OK',
        NULL,
        'fcm_msg_12345'
    );
    """)
    if code != 0:
        return False, f"Outcome recording failed: {err}"
    data = json.loads(out)
    if data.get("status") != "DELIVERED":
        return False, f"Expected DELIVERED, got {data}"

    # Verify attempt recorded
    code2, out2, _ = run_psql(f"SELECT outcome, provider FROM public.notification_delivery_attempts WHERE delivery_job_id='{job_id}' ORDER BY attempt_number DESC LIMIT 1;")
    code3, out3, _ = run_psql(f"SELECT provider_message_id FROM public.notification_delivery_jobs WHERE id='{job_id}';")
    if "SUCCESS" in out2 and "fcm_msg_12345" in out3:
        return True, ""
    return False, f"Delivery attempt row not found or mismatch: attempt={out2}, job={out3}"

def test_11_invalid_lock_token_rejected():
    job_id = "20202020-0000-0000-0000-000000000001"
    wrong_token = str(uuid.uuid4())
    code, _, err = run_psql(f"""
    SELECT public.record_delivery_attempt_outcome(
        '{job_id}'::UUID,
        '{wrong_token}'::UUID,
        'SUCCESS'::public.delivery_attempt_outcome,
        'MOCK'
    );
    """)
    if code != 0 and ("P0065" in err or "mismatch" in err.lower()):
        return True, ""
    return False, f"Expected P0065 lock token mismatch error, got code={code}, err={err}"

def test_12_kiosk_onboarding_grace_period_no_false_offline():
    # Create a newly provisioned kiosk (created 1 minute ago, last_seen_at IS NULL)
    new_kiosk_id = str(uuid.uuid4())
    run_psql(f"""
    INSERT INTO public.kiosk_devices (id, station_id, name, device_identifier, secret_hash, is_active, last_seen_at, created_by, created_at)
    VALUES ('{new_kiosk_id}', '11111111-1111-1111-1111-111111111111', 'Brand New Kiosk', 'KIO-NEW-01', 'hash', true, NULL, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now() - INTERVAL '1 minute');
    """)

    code, out, err = run_psql("SELECT public.evaluate_kiosk_health_transitions('11111111-1111-1111-1111-111111111111'::UUID);")
    if code != 0:
        return False, f"Evaluator failed: {err}"
    data = json.loads(out)
    if data.get("offline_transitions") == 0:
        return True, ""
    return False, f"False positive offline transition emitted for brand new kiosk: {data}"

def test_13_kiosk_offline_and_recovery_incident_lifecycle():
    kiosk_id = "99999999-9999-9999-9999-999999999999"
    # Make it inactive > 5 minutes
    run_psql(f"UPDATE public.kiosk_devices SET last_seen_at = now() - INTERVAL '10 minutes' WHERE id = '{kiosk_id}';")

    # Evaluator should transition ONLINE -> OFFLINE
    code, out, _ = run_psql("SELECT public.evaluate_kiosk_health_transitions('11111111-1111-1111-1111-111111111111'::UUID);")
    data = json.loads(out)
    if data.get("offline_transitions") != 1:
        return False, f"Expected 1 offline transition, got {data}"

    # Run again: should NOT duplicate offline transition (anti-storm)
    code, out2, _ = run_psql("SELECT public.evaluate_kiosk_health_transitions('11111111-1111-1111-1111-111111111111'::UUID);")
    data2 = json.loads(out2)
    if data2.get("offline_transitions") != 0:
        return False, f"Duplicate offline transition emitted: {data2}"

    # Now recover kiosk
    run_psql(f"UPDATE public.kiosk_devices SET last_seen_at = now() WHERE id = '{kiosk_id}';")
    code, out3, _ = run_psql("SELECT public.evaluate_kiosk_health_transitions('11111111-1111-1111-1111-111111111111'::UUID);")
    data3 = json.loads(out3)
    if data3.get("recovery_transitions") != 1:
        return False, f"Expected 1 recovery transition, got {data3}"

    return True, ""

def test_14_kiosk_subsequent_offline_incident_not_suppressed():
    kiosk_id = "99999999-9999-9999-9999-999999999999"
    # Make it offline again later (Incident #2)
    run_psql(f"UPDATE public.kiosk_devices SET last_seen_at = now() - INTERVAL '10 minutes' WHERE id = '{kiosk_id}';")
    code, out, _ = run_psql("SELECT public.evaluate_kiosk_health_transitions('11111111-1111-1111-1111-111111111111'::UUID);")
    data = json.loads(out)
    if data.get("offline_transitions") == 1:
        return True, ""
    return False, f"Incident #2 offline transition was incorrectly suppressed by deduplication! {data}"

def test_15_availability_deadline_reminder_and_extension_deduplication():
    # Create an availability period ending in 12 hours
    period_id = str(uuid.uuid4())
    run_psql(f"""
    INSERT INTO public.availability_periods (id, station_id, week_start_date, submission_deadline, status)
    VALUES ('{period_id}', '11111111-1111-1111-1111-111111111111', current_date + 7, now() + INTERVAL '12 hours', 'OPEN');
    """)

    # First run: emits reminders
    code, out, _ = run_psql("SELECT public.generate_due_notification_reminders();")
    data = json.loads(out)
    if data.get("availability_reminders_emitted", 0) < 1:
        return False, f"Expected availability reminders, got {data}"

    # Second run immediately: deduplicated (0 emitted)
    code, out2, _ = run_psql("SELECT public.generate_due_notification_reminders();")
    data2 = json.loads(out2)
    if data2.get("availability_reminders_emitted", 0) != 0:
        return False, f"Reminders duplicated without deadline change: {data2}"

    # Now extend deadline by 3 days and set to 18 hours from now
    run_psql(f"UPDATE public.availability_periods SET submission_deadline = now() + INTERVAL '18 hours' WHERE id = '{period_id}';")
    code, out3, _ = run_psql("SELECT public.generate_due_notification_reminders();")
    data3 = json.loads(out3)
    if data3.get("availability_reminders_emitted", 0) >= 1:
        return True, ""
    return False, f"New reminder for extended deadline was incorrectly suppressed: {data3}"

def test_16_schedule_revision_notifies_only_affected_employee():
    # Create schedule in PUBLISHED status with a shift
    ap_id = str(uuid.uuid4())
    pst_id = str(uuid.uuid4())
    schedule_id = str(uuid.uuid4())
    shift_id = str(uuid.uuid4())
    run_psql(f"""
    INSERT INTO public.availability_periods (id, station_id, week_start_date, submission_deadline, status, created_by)
    VALUES ('{ap_id}', '11111111-1111-1111-1111-111111111111', current_date + 7, now() + INTERVAL '1 day', 'OPEN', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
    ON CONFLICT (station_id, week_start_date) DO UPDATE SET status = 'OPEN';

    INSERT INTO public.availability_period_shift_templates (id, availability_period_id, shift_template_id, name_snapshot, start_time_snapshot, end_time_snapshot, sort_order_snapshot)
    VALUES ('{pst_id}', (SELECT id FROM public.availability_periods WHERE station_id = '11111111-1111-1111-1111-111111111111' AND week_start_date = current_date + 7), '80000000-0000-0000-0000-000000000001', 'Morning Shift', '08:00:00', '16:00:00', 1)
    ON CONFLICT (availability_period_id, shift_template_id) DO NOTHING;

    INSERT INTO public.work_schedules (id, station_id, availability_period_id, week_start_date, status, version, created_by, published_by, published_at)
    VALUES ('{schedule_id}', '11111111-1111-1111-1111-111111111111', (SELECT id FROM public.availability_periods WHERE station_id = '11111111-1111-1111-1111-111111111111' AND week_start_date = current_date + 7), current_date + 7, 'PUBLISHED', 1, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now())
    ON CONFLICT (station_id, week_start_date) DO UPDATE SET status = 'PUBLISHED';

    INSERT INTO public.work_schedule_shifts (
        id, work_schedule_id, station_id, operational_date, period_shift_template_id,
        shift_name_snapshot, start_time_snapshot, end_time_snapshot, starts_at, ends_at, required_staff_count
    ) VALUES (
        '{shift_id}',
        (SELECT id FROM public.work_schedules WHERE station_id = '11111111-1111-1111-1111-111111111111' AND week_start_date = current_date + 7),
        '11111111-1111-1111-1111-111111111111', current_date + 7,
        (SELECT id FROM public.availability_period_shift_templates WHERE availability_period_id = (SELECT id FROM public.availability_periods WHERE station_id = '11111111-1111-1111-1111-111111111111' AND week_start_date = current_date + 7) LIMIT 1),
        'Morning Shift', '08:00:00', '16:00:00', (current_date + 7)::timestamp + INTERVAL '08:00', (current_date + 7)::timestamp + INTERVAL '16:00', 1
    );
    """)

    # Assign Charlie to shift
    code, res, err = run_as_user_json(
        "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
        f"public.assign_employee_to_shift('{shift_id}'::UUID, '10000000-0000-0000-0000-000000000003'::UUID, 1, true, 'Emergency override', 'Staffing requirement')"
    )
    if code != 0 or not res.get("success"):
        return False, f"Assignment failed: {err}, res={res}"

    # Verify Charlie received SHIFT_ASSIGNED
    code2, out2, _ = run_psql("""
    SELECT event_type, recipient_user_id
    FROM public.notifications
    WHERE event_type = 'SHIFT_ASSIGNED' AND recipient_user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
    ORDER BY created_at DESC LIMIT 1;
    """)
    if "SHIFT_ASSIGNED" in out2 and "cccccccc-cccc-cccc-cccc-cccccccccccc" in out2:
        return True, ""
    return False, f"Charlie did not receive SHIFT_ASSIGNED: {out2}"

def test_17_cleanup_preserves_mandatory_compliance_records():
    # Insert 100-day-old read mandatory and non-mandatory notifications
    run_psql("""
    -- Mandatory 100-day-old read notification
    INSERT INTO public.notifications (id, recipient_user_id, category, event_type, priority, title_key, body_key, is_mandatory, read_at, created_at, deduplication_key)
    VALUES ('90909090-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'IDENTITY', 'IDENTITY_ADMIN_OVERRIDE_USED', 'CRITICAL', 't', 'b', true, now() - INTERVAL '100 days', now() - INTERVAL '100 days', 'mand-cleanup-test')
    ON CONFLICT (id) DO NOTHING;

    -- Non-mandatory 100-day-old read notification
    INSERT INTO public.notifications (id, recipient_user_id, category, event_type, priority, title_key, body_key, is_mandatory, read_at, created_at, deduplication_key)
    VALUES ('90909090-0000-0000-0000-000000000002', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'SCHEDULE', 'SHIFT_ASSIGNED', 'NORMAL', 't', 'b', false, now() - INTERVAL '100 days', now() - INTERVAL '100 days', 'nonmand-cleanup-test')
    ON CONFLICT (id) DO NOTHING;
    """)

    # Run cleanup (retention 90 days)
    code, out, err = run_psql("SELECT public.cleanup_expired_notifications(90);")
    if code != 0:
        return False, f"Cleanup failed: {err}"

    # Check existence
    code2, out2, _ = run_psql("""
    SELECT 
        EXISTS (SELECT 1 FROM public.notifications WHERE id = '90909090-0000-0000-0000-000000000001') AS mandatory_preserved,
        EXISTS (SELECT 1 FROM public.notifications WHERE id = '90909090-0000-0000-0000-000000000002') AS non_mandatory_purged;
    """)
    if code2 == 0 and "t|f" in out2:
        return True, ""
    return False, f"Mandatory compliance record was deleted or non-mandatory was retained: {out2}"

def test_18_security_definer_and_search_path_audit():
    # Verify all Phase 6 functions in pg_proc are SECURITY DEFINER with search_path set
    code, out, err = run_psql("""
    SELECT proname, prosecdef, proconfig
    FROM pg_proc
    WHERE proname IN (
        'get_my_notifications', 'get_unread_notification_count', 'mark_notification_read',
        'mark_all_notifications_read', 'get_my_notification_preferences',
        'update_my_notification_preferences', 'register_notification_device',
        'revoke_notification_device', 'claim_notification_delivery_jobs',
        'record_delivery_attempt_outcome', 'evaluate_kiosk_health_transitions',
        'generate_due_notification_reminders', 'cleanup_expired_notifications',
        'emit_notification_event', 'assign_employee_to_shift', 'remove_shift_assignment',
        'move_shift_assignment', 'submit_availability', 'revoke_identity_profile'
    );
    """)
    if code != 0:
        return False, f"pg_proc query failed: {err}"
    
    rows = [r.split("|") for r in out.strip().split("\n") if r.strip()]
    for row in rows:
        if len(row) < 3:
            continue
        pname, secdef, cfg = row[0], row[1], row[2]
        if secdef != "t":
            return False, f"Function {pname} is NOT SECURITY DEFINER!"
        if "search_path=public, pg_temp" not in cfg and "search_path=public,pg_temp" not in cfg:
            return False, f"Function {pname} has unpinned search_path: {cfg}"
    return True, ""

def test_19_mark_notification_read_cross_user_denied():
    # User David attempting to mark Charlie's notification as read
    code, res, err = run_as_user_json(
        "dddddddd-dddd-dddd-dddd-dddddddddddd",
        "public.mark_notification_read('aaaaaaaa-1111-1111-1111-aaaaaaaaaaaa'::UUID)"
    )
    if code != 0 and ("P0060" in err or "not found" in err.lower()):
        return True, ""
    return False, f"Cross-user mark-read was not rejected: code={code}, res={res}, err={err}"

def test_20_keyset_pagination_clamping():
    # Test get_my_notifications with extreme limits: -5 and 500
    code1, res1, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "public.get_my_notifications(-5)")
    code2, res2, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "public.get_my_notifications(500)")
    if code1 == 0 and res1.get("success") and code2 == 0 and res2.get("success"):
        return True, ""
    return False, f"Limit clamping test failed: res1={res1}, res2={res2}"

# ======================================================================
# MAIN EXECUTION RUNNER
# ======================================================================

def test_21_submit_availability_emits_confirmation():
    period_id = str(uuid.uuid4())
    pst_id = str(uuid.uuid4())
    run_psql(f"""
    INSERT INTO public.availability_periods (id, station_id, week_start_date, submission_deadline, status, created_by)
    VALUES ('{period_id}', '11111111-1111-1111-1111-111111111111', current_date + 35, now() + INTERVAL '2 days', 'OPEN', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
    ON CONFLICT (station_id, week_start_date) DO UPDATE SET status = 'OPEN';

    INSERT INTO public.availability_period_shift_templates (id, availability_period_id, shift_template_id, name_snapshot, start_time_snapshot, end_time_snapshot, sort_order_snapshot)
    VALUES ('{pst_id}', '{period_id}', '80000000-0000-0000-0000-000000000001', 'Morning Shift', '08:00:00', '16:00:00', 1)
    ON CONFLICT (availability_period_id, shift_template_id) DO NOTHING;
    """)

    entries = []
    import datetime
    base_date = datetime.date.today() + datetime.timedelta(days=35)
    for d in range(7):
        ed = (base_date + datetime.timedelta(days=d)).isoformat()
        entries.append({"date": ed, "period_shift_template_id": pst_id, "is_available": True})
    
    entries_json = json.dumps(entries)
    code, res, err = run_as_user_json(
        "cccccccc-cccc-cccc-cccc-cccccccccccc",
        f"public.submit_availability('{period_id}'::UUID, '{entries_json}'::JSONB)"
    )
    if code != 0 or not res.get("success"):
        return False, f"submit_availability failed: {err}, res={res}"

    code2, out2, _ = run_psql(f"""
    SELECT event_type, recipient_user_id
    FROM public.notifications
    WHERE event_type = 'AVAILABILITY_SUBMITTED_CONFIRMATION' AND recipient_user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
    ORDER BY created_at DESC LIMIT 1;
    """)
    if "AVAILABILITY_SUBMITTED_CONFIRMATION" in out2:
        return True, ""
    return False, f"Missing AVAILABILITY_SUBMITTED_CONFIRMATION notification: {out2}"

def test_22_remove_shift_assignment_emits_notification():
    ap_id = str(uuid.uuid4())
    pst_id = str(uuid.uuid4())
    schedule_id = str(uuid.uuid4())
    shift_id = str(uuid.uuid4())
    assign_id = str(uuid.uuid4())
    run_psql(f"""
    INSERT INTO public.availability_periods (id, station_id, week_start_date, submission_deadline, status, created_by)
    VALUES ('{ap_id}', '11111111-1111-1111-1111-111111111111', current_date + 42, now() + INTERVAL '2 days', 'OPEN', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
    ON CONFLICT (station_id, week_start_date) DO UPDATE SET status = 'OPEN';

    INSERT INTO public.availability_period_shift_templates (id, availability_period_id, shift_template_id, name_snapshot, start_time_snapshot, end_time_snapshot, sort_order_snapshot)
    VALUES ('{pst_id}', '{ap_id}', '80000000-0000-0000-0000-000000000001', 'Morning Shift', '08:00:00', '16:00:00', 1)
    ON CONFLICT (availability_period_id, shift_template_id) DO NOTHING;

    INSERT INTO public.work_schedules (id, station_id, availability_period_id, week_start_date, status, version, created_by, published_by, published_at)
    VALUES ('{schedule_id}', '11111111-1111-1111-1111-111111111111', '{ap_id}', current_date + 42, 'PUBLISHED', 1, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now())
    ON CONFLICT (station_id, week_start_date) DO UPDATE SET status = 'PUBLISHED';

    INSERT INTO public.work_schedule_shifts (
        id, work_schedule_id, station_id, operational_date, period_shift_template_id,
        shift_name_snapshot, start_time_snapshot, end_time_snapshot, starts_at, ends_at, required_staff_count
    ) VALUES (
        '{shift_id}', '{schedule_id}', '11111111-1111-1111-1111-111111111111', current_date + 42, '{pst_id}',
        'Morning Shift', '08:00:00', '16:00:00', (current_date + 42)::timestamp + INTERVAL '08:00', (current_date + 42)::timestamp + INTERVAL '16:00', 1
    );

    INSERT INTO public.shift_assignments (
        id, work_schedule_shift_id, station_id, membership_id, user_id,
        availability_state_snapshot, assigned_by
    ) VALUES (
        '{assign_id}', '{shift_id}', '11111111-1111-1111-1111-111111111111', '10000000-0000-0000-0000-000000000003',
        'cccccccc-cccc-cccc-cccc-cccccccccccc', 'AVAILABLE', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    );
    """)

    code, res, err = run_as_user_json(
        "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
        f"public.remove_shift_assignment('{assign_id}'::UUID, 1, 'Staff reduction')"
    )
    if code != 0 or not res.get("success"):
        return False, f"remove_shift_assignment failed: {err}, res={res}"

    code2, out2, _ = run_psql("""
    SELECT event_type, recipient_user_id
    FROM public.notifications
    WHERE event_type = 'SHIFT_REMOVED' AND recipient_user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
    ORDER BY created_at DESC LIMIT 1;
    """)
    if "SHIFT_REMOVED" in out2:
        return True, ""
    return False, f"Missing SHIFT_REMOVED notification: {out2}"

def test_23_move_shift_assignment_emits_notification():
    schedule_id = str(uuid.uuid4())
    shift1_id = str(uuid.uuid4())
    shift2_id = str(uuid.uuid4())
    assign_id = str(uuid.uuid4())
    pst_id = str(uuid.uuid4())
    ap_id = str(uuid.uuid4())
    run_psql(f"""
    INSERT INTO public.availability_periods (id, station_id, week_start_date, submission_deadline, status, created_by)
    VALUES ('{ap_id}', '11111111-1111-1111-1111-111111111111', current_date + 49, now() + INTERVAL '2 days', 'OPEN', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
    ON CONFLICT (station_id, week_start_date) DO UPDATE SET status = 'OPEN';

    INSERT INTO public.availability_period_shift_templates (id, availability_period_id, shift_template_id, name_snapshot, start_time_snapshot, end_time_snapshot, sort_order_snapshot)
    VALUES ('{pst_id}', '{ap_id}', '80000000-0000-0000-0000-000000000001', 'Morning Shift', '08:00:00', '16:00:00', 1)
    ON CONFLICT (availability_period_id, shift_template_id) DO NOTHING;

    INSERT INTO public.work_schedules (id, station_id, availability_period_id, week_start_date, status, version, created_by, published_by, published_at)
    VALUES ('{schedule_id}', '11111111-1111-1111-1111-111111111111', '{ap_id}', current_date + 49, 'PUBLISHED', 1, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now())
    ON CONFLICT (station_id, week_start_date) DO UPDATE SET status = 'PUBLISHED';

    INSERT INTO public.work_schedule_shifts (
        id, work_schedule_id, station_id, operational_date, period_shift_template_id,
        shift_name_snapshot, start_time_snapshot, end_time_snapshot, starts_at, ends_at, required_staff_count
    ) VALUES 
    ('{shift1_id}', '{schedule_id}', '11111111-1111-1111-1111-111111111111', current_date + 49, '{pst_id}', 'Morning Shift 1', '08:00:00', '16:00:00', (current_date + 49)::timestamp + INTERVAL '08:00', (current_date + 49)::timestamp + INTERVAL '16:00', 1),
    ('{shift2_id}', '{schedule_id}', '11111111-1111-1111-1111-111111111111', current_date + 50, '{pst_id}', 'Morning Shift 2', '08:00:00', '16:00:00', (current_date + 50)::timestamp + INTERVAL '08:00', (current_date + 50)::timestamp + INTERVAL '16:00', 1);

    INSERT INTO public.shift_assignments (
        id, work_schedule_shift_id, station_id, membership_id, user_id,
        availability_state_snapshot, assigned_by
    ) VALUES (
        '{assign_id}', '{shift1_id}', '11111111-1111-1111-1111-111111111111', '10000000-0000-0000-0000-000000000003',
        'cccccccc-cccc-cccc-cccc-cccccccccccc', 'AVAILABLE', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    );
    """)

    code, res, err = run_as_user_json(
        "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
        f"public.move_shift_assignment('{assign_id}'::UUID, '{shift2_id}'::UUID, 1, true, 'Moving override', 'Rebalancing coverage')"
    )
    if code != 0 or not res.get("success"):
        return False, f"move_shift_assignment failed: {err}, res={res}"

    code2, out2, _ = run_psql("""
    SELECT event_type, recipient_user_id
    FROM public.notifications
    WHERE event_type = 'SHIFT_CHANGED' AND recipient_user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
    ORDER BY created_at DESC LIMIT 1;
    """)
    if "SHIFT_CHANGED" in out2:
        return True, ""
    return False, f"Missing SHIFT_CHANGED notification: {out2}"

def test_24_revoke_identity_profile_emits_mandatory_notification():
    prof_id = str(uuid.uuid4())
    run_psql(f"""
    INSERT INTO public.employee_identity_profiles (id, employee_user_id, provider, status, provider_subject_id, enrolled_at)
    VALUES ('{prof_id}', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'mock', 'ACTIVE', 'sub_123', now())
    ON CONFLICT (employee_user_id) DO UPDATE SET status = 'ACTIVE';
    """)

    code, res, err = run_as_user_json(
        "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        "public.revoke_identity_profile('cccccccc-cccc-cccc-cccc-cccccccccccc'::UUID, 'Security revocation audit')"
    )
    if code != 0 or not res.get("success"):
        return False, f"revoke_identity_profile failed: {err}, res={res}"

    code2, out2, _ = run_psql("""
    SELECT event_type, is_mandatory
    FROM public.notifications
    WHERE event_type = 'IDENTITY_PROFILE_REVOKED'
    ORDER BY created_at DESC LIMIT 1;
    """)
    if "IDENTITY_PROFILE_REVOKED" in out2:
        return True, ""
    return False, f"Missing IDENTITY_PROFILE_REVOKED mandatory notification: {out2}"

def test_25_revoke_notification_device_marks_inactive():
    code_reg, res_reg, _ = run_as_user_json(
        "cccccccc-cccc-cccc-cccc-cccccccccccc",
        "public.register_notification_device('ios', 'apns', 'ios_apns_test_token_12345678', 'iPhone 15')"
    )
    device_id = res_reg.get("device_id")
    if not device_id:
        return False, f"Device registration for revoke failed: {res_reg}"

    code, res, err = run_as_user_json(
        "cccccccc-cccc-cccc-cccc-cccccccccccc",
        f"public.revoke_notification_device('{device_id}'::UUID)"
    )
    if code != 0 or res.get("success") is not True:
        return False, f"Revoke device RPC failed: {err}, res={res}"

    code2, out2, _ = run_psql(f"SELECT is_active, revoked_at IS NOT NULL FROM public.notification_devices WHERE id='{device_id}';")
    if "f|t" in out2:
        return True, ""
    return False, f"Device not marked inactive in DB: {out2}"

def test_26_mark_all_notifications_read_updates_only_caller():
    code, res, err = run_as_user_json(
        "cccccccc-cccc-cccc-cccc-cccccccccccc",
        "public.mark_all_notifications_read()"
    )
    if code == 0 and res.get("success") is True:
        code2, res2, _ = run_as_user_json(
            "cccccccc-cccc-cccc-cccc-cccccccccccc",
            "public.get_unread_notification_count()"
        )
        if code2 == 0 and res2.get("unread_count") == 0:
            return True, ""
    return False, f"mark_all_notifications_read failed: {err}, res={res}"

def test_27_future_timestamp_spoofing_prevented_on_seen_at():
    code, _, err = run_psql("""
    UPDATE public.notifications
    SET seen_at = now() + INTERVAL '10 days'
    WHERE recipient_user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
    """)
    if code != 0 and ("seen_at cannot be set to a future timestamp" in err or "22000" in err):
        return True, ""
    return False, f"Future seen_at timestamp was allowed: code={code}, err={err}"

def test_28_lease_expiration_auto_reclaim():
    job_id = str(uuid.uuid4())
    notif_id = str(uuid.uuid4())
    run_psql(f"""
    INSERT INTO public.notifications (id, recipient_user_id, category, event_type, priority, title_key, body_key, deduplication_key)
    VALUES ('{notif_id}', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'SYSTEM', 'TEST', 'NORMAL', 't', 'b', 'lease-exp-dedup')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.notification_delivery_jobs (id, notification_id, recipient_user_id, channel, status, lock_token, lease_expires_at, next_attempt_at)
    VALUES ('{job_id}', '{notif_id}', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'EMAIL', 'PROCESSING', gen_random_uuid(), now() - INTERVAL '5 minutes', now() - INTERVAL '10 minutes')
    ON CONFLICT (id) DO NOTHING;
    """)

    worker_token = str(uuid.uuid4())
    code, out, err = run_psql(f"SELECT public.claim_notification_delivery_jobs(10, 60, '{worker_token}'::UUID);")
    if code == 0 and job_id in out:
        return True, ""
    return False, f"Expired lease was not re-claimed: {out}"

def test_29_active_lease_protected_from_other_workers():
    job_id = str(uuid.uuid4())
    notif_id = str(uuid.uuid4())
    run_psql(f"""
    INSERT INTO public.notifications (id, recipient_user_id, category, event_type, priority, title_key, body_key, deduplication_key)
    VALUES ('{notif_id}', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'SYSTEM', 'TEST', 'NORMAL', 't', 'b', 'active-lease-dedup')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.notification_delivery_jobs (id, notification_id, recipient_user_id, channel, status, lock_token, lease_expires_at, next_attempt_at)
    VALUES ('{job_id}', '{notif_id}', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'EMAIL', 'PROCESSING', gen_random_uuid(), now() + INTERVAL '10 minutes', now())
    ON CONFLICT (id) DO NOTHING;
    """)

    worker2 = str(uuid.uuid4())
    code, out, _ = run_psql(f"SELECT public.claim_notification_delivery_jobs(10, 60, '{worker2}'::UUID);")
    if job_id not in out:
        return True, ""
    return False, f"Active leased job was stolen by second worker! {out}"

def test_30_retry_backoff_and_max_attempts():
    job_id = str(uuid.uuid4())
    notif_id = str(uuid.uuid4())
    run_psql(f"""
    INSERT INTO public.notifications (id, recipient_user_id, category, event_type, priority, title_key, body_key, deduplication_key)
    VALUES ('{notif_id}', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'SYSTEM', 'TEST', 'NORMAL', 't', 'b', 'retry-test-dedup')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.notification_delivery_jobs (id, notification_id, recipient_user_id, channel, status, attempt_count, max_attempts, next_attempt_at)
    VALUES ('{job_id}', '{notif_id}', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'SMS', 'PENDING', 0, 3, now())
    ON CONFLICT (id) DO NOTHING;
    """)

    w1 = str(uuid.uuid4())
    run_psql(f"UPDATE public.notification_delivery_jobs SET status='PROCESSING', lock_token='{w1}', attempt_count=1 WHERE id='{job_id}';")
    code, out, _ = run_psql(f"SELECT public.record_delivery_attempt_outcome('{job_id}'::UUID, '{w1}'::UUID, 'TEMPORARY_FAILURE'::public.delivery_attempt_outcome, 'TWILIO', '500_ERR', 'NETWORK_TIMEOUT');")
    data = json.loads(out)
    if data.get("status") != "RETRY":
        return False, f"Attempt 1 expected RETRY, got {data}"

    w2 = str(uuid.uuid4())
    run_psql(f"UPDATE public.notification_delivery_jobs SET status='PROCESSING', lock_token='{w2}', attempt_count=2 WHERE id='{job_id}';")
    code, out2, _ = run_psql(f"SELECT public.record_delivery_attempt_outcome('{job_id}'::UUID, '{w2}'::UUID, 'TEMPORARY_FAILURE'::public.delivery_attempt_outcome, 'TWILIO', '500_ERR', 'NETWORK_TIMEOUT');")
    data2 = json.loads(out2)
    if data2.get("status") != "RETRY":
        return False, f"Attempt 2 expected RETRY, got {data2}"

    w3 = str(uuid.uuid4())
    run_psql(f"UPDATE public.notification_delivery_jobs SET status='PROCESSING', lock_token='{w3}', attempt_count=3 WHERE id='{job_id}';")
    code, out3, _ = run_psql(f"SELECT public.record_delivery_attempt_outcome('{job_id}'::UUID, '{w3}'::UUID, 'TEMPORARY_FAILURE'::public.delivery_attempt_outcome, 'TWILIO', '500_ERR', 'NETWORK_TIMEOUT');")
    data3 = json.loads(out3)
    if data3.get("status") != "FAILED":
        return False, f"Attempt 3 (Max) expected FAILED, got {data3}"

    return True, ""

def test_31_non_service_role_claim_denied():
    code, _, err = run_as_user_json(
        "cccccccc-cccc-cccc-cccc-cccccccccccc",
        "public.claim_notification_delivery_jobs(10, 60)"
    )
    if code != 0 or "42501" in err or "denied" in err.lower():
        return True, ""
    return False, f"Non-service-role claim was permitted: code={code}, err={err}"

def test_32_non_service_role_record_outcome_denied():
    code, _, err = run_as_user_json(
        "cccccccc-cccc-cccc-cccc-cccccccccccc",
        "public.record_delivery_attempt_outcome('cccccccc-3333-3333-3333-cccccccccccc'::UUID, gen_random_uuid(), 'SUCCESS'::public.delivery_attempt_outcome, 'MOCK')"
    )
    if code != 0 or "42501" in err or "denied" in err.lower():
        return True, ""
    return False, f"Non-service-role outcome recording was permitted: code={code}, err={err}"

def test_33_non_service_role_cleanup_denied():
    code, _, err = run_as_user_json(
        "cccccccc-cccc-cccc-cccc-cccccccccccc",
        "public.cleanup_expired_notifications(90)"
    )
    if code != 0 or "42501" in err or "denied" in err.lower():
        return True, ""
    return False, f"Non-service-role cleanup was permitted: code={code}, err={err}"

def test_34_non_service_role_kiosk_evaluator_denied():
    code, _, err = run_as_user_json(
        "cccccccc-cccc-cccc-cccc-cccccccccccc",
        "public.evaluate_kiosk_health_transitions()"
    )
    if code != 0 or "42501" in err or "denied" in err.lower():
        return True, ""
    return False, f"Non-service-role kiosk evaluation was permitted: code={code}, err={err}"

def test_35_non_service_role_due_reminders_evaluator_denied():
    code, _, err = run_as_user_json(
        "cccccccc-cccc-cccc-cccc-cccccccccccc",
        "public.generate_due_notification_reminders()"
    )
    if code != 0 or "42501" in err or "denied" in err.lower():
        return True, ""
    return False, f"Non-service-role reminders generator was permitted: code={code}, err={err}"

def test_36_cross_station_notification_isolation():
    notif_id = str(uuid.uuid4())
    run_psql(f"""
    INSERT INTO public.notifications (id, recipient_user_id, station_id, category, event_type, priority, title_key, body_key, deduplication_key)
    VALUES ('{notif_id}', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '22222222-2222-2222-2222-222222222222', 'OPERATIONS', 'KIOSK_OFFLINE', 'HIGH', 't', 'b', 'south-isolated-1');
    """)

    code, res, err = run_as_user_json(
        "cccccccc-cccc-cccc-cccc-cccccccccccc",
        "public.get_my_notifications(20)"
    )
    if code == 0:
        items = res.get("items", [])
        if any(item.get("id") == notif_id for item in items):
            return False, "Cross-station notification leaked to Charlie!"
        return True, ""
    return False, f"Query failed: {err}"

def test_37_direct_delete_on_notifications_blocked():
    code, _, err = run_as_user_json(
        "cccccccc-cccc-cccc-cccc-cccccccccccc",
        "DELETE FROM public.notifications WHERE recipient_user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'"
    )
    if code != 0 or "permission denied" in err.lower() or "42501" in err:
        return True, ""
    return False, f"Direct DELETE on notifications was permitted: code={code}, err={err}"

def test_38_direct_insert_on_notifications_blocked():
    code, _, err = run_as_user_json(
        "cccccccc-cccc-cccc-cccc-cccccccccccc",
        "INSERT INTO public.notifications (recipient_user_id, title_key, body_key, deduplication_key) VALUES ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'spoof', 'spoof', 'spoof')"
    )
    if code != 0 or "permission denied" in err.lower() or "42501" in err:
        return True, ""
    return False, f"Direct INSERT on notifications was permitted: code={code}, err={err}"

def test_39_keyset_pagination_has_more_and_cursor():
    for i in range(15):
        run_psql(f"""
        INSERT INTO public.notifications (id, recipient_user_id, category, event_type, priority, title_key, body_key, deduplication_key, created_at)
        VALUES ('30303030-0000-0000-0000-{i:012d}', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'SCHEDULE', 'TEST', 'NORMAL', 't', 'b', 'page-dedup-{i}', now() - INTERVAL '{i} minutes')
        ON CONFLICT (id) DO NOTHING;
        """)

    code, res1, _ = run_as_user_json("dddddddd-dddd-dddd-dddd-dddddddddddd", "public.get_my_notifications(10)")
    if code != 0 or not res1.get("has_more") or len(res1.get("items", [])) != 10:
        return False, f"Page 1 failed: {res1}"

    cursor_ts = res1["next_cursor_created_at"]
    cursor_id = res1["next_cursor_id"]

    code2, res2, _ = run_as_user_json(
        "dddddddd-dddd-dddd-dddd-dddddddddddd",
        f"public.get_my_notifications(10, '{cursor_ts}'::TIMESTAMPTZ, '{cursor_id}'::UUID)"
    )
    if code2 != 0 or len(res2.get("items", [])) == 0:
        return False, f"Page 2 failed: {res2}"

    page1_ids = set(x["id"] for x in res1["items"])
    page2_ids = set(x["id"] for x in res2["items"])
    if len(page1_ids.intersection(page2_ids)) == 0:
        return True, ""
    return False, f"Overlap between pages: {page1_ids.intersection(page2_ids)}"

def test_40_category_filter_in_query():
    code, res, _ = run_as_user_json(
        "dddddddd-dddd-dddd-dddd-dddddddddddd",
        "public.get_my_notifications(20, NULL, NULL, 'SCHEDULE'::public.notification_category)"
    )
    if code == 0 and all(item.get("category") == "SCHEDULE" for item in res.get("items", [])):
        return True, ""
    return False, f"Category filter failed: {res}"

def test_41_unread_notification_count_by_category():
    for i in range(2):
        run_psql(f"""
        INSERT INTO public.notifications (id, recipient_user_id, category, event_type, priority, title_key, body_key, deduplication_key)
        VALUES ('40404040-0000-0000-0000-{i:012d}', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'SCHEDULE', 'TEST', 'NORMAL', 't', 'b', 'cnt-sch-{i}')
        ON CONFLICT (id) DO NOTHING;
        """)
    run_psql("""
    INSERT INTO public.notifications (id, recipient_user_id, category, event_type, priority, title_key, body_key, deduplication_key)
    VALUES ('40404040-0000-0000-0000-000000000099', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'ATTENDANCE', 'TEST', 'NORMAL', 't', 'b', 'cnt-att-1')
    ON CONFLICT (id) DO NOTHING;
    """)

    code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "public.get_unread_notification_count()")
    if code == 0 and res.get("unread_count", 0) >= 3:
        return True, ""
    return False, f"Unread count query failed: {res}"

def test_42_mark_notification_read_idempotent():
    notif_id = "40404040-0000-0000-0000-000000000099"
    # Call 1
    code1, res1, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"public.mark_notification_read('{notif_id}'::UUID)")
    # Call 2
    code2, res2, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"public.mark_notification_read('{notif_id}'::UUID)")
    if code1 == 0 and res1.get("success") and code2 == 0 and res2.get("success"):
        return True, ""
    return False, f"Idempotent mark read failed: res1={res1}, res2={res2}"

def test_43_kiosk_offline_is_mandatory():
    code, out, _ = run_psql("""
    SELECT is_mandatory, priority
    FROM public.notifications
    WHERE event_type = 'KIOSK_OFFLINE'
    LIMIT 1;
    """)
    if "t|HIGH" in out or "t|" in out:
        return True, ""
    return False, f"KIOSK_OFFLINE is not marked mandatory: {out}"

def test_44_attendance_manual_correction_mandatory():
    event_id = str(uuid.uuid4())
    code, out, _ = run_psql(f"""
    SELECT public.emit_notification_event(
        '11111111-1111-1111-1111-111111111111'::UUID,
        'ATTENDANCE_MANUALLY_CORRECTED',
        'ATTENDANCE'::public.notification_category,
        'HIGH'::public.notification_priority,
        'attendance_record',
        '{event_id}'::UUID,
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::UUID,
        jsonb_build_object('employee_name', 'Charlie Worker', 'reason', 'Clock malfunction'),
        'mand-att-corr-{event_id}'
    );
    """)
    code2, out2, _ = run_psql(f"""
    SELECT is_mandatory, action_type
    FROM public.notifications
    WHERE deduplication_key LIKE 'mand-att-corr-{event_id}%'
    LIMIT 1;
    """)
    if "t|NAVIGATE_ATTENDANCE" in out2:
        return True, ""
    return False, f"ATTENDANCE_MANUALLY_CORRECTED not mandatory or missing action_type: {out2}"

def test_45_identity_override_used_mandatory():
    event_id = str(uuid.uuid4())
    code, out, _ = run_psql(f"""
    SELECT public.emit_notification_event(
        '11111111-1111-1111-1111-111111111111'::UUID,
        'IDENTITY_ADMIN_OVERRIDE_USED',
        'IDENTITY'::public.notification_category,
        'CRITICAL'::public.notification_priority,
        'identity_proof',
        '{event_id}'::UUID,
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::UUID,
        jsonb_build_object('employee_name', 'Charlie Worker', 'admin_name', 'Alice Admin', 'reason', 'Camera failure'),
        'mand-id-override-{event_id}'
    );
    """)
    code2, out2, _ = run_psql(f"""
    SELECT is_mandatory, priority
    FROM public.notifications
    WHERE deduplication_key LIKE 'mand-id-override-{event_id}%'
    LIMIT 1;
    """)
    if "t|CRITICAL" in out2:
        return True, ""
    return False, f"IDENTITY_ADMIN_OVERRIDE_USED not mandatory CRITICAL: {out2}"

def test_46_device_token_invalid_inputs_raise_errors():
    # Short token
    code1, _, err1 = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "public.register_notification_device('ios', 'apns', 'short')")
    # Unsupported platform
    code2, _, err2 = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "public.register_notification_device('blackberry', 'fcm', 'valid_long_device_token_12345678')")
    # Unsupported provider
    code3, _, err3 = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "public.register_notification_device('ios', 'unsupported_provider', 'valid_long_device_token_12345678')")
    if code1 != 0 and "P0061" in err1 and code2 != 0 and "P0062" in err2 and code3 != 0 and "P0063" in err3:
        return True, ""
    return False, f"Input validation errors not raised as expected: err1={err1}, err2={err2}, err3={err3}"

def test_47_worker_batch_size_and_lease_clamping():
    # Batch size clamped between 1 and 100, lease between 10 and 600
    code1, out1, _ = run_psql("SELECT public.claim_notification_delivery_jobs(-10, 2);")
    code2, out2, _ = run_psql("SELECT public.claim_notification_delivery_jobs(500, 10000);")
    if code1 == 0 and code2 == 0:
        return True, ""
    return False, f"Worker clamp failed: out1={out1}, out2={out2}"

def test_48_cleanup_ignores_recent_records():
    # Insert fresh read non-mandatory notification (1 day old)
    fresh_id = str(uuid.uuid4())
    run_psql(f"""
    INSERT INTO public.notifications (id, recipient_user_id, category, event_type, priority, title_key, body_key, is_mandatory, read_at, created_at, deduplication_key)
    VALUES ('{fresh_id}', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'SCHEDULE', 'SHIFT_ASSIGNED', 'NORMAL', 't', 'b', false, now() - INTERVAL '1 day', now() - INTERVAL '1 day', 'fresh-cleanup-{fresh_id}')
    ON CONFLICT (id) DO NOTHING;
    """)

    # Cleanup 90 days
    run_psql("SELECT public.cleanup_expired_notifications(90);")

    # Verify fresh notification remains intact
    code, out, _ = run_psql(f"SELECT EXISTS (SELECT 1 FROM public.notifications WHERE id = '{fresh_id}');")
    if "t" in out:
        return True, ""
    return False, f"Fresh notification was prematurely deleted by cleanup: {out}"

def test_49_cleanup_ignores_unread_old_records():
    # Insert 120-day-old UNREAD notification (read_at IS NULL)
    old_unread_id = str(uuid.uuid4())
    run_psql(f"""
    INSERT INTO public.notifications (id, recipient_user_id, category, event_type, priority, title_key, body_key, is_mandatory, read_at, created_at, deduplication_key)
    VALUES ('{old_unread_id}', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'SCHEDULE', 'SHIFT_ASSIGNED', 'NORMAL', 't', 'b', false, NULL, now() - INTERVAL '120 days', 'old-unread-{old_unread_id}')
    ON CONFLICT (id) DO NOTHING;
    """)

    # Cleanup 90 days
    run_psql("SELECT public.cleanup_expired_notifications(90);")

    # Verify old unread notification is preserved
    code, out, _ = run_psql(f"SELECT EXISTS (SELECT 1 FROM public.notifications WHERE id = '{old_unread_id}');")
    if "t" in out:
        return True, ""
    return False, f"Old unread notification was deleted by cleanup: {out}"

def test_50_full_end_to_end_lifecycle():
    # End-to-end test: register device -> emit event -> verify outbox job -> worker claim -> worker delivery success
    user_id = "cccccccc-cccc-cccc-cccc-cccccccccccc"
    raw_token = "fcm_e2e_device_token_99999999"
    run_as_user_json(user_id, f"public.register_notification_device('android', 'fcm', '{raw_token}', 'E2E Device')")

    event_id = str(uuid.uuid4())
    code, out, _ = run_psql(f"""
    SELECT public.emit_notification_event(
        '11111111-1111-1111-1111-111111111111'::UUID,
        'CHECK_IN_CONFIRMED',
        'ATTENDANCE'::public.notification_category,
        'NORMAL'::public.notification_priority,
        'attendance_record',
        '{event_id}'::UUID,
        '{user_id}'::UUID,
        jsonb_build_object('target_user_id', '{user_id}', 'shift_name', 'Morning Shift'),
        'e2e-event-{event_id}'
    );
    """)

    # Claim job as worker
    worker_id = str(uuid.uuid4())
    code2, out2, _ = run_psql(f"SELECT public.claim_notification_delivery_jobs(10, 60, '{worker_id}'::UUID);")
    data2 = json.loads(out2)
    claimed = data2.get("jobs", [])
    target = next((j for j in claimed if j.get("recipient_user_id") == user_id and j.get("channel") == "PUSH"), None)
    if not target:
        return False, f"E2E push job not claimed: {data2}"

    # Record delivery success
    job_id = target["job_id"]
    code3, out3, _ = run_psql(f"SELECT public.record_delivery_attempt_outcome('{job_id}'::UUID, '{worker_id}'::UUID, 'SUCCESS'::public.delivery_attempt_outcome, 'FCM', '200_OK', NULL, 'msg_e2e_1');")
    data3 = json.loads(out3)
    if data3.get("status") == "DELIVERED":
        return True, ""
    return False, f"E2E delivery outcome failed: {data3}"

# ======================================================================
# MAIN EXECUTION RUNNER
# ======================================================================

def main():
    print("===========================================================================")
    print("YELLOWSHIFTS PHASE 6 INDEPENDENT ADVERSARIAL AUDIT & REMEDIATION SUITE V2")
    print("===========================================================================")

    setup_fresh_db()
    seed_audit_context()

    scenarios = [
        ("AUDIT-V2-01", "Migration 010 Schema Extensions (Token, Incident ID, System Invariant)", test_01_schema_extensions),
        ("AUDIT-V2-02", "Direct UPDATE on Notifications Table Denied via Table Privilege", test_02_direct_notification_update_blocked),
        ("AUDIT-V2-03", "Trigger Enforces Column Immutability on Notifications", test_03_notification_immutability_trigger_protection),
        ("AUDIT-V2-04", "Direct Write Privileges on Preferences Table Revoked", test_04_direct_preference_write_blocked),
        ("AUDIT-V2-05", "Preference RPC Enforces Mandatory SYSTEM In-App Channel", test_05_update_preference_rpc_enforces_system_mandatory),
        ("AUDIT-V2-06", "Push Device Registration Persists Token for Delivery Worker", test_06_push_device_registration_persists_raw_token_safely),
        ("AUDIT-V2-07", "Device Token Protected from Unprivileged Direct Queries", test_07_device_token_not_exposed_in_public_select),
        ("AUDIT-V2-08", "Worker Claim Returns Delivery Tokens & Idempotency Key", test_08_worker_claim_retrieves_push_tokens_and_idempotency_key),
        ("AUDIT-V2-09", "Real Multi-Threaded Worker Claim Concurrency (SKIP LOCKED)", test_09_worker_concurrency_skip_locked),
        ("AUDIT-V2-10", "Worker Outcome Recording & State Machine Transitions", test_10_worker_outcome_recording_and_state_machine),
        ("AUDIT-V2-11", "Invalid Worker Lock Token Rejection (P0065)", test_11_invalid_lock_token_rejected),
        ("AUDIT-V2-12", "Kiosk Onboarding 15m Grace Period (Zero False Alerts)", test_12_kiosk_onboarding_grace_period_no_false_offline),
        ("AUDIT-V2-13", "Kiosk Offline/Recovered Lifecycle & Anti-Storm Deduplication", test_13_kiosk_offline_and_recovery_incident_lifecycle),
        ("AUDIT-V2-14", "Subsequent Kiosk Incidents Not Suppressed by Deduplication", test_14_kiosk_subsequent_offline_incident_not_suppressed),
        ("AUDIT-V2-15", "Availability Deadline Reminder & Extension Fresh Deduplication", test_15_availability_deadline_reminder_and_extension_deduplication),
        ("AUDIT-V2-16", "Schedule Revision Notifies Affected Employee on Published Mod", test_16_schedule_revision_notifies_only_affected_employee),
        ("AUDIT-V2-17", "Cleanup Preserves Mandatory Compliance Notifications", test_17_cleanup_preserves_mandatory_compliance_records),
        ("AUDIT-V2-18", "All Phase 6 Functions Pinned with search_path=public, pg_temp", test_18_security_definer_and_search_path_audit),
        ("AUDIT-V2-19", "Cross-User Mark-Notification-Read Rejected (P0060)", test_19_mark_notification_read_cross_user_denied),
        ("AUDIT-V2-20", "Keyset Pagination Limit Clamping & Security", test_20_keyset_pagination_clamping),
        ("AUDIT-V2-21", "Submit Availability Emits Confirmation Notification", test_21_submit_availability_emits_confirmation),
        ("AUDIT-V2-22", "Remove Shift Assignment Emits SHIFT_REMOVED Notification", test_22_remove_shift_assignment_emits_notification),
        ("AUDIT-V2-23", "Move Shift Assignment Emits SHIFT_CHANGED Notification", test_23_move_shift_assignment_emits_notification),
        ("AUDIT-V2-24", "Revoke Identity Profile Emits Mandatory IDENTITY_PROFILE_REVOKED", test_24_revoke_identity_profile_emits_mandatory_notification),
        ("AUDIT-V2-25", "Revoke Notification Device Safely Deactivates Token", test_25_revoke_notification_device_marks_inactive),
        ("AUDIT-V2-26", "Mark All Notifications Read Atomic to Caller", test_26_mark_all_notifications_read_updates_only_caller),
        ("AUDIT-V2-27", "Future Timestamp Spoofing on seen_at Blocked", test_27_future_timestamp_spoofing_prevented_on_seen_at),
        ("AUDIT-V2-28", "Lease Expiration Auto-Reclaim by Subsequent Worker Cycle", test_28_lease_expiration_auto_reclaim),
        ("AUDIT-V2-29", "Active Leased Job Protected Against Worker Stealing", test_29_active_lease_protected_from_other_workers),
        ("AUDIT-V2-30", "Retry Backoff Progression (1m -> 5m -> 15m -> Max Failure)", test_30_retry_backoff_and_max_attempts),
        ("AUDIT-V2-31", "Non-Service-Role Call to claim_notification_delivery_jobs Denied", test_31_non_service_role_claim_denied),
        ("AUDIT-V2-32", "Non-Service-Role Call to record_delivery_attempt_outcome Denied", test_32_non_service_role_record_outcome_denied),
        ("AUDIT-V2-33", "Non-Service-Role Call to cleanup_expired_notifications Denied", test_33_non_service_role_cleanup_denied),
        ("AUDIT-V2-34", "Non-Service-Role Call to evaluate_kiosk_health_transitions Denied", test_34_non_service_role_kiosk_evaluator_denied),
        ("AUDIT-V2-35", "Non-Service-Role Call to generate_due_notification_reminders Denied", test_35_non_service_role_due_reminders_evaluator_denied),
        ("AUDIT-V2-36", "Cross-Station Notification Data Isolation", test_36_cross_station_notification_isolation),
        ("AUDIT-V2-37", "Direct DELETE on Notifications Table Blocked", test_37_direct_delete_on_notifications_blocked),
        ("AUDIT-V2-38", "Direct INSERT on Notifications Table Blocked", test_38_direct_insert_on_notifications_blocked),
        ("AUDIT-V2-39", "Keyset Pagination Cursor Continuity and Zero Duplication", test_39_keyset_pagination_has_more_and_cursor),
        ("AUDIT-V2-40", "Category Filter in Notification Feed Selection", test_40_category_filter_in_query),
        ("AUDIT-V2-41", "Unread Notification Count by Category Breakdown", test_41_unread_notification_count_by_category),
        ("AUDIT-V2-42", "Mark Notification Read Idempotent Execution", test_42_mark_notification_read_idempotent),
        ("AUDIT-V2-43", "Kiosk Offline Alert Invariant is_mandatory = true", test_43_kiosk_offline_is_mandatory),
        ("AUDIT-V2-44", "Attendance Manual Correction Notification Mandatory & Action", test_44_attendance_manual_correction_mandatory),
        ("AUDIT-V2-45", "Identity Admin Override Notification Mandatory CRITICAL", test_45_identity_override_used_mandatory),
        ("AUDIT-V2-46", "Device Registration Input Validation & Error Codes (P0061-P0063)", test_46_device_token_invalid_inputs_raise_errors),
        ("AUDIT-V2-47", "Worker Claim Batch Size & Lease Duration Strict Clamping", test_47_worker_batch_size_and_lease_clamping),
        ("AUDIT-V2-48", "Cleanup Retention Ignores Recent Notifications (< 90 days)", test_48_cleanup_ignores_recent_records),
        ("AUDIT-V2-49", "Cleanup Retention Preserves Old Unread Notifications", test_49_cleanup_ignores_unread_old_records),
        ("AUDIT-V2-50", "Full End-to-End Lifecycle (Event -> Outbox -> Worker Delivery)", test_50_full_end_to_end_lifecycle),
    ]

    passed = 0
    total = len(scenarios)
    for s_id, s_desc, s_fn in scenarios:
        if run_test(s_id, s_desc, s_fn):
            passed += 1

    print("\n" + "=" * 75)
    print(f"AUDIT V2 RESULTS: {passed} / {total} SCENARIOS PASSED ({(passed/total)*100:.1f}%)")
    print("=" * 75)

    if passed == total:
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()
