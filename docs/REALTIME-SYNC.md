# YellowShifts — Realtime Synchronization Architecture

This document describes the scoped Realtime channel architecture, subscription ownership, optimistic updates policy, and network reconnection handling across all system phases.

---

## 1. Scoped Subscription Ownership

To prevent cross-tenant data leaks and unnecessary network load, the application never subscribes globally across all stations. Realtime channels are strictly filtered and scoped.

### Subscription Scoping Rules:
1. **User Scope**: Realtime subscription listening to changes on `public.profiles` for `id = auth.uid()`.
2. **Station Scope**: When an active station is selected (`activeStationIdProvider`), a dedicated Realtime channel `station:attendance:{stationId}` is instantiated.
3. **Table Scopes**:
   - `public.attendance_records` (Filter: `station_id=eq.{stationId}`): Listens for `INSERT` (check-in) and `UPDATE` (check-out/correction) events to invalidate `managerLiveAttendanceProvider` and `myAttendanceHistoryProvider`.
   - `public.kiosk_devices` (Filter: `station_id=eq.{stationId}`): Listens for heartbeats, status changes, and newly provisioned kiosks to update `kioskDevicesProvider`.
4. **Station Switching Lifecycle**:
   - When switching from Station A to Station B:
     1. Unsubscribe and destroy Realtime channel for Station A.
     2. Invalidate station-scoped cached Riverpod provider states.
     3. Instantiate new Realtime channel for Station B.
     4. Fetch fresh authoritative state from PostgreSQL RPCs.

```
[Active Station: Station A] ──────► [Unsubscribe Channel A]
                                           │
                                           ▼ (Dispose A's providers)
                                    [Switch Active Station ID]
                                           │
                                           ▼ (Initialize B's providers)
[Active Station: Station B] ◄────── [Subscribe Channel B with station filter]
```

---

## 2. Optimistic UX Policy

- **Allowed Optimistic Operations**:
  - Local tab selection, UI filters, theme/locale preference toggles, calendar navigation.
- **Prohibited Optimistic Operations (Server Authority Required)**:
  - Attendance check-in / check-out. (Requires cryptographic presence proof verification and returned open session ID).
  - Manual attendance record corrections. (Requires server-side duration, reason validation, and ledger commit).
  - Kiosk provisioning and credential rotation. (Requires server cryptographic random secret generation).
  - Schedule publication and availability submissions.

---

## 3. Ephemeral Sync & Heartbeats

- **Kiosk Active Sync**: Kiosk devices authenticate and mint rotating dynamic QR challenges every 25 seconds via `kiosk_authenticate_and_mint_qr`.
- **Server Heartbeat**: Each successful challenge minting automatically updates `kiosk_devices.last_seen_at = now()`. Devices with `last_seen_at < now() - INTERVAL '3 minutes'` transition to `Offline / Idle` on manager dashboards.
