# YellowShifts — Production Release & Go-Live Checklist

This checklist must be reviewed and signed off prior to deploying a new release candidate to production or onboarding a pilot station.

---

## 1. Automated Quality & Security Gates

- [x] **Git Hygiene**: Clean working directory on `main` branch.
- [x] **Dependencies Resolved**: `pubspec.lock` up to date; zero unpinned critical dependencies.
- [x] **Localization Parity**: English (`app_en.arb`) and Hebrew (`app_he.arb`) 100% synchronized with 0 missing keys.
- [x] **Dart Code Formatting**: `dart format --output=none --set-exit-if-changed .` clean.
- [x] **Static Code Analysis**: `flutter analyze` reports 0 errors and 0 warnings.
- [x] **Flutter Unit & Widget Tests**: 277 / 277 tests passing (100%).
- [x] **Web Production Builds**: `flutter build web --release` and `flutter build web --wasm` compiled cleanly.
- [x] **Client Secret Scan**: `python3 scripts/audit_bundle_secrets.py` passed (0 leaked private keys or service_role secrets).
- [x] **Zero-Payroll Scan**: `python3 scripts/verify_zero_payroll.py` passed (0 payroll/wage columns or logic).
- [x] **Database Restore Drill**: `python3 scripts/restore_drill.py` passed (rebuilt 33 tables from scratch).
- [x] **SQL Adversarial & Regression Suites**: 13 suites passed (77 Phase 10 scenarios + all historical regression suites).
- [x] **Database Migrations Synchronized**: Remote Supabase project (`<YOUR_SUPABASE_PROJECT_REF>.supabase.co`) synchronized with canonical migrations 001–017.
- [x] **Edge Functions Deployed**: All 6 Edge Functions deployed and ACTIVE on remote Supabase.
- [x] **Live Schema Compatibility RPC**: Remote `get_platform_schema_version()` endpoint verified live (status `HEALTHY`, schema `20260825000017`).

---

## 2. External Production Prerequisites (Pilot Onboarding)

*The following items require real-world physical hardware or external provider setup and must be verified on-site during pilot onboarding:*

- [ ] **Physical Kiosk Hardware Provisioned**: Dedicated Android/iPad tablet mounted at station entrance with kiosk browser lock.
- [ ] **Station Administrator Onboarded**: First real station admin account created via administrative bootstrap.
- [ ] **Station Shift Templates & Operating Hours Configured**: Morning, Evening, and Night shift templates defined for pilot station.
- [ ] **External Push Notification Provider (FCM / APNs)**: Production FCM / APNs credentials configured if push delivery is required outside web notifications.
- [ ] **Third-Party Identity Verification Provider**: External biometric identity provider API keys provisioned if biometric verification is enabled for pilot.
- [ ] **Pilot Operator Training**: Station admin and shift managers trained on attendance management, QR check-in, and exception handling.
