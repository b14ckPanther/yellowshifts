# Shift Templates Architecture & Operational Configuration

## Overview
YellowShifts implements dynamic, station-defined shift templates rather than hardcoding fixed shifts (e.g., Morning, Evening, Night). Each station administrator can define any number of daily operational shifts according to the station's operational needs.

---

## Data Model & Constraints (`shift_templates`)

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | UUID | PRIMARY KEY, DEFAULT `gen_random_uuid()` | Unique shift template identifier |
| `station_id` | UUID | NOT NULL, REFERENCES `stations(id)` ON DELETE CASCADE | Scoped station identifier |
| `name` | TEXT | NOT NULL | Shift name (e.g., "Morning", "Night", "Shift A") |
| `code` | TEXT | UNIQUE per station (case-insensitive) | Optional 1-3 letter short identifier (e.g. "M", "E", "N") |
| `start_time` | TIME | NOT NULL | Shift start time |
| `end_time` | TIME | NOT NULL | Shift end time |
| `sort_order` | INTEGER | NOT NULL DEFAULT 0 | Ordering index within station |
| `is_active` | BOOLEAN | NOT NULL DEFAULT true | Active status for availability periods |
| `created_at` | TIMESTAMPTZ | NOT NULL DEFAULT UTC now | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL DEFAULT UTC now | Auto-updated via trigger |

### Business Rules & Constraints
1. **Zero-Duration Rejection**: `CONSTRAINT chk_shift_template_non_zero_duration CHECK (start_time <> end_time)` rejects invalid 0-duration templates.
2. **Cross-Midnight Duration**: Shifts that cross midnight (e.g. `23:00 -> 07:00`) are supported without arbitrary 8h or 12h caps.
   - Standard daytime duration: `end_time - start_time`
   - Cross-midnight duration: `(24 hours - start_time) + end_time`
3. **Station Scoping**: All operations, unique codes, and ordering are strictly isolated per station.
4. **Soft Deactivation**: Historical shifts are soft-deactivated (`is_active = false`) so historical availability periods referencing the templates remain intact.

---

## Server RPC Functions

### `admin_manage_shift_template`
Handles transactional creation, editing, deactivation, and reactivation with authorization checks (`shift_templates.manage` permission or `ADMIN` role):
- Validates non-empty name, valid times, non-zero duration.
- Generates immutable audit logs (`SHIFT_TEMPLATE_CREATED`, `SHIFT_TEMPLATE_UPDATED`, `SHIFT_TEMPLATE_DEACTIVATED`, `SHIFT_TEMPLATE_REACTIVATED`).

### `admin_reorder_shift_templates`
Performs atomic reordering of shift templates within a station without unique constraint collisions or swap deadlocks.

---

## Mobile & Desktop UX
- **Mobile (`Compact`)**: Responsive card with grip handle, drag-to-reorder list, duration pill, and action buttons.
- **Tablet/Desktop (`Medium`/`Expanded`)**: Dense operational view with inline time range, duration badge, active toggle, and edit modal.
- **RTL Support**: Full bidirectional support with Hebrew & English number and time localization.
