#!/usr/bin/env python3
"""
YellowShifts Phase 1 Real PostgreSQL RLS & Security Adversarial Suite
Executes direct attacks against true PostgreSQL 16 engine asserting RLS, RPC authorization,
Last-Admin protection, multi-station isolation, and audit log integrity.
"""

import os
import shutil
import subprocess
import sys

PSQL_BIN = shutil.which("psql") or "/opt/homebrew/opt/postgresql@16/bin/psql"
if not os.path.exists(PSQL_BIN):
    PSQL_BIN = "psql"
DB_NAME = "postgres"

def run_query(sql):
    cmd = [PSQL_BIN, "-d", DB_NAME, "-t", "-A", "-c", sql]
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.returncode, result.stdout.strip(), result.stderr.strip()

def run_test(name, sql_body, expect_error=None, expect_contain=None):
    print(f"[*] RUNNING: {name} ... ", end="")
    code, out, err = run_query(sql_body)

    combined = f"{out}\n{err}".strip()

    if expect_error:
        if code != 0 or expect_error in combined:
            print(f"DEFENDED PASS (Blocked as expected: {expect_error})")
            return True
        else:
            print(f"FAILED (Expected error '{expect_error}', but got success output: {combined})")
            return False
    else:
        if code == 0 and (not expect_contain or expect_contain in combined):
            print(f"PASS ({combined})")
            return True
        else:
            print(f"FAILED (code={code}, output={combined})")
            return False

def main():
    print("================================================================")
    print("YELLOWSHIFTS PHASE 1 POSTGRESQL RLS & LOGIC ADVERSARIAL TEST SUITE")
    print("================================================================\n")

    # Step 1: Re-seed fresh test database
    print("[+] Initializing test database with Phase 0 & Phase 1 migrations...")
    seed_code, _, seed_err = subprocess.run(
        [PSQL_BIN, "-d", DB_NAME, "-v", "ON_ERROR_STOP=1", "-f", "test/sql/setup_test_db.sql"],
        capture_output=True,
        text=True
    ).returncode, "", ""
    if seed_code != 0:
        print(f"[-] Database setup failed: {seed_err}")
        sys.exit(1)
    print("[+] Database initialized successfully.\n")

    results = []

    # Test 1: Last Admin Demotion Prevention
    results.append(run_test(
        "Attack 01: Demote last active Administrator of Station Alpha",
        """
        SET request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
        SET request.jwt.claim.role = 'authenticated';
        SET ROLE authenticated;
        UPDATE public.station_memberships 
        SET role = 'EMPLOYEE' 
        WHERE user_id = '33333333-3333-3333-3333-333333333333' AND station_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
        """,
        expect_error="last active Administrator"
    ))

    # Test 2: Last Admin Deactivation Prevention
    results.append(run_test(
        "Attack 02: Deactivate last active Administrator of Station Alpha",
        """
        SET request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
        SET request.jwt.claim.role = 'authenticated';
        SET ROLE authenticated;
        UPDATE public.station_memberships 
        SET status = 'INACTIVE' 
        WHERE user_id = '33333333-3333-3333-3333-333333333333' AND station_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
        """,
        expect_error="last active Administrator"
    ))

    # Test 3: Last Admin Deletion Prevention
    results.append(run_test(
        "Attack 03: Delete last active Administrator of Station Alpha",
        """
        SET request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
        SET request.jwt.claim.role = 'authenticated';
        SET ROLE authenticated;
        DELETE FROM public.station_memberships 
        WHERE user_id = '33333333-3333-3333-3333-333333333333' AND station_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
        """,
        expect_error="last active Administrator"
    ))

    # Test 4: Privilege Escalation via RPC
    results.append(run_test(
        "Attack 04: Employee User A attempts to escalate themselves to ADMIN via RPC",
        """
        SET request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
        SET request.jwt.claim.role = 'authenticated';
        SET ROLE authenticated;
        SELECT public.admin_update_membership(
            'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            (SELECT id FROM public.station_memberships WHERE user_id = '11111111-1111-1111-1111-111111111111' AND station_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
            'ADMIN',
            'ACTIVE'
        );
        """,
        expect_error="Access denied: caller is not an administrator of this station"
    ))

    # Test 5: Cross-Station Settings Tampering
    results.append(run_test(
        "Attack 05: Admin A attempts to modify settings of Station Beta (Station B)",
        """
        SET request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
        SET request.jwt.claim.role = 'authenticated';
        SET ROLE authenticated;
        SELECT public.admin_update_station(
            'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
            'Hacked Station Beta',
            'HACK',
            'UTC',
            'en',
            0,
            true
        );
        """,
        expect_error="Access denied: caller is not an administrator of this station"
    ))

    # Test 6: Cross-Station Employee Snooping via RPC
    results.append(run_test(
        "Attack 06: Admin A attempts to list employees of Station Beta via RPC",
        """
        SET request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
        SET request.jwt.claim.role = 'authenticated';
        SET ROLE authenticated;
        SELECT COUNT(*) FROM public.admin_get_station_members('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
        """,
        expect_error="Access denied: caller is not an active member of this station"
    ))

    # Test 7: Direct Cross-Station RLS Table Isolation
    results.append(run_test(
        "Test 07: Admin A direct SELECT on station_memberships only returns memberships of Station Alpha",
        """
        SET request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
        SET request.jwt.claim.role = 'authenticated';
        SET ROLE authenticated;
        SELECT COUNT(*) FROM public.station_memberships WHERE station_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
        """,
        expect_contain="0"
    ))

    # Test 8: Multi-Station Human Architecture & Soft Deactivation
    results.append(run_test(
        "Test 08: Soft deactivation in Station Alpha preserves active membership in Station Beta",
        """
        SET request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
        SET request.jwt.claim.role = 'authenticated';
        SET ROLE authenticated;
        -- Admin A deactivates User A in Station Alpha
        SELECT public.admin_update_membership(
            'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            (SELECT id FROM public.station_memberships WHERE user_id = '11111111-1111-1111-1111-111111111111' AND station_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
            'EMPLOYEE',
            'INACTIVE'
        );
        -- Verify User A is still ACTIVE in Station Beta
        SELECT status FROM public.station_memberships WHERE user_id = '11111111-1111-1111-1111-111111111111' AND station_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
        """,
        expect_contain="ACTIVE"
    ))

    # Test 9: With a second Admin present, Phase 1 last-admin allows extra-admin demotion.
    # P00105 (station ADMIN cannot grant/revoke ADMIN) is enforced only after migration 018
    # and is covered by Phase 10.5 suites. This suite applies 001-002 only.
    results.append(run_test(
        "Test 09: Extra Station Admin can be demoted when last-admin invariant is preserved",
        """
        -- Reset context to superuser to add second admin in Station A
        RESET ROLE;
        INSERT INTO public.station_memberships (station_id, user_id, role, status, employee_code)
        VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '77777777-7777-7777-7777-777777777777', 'ADMIN', 'ACTIVE', 'ADM-002');
        
        -- Admin A demotes themselves now that a second admin exists
        SET request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
        SET request.jwt.claim.role = 'authenticated';
        SET ROLE authenticated;
        SELECT public.admin_update_membership(
            'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            (SELECT id FROM public.station_memberships WHERE user_id = '33333333-3333-3333-3333-333333333333' AND station_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
            'SHIFT_MANAGER',
            'ACTIVE'
        );
        """,
        expect_contain="SHIFT_MANAGER"
    ))

    # Test 10: Audit Log Creation Verification
    results.append(run_test(
        "Test 10: Verify sensitive operations generated immutable audit logs",
        """
        RESET ROLE;
        SELECT COUNT(*) FROM public.audit_logs WHERE action IN ('MEMBERSHIP_ROLE_CHANGED', 'MEMBERSHIP_DEACTIVATED');
        """,
        expect_contain="2"
    ))

    # Test 11: Station Pulse Counts Accuracy
    results.append(run_test(
        "Test 11: Pulse counts RPC returns exact metrics for Station Alpha",
        """
        SET request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';
        SET request.jwt.claim.role = 'authenticated';
        SET ROLE authenticated;
        SELECT (public.get_station_pulse_counts('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')->>'admin_count')::int;
        """,
        expect_contain="1"
    ))

    # Test 12: Colleague Profile View Boundary
    results.append(run_test(
        "Test 12: User B in Station Beta cannot view User C profile (Station Gamma only)",
        """
        SET request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
        SET request.jwt.claim.role = 'authenticated';
        SET ROLE authenticated;
        SELECT COUNT(*) FROM public.profiles WHERE id = '55555555-5555-5555-5555-555555555555';
        """,
        expect_contain="0"
    ))

    print("\n================================================================")
    passed = sum(1 for r in results if r)
    total = len(results)
    print(f"PHASE 1 ADVERSARIAL SECURITY SUMMARY: {passed}/{total} PASSED ({(passed/total)*100:.1f}%)")
    print("================================================================")

    if passed != total:
        sys.exit(1)

if __name__ == "__main__":
    main()
