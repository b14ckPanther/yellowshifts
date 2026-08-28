# YellowShifts — Development Setup & Tooling Guide

This document contains step-by-step instructions for setting up the local development environment, running tests, executing Supabase migrations, and building Flutter targets.

---

## 1. Prerequisites

- **Flutter SDK**: 3.47+ (Dart 3+)
- **Supabase CLI**: 2.115+
- **Docker**: For running local Supabase containers
- **Node.js**: (Optional for Supabase Edge Functions)
- **Xcode / CocoaPods**: (For iOS builds on macOS)
- **Android Studio / Android SDK**: (For Android builds)

---

## 2. Environment Configuration

Create a `.env` file from the template (never commit `.env`):

```bash
cp .env.example .env
```

`.env.example` uses local placeholders only. Do not put `SUPABASE_SERVICE_ROLE_KEY` or database passwords in Flutter or Git.

```bash
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=eyJh...
```

---

## 3. Local Supabase Setup

1. Start local Supabase containers:
   ```bash
   supabase start
   ```
2. Apply migrations and seed data:
   ```bash
   supabase db reset
   ```
3. Open Supabase Studio:
   `http://localhost:54323`

---

## 4. Running Flutter

### Web:
```bash
flutter run -d chrome --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

### Mobile (iOS / Android):
```bash
flutter run -d ios
# or
flutter run -d android
```

---

## 5. Quality Gate Verification

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter build web --release
```
