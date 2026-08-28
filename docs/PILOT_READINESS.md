# YellowShifts — Controlled Real-Station Pilot Readiness Guide

## 1. Pilot Purpose & Scope

The objective of Phase 10 was to prepare YellowShifts for a **Controlled Real-Station Pilot**. Phase 10.5 adds Platform Administration so stations can be provisioned in-app **before** that pilot.

**The real-station pilot is not started and is not complete.**

Pilot onboarding of new stations should use Platform Administration → Create Station (see [`STATION_PROVISIONING.md`](STATION_PROVISIONING.md)), not the Supabase Table Editor.

Phase 10.5 independent audit is complete. Remaining before the **controlled real-station pilot**: first Platform Admin bootstrap, operational smoke of platform Edge Functions, and real-device kiosk checks. MFA is strongly recommended for Platform Admin before **broad production rollout** (not a pre-pilot certification blocker).

- **Target Pilot Size**: 1–2 physical stations.
- **Target User Volume**: ~20–50 active employees per station.
- **Pilot Duration**: 2–4 consecutive operational weeks.
- **Primary Operational Focus**:
  - Employee shift scheduling and availability submission.
  - Daily kiosk dynamic QR check-in and check-out.
  - Exception handling (forgotten check-outs, shift trades, attendance corrections).
  - Shift manager operational overview and PDF/CSV reporting exports.

---

## 2. Pilot Station Onboarding Workflow

1. **Station Profile Setup**:
   - Provision Station Name (e.g., "Station HaSharon 01"), station code, and late grace minutes policy.
2. **Shift Templates Definition**:
   - Define canonical station shifts (e.g. Morning: 07:00–15:00, Evening: 15:00–23:00, Night: 23:00–07:00).
3. **Kiosk Hardware Setup**:
   - Mount tablet at entrance with continuous power.
   - Open kiosk mode URL in fullscreen browser.
   - Verify dynamic QR challenge rotation every 30 seconds.
4. **Employee Provisioning**:
   - Admin imports or registers employee roster using the Employees Screen.
   - Issue temporary passwords or magic login links.
   - Instruct employees to install PWA on their mobile devices (iOS Safari "Add to Home Screen" or Android Chrome "Install App").
5. **Pilot Success Metrics**:
   - Check-in latency < 2 seconds at kiosk.
   - Zero double-check-in collisions.
   - Zero cross-station data leakage.
   - Zero payroll calculations (pure attendance hours verification).
