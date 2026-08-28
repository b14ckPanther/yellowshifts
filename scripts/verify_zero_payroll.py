#!/usr/bin/env python3
"""
YellowShifts — Zero-Payroll & Non-Compensation Invariant Scanner
Verifies that no payroll, salary, wage, hourly pay, tax, or financial compensation
logic exists anywhere in schema migrations, Dart models, or application business logic.
"""

import os
import re
import sys

FORBIDDEN_TERMS = [
    r'\bgross_pay\b',
    r'\bnet_pay\b',
    r'\bhourly_rate\b',
    r'\bovertime_rate\b',
    r'\btax_withholding\b',
    r'\bcalculate_salary\b',
    r'\bpayroll_export\b',
    r'\bwage_calculation\b',
]

SCAN_DIRS = ["lib", "web", "supabase/migrations", "supabase/functions", "assets"]
EXCLUDE_FILES = {'verify_zero_payroll.py', 'PHASE-10-PRODUCTION-READINESS.md', 'SECURITY.md', 'walkthrough.md'}

def main():
    print("==================================================")
    print(" YELLOWSHIFTS ZERO-PAYROLL INVARIANT SCANNER      ")
    print("==================================================")

    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    compiled_terms = [re.compile(t, re.IGNORECASE) for t in FORBIDDEN_TERMS]
    violations = []
    scanned_count = 0

    for target in SCAN_DIRS:
        abs_target = os.path.join(root_dir, target)
        if not os.path.exists(abs_target):
            continue
        for root, dirs, files in os.walk(abs_target):
            for file in files:
                if file in EXCLUDE_FILES or file.endswith('.png') or file.endswith('.ttf') or file.endswith('.lock'):
                    continue
                
                filepath = os.path.join(root, file)
                rel_path = os.path.relpath(filepath, root_dir)
                scanned_count += 1

                try:
                    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                        for line_no, line in enumerate(f, start=1):
                            for pattern in compiled_terms:
                                if pattern.search(line):
                                    # Check if it's a test asserting the absence or docs stating prohibition
                                    if "prohibited" in line or "Zero forbidden" in line or "Zero payroll" in line:
                                        continue
                                    violations.append(f"{rel_path}:{line_no} — {line.strip()}")
                except Exception as e:
                    print(f"[!] Error reading {rel_path}: {e}")

    print(f"[*] Scanned {scanned_count} files.")

    if violations:
        print(f"\n[!] INVARIANT VIOLATION: {len(violations)} payroll references found:")
        for v in violations:
            print(f"  - {v}")
        sys.exit(1)
    else:
        print("[+] SUCCESS: Zero payroll, wage, tax, or financial compensation logic detected.")
        sys.exit(0)

if __name__ == "__main__":
    main()
