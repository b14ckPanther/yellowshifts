-- YellowShifts Phase 1 Real PostgreSQL RLS Adversarial Test Suite
-- Executes migrations and runs attack matrix against true PostgreSQL 16 RLS engine

BEGIN;

-- 1. Create fresh testing schema environment
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
CREATE SCHEMA IF NOT EXISTS auth;

-- 2. Setup auth.users stub table
DROP TABLE IF EXISTS auth.users CASCADE;
CREATE TABLE auth.users (
    id UUID PRIMARY KEY,
    email TEXT,
    raw_user_meta_data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Context function for auth.uid()
CREATE OR REPLACE FUNCTION auth.uid()
RETURNS UUID AS $$
BEGIN
    RETURN NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid;
END;
$$ LANGUAGE plpgsql STABLE;

-- Context function for auth.role()
CREATE OR REPLACE FUNCTION auth.role()
RETURNS TEXT AS $$
BEGIN
    RETURN COALESCE(NULLIF(current_setting('request.jwt.claim.role', true), ''), 'anon');
END;
$$ LANGUAGE plpgsql STABLE;

-- 3. Apply Phase 0 Schema Migration
\i supabase/migrations/20260825000001_initial_schema.sql

-- 4. Apply Phase 1 Schema Migration
\i supabase/migrations/20260825000002_phase1_identity_and_roles.sql

-- 5. Create Test Roles (matching Supabase anon and authenticated)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated NOLOGIN;
    END IF;
END $$;

GRANT USAGE ON SCHEMA public, auth TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public, auth TO authenticated, anon;
REVOKE UPDATE, DELETE ON public.audit_logs FROM authenticated, anon, PUBLIC;

-- 6. Seed Test Fixtures
-- Users
INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES
('11111111-1111-1111-1111-111111111111', 'user.a@station-a.com', '{"first_name":"User","last_name":"A"}'),
('22222222-2222-2222-2222-222222222222', 'user.b@station-b.com', '{"first_name":"User","last_name":"B"}'),
('33333333-3333-3333-3333-333333333333', 'admin.a@station-a.com', '{"first_name":"Admin","last_name":"A"}'),
('44444444-4444-4444-4444-444444444444', 'admin.b@station-b.com', '{"first_name":"Admin","last_name":"B"}'),
('55555555-5555-5555-5555-555555555555', 'user.c@station-c.com', '{"first_name":"User","last_name":"C"}'),
('66666666-6666-6666-6666-666666666666', 'inactive@station-a.com', '{"first_name":"Inactive","last_name":"User"}'),
('77777777-7777-7777-7777-777777777777', 'admin.a2@station-a.com', '{"first_name":"Admin2","last_name":"A"}');

-- Stations
INSERT INTO public.stations (id, name, code, timezone, locale, week_start, is_active) VALUES
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Station Alpha', 'STA-A', 'Asia/Jerusalem', 'he', 0, true),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Station Beta', 'STA-B', 'Asia/Jerusalem', 'he', 0, true),
('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Station Gamma', 'STA-C', 'Asia/Jerusalem', 'he', 0, true);

-- Memberships
-- User A: EMPLOYEE in Station A, SHIFT_MANAGER in Station B
INSERT INTO public.station_memberships (station_id, user_id, role, status, employee_code) VALUES
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'EMPLOYEE', 'ACTIVE', 'EMP-001'),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', 'SHIFT_MANAGER', 'ACTIVE', 'MGR-001'),
-- User B: EMPLOYEE in Station B
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', 'EMPLOYEE', 'ACTIVE', 'EMP-002'),
-- Admin A: ADMIN in Station A
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-333333333333', 'ADMIN', 'ACTIVE', 'ADM-001'),
-- Admin B: ADMIN in Station B
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '44444444-4444-4444-4444-444444444444', 'ADMIN', 'ACTIVE', 'ADM-002'),
-- User C: EMPLOYEE in Station C
('cccccccc-cccc-cccc-cccc-cccccccccccc', '55555555-5555-5555-5555-555555555555', 'EMPLOYEE', 'ACTIVE', 'EMP-003'),
-- Inactive User: INACTIVE in Station A
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '66666666-6666-6666-6666-666666666666', 'EMPLOYEE', 'INACTIVE', 'EMP-004');

COMMIT;
