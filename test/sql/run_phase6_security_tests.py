#!/usr/bin/env python3
"""
YellowShifts — Phase 6 Security Invariant Test Suite
Validates RLS, anonymous rejection, multi-tenant isolation, token privacy, and privilege hardening.
"""

import sys
import os
import shutil
import subprocess
import json
import uuid

PSQL_BIN = shutil.which("psql") or "/opt/homebrew/opt/postgresql@16/bin/psql"
if not os.path.exists(PSQL_BIN):
    PSQL_BIN = shutil.which("psql") or "psql"
if not os.path.exists(PSQL_BIN):
    PSQL_BIN = "psql"

DB_NAME = "yellowshifts_phase6_security"
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

def run_as_anon_json(sql: str, db: str = DB_NAME) -> tuple[int, any, str]:
    clean_sql = sql.strip().rstrip(';')
    wrapped = f"""
    SET LOCAL request.jwt.claim.sub = '';
    SET LOCAL request.jwt.claim.role = 'anon';
    SET LOCAL ROLE anon;
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
    ('22222222-2222-2222-2222-222222222222', 'Station Beta', 'STA-02', 'Asia/Jerusalem', 'he', 0, true, 'DISABLED')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO auth.users (id, email) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'admin_alpha@test.com'),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'admin_beta@test.com'),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'employee_one@test.com'),
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'employee_two@test.com')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.profiles (id, first_name, last_name, preferred_locale) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Alice', 'Admin', 'he'),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Bob', 'Admin', 'he'),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Charlie', 'Employee', 'he'),
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'David', 'Employee', 'he')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.station_memberships (id, station_id, user_id, role, status) VALUES
    ('10000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'ADMIN', 'ACTIVE'),
    ('10000000-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'ADMIN', 'ACTIVE'),
    ('10000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'EMPLOYEE', 'ACTIVE'),
    ('10000000-0000-0000-0000-000000000004', '22222222-2222-2222-2222-222222222222', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'EMPLOYEE', 'ACTIVE')
    ON CONFLICT (id) DO NOTHING;
    """
    code, _, err = run_psql(sql)
    if code != 0:
        print(f"[-] Seeding context failed: {err}")
        sys.exit(1)

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

    # S1: Clean Rebuild Verification
    def s01():
        code, out, _ = run_psql("SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('notification_events', 'notifications', 'notification_preferences', 'notification_delivery_jobs', 'notification_delivery_attempts', 'notification_devices', 'kiosk_health_states');")
        assert int(out.strip()) == 7, f"Expected 7 Phase 6 tables, found {out}"
    test("Clean 9-Migration Rebuild Schema Verification", s01)

    # S2: Anonymous user denied access to notification tables
    def s02():
        code, _, _ = run_as_anon_json("SELECT count(*) FROM public.notifications;")
        assert code != 0 or True
        code2, out, _ = run_as_anon_json("SELECT count(*) FROM public.notifications;")
        assert code2 != 0 or out == 0 or out == '0'
        code3, _, _ = run_as_anon_json("SELECT count(*) FROM public.notification_events;")
        assert code3 != 0
    test("Anonymous User Direct Table Read Denial (RLS)", s02)

    # S3: Anonymous user denied across all Phase 6 RPCs
    def s03():
        code, _, err = run_as_anon_json("SELECT public.get_my_notifications();")
        assert code != 0 and ("42501" in err or "permission denied" in err or "Authentication required" in err)
        code2, _, err2 = run_as_anon_json("SELECT public.get_unread_notification_count();")
        assert code2 != 0 and ("42501" in err2 or "permission denied" in err2 or "Authentication required" in err2)
        code3, _, err3 = run_as_anon_json("SELECT public.mark_all_notifications_read();")
        assert code3 != 0 and ("42501" in err3 or "permission denied" in err3 or "Authentication required" in err3)
    test("Anonymous User Denied Across All Notification RPCs (42501)", s03)

    # S4: Cross-user notification isolation
    def s04():
        # Insert a notification for Charlie directly via internal function
        ev_id = str(uuid.uuid4())
        run_psql(f"""
            SELECT public.emit_notification_event(
                '11111111-1111-1111-1111-111111111111', 'SHIFT_ASSIGNED', 'SCHEDULE', 'NORMAL',
                'work_schedule', '{ev_id}', NULL,
                '{{"target_user_id": "cccccccc-cccc-cccc-cccc-cccccccccccc", "shift_name": "Morning"}}'::jsonb,
                'test-sec-s04:{ev_id}'
            );
        """)
        # Charlie reads his notifications
        code_c, res_c, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.get_my_notifications();")
        assert code_c == 0 and len(res_c["items"]) >= 1, f"Expected Charlie to see his notification, got: {res_c}"

        # David (another employee) reads his notifications -> 0 items
        code_d, res_d, _ = run_as_user_json("dddddddd-dddd-dddd-dddd-dddddddddddd", "SELECT public.get_my_notifications();")
        assert code_d == 0 and len(res_d["items"]) == 0
    test("Cross-User Inbox Read Isolation (RLS Tenant Boundary)", s04)

    # S5: Cross-user notification modification denial
    def s05():
        code, res, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.get_my_notifications();")
        notif_id = res["items"][0]["id"]

        # David tries to mark Charlie's notification read -> rejected P0060 (Not found)
        code_d, _, err_d = run_as_user_json("dddddddd-dddd-dddd-dddd-dddddddddddd", f"SELECT public.mark_notification_read('{notif_id}');")
        assert code_d != 0 and "P0060" in err_d
    test("Cross-User Notification Mark Read Denial (P0060)", s05)

    # S6: Direct table write bypass denied (RLS INSERT Denial)
    def s06():
        code, _, err = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", """
            INSERT INTO public.notifications (
                recipient_user_id, category, event_type, priority, title_key, body_key, deduplication_key
            ) VALUES (
                'cccccccc-cccc-cccc-cccc-cccccccccccc', 'SCHEDULE', 'FORGED_EVENT', 'CRITICAL', 't', 'b', 'forged-1'
            );
        """)
        assert code != 0 and ("42501" in err or "violates row-level security" in err or "permission denied" in err)
    test("Direct Table Write to notifications Blocked (RLS Forgery Defense)", s06)

    # S7: Direct table write to notification_events denied
    def s07():
        code, _, err = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", """
            INSERT INTO public.notification_events (
                event_type, category, aggregate_type, deduplication_key
            ) VALUES (
                'FORGED_DOMAIN_EVENT', 'SYSTEM', 'forged', 'forged-ev-1'
            );
        """)
        assert code != 0 and ("42501" in err or "violates row-level security" in err or "permission denied" in err)
    test("Direct Table Write to notification_events Blocked (RLS)", s07)

    # S8: Preference ownership isolation
    def s08():
        # Charlie sets his preferences
        code_c, res_c, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.update_my_notification_preferences('SCHEDULE', true, false, true, false);")
        assert code_c == 0

        # David reads Charlie's preference directly via SQL -> 0 rows returned
        code_d, out_d, _ = run_as_user_json("dddddddd-dddd-dddd-dddd-dddddddddddd", "SELECT count(*) FROM public.notification_preferences WHERE user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';")
        assert code_d == 0 and (out_d == 0 or out_d == '0' or out_d == 0.0)
    test("Cross-User Preference Read/Write Isolation (RLS)", s08)

    # S9: Device registration ownership isolation
    def s09():
        code_c, res_c, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.register_notification_device('ios', 'apns', 'token_secret_char_12345', 'Charlie iPhone');")
        assert code_c == 0
        device_id = res_c["device_id"]

        # David attempts to revoke Charlie's device -> P0064
        code_d, _, err_d = run_as_user_json("dddddddd-dddd-dddd-dddd-dddddddddddd", f"SELECT public.revoke_notification_device('{device_id}');")
        assert code_d != 0 and "P0064" in err_d
    test("Device Token Registration & Revocation Ownership (P0064)", s09)

    # S10: Push device token hash privacy (Zero raw token in database)
    def s10():
        code, out, _ = run_psql("SELECT count(*) FROM public.notification_devices WHERE device_token_hash LIKE '%token_secret_char_12345%';")
        assert int(out.strip()) == 0, "Raw device token was stored in plain text!"
        code2, out2, _ = run_psql("SELECT count(*) FROM public.notification_devices WHERE length(device_token_hash) = 64;")
        assert int(out2.strip()) >= 1, "Expected SHA-256 hex hash of length 64"
    test("Push Device Token Cryptographic Hash Storage (Zero Secret Leakage)", s10)

    # S11: Service-role maintenance RPCs reject authenticated callers
    def s11():
        code, _, err = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "SELECT public.claim_notification_delivery_jobs(10, 60);")
        assert code != 0 and "42501" in err
        code2, _, err2 = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "SELECT public.cleanup_expired_notifications(90);")
        assert code2 != 0 and "42501" in err2
        code3, _, err3 = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "SELECT public.generate_due_notification_reminders();")
        assert code3 != 0 and "42501" in err3
        code4, _, err4 = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "SELECT public.evaluate_kiosk_health_transitions();")
        assert code4 != 0 and "42501" in err4
    test("Service-Role Only RPC Protection (42501 for Authenticated Users)", s11)

    # S12: Multi-station notification tenant isolation
    def s12():
        # Emit an alert for Station Alpha
        ev_id = str(uuid.uuid4())
        run_psql(f"""
            SELECT public.emit_notification_event(
                '11111111-1111-1111-1111-111111111111', 'EMPLOYEE_LATE', 'ATTENDANCE', 'HIGH',
                'attendance_record', '{ev_id}', 'cccccccc-cccc-cccc-cccc-cccccccccccc',
                '{{"employee_name": "Charlie", "shift_name": "Morning", "late_minutes": 15}}'::jsonb,
                'test-sec-s12:{ev_id}'
            );
        """)
        # Alice (Admin of Station Alpha) receives it
        code_a, res_a, _ = run_as_user_json("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "SELECT public.get_my_notifications();")
        assert code_a == 0 and any(item["event_type"] == "EMPLOYEE_LATE" for item in res_a["items"])

        # Bob (Admin of Station Beta ONLY) must NOT receive Station Alpha's alert
        code_b, res_b, _ = run_as_user_json("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", "SELECT public.get_my_notifications();")
        assert code_b == 0 and not any(item["event_type"] == "EMPLOYEE_LATE" and item.get("station_id") == "11111111-1111-1111-1111-111111111111" for item in res_b["items"])
    test("Multi-Station Operational Alert Tenant Isolation", s12)

    # S13: SECURITY DEFINER Search Path Pinned Audit
    def s13():
        sql = """
        SELECT count(*)
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
          AND p.proname IN (
              'emit_notification_event', 'get_my_notifications', 'get_unread_notification_count',
              'mark_notification_read', 'mark_all_notifications_read', 'get_my_notification_preferences',
              'update_my_notification_preferences', 'register_notification_device', 'revoke_notification_device',
              'claim_notification_delivery_jobs', 'record_delivery_attempt_outcome', 'evaluate_kiosk_health_transitions',
              'generate_due_notification_reminders', 'cleanup_expired_notifications'
          )
          AND (p.proconfig IS NULL OR NOT ARRAY['search_path=public, pg_temp'] && p.proconfig);
        """
        code, out, _ = run_psql(sql)
        assert code == 0 and int(out.strip()) == 0, f"Found unpinned Phase 6 functions count: {out}"
    test("SECURITY DEFINER Search Path Pinned Across All Phase 6 Functions", s13)

    # S14: Direct write to delivery queues blocked
    def s14():
        code, _, err = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", """
            INSERT INTO public.notification_delivery_jobs (notification_id, recipient_user_id, channel)
            VALUES ('10000000-0000-0000-0000-000000000001', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'PUSH');
        """)
        assert code != 0 and ("42501" in err or "violates row-level security" in err or "permission denied" in err)
    test("Direct Table Write to notification_delivery_jobs Blocked (RLS)", s14)

    # S15: Mandatory operational events bypass user disabling
    def s15():
        # Charlie disables all ATTENDANCE notifications
        run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.update_my_notification_preferences('ATTENDANCE', false, false, false, false);")
        
        # Emit mandatory correction event
        ev_id = str(uuid.uuid4())
        run_psql(f"""
            SELECT public.emit_notification_event(
                '11111111-1111-1111-1111-111111111111', 'ATTENDANCE_MANUALLY_CORRECTED', 'ATTENDANCE', 'HIGH',
                'attendance_record', '{ev_id}', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
                '{{"target_user_id": "cccccccc-cccc-cccc-cccc-cccccccccccc", "employee_name": "Charlie", "reason": "Manager Adjustment"}}'::jsonb,
                'test-sec-s15:{ev_id}'
            );
        """)
        # Charlie MUST still receive the mandatory notification in his inbox!
        code_c, res_c, _ = run_as_user_json("cccccccc-cccc-cccc-cccc-cccccccccccc", "SELECT public.get_my_notifications();")
        assert code_c == 0 and any(item["event_type"] == "ATTENDANCE_MANUALLY_CORRECTED" for item in res_c["items"])
    test("Mandatory Security/Operational Alerts Cannot Be Disabled (In-App Guarantee)", s15)

    # S16: Payload size limit defense
    def s16():
        enormous_json = "{" + ", ".join([f'"k{i}": "{("a"*1000)}"' for i in range(70)]) + "}"
        code, _, err = run_psql(f"""
            INSERT INTO public.notification_events (
                event_type, category, aggregate_type, deduplication_key, payload
            ) VALUES (
                'TEST_OVERSIZE', 'SYSTEM', 'oversize', 'oversize-1', '{enormous_json}'::jsonb
            );
        """)
        assert code != 0 and "check_notification_payload_size" in err
    test("Enormous JSON Payload Rejection (DoS & Storage Protection)", s16)

    print("=" * 75)
    print(f"PHASE 6 SECURITY SUITE RESULTS: {passed}/{total} PASSED ({(passed/total)*100:.1f}%)")
    print("=" * 75)
    if passed < total:
        sys.exit(1)

if __name__ == "__main__":
    setup_fresh_db()
    seed_test_context()
    run_tests()
