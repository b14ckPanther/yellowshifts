# Shift Manager Capability Overrides Architecture

## Overview
YellowShifts uses a role-based access control system augmented with station-scoped capability overrides for the `SHIFT_MANAGER` role.

Station Administrators always retain full operational and administrative authority across all modules. `EMPLOYEE` roles only receive self-service capabilities. `SHIFT_MANAGER` capabilities can be customized per station by station administrators.

---

## Data Model (`station_shift_manager_permissions`)

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | UUID | PRIMARY KEY, DEFAULT `gen_random_uuid()` | Unique override record ID |
| `station_id` | UUID | NOT NULL, REFERENCES `stations(id)` ON DELETE CASCADE | Station scope |
| `permission` | TEXT | NOT NULL | Permission string identifier |
| `is_enabled` | BOOLEAN | NOT NULL DEFAULT false | Override toggle |
| `created_at` | TIMESTAMPTZ | NOT NULL DEFAULT UTC now | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL DEFAULT UTC now | Auto-updated via trigger |

Unique constraint: `UNIQUE (station_id, permission)`.

---

## Supported Capability Identifiers

| Permission String | Capability Description | Default for Shift Manager |
|---|---|---|
| `shift_templates.manage` | Create, edit, reorder, deactivate shift templates | `false` |
| `availability.period.create` | Create new draft weekly availability periods | `false` |
| `availability.period.open` | Open draft period & freeze snapshots | `false` |
| `availability.period.close` | Close active availability period | `false` |
| `availability.team.read` | View workforce matrix & employee submissions | `true` |
| `shift_templates.read` | View station shift templates | `true` |
| `availability.period.read` | View availability periods | `true` |

---

## Authorization Enforcement & Security

### `has_station_permission(p_station_id, p_user_id, p_permission)`
- Evaluated on server with `SECURITY DEFINER STABLE`.
- Station `ADMIN` always returns `TRUE`.
- Station `SHIFT_MANAGER` resolves active overrides from `station_shift_manager_permissions`, falling back to safe defaults.
- Unknown permission actions resolve safely to `FALSE`.
- Self-escalation and cross-station mutation attempts are rejected with `42501`.

### Row Level Security
- `station_shift_manager_permissions`:
  - `SELECT`: Any active member of the station.
  - `ALL` (INSERT/UPDATE/DELETE): Station Administrators only (`is_station_admin(station_id, auth.uid())`).
