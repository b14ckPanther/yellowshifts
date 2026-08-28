#!/usr/bin/env python3
"""
YellowShifts Phase 10.5 — Platform Admin Edge Function contract tests.

Runtime JWT invocation requires a live Supabase Functions host. This suite
statically verifies every required authorization, validation, and sanitization
branch in the function sources so CI can fail closed without Deno.
"""

import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FN = os.path.join(ROOT, "supabase", "functions")


def load(name: str) -> str:
    path = os.path.join(FN, name, "index.ts")
    with open(path, encoding="utf-8") as f:
        return f.read()


def main():
    passed = 0
    total = 0

    def ok(name, cond, details=""):
        nonlocal passed, total
        total += 1
        print(f"  [{'PASS' if cond else 'FAIL'}] {total:02d}: {name}" + ("" if cond else f" - {details}"))
        if cond:
            passed += 1

    create = load("platform-create-station")
    assign = load("platform-assign-station-admin")
    remove = load("platform-remove-station-admin")
    admin_create = load("admin-create-employee")
    admin_update = load("admin-update-employee")

    for src, label in (
        (create, "platform-create-station"),
        (assign, "platform-assign-station-admin"),
        (remove, "platform-remove-station-admin"),
    ):
        ok(f"{label} rejects missing Authorization", "Missing Authorization header" in src)
        ok(f"{label} rejects invalid/expired session", "Invalid or expired session" in src)
        ok(f"{label} verifies is_platform_admin server-side", 'rpc("is_platform_admin")' in src)
        ok(f"{label} returns NOT_PLATFORM_ADMIN", "NOT_PLATFORM_ADMIN" in src)
        ok(f"{label} does not read isPlatformAdmin from the request body", "body.isPlatformAdmin" not in src and 'isPlatformAdmin:' not in src)
        ok(f"{label} never logs service role key", "console.log(supabaseServiceKey)" not in src)
        ok(f"{label} sanitizes JSON parse failures", "req.json().catch" in src or "catch (() => ({}))" in src)

    ok("create-station requires name and code", "Station name and code are required" in create)
    ok("create-station uses service role only server-side", "SUPABASE_SERVICE_ROLE_KEY" in create)
    ok("create-station compensating cleanup on auth user", "createdAuthUserId" in create)
    ok("create-station looks up existing users via platform_lookup_user_by_email", "platform_lookup_user_by_email" in create)
    ok("create-station does not paginate Auth admin.listUsers for identity", "listUsers" not in create)
    ok("assign-station-admin requires station_id", "station_id is required" in assign)
    ok("remove-station-admin requires reason", "reason are required" in remove)
    ok("admin-create-employee rejects ADMIN with P00105", "P00105" in admin_create and '["SHIFT_MANAGER", "EMPLOYEE"]' in admin_create)
    ok("admin-create-employee allows PLATFORM_ADMIN without membership", 'rpc("is_platform_admin")' in admin_create)
    ok("admin-update-employee rejects ADMIN grant/revoke", "P00105" in admin_update)
    ok("admin-update-employee allows PLATFORM_ADMIN without membership", 'rpc("is_platform_admin")' in admin_update)
    ok("no function reads isPlatformAdmin from request body", all("body.isPlatformAdmin" not in s for s in (create, assign, remove)))

    print(f"\n[+] Phase 10.5 Edge Function contracts: {passed}/{total} passed")
    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
