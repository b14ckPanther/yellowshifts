# YellowShifts — Platform Admin Bootstrap

The first Platform Admin must be created by a **trusted operational action**. There is no in-app self-promotion, hidden URL, or Station Admin upgrade path.

## What clients must never receive

- `SUPABASE_SERVICE_ROLE_KEY`
- Database passwords
- Ability to `INSERT`/`UPDATE` `public.platform_admins`
- A client-supplied `isPlatformAdmin` flag that the server trusts

`public.platform_admins` has RLS enabled, **no authenticated policies**, and grants only to `service_role`.

## Development / first-ever bootstrap (trusted SQL)

Run as a database owner or via the Supabase SQL editor **after** the target user already exists in `auth.users` and `public.profiles`:

```sql
INSERT INTO public.platform_admins (user_id, is_active, created_by)
VALUES (
  '<existing-auth-user-uuid>',
  true,
  NULL  -- bootstrap: created_by may be null; it must not equal user_id
)
ON CONFLICT (user_id) DO UPDATE
SET is_active = true,
    updated_at = timezone('utc'::text, now());
```

`created_by` cannot equal `user_id` (table check). Bootstrap uses `NULL`.

## Verify

As the bootstrapped user (JWT session):

```sql
SELECT public.is_platform_admin();  -- true
SELECT public.platform_get_overview();  -- succeeds
```

As a Station Admin of any station:

```sql
SELECT public.is_platform_admin();  -- false
SELECT public.platform_get_overview();  -- 42501
```

Confirm **zero** membership rows were created for the Platform Admin:

```sql
SELECT COUNT(*) FROM public.station_memberships WHERE user_id = '<platform-admin-uuid>';
```

## Adding further Platform Admins (Phase 10.5)

There is **no Platform Admin management UI**. Additional operators must be inserted with the same trusted SQL / service-role procedure by an existing operator who already has database access. This is intentional: the role is extremely privileged.

## Disable / revoke

```sql
UPDATE public.platform_admins
SET is_active = false,
    updated_at = timezone('utc'::text, now())
WHERE user_id = '<uuid>';
```

Inactive Platform Admins immediately fail `is_platform_admin()` and all `platform_*` RPCs. Any **independent** station memberships that user holds continue to apply at station scope only.

## Recovery

If every Platform Admin is inactivated:

1. Restore access with the same trusted SQL as bootstrap (`is_active = true`).
2. Do not grant `PLATFORM_ADMIN` through Flutter or Station Admin screens.
3. Rotate the operator's Auth password / revoke sessions after recovery.

## Authorization required

Bootstrap requires **service_role or database owner**, never the Flutter anon key.
