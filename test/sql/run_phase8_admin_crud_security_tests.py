#!/usr/bin/env python3
"""
YellowShifts Phase 8 — Role Isolation, Authorization, Localization & Admin CRUD Test Suite
Validates phone normalization, admin employee profile update, Last-Admin protection,
anti-cross-station IDOR shield, directory email joining, and audit logging.
"""

import os
import shutil
import sys
import json
import subprocess
import uuid

DB_NAME = "yellowshifts_phase8_admin_crud_test"
PSQL_BIN = shutil.which("psql") or "/opt/homebrew/opt/postgresql@16/bin/psql"
if not os.path.exists(PSQL_BIN):
    PSQL_BIN = shutil.which("psql") or "psql"
CURRENT_USER = os.getenv("USER", "postgres")
MIGRATIONS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "supabase", "migrations"))

def run_psql(sql: str, db: str = DB_NAME) -> tuple[int, str, str]:
    cmd = [PSQL_BIN, "-d", db, "-U", CURRENT_USER, "-v", "VERBOSITY=verbose", "-A", "-t", "-c", sql]
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.returncode, res.stdout.strip(), res.stderr.strip()

def run_as_user_json(user_id: str, sql: str, db: str = DB_NAME) -> tuple[int, any, str]:
    clean_sql = sql.strip().rstrip(';')
    if not clean_sql.upper().startswith("SELECT") and not clean_sql.upper().startswith("INSERT") and not clean_sql.upper().startswith("UPDATE") and not clean_sql.upper().startswith("DELETE"):
        clean_sql = "SELECT " + clean_sql
    wrapped = f"""
    SET LOCAL request.jwt.claim.sub = '{user_id}';
    SET LOCAL request.jwt.claim.role = 'authenticated';
    {clean_sql};
    """
    cmd = [PSQL_BIN, "-d", db, "-U", CURRENT_USER, "-v", "VERBOSITY=verbose", "-A", "-t", "-c", wrapped]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        return res.returncode, None, res.stderr.strip()

    
    # Process stdout lines
    lines = [line.strip() for line in res.stdout.strip().split('\n') if line.strip()]
    if not lines:
        return 0, None, ""
    
    target_line = lines[-1]
    try:
        data = json.loads(target_line)
        return 0, data, ""
    except json.JSONDecodeError:
        return 0, target_line, ""

def setup_test_db():
    print(f"[*] Rebuilding isolated test database: {DB_NAME}")
    subprocess.run(["dropdb", "--if-exists", "-U", CURRENT_USER, DB_NAME], capture_output=True)
    subprocess.run(["createdb", "-U", CURRENT_USER, DB_NAME], check=True)
    subprocess.run([PSQL_BIN, "-d", DB_NAME, "-U", CURRENT_USER, "-c", "CREATE PUBLICATION supabase_realtime;"], capture_output=True)

    # Gather all migrations in order
    migration_files = sorted([f for f in os.listdir(MIGRATIONS_DIR) if f.endswith(".sql")])
    assert len(migration_files) >= 13, f"Expected at least 13 migrations, found {len(migration_files)}: {migration_files}"

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

    def assert_test(name, condition, msg=""):
        nonlocal passed, total
        total += 1
        if condition:
            print(f"[{total:02d}] {name} ... PASSED")
            passed += 1
        else:
            print(f"[{total:02d}] {name} ... FAILED: {msg}")
            sys.exit(1)

    print("\n--- Suite 1: Phone Normalization Engine ---")
    rc, out, err = run_psql("SELECT public.normalize_phone('0501234567');")
    assert_test("Israeli standard local: 0501234567 -> +972501234567", rc == 0 and out == "+972501234567", err)

    rc, out, err = run_psql("SELECT public.normalize_phone('052-987-6543');")
    assert_test("Israeli formatted: 052-987-6543 -> +972529876543", rc == 0 and out == "+972529876543", err)

    rc, out, err = run_psql("SELECT public.normalize_phone('+972 54 111 2233');")
    assert_test("E.164 with whitespace: +972 54 111 2233 -> +972541112233", rc == 0 and out == "+972541112233", err)

    rc, out, err = run_psql("SELECT public.normalize_phone('+14155552671');")
    assert_test("International US: +14155552671 -> +14155552671", rc == 0 and out == "+14155552671", err)

    rc, out, err = run_psql("SELECT public.normalize_phone('');")
    assert_test("Empty phone string normalizes to NULL", rc == 0 and out == "", err)

    rc, out, err = run_psql("SELECT public.normalize_phone('12345');")
    assert_test("Malformed phone rejected with error", rc != 0 and "Invalid phone number format" in err, err)


    print("\n--- Suite 2: Fixtures & Multi-Station Setup ---")
    st_north = str(uuid.uuid4())
    st_south = str(uuid.uuid4())

    run_psql(f"""
        INSERT INTO public.stations (id, name, code, timezone, locale)
        VALUES 
            ('{st_north}', 'Station North', 'ST-NORTH', 'Asia/Jerusalem', 'he'),
            ('{st_south}', 'Station South', 'ST-SOUTH', 'Asia/Jerusalem', 'he');
    """)

    admin_a = str(uuid.uuid4())
    manager_a = str(uuid.uuid4())
    employee_a = str(uuid.uuid4())
    employee_b = str(uuid.uuid4())
    admin_b = str(uuid.uuid4())

    users = [
        (admin_a, 'admin_a@yellowshifts.com', 'Avi', 'Admin', '+972501111111'),
        (manager_a, 'manager_a@yellowshifts.com', 'Miri', 'Manager', '+972502222222'),
        (employee_a, 'emp_a@yellowshifts.com', 'Eli', 'Employee', '+972503333333'),
        (employee_b, 'emp_b@yellowshifts.com', 'Ben', 'Employee', '+972504444444'),
        (admin_b, 'admin_b@yellowshifts.com', 'Boaz', 'AdminB', '+972505555555'),
    ]

    for u_id, email, fn, ln, phone in users:
        run_psql(f"INSERT INTO auth.users (id, email) VALUES ('{u_id}', '{email}');")
        run_psql(f"""
            INSERT INTO public.profiles (id, first_name, last_name, phone, preferred_locale)
            VALUES ('{u_id}', '{fn}', '{ln}', '{phone}', 'he')
            ON CONFLICT (id) DO UPDATE SET
                first_name = EXCLUDED.first_name,
                last_name = EXCLUDED.last_name,
                phone = EXCLUDED.phone,
                preferred_locale = EXCLUDED.preferred_locale;
        """)


    mem_adm_a = str(uuid.uuid4())
    mem_mgr_a = str(uuid.uuid4())
    mem_emp_a = str(uuid.uuid4())
    mem_adm_b = str(uuid.uuid4())
    mem_emp_b = str(uuid.uuid4())

    run_psql(f"""
        INSERT INTO public.station_memberships (id, station_id, user_id, role, status, employee_code)
        VALUES
            ('{mem_adm_a}', '{st_north}', '{admin_a}', 'ADMIN', 'ACTIVE', 'ADM-001'),
            ('{mem_mgr_a}', '{st_north}', '{manager_a}', 'SHIFT_MANAGER', 'ACTIVE', 'MGR-001'),
            ('{mem_emp_a}', '{st_north}', '{employee_a}', 'EMPLOYEE', 'ACTIVE', 'EMP-001'),
            ('{mem_adm_b}', '{st_south}', '{admin_b}', 'ADMIN', 'ACTIVE', 'ADM-002'),
            ('{mem_emp_b}', '{st_south}', '{employee_b}', 'EMPLOYEE', 'ACTIVE', 'EMP-002');
    """)

    print("\n--- Suite 3: Access Control & Denial Verification ---")
    # Anonymous on admin_get_station_members
    rc, out, err = run_psql(f"SELECT * FROM public.admin_get_station_members('{st_north}');")
    assert_test("Anonymous denied on admin_get_station_members", rc != 0 and ("42501" in err or "Authentication required" in err), err)

    # Employee on admin_get_station_members
    rc, out, err = run_as_user_json(employee_a, f"SELECT * FROM public.admin_get_station_members('{st_north}');")
    assert_test("Employee denied on admin_get_station_members (42501)", rc != 0 and "42501" in err, err)

    # Employee on admin_update_employee_profile
    rc, out, err = run_as_user_json(employee_a, f"SELECT public.admin_update_employee_profile('{st_north}', '{employee_a}', 'Hacked', 'User');")
    assert_test("Employee denied on admin_update_employee_profile (42501)", rc != 0 and "42501" in err, err)

    # Shift Manager on admin_update_employee_profile
    rc, out, err = run_as_user_json(manager_a, f"SELECT public.admin_update_employee_profile('{st_north}', '{employee_a}', 'Hacked', 'User');")
    assert_test("Shift Manager denied on admin_update_employee_profile (42501)", rc != 0 and "42501" in err, err)

    # Shift Manager on admin_update_membership
    rc, out, err = run_as_user_json(manager_a, f"SELECT public.admin_update_membership('{st_north}', '{mem_emp_a}', 'ADMIN', 'ACTIVE', 'EMP-X');")
    assert_test("Shift Manager denied on admin_update_membership (42501)", rc != 0 and "42501" in err, err)

    print("\n--- Suite 4: Admin CRUD & Email Visibility ---")
    # Admin A calls admin_get_station_members (JSON array check)
    rc, out, err = run_as_user_json(admin_a, f"""
        SELECT jsonb_agg(row_to_json(m)) FROM (
            SELECT membership_id, first_name, email FROM public.admin_get_station_members('{st_north}')
        ) m;
    """)
    assert_test("Admin lists station members with emails from auth.users", rc == 0 and len(out) == 3 and any(x.get('email') == 'emp_a@yellowshifts.com' for x in out), str(out))

    # Admin A updates Employee A profile
    rc, out, err = run_as_user_json(admin_a, f"""
        SELECT public.admin_update_employee_profile('{st_north}', '{employee_a}', 'Elijah', 'Cohen', '050-999-8877', 'en');
    """)
    assert_test("Admin successfully updates employee profile", rc == 0 and out.get('success') is True and out.get('first_name') == 'Elijah' and out.get('phone') == '+972509998877', str(out))

    # Duplicate phone conflict
    rc, out, err = run_as_user_json(admin_a, f"""
        SELECT public.admin_update_employee_profile('{st_north}', '{employee_a}', 'Elijah', 'Cohen', '+972502222222', 'en');
    """)
    assert_test("Duplicate phone rejected with code 23505", rc != 0 and "23505" in err, err)




    # Anti-cross-station IDOR: Admin A cannot update Employee B (Station B)
    rc, out, err = run_as_user_json(admin_a, f"""
        SELECT public.admin_update_employee_profile('{st_north}', '{employee_b}', 'CrossStation', 'Attack', '+972509990000', 'he');
    """)
    assert_test("Cross-station employee update blocked with P0002", rc != 0 and "P0002" in err, err)

    # Admin A promotes Employee A to Shift Manager
    rc, out, err = run_as_user_json(admin_a, f"""
        SELECT public.admin_update_membership('{st_north}', '{mem_emp_a}', 'SHIFT_MANAGER', 'ACTIVE', 'MGR-NEW');
    """)
    assert_test("Admin promotes employee to Shift Manager", rc == 0 and out.get('role') == 'SHIFT_MANAGER' and out.get('employee_code') == 'MGR-NEW', str(out))

    print("\n--- Suite 5: Last-Admin Invariant & Station-Admin Role Authority (Phase 10.5) ---")
    # Station Admin cannot demote ADMIN (P00105 takes precedence over last-admin P0001)
    rc, out, err = run_as_user_json(admin_a, f"""
        SELECT public.admin_update_membership('{st_north}', '{mem_adm_a}', 'EMPLOYEE', 'ACTIVE', 'ADM-001');
    """)
    assert_test("Station Admin demotion of ADMIN blocked (P00105)", rc != 0 and "P00105" in err, err)

    # Station Admin cannot deactivate ADMIN
    rc, out, err = run_as_user_json(admin_a, f"""
        SELECT public.admin_update_membership('{st_north}', '{mem_adm_a}', 'ADMIN', 'INACTIVE', 'ADM-001');
    """)
    assert_test("Station Admin deactivation of ADMIN blocked (P00105)", rc != 0 and "P00105" in err, err)

    # Station Admin cannot promote Manager to ADMIN
    rc, out, err = run_as_user_json(admin_a, f"""
        SELECT public.admin_update_membership('{st_north}', '{mem_mgr_a}', 'ADMIN', 'ACTIVE', 'MGR-TO-ADM');
    """)
    assert_test("Station Admin cannot promote to ADMIN (P00105)", rc != 0 and "P00105" in err, err)

    rc, out, err = run_as_user_json(admin_a, f"""
        SELECT public.admin_update_employee_profile('{st_north}', '{admin_a}', 'Avi', 'Admin', '+972506666666', 'he');
    """)
    assert_test("Station Admin can update own profile", rc == 0 and out.get('success') is True and out.get('phone') == '+972506666666', str(out))

    rc, out, err = run_as_user_json(admin_a, f"""
        SELECT public.admin_update_membership('{st_north}', '{mem_adm_a}', 'ADMIN', 'ACTIVE', 'ADM-001');
    """)
    assert_test("Station Admin can keep ADMIN role and update employee code", rc == 0 and out.get('role') == 'ADMIN', str(out))

    # Manager remains SHIFT_MANAGER
    rc, out, err = run_psql(f"SELECT role FROM public.station_memberships WHERE id = '{mem_mgr_a}';")
    assert_test("Shift Manager role unchanged after forbidden ADMIN promotion", rc == 0 and out == "SHIFT_MANAGER", out)

    print("\n--- Suite 6: Immutable Audit Logs ---")
    rc, out, err = run_psql(f"""
        SELECT string_agg(action, ',') FROM public.audit_logs WHERE station_id = '{st_north}';
    """)
    actions = out.split(',') if out else []
    assert_test("Audit log records EMPLOYEE_PROFILE_UPDATED", 'EMPLOYEE_PROFILE_UPDATED' in actions, str(actions))
    assert_test("Audit log records MEMBERSHIP_ROLE_CHANGED", 'MEMBERSHIP_ROLE_CHANGED' in actions, str(actions))
    assert_test("Audit log records EMPLOYEE_CODE_UPDATED", 'EMPLOYEE_CODE_UPDATED' in actions, str(actions))

    print(f"\n===========================================================================")
    print(f"PHASE 8 ADMIN CRUD & AUTHZ SECURITY RESULTS: {passed}/{total} PASSED (100.0%)")
    print(f"===========================================================================")

if __name__ == "__main__":
    main()
