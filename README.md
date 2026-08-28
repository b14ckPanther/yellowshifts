# YellowShifts

Multi-station workforce scheduling, attendance, operations, and station-management platform.

YellowShifts is built for fuel-station networks that need one product across many sites: station-scoped roles, kiosk QR attendance, schedules, reports, and a global Platform Administration layer for provisioning. It is a Flutter client on a Supabase (PostgreSQL) backend.

YellowShifts does **not** calculate payroll, salary, tax, or wages. Attendance is **not** GPS-based.

## Current Status

**Phase 10.5 Independently Certified — Ready for Pre-Pilot Setup**

- Controlled real-station pilot has **not** started.
- Production launch has **not** happened.
- Real-device / kiosk hardware validation is pending.
- The first Platform Admin has **not** been bootstrapped (`platform_admins` is empty until a trusted operator action).
- MFA is documented and recommended, not implemented.
- External push providers (FCM/APNs) may still be unconfigured.

App release: **1.0.5+11**. Platform version: **1.0.5**. Schema version: **20260825000019**. Minimum compatible client: **1.0.0**.

## Core Capabilities

- Multi-station tenancy with fail-closed isolation
- Station-scoped roles and employee management
- Global Platform Administration and in-app station provisioning
- Weekly availability and shift templates
- Multi-station scheduling and conflict detection
- Kiosk QR attendance, worked-time tracking, and late calculation
- Identity-verification architecture (provider integration is a separate operational step)
- Notification outbox and delivery pipeline
- Attendance reporting, CSV/PDF exports, and audit center
- Station settings, system health, and operational recovery tooling

## Roles

| Role | Scope |
| :--- | :--- |
| **PLATFORM_ADMIN** | Global operator. Stored in `public.platform_admins`, not on `station_memberships`. |
| **ADMIN** (Station Manager) | Station-scoped. May manage **EMPLOYEE ↔ SHIFT_MANAGER** only. |
| **SHIFT_MANAGER** | Station-scoped operational role with delegated permissions. |
| **EMPLOYEE** | Station-scoped self-service. |

**Invariant:** only PLATFORM_ADMIN may grant or revoke station ADMIN. Station Managers cannot promote themselves or others to Station Manager.

## Architecture

- **Client:** Flutter (web PWA, with iOS/Android project shells)
- **Backend:** Supabase — PostgreSQL, Auth, Storage, Edge Functions
- **Authorization:** Row Level Security plus SECURITY DEFINER RPCs; privileged Auth operations run in Edge Functions
- **Identity of callers:** JWT `auth.uid()` on the server. Client flags are not trusted.

## Attendance Model

Physical presence is proven with a station kiosk that broadcasts short-lived QR challenges. Check-in and check-out are server-authoritative. Worked time and lateness are derived from those records.

- No GPS / geofence attendance
- No arbitrary daily hour cap (a 16-hour threshold is anomaly telemetry, not a hard stop)
- One open attendance session per employee at a time

## Platform Administration

Active Platform Admins can create stations, assign/remove Station Managers, deactivate/reactivate stations, and inspect platform health and audit. They do not receive a fake `station_memberships` row. Operating a station is an explicit context.

First Platform Admin bootstrap is a trusted SQL / service-role action. See [`docs/PLATFORM_ADMIN_BOOTSTRAP.md`](docs/PLATFORM_ADMIN_BOOTSTRAP.md).

## Security

YellowShifts is designed fail-closed: station isolation, role-escalation prevention (`P00105`), last-admin protection (`P0001`), pinned `search_path` on SECURITY DEFINER functions, service-role secrets only on the server, audit logging, and automated secret/payroll scanners.

This is not a claim of absolute security. Independent Phase 10.5 audit: [`docs/PHASE-10-5-INDEPENDENT-AUDIT.md`](docs/PHASE-10-5-INDEPENDENT-AUDIT.md).

## Migrations

Remote schema (linked YellowShifts project) has **001–019** applied.

| Migration | Status |
| :--- | :--- |
| `20260825000001`–`20260825000017` | Canonical history; applied remotely |
| `20260825000018_phase10_5_platform_administration.sql` | Phase 10.5 implementation; applied remotely |
| `20260825000019_phase10_5_independent_audit_remediation.sql` | Phase 10.5 audit remediation; applied remotely |
| `20260828000001_fix_kiosk_audit_log_columns.sql` | In source control. **Not deployed.** Audit decision: **KIOSK FIX SAFE TO DEFER**. |

Source-control presence is not the same as deployed state.

## Testing & Quality

Figures below are from the Phase 10.5 independent audit (local execution), not from GitHub Actions until a remote run is inspected.

| Gate | Result |
| :--- | :--- |
| Flutter tests | 310/310 |
| Phase 10.5 independent audit | 87/87 |
| Phase 10.5 security | 36/36 |
| Phase 10.5 comprehensive | 70/70 |
| Edge Function contracts | 33/33 STATIC CONTRACT VERIFIED |
| Historical SQL Phases 1–10 (including V2 suites) | passed in audit |
| `flutter analyze` | clean |
| Web release / WASM builds | pass |
| Secret scan | pass |
| Zero payroll | pass |
| Zero GPS attendance columns | pass |

CI workflow: [`.github/workflows/ci.yml`](.github/workflows/ci.yml). Before the first push the configuration was locally audited only.

## Localization

Hebrew (RTL) and English (LTR), via Flutter gen-l10n (`lib/l10n`).

## Project Structure

```
lib/                  Flutter application
supabase/migrations/  Additive PostgreSQL migrations
supabase/functions/   Edge Functions
test/                 Flutter tests and PostgreSQL audit suites
docs/                 Architecture, operations, and audit records
scripts/              Secret/payroll scanners, restore drill, local helpers
.github/workflows/    CI quality gates
```

## Development Setup

Required:

- Flutter SDK (see `pubspec.yaml`: Flutter `>=3.19.0`, Dart `>=3.3.0`)
- Supabase CLI
- PostgreSQL client (`psql`) for SQL suites
- Python 3.11+ for SQL/CI helper scripts

Optional: Docker for local Supabase; Deno if you serve Edge Functions locally.

```bash
cp .env.example .env
flutter pub get
flutter gen-l10n
```

`.env.example` contains placeholders only. Never put `SUPABASE_SERVICE_ROLE_KEY` or database passwords in Flutter, `.env.example`, or Git.

The public anon key may appear in client configuration. That is not the service-role key.

## Running Locally

See [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md). Typical flow:

```bash
supabase start          # if using local Supabase
flutter run -d chrome --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_ANON_KEY=<local-anon-key>
```

Quality gates:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
python3 scripts/audit_bundle_secrets.py
python3 scripts/verify_zero_payroll.py
```

## CI/CD

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs Flutter format, gen-l10n, analyze, tests, web release, WASM, secret scan, zero-payroll scan, and PostgreSQL security/regression suites including Phase 10.5 independent audit. Mandatory gates do not use `continue-on-error`.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Authorization / RLS](docs/AUTHORIZATION-RLS.md)
- [Role and permission model](docs/ROLE_AND_PERMISSION_MODEL.md)
- [Platform admin architecture](docs/PLATFORM_ADMIN_ARCHITECTURE.md)
- [Platform admin bootstrap](docs/PLATFORM_ADMIN_BOOTSTRAP.md)
- [Station provisioning](docs/STATION_PROVISIONING.md)
- [Security](docs/SECURITY.md)
- [Phase 10.5 independent audit](docs/PHASE-10-5-INDEPENDENT-AUDIT.md)
- [Pilot readiness](docs/PILOT_READINESS.md)
- [Publication manifest](docs/PUBLICATION_MANIFEST.md)
- [Roadmap](docs/ROADMAP.md)

## Roadmap

1. Phase 10.5 independently certified
2. GitHub publication
3. Pre-pilot setup
4. Platform Admin bootstrap
5. Live JWT smoke of platform Edge Functions
6. Real-device validation
7. Controlled real-station pilot
8. Final production certification

## Contributors

- [b14ckPanther](https://github.com/b14ckPanther)
- [lzbedat3](https://github.com/lzbedat3)
