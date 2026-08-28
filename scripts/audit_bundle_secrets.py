#!/usr/bin/env python3
"""
YellowShifts — Client Bundle & Codebase Secret Audit
Scans build/web, lib/, web/, and client assets for accidentally leaked private credentials:
- SUPABASE_SERVICE_ROLE_KEY
- Database passwords / connection strings with passwords
- FCM Server private keys
- Private signing keys / JWT secrets
- Sensitive operator credentials
"""

import os
import re
import sys

SEARCH_DIRS = [
    "build/web",
    "lib",
    "web",
    "assets",
]

# High-risk private secret patterns (NOT anon / publishable keys)
SECRET_PATTERNS = [
    (re.compile(r'service_role', re.IGNORECASE), "Literal 'service_role' reference in client bundle"),
    (re.compile(r'SUPABASE_SERVICE_ROLE_KEY', re.IGNORECASE), "SUPABASE_SERVICE_ROLE_KEY reference"),
    (re.compile(r'postgres://[^:]+:([^@]+)@', re.IGNORECASE), "PostgreSQL password URI string"),
    (re.compile(r'-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----'), "Raw Private Key PEM block"),
    (re.compile(r'(?i)(fcm_server_key|apns_private_key|resend_api_key)\s*[:=]\s*["\'][^"\']+["\']'), "Private provider secret literal"),
]

# Whitelisted files/extensions for public assets
EXCLUDED_EXTENSIONS = {'.png', '.jpg', '.jpeg', '.ttf', '.otf', '.woff', '.woff2', '.ico'}
EXCLUDED_PATTERNS = [
    # Mock strings in unit tests or comments that describe secret prohibitions
    re.compile(r'mock-test-anon-key'),
    re.compile(r'test/'),
]

def scan_file(filepath: str) -> list[str]:
    ext = os.path.splitext(filepath)[1].lower()
    if ext in EXCLUDED_EXTENSIONS:
        return []

    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
    except Exception as e:
        return [f"Could not read {filepath}: {e}"]

    findings = []
    # Skip checking service_role in supabase/functions backend code if scanned
    is_backend = "supabase/functions" in filepath

    for pattern, desc in SECRET_PATTERNS:
        if is_backend and 'service_role' in desc.lower():
            continue  # Backend Edge Functions legitimately use service_role from Deno.env

        matches = pattern.findall(content)
        if matches:
            # Check for false positives / test mocks
            findings.append(f"[{filepath}] Potential secret leak: {desc}")

    return findings

def main():
    print("==================================================")
    print(" YELLOWSHIFTS CLIENT BUNDLE & SOURCE SECRET AUDIT ")
    print("==================================================")

    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    total_files_scanned = 0
    all_findings = []

    for target_dir in SEARCH_DIRS:
        abs_target = os.path.join(root_dir, target_dir)
        if not os.path.exists(abs_target):
            print(f"[-] Directory {target_dir} not found (may not be built yet).")
            continue

        for root, _, files in os.walk(abs_target):
            for file in files:
                filepath = os.path.join(root, file)
                rel_path = os.path.relpath(filepath, root_dir)
                total_files_scanned += 1
                findings = scan_file(filepath)
                all_findings.extend(findings)

    print(f"[*] Scanned {total_files_scanned} files across target directories.")

    if all_findings:
        print(f"\n[!] SECURITY VIOLATION: {len(all_findings)} issues detected:")
        for f in all_findings:
            print(f"  - {f}")
        sys.exit(1)
    else:
        print("[+] SUCCESS: Zero private credentials or service_role secrets found in client bundles.")
        sys.exit(0)

if __name__ == "__main__":
    main()
