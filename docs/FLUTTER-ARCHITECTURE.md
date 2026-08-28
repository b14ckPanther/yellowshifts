# YellowShifts — Flutter Frontend Architecture

This document describes the architectural patterns, state management lifecycle, folder conventions, and presentation patterns used across the YellowShifts Flutter application.

---

## 1. Directory Structure

```
lib/
├── app/
│   ├── app.dart                        # Root YellowShiftsApp widget
│   ├── bootstrap.dart                  # Async initialization (Supabase, Config, Error handling)
│   ├── config/
│   │   └── app_config.dart             # Environment config (Supabase URL, Anon Key, Flavors)
│   ├── localization/
│   │   ├── app_localizations.dart      # Generated localization wrapper
│   │   └── locale_provider.dart        # Riverpod locale state provider
│   └── routing/
│       ├── app_router.dart             # GoRouter configuration & route definitions
│       ├── route_guards.dart           # Auth & Station context navigation guards
│       └── shell/
│           ├── adaptive_app_shell.dart # Size-class shell switcher
│           ├── compact_app_shell.dart  # Mobile bottom nav & header layout
│           ├── medium_app_shell.dart   # Tablet NavigationRail & split layout
│           └── expanded_app_shell.dart # Desktop sidebar & dense workspace layout
│
├── core/
│   ├── auth/
│   │   ├── auth_repository.dart        # Supabase Auth interface and implementation
│   │   └── auth_state_provider.dart    # Riverpod session & user state
│   ├── design_system/
│   │   ├── components/                 # Reusable UI primitives (AppButton, AppTextField, etc.)
│   │   ├── motion/                     # Motion tokens, durations, and curves
│   │   ├── responsive/                 # Breakpoints, SizeClass, AdaptiveBuilder
│   │   ├── theme/                      # AppTheme & ThemeData generator
│   │   ├── tokens/                     # Semantic color, spacing, radius, typography tokens
│   │   └── typography/                 # Locale-aware typography system
│   ├── errors/
│   │   ├── app_exception.dart          # Domain failure hierarchy
│   │   └── error_handler.dart          # Error mapping from Supabase/PostgREST
│   ├── permissions/
│   │   └── station_permissions.dart    # Station-scoped capability calculation
│   ├── realtime/
│   │   └── realtime_subscription_manager.dart # Scoped channel lifecycle manager
│   ├── supabase/
│   │   └── supabase_client_provider.dart # Supabase instance injection
│   └── utils/
│       └── directionality_utils.dart   # RTL/LTR numeric and text formatting helpers
│
├── features/
│   ├── authentication/
│   │   └── presentation/login_screen.dart # Login & credential flow
│   ├── dashboard/
│   │   └── presentation/dashboard_screen.dart # Station dashboard & metrics foundation
│   ├── dev_preview/
│   │   └── presentation/design_system_preview_screen.dart # UI component catalog (Dev only)
│   ├── employees/
│   │   └── presentation/employees_screen.dart # Employee directory foundation
│   ├── schedule/
│   │   └── presentation/schedule_screen.dart # Schedule workspace foundation
│   ├── attendance/
│   │   └── presentation/attendance_screen.dart # Attendance roster foundation
│   ├── settings/
│   │   └── presentation/settings_screen.dart # User & Station settings
│   └── stations/
│       ├── data/
│       │   ├── station_repository.dart        # Station fetch & query operations
│       │   └── membership_repository.dart     # Membership fetch & real-time sync
│       ├── domain/
│       │   ├── station.dart                   # Station immutable entity
│       │   └── station_membership.dart        # Membership entity & role enum
│       └── presentation/
│           ├── active_station_provider.dart   # Current active station state
│           ├── station_selector_screen.dart   # Multi-station chooser
│           └── widgets/app_station_switcher.dart # Header station context switch menu
│
├── l10n/
│   ├── app_en.arb                      # English ARB translations
│   └── app_he.arb                      # Hebrew ARB translations
│
└── shared/
    ├── models/
    │   └── user_profile.dart           # User profile domain entity
    └── widgets/
        ├── app_empty_state.dart        # Standard empty state component
        ├── app_error_state.dart        # Standard error state component
        └── app_skeleton.dart           # Shimmer loading skeleton
```

---

## 2. State Ownership & Riverpod Layering

The application strictly separates data sources, domain repositories, state controllers, and presentation widgets:

```
[Presentation Widgets]
       │
       ▼ (read / watch)
[Riverpod Providers / Notifiers] (e.g. activeStationProvider, userMembershipsProvider)
       │
       ▼ (calls domain operations)
[Repository Layer] (e.g. StationRepository, AuthRepository)
       │
       ▼ (invokes Supabase SDK / PostgREST)
[Supabase Client & Realtime WebSockets]
```

### Key Principles:
1. **Widgets never call `Supabase.instance.client` directly**.
2. **Errors are converted into typed `AppFailure` objects** at the repository boundary before reaching Riverpod controllers.
3. **Station-scoped providers automatically invalidate and dispose** when the active station is switched, preventing stale data leaks between stations.
