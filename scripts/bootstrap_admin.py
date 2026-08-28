#!/usr/bin/env python3
"""
YellowShifts Platform Admin bootstrap helper.

This is an operator workstation tool. It is never bundled in Flutter.

Canonical bootstrap is trusted SQL (service_role / database owner) as documented in
docs/PLATFORM_ADMIN_BOOTSTRAP.md. This script does not insert rows and does not
accept the anon key as a substitute for service_role.
"""

import argparse
import os
import sys


def load_env(env_path=".env"):
    env_vars = {}
    if not os.path.exists(env_path):
        return env_vars
    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, val = line.split("=", 1)
                env_vars[key.strip()] = val.strip().strip('"').strip("'")
    return env_vars


def main():
    parser = argparse.ArgumentParser(
        description="Print the trusted SQL required to bootstrap a Platform Admin. Does not mutate production."
    )
    parser.add_argument("--user-id", required=True, help="Existing auth.users UUID to grant PLATFORM_ADMIN")
    args = parser.parse_args()

    env = load_env()
    if env.get("SUPABASE_ANON_KEY") and not env.get("SUPABASE_SERVICE_ROLE_KEY"):
        print(
            "Refusing to proceed: SUPABASE_ANON_KEY cannot bootstrap Platform Admins.",
            file=sys.stderr,
        )
        sys.exit(2)

    print("Canonical bootstrap is trusted SQL, not a public HTTP endpoint.")
    print("Flutter cannot insert into public.platform_admins.")
    print("created_by must remain NULL for first-ever bootstrap (must not equal user_id).")
    print()
    print("Run as database owner / service_role SQL editor:")
    print()
    print(
        f"""INSERT INTO public.platform_admins (user_id, is_active, created_by)
VALUES (
  '{args.user_id}',
  true,
  NULL
)
ON CONFLICT (user_id) DO UPDATE
SET is_active = true,
    updated_at = timezone('utc'::text, now());

-- Verify (as the bootstrapped user's JWT, not as postgres):
--   SELECT public.is_platform_admin();
--   SELECT COUNT(*) FROM public.station_memberships WHERE user_id = '{args.user_id}';
"""
    )
    print("This script did not connect to any database and did not insert any rows.")


if __name__ == "__main__":
    main()
