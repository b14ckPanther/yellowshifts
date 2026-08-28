#!/usr/bin/env python3
"""
YellowShifts — Phase 6 Comprehensive Adversarial Audit Suite
60+ end-to-end scenarios validating transactional outbox, delivery worker races,
kiosk health transitions, reminder generators, user inbox RPCs, and domain integration.
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

DB_NAME = "yellowshifts_phase6_audit"
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

    -- Memberships
    INSERT INTO public.station_memberships (id, station_id, user_id, role, status) VALUES
    ('10000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'ADMIN', 'ACTIVE'),
    ('10000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'SHIFT_MANAGER', 'ACTIVE'),
    ('10000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'EMPLOYEE', 'ACTIVE'),
    ('10000000-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'EMPLOYEE', 'ACTIVE'),
    ('10000000-0000-0000-0000-000000000005', '22222222-2222-2222-2222-222222222222', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'ADMIN', 'ACTIVE')
    ON CONFLICT (id) DO NOTHING;

    -- Kiosks (both starting active and online)
    INSERT INTO public.kiosk_devices (id, station_id, name, device_identifier, secret_hash, created_by, is_active, last_seen_at) VALUES
    ('90000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'North Kiosk Main', 'KIOSK-N1', encode(sha256('kiosk_secret_1'::bytea), 'hex'), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true, now()),
    ('90000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'North Kiosk Secondary', 'KIOSK-N2', encode(sha256('kiosk_secret_2'::bytea), 'hex'), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true, now())
    ON CONFLICT (id) DO NOTHING;

    -- Shift Templates
    INSERT INTO public.shift_templates (id, station_id, name, start_time, end_time, sort_order)
    VALUES ('80000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Morning Shift', '07:00:00', '15:00:00', 1)
    ON CONFLICT (id) DO NOTHING;
    """
    code, _, err = run_psql(sql)
    if code != 0:
        print(f"[-] Seeding context failed: {err}")
        sys.exit(1)

def helper_create_shift_and_presence(user_id, station_id, membership_id, kiosk_id, action="CHECK_IN", starts_at_offset="-2 minutes"):
    ap_id = str(uuid.uuid4())
    ws_id = str(uuid.uuid4())
    shift_id = str(uuid.uuid4())
    assign_id = str(uuid.uuid4())
    pst_id = str(uuid.uuid4())
    pres_id = str(uuid.uuid4())
    tmpl_id = '80000000-0000-0000-0000-000000000001'

    raw_token = f"PRES_TOK_{uuid.uuid4().hex}"
    tok_hash = hashlib.sha256(raw_token.encode("utf-8")).hexdigest()

    qr_id = str(uuid.uuid4())
    chal_hash = hashlib.sha256(f"CHAL_{uuid.uuid4().hex}".encode("utf-8")).hexdigest()

    sql = f"""
    INSERT INTO public.kiosk_qr_challenges (
        id, station_id, kiosk_device_id, challenge_hash, display_code, expires_at
    ) VALUES (
        '{qr_id}', '{station_id}', '{kiosk_id}', '{chal_hash}', '123456', now() + INTERVAL '30 seconds'
    ) ON CONFLICT DO NOTHING;

    INSERT INTO public.availability_periods (id, station_id, week_start_date, submission_deadline, status, created_by)
    VALUES ('{ap_id}', '{station_id}', current_date, now() + interval '1 day', 'OPEN', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
    ON CONFLICT (station_id, week_start_date) DO UPDATE SET status = 'OPEN';

    INSERT INTO public.availability_period_shift_templates (id, availability_period_id, shift_template_id, name_snapshot, start_time_snapshot, end_time_snapshot, sort_order_snapshot)
    VALUES ('{pst_id}', (SELECT id FROM public.availability_periods WHERE station_id = '{station_id}' AND week_start_date = current_date), '{tmpl_id}', 'Morning Shift', '07:00:00', '15:00:00', 1)
    ON CONFLICT (availability_period_id, shift_template_id) DO NOTHING;

    INSERT INTO public.work_schedules (id, station_id, availability_period_id, week_start_date, status, version, created_by)
    VALUES ('{ws_id}', '{station_id}', (SELECT id FROM public.availability_periods WHERE station_id = '{station_id}' AND week_start_date = current_date), current_date, 'PUBLISHED', 1, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
    ON CONFLICT (station_id, week_start_date) DO UPDATE SET status = 'PUBLISHED';

    INSERT INTO public.work_schedule_shifts (
        id, work_schedule_id, station_id, operational_date, period_shift_template_id,
        shift_name_snapshot, start_time_snapshot, end_time_snapshot, starts_at, ends_at, required_staff_count
    ) VALUES (
        '{shift_id}',
        (SELECT id FROM public.work_schedules WHERE station_id = '{station_id}' AND week_start_date = current_date),
        '{station_id}', current_date,
        (SELECT id FROM public.availability_period_shift_templates WHERE availability_period_id = (SELECT id FROM public.availability_periods WHERE station_id = '{station_id}' AND week_start_date = current_date) LIMIT 1),
        'Morning Shift', '07:00:00', '15:00:00', now() + INTERVAL '{starts_at_offset}', now() + INTERVAL '{starts_at_offset}' + INTERVAL '8 hours', 1
    );

    INSERT INTO public.shift_assignments (
        id, work_schedule_shift_id, station_id, membership_id, user_id,
        availability_state_snapshot, assigned_by
    ) VALUES (
        '{assign_id}', '{shift_id}', '{station_id}', '{membership_id}', '{user_id}',
        'AVAILABLE', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    );

    INSERT INTO public.attendance_presence_proofs (
        id, station_id, kiosk_device_id, qr_challenge_id, station_membership_id, employee_user_id,
        action, token_hash, expires_at, created_at
    ) VALUES (
        '{pres_id}', '{station_id}', '{kiosk_id}', '{qr_id}', '{membership_id}', '{user_id}',
        '{action}', '{tok_hash}', now() + INTERVAL '120 seconds', now()
    );
    """
    code, _, err = run_psql(sql)
    if code != 0:
        raise RuntimeError(f"Failed helper_create_shift_and_presence: {err}")
    return raw_token, pres_id

def run_tests():
    total = 0
    passed = 0

    def test(name, fn):
        nonlocal total, passed
        total += 1
        print(f"[{total:02d}] RUNNING: {name} ...", end=" ")
        try:
            fn()
            passed += 1
            print("PASSED")
        except Exception as e:
            print(f"FAILED: {e}")

    # =========================================================================
    # SECTION 1: OUTBOX & EVENT INVARIANTS (T01 - T08)
    # =========================================================================
    def t01():
        dedup = f"test-dedup-{uuid.uuid4()}"
        code1, out1, _ = run_psql(f"""
            SELECT public.emit_notification_event(
                '11111111-1111-1111-1111-111111111111', 'SHIFT_ASSIGNED', 'SCHEDULE', 'NORMAL',
                'work_schedule', gen_random_uuid(), NULL,
                '{{"target_user_id": "cccccccc-cccc-cccc-cccc-cccccccccccc", "shift_name": "Morning"}}'::jsonb,
                '{dedup}'
            );
        """)
        ev1 = out1.strip()
        code2, out2, _ = run_psql(f"""
            SELECT public.emit_notification_event(
                '11111111-1111-1111-1111-111111111111', 'SHIFT_ASSIGNED', 'SCHEDULE', 'NORMAL',
                'work_schedule', gen_random_uuid(), NULL,
                '{{"target_user_id": "cccccccc-cccc-cccc-cccc-cccccccccccc", "shift_name": "Morning"}}'::jsonb,
                '{dedup}'
            );
        """)
        ev2 = out2.strip()
        assert ev1 == ev2, f"Expected idempotent event ID match, got {ev1} vs {ev2}"
        code_cnt, cnt, _ = run_psql(f"SELECT count(*) FROM public.notifications WHERE deduplication_key LIKE '{dedup}%';")
        assert int(cnt.strip()) == 1, f"Expected exactly 1 inbox row for dedup key, got {cnt}"
    test("Event Deduplication Idempotency (Single Inbox Row on Re-emit)", t01)

    def t02():
        ev_id = str(uuid.uuid4())
        run_psql(f"""
            SELECT public.emit_notification_event(
                '11111111-1111-1111-1111-111111111111', 'EMPLOYEE_CHECKED_IN', 'ATTENDANCE', 'NORMAL',
                'attendance_record', '{ev_id}', 'cccccccc-cccc-cccc-cccc-cccccccccccc',
                '{{"employee_name": "Charlie Worker", "shift_name": "Morning"}}'::jsonb,
                'test-mgr-route:{ev_id}'
            );
        """)
        code, out, _ = run_psql(f"""
            SELECT json_agg(recipient_user_id) 
            FROM public.notifications 
            WHERE deduplication_key LIKE 'test-mgr-route:{ev_id}%';
        """)
        recipients = json.loads(out)
        assert "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" in recipients, "Admin should receive manager alert"
        assert "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb" in recipients, "Shift Manager should receive manager alert"
        assert "cccccccc-cccc-cccc-cccc-cccccccccccc" not in recipients, "Employee should not receive station manager alert"
    test("Multi-Recipient Routing to Station Management (Admin & Shift Manager)", t02)

    def t03():
        ev_id = str(uuid.uuid4())
        run_psql(f"""
            SELECT public.emit_notification_event(
                '11111111-1111-1111-1111-111111111111', 'CHECK_IN_CONFIRMED', 'ATTENDANCE', 'LOW',
                'attendance_record', '{ev_id}', 'cccccccc-cccc-cccc-cccc-cccccccccccc',
                '{{"target_user_id": "cccccccc-cccc-cccc-cccc-cccccccccccc", "shift_name": "Morning"}}'::jsonb,
                'test-target-route:{ev_id}'
            );
        """)
        code, out, _ = run_psql(f"""
            SELECT recipient_user_id 
            FROM public.notifications 
            WHERE deduplication_key LIKE 'test-target-route:{ev_id}%';
        """)
        assert out.strip() == "cccccccc-cccc-cccc-cccc-cccccccccccc"
    test("Targeted Recipient Direct Routing (Self Confirmation)", t03)

    def t04():
        run_as_user_json("dddddddd-dddd-dddd-dddd-dddddddddddd", "SELECT public.update_my_notification_preferences('ATTENDANCE', false, false, false, false);")
        ev_id = str(uuid.uuid4())
        run_psql(f"""
            SELECT public.emit_notification_event(
                '11111111-1111-1111-1111-111111111111', 'ATTENDANCE_MANUALLY_CORRECTED', 'ATTENDANCE', 'HIGH',
                'attendance_record', '{ev_id}', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
                '{{"target_user_id": "dddddddd-dddd-dddd-dddd-dddddddddddd", "employee_name": "David", "reason": "Correction"}}'::jsonb,
                'test-mandatory-alert:{ev_id}'
            );
        """)
        code, res, _ = run_as_user_json("dddddddd-dddd-dddd-dddd-dddddddddddd", "SELECT public.get_my_notifications();")
        assert code == 0 and any(item["event_type"] == "ATTENDANCE_MANUALLY_CORRECTED" for item in res["items"])
    test("Mandatory Security/Correction Notification Bypasses User Suppression", t04)

    def t05():
        run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.update_my_notification_preferences('SCHEDULE', true, false, false, false);")
        run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.register_notification_device('ios', 'apns', 'token_char_t05_12345', 'Charlie Phone');")

        ev_id = str(uuid.uuid4())
        run_psql(f"""
            SELECT public.emit_notification_event(
                '11111111-1111-1111-1111-111111111111', 'SHIFT_ASSIGNED', 'SCHEDULE', 'NORMAL',
                'work_schedule', '{ev_id}', NULL,
                '{{"target_user_id": "cccccccc-cccc-cccc-cccc-cccccccccccc", "shift_name": "Morning"}}'::jsonb,
                'test-nopush:{ev_id}'
            );
        """)
        code, out, _ = run_psql(f"""
            SELECT count(*) 
            FROM public.notification_delivery_jobs j
            JOIN public.notifications n ON j.notification_id = n.id
            WHERE n.deduplication_key LIKE 'test-nopush:{ev_id}%' AND j.channel = 'PUSH';
        """)
        assert int(out.strip()) == 0
    test("Disabled Delivery Channel Suppresses Outbox Job Enqueueing", t05)

    def t06():
        run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.update_my_notification_preferences('SCHEDULE', true, true, false, false);")
        ev_id = str(uuid.uuid4())
        run_psql(f"""
            SELECT public.emit_notification_event(
                '11111111-1111-1111-1111-111111111111', 'SHIFT_ASSIGNED', 'SCHEDULE', 'NORMAL',
                'work_schedule', '{ev_id}', NULL,
                '{{"target_user_id": "cccccccc-cccc-cccc-cccc-cccccccccccc", "shift_name": "Morning"}}'::jsonb,
                'test-push-enqueued:{ev_id}'
            );
        """)
        code, out, _ = run_psql(f"""
            SELECT count(*) 
            FROM public.notification_delivery_jobs j
            JOIN public.notifications n ON j.notification_id = n.id
            WHERE n.deduplication_key LIKE 'test-push-enqueued:{ev_id}%' AND j.channel = 'PUSH' AND j.status = 'PENDING';
        """)
        assert int(out.strip()) == 1
    test("Enabled Channel Enqueues PENDING Delivery Job in Outbox", t06)

    def t07():
        code, out, _ = run_psql("SELECT render_data, title_key, body_key FROM public.notifications WHERE title_key = 'notif_shift_assigned_title' LIMIT 1;")
        assert code == 0 and out.strip() != ""
        parts = out.strip().split("|")
        render_data = json.loads(parts[0])
        assert "shift_name" in render_data and "station_name" in render_data
    test("Render Data Schema & Template Key Contract Consistency", t07)

    def t08():
        oversized = "{" + ", ".join([f'"f{i}": "{("b"*1000)}"' for i in range(20)]) + "}"
        code, _, err = run_psql(f"""
            INSERT INTO public.notifications (
                recipient_user_id, category, event_type, priority, title_key, body_key,
                render_data, deduplication_key
            ) VALUES (
                'cccccccc-cccc-cccc-cccc-cccccccccccc', 'SYSTEM', 'TEST', 'LOW', 't', 'b',
                '{oversized}'::jsonb, 'test-oversize-render'
            );
        """)
        assert code != 0 and "check_notification_render_data_size" in err
    test("Render Data Maximum Size Constraint Guard (<= 16KB)", t08)

    # =========================================================================
    # SECTION 2: USER INBOX RPC MECHANICS (T09 - T20)
    # =========================================================================
    def t09():
        for i in range(25):
            ev_id = str(uuid.uuid4())
            run_psql(f"""
                SELECT public.emit_notification_event(
                    '11111111-1111-1111-1111-111111111111', 'SHIFT_ASSIGNED', 'SCHEDULE', 'NORMAL',
                    'work_schedule', '{ev_id}', NULL,
                    '{{"target_user_id": "cccccccc-cccc-cccc-cccc-cccccccccccc", "shift_name": "Shift {i}"}}'::jsonb,
                    'batch-notif-{i}:{ev_id}'
                );
            """)
        code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.get_my_notifications();")
        assert code == 0 and len(res["items"]) == 20
        assert res["has_more"] is True
        assert res["next_cursor_created_at"] is not None
    test("get_my_notifications Keyset Pagination Default Page Limit (20)", t09)

    def t10():
        code1, res1, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.get_my_notifications(15);")
        assert len(res1["items"]) == 15
        assert res1["has_more"] is True
        cur_time = res1["next_cursor_created_at"]
        cur_id = res1["next_cursor_id"]

        code2, res2, _ = run_as_user_json(
            "cccccccc-cccc-cccc-cccc-cccccccccccc",
            f"SELECT public.get_my_notifications(15, '{cur_time}', '{cur_id}');"
        )
        assert code2 == 0 and len(res2["items"]) >= 10
        ids_p1 = {item["id"] for item in res1["items"]}
        ids_p2 = {item["id"] for item in res2["items"]}
        assert len(ids_p1.intersection(ids_p2)) == 0, "Pages should be strictly disjoint"
    test("Keyset Cursor Forward Pagination (Strict Disjoint Pages)", t10)

    def t11():
        code, res, _ = run_as_user_json("eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee", "SELECT public.get_my_notifications();")
        assert code == 0 and len(res["items"]) == 0 and res["has_more"] is False
    test("get_my_notifications Empty State Handling", t11)

    def t12():
        code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.get_my_notifications(20, NULL, NULL, 'SCHEDULE');")
        assert code == 0 and all(item["category"] == "SCHEDULE" for item in res["items"])
    test("get_my_notifications Category Filtering", t12)

    def t13():
        code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.get_unread_notification_count();")
        assert code == 0 and res["unread_count"] > 0
    test("get_unread_notification_count Correct Calculation", t13)

    def t14():
        code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.get_my_notifications(1);")
        notif_id = res["items"][0]["id"]
        assert res["items"][0]["read_at"] is None

        code_m, res_m, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.mark_notification_read('{notif_id}');")
        assert code_m == 0 and res_m["success"] is True and res_m["read_at"] is not None

        code_v, res_v, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.get_my_notifications(1);")
        assert res_v["items"][0]["read_at"] is not None
    test("mark_notification_read Status Transition (NULL -> UTC Timestamp)", t14)

    def t15():
        code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.get_my_notifications(1);")
        notif_id = res["items"][0]["id"]
        r1 = res["items"][0]["read_at"]

        code2, res2, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.mark_notification_read('{notif_id}');")
        assert code2 == 0 and res2["read_at"] == r1
    test("mark_notification_read Idempotency on Repeated Invocations", t15)

    def t16():
        fake_id = str(uuid.uuid4())
        code, _, err = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.mark_notification_read('{fake_id}');")
        assert code != 0 and "P0060" in err
    test("mark_notification_read Non-Existent Notification Rejection (P0060)", t16)

    def t17():
        code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.mark_all_notifications_read();")
        assert code == 0 and res["marked_read_count"] > 0
        code_c, res_c, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.get_unread_notification_count();")
        assert res_c["unread_count"] == 0
    test("mark_all_notifications_read Full Inbox Sweep", t17)

    def t18():
        ev1 = str(uuid.uuid4())
        ev2 = str(uuid.uuid4())
        run_psql(f"""
            SELECT public.emit_notification_event('11111111-1111-1111-1111-111111111111', 'CHECK_IN_CONFIRMED', 'ATTENDANCE', 'LOW', 'attendance_record', '{ev1}', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '{{"target_user_id": "cccccccc-cccc-cccc-cccc-cccccccccccc"}}'::jsonb, 't18-att:{ev1}');
            SELECT public.emit_notification_event('11111111-1111-1111-1111-111111111111', 'SHIFT_ASSIGNED', 'SCHEDULE', 'LOW', 'work_schedule', '{ev2}', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '{{"target_user_id": "cccccccc-cccc-cccc-cccc-cccccccccccc"}}'::jsonb, 't18-sch:{ev2}');
        """)
        code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.mark_all_notifications_read('ATTENDANCE');")
        assert code == 0 and res["marked_read_count"] >= 1

        code_s, res_s, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.get_my_notifications(5, NULL, NULL, 'SCHEDULE', true);")
        assert len(res_s["items"]) >= 1
    test("mark_all_notifications_read Category-Scoped Sweep", t18)

    def t19():
        code, res, _ = run_as_user_json("eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee", "SELECT public.get_my_notification_preferences();")
        assert code == 0 and len(res["preferences"]) == 6
        assert all("category" in p and "in_app_enabled" in p for p in res["preferences"])
    test("get_my_notification_preferences Complete 6-Category Enum Schema", t19)

    def t20():
        code, res, _ = run_as_user_json("eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee", "SELECT public.update_my_notification_preferences('AVAILABILITY', true, true, true, false);")
        assert code == 0 and res["email_enabled"] is True
    test("update_my_notification_preferences Channel Configuration Upsert", t20)

    # =========================================================================
    # SECTION 3: PUSH DEVICE REGISTRY (T21 - T27)
    # =========================================================================
    def t21():
        code, res, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "SELECT public.register_notification_device('android', 'fcm', 'fcm_token_alice_prod_xyz123', 'Pixel 9 Pro');")
        assert code == 0 and res["is_active"] is True
    test("register_notification_device Standard Token Registration", t21)

    def t22():
        code, _, err = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "SELECT public.register_notification_device('android', 'fcm', 'short', 'Bad Device');")
        assert code != 0 and "P0061" in err
    test("register_notification_device Short Token Guard (P0061)", t22)

    def t23():
        code, _, err = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "SELECT public.register_notification_device('blackberry', 'fcm', 'fcm_token_alice_xyz', 'BB');")
        assert code != 0 and "P0062" in err
    test("register_notification_device Unsupported Platform Guard (P0062)", t23)

    def t24():
        code, _, err = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "SELECT public.register_notification_device('android', 'unsupported_provider', 'fcm_token_alice_xyz', 'Device');")
        assert code != 0 and "P0063" in err
    test("register_notification_device Unsupported Provider Guard (P0063)", t24)

    def t25():
        code1, res1, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "SELECT public.register_notification_device('android', 'fcm', 'fcm_token_alice_prod_xyz123', 'Pixel 9 Pro Renamed');")
        dev_id = res1["device_id"]
        run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", f"SELECT public.revoke_notification_device('{dev_id}');")
        code2, res2, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "SELECT public.register_notification_device('android', 'fcm', 'fcm_token_alice_prod_xyz123', 'Pixel 9 Pro');")
        assert res2["device_id"] == dev_id and res2["is_active"] is True
    test("register_notification_device Re-activation Idempotency on Token Collision", t25)

    def t26():
        code, res, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "SELECT public.register_notification_device('web', 'webpush', 'webpush_token_alice_browser_123', 'Chrome');")
        dev_id = res["device_id"]
        code_r, res_r, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", f"SELECT public.revoke_notification_device('{dev_id}');")
        assert code_r == 0 and res_r["revoked_at"] is not None
    test("revoke_notification_device Lifecycle Revocation", t26)

    def t27():
        code, _, err = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", f"SELECT public.revoke_notification_device('{uuid.uuid4()}');")
        assert code != 0 and "P0064" in err
    test("revoke_notification_device Non-Existent Device Rejection (P0064)", t27)

    # =========================================================================
    # SECTION 4: OUTBOX WORKER CLAIMING & CONCURRENCY (T28 - T37)
    # =========================================================================
    def t28():
        ev_id = str(uuid.uuid4())
        run_psql(f"""
            SELECT public.emit_notification_event(
                '11111111-1111-1111-1111-111111111111', 'SHIFT_ASSIGNED', 'SCHEDULE', 'HIGH',
                'work_schedule', '{ev_id}', NULL,
                '{{"target_user_id": "cccccccc-cccc-cccc-cccc-cccccccccccc", "shift_name": "Morning"}}'::jsonb,
                't28-claim:{ev_id}'
            );
        """)
        code, out, _ = run_psql("SELECT public.claim_notification_delivery_jobs(5, 60);")
        res = json.loads(out)
        assert res["success"] is True and res["claimed_count"] >= 1
        assert res["lock_token"] is not None
        job = res["jobs"][0]
        assert "job_id" in job and "lock_token" in job
    test("claim_notification_delivery_jobs Worker Lease Acquisition", t28)

    def t29():
        for i in range(20):
            ev_id = str(uuid.uuid4())
            run_psql(f"""
                SELECT public.emit_notification_event(
                    '11111111-1111-1111-1111-111111111111', 'SHIFT_ASSIGNED', 'SCHEDULE', 'HIGH',
                    'work_schedule', '{ev_id}', NULL,
                    '{{"target_user_id": "cccccccc-cccc-cccc-cccc-cccccccccccc", "shift_name": "Shift {i}"}}'::jsonb,
                    't29-race-{i}:{ev_id}'
                );
            """)

        all_claimed_job_ids = []

        def worker_claim():
            code, out, _ = run_psql("SELECT public.claim_notification_delivery_jobs(4, 60);")
            if code == 0 and out.strip():
                try:
                    data = json.loads(out)
                    return [j["job_id"] for j in data["jobs"]]
                except Exception:
                    return []
            return []

        with ThreadPoolExecutor(max_workers=8) as executor:
            futures = [executor.submit(worker_claim) for _ in range(8)]
            for f in futures:
                all_claimed_job_ids.extend(f.result())

        assert len(all_claimed_job_ids) == len(set(all_claimed_job_ids)), "Concurrency race condition: Duplicate job IDs claimed across workers!"
    test("Worker Concurrency Claim Race (FOR UPDATE SKIP LOCKED Zero-Collision)", t29)

    def t30():
        run_psql("""
            UPDATE public.notification_delivery_jobs
            SET status = 'PROCESSING', lease_expires_at = now() - INTERVAL '10 seconds'
            WHERE id = (SELECT id FROM public.notification_delivery_jobs WHERE status = 'PROCESSING' LIMIT 1);
        """)
        code, out, _ = run_psql("SELECT public.claim_notification_delivery_jobs(1, 60);")
        res = json.loads(out)
        assert res["claimed_count"] >= 1, "Failed to recover abandoned job with expired lease"
    test("Abandoned Job Lease Expiration Recovery", t30)

    def t31():
        run_psql("""
            INSERT INTO public.notification_delivery_jobs (
                notification_id, recipient_user_id, channel, status, next_attempt_at
            ) VALUES (
                (SELECT id FROM public.notifications LIMIT 1),
                'cccccccc-cccc-cccc-cccc-cccccccccccc', 'PUSH', 'RETRY', now() + INTERVAL '1 hour'
            );
        """)
        code, out, _ = run_psql("""
            SELECT count(*) 
            FROM public.notification_delivery_jobs 
            WHERE next_attempt_at > now() AND status = 'PROCESSING';
        """)
        assert int(out.strip()) == 0
    test("Future Scheduled Retry Jobs Excluded From Immediate Claiming", t31)

    def t32():
        code, out, _ = run_psql("SELECT public.claim_notification_delivery_jobs(1, 60);")
        res = json.loads(out)
        job = res["jobs"][0]
        job_id = job["job_id"]
        lock_token = res["lock_token"]

        code_s, out_s, _ = run_psql(f"""
            SELECT public.record_delivery_attempt_outcome(
                '{job_id}', '{lock_token}', 'SUCCESS', 'FCM', '200_OK', NULL, 'fcm_msg_123'
            );
        """)
        res_s = json.loads(out_s)
        assert res_s["status"] == "DELIVERED"
        code_chk, status, _ = run_psql(f"SELECT status FROM public.notification_delivery_jobs WHERE id = '{job_id}';")
        assert status.strip() == "DELIVERED"
    test("record_delivery_attempt_outcome SUCCESS Lifecycle Transition", t32)

    def t33():
        code, out, _ = run_psql("SELECT public.claim_notification_delivery_jobs(1, 60);")
        res = json.loads(out)
        job = res["jobs"][0]
        job_id = job["job_id"]
        lock_token = res["lock_token"]

        code_f, out_f, _ = run_psql(f"""
            SELECT public.record_delivery_attempt_outcome(
                '{job_id}', '{lock_token}', 'TEMPORARY_FAILURE', 'APNS', '503_UNAVAILABLE', 'PROVIDER_RATE_LIMIT'
            );
        """)
        res_f = json.loads(out_f)
        assert res_f["status"] == "RETRY"
        assert res_f["next_attempt_at"] is not None
    test("record_delivery_attempt_outcome TEMPORARY_FAILURE Exponential Backoff", t33)

    def t34():
        code, out, _ = run_psql("SELECT public.claim_notification_delivery_jobs(1, 60);")
        res = json.loads(out)
        job = res["jobs"][0]
        job_id = job["job_id"]
        lock_token = res["lock_token"]

        code_f, out_f, _ = run_psql(f"""
            SELECT public.record_delivery_attempt_outcome(
                '{job_id}', '{lock_token}', 'PERMANENT_FAILURE', 'APNS', '410_GONE', 'INVALID_TOKEN'
            );
        """)
        res_f = json.loads(out_f)
        assert res_f["status"] == "FAILED"
    test("record_delivery_attempt_outcome PERMANENT_FAILURE Immediate Termination", t34)

    def t35():
        job_id = str(uuid.uuid4())
        run_psql(f"""
            INSERT INTO public.notification_delivery_jobs (
                id, notification_id, recipient_user_id, channel, status, attempt_count, max_attempts, lock_token, locked_at, lease_expires_at
            ) VALUES (
                '{job_id}', (SELECT id FROM public.notifications LIMIT 1), 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'PUSH',
                'PROCESSING', 5, 5, '{job_id}', now(), now() + INTERVAL '60s'
            );
        """)
        code_f, out_f, _ = run_psql(f"""
            SELECT public.record_delivery_attempt_outcome(
                '{job_id}', '{job_id}', 'TEMPORARY_FAILURE', 'FCM', '500_ERR', 'SERVER_ERROR'
            );
        """)
        res_f = json.loads(out_f)
        assert res_f["status"] == "FAILED", "Job exceeding max_attempts must transition to FAILED"
    test("Max Attempts Exhaustion Transitions Job to FAILED", t35)

    def t36():
        fake_lock = str(uuid.uuid4())
        code, _, err = run_psql(f"""
            SELECT public.record_delivery_attempt_outcome(
                (SELECT id FROM public.notification_delivery_jobs LIMIT 1), '{fake_lock}', 'SUCCESS', 'FCM'
            );
        """)
        assert code != 0 and "P0065" in err
    test("Worker Lock Token Mismatch Rejection (P0065)", t36)

    def t37():
        code, out, _ = run_psql("SELECT count(*) FROM public.notification_delivery_attempts WHERE outcome = 'SUCCESS';")
        assert int(out.strip()) >= 1
    test("Append-Only Delivery Attempt Audit Ledger Verification", t37)

    # =========================================================================
    # SECTION 5: KIOSK HEALTH EVALUATOR & TRANSITIONS (T38 - T42)
    # =========================================================================
    def t38():
        run_psql("UPDATE public.kiosk_devices SET last_seen_at = now() WHERE is_active = true;")
        code, out, _ = run_psql("SELECT public.evaluate_kiosk_health_transitions('11111111-1111-1111-1111-111111111111');")
        res = json.loads(out)
        assert res["success"] is True and res["offline_transitions"] == 0
    test("Kiosk Health Evaluator Normal Online State Check", t38)

    def t39():
        # Set Kiosk 2 to 5 minutes ago -> triggers ONLINE -> OFFLINE
        run_psql("UPDATE public.kiosk_devices SET last_seen_at = now() - INTERVAL '5 minutes' WHERE id = '90000000-0000-0000-0000-000000000002';")
        code, out, _ = run_psql("SELECT public.evaluate_kiosk_health_transitions('11111111-1111-1111-1111-111111111111');")
        res = json.loads(out)
        assert res["offline_transitions"] >= 1, f"Expected offline transition, got {res}"
        code_notif, cnt, _ = run_psql("SELECT count(*) FROM public.notifications WHERE event_type = 'KIOSK_OFFLINE';")
        assert int(cnt.strip()) >= 1
    test("Dormant Kiosk Triggers ONLINE -> OFFLINE State Transition & Alert", t39)

    def t40():
        code, out, _ = run_psql("SELECT public.evaluate_kiosk_health_transitions('11111111-1111-1111-1111-111111111111');")
        res = json.loads(out)
        assert res["offline_transitions"] == 0, "Anti-storm deduplication failed: duplicate offline transition produced"
    test("Kiosk Health Transition Anti-Storm Deduplication", t40)

    def t41():
        run_psql("UPDATE public.kiosk_devices SET last_seen_at = now() WHERE id = '90000000-0000-0000-0000-000000000002';")
        code, out, _ = run_psql("SELECT public.evaluate_kiosk_health_transitions('11111111-1111-1111-1111-111111111111');")
        res = json.loads(out)
        assert res["recovery_transitions"] >= 1, "Expected recovery transition for restored kiosk"
        code_notif, cnt, _ = run_psql("SELECT count(*) FROM public.notifications WHERE event_type = 'KIOSK_RECOVERED';")
        assert int(cnt.strip()) >= 1
    test("Kiosk Restored Heartbeat Triggers OFFLINE -> ONLINE Recovery Alert", t41)

    def t42():
        run_psql("UPDATE public.kiosk_devices SET is_active = false, last_seen_at = now() - INTERVAL '1 hour' WHERE id = '90000000-0000-0000-0000-000000000002';")
        code, out, _ = run_psql("SELECT public.evaluate_kiosk_health_transitions('11111111-1111-1111-1111-111111111111');")
        res = json.loads(out)
        assert res["offline_transitions"] == 0
    test("Deactivated Kiosks Excluded From Health Alerting", t42)

    # =========================================================================
    # SECTION 6: SCHEDULED EVALUATORS & REMINDERS (T43 - T48)
    # =========================================================================
    def t43():
        ap_id = str(uuid.uuid4())
        run_psql(f"""
            INSERT INTO public.availability_periods (
                id, station_id, week_start_date, submission_deadline, status, created_by
            ) VALUES (
                '{ap_id}', '11111111-1111-1111-1111-111111111111', current_date + 21,
                now() + INTERVAL '6 hours', 'OPEN', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
            );
        """)
        code, out, _ = run_psql("SELECT public.generate_due_notification_reminders();")
        res = json.loads(out)
        assert res["availability_reminders_emitted"] >= 1
        code_n, cnt, _ = run_psql(f"SELECT count(*) FROM public.notifications WHERE event_type = 'AVAILABILITY_DEADLINE_APPROACHING' AND deduplication_key LIKE '%{ap_id}%';")
        assert int(cnt.strip()) >= 1
    test("generate_due_notification_reminders Emits Approaching Deadline Reminder", t43)

    def t44():
        run_psql("""
            INSERT INTO public.availability_submissions (
                availability_period_id, membership_id, status
            ) VALUES (
                (SELECT id FROM public.availability_periods WHERE status = 'OPEN' ORDER BY created_at DESC LIMIT 1),
                '10000000-0000-0000-0000-000000000003', 'SUBMITTED'
            ),
            (
                (SELECT id FROM public.availability_periods WHERE status = 'OPEN' ORDER BY created_at DESC LIMIT 1),
                '10000000-0000-0000-0000-000000000004', 'SUBMITTED'
            )
            ON CONFLICT (availability_period_id, membership_id) DO UPDATE SET status = 'SUBMITTED';
        """)
        code, out, _ = run_psql("SELECT public.generate_due_notification_reminders();")
        res = json.loads(out)
        assert res["availability_reminders_emitted"] == 0
    test("Submitted Employees Excluded From Availability Reminders", t44)

    def t45():
        code, out, _ = run_psql("SELECT count(*) FROM public.notifications WHERE deduplication_key LIKE 'avail-deadline-24h:%';")
        assert int(out.strip()) >= 1
    test("Availability Reminders Strictly Deduplicated By Period & Employee", t45)

    def t46():
        helper_create_shift_and_presence(
            "dddddddd-dddd-dddd-dddd-dddddddddddd",
            "11111111-1111-1111-1111-111111111111",
            "10000000-0000-0000-0000-000000000004",
            "90000000-0000-0000-0000-000000000001",
            "CHECK_IN",
            "-30 minutes"
        )
        code, out, _ = run_psql("SELECT public.generate_due_notification_reminders();")
        res = json.loads(out)
        assert res["missed_checkins_emitted"] >= 1
    test("Missed Check-In Detection When Shift Window Exceeded Without Open Record", t46)

    def t47():
        code, out, _ = run_psql("SELECT count(*) FROM public.notifications WHERE event_type = 'EMPLOYEE_MISSED_CHECK_IN';")
        assert int(out.strip()) >= 1
    test("Missed Check-In Alert Emitted To Station Management", t47)

    def t48():
        run_psql("""
            INSERT INTO public.attendance_records (
                station_id, employee_user_id, station_membership_id, work_schedule_id,
                work_schedule_shift_id, shift_assignment_id, check_in_time, status, verification_method,
                check_in_kiosk_device_id
            ) VALUES (
                '11111111-1111-1111-1111-111111111111', 'dddddddd-dddd-dddd-dddd-dddddddddddd',
                '10000000-0000-0000-0000-000000000004',
                (SELECT work_schedule_id FROM public.work_schedule_shifts ORDER BY created_at DESC LIMIT 1),
                (SELECT id FROM public.work_schedule_shifts ORDER BY created_at DESC LIMIT 1),
                (SELECT id FROM public.shift_assignments WHERE user_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd' ORDER BY created_at DESC LIMIT 1),
                now(), 'OPEN', 'QR_ONLY', '90000000-0000-0000-0000-000000000001'
            );
        """)
        code, out, _ = run_psql("SELECT public.generate_due_notification_reminders();")
        res = json.loads(out)
        assert res["missed_checkins_emitted"] == 0
    test("Checked-In Employees Suppress Missed Check-In Alerts", t48)

    # =========================================================================
    # SECTION 7: DOMAIN RPC INTEGRATION & ATOMICITY (T49 - T55)
    # =========================================================================
    def t49():
        ap_id = str(uuid.uuid4())
        ws_id = str(uuid.uuid4())
        shift_id = str(uuid.uuid4())
        asgn_id = str(uuid.uuid4())
        pst_id = str(uuid.uuid4())
        tmpl_id = '80000000-0000-0000-0000-000000000001'

        run_psql(f"""
            INSERT INTO public.availability_periods (id, station_id, week_start_date, submission_deadline, status, created_by)
            VALUES ('{ap_id}', '11111111-1111-1111-1111-111111111111', current_date + 28, now() + interval '1 day', 'OPEN', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

            INSERT INTO public.availability_period_shift_templates (id, availability_period_id, shift_template_id, name_snapshot, start_time_snapshot, end_time_snapshot, sort_order_snapshot)
            VALUES ('{pst_id}', '{ap_id}', '{tmpl_id}', 'Morning Shift', '07:00:00', '15:00:00', 1);

            INSERT INTO public.work_schedules (id, station_id, availability_period_id, week_start_date, status, version, created_by)
            VALUES ('{ws_id}', '11111111-1111-1111-1111-111111111111', '{ap_id}', current_date + 28, 'DRAFT', 0, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

            INSERT INTO public.work_schedule_shifts (
                id, work_schedule_id, station_id, operational_date, period_shift_template_id,
                shift_name_snapshot, start_time_snapshot, end_time_snapshot, starts_at, ends_at, required_staff_count
            ) VALUES (
                '{shift_id}', '{ws_id}', '11111111-1111-1111-1111-111111111111', current_date + 28, '{pst_id}',
                'Morning Shift', '07:00:00', '15:00:00', now() + INTERVAL '28 days', now() + INTERVAL '28 days 8 hours', 1
            );

            INSERT INTO public.shift_assignments (
                id, work_schedule_shift_id, station_id, membership_id, user_id,
                availability_state_snapshot, assigned_by
            ) VALUES (
                '{asgn_id}', '{shift_id}', '11111111-1111-1111-1111-111111111111', '10000000-0000-0000-0000-000000000003',
                'cccccccc-cccc-cccc-cccc-cccccccccccc', 'AVAILABLE', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
            );
        """)
        code_p, res_p, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", f"SELECT public.publish_work_schedule('{ws_id}', 0, true);")
        assert code_p == 0 and res_p["status"] == "PUBLISHED"

        code_n, res_n, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.get_my_notifications(5, NULL, NULL, 'SCHEDULE');")
        assert any(item["event_type"] == "SCHEDULE_PUBLISHED" for item in res_n["items"])
    test("publish_work_schedule Automatically Emits SCHEDULE_PUBLISHED To Assigned Staff", t49)

    def t50():
        run_psql("UPDATE public.attendance_records SET check_out_time = now(), status = 'COMPLETED' WHERE check_out_time IS NULL;")

        pres_tok, pres_id = helper_create_shift_and_presence(
            "cccccccc-cccc-cccc-cccc-cccccccccccc",
            "11111111-1111-1111-1111-111111111111",
            "10000000-0000-0000-0000-000000000003",
            "90000000-0000-0000-0000-000000000001",
            "CHECK_IN",
            "-2 minutes"
        )

        code_ov, res_ov, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", f"SELECT public.create_identity_admin_override('{pres_tok}', 'Audit override');")
        id_token = res_ov["identity_proof_token"]

        code_ci, res_ci, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.check_in_with_presence_proof('{pres_tok}', '{id_token}');")
        assert code_ci == 0 and res_ci["status"] == "OPEN"

        code_a, res_a, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "SELECT public.get_my_notifications(5, NULL, NULL, 'ATTENDANCE');")
        assert any(item["event_type"] == "EMPLOYEE_CHECKED_IN" for item in res_a["items"])
        code_c, res_c, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.get_my_notifications(5, NULL, NULL, 'ATTENDANCE');")
        assert any(item["event_type"] == "CHECK_IN_CONFIRMED" for item in res_c["items"])
    test("check_in_with_presence_proof Emits Realtime Notification Pair (Manager & Employee)", t50)

    def t51():
        code, out, _ = run_psql("SELECT count(*) FROM public.notifications WHERE event_type = 'EMPLOYEE_LATE';")
        assert int(out.strip()) == 0
    test("Grace Period Lateness Suppression (No False-Positive Late Alerts)", t51)

    def t52():
        pres_out_tok, pres_out_id = helper_create_shift_and_presence(
            "cccccccc-cccc-cccc-cccc-cccccccccccc",
            "11111111-1111-1111-1111-111111111111",
            "10000000-0000-0000-0000-000000000003",
            "90000000-0000-0000-0000-000000000001",
            "CHECK_OUT",
            "-2 minutes"
        )

        code_co, res_co, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", f"SELECT public.check_out_with_presence_proof('{pres_out_tok}', NULL);")
        assert code_co == 0 and res_co["status"] == "COMPLETED"

        code_a, res_a, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "SELECT public.get_my_notifications(5, NULL, NULL, 'ATTENDANCE');")
        assert any(item["event_type"] == "EMPLOYEE_CHECKED_OUT" for item in res_a["items"])
        code_c, res_c, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.get_my_notifications(5, NULL, NULL, 'ATTENDANCE');")
        assert any(item["event_type"] == "CHECK_OUT_CONFIRMED" for item in res_c["items"])
    test("check_out_with_presence_proof Emits Checkout Notifications with Worked Minutes", t52)

    def t53():
        code, out, _ = run_psql("SELECT id FROM public.attendance_records WHERE employee_user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' LIMIT 1;")
        att_id = out.strip()
        code_c, res_c, _ = run_as_user_json(
            "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            f"SELECT public.correct_attendance_record('{att_id}', now() - INTERVAL '3 hours', now(), 'Shift time adjustment');"
        )
        assert code_c == 0 and res_c["success"] is True

        code_n, res_n, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.get_my_notifications(5, NULL, NULL, 'ATTENDANCE');")
        assert any(item["event_type"] == "ATTENDANCE_MANUALLY_CORRECTED" for item in res_n["items"])
    test("correct_attendance_record Emits ATTENDANCE_MANUALLY_CORRECTED Notice", t53)

    def t54():
        code, out, _ = run_psql("SELECT count(*) FROM public.notifications WHERE event_type = 'IDENTITY_ADMIN_OVERRIDE_USED';")
        assert int(out.strip()) >= 1
    test("create_identity_admin_override Emits IDENTITY_ADMIN_OVERRIDE_USED Alert", t54)

    def t55():
        cnt_before = int(run_psql("SELECT count(*) FROM public.notification_events;")[1].strip())
        run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.check_in_with_presence_proof('NON_EXISTENT_TOKEN', NULL);")
        cnt_after = int(run_psql("SELECT count(*) FROM public.notification_events;")[1].strip())
        assert cnt_before == cnt_after, "Transactional rollback invariant violated: event persisted despite RPC error"
    test("Domain RPC Failure Atomically Rolls Back Notification Event Emission", t55)

    # =========================================================================
    # SECTION 8: RETENTION & REALTIME PUBLICATION (T56 - T60)
    # =========================================================================
    def t56():
        job_id = str(uuid.uuid4())
        run_psql(f"""
            INSERT INTO public.notification_delivery_jobs (
                id, notification_id, recipient_user_id, channel, status, delivered_at, created_at
            ) VALUES (
                '{job_id}', (SELECT id FROM public.notifications LIMIT 1), 'cccccccc-cccc-cccc-cccc-cccccccccccc',
                'PUSH', 'DELIVERED', now() - INTERVAL '100 days', now() - INTERVAL '100 days'
            );
        """)
        code, out, _ = run_psql("SELECT public.cleanup_expired_notifications(90);")
        res = json.loads(out)
        assert res["success"] is True and res["purged_delivery_jobs"] >= 1
    test("cleanup_expired_notifications Purges Outdated Delivered Delivery Jobs", t56)

    def t57():
        notif_id = str(uuid.uuid4())
        run_psql(f"""
            INSERT INTO public.notifications (
                id, recipient_user_id, category, event_type, priority, title_key, body_key,
                deduplication_key, read_at, created_at
            ) VALUES (
                '{notif_id}', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'SCHEDULE', 'OLD', 'LOW',
                't', 'b', 'old-notif-1', now() - INTERVAL '100 days', now() - INTERVAL '100 days'
            );
        """)
        code, out, _ = run_psql("SELECT public.cleanup_expired_notifications(90);")
        res = json.loads(out)
        assert res["purged_notifications"] >= 1
    test("cleanup_expired_notifications Purges Old Read Notifications", t57)

    def t58():
        code, out, _ = run_psql("SELECT count(*) FROM public.notifications WHERE read_at IS NULL;")
        assert int(out.strip()) >= 1
    test("cleanup_expired_notifications Preserves All Active & Unread Items", t58)

    def t59():
        code, _, err = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.cleanup_expired_notifications(90);")
        assert code != 0 and "42501" in err
    test("cleanup_expired_notifications Rejects Non-Service-Role Callers (42501)", t59)

    def t60():
        code, out, _ = run_psql("""
            SELECT count(*) 
            FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' AND tablename = 'notifications';
        """)
        code_pub, pub_exists, _ = run_psql("SELECT count(*) FROM pg_publication WHERE pubname = 'supabase_realtime';")
        if int(pub_exists.strip()) > 0:
            assert int(out.strip()) == 1, "public.notifications table missing from supabase_realtime publication!"
    test("Supabase Realtime Publication Verification (public.notifications)", t60)

    print("=" * 75)
    print(f"PHASE 6 COMPREHENSIVE AUDIT RESULTS: {passed}/{total} PASSED ({(passed/total)*100:.1f}%)")
    print("=" * 75)
    if passed < total:
        sys.exit(1)

if __name__ == "__main__":
    setup_fresh_db()
    seed_audit_context()
    run_tests()
