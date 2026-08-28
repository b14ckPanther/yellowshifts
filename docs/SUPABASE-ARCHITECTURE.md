# YellowShifts — Supabase Architecture

This document describes the backend architecture, PostgreSQL modeling, Row Level Security (RLS) enforcement, database triggers, Edge Functions strategy, and real-time subscription lifecycle.

---

## 1. Core Supabase Services

YellowShifts relies strictly on the following Supabase platform services:
1. **Supabase Auth**: JWT-based authentication for email/password and future SSO/magic link authentications. Linked 1:1 with `public.profiles`.
2. **PostgreSQL Database**: Relational schema with strict foreign keys, enums, triggers, and constraints.
3. **Row Level Security (RLS)**: Mandatory multi-tenant isolation policies running in PostgreSQL kernel.
4. **Database Functions & RPC**: High-performance PL/pgSQL security evaluators (`is_station_member`, `is_station_admin`, `is_station_manager_or_admin`).
5. **Realtime**: Postgres logical replication over WebSockets for live station roster and membership changes.
6. **Edge Functions (Planned for Phase 1+)**: Privileged serverless operations executed with the `service_role` secret (e.g. employee onboarding, password resets, attendance verification).

---

## 2. Environment Strategy

YellowShifts maintains strict separation between environments:

| Setting | Development (Local) | Staging | Production |
| :--- | :--- | :--- | :--- |
| **Supabase Host** | `http://127.0.0.1:54321` | `https://staging-project.supabase.co` | `https://prod-project.supabase.co` |
| **Auth Expiry** | 3600s | 3600s | 3600s |
| **Realtime** | Enabled | Enabled | Enabled |
| **Seed Fixtures** | `supabase/seed.sql` | Controlled Staging Seed | Empty (Production) |
| **Service Role Key** | Server CLI only | GitHub Secrets / Cloudflare | GitHub Secrets / Supabase Vault |

---

## 3. Privileged Operations Strategy

Privileged operations requiring the `service_role` key (such as provisioning an employee account with temporary credentials or resetting an employee's password) are NEVER executed directly from Flutter via client-side libraries. 

Instead, they follow the server-authoritative pattern:
```
[Flutter Client] 
     │ (Authenticated HTTPS request with user JWT)
     ▼
[Supabase Edge Function / RPC]
     │ (1. Validates caller is Station Admin via RLS / JWT metadata)
     │ (2. Executes Auth Admin API or privileged SQL)
     │ (3. Emits immutable audit log entry)
     ▼
[PostgreSQL Database]
```
