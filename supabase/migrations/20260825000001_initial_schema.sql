-- YellowShifts Phase 0 Initial Schema Migration
-- Greenfield Multi-Station Workforce Operations Platform

-- 0. Ensure Core Auth Schema, Roles, and Functions Exist (Idempotent for Supabase & vanilla PostgreSQL)
CREATE SCHEMA IF NOT EXISTS auth;

CREATE TABLE IF NOT EXISTS auth.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT,
    raw_user_meta_data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);

CREATE OR REPLACE FUNCTION auth.uid()
RETURNS UUID AS $$
BEGIN
    RETURN NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION auth.role()
RETURNS TEXT AS $$
BEGIN
    RETURN COALESCE(NULLIF(current_setting('request.jwt.claim.role', true), ''), 'anon');
END;
$$ LANGUAGE plpgsql STABLE;

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated NOLOGIN;
    END IF;
END $$;

-- 1. Create Enums
CREATE TYPE public.station_role AS ENUM ('ADMIN', 'SHIFT_MANAGER', 'EMPLOYEE');
CREATE TYPE public.membership_status AS ENUM ('ACTIVE', 'INACTIVE', 'SUSPENDED');

-- 2. Profiles Table (1:1 with auth.users)
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    first_name TEXT NOT NULL DEFAULT '',
    last_name TEXT NOT NULL DEFAULT '',
    phone TEXT,
    preferred_locale TEXT NOT NULL DEFAULT 'he',
    avatar_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 3. Stations Table
CREATE TABLE public.stations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT NOT NULL UNIQUE,
    timezone TEXT NOT NULL DEFAULT 'Asia/Jerusalem',
    locale TEXT NOT NULL DEFAULT 'he',
    week_start INTEGER NOT NULL DEFAULT 0, -- 0 = Sunday
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 4. Station Memberships Table (Many-to-Many: User <-> Station with Station-Scoped Role)
-- Using ON DELETE RESTRICT on stations and profiles to preserve workforce history and audit integrity
CREATE TABLE public.station_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    role public.station_role NOT NULL DEFAULT 'EMPLOYEE',
    status public.membership_status NOT NULL DEFAULT 'ACTIVE',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_station_user UNIQUE (station_id, user_id)
);

-- 5. Audit Logs Table (Immutable append-only foundation)
CREATE TABLE public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    station_id UUID REFERENCES public.stations(id) ON DELETE SET NULL,
    actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    target_type TEXT NOT NULL,
    target_id TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 6. Indexes
CREATE INDEX idx_station_memberships_user_id ON public.station_memberships(user_id);
CREATE INDEX idx_station_memberships_station_id ON public.station_memberships(station_id);
CREATE INDEX idx_station_memberships_status ON public.station_memberships(status);
CREATE INDEX idx_stations_code ON public.stations(code);
CREATE INDEX idx_stations_is_active ON public.stations(is_active);
CREATE INDEX idx_audit_logs_station_created ON public.audit_logs(station_id, created_at DESC);

-- 7. Automated Timestamps Function & Triggers
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public, pg_temp;

CREATE TRIGGER tr_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER tr_stations_updated_at
    BEFORE UPDATE ON public.stations
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER tr_station_memberships_updated_at
    BEFORE UPDATE ON public.station_memberships
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- 8. Trigger on auth.users for Profile Provisioning (Security Definer with safe search_path)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, first_name, last_name, preferred_locale)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'first_name', ''),
        COALESCE(NEW.raw_user_meta_data->>'last_name', ''),
        COALESCE(NEW.raw_user_meta_data->>'preferred_locale', 'he')
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 9. Security Helper Functions for RLS (Security Definer with strict search_path)
CREATE OR REPLACE FUNCTION public.is_station_member(p_station_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.station_memberships
        WHERE station_id = p_station_id
          AND user_id = p_user_id
          AND status = 'ACTIVE'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION public.is_station_admin(p_station_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.station_memberships
        WHERE station_id = p_station_id
          AND user_id = p_user_id
          AND role = 'ADMIN'
          AND status = 'ACTIVE'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION public.is_station_manager_or_admin(p_station_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.station_memberships
        WHERE station_id = p_station_id
          AND user_id = p_user_id
          AND role IN ('ADMIN', 'SHIFT_MANAGER')
          AND status = 'ACTIVE'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION public.shares_active_station_with(target_user_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.station_memberships sm1
        JOIN public.station_memberships sm2 ON sm1.station_id = sm2.station_id
        WHERE sm1.user_id = p_user_id
          AND sm2.user_id = target_user_id
          AND sm1.status = 'ACTIVE'
          AND sm2.status = 'ACTIVE'
       );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public, pg_temp;

-- 10. Enable Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.station_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- 11. Explicit Permission Grants and Revocations
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;
REVOKE UPDATE, DELETE ON public.audit_logs FROM PUBLIC, authenticated, anon;

-- 12. RLS Policies: Profiles
-- Users can read their own profile, or profiles of colleagues in their shared active stations
CREATE POLICY "profiles_select_own_or_colleagues"
    ON public.profiles
    FOR SELECT
    TO authenticated
    USING (
        id = auth.uid()
        OR public.shares_active_station_with(id, auth.uid())
    );

-- Users can update safe non-role fields of their own profile
CREATE POLICY "profiles_update_own"
    ON public.profiles
    FOR UPDATE
    TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- 13. RLS Policies: Stations
-- Authenticated users can view stations where they hold an ACTIVE membership
CREATE POLICY "stations_select_members"
    ON public.stations
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.station_memberships
            WHERE station_id = stations.id
              AND user_id = auth.uid()
              AND status = 'ACTIVE'
        )
    );

-- Only Station Admins can update station settings
CREATE POLICY "stations_update_admins"
    ON public.stations
    FOR UPDATE
    TO authenticated
    USING (public.is_station_admin(id, auth.uid()))
    WITH CHECK (public.is_station_admin(id, auth.uid()));

-- 14. RLS Policies: Station Memberships
-- Members can view their own membership or all memberships in stations they actively belong to
CREATE POLICY "memberships_select"
    ON public.station_memberships
    FOR SELECT
    TO authenticated
    USING (
        user_id = auth.uid()
        OR public.is_station_member(station_id, auth.uid())
    );

-- Only Station Admins can insert memberships (provision employees/managers into their station)
CREATE POLICY "memberships_insert_admin"
    ON public.station_memberships
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_station_admin(station_id, auth.uid())
    );

-- Only Station Admins can update memberships (change role or status)
CREATE POLICY "memberships_update_admin"
    ON public.station_memberships
    FOR UPDATE
    TO authenticated
    USING (public.is_station_admin(station_id, auth.uid()))
    WITH CHECK (public.is_station_admin(station_id, auth.uid()));

-- Only Station Admins can delete memberships
CREATE POLICY "memberships_delete_admin"
    ON public.station_memberships
    FOR DELETE
    TO authenticated
    USING (public.is_station_admin(station_id, auth.uid()));

-- 15. RLS Policies: Audit Logs
-- Station Admins can view audit logs for their station
CREATE POLICY "audit_logs_select_admin"
    ON public.audit_logs
    FOR SELECT
    TO authenticated
    USING (public.is_station_admin(station_id, auth.uid()));

-- Authenticated members can append audit entries for authorized active stations
CREATE POLICY "audit_logs_insert_members"
    ON public.audit_logs
    FOR INSERT
    TO authenticated
    WITH CHECK (
        actor_id = auth.uid()
        AND (station_id IS NULL OR public.is_station_member(station_id, auth.uid()))
    );

-- 16. Enable Supabase Realtime for Multi-Station Synced Tables
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.station_memberships;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.stations;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
    END IF;
END $$;
