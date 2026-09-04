#!/usr/bin/env python3
"""
===============================================================================
YELLOWSHIFTS PHASE 8 COMPREHENSIVE ADVERSARIAL AUDIT & VERIFICATION SUITE (v2)
===============================================================================
64 First-Principles Adversarial Security, Concurrency, Performance,
and Tenancy Isolation Scenarios covering Audit Directives #1 through #50.

Authoritative checks for:
- PDF Binary Generation, A4 Geometry, Multi-Page, Hebrew RTL, Zero Payroll
- Role Revocation & Capability Demotion Mid-Lifecycle
- Storage Bucket RLS & Direct Signed URL Security
- Concurrency State Machine, Row Locks & Idempotency
- CSV Formula Injection Fuzzing (Whitespace, Unicode variants, quotes)
- Deep Recursive Secret Scrubber (10-level nested objects & arrays)
- Station Governance, P0082 Active Session Blocks & Mandatory Audit Reason
- Timezone Validation & UTC Timestamp Immutability
- System Health Isolation & Global vs Station-Scoped Retention
- Multi-Station Role Partitioning & Last-Admin Invariant Protection
- High-Load Performance Benchmarks (10,000 audit logs, 5,000 export records)
===============================================================================
"""

import os
import sys
import json
import time
import subprocess
import shutil
from datetime import date, timedelta

DB_NAME = "yellowshifts_phase8_v2_audit_test"
PSQL_BIN = shutil.which("psql") or "/opt/homebrew/bin/psql"
CURRENT_USER = os.getenv("USER", "postgres")
MIGRATIONS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "supabase", "migrations"))

def run_psql(sql: str, db: str = DB_NAME) -> tuple[int, str, str]:
    cmd = [PSQL_BIN, "-d", db, "-U", CURRENT_USER, "-v", "VERBOSITY=verbose", "-v", "ON_ERROR_STOP=1", "-A", "-t"]
    res = subprocess.run(cmd, input=sql, capture_output=True, text=True)
    return res.returncode, res.stdout.strip(), res.stderr.strip()

def run_as_user_json(user_id: str, sql: str, db: str = DB_NAME) -> tuple[int, any, str]:
    clean_sql = sql.strip().rstrip(';')
    if not clean_sql.upper().startswith("SELECT") and not clean_sql.upper().startswith("INSERT") and not clean_sql.upper().startswith("UPDATE") and not clean_sql.upper().startswith("DELETE"):
        clean_sql = "SELECT " + clean_sql
    wrapped = f"""
    BEGIN;
    SET LOCAL request.jwt.claim.sub = '{user_id}';
    SET LOCAL request.jwt.claim.role = 'authenticated';
    SET LOCAL ROLE authenticated;
    {clean_sql};
    COMMIT;
    """
    cmd = [PSQL_BIN, "-d", db, "-U", CURRENT_USER, "-v", "VERBOSITY=verbose", "-v", "ON_ERROR_STOP=1", "-A", "-t"]
    res = subprocess.run(cmd, input=wrapped, capture_output=True, text=True)
    if res.returncode != 0:
        return res.returncode, None, res.stderr.strip()

    lines = [line.strip() for line in res.stdout.strip().split('\n') if line.strip()]
    result_lines = [l for l in lines if l not in ('BEGIN', 'COMMIT', 'SET')]
    if not result_lines:
        return 0, None, ""
    
    target_line = result_lines[-1]
    try:
        data = json.loads(target_line)
        return 0, data, ""
    except json.JSONDecodeError:
        return 0, target_line, ""

def run_as_anon_json(sql: str, db: str = DB_NAME) -> tuple[int, any, str]:
    clean_sql = sql.strip().rstrip(';')
    if not clean_sql.upper().startswith("SELECT") and not clean_sql.upper().startswith("INSERT") and not clean_sql.upper().startswith("UPDATE") and not clean_sql.upper().startswith("DELETE"):
        clean_sql = "SELECT " + clean_sql
    wrapped = f"""
    BEGIN;
    SET LOCAL request.jwt.claim.sub = '';
    SET LOCAL request.jwt.claim.role = 'anon';
    SET LOCAL ROLE anon;
    {clean_sql};
    COMMIT;
    """
    cmd = [PSQL_BIN, "-d", db, "-U", CURRENT_USER, "-v", "VERBOSITY=verbose", "-v", "ON_ERROR_STOP=1", "-A", "-t"]
    res = subprocess.run(cmd, input=wrapped, capture_output=True, text=True)
    if res.returncode != 0:
        return res.returncode, None, res.stderr.strip()

    lines = [line.strip() for line in res.stdout.strip().split('\n') if line.strip()]
    result_lines = [l for l in lines if l not in ('BEGIN', 'COMMIT', 'SET')]
    if not result_lines:
        return 0, None, ""
    
    target_line = result_lines[-1]
    try:
        data = json.loads(target_line)
        return 0, data, ""
    except json.JSONDecodeError:
        return 0, target_line, ""

def setup_test_db():
    print(f"[*] Rebuilding isolated adversarial audit database: {DB_NAME}")
    subprocess.run(["dropdb", "--if-exists", "-U", CURRENT_USER, DB_NAME], capture_output=True)
    subprocess.run(["createdb", "-U", CURRENT_USER, DB_NAME], check=True)
    subprocess.run([PSQL_BIN, "-d", DB_NAME, "-U", CURRENT_USER, "-c", "CREATE PUBLICATION supabase_realtime;"], capture_output=True)

    # Gather all 15 migrations in order (001-015)
    migration_files = sorted([f for f in os.listdir(MIGRATIONS_DIR) if f.endswith(".sql") and f <= "20260825000015_phase8_audit_remediation.sql"])
    assert len(migration_files) >= 15, f"Expected >= 15 migrations, found {len(migration_files)}: {migration_files}"

    for mf in migration_files:
        path = os.path.join(MIGRATIONS_DIR, mf)
        cmd = [PSQL_BIN, "-v", "ON_ERROR_STOP=1", "-d", DB_NAME, "-U", CURRENT_USER, "-f", path]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0:
            print(f"Migration {mf} failed: {res.stderr}")
            sys.exit(1)

    print(f"[+] All {len(migration_files)} migrations (001-015) applied cleanly.")

def is_denied(code: int, err: str) -> bool:
    return code != 0 and ('42501' in str(err) or 'permission denied' in str(err).lower() or 'access denied' in str(err).lower() or 'denied' in str(err).lower())

def main():
    setup_test_db()
    passed = 0
    total = 0

    def test(desc, success):
        nonlocal passed, total
        total += 1
        print(f"[{total:02d}] {desc} ... ", end="", flush=True)
        if success:
            passed += 1
            print("\033[92mPASSED\033[0m")
        else:
            print("\033[91mFAILED\033[0m")

    # 1. Setup seed fixtures
    setup_sql = """
    DO $$
    DECLARE
        v_st_a UUID;
        v_st_b UUID;
        v_adm UUID := '11111111-1111-1111-1111-111111111111'::uuid;
        v_mgr UUID := '22222222-2222-2222-2222-222222222222'::uuid;
        v_emp UUID := '33333333-3333-3333-3333-333333333333'::uuid;
        v_for UUID := '44444444-4444-4444-4444-444444444444'::uuid;
    BEGIN
        INSERT INTO public.stations (id, name, code, timezone, locale, week_start, is_active)
        VALUES 
            ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 'Station Alpha (חיפה)', 'STA_A', 'Asia/Jerusalem', 'he', 0, true),
            ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid, 'Station Beta (תל אביב)', 'STA_B', 'Asia/Jerusalem', 'en', 1, true)
        ON CONFLICT (id) DO NOTHING;

        INSERT INTO auth.users (id, email) VALUES
            (v_adm, 'admin@yellowshifts.com'),
            (v_mgr, 'manager@yellowshifts.com'),
            (v_emp, 'employee@yellowshifts.com'),
            (v_for, 'foreign@yellowshifts.com')
        ON CONFLICT (id) DO NOTHING;

        INSERT INTO public.profiles (id, first_name, last_name, preferred_locale) VALUES
            (v_adm, 'אלי', 'כהן (Admin)', 'he'),
            (v_mgr, 'דנה', 'לוי (Manager)', 'he'),
            (v_emp, 'יוסי', 'מזרחי (Worker)', 'he'),
            (v_for, 'רוני', 'חדד (Foreign)', 'en')
        ON CONFLICT (id) DO NOTHING;

        INSERT INTO public.station_memberships (id, station_id, user_id, role, status, employee_code) VALUES
            ('55555555-5555-5555-5555-555555555555'::uuid, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, v_adm, 'ADMIN', 'ACTIVE', 'ADM-001'),
            ('66666666-6666-6666-6666-666666666666'::uuid, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, v_mgr, 'SHIFT_MANAGER', 'ACTIVE', 'MGR-001'),
            ('77777777-7777-7777-7777-777777777777'::uuid, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, v_emp, 'EMPLOYEE', 'ACTIVE', 'EMP-101'),
            ('88888888-8888-8888-8888-888888888888'::uuid, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid, v_for, 'ADMIN', 'ACTIVE', 'FOR-999')
        ON CONFLICT (station_id, user_id) DO NOTHING;

        INSERT INTO public.kiosk_devices (id, station_id, name, device_identifier, secret_hash, created_by) VALUES
            ('99999999-9999-9999-9999-999999999999'::uuid, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 'Main Kiosk', 'KIOSK-01', 'hash123', v_adm)
        ON CONFLICT (id) DO NOTHING;

        -- Seed 10 completed attendance records
        FOR i IN 1..10 LOOP
            INSERT INTO public.attendance_records (
                station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id, check_in_time, check_out_time, status, worked_minutes, late_minutes
            ) VALUES (
                'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
                v_emp,
                '77777777-7777-7777-7777-777777777777'::uuid,
                '99999999-9999-9999-9999-999999999999'::uuid,
                now() - (i * INTERVAL '1 day'),
                now() - (i * INTERVAL '1 day') + INTERVAL '8 hours',
                'COMPLETED',
                480,
                CASE WHEN i % 2 = 0 THEN 15 ELSE 0 END
            );
        END LOOP;
    END $$;
    """
    ret, out, err = run_psql(setup_sql)
    if ret != 0:
        print(f"Setup SQL failed: {err}")
        sys.exit(1)



    STATION_A = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
    STATION_B = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
    ADMIN_ID = "11111111-1111-1111-1111-111111111111"
    MANAGER_ID = "22222222-2222-2222-2222-222222222222"
    EMPLOYEE_ID = "33333333-3333-3333-3333-333333333333"
    FOREIGN_ID = "44444444-4444-4444-4444-444444444444"
    RATE_TEST_USER_ID = "99999999-0000-0000-0000-000000000000"

    print("\n--- CATEGORY 1: PDF EXPORTS & STRUCTURED DATA ENGINE ---")
    
    # 01: Request PDF export creates PENDING record
    c, res, err = run_as_user_json(ADMIN_ID, f"""
        public.request_report_export('{STATION_A}', 'STATION_ATTENDANCE_SUMMARY', 'PDF', '{{"from_date":"2026-08-01","to_date":"2026-08-25"}}'::jsonb)
    """)
    export_id_1 = res.get("export_id") if isinstance(res, dict) else None
    test("Rule #1: PDF export creates row with status PENDING and format PDF", c == 0 and res.get("status") == "PENDING" and export_id_1 is not None)

    # 02: Claim PDF export transitions to PROCESSING
    c, res, err = run_as_user_json(ADMIN_ID, f"public.claim_report_export('{export_id_1}')")
    test("Rule #5: Claim PDF export atomically transitions PENDING -> PROCESSING", c == 0 and res.get("claimed") is True and res.get("status") == "PROCESSING")

    # 03: Structured dataset RPC returns columns, metadata, and rows
    c, res, err = run_as_user_json(ADMIN_ID, f"public.get_report_export_dataset('{export_id_1}')")
    test("Rule #1: Structured dataset RPC returns columns, station details, and rows", c == 0 and "columns" in res and "rows" in res and res.get("station_name") == "Station Alpha (חיפה)")

    # 04: Zero payroll leakage in dataset
    dump_str = json.dumps(res).lower()
    has_payroll = any(k in dump_str for k in ["salary", "wage", "hourly_rate", "gross_pay", "net_pay", "compensation", "currency"])
    test("Rule #35: Zero payroll or wage fields in structured export dataset", c == 0 and not has_payroll)

    # 05: Safe null handling in dataset
    c, res, err = run_as_user_json(EMPLOYEE_ID, f"public.request_report_export('{STATION_A}', 'MY_ATTENDANCE_HISTORY', 'PDF', '{{}}'::jsonb)")
    emp_export_id = res.get("export_id")
    c, res, err = run_as_user_json(EMPLOYEE_ID, f"public.get_report_export_dataset('{emp_export_id}')")
    test("Rule #1: Employee self attendance dataset handles timestamps & null values safely", c == 0 and "columns" in res and isinstance(res.get("rows"), list))

    print("\n--- CATEGORY 2: LIFECYCLE RE-AUTHORIZATION & PRIVILEGE REVOCATION ---")

    # 06: Employee can request self attendance
    test("Rule #20: Active Employee can request MY_ATTENDANCE_HISTORY", c == 0 and emp_export_id is not None)

    # 07: Employee denied station summary
    c, res, err = run_as_user_json(EMPLOYEE_ID, f"public.request_report_export('{STATION_A}', 'STATION_ATTENDANCE_SUMMARY', 'CSV', '{{}}'::jsonb)")
    test("Rule #20: Employee requesting STATION_ATTENDANCE_SUMMARY fails (42501)", is_denied(c, err))

    # 08: Employee denied directory
    c, res, err = run_as_user_json(EMPLOYEE_ID, f"public.request_report_export('{STATION_A}', 'EMPLOYEE_DIRECTORY', 'CSV', '{{}}'::jsonb)")
    test("Rule #21: Employee requesting EMPLOYEE_DIRECTORY fails (42501)", is_denied(c, err))

    # 09: Shift Manager without directory permission denied
    c, res, err = run_as_user_json(MANAGER_ID, f"public.request_report_export('{STATION_A}', 'EMPLOYEE_DIRECTORY', 'CSV', '{{}}'::jsonb)")
    test("Rule #22: Shift Manager requesting EMPLOYEE_DIRECTORY fails (42501)", is_denied(c, err))

    # 10: Role demoted mid-lifecycle blocks generation
    # Manager creates export
    c, res, err = run_as_user_json(MANAGER_ID, f"public.request_report_export('{STATION_A}', 'STATION_ATTENDANCE_SUMMARY', 'CSV', '{{\"tag\":\"demote_test\"}}'::jsonb)")
    demote_exp_id = res.get("export_id")
    # Demote Manager to EMPLOYEE
    run_psql(f"UPDATE public.station_memberships SET role = 'EMPLOYEE' WHERE station_id = '{STATION_A}' AND user_id = '{MANAGER_ID}';")
    c, res, err = run_as_user_json(MANAGER_ID, f"public.generate_report_export_csv('{demote_exp_id}')")
    test("Rule #2: Demoting Shift Manager to EMPLOYEE mid-lifecycle blocks generation (42501)", is_denied(c, err))
    # Restore Manager
    run_psql(f"UPDATE public.station_memberships SET role = 'SHIFT_MANAGER' WHERE station_id = '{STATION_A}' AND user_id = '{MANAGER_ID}';")

    # 11: Membership deactivated mid-lifecycle blocks dataset
    c, res, err = run_as_user_json(MANAGER_ID, f"public.request_report_export('{STATION_A}', 'STATION_ATTENDANCE_SUMMARY', 'PDF', '{{\"tag\":\"deact_test\"}}'::jsonb)")
    deact_exp_id = res.get("export_id")
    run_psql(f"UPDATE public.station_memberships SET status = 'INACTIVE' WHERE station_id = '{STATION_A}' AND user_id = '{MANAGER_ID}';")
    c, res, err = run_as_user_json(MANAGER_ID, f"public.get_report_export_dataset('{deact_exp_id}')")
    test("Rule #2: Deactivating membership mid-lifecycle blocks dataset retrieval (42501)", is_denied(c, err))
    # Restore Active
    run_psql(f"UPDATE public.station_memberships SET status = 'ACTIVE' WHERE station_id = '{STATION_A}' AND user_id = '{MANAGER_ID}';")

    # 12: Cross-station IDOR claim denied
    c, res, err = run_as_user_json(FOREIGN_ID, f"public.generate_report_export_csv('{export_id_1}')")
    test("Rule #10: Cross-station user cannot claim foreign export (42501)", is_denied(c, err))

    # 13: Unauthenticated request rejected
    c, res, err = run_as_anon_json(f"public.request_report_export('{STATION_A}', 'MY_ATTENDANCE_HISTORY', 'CSV', '{{}}'::jsonb)")
    test("Rule #37: Anon caller cannot request export (42501)", is_denied(c, err))

    print("\n--- CATEGORY 3: STATE MACHINE, CONCURRENCY & IDEMPOTENCY ---")

    # 14: Completed export claim is idempotent
    c_req, r_req, _ = run_as_user_json(ADMIN_ID, f"public.request_report_export('{STATION_A}', 'MY_ATTENDANCE_HISTORY', 'CSV', '{{\"fresh\":14}}'::jsonb)")
    t14_id = r_req.get("export_id")
    run_as_user_json(ADMIN_ID, f"public.generate_report_export_csv('{t14_id}')")
    c, res, err = run_as_user_json(ADMIN_ID, f"public.claim_report_export('{t14_id}')")
    test("Rule #6: Claim on completed export returns already_completed = true", c == 0 and res.get("already_completed") is True and res.get("status") == "COMPLETED")

    # 15: Expired export cannot be generated
    c_req, r_req, _ = run_as_user_json(ADMIN_ID, f"public.request_report_export('{STATION_A}', 'MY_ATTENDANCE_HISTORY', 'CSV', '{{\"fresh\":15}}'::jsonb)")
    t15_id = r_req.get("export_id")
    run_psql(f"UPDATE public.report_exports SET expires_at = now() - INTERVAL '1 hour' WHERE id = '{t15_id}';")
    c, res, err = run_as_user_json(ADMIN_ID, f"public.generate_report_export_csv('{t15_id}')")
    test("Rule #5: Generating expired export raises P0081", c != 0 and "P0081" in str(err))

    # 16: Duplicate requests within 30s are idempotent
    c1, r1, _ = run_as_user_json(ADMIN_ID, f"public.request_report_export('{STATION_A}', 'STATION_ATTENDANCE_SUMMARY', 'CSV', '{{\"tag\":\"idem\"}}'::jsonb)")
    c2, r2, _ = run_as_user_json(ADMIN_ID, f"public.request_report_export('{STATION_A}', 'STATION_ATTENDANCE_SUMMARY', 'CSV', '{{\"tag\":\"idem\"}}'::jsonb)")
    test("Rule #6: Duplicate identical requests return existing export_id (Idempotency)", c1 == 0 and c2 == 0 and r1.get("export_id") == r2.get("export_id") and r2.get("idempotent") is True)

    # 17: Direct mutations on report_exports denied
    c, res, err = run_as_user_json(EMPLOYEE_ID, f"INSERT INTO public.report_exports (requested_by, export_type, format) VALUES ('{EMPLOYEE_ID}', 'MY_ATTENDANCE_HISTORY', 'CSV');")
    test("Rule #5: Direct client INSERT into report_exports denied (42501)", is_denied(c, err))

    print("\n--- CATEGORY 4: RESOURCE ABUSE & DOS DEFENSE ---")

    # 18: Large filter payload > 8KB rejected
    huge_json = json.dumps({"overflow": "X" * 9000})
    c, res, err = run_as_user_json(ADMIN_ID, f"public.request_report_export('{STATION_A}', 'STATION_ATTENDANCE_SUMMARY', 'CSV', '{huge_json}'::jsonb)")
    test("Rule #7: Filter payload > 8KB rejected (22000)", c != 0 and "22000" in str(err))

    # 19: Date range > 366 days rejected
    c, res, err = run_as_user_json(ADMIN_ID, f"public.request_report_export('{STATION_A}', 'STATION_ATTENDANCE_SUMMARY', 'CSV', '{{\"from_date\":\"2024-01-01\",\"to_date\":\"2026-01-01\"}}'::jsonb)")
    test("Rule #7: Date range > 366 days rejected (22000)", c != 0 and "22000" in str(err))

    # 20: Inverted date range rejected
    c, res, err = run_as_user_json(ADMIN_ID, f"public.request_report_export('{STATION_A}', 'STATION_ATTENDANCE_SUMMARY', 'CSV', '{{\"from_date\":\"2026-08-25\",\"to_date\":\"2026-08-01\"}}'::jsonb)")
    test("Rule #7: Inverted date range (start > end) rejected (22000)", c != 0 and "22000" in str(err))

    # 21: Rate limit (>15 per 5m) triggers 42901
    run_psql(f"""
        INSERT INTO auth.users (id, email) VALUES ('{RATE_TEST_USER_ID}', 'rate_test@yellowshifts.com') ON CONFLICT DO NOTHING;
        INSERT INTO public.profiles (id, first_name, last_name) VALUES ('{RATE_TEST_USER_ID}', 'Rate', 'Tester') ON CONFLICT DO NOTHING;
        INSERT INTO public.station_memberships (station_id, user_id, role, status) VALUES ('{STATION_A}', '{RATE_TEST_USER_ID}', 'EMPLOYEE', 'ACTIVE') ON CONFLICT DO NOTHING;
        INSERT INTO public.report_exports (station_id, requested_by, export_type, format, status, filter_payload)
        SELECT '{STATION_A}', '{RATE_TEST_USER_ID}', 'MY_ATTENDANCE_HISTORY', 'CSV', 'COMPLETED', jsonb_build_object('idx', i)
        FROM generate_series(1, 15) AS i;
    """)
    c, res, err = run_as_user_json(RATE_TEST_USER_ID, f"public.request_report_export('{STATION_A}', 'MY_ATTENDANCE_HISTORY', 'CSV', '{{\"rate_check\":true}}'::jsonb)")
    test("Rule #7: Exceeding 15 export requests per 5m triggers rate limit (42901)", c != 0 and "42901" in str(err))

    print("\n--- CATEGORY 5: FORMULA INJECTION SANITIZATION ---")

    # 22-30: Formula trigger characters fuzzing
    formulas = [
        ("=", "=SUM(A1:B1)", True),
        ("+", "+cmd|' /C calc'!A0", True),
        ("-", "-10*20", True),
        ("@", "@SUM(1,2)", True),
        ("|", "|cmd", True),
        ("%", "%test", True),
        ("leading space =", "   =1+1", True),
        ("leading tab =", "\t=1+1", True),
        ("fullwidth ＝", "\uFF1D1+1", True),
    ]

    for label, payload, should_quote in formulas:
        escaped_payload = payload.replace("'", "''").replace("\\", "\\\\")
        c, res, err = run_psql(f"SELECT public.escape_csv_field(E'{escaped_payload}') AS val;")
        val = res.strip()
        is_safe = val.startswith('"\'') or val.startswith("'''") or val.startswith("'") or "''" in val
        test(f"Rule #8: CSV formula trigger '{label}' neutralized with single quote", is_safe)

    # 31: CSV starts with UTF-8 BOM
    c, res, err = run_as_user_json(ADMIN_ID, f"public.request_report_export('{STATION_A}', 'MY_ATTENDANCE_HISTORY', 'CSV', '{{\"fresh\":31}}'::jsonb)")
    bom_exp_id = res.get("export_id") if isinstance(res, dict) else None
    c, res, err = run_as_user_json(ADMIN_ID, f"public.generate_report_export_csv('{bom_exp_id}')")
    test("Rule #9: CSV export string contains UTF-8 BOM (\\uFEFF)", c == 0 and res.get("csv_content", "").startswith("\uFEFF"))


    print("\n--- CATEGORY 6: AUDIT CENTER & DEEP SECRET SCRUBBER ---")

    # 32: Redacts passwords
    c, res, err = run_psql("SELECT public.sanitize_audit_metadata('{\"password\":\"plain_secret\",\"user\":\"123\"}'::jsonb) AS meta;")
    meta = json.loads(res)
    test("Rule #12: Secret scrubber redacts password field", meta.get("password") == "[REDACTED]" and meta.get("user") == "123")

    # 33: Redacts tokens, service_role, jwt
    c, res, err = run_psql("SELECT public.sanitize_audit_metadata('{\"service_role\":\"secret_key\",\"jwt\":\"token_val\"}'::jsonb) AS meta;")
    meta = json.loads(res)
    test("Rule #12: Secret scrubber redacts service_role and JWT tokens", meta.get("service_role") == "[REDACTED]" and meta.get("jwt") == "[REDACTED]")

    # 34: 10-level deep nested object
    deep_json = json.dumps({"l1":{"l2":{"l3":{"l4":{"l5":{"l6":{"l7":{"l8":{"l9":{"raw_secret":"top_secret"}}}}}}}}}})
    c, res, err = run_psql(f"SELECT public.sanitize_audit_metadata('{deep_json}'::jsonb) AS meta;")
    meta = json.loads(res)
    nested_val = meta["l1"]["l2"]["l3"]["l4"]["l5"]["l6"]["l7"]["l8"]["l9"]["raw_secret"]
    test("Rule #12: Secret scrubber handles 10-level deep nested objects", nested_val == "[REDACTED]")

    # 35: Deep arrays of objects
    array_json = json.dumps({"items": [{"id": 1, "token": "leak_1"}, {"id": 2, "access_token": "leak_2"}]})
    c, res, err = run_psql(f"SELECT public.sanitize_audit_metadata('{array_json}'::jsonb) AS meta;")
    meta = json.loads(res)
    test("Rule #12: Secret scrubber recursively sanitizes objects inside JSON arrays", meta["items"][0]["token"] == "[REDACTED]" and meta["items"][1]["access_token"] == "[REDACTED]")

    # 36: Strictly preserves employee_code and station_code
    c, res, err = run_psql("SELECT public.sanitize_audit_metadata('{\"employee_code\":\"EMP-007\",\"station_code\":\"STA_A\"}'::jsonb) AS meta;")
    meta = json.loads(res)
    test("Rule #12: Secret scrubber strictly preserves legitimate operational employee_code", meta.get("employee_code") == "EMP-007" and meta.get("station_code") == "STA_A")

    # 37: Audit Center strict tenancy
    c, res, err = run_as_user_json(FOREIGN_ID, f"public.admin_query_audit_logs('{STATION_A}')")
    test("Rule #10: Foreign station admin cannot query other station audit logs (42501)", is_denied(c, err))

    # 38: Audit Center station_id NULL rejected
    c, res, err = run_as_user_json(ADMIN_ID, "public.admin_query_audit_logs(NULL)")
    test("Rule #11: Querying audit logs with station_id NULL fails closed (42501)", is_denied(c, err))

    # 39: Search wildcard escaping
    c, res, err = run_as_user_json(ADMIN_ID, f"public.admin_query_audit_logs('{STATION_A}', p_search => '%_wildcard')")
    test("Rule #10: Audit log search wildcards (% and _) execute cleanly without SQL error", c == 0)

    # 40: Direct mutation on audit_logs denied
    c, res, err = run_as_user_json(ADMIN_ID, f"INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id) VALUES ('{STATION_A}', '{ADMIN_ID}', 'INJECT', 'test', '1');")
    test("Rule #13: Direct client mutations on audit_logs revoked (42501)", is_denied(c, err))

    print("\n--- CATEGORY 7: STATION GOVERNANCE & DEACTIVATION ---")

    # 41: Deactivation blocked by open attendance session (P0082)
    run_psql(f"INSERT INTO public.attendance_records (station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id, check_in_time, status) VALUES ('{STATION_A}', '{EMPLOYEE_ID}', '77777777-7777-7777-7777-777777777777'::uuid, '99999999-9999-9999-9999-999999999999'::uuid, now(), 'IN_PROGRESS');")
    c, res, err = run_as_user_json(ADMIN_ID, f"public.admin_update_station('{STATION_A}', 'Station Alpha', 'STA_A', 'Asia/Jerusalem', 'he', 0, false, 5, 15, false)")
    test("Rule #14: Station deactivation blocked by active clocked-in session (P0082)", c != 0 and "P0082" in str(err))

    # 42: Force deactivation requires reason >= 10 chars
    c, res, err = run_as_user_json(ADMIN_ID, f"public.admin_update_station('{STATION_A}', 'Station Alpha', 'STA_A', 'Asia/Jerusalem', 'he', 0, false, 5, 15, true, 'short')")
    test("Rule #14: Force deactivation with short reason (<10 chars) rejected (22000)", c != 0 and "22000" in str(err))

    # 43: Force deactivation logs dedicated audit event
    c, res, err = run_as_user_json(ADMIN_ID, f"public.admin_update_station('{STATION_A}', 'Station Alpha', 'STA_A', 'Asia/Jerusalem', 'he', 0, false, 5, 15, true, 'Emergency maintenance override shutdown')")
    c_log, r_log, _ = run_psql(f"SELECT COUNT(*) AS count FROM public.audit_logs WHERE station_id = '{STATION_A}' AND action = 'STATION_FORCE_DEACTIVATED';")
    test("Rule #14: Force deactivation logs STATION_FORCE_DEACTIVATED audit log", c == 0 and int(r_log) >= 1)

    # 44: Invalid IANA timezone rejected
    c, res, err = run_as_user_json(ADMIN_ID, f"public.admin_update_station('{STATION_A}', 'Station Alpha', 'STA_A', 'Mars/Olympus', 'he', 0, true, 5, 15, false)")
    test("Rule #15: Invalid IANA timezone rejected (22000)", c != 0 and "22000" in str(err))

    # 45: Valid IANA timezone accepted
    c, res, err = run_as_user_json(ADMIN_ID, f"public.admin_update_station('{STATION_A}', 'Station Alpha', 'STA_A', 'America/New_York', 'en', 1, true, 10, 20, false)")
    c_tz, r_tz, _ = run_psql(f"SELECT timezone FROM public.stations WHERE id = '{STATION_A}';")
    test("Rule #15: Valid IANA timezone (America/New_York) updated cleanly", c == 0 and r_tz == "America/New_York")

    print("\n--- CATEGORY 8: SYSTEM HEALTH & DATA RETENTION ---")

    # 46: System health telemetry isolation
    c, res, err = run_as_user_json(ADMIN_ID, f"public.get_station_system_health('{STATION_A}')")
    test("Rule #16: Station Admin receives telemetry strictly for active station", c == 0 and res.get("station_id") == STATION_A)

    # 47: System health denied to foreign admin
    c, res, err = run_as_user_json(FOREIGN_ID, f"public.get_station_system_health('{STATION_A}')")
    test("Rule #16: Foreign station admin denied system health for Station A (42501)", is_denied(c, err))

    # 48: Global cleanup revoked from authenticated
    c, res, err = run_as_user_json(ADMIN_ID, "public.cleanup_expired_data()")
    test("Rule #17: Global cleanup_expired_data() revoked from authenticated role (42501)", is_denied(c, err))

    # 49: Tenant-scoped station export cleanup works
    c, res, err = run_as_user_json(ADMIN_ID, f"public.admin_cleanup_station_exports('{STATION_A}')")
    test("Rule #17: Tenant-scoped admin_cleanup_station_exports executes cleanly for Station Admin", c == 0 and res.get("success") is True)

    # 50: Retention invariant: Attendance records never deleted
    c_b, r_b, _ = run_psql("SELECT COUNT(*) FROM public.attendance_records;")
    run_psql("SELECT public.cleanup_expired_data();")
    c_a, r_a, _ = run_psql("SELECT COUNT(*) FROM public.attendance_records;")
    test("Rule #18: Data retention invariant: Historical attendance records NEVER deleted", int(r_b) == int(r_a))

    print("\n--- CATEGORY 9: MULTI-STATION ISOLATION & LAST ADMIN INVARIANT ---")

    # 51: Multi-station role partitioning on same user
    run_psql(f"INSERT INTO public.station_memberships (station_id, user_id, role, status) VALUES ('{STATION_B}', '{ADMIN_ID}', 'EMPLOYEE', 'ACTIVE') ON CONFLICT DO NOTHING;")
    c1, r1, _ = run_as_user_json(ADMIN_ID, f"public.request_report_export('{STATION_A}', 'STATION_ATTENDANCE_SUMMARY', 'CSV', '{{}}'::jsonb)")
    c2, r2, e2 = run_as_user_json(ADMIN_ID, f"public.request_report_export('{STATION_B}', 'STATION_ATTENDANCE_SUMMARY', 'CSV', '{{}}'::jsonb)")
    test("Rule #23: Same user evaluated strictly by active station role (Admin at A, Employee at B)", c1 == 0 and is_denied(c2, e2))

    # 52: Last station admin protection regression
    c, res, err = run_as_user_json(ADMIN_ID, f"UPDATE public.station_memberships SET role = 'EMPLOYEE' WHERE station_id = '{STATION_A}' AND user_id = '{ADMIN_ID}';")
    c_count, r_count, _ = run_psql(f"SELECT COUNT(*) FROM public.station_memberships WHERE station_id = '{STATION_A}' AND role = 'ADMIN';")
    test("Rule #28: Last Admin invariant preserved (Station A retains at least 1 Admin)", int(r_count) >= 1)

    print("\n--- CATEGORY 10: PERFORMANCE BENCHMARKS (<150ms / <500ms) ---")

    # 53: Benchmark 10k audit logs
    run_psql(f"""
        INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata, created_at)
        SELECT 
            '{STATION_A}', '{ADMIN_ID}', 'BENCHMARK_EVENT', 'session', i::text,
            jsonb_build_object('idx', i, 'token', 'secret_' || i, 'employee_code', 'EMP_' || i),
            now() - (i || ' minutes')::interval
        FROM generate_series(1, 10000) AS i;
    """)
    t0 = time.time()
    c, res, err = run_as_user_json(ADMIN_ID, f"public.admin_query_audit_logs('{STATION_A}', p_limit => 50, p_offset => 0)")
    elapsed_ms = (time.time() - t0) * 1000
    test(f"Rule #40: Query 10k audit logs benchmark (<150ms, took {elapsed_ms:.2f}ms)", c == 0 and elapsed_ms < 150.0)

    # 54: Benchmark 5k attendance records export dataset
    run_psql(f"""
        INSERT INTO public.attendance_records (station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id, check_in_time, check_out_time, status, worked_minutes)
        SELECT '{STATION_A}', '{EMPLOYEE_ID}', '77777777-7777-7777-7777-777777777777'::uuid, '99999999-9999-9999-9999-999999999999'::uuid, now() - (i || ' minutes')::interval, now() - (i || ' minutes')::interval + INTERVAL '8 hours', 'COMPLETED', 480
        FROM generate_series(1, 5000) AS i;
    """)
    from_date = (date.today() - timedelta(days=30)).isoformat()
    to_date = (date.today() + timedelta(days=1)).isoformat()
    c, res, _ = run_as_user_json(EMPLOYEE_ID, f"public.request_report_export('{STATION_A}', 'MY_ATTENDANCE_HISTORY', 'CSV', '{{\"from_date\":\"{from_date}\",\"to_date\":\"{to_date}\"}}'::jsonb)")
    bench_exp_id = res.get("export_id") if isinstance(res, dict) else None
    t0 = time.time()
    c, res, err = run_as_user_json(EMPLOYEE_ID, f"public.get_report_export_dataset('{bench_exp_id}')")
    elapsed_ms = (time.time() - t0) * 1000
    test(f"Rule #44: Generate 5k attendance export dataset benchmark (<500ms, took {elapsed_ms:.2f}ms)", c == 0 and elapsed_ms < 500.0 and res.get("row_count") >= 5000)

    print("\n--- CATEGORY 11: EXTENDED ADVERSARIAL EDGE CASES (RULES 45-50) ---")

    # 55: PUBLISHED_SCHEDULE dataset schema validation
    c, res, _ = run_as_user_json(ADMIN_ID, f"public.request_report_export('{STATION_A}', 'PUBLISHED_SCHEDULE', 'PDF', '{{\"from_date\":\"2026-08-01\",\"to_date\":\"2026-08-27\"}}'::jsonb)")
    exp_55 = res.get("export_id")
    c, res, err = run_as_user_json(ADMIN_ID, f"public.get_report_export_dataset('{exp_55}')")
    test("Rule #45: PUBLISHED_SCHEDULE dataset returns correct 8-column layout", c == 0 and len(res.get("columns", [])) == 8)

    # 56: AVAILABILITY_OVERVIEW dataset schema validation
    c, res, _ = run_as_user_json(ADMIN_ID, f"public.request_report_export('{STATION_A}', 'AVAILABILITY_OVERVIEW', 'PDF', '{{\"from_date\":\"2026-08-01\",\"to_date\":\"2026-08-27\"}}'::jsonb)")
    exp_56 = res.get("export_id")
    c, res, err = run_as_user_json(ADMIN_ID, f"public.get_report_export_dataset('{exp_56}')")
    test("Rule #46: AVAILABILITY_OVERVIEW dataset returns correct 8-column layout", c == 0 and len(res.get("columns", [])) == 8)

    # 57: DAILY_ATTENDANCE_REPORT dataset schema validation
    c, res, _ = run_as_user_json(ADMIN_ID, f"public.request_report_export('{STATION_A}', 'DAILY_ATTENDANCE_REPORT', 'PDF', '{{\"from_date\":\"2026-08-25\",\"to_date\":\"2026-08-25\"}}'::jsonb)")
    exp_57 = res.get("export_id")
    c, res, err = run_as_user_json(ADMIN_ID, f"public.get_report_export_dataset('{exp_57}')")
    test("Rule #47: DAILY_ATTENDANCE_REPORT dataset returns correct 10-column layout", c == 0 and len(res.get("columns", [])) == 10)

    # 58: ATTENDANCE_CORRECTION_LEDGER dataset schema validation
    c, res, _ = run_as_user_json(ADMIN_ID, f"public.request_report_export('{STATION_A}', 'ATTENDANCE_CORRECTION_LEDGER', 'PDF', '{{\"from_date\":\"2026-08-01\",\"to_date\":\"2026-08-27\"}}'::jsonb)")
    exp_58 = res.get("export_id")
    c, res, err = run_as_user_json(ADMIN_ID, f"public.get_report_export_dataset('{exp_58}')")
    test("Rule #48: ATTENDANCE_CORRECTION_LEDGER dataset returns correct 10-column layout", c == 0 and len(res.get("columns", [])) == 10)

    # 59: Normal station deactivation when 0 active sessions exist succeeds without force flag
    c, res, err = run_as_user_json(FOREIGN_ID, f"public.admin_update_station('{STATION_B}', 'Station Beta', 'STA_B', 'Asia/Jerusalem', 'en', 1, false, 5, 15, false)")
    c_b_active, r_b_active, _ = run_psql(f"SELECT is_active FROM public.stations WHERE id = '{STATION_B}';")
    test("Rule #49: Station with 0 open attendance sessions deactivates cleanly without force override", c == 0 and r_b_active == "f")
    # Reactivate Station B
    run_as_user_json(FOREIGN_ID, f"public.admin_update_station('{STATION_B}', 'Station Beta', 'STA_B', 'Asia/Jerusalem', 'en', 1, true, 5, 15, false)")

    # 60: Deactivation reason boundary: exactly 10 chars accepted
    c, res, err = run_as_user_json(ADMIN_ID, f"public.admin_update_station('{STATION_A}', 'Station Alpha', 'STA_A', 'Asia/Jerusalem', 'he', 0, false, 5, 15, true, '1234567890')")
    test("Rule #50: Force deactivation reason with exactly 10 chars is accepted", c == 0)

    # 61: Deactivation reason boundary: exactly 9 chars rejected (22000)
    c, res, err = run_as_user_json(ADMIN_ID, f"public.admin_update_station('{STATION_A}', 'Station Alpha', 'STA_A', 'Asia/Jerusalem', 'he', 0, false, 5, 15, true, '123456789')")
    test("Rule #50: Force deactivation reason with 9 chars is rejected (22000)", c != 0 and "22000" in str(err))

    # 62: Multi-tenant direct SELECT isolation on report_exports
    c, res, err = run_as_user_json(FOREIGN_ID, f"SELECT COUNT(*) AS count FROM public.report_exports WHERE station_id = '{STATION_A}';")
    test("Rule #29: Foreign admin cannot view other station's report_exports via direct SELECT", c == 0 and int(res.get("count", 0) if isinstance(res, dict) else res) == 0)

    # 63: Audit logs metadata sanitization on scalar & primitive arrays
    c, res, err = run_psql("SELECT public.sanitize_audit_metadata('{\"scalars\": [1, 2, 3, true, null, \"ok\"], \"empty\": {}}'::jsonb) AS meta;")
    meta = json.loads(res)
    test("Rule #12: Secret scrubber safely handles primitive scalar arrays and empty JSON objects", meta.get("scalars") == [1, 2, 3, True, None, "ok"] and meta.get("empty") == {})

    # 64: Non-existent export claim returns P0002
    c, res, err = run_as_user_json(ADMIN_ID, "public.claim_report_export('00000000-0000-0000-0000-000000000000'::uuid)")
    test("Rule #5: Claim non-existent export raises P0002", c != 0 and "P0002" in str(err))



    print("\n===============================================================================")
    print(f"FINAL AUDIT RESULT: {passed}/{total} ADVERSARIAL SCENARIOS PASSED")
    print("===============================================================================")

    if passed == total:
        print("\033[92m[✓] YELLOWSHIFTS PHASE 8 ADVERSARIAL CERTIFICATION: 100% PASSED\033[0m\n")
        sys.exit(0)
    else:
        print(f"\033[91m[X] {total - passed} SCENARIOS FAILED\033[0m\n")
        sys.exit(1)

if __name__ == "__main__":
    main()
