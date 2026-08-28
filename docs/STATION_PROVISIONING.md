# YellowShifts — Station Provisioning

Routine station onboarding is performed by a Platform Admin in the app. The Supabase Table Editor is not required.

## Flow

```
Flutter Create Station
  → Edge Function platform-create-station
  → JWT auth + is_platform_admin()
  → optional Auth user provision (service role)
  → RPC platform_create_station (single PostgreSQL transaction)
  → audit platform.station.created [+ platform.station_admin.assigned]
  → station appears in platform_list_stations
```

## Inputs

| Field | Rules |
| :--- | :--- |
| name | 2–120 characters, trimmed |
| code | Normalized `UPPER(TRIM)` with whitespace stripped; 2–32 chars; `[A-Z0-9][A-Z0-9_-]*`; unique (`P00106`) |
| timezone | IANA name; default `Asia/Jerusalem` (Israeli pilot). Not a fixed UTC offset |
| locale | `he` or `en` (default `he`) |
| week_start | `0` Sunday or `1` Monday |
| initial manager | Existing `user_id` **or** email + first/last name for a new Auth user |

Station defaults (timezone, locale, week start, active flag, grace windows) come from the `stations` table defaults. Flutter does not duplicate a second defaults catalog.

## Idempotency

- Unique station **code** prevents accidental duplicates.
- Optional `idempotency_key` (8–128 chars) stored in `platform_provisioning_keys`, **scoped to the creating Platform Admin**. Same-caller retries return the original station (`idempotent: true`). A different Platform Admin reusing the key fails with `P00107`.
- Existing manager emails are resolved with `platform_lookup_user_by_email` (not Auth `listUsers` pagination).

## Partial failure (Auth vs Postgres)

Auth user creation is outside PostgreSQL. The Edge Function:

1. Creates the Auth user only when an initial manager email is new.
2. Upserts `profiles`.
3. Calls `platform_create_station` with the resolved `user_id`.
4. On RPC failure after Auth create, **deletes** the provisioned Auth user (`auth.admin.deleteUser`) so privileged orphan accounts are not left behind.
5. On profile upsert failure, the Auth user is deleted before returning.

If station insert succeeds and a later step inside the RPC fails, the RPC transaction rolls back. Retry with the same idempotency key or a new unique code.

## Lifecycle

- **Deactivate** (`platform_set_station_active(..., false, reason)`): requires a reason ≥ 3 characters; reuses `admin_update_station` including `P0082` (active attendance). History, memberships, schedules, and audit logs are retained.
- **Reactivate**: same RPC with `is_active = true`. Memberships and history remain.
- **Hard delete** is not a Platform Admin feature.

## Destructive deletion

Do not expose station or user hard-delete in production Platform Administration. Use deactivate / membership status.
