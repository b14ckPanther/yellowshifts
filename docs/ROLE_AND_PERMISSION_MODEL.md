# YellowShifts — Role and Permission Model (Phase 10.5)

Internal enum `ADMIN` is unchanged. The UI label for station `ADMIN` is **Station Manager**.

`PLATFORM_ADMIN` is global. Station roles remain tenant-scoped.

## Permission matrix

| Action | PLATFORM_ADMIN | Station ADMIN | SHIFT_MANAGER | EMPLOYEE |
| :--- | :---: | :---: | :---: | :---: |
| Create station | YES | NO | NO | NO |
| Edit station (platform RPC) | YES | NO | NO | NO |
| Deactivate / reactivate station | YES | station settings per existing rules | NO | NO |
| View all stations / platform overview | YES | NO | NO | NO |
| Assign / revoke Station Manager (`ADMIN`) | YES | NO | NO | NO |
| Create employee | YES* | YES | NO | NO |
| Create Shift Manager | YES* | YES | NO | NO |
| EMPLOYEE ↔ SHIFT_MANAGER | YES* | YES | NO | NO |
| Promote to Station Admin | YES | NO | NO | NO |
| Manage PLATFORM_ADMIN accounts | trusted SQL only | NO | NO | NO |
| Manage schedules | YES* | YES | per delegated permissions | NO |
| Attendance admin / corrections | YES* | YES | per delegated permissions | NO |
| View own schedule / hours / availability | YES* | YES | YES | YES |
| Access `/platform/*` | YES | NO | NO | NO |
| Open any station (operating context) | YES | own stations only | own stations only | own stations only |

\* When the Platform Admin has explicitly opened that station (operating context). Server helpers treat an **active** Platform Admin as a station operator **only for `auth.uid()`** (no PA-oracle via another UUID). Support RPCs that call `is_station_admin()` allow those operations without a membership row.

## Invariants

1. Platform authorization is **not** stored on `station_memberships`.
2. Station Admin **cannot** grant or revoke `ADMIN` (`P00105`).
3. Last active Station Manager on an active station cannot be removed (`P0001`), including by Platform Admin, unless a defined deactivation workflow applies.
4. Multiple Station Managers per station are allowed.
5. Inactive `platform_admins.is_active = false` loses global privileges immediately; leftover station memberships continue independently.
