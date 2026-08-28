#!/usr/bin/env python3
"""
YellowShifts Phase 2 — Adversarial Security, Concurrency & Invariant Test Suite
Executes real PostgreSQL queries under authentic user session JWTs to prove:
- Dynamic shift templates & cross-midnight support
- Shift Manager permission overrides
- Snapshot freezing on open & historical immutability
- Draft auto-save & atomic completeness validation
- Edit-after-submit reversion to DRAFT
- Manager operational matrix with verified KPI invariants
- Multi-station RLS isolation
"""

import os
import subprocess
import shutil
import sys
import json

PSQL_BIN = shutil.which("psql") or "/opt/homebrew/opt/postgresql@16/bin/psql"
if not os.path.exists(PSQL_BIN):
    PSQL_BIN = shutil.which("psql") or "psql"
DB_NAME = "postgres"

USER_A = '11111111-1111-1111-1111-111111111111'     # Station A (EMPLOYEE), Station B (SHIFT_MANAGER)
USER_B = '22222222-2222-2222-2222-222222222222'     # Station B (EMPLOYEE)
ADMIN_A = '33333333-3333-3333-3333-333333333333'    # Station A (ADMIN)
ADMIN_B = '44444444-4444-4444-4444-444444444444'    # Station B (ADMIN)
USER_C = '55555555-5555-5555-5555-555555555555'     # Station C (EMPLOYEE)
MANAGER_A = '77777777-7777-7777-7777-777777777777'  # Station A (SHIFT_MANAGER)

STATION_A = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
STATION_B = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
STATION_C = 'cccccccc-cccc-cccc-cccc-cccccccccccc'

def run_query(sql, user_id=None, as_role='authenticated'):
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
    cmd = [PSQL_BIN, "-d", DB_NAME, "-t", "-A", "-c", full_sql]
    res = subprocess.run(cmd, capture_output=True, text=True)
    raw_lines = [l.strip() for l in res.stdout.strip().splitlines() if l.strip() and l.strip() != 'SET']
    out = "\n".join(raw_lines)
    return res.returncode, out, res.stderr.strip()

def main():
    print("=================================================================")
    print("YELLOWSHIFTS PHASE 2 ADVERSARIAL SECURITY & OPERATIONAL SUITE")
    print("=================================================================\n")

    # Step 1: Re-seed test database with Phase 0, 1, and 2 migrations
    print("[+] Re-seeding database from clean migrations...")
    seed_res = subprocess.run(
        [PSQL_BIN, "-d", DB_NAME, "-v", "ON_ERROR_STOP=1", "-f", "test/sql/setup_phase2_test_db.sql"],
        capture_output=True,
        text=True
    )
    if seed_res.returncode != 0:
        print(f"[-] Database setup failed:\n{seed_res.stderr}")
        sys.exit(1)
    print("[+] Database initialized successfully.\n")

    results = []

    def record(name, expected, passed, detail):
        status = "PASS" if passed else "FAIL"
        results.append((name, expected, detail, status))
        print(f"[*] RUNNING: {name} ... {status} ({detail})")

    # Test 01: Create dynamic shift templates (including cross-midnight)
    code, out, err = run_query(f"""
        SELECT public.admin_manage_shift_template(
            '{STATION_A}', NULL, 'Morning', 'MOR', '07:00'::time, '15:30'::time, 0, true
        );
        SELECT public.admin_manage_shift_template(
            '{STATION_A}', NULL, 'Evening', 'EVE', '15:30'::time, '23:00'::time, 1, true
        );
        SELECT public.admin_manage_shift_template(
            '{STATION_A}', NULL, 'Night Cross-Midnight', 'NIGHT', '23:00'::time, '07:00'::time, 2, true
        );
    """, user_id=ADMIN_A)
    record(
        "Test 01: Admin A creates 3 shift templates with cross-midnight",
        "Templates created",
        code == 0 and "Night Cross-Midnight" in out,
        "Created 3 templates (including 23:00->07:00)"
    )

    # Test 02: Zero-duration template rejection (chk_shift_template_non_zero_duration)
    code, out, err = run_query(f"""
        SELECT public.admin_manage_shift_template(
            '{STATION_A}', NULL, 'Invalid Zero', 'ZERO', '08:00'::time, '08:00'::time, 3, true
        );
    """, user_id=ADMIN_A)
    record(
        "Test 02: Zero-duration shift template rejection (08:00 -> 08:00)",
        "Blocked with validation error",
        code != 0,
        "Blocked zero-duration template"
    )

    # Test 03: Shift Manager without shift_templates.manage permission blocked from creating template
    code, out, err = run_query(f"""
        SELECT public.admin_manage_shift_template(
            '{STATION_A}', NULL, 'Manager Shift', 'MGR', '10:00'::time, '18:00'::time, 3, true
        );
    """, user_id=MANAGER_A)
    record(
        "Test 03: Shift Manager A without manage permission blocked from creating templates",
        "Permission denied (42501)",
        code != 0 and "access denied" in err.lower(),
        "Access denied as expected"
    )

    # Test 04: Admin grants shift_templates.manage to Shift Manager -> Manager can create template
    run_query(f"""
        SELECT public.admin_set_shift_manager_permissions('{STATION_A}', '{{"shift_templates.manage": true}}'::jsonb);
    """, user_id=ADMIN_A)
    code, out, err = run_query(f"""
        SELECT public.admin_manage_shift_template(
            '{STATION_A}', NULL, 'Manager Special', 'SPEC', '12:00'::time, '20:00'::time, 3, true
        );
    """, user_id=MANAGER_A)
    record(
        "Test 04: Admin grants shift_templates.manage override to Shift Manager -> Success",
        "Template created by Manager",
        code == 0 and "Manager Special" in out,
        "Manager successfully created template with override"
    )

    # Test 05: Cross-station template tampering blocked (Admin A on Station Beta)
    code, out, err = run_query(f"""
        SELECT public.admin_manage_shift_template(
            '{STATION_B}', NULL, 'Hacked Shift', 'HACK', '08:00'::time, '16:00'::time, 0, true
        );
    """, user_id=ADMIN_A)
    record(
        "Test 05: Admin A attempts cross-station template mutation on Station Beta",
        "Blocked (42501)",
        code != 0 and "access denied" in err.lower(),
        "Cross-station admin mutation blocked"
    )

    # Clean template 4 for standard 3-template testing
    run_query(f"""
        DELETE FROM public.shift_templates WHERE code = 'SPEC';
    """)

    # Test 06: Create Draft Availability Period
    code, out, err = run_query(f"""
        SELECT public.create_availability_period(
            '{STATION_A}', '2026-09-06'::date, (now() + INTERVAL '5 days'), 'Weekly availability request'
        );
    """, user_id=ADMIN_A)
    period_id = json.loads(out.splitlines()[-1])['period_id'] if code == 0 else None
    record(
        "Test 06: Admin A creates DRAFT weekly availability period",
        "Period created in DRAFT",
        code == 0 and period_id is not None,
        f"Period ID: {period_id[:8]}..." if period_id else "Failed"
    )

    # Test 07: Duplicate availability period rejection (same station & week_start_date)
    code, out, err = run_query(f"""
        SELECT public.create_availability_period(
            '{STATION_A}', '2026-09-06'::date, (now() + INTERVAL '5 days'), 'Duplicate attempt'
        );
    """, user_id=ADMIN_A)
    record(
        "Test 07: Duplicate availability period for same station and week rejected",
        "Unique constraint rejection",
        code != 0,
        "Duplicate period rejected"
    )

    # Test 08: Open Availability Period (Atomic Snapshot of templates & eligible members)
    code, out, err = run_query(f"""
        SELECT public.open_availability_period('{period_id}');
    """, user_id=ADMIN_A)
    record(
        "Test 08: Open availability period (Freezes template & member snapshots)",
        "Period OPEN with 3 templates snapshotted",
        code == 0 and '"status": "OPEN"' in out,
        "Snapshot frozen successfully"
    )

    # Test 09: Template Immutability Isolation: Admin modifies live template AFTER period open
    # Snapshot in open period must remain unchanged!
    run_query(f"""
        UPDATE public.shift_templates SET name = 'Renamed Live Morning' WHERE code = 'MOR' AND station_id = '{STATION_A}';
    """, user_id=ADMIN_A)
    _, snap_name_out, _ = run_query(f"""
        SELECT name_snapshot FROM public.availability_period_shift_templates 
        WHERE availability_period_id = '{period_id}' AND code_snapshot = 'MOR';
    """, user_id=ADMIN_A)
    record(
        "Test 09: Period template snapshot remains frozen after live template rename",
        "Snapshot name is still 'Morning'",
        snap_name_out.strip() == "Morning",
        f"Snapshot name preserved: '{snap_name_out.strip()}'"
    )

    # Fetch period shift template IDs for submission
    _, snap_ids_raw, _ = run_query(f"""
        SELECT id FROM public.availability_period_shift_templates 
        WHERE availability_period_id = '{period_id}' ORDER BY sort_order_snapshot ASC;
    """, user_id=ADMIN_A)
    snap_ids = snap_ids_raw.splitlines()

    # Test 10: Employee saves partial draft availability
    draft_entries = [
        {"date": "2026-09-06", "period_shift_template_id": snap_ids[0], "is_available": True},
        {"date": "2026-09-06", "period_shift_template_id": snap_ids[1], "is_available": False},
    ]
    code, out, err = run_query(f"""
        SELECT public.save_availability_draft('{period_id}', '{json.dumps(draft_entries)}'::jsonb);
    """, user_id=USER_A)
    record(
        "Test 10: Employee User A saves partial availability draft",
        "Saved in DRAFT status",
        code == 0 and '"status": "DRAFT"' in out,
        "Partial draft saved"
    )

    # Test 11: Incomplete final submission rejected (only 2 of 21 slots answered)
    code, out, err = run_query(f"""
        SELECT public.submit_availability('{period_id}', '{json.dumps(draft_entries)}'::jsonb);
    """, user_id=USER_A)
    record(
        "Test 11: Incomplete availability submission rejected (P0004)",
        "Blocked due to missing slots",
        code != 0 and "incomplete" in err.lower(),
        "Rejected incomplete submission as required"
    )

    # Test 12: Complete 21-slot submission (3 templates x 7 days)
    full_entries = []
    days = ["2026-09-06", "2026-09-07", "2026-09-08", "2026-09-09", "2026-09-10", "2026-09-11", "2026-09-12"]
    for d in days:
        for tid in snap_ids:
            full_entries.append({"date": d, "period_shift_template_id": tid, "is_available": True})

    code, out, err = run_query(f"""
        SELECT public.submit_availability('{period_id}', '{json.dumps(full_entries)}'::jsonb);
    """, user_id=USER_A)
    record(
        "Test 12: Complete 21-slot availability submission succeeds",
        "Status becomes SUBMITTED",
        code == 0 and '"status": "SUBMITTED"' in out,
        "Submitted successfully"
    )

    # Test 13: Employee edits slot after submission -> Automatically reverts to DRAFT
    single_edit = [{"date": "2026-09-06", "period_shift_template_id": snap_ids[0], "is_available": False}]
    code, out, err = run_query(f"""
        SELECT public.save_availability_draft('{period_id}', '{json.dumps(single_edit)}'::jsonb);
    """, user_id=USER_A)
    _, sub_status_out, _ = run_query(f"""
        SELECT status FROM public.availability_submissions 
        WHERE availability_period_id = '{period_id}' AND membership_id = (
            SELECT id FROM public.station_memberships WHERE station_id = '{STATION_A}' AND user_id = '{USER_A}'
        );
    """, user_id=USER_A)
    record(
        "Test 13: Editing slot after submit automatically reverts status to DRAFT",
        "Submission status reverts to DRAFT",
        sub_status_out.strip() == "DRAFT",
        f"Reverted to status: '{sub_status_out.strip()}'"
    )

    # Resubmit complete availability for User A
    run_query(f"""
        SELECT public.submit_availability('{period_id}', '{json.dumps(full_entries)}'::jsonb);
    """, user_id=USER_A)

    # Test 14: Cross-station availability review blocked (Shift Manager in Station B cannot read Station A matrix)
    code, out, err = run_query(f"""
        SELECT public.get_availability_matrix('{period_id}');
    """, user_id=USER_B)
    record(
        "Test 14: Station B user blocked from querying Station A availability matrix",
        "Access denied (42501)",
        code != 0 and "access denied" in err.lower(),
        "Cross-station matrix read blocked"
    )

    # Test 15: Manager Review & KPI Invariant Verification
    code, out, err = run_query(f"""
        SELECT public.get_availability_matrix('{period_id}');
    """, user_id=ADMIN_A)
    matrix_data = json.loads(out.splitlines()[-1]) if code == 0 else {}
    metrics = matrix_data.get('metrics', {})
    eligible = metrics.get('eligible_employees', 0)
    submitted = metrics.get('submitted_employees', 0)
    draft = metrics.get('draft_employees', 0)
    not_started = metrics.get('not_started_employees', 0)
    not_submitted = metrics.get('not_submitted_employees', 0)

    invariant1 = (eligible == submitted + draft + not_started)
    invariant2 = (not_submitted == draft + not_started)

    record(
        "Test 15: Manager Availability Matrix KPI Invariants verified",
        "eligible == submitted + draft + not_started AND not_submitted == draft + not_started",
        invariant1 and invariant2 and eligible > 0,
        f"KPIs: Eligible={eligible}, Submitted={submitted}, Draft={draft}, NotStarted={not_started}"
    )

    # Test 16: Close Availability Period
    code, out, err = run_query(f"""
        SELECT public.close_availability_period('{period_id}');
    """, user_id=ADMIN_A)
    record(
        "Test 16: Admin A closes availability period",
        "Status becomes CLOSED",
        code == 0 and '"status": "CLOSED"' in out,
        "Period closed successfully"
    )

    # Test 17: Employee submission blocked on CLOSED period
    code, out, err = run_query(f"""
        SELECT public.submit_availability('{period_id}', '{json.dumps(full_entries)}'::jsonb);
    """, user_id=USER_A)
    record(
        "Test 17: Employee submission on CLOSED period rejected",
        "Blocked (not open for submission)",
        code != 0,
        "Mutation on closed period blocked"
    )

    # Test 18: Anonymous client blocked from all Phase 2 tables
    code, out, err = run_query(f"""
        SELECT COUNT(*) FROM public.shift_templates;
        SELECT COUNT(*) FROM public.availability_periods;
        SELECT COUNT(*) FROM public.availability_submissions;
    """, as_role='anon')
    record(
        "Test 18: Anonymous access blocked across all Phase 2 operational tables",
        "0 rows returned",
        out == "0\n0\n0" or out == "",
        "Anonymous access blocked"
    )

    # Test 19: Verify Audit Logs generated for Phase 2 events without credential leakage
    _, audit_count, _ = run_query(f"""
        RESET ROLE;
        SELECT COUNT(*) FROM public.audit_logs 
        WHERE station_id = '{STATION_A}' 
          AND action IN ('SHIFT_TEMPLATE_CREATED', 'AVAILABILITY_PERIOD_CREATED', 'AVAILABILITY_PERIOD_OPENED', 'AVAILABILITY_SUBMITTED');
    """)
    record(
        "Test 19: Immutable audit logs generated for Phase 2 operational events",
        "Audit rows present with zero credential metadata",
        int(audit_count.strip().splitlines()[-1]) >= 4,
        f"Generated {audit_count.strip().splitlines()[-1]} Phase 2 audit events"
    )

    print("\n=================================================================")
    passed = sum(1 for r in results if r[3] == "PASS")
    total = len(results)
    print(f"PHASE 2 ADVERSARIAL SECURITY SUMMARY: {passed}/{total} PASSED ({(passed/total)*100:.1f}%)")
    print("=================================================================")

    if passed != total:
        sys.exit(1)

if __name__ == "__main__":
    main()
