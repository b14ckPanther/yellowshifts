# YellowShifts — Public GitHub Publication Manifest

Review performed before the first commit to `https://github.com/b14ckPanther/yellowshifts` (public).

This file does **not** record secret values.

## PUBLIC SOURCE

Entire application, schema, tests, and operational documentation unless listed below.

| Path | Reason |
| :--- | :--- |
| `lib/` | Flutter application |
| `supabase/migrations/` (`001`–`019` and `20260828000001`) | Schema is public source. Security does not depend on hiding SQL. `20260828000001` is source-controlled and **not deployed** (KIOSK FIX SAFE TO DEFER). |
| `supabase/functions/` | Edge Functions; service-role is read from the environment only |
| `supabase/config.toml`, `supabase/.gitignore` | Project config without private keys |
| `test/` | Flutter and PostgreSQL suites |
| `scripts/` | Scanners and operator helpers (no embedded private credentials) |
| `.github/workflows/ci.yml` | CI gates; CI Postgres password is a local service fixture |
| `android/`, `ios/`, `web/`, `assets/` | Client shells and fonts (licenses included). Gradle wrapper (`gradlew`, `gradle-wrapper.jar`) is public source. |
| `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `l10n.yaml`, `.metadata` | Package identity `1.0.5+11` |
| `.env.example` | Placeholders / dummy anon token only |
| `docs/*.md` (except sanitization notes below) | Architecture, RLS, runbooks, phase audits |
| `implementation_plan.md` | Historical implementation plan |
| `walkthrough.md` | Phase 10.5 walkthrough |
| `README.md` | Public project overview |
| `lib/app/config/app_config.dart` | Contains the **public** Supabase URL and anon (publishable) JWT default. This is a client key, not `service_role`. |

Migrations `001`–`019` were **not** rewritten for publication. No applied migration logic was changed.

## PUBLIC AFTER SANITIZATION

| Path | Action (no secret values recorded) |
| :--- | :--- |
| Multiple `docs/*.md`, `walkthrough.md`, `implementation_plan.md` | Replaced absolute local machine paths and `file://` links (including an agent-workspace CI path) with repository-relative links; replaced unnecessary production project-ref URLs with `<YOUR_SUPABASE_PROJECT_REF>` |
| `test/sql/run_phase*.py` (several suites) | Replaced hardcoded machine `MIGRATIONS_DIR` and Homebrew `psql` paths with repo-relative / `PATH` lookup so CI and other machines can run them |
| `supabase/seed.sql` | Replaced local-dev fixture password with an obviously non-production fixture; emails remain `*.yellowshifts.local` |
| `docs/PHASE-10-PRODUCTION-READINESS.md` | Added a historical-snapshot banner so Phase 10 figures (277 tests, schema 017) are not read as the current certified identity |
| `docs/PRODUCTION_DEPLOYMENT.md` | Removed stale test-count claims from the pipeline diagram |
| `docs/BACKUP_AND_RESTORE.md` | Clarified schema reconstruction vs unproven production restore; documented deferred kiosk migration in source vs remote |
| `docs/DEVELOPMENT.md` | Documented copying `.env.example` instead of implying a committed `.env` |

## PRIVATE / EXCLUDED

Never staged. Enforced by `.gitignore` and/or publication policy.

| Path | Reason |
| :--- | :--- |
| `.env` | Local environment; may contain real project anon key and must not be committed |
| `supabase/.temp/` | Linked-project metadata and local CLI cache |
| `.idea/`, `*.iml` | IDE local state |
| `android/local.properties` | Machine Flutter SDK path (`android/.gitignore`) |
| iOS generated Flutter files (`Generated.xcconfig`, `ephemeral/`, `flutter_export_environment.sh`) | `ios/.gitignore` |

No production `SUPABASE_SERVICE_ROLE_KEY`, database password, CRON_SECRET, PAT, or private key file was found in files intended for Git.

## TEMPORARY / EXCLUDED

| Path | Reason |
| :--- | :--- |
| `.dart_tool/` | Dart tooling cache |
| `build/` | Flutter build output |
| `coverage/` | Test coverage output |
| `.flutter-plugins`, `.flutter-plugins-dependencies` | Generated plugin lists |

## Notes

- `.cursor/` is not present in this repository; it was not ignored as a blanket rule.
- `.vscode/` is ignored; there is no shared VS Code project config to publish.
- `lib/app/config/app_config.dart` keeps the public project URL because the client requires a default HTTPS endpoint. Docs no longer repeat that identifier where an example placeholder is enough.
- CI `POSTGRES_PASSWORD: password` is the GitHub Actions service container fixture, not a production database password.
