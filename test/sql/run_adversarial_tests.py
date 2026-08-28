#!/usr/bin/env python3
"""
YellowShifts Phase 0 & 1 — RLS Adversarial Attack Matrix Test Runner
Executes real PostgreSQL queries under authentic user session JWTs.
"""

import subprocess
import sys

USER_A = '11111111-1111-1111-1111-111111111111'   # Station A (EMPLOYEE), Station B (SHIFT_MANAGER)
USER_B = '22222222-2222-2222-2222-222222222222'   # Station B (EMPLOYEE)
ADMIN_A = '33333333-3333-3333-3333-333333333333'  # Station A (ADMIN)
ADMIN_B = '44444444-4444-4444-4444-444444444444'  # Station B (ADMIN)
USER_C = '55555555-5555-5555-5555-555555555555'   # Station C (EMPLOYEE)
INACTIVE_USER = '66666666-6666-6666-6666-666666666666' # Station A (INACTIVE)

STATION_A = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
STATION_B = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
STATION_C = 'cccccccc-cccc-cccc-cccc-cccccccccccc'

def run_query(sql, as_role='authenticated', user_id=None):
    setup = []
    if as_role:
        setup.append(f"SET ROLE {as_role};")
    if user_id:
        setup.append(f"SET request.jwt.claim.sub = '{user_id}';")
        setup.append(f"SET request.jwt.claim.role = '{as_role}';")
    else:
        setup.append("SET request.jwt.claim.sub = '';")
        setup.append(f"SET request.jwt.claim.role = '{as_role}';")

    full_sql = " ".join(setup) + " " + sql
    cmd = [
        "/opt/homebrew/opt/postgresql@16/bin/psql",
        "-d", "postgres",
        "-t", "-A",
        "-q",
        "-c", full_sql
    ]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    raw_lines = [l.strip() for l in res.stdout.strip().splitlines() if l.strip() and l.strip() != 'SET']
    out = "\n".join(raw_lines)
    return out, res.stderr.strip(), res.returncode

def main():
    # Initialize fresh DB
    subprocess.run(
        ["/opt/homebrew/opt/postgresql@16/bin/psql", "-d", "postgres", "-v", "ON_ERROR_STOP=1", "-f", "test/sql/setup_test_db.sql"],
        capture_output=True,
        text=True
    )

    results = []

    def record(name, expected, actual_pass, detail):
        status = "PASS" if actual_pass else "FAIL"
        results.append((name, expected, detail, status))

    print("Running YellowShifts Phase 0 Adversarial RLS Matrix...\n")

    # Attack 1: User A reads own profile
    out, err, code = run_query("SELECT id FROM public.profiles WHERE id = auth.uid();", user_id=USER_A)
    record("User A reads own profile", "1 row returned (own profile)", USER_A in out, out)

    # Attack 2: User A reads colleague profile (Admin A in Station A)
    out, err, code = run_query(f"SELECT id FROM public.profiles WHERE id = '{ADMIN_A}';", user_id=USER_A)
    record("User A reads colleague profile (Admin A in Station A)", "1 row returned (colleague visible)", ADMIN_A in out, out)

    # Attack 3: User A reads unrelated User C profile
    out, err, code = run_query(f"SELECT id FROM public.profiles WHERE id = '{USER_C}';", user_id=USER_A)
    record("User A attempts to read unrelated User C profile", "0 rows returned (RLS isolated)", out == "" or out == "0", out or "0 rows")

    # Attack 4: User A reads Station A
    out, err, code = run_query(f"SELECT id FROM public.stations WHERE id = '{STATION_A}';", user_id=USER_A)
    record("User A reads Station A (Authorized member)", "1 row returned", STATION_A in out, f"{len(out.splitlines()) if out else 0} rows")

    # Attack 5: User A reads Station B
    out, err, code = run_query(f"SELECT id FROM public.stations WHERE id = '{STATION_B}';", user_id=USER_A)
    record("User A reads Station B (Authorized Shift Manager)", "1 row returned", STATION_B in out, f"{len(out.splitlines()) if out else 0} rows")

    # Attack 6: User A reads Station C
    out, err, code = run_query(f"SELECT id FROM public.stations WHERE id = '{STATION_C}';", user_id=USER_A)
    record("User A attempts to read Station C (Unrelated station)", "0 rows returned (RLS isolated)", out == "", f"{len(out.splitlines()) if out else 0} rows")

    # Attack 7: User A modifies User B profile
    run_query(f"UPDATE public.profiles SET first_name = 'Hacked' WHERE id = '{USER_B}';", user_id=USER_A)
    out, _, _ = run_query(f"SELECT first_name FROM public.profiles WHERE id = '{USER_B}';", user_id=USER_B)
    record("User A attempts to modify User B profile", "0 rows updated (Modification blocked)", out != "Hacked", f"first_name is '{out}'")

    # Attack 8: EMPLOYEE creates ADMIN membership
    out, err, code = run_query(f"INSERT INTO public.station_memberships (station_id, user_id, role) VALUES ('{STATION_A}', '{USER_A}', 'ADMIN');", user_id=USER_A)
    record("EMPLOYEE attempts to create ADMIN membership", "Blocked by RLS policy", code != 0, f"Code {code}, err: {err[:50]}...")

    # Attack 9: EMPLOYEE self-promotion
    run_query(f"UPDATE public.station_memberships SET role = 'ADMIN' WHERE user_id = '{USER_A}' AND station_id = '{STATION_A}';", user_id=USER_A)
    out, _, _ = run_query(f"SELECT role FROM public.station_memberships WHERE user_id = '{USER_A}' AND station_id = '{STATION_A}';", user_id=USER_A)
    record("EMPLOYEE attempts self-promotion to ADMIN", "0 rows updated (Role unchanged)", out == "EMPLOYEE", f"role is '{out}'")

    # Attack 10: EMPLOYEE deactivates ADMIN
    run_query(f"UPDATE public.station_memberships SET status = 'SUSPENDED' WHERE user_id = '{ADMIN_A}' AND station_id = '{STATION_A}';", user_id=USER_A)
    out, _, _ = run_query(f"SELECT status FROM public.station_memberships WHERE user_id = '{ADMIN_A}' AND station_id = '{STATION_A}';", user_id=ADMIN_A)
    record("EMPLOYEE attempts to suspend Admin A membership", "0 rows updated (Status unchanged)", out == "ACTIVE", f"status is '{out}'")

    # Attack 11: SHIFT_MANAGER provisions member
    out, err, code = run_query(f"INSERT INTO public.station_memberships (station_id, user_id, role) VALUES ('{STATION_B}', '{USER_C}', 'EMPLOYEE');", user_id=USER_A)
    record("SHIFT_MANAGER attempts ADMIN-only member provisioning", "Blocked by RLS policy", code != 0, f"Code {code}, err: {err[:50]}...")

    # Attack 12: Admin A updates Station B
    run_query(f"UPDATE public.stations SET name = 'Hacked Beta' WHERE id = '{STATION_B}';", user_id=ADMIN_A)
    out, _, _ = run_query(f"SELECT name FROM public.stations WHERE id = '{STATION_B}';", user_id=ADMIN_B)
    record("Admin A attempts to update Station B settings", "0 rows updated (Cross-station admin blocked)", out == "Station Beta", f"name is '{out}'")

    # Attack 13: Unauthenticated query stations
    out, err, code = run_query("SELECT COUNT(*) FROM public.stations;", as_role='anon')
    record("Unauthenticated client attempts to query stations", "0 rows returned (Anonymous access blocked)", out == "0" or out == "", f"{out} rows")

    # Attack 14: Unauthenticated query memberships
    out, err, code = run_query("SELECT COUNT(*) FROM public.station_memberships;", as_role='anon')
    record("Unauthenticated client attempts to query memberships", "0 rows returned (Anonymous access blocked)", out == "0" or out == "", f"{out} rows")

    # Attack 15: DELETE audit logs
    out, err, code = run_query(f"DELETE FROM public.audit_logs WHERE station_id = '{STATION_A}';", user_id=ADMIN_A)
    record("Authenticated user attempts to DELETE audit logs", "Permission denied (Append-only immutability)", code != 0, f"Code {code}, err: {err[:50]}...")

    # Attack 16: UPDATE audit logs
    out, err, code = run_query(f"UPDATE public.audit_logs SET action = 'TAMPERED';", user_id=ADMIN_A)
    record("Authenticated user attempts to UPDATE audit logs", "Permission denied (Append-only immutability)", code != 0, f"Code {code}, err: {err[:50]}...")

    # Attack 17: Inactive member accesses station data
    out, err, code = run_query(f"SELECT id FROM public.stations WHERE id = '{STATION_A}';", user_id=INACTIVE_USER)
    record("Inactive member attempts to access Station A data", "0 rows returned (Inactive context blocked)", out == "", f"{len(out.splitlines()) if out else 0} rows")

    # Summary
    print("=" * 105)
    print(f"{'Attack':<53} | {'Expected':<22} | {'Actual Result':<14} | {'Status'}")
    print("=" * 105)
    for name, exp, det, st in results:
        print(f"{name:<53} | {exp:<22} | {det[:14]:<14} | {st}")
    print("=" * 105)

    failures = [r for r in results if r[3] == "FAIL"]
    if failures:
        print(f"\nRESULT: {len(failures)} RLS SECURITY BREACHES DETECTED!")
        sys.exit(1)
    else:
        print(f"\nRESULT: 17/17 RLS ATTACKS DEFENDED (100% PASS RATE). ZERO BREACHES.")

if __name__ == "__main__":
    main()
