# YellowShifts — Architecture Overview

YellowShifts is a multi-station workforce operations platform designed to deliver real-time operational coordination, scheduling, availability management, and attendance verification across multiple physical stations.

---

## 1. System Philosophy & Principles

1. **Station-Scoped Multi-Tenancy from Day Zero**:
   Every operational entity (schedules, attendance, shifts, employee roles) belongs to a distinct station. A user identity is global, but authorization and operational data are strictly station-scoped.
2. **Server-Authoritative Supabase Core**:
   The Flutter client acts as a responsive, reactive presentation layer. PostgreSQL, Row Level Security (RLS), and database functions/triggers serve as the authoritative security boundary. The client never executes privileged mutations directly.
3. **Zero Mock Data Architecture**:
   The frontend communicates strictly with live Supabase backends. Empty states are explicitly designed as first-class UI components for zero-data conditions.
4. **Adaptive Multi-Platform Shell**:
   Rather than stretching or shrinking layouts, YellowShifts provides intentional information architectures across size classes:
   - **Compact (< 600px)**: Mobile-native navigation, bottom sheets, full-screen detail flows.
   - **Medium (600px – 1024px)**: Tablet NavigationRail, master/detail split views, operational inspection panes.
   - **Expanded (> 1024px)**: Desktop persistent navigation, dense multi-column operational boards, keyboard workflows.
5. **Fluid Motion & Reactive Synchronization**:
   Real-time channels synchronize live state changes directly into fine-grained Riverpod providers, animating affected records without blocking user interaction or causing full-page reloads.

---

## 2. High-Level Architecture Diagram

```
                                    +-----------------------------------+
                                    |        YellowShifts Flutter       |
                                    |    (iOS / Android / Web Apps)     |
                                    +-----------------+-----------------+
                                                      |
                               +----------------------+----------------------+
                               |                                             |
                     [REST / PostgREST APIs]                             [WebSockets]
                     HTTPS Queries & Mutations                    Supabase Realtime Engine
                               |                                             |
                               +----------------------+----------------------+
                                                      |
                                                      v
                                    +-----------------------------------+
                                    |          Supabase Core            |
                                    +-----------------------------------+
                                    | • Supabase Auth (JWT Verification)|
                                    | • Row Level Security (RLS Engine) |
                                    | • PostgreSQL 15 Engine            |
                                    | • PL/pgSQL Triggers & RPC         |
                                    | • Realtime Change Data Capture    |
                                    +-----------------+-----------------+
                                                      |
                   +----------------------------------+----------------------------------+
                   |                                  |                                  |
                   v                                  v                                  v
        +---------------------+            +---------------------+            +---------------------+
        |      Station A      |            |      Station B      |            |      Station N      |
        |  (Galil Central)    |            |  (Negev Operations) |            |   (Future Station)  |
        +---------------------+            +---------------------+            +---------------------+
        | • Admins            |            | • Admins            |            | • Admins            |
        | • Shift Managers    |            | • Shift Managers    |            | • Shift Managers    |
        | • Employees         |            | • Employees         |            | • Employees         |
        | • Memberships       |            | • Memberships       |            | • Memberships       |
        | • Operational State |            | • Operational State |            | • Operational State |
        +---------------------+            +---------------------+            +---------------------+
```

---

## 3. Technology Stack Summary

| Layer | Technology | Primary Function |
| :--- | :--- | :--- |
| **Frontend Framework** | Flutter (Dart 3+) | Cross-platform client for iOS, Android, and Web |
| **State Management** | Flutter Riverpod | Reactive state, dependency injection, station-scoped caching |
| **Routing & Deep Linking** | go_router | Declarative path routing, auth guards, shell routes |
| **Design System** | Custom Semantic Tokens | Strict design token mapping from official station brand palette |
| **Typography** | Google Fonts (Ubuntu, Heebo) | Locale-aware font family switching (English LTR / Hebrew RTL) |
| **Icons** | Lucide Icons (Flutter) | Consistent, modern vector iconography (0 emojis) |
| **Backend & DB** | Supabase / PostgreSQL 15 | Relational storage, Auth, Realtime CDC, RLS policies |
| **Security Layer** | Row Level Security (RLS) | Tenant isolation, station membership authorization, self-promotion defense |

---

## 4. Key Security Boundaries

- **Public Client Boundary**: The Flutter application is distributed with only public anonymous credentials (`SUPABASE_URL`, `SUPABASE_ANON_KEY`).
- **Zero Service-Role Exposure**: The PostgreSQL `service_role` key is strictly excluded from client builds, code repositories, and frontend runtime environments.
- **Tenant Isolation**: Direct queries to Supabase PostgREST tables are evaluated against Postgres RLS policies based on `auth.uid()`. Cross-station data retrieval returns empty sets or throws permission violations at the database engine level.
