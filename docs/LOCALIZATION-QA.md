# YellowShifts Localization & Typography QA Guide

## 1. Overview & Typography Hierarchy

YellowShifts enforces strict bilingual parity between Hebrew (`he`) and English (`en`):
- **Hebrew (`he`)**: Right-to-Left (RTL), Typography: **Heebo** font family.
- **English (`en`)**: Left-to-Right (LTR), Typography: **Ubuntu** font family.

---

## 2. Localization Parity Matrix

Both `lib/l10n/app_en.arb` and `lib/l10n/app_he.arb` maintain **331 symmetric translation keys** with identical argument placeholders.

### Key Functional Domains Covered:

| Domain | ARB Keys Scope | Verified RTL/LTR Rendering |
| :--- | :--- | :---: |
| **Authentication & Station Select** | `login*`, `stationSelect*` | ✅ |
| **Role Badges & Labels** | `roleAdmin`, `roleShiftManager`, `roleEmployee` | ✅ |
| **Membership Statuses** | `statusActive`, `statusInactive`, `statusSuspended` | ✅ |
| **Navigation & Sections** | `nav*`, `navSection*` | ✅ |
| **Role-Aware Dashboard** | `dashboard*`, `kpi*` | ✅ |
| **Employee Directory & CRUD** | `employees*`, `createEmployee*`, `editEmployee*` | ✅ |
| **Schedule & Shift Management** | `schedule*`, `shiftTemplates*` | ✅ |
| **Attendance & Kiosks** | `attendance*`, `kiosk*` | ✅ |
| **Reports & Hours** | `reports*`, `hours*` | ✅ |
| **Backend & System Errors** | `error*` | ✅ |

---

## 3. Centralized Error Localizer (`ErrorLocalizer`)

All database exception codes, Edge Function codes, and generic errors are resolved through `ErrorLocalizer.localize(error, l10n)`:

| Backend Error Code | Hebrew Translation (`app_he.arb`) | English Translation (`app_en.arb`) |
| :--- | :--- | :--- |
| `P0001` | לא ניתן להסיר או להשבית את מנהל התחנה הפעיל האחרון. | Cannot demote or deactivate the last active Administrator of this station. |
| `23505` | מספר טלפון זה כבר מקושר למשתמש אחר במערכת. | This phone number is already associated with another user account. |
| `42501` | הגישה נדחתה. אין לך הרשאות מתאימות לפעולה זו. | Access denied. You do not have permission to perform this action. |
| `22000` | הנתונים שהוזנו אינם תקינים. אנא בדוק ונסה שנית. | Invalid input data. Please verify and try again. |
| `P0002` | העובד או הרשומה המבוקשת אינם שייכים לתחנה זו. | The requested employee does not belong to this station. |

---

## 4. Directionality & Layout Safety Rules

1. **Directional Padding & Alignment**:
   - Always use `EdgeInsetsDirectional` or symmetrical `AppSpacing` tokens.
   - Use `AlignmentDirectional.centerStart` rather than `Alignment.centerLeft`.
2. **Text Ellipsis on Constrained Row Elements**:
   - All text rendered inside horizontal flex containers must be wrapped in `Expanded` or `Flexible` with `TextOverflow.ellipsis` to prevent overflow across English/Hebrew string lengths.
3. **Numerics & Formatting**:
   - Phone numbers and codes maintain LTR text directionality (`TextDirection.ltr`) even when the parent layout is Hebrew RTL.
