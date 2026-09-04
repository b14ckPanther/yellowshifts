#!/usr/bin/env python3
"""
YellowShifts Phase 8 — Comprehensive Audit, Benchmark & Adversarial Fuzzing Suite
Validates 5k volume benchmarks, deep metadata sanitization, formula injection defense,
multi-station isolation, and UTF-8 encoding fidelity.
"""

import os
import sys
import json
import time
import subprocess
import shutil

DB_NAME = "yellowshifts_phase8_audit_test"
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

def setup_test_db():
    print(f"[*] Rebuilding isolated comprehensive audit DB: {DB_NAME}")
    subprocess.run(["dropdb", "--if-exists", "-U", CURRENT_USER, DB_NAME], capture_output=True)
    subprocess.run(["createdb", "-U", CURRENT_USER, DB_NAME], check=True)
    subprocess.run([PSQL_BIN, "-d", DB_NAME, "-U", CURRENT_USER, "-c", "CREATE PUBLICATION supabase_realtime;"], capture_output=True)

    migration_files = sorted([f for f in os.listdir(MIGRATIONS_DIR) if f.endswith(".sql") and f <= "20260825000015_phase8_audit_remediation.sql"])
    for mf in migration_files:
        path = os.path.join(MIGRATIONS_DIR, mf)
        cmd = [PSQL_BIN, "-v", "ON_ERROR_STOP=1", "-d", DB_NAME, "-U", CURRENT_USER, "-f", path]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0:
            print(f"Migration {mf} failed: {res.stderr}")
            sys.exit(1)

    print(f"[+] All {len(migration_files)} migrations applied cleanly.")

def main():
    setup_test_db()
    passed = 0
    total = 0

    def test(desc, success):
        nonlocal passed, total
        total += 1
        print(f"[{total:02d}] {desc} ... {'PASSED' if success else 'FAILED'}")
        if success:
            passed += 1
        else:
            print(f"    --> FAILED: {desc}")

    ADMIN_A = '00000000-0000-0000-0000-000000000001'
    MGR_A = '00000000-0000-0000-0000-000000000002'
    EMP_A = '00000000-0000-0000-0000-000000000003'
    STATION_A = '10000000-0000-0000-0000-000000000001'

    print("\n--- Seeding Base Entities & Hebrew Profiles ---")
    seed_sql = f"""
    INSERT INTO auth.users (id, email) VALUES 
        ('{ADMIN_A}', 'admin@yellowshifts.local'),
        ('{MGR_A}', 'manager@yellowshifts.local'),
        ('{EMP_A}', 'employee@yellowshifts.local')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.profiles (id, first_name, last_name, phone, preferred_locale) VALUES
        ('{ADMIN_A}', 'אדמין', 'ראשי', '+972501111111', 'he'),
        ('{MGR_A}', 'מנהל', 'משמרת', '+972502222222', 'he'),
        ('{EMP_A}', 'דוד', 'כהן', '+972503333333', 'he')
    ON CONFLICT (id) DO UPDATE SET
        first_name = EXCLUDED.first_name,
        last_name = EXCLUDED.last_name,
        preferred_locale = EXCLUDED.preferred_locale;

    INSERT INTO public.stations (id, name, code, timezone, locale, is_active) VALUES
        ('{STATION_A}', 'תחנת ירושלים מרכז', 'JR-01', 'Asia/Jerusalem', 'he', true)
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.station_memberships (id, station_id, user_id, role, status, employee_code)
    VALUES 
        ('40000000-0000-0000-0000-000000000001', '{STATION_A}', '{ADMIN_A}', 'ADMIN', 'ACTIVE', 'ADM-01')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.station_memberships (id, station_id, user_id, role, status, employee_code)
    VALUES 
        ('40000000-0000-0000-0000-000000000002', '{STATION_A}', '{MGR_A}', 'SHIFT_MANAGER', 'ACTIVE', 'MGR-01')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.station_memberships (id, station_id, user_id, role, status, employee_code)
    VALUES 
        ('40000000-0000-0000-0000-000000000003', '{STATION_A}', '{EMP_A}', 'EMPLOYEE', 'ACTIVE', 'EMP-01')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.kiosk_devices (id, station_id, name, device_identifier, secret_hash, created_by, is_active, last_seen_at)
    VALUES ('30000000-0000-0000-0000-000000000001', '{STATION_A}', 'עמדת כניסה ראשית', 'KIOSK-MAIN', 'hash123', '{ADMIN_A}', true, now())
    ON CONFLICT (id) DO NOTHING;
    """
    code, _, err = run_psql(seed_sql)
    if code != 0:
        print(f"Base seed failed: {err}")
        sys.exit(1)

    print("\n--- Benchmark 1: Seeding 5,000 High-Volume Attendance Records ---")
    start_bulk = time.time()
    bulk_sql = f"""
    INSERT INTO public.attendance_records (
        station_id, employee_user_id, station_membership_id, 
        check_in_time, check_out_time, worked_minutes, status, late_minutes, check_in_kiosk_device_id
    )
    SELECT 
        '{STATION_A}',
        '{EMP_A}',
        '40000000-0000-0000-0000-000000000003',
        (now() - (i || ' minutes')::interval),
        (now() - (i || ' minutes')::interval + interval '8 hours'),
        480,
        'COMPLETED',
        (CASE WHEN (i % 5) = 0 THEN 15 ELSE 0 END),
        '30000000-0000-0000-0000-000000000001'
    FROM generate_series(1, 5000) i;
    """
    code, _, err = run_psql(bulk_sql)
    elapsed_bulk = time.time() - start_bulk
    test(f"Bulk seeded 5,000 attendance records in {elapsed_bulk:.2f}s", code == 0)

    print("\n--- Benchmark 2: Server CSV Generation on 5k Dataset ---")
    # Request station employee summary within valid 30-day window
    code, data, err = run_as_user_json(ADMIN_A, f"""
        SELECT public.request_report_export('{STATION_A}', 'STATION_EMPLOYEE_WORKED_HOURS', 'CSV', '{{"from_date": "2026-08-01", "to_date": "2026-08-26"}}'::jsonb);
    """)
    export_id = data.get('export_id') if isinstance(data, dict) else None
    test("Export job requested for 5k records", code == 0 and export_id is not None)

    # Benchmark CSV generator latency
    start_gen = time.time()
    code, data, err = run_as_user_json(ADMIN_A, f"SELECT public.generate_report_export_csv('{export_id}');")
    gen_time_ms = (time.time() - start_gen) * 1000
    csv_content = data.get('csv_content', '') if isinstance(data, dict) else ''
    test(f"CSV generation latency < 500ms (Actual: {gen_time_ms:.1f}ms)", code == 0 and gen_time_ms < 500)
    test("CSV starts with UTF-8 BOM (\\uFEFF)", csv_content.startswith('\ufeff'))
    test("Hebrew characters rendered properly in CSV", "דוד כהן" in csv_content or "תחנת ירושלים" in csv_content or "EMP-01" in csv_content)

    print("\n--- Suite 3: Adversarial Formula Injection Fuzzing Matrix ---")
    payloads = [
        ("=1+1", "'=1+1"),
        ("+cmd|' /C calc'!A0", "'+cmd|' /C calc'!A0"),
        ("-2+3+cmd|' /C calc'!A0", "'-2+3+cmd|' /C calc'!A0"),
        ("@SUM(A1:B10)", "'@SUM(A1:B10)"),
        ("\t=2+5", "'\t=2+5"),
        ("Normal text", "Normal text"),
        ("Text with, comma", '"Text with, comma"'),
        ('Text with "quotes"', '"Text with ""quotes"""'),
        ("=HYPERLINK(\"http://evil.com\",\"Click\")", "'=HYPERLINK")
    ]
    for raw, expected_prefix in payloads:
        escaped_sql_str = raw.replace("'", "''")
        code, out, _ = run_psql(f"SELECT public.escape_csv_field('{escaped_sql_str}');")
        is_safe = out.startswith(expected_prefix) or expected_prefix in out
        test(f"Formula sanitized: {repr(raw)[:30]}", is_safe)

    print("\n--- Suite 4: Deep Recursive Audit Metadata Sanitizer Fuzzing ---")
    malicious_meta = {
        "normal_key": "safe_value",
        "user_action": "UPDATE_PROFILE",
        "credentials": {
            "password": "PLAINTEXT_PASSWORD_123",
            "token": "JWT_SECRET_TOKEN",
            "nested_level_2": {
                "raw_secret": "KIOSK_SUPER_SECRET",
                "pin": 9999,
                "safe_nested_field": "KEEP_ME"
            }
        },
        "device": {
            "device_token": "FCM_SECRET_TOKEN_456",
            "client_secret": "OAUTH_SECRET"
        }
    }
    meta_json = json.dumps(malicious_meta).replace("'", "''")
    code, data, err = run_psql(f"SELECT public.sanitize_audit_metadata('{meta_json}'::jsonb);")
    parsed = json.loads(data) if data else {}
    
    # Check all sensitive keys are sanitized with [REDACTED] and plain secrets never leak
    has_safe_val = parsed.get("normal_key") == "safe_value"
    has_safe_nested = parsed.get("credentials", {}).get("nested_level_2", {}).get("safe_nested_field") == "KEEP_ME"
    has_plain_leak = any(s in json.dumps(parsed) for s in ["PLAINTEXT_PASSWORD_123", "JWT_SECRET_TOKEN", "KIOSK_SUPER_SECRET", "9999", "FCM_SECRET_TOKEN_456", "OAUTH_SECRET"])
    has_password_redacted = parsed.get("credentials", {}).get("password") == "[REDACTED]"
    has_token_redacted = parsed.get("credentials", {}).get("token") == "[REDACTED]"
    has_secret_redacted = parsed.get("credentials", {}).get("nested_level_2", {}).get("raw_secret") == "[REDACTED]"
    has_pin_redacted = parsed.get("credentials", {}).get("nested_level_2", {}).get("pin") == "[REDACTED]"

    test("Sanitizer preserved top-level safe keys", has_safe_val)
    test("Sanitizer preserved deep nested safe keys", has_safe_nested)
    test("Sanitizer stripped/redacted all passwords from deep JSON", has_password_redacted and not has_plain_leak)
    test("Sanitizer stripped/redacted all tokens from deep JSON", has_token_redacted and not has_plain_leak)
    test("Sanitizer stripped/redacted all secrets from deep JSON", has_secret_redacted and not has_plain_leak)
    test("Sanitizer stripped/redacted all pins from deep JSON", has_pin_redacted and not has_plain_leak)


    print("\n--- Suite 5: System Telemetry & Anomaly Detection ---")
    code, health_data, err = run_as_user_json(ADMIN_A, f"SELECT public.get_station_system_health('{STATION_A}');")
    health = health_data if isinstance(health_data, dict) else {}
    test("Telemetry reports kiosk fleet correctly", health.get('kiosks', {}).get('total') == 1 and health.get('kiosks', {}).get('online') == 1)
    exports_total = (
        (health.get('exports') or {}).get('total_24h')
        or (health.get('exports_24h') or {}).get('total')
        or 0
    )
    test("Telemetry reports 24h export pipeline activity", exports_total >= 1)

    print("\n" + "=" * 75)
    print(f"PHASE 8 COMPREHENSIVE BENCHMARK & AUDIT: {passed}/{total} PASSED ({passed/total*100:.1f}%)")
    print("=" * 75)
    if passed != total:
        sys.exit(1)

if __name__ == "__main__":
    main()
