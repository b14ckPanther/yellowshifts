#!/usr/bin/env python3
"""
YellowShifts Phase 10 — High-Load Database Performance Benchmarks
Tests query execution times and EXPLAIN ANALYZE plans on realistic production datasets:
- 10,000 Audit Log rows
- 10,000 Attendance records
- 5,000 Export dataset rows
"""

import os
import sys
import time
import uuid
import shutil
import subprocess

DB_NAME = "yellowshifts_phase10_benchmarks"
PSQL_BIN = shutil.which("psql") or "/opt/homebrew/bin/psql"
CURRENT_USER = os.getenv("USER", "postgres")
MIGRATIONS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "supabase", "migrations"))

def run_psql(sql: str, db: str = DB_NAME) -> tuple[int, str, str]:
    cmd = [PSQL_BIN, "-d", db, "-U", CURRENT_USER, "-v", "VERBOSITY=verbose", "-v", "ON_ERROR_STOP=1", "-A", "-t"]
    res = subprocess.run(cmd, input=sql, capture_output=True, text=True)
    return res.returncode, res.stdout.strip(), res.stderr.strip()

def run_psql_file(filepath: str, db: str = DB_NAME) -> tuple[int, str, str]:
    cmd = [PSQL_BIN, "-d", db, "-U", CURRENT_USER, "-v", "VERBOSITY=verbose", "-v", "ON_ERROR_STOP=1", "-f", filepath]
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.returncode, res.stdout.strip(), res.stderr.strip()

def run_benchmarks():
    print(f"[*] Provisioning isolated benchmark database: {DB_NAME}...")
    run_psql(f"DROP DATABASE IF EXISTS {DB_NAME};", db="postgres")
    code, _, err = run_psql(f"CREATE DATABASE {DB_NAME};", db="postgres")
    if code != 0:
        print(f"[!] DB creation error: {err}")
        return 1

    setup_sql = """
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "pgcrypto";
    DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN CREATE PUBLICATION supabase_realtime; END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon NOLOGIN; END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN CREATE ROLE service_role NOLOGIN; END IF;
    END $$;
    CREATE SCHEMA IF NOT EXISTS auth;
    CREATE TABLE IF NOT EXISTS auth.users (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), email TEXT UNIQUE, encrypted_password TEXT, raw_user_meta_data JSONB DEFAULT '{}'::jsonb, created_at TIMESTAMPTZ DEFAULT now(), updated_at TIMESTAMPTZ DEFAULT now());
    CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID AS $$ BEGIN RETURN NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid; EXCEPTION WHEN OTHERS THEN RETURN NULL; END; $$ LANGUAGE plpgsql STABLE;
    CREATE OR REPLACE FUNCTION auth.role() RETURNS TEXT AS $$ BEGIN RETURN COALESCE(NULLIF(current_setting('request.jwt.claim.role', true), ''), 'anon'); EXCEPTION WHEN OTHERS THEN RETURN 'anon'; END; $$ LANGUAGE plpgsql STABLE;
    """
    run_psql(setup_sql)

    migration_files = sorted([f for f in os.listdir(MIGRATIONS_DIR) if f.endswith(".sql") and f <= "20260825000017_phase9_audit_remediation.sql"])
    for mf in migration_files:
        code, _, err = run_psql_file(os.path.join(MIGRATIONS_DIR, mf))
        if code != 0:
            print(f"[!] Migration {mf} failed: {err}")
            return 1

    print("[+] Migrations applied cleanly. Seeding high-load datasets...")

    sta_id = str(uuid.uuid4())
    admin_id = str(uuid.uuid4())
    kiosk_id = str(uuid.uuid4())

    seed_core = f"""
    INSERT INTO auth.users (id, email) VALUES ('{admin_id}', 'benchmark.admin@yellowshifts.local');
    INSERT INTO public.stations (id, name, code, is_active) VALUES ('{sta_id}', 'Benchmark Station', 'BENCH-01', true);
    INSERT INTO public.profiles (id, first_name, last_name, phone) VALUES ('{admin_id}', 'Bench', 'Admin', '+972509999999');
    INSERT INTO public.station_memberships (station_id, user_id, role, status) VALUES ('{sta_id}', '{admin_id}', 'ADMIN', 'ACTIVE');
    INSERT INTO public.kiosk_devices (id, station_id, name, device_identifier, secret_hash, created_by, is_active, last_seen_at)
    VALUES ('{kiosk_id}', '{sta_id}', 'Bench Kiosk', 'BENCH-K1', crypt('k1-sec', gen_salt('bf')), '{admin_id}', true, now());
    """
    run_psql(seed_core)

    # 1. Benchmark 10,000 Audit Log Rows
    print("[*] Seeding 10,000 audit log rows...")
    t0 = time.perf_counter()
    run_psql(f"""
    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata, created_at)
    SELECT
      '{sta_id}',
      '{admin_id}',
      CASE (i % 4)
        WHEN 0 THEN 'ATTENDANCE_CHECK_IN'
        WHEN 1 THEN 'ATTENDANCE_CHECK_OUT'
        WHEN 2 THEN 'SCHEDULE_PUBLISHED'
        ELSE 'EMPLOYEE_ROLE_UPDATED'
      END,
      'attendance',
      gen_random_uuid(),
      jsonb_build_object('iteration', i, 'employee_code', 'EMP-' || (i % 100)),
      now() - (i || ' minutes')::interval
    FROM generate_series(1, 10000) AS i;
    """)
    t_seed_audit = (time.perf_counter() - t0) * 1000
    print(f"    10,000 audit logs seeded in {t_seed_audit:.2f}ms")

    # Benchmark: Paginated station audit log retrieval
    t0 = time.perf_counter()
    code, audit_res, _ = run_psql(f"""
    EXPLAIN ANALYZE
    SELECT id, actor_id, action, target_type, created_at
    FROM public.audit_logs
    WHERE station_id = '{sta_id}'
    ORDER BY created_at DESC
    LIMIT 50;
    """)
    t_query_audit = (time.perf_counter() - t0) * 1000
    print(f"[*] Benchmark 1 (Paginated 10k Audit Query): {t_query_audit:.2f}ms")
    print(f"    Execution plan:\n{audit_res}\n")

    # 2. Benchmark 10,000 Attendance Records
    print("[*] Seeding 10,000 attendance records across 100 employees...")
    t0 = time.perf_counter()
    # Seed 100 employees
    run_psql(f"""
    DO $$
    DECLARE
      u_id UUID;
      m_id UUID;
    BEGIN
      FOR i IN 1..100 LOOP
        u_id := gen_random_uuid();
        INSERT INTO auth.users (id, email) VALUES (u_id, 'bench_emp_' || i || '@test.local');
        INSERT INTO public.profiles (id, first_name, last_name, phone) VALUES (u_id, 'Emp', '' || i, '+97250000' || lpad(i::text, 4, '0'));
        INSERT INTO public.station_memberships (id, station_id, user_id, role, status) VALUES (gen_random_uuid(), '{sta_id}', u_id, 'EMPLOYEE', 'ACTIVE');
      END LOOP;
    END $$;

    INSERT INTO public.attendance_records (station_id, employee_user_id, station_membership_id, check_in_kiosk_device_id, check_in_time, check_out_time, worked_minutes, verification_method, operational_date)
    SELECT
      sm.station_id,
      sm.user_id,
      sm.id,
      '{kiosk_id}',
      (CURRENT_DATE - (d || ' days')::interval + '08:00:00'::time),
      (CURRENT_DATE - (d || ' days')::interval + '16:30:00'::time),
      510,
      'QR_ONLY',
      (CURRENT_DATE - (d || ' days')::interval)::date
    FROM public.station_memberships sm
    CROSS JOIN generate_series(1, 100) AS d
    WHERE sm.station_id = '{sta_id}' AND sm.role = 'EMPLOYEE';
    """)
    t_seed_att = (time.perf_counter() - t0) * 1000
    print(f"    10,000 attendance records seeded in {t_seed_att:.2f}ms")

    # Benchmark: Monthly attendance KPI summary across 10,000 records
    t0 = time.perf_counter()
    code, kpi_res, _ = run_psql(f"""
    EXPLAIN ANALYZE
    SELECT
      COUNT(*) AS total_shifts,
      SUM(worked_minutes) AS total_minutes,
      AVG(worked_minutes) AS avg_minutes
    FROM public.attendance_records
    WHERE station_id = '{sta_id}'
      AND operational_date BETWEEN (CURRENT_DATE - INTERVAL '30 days') AND CURRENT_DATE;
    """)
    t_query_kpi = (time.perf_counter() - t0) * 1000
    print(f"[*] Benchmark 2 (Monthly 10k Attendance KPI Aggregation): {t_query_kpi:.2f}ms")
    print(f"    Execution plan:\n{kpi_res}\n")

    # 3. Benchmark 5,000 Export Dataset Aggregation
    print("[*] Benchmarking JSON export aggregation over 5,000 records...")
    t0 = time.perf_counter()
    code, exp_agg_res, _ = run_psql(f"""
    EXPLAIN ANALYZE
    SELECT jsonb_agg(
      jsonb_build_object(
        'attendance_id', ar.id,
        'employee_name', p.first_name || ' ' || p.last_name,
        'operational_date', ar.operational_date,
        'worked_minutes', ar.worked_minutes,
        'check_in_time', ar.check_in_time,
        'check_out_time', ar.check_out_time
      )
    )
    FROM public.attendance_records ar
    JOIN public.profiles p ON ar.employee_user_id = p.id
    WHERE ar.station_id = '{sta_id}'
    LIMIT 5000;
    """)
    t_query_exp = (time.perf_counter() - t0) * 1000
    print(f"[*] Benchmark 3 (5,000 Export Rows JSON Aggregation): {t_query_exp:.2f}ms")
    print(f"    Execution plan:\n{exp_agg_res}\n")

    print("==================================================================")
    print("   HIGH-LOAD BENCHMARK SUMMARY                                    ")
    print("==================================================================")
    print(f"   1. Paginated Audit Query (10,000 rows):     {t_query_audit:.2f} ms")
    print(f"   2. Attendance KPI Aggregation (10,000 rows): {t_query_kpi:.2f} ms")
    print(f"   3. Export JSON Aggregation (5,000 rows):    {t_query_exp:.2f} ms")
    print("==================================================================")
    return 0

if __name__ == "__main__":
    sys.exit(run_benchmarks())
