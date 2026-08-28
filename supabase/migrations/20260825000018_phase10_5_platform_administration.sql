-- ============================================================================
-- Migration: 20260825000018_phase10_5_platform_administration.sql
-- Description: Phase 10.5 — Platform Administration, Station Provisioning
--              & Global Operations.
--              Additive only. Does not modify migrations 001–017.
--              ADMIN / SHIFT_MANAGER / EMPLOYEE remain station-scoped.
--              PLATFORM_ADMIN is a separate global authorization scope.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Platform Admin storage (Option B — single global role)
--    NEVER stored on station_memberships.role.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.platform_admins (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE RESTRICT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT platform_admins_no_self_bootstrap CHECK (created_by IS DISTINCT FROM user_id OR created_by IS NULL)
);

CREATE INDEX IF NOT EXISTS idx_platform_admins_active
    ON public.platform_admins (user_id)
    WHERE is_active = true;

DROP TRIGGER IF EXISTS tr_platform_admins_updated_at ON public.platform_admins;
CREATE TRIGGER tr_platform_admins_updated_at
    BEFORE UPDATE ON public.platform_admins
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.platform_admins ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.platform_admins FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.platform_admins TO service_role;

-- No authenticated RLS policies: fail closed for PostgREST. SECURITY DEFINER
-- helpers below are the only client-reachable authorization primitive.

CREATE TABLE IF NOT EXISTS public.platform_provisioning_keys (
    idempotency_key TEXT PRIMARY KEY,
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT platform_provisioning_keys_key_len CHECK (char_length(idempotency_key) BETWEEN 8 AND 128)
);

ALTER TABLE public.platform_provisioning_keys ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.platform_provisioning_keys FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.platform_provisioning_keys TO service_role;

CREATE INDEX IF NOT EXISTS idx_audit_logs_action_created
    ON public.audit_logs (action, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_station_memberships_station_role_status
    ON public.station_memberships (station_id, role, status);

-- ----------------------------------------------------------------------------
-- 2. Canonical platform-admin authorization helpers
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_platform_admin(p_user_id UUID DEFAULT NULL)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid UUID;
BEGIN
    v_uid := COALESCE(p_user_id, auth.uid());
    IF v_uid IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN EXISTS (
        SELECT 1
        FROM public.platform_admins pa
        WHERE pa.user_id = v_uid
          AND pa.is_active = true
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.require_platform_admin()
RETURNS VOID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required'
            USING ERRCODE = '42501';
    END IF;
    IF NOT public.is_platform_admin(auth.uid()) THEN
        RAISE EXCEPTION 'Access denied: platform administrator required'
            USING ERRCODE = '42501';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.is_station_membership_admin(p_station_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF p_station_id IS NULL OR p_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.station_memberships
        WHERE station_id = p_station_id
          AND user_id = p_user_id
          AND role = 'ADMIN'
          AND status = 'ACTIVE'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.is_platform_admin(UUID) FROM PUBLIC;
-- Fail-closed boolean for unauthenticated callers (always false). Does not leak data.
GRANT EXECUTE ON FUNCTION public.is_platform_admin(UUID) TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.require_platform_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.require_platform_admin() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.is_station_membership_admin(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_station_membership_admin(UUID, UUID) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 3. Tighten direct membership / station mutations to membership-admins only
--    Platform Admin mutations must go through audited SECURITY DEFINER RPCs.
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS memberships_insert_admin ON public.station_memberships;
CREATE POLICY memberships_insert_admin
    ON public.station_memberships
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_station_membership_admin(station_id, auth.uid())
    );

DROP POLICY IF EXISTS memberships_update_admin ON public.station_memberships;
CREATE POLICY memberships_update_admin
    ON public.station_memberships
    FOR UPDATE
    TO authenticated
    USING (public.is_station_membership_admin(station_id, auth.uid()))
    WITH CHECK (public.is_station_membership_admin(station_id, auth.uid()));

DROP POLICY IF EXISTS memberships_delete_admin ON public.station_memberships;
CREATE POLICY memberships_delete_admin
    ON public.station_memberships
    FOR DELETE
    TO authenticated
    USING (public.is_station_membership_admin(station_id, auth.uid()));

DROP POLICY IF EXISTS stations_update_admins ON public.stations;
CREATE POLICY stations_update_admins
    ON public.stations
    FOR UPDATE
    TO authenticated
    USING (public.is_station_membership_admin(id, auth.uid()))
    WITH CHECK (public.is_station_membership_admin(id, auth.uid()));

-- ----------------------------------------------------------------------------
-- 4. Extend station helpers so an ACTIVE platform admin can operate a station
--    without a station_memberships row. Inactive platform admins fail closed.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_station_admin(p_station_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF p_station_id IS NULL OR p_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    RETURN public.is_station_membership_admin(p_station_id, p_user_id)
        OR public.is_platform_admin(p_user_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.is_station_member(p_station_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF p_station_id IS NULL OR p_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.station_memberships
        WHERE station_id = p_station_id
          AND user_id = p_user_id
          AND status = 'ACTIVE'
    ) OR public.is_platform_admin(p_user_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.is_station_manager_or_admin(p_station_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF p_station_id IS NULL OR p_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    RETURN EXISTS (
        SELECT 1 FROM public.station_memberships
        WHERE station_id = p_station_id
          AND user_id = p_user_id
          AND role IN ('ADMIN', 'SHIFT_MANAGER')
          AND status = 'ACTIVE'
    ) OR public.is_platform_admin(p_user_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.has_station_permission(
    p_station_id UUID,
    p_user_id UUID,
    p_permission TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_role public.station_role;
    v_status public.membership_status;
    v_override_enabled BOOLEAN;
BEGIN
    IF p_station_id IS NULL OR p_user_id IS NULL OR p_permission IS NULL THEN
        RETURN FALSE;
    END IF;

    IF public.is_platform_admin(p_user_id) THEN
        RETURN TRUE;
    END IF;

    SELECT role, status INTO v_role, v_status
    FROM public.station_memberships
    WHERE station_id = p_station_id AND user_id = p_user_id;

    IF NOT FOUND OR v_status <> 'ACTIVE' THEN
        RETURN FALSE;
    END IF;

    IF v_role = 'ADMIN' THEN
        RETURN TRUE;
    END IF;

    IF v_role = 'EMPLOYEE' THEN
        IF p_permission IN (
            'shift_templates.read', 'availability.period.read', 'availability.submit',
            'schedule.read', 'attendance.read', 'reports.self.read'
        ) THEN
            RETURN TRUE;
        END IF;
        RETURN FALSE;
    END IF;

    IF v_role = 'SHIFT_MANAGER' THEN
        SELECT is_enabled INTO v_override_enabled
        FROM public.station_shift_manager_permissions
        WHERE station_id = p_station_id AND permission = p_permission;

        IF FOUND THEN
            RETURN v_override_enabled;
        END IF;

        CASE p_permission
            WHEN 'shift_templates.read' THEN RETURN TRUE;
            WHEN 'availability.period.read' THEN RETURN TRUE;
            WHEN 'availability.submit' THEN RETURN TRUE;
            WHEN 'availability.team.read' THEN RETURN TRUE;
            WHEN 'schedule.read' THEN RETURN TRUE;
            WHEN 'attendance.read' THEN RETURN TRUE;
            WHEN 'attendance.team.read' THEN RETURN TRUE;
            WHEN 'reports.self.read' THEN RETURN TRUE;
            WHEN 'reports.team.read' THEN RETURN TRUE;
            WHEN 'reports.station.read' THEN RETURN TRUE;
            WHEN 'shift_templates.manage' THEN RETURN FALSE;
            WHEN 'availability.period.create' THEN RETURN FALSE;
            WHEN 'availability.period.open' THEN RETURN FALSE;
            WHEN 'availability.period.close' THEN RETURN FALSE;
            WHEN 'schedule.manage' THEN RETURN FALSE;
            WHEN 'schedule.publish' THEN RETURN FALSE;
            WHEN 'attendance.kiosk.manage' THEN RETURN FALSE;
            WHEN 'attendance.correct' THEN RETURN FALSE;
            ELSE RETURN FALSE;
        END CASE;
    END IF;

    RETURN FALSE;
END;
$$;

-- Platform-admin SELECT for tables whose policies do not use the helpers above.
DROP POLICY IF EXISTS stations_select_platform_admin ON public.stations;
CREATE POLICY stations_select_platform_admin
    ON public.stations
    FOR SELECT
    TO authenticated
    USING (public.is_platform_admin(auth.uid()));

DROP POLICY IF EXISTS profiles_select_platform_admin ON public.profiles;
CREATE POLICY profiles_select_platform_admin
    ON public.profiles
    FOR SELECT
    TO authenticated
    USING (public.is_platform_admin(auth.uid()));

DROP POLICY IF EXISTS audit_logs_select_platform_admin ON public.audit_logs;
CREATE POLICY audit_logs_select_platform_admin
    ON public.audit_logs
    FOR SELECT
    TO authenticated
    USING (public.is_platform_admin(auth.uid()));

-- ----------------------------------------------------------------------------
-- 5. Database invariant: only PLATFORM_ADMIN may grant or revoke station ADMIN
--    Enforced when the JWT role is authenticated (PostgREST + JWT-backed RPCs).
--    Superuser test seeds and service_role bypass this trigger; RPCs/Edge
--    Functions still enforce authorization independently.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_station_admin_role_authority()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_jwt_role TEXT;
    v_uid UUID;
    v_admin_involved BOOLEAN := false;
BEGIN
    v_jwt_role := COALESCE(auth.role(), '');
    v_uid := auth.uid();

    IF v_jwt_role IS DISTINCT FROM 'authenticated' THEN
        IF TG_OP = 'DELETE' THEN
            RETURN OLD;
        END IF;
        RETURN NEW;
    END IF;

    IF TG_OP = 'INSERT' THEN
        v_admin_involved := (NEW.role = 'ADMIN');
    ELSIF TG_OP = 'UPDATE' THEN
        v_admin_involved := (OLD.role = 'ADMIN' OR NEW.role = 'ADMIN');
    ELSIF TG_OP = 'DELETE' THEN
        v_admin_involved := (OLD.role = 'ADMIN');
    END IF;

    IF v_admin_involved AND NOT public.is_platform_admin(v_uid) THEN
        RAISE EXCEPTION 'Only platform administrators may grant or revoke station ADMIN privileges'
            USING ERRCODE = 'P00105';
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_enforce_station_admin_role_authority ON public.station_memberships;
CREATE TRIGGER tr_enforce_station_admin_role_authority
    BEFORE INSERT OR UPDATE OR DELETE ON public.station_memberships
    FOR EACH ROW EXECUTE FUNCTION public.enforce_station_admin_role_authority();

-- ----------------------------------------------------------------------------
-- 6. Harden admin_update_membership: station ADMIN cannot touch ADMIN role
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_update_membership(
    p_station_id UUID,
    p_membership_id UUID,
    p_role public.station_role,
    p_status public.membership_status,
    p_employee_code TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_old_role public.station_role;
    v_old_status public.membership_status;
    v_old_code TEXT;
    v_target_user_id UUID;
    v_clean_code TEXT;
    v_active_admins_count INTEGER;
    v_is_platform BOOLEAN;
    v_is_membership_admin BOOLEAN;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_is_platform := public.is_platform_admin(v_caller_id);
    v_is_membership_admin := public.is_station_membership_admin(p_station_id, v_caller_id);

    IF NOT v_is_platform AND NOT v_is_membership_admin THEN
        RAISE EXCEPTION 'Access denied: caller is not an administrator of this station'
            USING ERRCODE = '42501';
    END IF;

    SELECT role, status, user_id, employee_code
    INTO v_old_role, v_old_status, v_target_user_id, v_old_code
    FROM public.station_memberships
    WHERE id = p_membership_id AND station_id = p_station_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Membership not found in station' USING ERRCODE = 'P0002';
    END IF;

    IF NOT v_is_platform THEN
        IF v_old_role = 'ADMIN' OR p_role = 'ADMIN' THEN
            RAISE EXCEPTION 'Station administrators cannot grant or revoke Station Manager (ADMIN) privileges'
                USING ERRCODE = 'P00105';
        END IF;
        IF p_role NOT IN ('EMPLOYEE', 'SHIFT_MANAGER') THEN
            RAISE EXCEPTION 'Station administrators may only assign EMPLOYEE or SHIFT_MANAGER'
                USING ERRCODE = 'P00105';
        END IF;
    END IF;

    IF v_old_role = 'ADMIN' AND v_old_status = 'ACTIVE' AND (p_role <> 'ADMIN' OR p_status <> 'ACTIVE') THEN
        SELECT COUNT(*) INTO v_active_admins_count
        FROM public.station_memberships
        WHERE station_id = p_station_id AND role = 'ADMIN' AND status = 'ACTIVE';

        IF v_active_admins_count <= 1 THEN
            RAISE EXCEPTION 'Cannot demote or deactivate the last active Administrator of this station'
                USING ERRCODE = 'P0001';
        END IF;
    END IF;

    v_clean_code := NULLIF(TRIM(COALESCE(p_employee_code, '')), '');
    IF v_clean_code IS NOT NULL AND length(v_clean_code) > 50 THEN
        RAISE EXCEPTION 'Employee code cannot exceed 50 characters' USING ERRCODE = '22000';
    END IF;

    UPDATE public.station_memberships
    SET role = p_role,
        status = p_status,
        employee_code = v_clean_code,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_membership_id AND station_id = p_station_id;

    IF v_old_role <> p_role THEN
        INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
        VALUES (
            p_station_id,
            v_caller_id,
            'MEMBERSHIP_ROLE_CHANGED',
            'station_membership',
            p_membership_id::text,
            public.sanitize_audit_metadata(jsonb_build_object(
                'old_role', v_old_role,
                'new_role', p_role,
                'target_user_id', v_target_user_id,
                'actor_scope', CASE WHEN v_is_platform THEN 'PLATFORM_ADMIN' ELSE 'STATION_ADMIN' END
            ))
        );
    END IF;

    IF v_old_status <> p_status THEN
        INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
        VALUES (
            p_station_id,
            v_caller_id,
            CASE WHEN p_status = 'ACTIVE' THEN 'MEMBERSHIP_REACTIVATED' ELSE 'MEMBERSHIP_DEACTIVATED' END,
            'station_membership',
            p_membership_id::text,
            public.sanitize_audit_metadata(jsonb_build_object(
                'old_status', v_old_status,
                'new_status', p_status,
                'target_user_id', v_target_user_id
            ))
        );
    END IF;

    IF v_old_code IS DISTINCT FROM v_clean_code THEN
        INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
        VALUES (
            p_station_id,
            v_caller_id,
            'EMPLOYEE_CODE_UPDATED',
            'station_membership',
            p_membership_id::text,
            public.sanitize_audit_metadata(jsonb_build_object(
                'old_code', v_old_code,
                'new_code', v_clean_code,
                'target_user_id', v_target_user_id
            ))
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'membership_id', p_membership_id,
        'role', p_role,
        'status', p_status,
        'employee_code', v_clean_code
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 7. Station code normalization
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.normalize_station_code(p_code TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
    v_clean TEXT;
BEGIN
    v_clean := UPPER(TRIM(COALESCE(p_code, '')));
    v_clean := regexp_replace(v_clean, '\s+', '', 'g');
    IF char_length(v_clean) < 2 OR char_length(v_clean) > 32 THEN
        RAISE EXCEPTION 'Station code must be between 2 and 32 characters'
            USING ERRCODE = '22000';
    END IF;
    IF v_clean !~ '^[A-Z0-9][A-Z0-9_-]*$' THEN
        RAISE EXCEPTION 'Station code may contain only letters, digits, hyphen and underscore'
            USING ERRCODE = '22000';
    END IF;
    RETURN v_clean;
END;
$$;

REVOKE ALL ON FUNCTION public.normalize_station_code(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.normalize_station_code(TEXT) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 8. Platform station provisioning (transactional)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.platform_create_station(
    p_name TEXT,
    p_code TEXT,
    p_timezone TEXT DEFAULT 'Asia/Jerusalem',
    p_locale TEXT DEFAULT 'he',
    p_week_start INTEGER DEFAULT 0,
    p_is_active BOOLEAN DEFAULT true,
    p_initial_admin_user_id UUID DEFAULT NULL,
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_clean_name TEXT;
    v_clean_code TEXT;
    v_clean_tz TEXT;
    v_locale TEXT;
    v_station_id UUID;
    v_membership_id UUID;
    v_existing_station UUID;
    v_key TEXT;
    v_result JSONB;
BEGIN
    v_caller_id := auth.uid();
    PERFORM public.require_platform_admin();

    v_key := NULLIF(TRIM(COALESCE(p_idempotency_key, '')), '');
    IF v_key IS NOT NULL THEN
        SELECT station_id INTO v_existing_station
        FROM public.platform_provisioning_keys
        WHERE idempotency_key = v_key;
        IF FOUND THEN
            SELECT jsonb_build_object(
                'success', true,
                'station_id', s.id,
                'name', s.name,
                'code', s.code,
                'timezone', s.timezone,
                'locale', s.locale,
                'is_active', s.is_active,
                'idempotent', true
            )
            INTO v_result
            FROM public.stations s
            WHERE s.id = v_existing_station;
            RETURN v_result;
        END IF;
    END IF;

    v_clean_name := TRIM(COALESCE(p_name, ''));
    IF char_length(v_clean_name) < 2 OR char_length(v_clean_name) > 120 THEN
        RAISE EXCEPTION 'Station name must be between 2 and 120 characters'
            USING ERRCODE = '22000';
    END IF;

    v_clean_code := public.normalize_station_code(p_code);
    IF EXISTS (SELECT 1 FROM public.stations WHERE code = v_clean_code) THEN
        RAISE EXCEPTION 'Station code already exists: %', v_clean_code
            USING ERRCODE = 'P00106';
    END IF;

    v_clean_tz := TRIM(COALESCE(p_timezone, 'Asia/Jerusalem'));
    IF v_clean_tz = '' THEN
        v_clean_tz := 'Asia/Jerusalem';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_timezone_names WHERE name = v_clean_tz) THEN
        RAISE EXCEPTION 'Invalid IANA timezone: %', v_clean_tz
            USING ERRCODE = '22000';
    END IF;

    v_locale := LOWER(TRIM(COALESCE(p_locale, 'he')));
    IF v_locale NOT IN ('he', 'en') THEN
        v_locale := 'he';
    END IF;

    IF p_week_start NOT IN (0, 1) THEN
        RAISE EXCEPTION 'week_start must be 0 (Sunday) or 1 (Monday)'
            USING ERRCODE = '22000';
    END IF;

    IF p_initial_admin_user_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_initial_admin_user_id) THEN
            RAISE EXCEPTION 'Initial station manager profile not found'
                USING ERRCODE = 'P0002';
        END IF;
    END IF;

    INSERT INTO public.stations (name, code, timezone, locale, week_start, is_active)
    VALUES (v_clean_name, v_clean_code, v_clean_tz, v_locale, p_week_start, COALESCE(p_is_active, true))
    RETURNING id INTO v_station_id;

    IF p_initial_admin_user_id IS NOT NULL THEN
        INSERT INTO public.station_memberships (station_id, user_id, role, status)
        VALUES (v_station_id, p_initial_admin_user_id, 'ADMIN', 'ACTIVE')
        RETURNING id INTO v_membership_id;
    END IF;

    IF v_key IS NOT NULL THEN
        INSERT INTO public.platform_provisioning_keys (idempotency_key, station_id, created_by)
        VALUES (v_key, v_station_id, v_caller_id)
        ON CONFLICT (idempotency_key) DO NOTHING;
    END IF;

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        v_station_id,
        v_caller_id,
        'platform.station.created',
        'station',
        v_station_id::text,
        public.sanitize_audit_metadata(jsonb_build_object(
            'name', v_clean_name,
            'code', v_clean_code,
            'timezone', v_clean_tz,
            'locale', v_locale,
            'initial_admin_user_id', p_initial_admin_user_id
        ))
    );

    IF v_membership_id IS NOT NULL THEN
        INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
        VALUES (
            v_station_id,
            v_caller_id,
            'platform.station_admin.assigned',
            'station_membership',
            v_membership_id::text,
            public.sanitize_audit_metadata(jsonb_build_object(
                'target_user_id', p_initial_admin_user_id,
                'via', 'station_create'
            ))
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'station_id', v_station_id,
        'name', v_clean_name,
        'code', v_clean_code,
        'timezone', v_clean_tz,
        'locale', v_locale,
        'week_start', p_week_start,
        'is_active', COALESCE(p_is_active, true),
        'membership_id', v_membership_id,
        'idempotent', false
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 9. Platform station update / lifecycle
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.platform_update_station(
    p_station_id UUID,
    p_name TEXT,
    p_code TEXT,
    p_timezone TEXT,
    p_locale TEXT DEFAULT 'he',
    p_week_start INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_clean_name TEXT;
    v_clean_code TEXT;
    v_clean_tz TEXT;
    v_locale TEXT;
BEGIN
    v_caller_id := auth.uid();
    PERFORM public.require_platform_admin();

    IF NOT EXISTS (SELECT 1 FROM public.stations WHERE id = p_station_id) THEN
        RAISE EXCEPTION 'Station not found' USING ERRCODE = 'P0002';
    END IF;

    v_clean_name := TRIM(COALESCE(p_name, ''));
    IF char_length(v_clean_name) < 2 THEN
        RAISE EXCEPTION 'Station name must be at least 2 characters' USING ERRCODE = '22000';
    END IF;

    v_clean_code := public.normalize_station_code(p_code);
    IF EXISTS (SELECT 1 FROM public.stations WHERE code = v_clean_code AND id <> p_station_id) THEN
        RAISE EXCEPTION 'Station code already exists: %', v_clean_code
            USING ERRCODE = 'P00106';
    END IF;

    v_clean_tz := TRIM(p_timezone);
    IF NOT EXISTS (SELECT 1 FROM pg_timezone_names WHERE name = v_clean_tz) THEN
        RAISE EXCEPTION 'Invalid IANA timezone: %', v_clean_tz USING ERRCODE = '22000';
    END IF;

    v_locale := LOWER(TRIM(COALESCE(p_locale, 'he')));
    IF v_locale NOT IN ('he', 'en') THEN
        v_locale := 'he';
    END IF;

    IF p_week_start NOT IN (0, 1) THEN
        RAISE EXCEPTION 'week_start must be 0 (Sunday) or 1 (Monday)' USING ERRCODE = '22000';
    END IF;

    UPDATE public.stations
    SET name = v_clean_name,
        code = v_clean_code,
        timezone = v_clean_tz,
        locale = v_locale,
        week_start = p_week_start,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_station_id;

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        p_station_id,
        v_caller_id,
        'platform.station.updated',
        'station',
        p_station_id::text,
        public.sanitize_audit_metadata(jsonb_build_object(
            'name', v_clean_name,
            'code', v_clean_code,
            'timezone', v_clean_tz,
            'locale', v_locale
        ))
    );

    RETURN jsonb_build_object('success', true, 'station_id', p_station_id, 'code', v_clean_code);
END;
$$;

CREATE OR REPLACE FUNCTION public.platform_set_station_active(
    p_station_id UUID,
    p_is_active BOOLEAN,
    p_reason TEXT,
    p_force_deactivate BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_current BOOLEAN;
    v_name TEXT;
    v_code TEXT;
    v_tz TEXT;
    v_locale TEXT;
    v_week INTEGER;
    v_late INTEGER;
    v_early INTEGER;
    v_reason TEXT;
    v_result JSONB;
BEGIN
    v_caller_id := auth.uid();
    PERFORM public.require_platform_admin();

    SELECT is_active, name, code, timezone, locale, week_start, late_grace_minutes, check_in_early_minutes
    INTO v_current, v_name, v_code, v_tz, v_locale, v_week, v_late, v_early
    FROM public.stations
    WHERE id = p_station_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Station not found' USING ERRCODE = 'P0002';
    END IF;

    v_reason := TRIM(COALESCE(p_reason, ''));
    IF char_length(v_reason) < 3 THEN
        RAISE EXCEPTION 'A reason of at least 3 characters is required for station lifecycle changes'
            USING ERRCODE = '22000';
    END IF;

    IF p_is_active AND v_current THEN
        RAISE EXCEPTION 'Station is already active' USING ERRCODE = 'P00109';
    END IF;
    IF (NOT p_is_active) AND (NOT v_current) THEN
        RAISE EXCEPTION 'Station is already inactive' USING ERRCODE = 'P00108';
    END IF;

    -- Reuse existing deactivation safety (P0082) and last-admin preservation.
    v_result := public.admin_update_station(
        p_station_id,
        v_name,
        v_code,
        v_tz,
        v_locale,
        v_week,
        p_is_active,
        v_late,
        v_early,
        p_force_deactivate,
        v_reason
    );

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        p_station_id,
        v_caller_id,
        CASE WHEN p_is_active THEN 'platform.station.activated' ELSE 'platform.station.deactivated' END,
        'station',
        p_station_id::text,
        public.sanitize_audit_metadata(jsonb_build_object(
            'reason', v_reason,
            'force', p_force_deactivate
        ))
    );

    RETURN v_result || jsonb_build_object('reason', v_reason);
END;
$$;

-- ----------------------------------------------------------------------------
-- 10. Station manager (ADMIN) assignment / removal / replace
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.platform_assign_station_admin(
    p_station_id UUID,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_membership_id UUID;
    v_old_role public.station_role;
    v_old_status public.membership_status;
    v_created BOOLEAN := false;
BEGIN
    v_caller_id := auth.uid();
    PERFORM public.require_platform_admin();

    IF NOT EXISTS (SELECT 1 FROM public.stations WHERE id = p_station_id) THEN
        RAISE EXCEPTION 'Station not found' USING ERRCODE = 'P0002';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
        RAISE EXCEPTION 'Target user not found' USING ERRCODE = 'P0002';
    END IF;

    SELECT id, role, status INTO v_membership_id, v_old_role, v_old_status
    FROM public.station_memberships
    WHERE station_id = p_station_id AND user_id = p_user_id;

    IF FOUND THEN
        UPDATE public.station_memberships
        SET role = 'ADMIN',
            status = 'ACTIVE',
            updated_at = timezone('utc'::text, now())
        WHERE id = v_membership_id;
    ELSE
        INSERT INTO public.station_memberships (station_id, user_id, role, status)
        VALUES (p_station_id, p_user_id, 'ADMIN', 'ACTIVE')
        RETURNING id INTO v_membership_id;
        v_created := true;
    END IF;

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        p_station_id,
        v_caller_id,
        'platform.station_admin.assigned',
        'station_membership',
        v_membership_id::text,
        public.sanitize_audit_metadata(jsonb_build_object(
            'target_user_id', p_user_id,
            'created', v_created,
            'previous_role', v_old_role,
            'previous_status', v_old_status
        ))
    );

    RETURN jsonb_build_object(
        'success', true,
        'membership_id', v_membership_id,
        'station_id', p_station_id,
        'user_id', p_user_id,
        'role', 'ADMIN',
        'status', 'ACTIVE',
        'created', v_created
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.platform_remove_station_admin(
    p_station_id UUID,
    p_user_id UUID,
    p_reason TEXT,
    p_demote_to public.station_role DEFAULT 'EMPLOYEE',
    p_deactivate BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_membership_id UUID;
    v_old_role public.station_role;
    v_old_status public.membership_status;
    v_active_admins INTEGER;
    v_station_active BOOLEAN;
    v_reason TEXT;
    v_new_role public.station_role;
    v_new_status public.membership_status;
BEGIN
    v_caller_id := auth.uid();
    PERFORM public.require_platform_admin();

    v_reason := TRIM(COALESCE(p_reason, ''));
    IF char_length(v_reason) < 3 THEN
        RAISE EXCEPTION 'A reason of at least 3 characters is required'
            USING ERRCODE = '22000';
    END IF;

    IF p_demote_to = 'ADMIN' THEN
        RAISE EXCEPTION 'Cannot demote a Station Manager to ADMIN'
            USING ERRCODE = '22000';
    END IF;

    SELECT is_active INTO v_station_active FROM public.stations WHERE id = p_station_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Station not found' USING ERRCODE = 'P0002';
    END IF;

    SELECT id, role, status INTO v_membership_id, v_old_role, v_old_status
    FROM public.station_memberships
    WHERE station_id = p_station_id AND user_id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Target user is not a member of this station' USING ERRCODE = 'P0002';
    END IF;

    IF v_old_role <> 'ADMIN' THEN
        RAISE EXCEPTION 'Target user is not a Station Manager of this station' USING ERRCODE = '22000';
    END IF;

    SELECT COUNT(*) INTO v_active_admins
    FROM public.station_memberships
    WHERE station_id = p_station_id AND role = 'ADMIN' AND status = 'ACTIVE';

    IF v_old_status = 'ACTIVE' AND v_active_admins <= 1 AND COALESCE(v_station_active, true) THEN
        RAISE EXCEPTION 'Cannot remove the last active Station Manager of an active station'
            USING ERRCODE = 'P0001';
    END IF;

    v_new_role := p_demote_to;
    v_new_status := CASE WHEN p_deactivate THEN 'INACTIVE'::public.membership_status ELSE 'ACTIVE'::public.membership_status END;

    UPDATE public.station_memberships
    SET role = v_new_role,
        status = v_new_status,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_membership_id;

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        p_station_id,
        v_caller_id,
        'platform.station_admin.removed',
        'station_membership',
        v_membership_id::text,
        public.sanitize_audit_metadata(jsonb_build_object(
            'target_user_id', p_user_id,
            'reason', v_reason,
            'new_role', v_new_role,
            'new_status', v_new_status
        ))
    );

    RETURN jsonb_build_object(
        'success', true,
        'membership_id', v_membership_id,
        'user_id', p_user_id,
        'role', v_new_role,
        'status', v_new_status
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.platform_replace_station_admin(
    p_station_id UUID,
    p_outgoing_user_id UUID,
    p_incoming_user_id UUID,
    p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_assign JSONB;
    v_remove JSONB;
    v_reason TEXT;
BEGIN
    PERFORM public.require_platform_admin();
    v_reason := TRIM(COALESCE(p_reason, ''));
    IF char_length(v_reason) < 3 THEN
        RAISE EXCEPTION 'A reason of at least 3 characters is required'
            USING ERRCODE = '22000';
    END IF;
    IF p_outgoing_user_id = p_incoming_user_id THEN
        RAISE EXCEPTION 'Incoming and outgoing Station Managers must be different users'
            USING ERRCODE = '22000';
    END IF;

    v_assign := public.platform_assign_station_admin(p_station_id, p_incoming_user_id);
    v_remove := public.platform_remove_station_admin(
        p_station_id, p_outgoing_user_id, v_reason, 'EMPLOYEE', false
    );

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        p_station_id,
        auth.uid(),
        'platform.station_admin.replaced',
        'station',
        p_station_id::text,
        public.sanitize_audit_metadata(jsonb_build_object(
            'outgoing_user_id', p_outgoing_user_id,
            'incoming_user_id', p_incoming_user_id,
            'reason', v_reason
        ))
    );

    RETURN jsonb_build_object(
        'success', true,
        'assigned', v_assign,
        'removed', v_remove
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 11. Platform list / overview / managers / health / audit
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.platform_list_stations()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_now TIMESTAMPTZ := now();
BEGIN
    PERFORM public.require_platform_admin();

    RETURN COALESCE((
        SELECT jsonb_agg(row_data ORDER BY name)
        FROM (
            SELECT jsonb_build_object(
                'id', s.id,
                'name', s.name,
                'code', s.code,
                'timezone', s.timezone,
                'locale', s.locale,
                'is_active', s.is_active,
                'created_at', s.created_at,
                'updated_at', s.updated_at,
                'active_members', COALESCE(m.active_members, 0),
                'admin_count', COALESCE(m.admin_count, 0),
                'shift_manager_count', COALESCE(m.shift_manager_count, 0),
                'employee_count', COALESCE(m.employee_count, 0),
                'kiosks_total', COALESCE(k.kiosks_total, 0),
                'kiosks_online', COALESCE(k.kiosks_online, 0),
                'kiosks_offline', COALESCE(k.kiosks_offline, 0),
                'stale_open_sessions', COALESCE(a.stale_open_sessions, 0),
                'exports_failed_24h', COALESCE(e.exports_failed_24h, 0)
            ) AS row_data,
            s.name
            FROM public.stations s
            LEFT JOIN LATERAL (
                SELECT
                    COUNT(*) FILTER (WHERE sm.status = 'ACTIVE') AS active_members,
                    COUNT(*) FILTER (WHERE sm.status = 'ACTIVE' AND sm.role = 'ADMIN') AS admin_count,
                    COUNT(*) FILTER (WHERE sm.status = 'ACTIVE' AND sm.role = 'SHIFT_MANAGER') AS shift_manager_count,
                    COUNT(*) FILTER (WHERE sm.status = 'ACTIVE' AND sm.role = 'EMPLOYEE') AS employee_count
                FROM public.station_memberships sm
                WHERE sm.station_id = s.id
            ) m ON true
            LEFT JOIN LATERAL (
                SELECT
                    COUNT(*) AS kiosks_total,
                    COUNT(*) FILTER (
                        WHERE kd.is_active = true
                          AND kd.last_seen_at IS NOT NULL
                          AND kd.last_seen_at >= (v_now - INTERVAL '2 minutes')
                    ) AS kiosks_online,
                    COUNT(*) FILTER (
                        WHERE kd.is_active = false
                           OR kd.last_seen_at IS NULL
                           OR kd.last_seen_at < (v_now - INTERVAL '2 minutes')
                    ) AS kiosks_offline
                FROM public.kiosk_devices kd
                WHERE kd.station_id = s.id
            ) k ON true
            LEFT JOIN LATERAL (
                SELECT COUNT(*) AS stale_open_sessions
                FROM public.attendance_records ar
                WHERE ar.station_id = s.id
                  AND ar.check_out_time IS NULL
                  AND ar.check_in_time <= (v_now - INTERVAL '16 hours')
            ) a ON true
            LEFT JOIN LATERAL (
                SELECT COUNT(*) FILTER (WHERE re.status = 'FAILED') AS exports_failed_24h
                FROM public.report_exports re
                WHERE re.station_id = s.id
                  AND re.created_at >= (v_now - INTERVAL '24 hours')
            ) e ON true
        ) q
    ), '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.platform_get_overview()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_now TIMESTAMPTZ := now();
    v_total_stations INTEGER := 0;
    v_active_stations INTEGER := 0;
    v_inactive_stations INTEGER := 0;
    v_active_memberships INTEGER := 0;
    v_admin_count INTEGER := 0;
    v_shift_manager_count INTEGER := 0;
    v_kiosks_online INTEGER := 0;
    v_kiosks_offline INTEGER := 0;
    v_stale_sessions INTEGER := 0;
    v_failed_exports INTEGER := 0;
    v_pending_notifications INTEGER := 0;
    v_identity_failures INTEGER := 0;
    v_alert_count INTEGER := 0;
BEGIN
    PERFORM public.require_platform_admin();

    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE is_active),
        COUNT(*) FILTER (WHERE NOT is_active)
    INTO v_total_stations, v_active_stations, v_inactive_stations
    FROM public.stations;

    SELECT
        COUNT(*) FILTER (WHERE status = 'ACTIVE'),
        COUNT(*) FILTER (WHERE status = 'ACTIVE' AND role = 'ADMIN'),
        COUNT(*) FILTER (WHERE status = 'ACTIVE' AND role = 'SHIFT_MANAGER')
    INTO v_active_memberships, v_admin_count, v_shift_manager_count
    FROM public.station_memberships;

    SELECT
        COUNT(*) FILTER (
            WHERE is_active = true
              AND last_seen_at IS NOT NULL
              AND last_seen_at >= (v_now - INTERVAL '2 minutes')
        ),
        COUNT(*) FILTER (
            WHERE is_active = false
               OR last_seen_at IS NULL
               OR last_seen_at < (v_now - INTERVAL '2 minutes')
        )
    INTO v_kiosks_online, v_kiosks_offline
    FROM public.kiosk_devices;

    SELECT COUNT(*) INTO v_stale_sessions
    FROM public.attendance_records
    WHERE check_out_time IS NULL
      AND check_in_time <= (v_now - INTERVAL '16 hours');

    SELECT COUNT(*) INTO v_failed_exports
    FROM public.report_exports
    WHERE status = 'FAILED'
      AND created_at >= (v_now - INTERVAL '24 hours');

    SELECT COUNT(*) INTO v_pending_notifications
    FROM public.notification_delivery_jobs
    WHERE status = 'PENDING';

    SELECT COUNT(*) INTO v_identity_failures
    FROM public.identity_verification_attempts
    WHERE result IN ('NOT_VERIFIED', 'INCONCLUSIVE')
      AND created_at >= (v_now - INTERVAL '24 hours');

    v_alert_count :=
        (CASE WHEN v_kiosks_offline > 0 THEN 1 ELSE 0 END) +
        (CASE WHEN v_stale_sessions > 0 THEN 1 ELSE 0 END) +
        (CASE WHEN v_failed_exports > 0 THEN 1 ELSE 0 END) +
        (CASE WHEN v_inactive_stations > 0 THEN 1 ELSE 0 END);

    RETURN jsonb_build_object(
        'total_stations', v_total_stations,
        'active_stations', v_active_stations,
        'inactive_stations', v_inactive_stations,
        'active_memberships', v_active_memberships,
        'station_admin_count', v_admin_count,
        'shift_manager_count', v_shift_manager_count,
        'kiosks_online', v_kiosks_online,
        'kiosks_offline', v_kiosks_offline,
        'stale_open_sessions', v_stale_sessions,
        'failed_exports_24h', v_failed_exports,
        'pending_notifications', v_pending_notifications,
        'identity_failures_24h', v_identity_failures,
        'operational_alert_count', v_alert_count,
        'schema_version', '20260825000018',
        'telemetry_timestamp', v_now
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.platform_get_health_overview()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN public.platform_get_overview();
END;
$$;

CREATE OR REPLACE FUNCTION public.platform_get_station_managers(p_station_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    PERFORM public.require_platform_admin();
    IF NOT EXISTS (SELECT 1 FROM public.stations WHERE id = p_station_id) THEN
        RAISE EXCEPTION 'Station not found' USING ERRCODE = 'P0002';
    END IF;

    RETURN COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
            'membership_id', sm.id,
            'station_id', sm.station_id,
            'user_id', sm.user_id,
            'role', sm.role,
            'status', sm.status,
            'employee_code', sm.employee_code,
            'joined_at', sm.joined_at,
            'updated_at', sm.updated_at,
            'first_name', p.first_name,
            'last_name', p.last_name,
            'phone', p.phone,
            'email', u.email
        ) ORDER BY sm.status, p.last_name, p.first_name)
        FROM public.station_memberships sm
        JOIN public.profiles p ON p.id = sm.user_id
        LEFT JOIN auth.users u ON u.id = sm.user_id
        WHERE sm.station_id = p_station_id
          AND sm.role = 'ADMIN'
    ), '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.platform_query_audit_logs(
    p_station_id UUID DEFAULT NULL,
    p_action TEXT DEFAULT NULL,
    p_actor_id UUID DEFAULT NULL,
    p_from TIMESTAMPTZ DEFAULT NULL,
    p_to TIMESTAMPTZ DEFAULT NULL,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_limit INTEGER;
    v_offset INTEGER;
BEGIN
    PERFORM public.require_platform_admin();
    v_limit := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
    v_offset := GREATEST(COALESCE(p_offset, 0), 0);

    RETURN COALESCE((
        SELECT jsonb_build_object(
            'total', MAX(sub.total_count),
            'limit', v_limit,
            'offset', v_offset,
            'entries', COALESCE(jsonb_agg(jsonb_build_object(
                'id', sub.id,
                'station_id', sub.station_id,
                'station_name', sub.station_name,
                'actor_id', sub.actor_id,
                'actor_name', sub.actor_name,
                'action', sub.action,
                'target_type', sub.target_type,
                'target_id', sub.target_id,
                'metadata', sub.metadata,
                'created_at', sub.created_at
            ) ORDER BY sub.created_at DESC), '[]'::jsonb)
        )
        FROM (
            SELECT
                al.id,
                al.station_id,
                s.name AS station_name,
                al.actor_id,
                COALESCE(p.first_name || ' ' || p.last_name, 'System') AS actor_name,
                al.action,
                al.target_type,
                al.target_id,
                public.sanitize_audit_metadata(al.metadata) AS metadata,
                al.created_at,
                COUNT(*) OVER() AS total_count
            FROM public.audit_logs al
            LEFT JOIN public.stations s ON s.id = al.station_id
            LEFT JOIN public.profiles p ON p.id = al.actor_id
            WHERE (p_station_id IS NULL OR al.station_id = p_station_id)
              AND (p_from IS NULL OR al.created_at >= p_from)
              AND (p_to IS NULL OR al.created_at <= p_to)
              AND (p_actor_id IS NULL OR al.actor_id = p_actor_id)
              AND (
                  p_action IS NULL
                  OR TRIM(p_action) = ''
                  OR al.action ILIKE ('%' || regexp_replace(SUBSTRING(TRIM(p_action) FROM 1 FOR 80), '([%_\\])', '\\\1', 'g') || '%')
              )
            ORDER BY al.created_at DESC
            LIMIT v_limit
            OFFSET v_offset
        ) sub
    ), jsonb_build_object('total', 0, 'limit', v_limit, 'offset', v_offset, 'entries', '[]'::jsonb));
END;
$$;

-- Resolve a user by email for platform manager assignment (no secrets).
CREATE OR REPLACE FUNCTION public.platform_lookup_user_by_email(p_email TEXT)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_email TEXT;
    v_user_id UUID;
    v_first TEXT;
    v_last TEXT;
BEGIN
    PERFORM public.require_platform_admin();
    v_email := LOWER(TRIM(COALESCE(p_email, '')));
    IF v_email = '' OR position('@' IN v_email) = 0 THEN
        RAISE EXCEPTION 'A valid email is required' USING ERRCODE = '22000';
    END IF;

    SELECT u.id, pr.first_name, pr.last_name
    INTO v_user_id, v_first, v_last
    FROM auth.users u
    LEFT JOIN public.profiles pr ON pr.id = u.id
    WHERE LOWER(u.email) = v_email
    LIMIT 1;

    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('found', false, 'email', v_email);
    END IF;

    RETURN jsonb_build_object(
        'found', true,
        'user_id', v_user_id,
        'email', v_email,
        'first_name', v_first,
        'last_name', v_last
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 12. Schema version bump
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_platform_schema_version()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN jsonb_build_object(
        'schema_version', '20260825000018',
        'platform_version', '1.0.5',
        'min_compatible_client_version', '1.0.0',
        'status', 'HEALTHY',
        'server_timestamp', now()
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_station_system_health(p_station_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_total_kiosks INTEGER := 0;
    v_online_kiosks INTEGER := 0;
    v_offline_kiosks INTEGER := 0;
    v_exports_total_24h INTEGER := 0;
    v_exports_failed_24h INTEGER := 0;
    v_exports_pending INTEGER := 0;
    v_stale_open_sessions INTEGER := 0;
    v_failed_identity_attempts INTEGER := 0;
    v_pending_notifications INTEGER := 0;
    v_now TIMESTAMPTZ := now();
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL OR NOT public.is_station_admin(p_station_id, v_caller_id) THEN
        RAISE EXCEPTION 'Access denied: caller is not an administrator of this station'
            USING ERRCODE = '42501';
    END IF;

    SELECT
        COALESCE(COUNT(*), 0),
        COALESCE(COUNT(*) FILTER (WHERE is_active = true AND last_seen_at IS NOT NULL AND last_seen_at >= (v_now - INTERVAL '2 minutes')), 0),
        COALESCE(COUNT(*) FILTER (WHERE is_active = false OR last_seen_at IS NULL OR last_seen_at < (v_now - INTERVAL '2 minutes')), 0)
    INTO v_total_kiosks, v_online_kiosks, v_offline_kiosks
    FROM public.kiosk_devices
    WHERE station_id = p_station_id;

    SELECT
        COALESCE(COUNT(*), 0),
        COALESCE(COUNT(*) FILTER (WHERE status = 'FAILED'), 0),
        COALESCE(COUNT(*) FILTER (WHERE status IN ('PENDING', 'PROCESSING')), 0)
    INTO v_exports_total_24h, v_exports_failed_24h, v_exports_pending
    FROM public.report_exports
    WHERE station_id = p_station_id
      AND created_at >= (v_now - INTERVAL '24 hours');

    SELECT COALESCE(COUNT(*), 0)
    INTO v_stale_open_sessions
    FROM public.attendance_records
    WHERE station_id = p_station_id
      AND check_out_time IS NULL
      AND check_in_time <= (v_now - INTERVAL '16 hours');

    SELECT COALESCE(COUNT(*), 0)
    INTO v_failed_identity_attempts
    FROM public.identity_verification_attempts
    WHERE station_id = p_station_id
      AND result IN ('NOT_VERIFIED', 'INCONCLUSIVE')
      AND created_at >= (v_now - INTERVAL '24 hours');

    SELECT COALESCE(COUNT(*), 0)
    INTO v_pending_notifications
    FROM public.notification_delivery_jobs j
    JOIN public.notifications n ON j.notification_id = n.id
    WHERE n.station_id = p_station_id
      AND j.status = 'PENDING';

    RETURN jsonb_build_object(
        'station_id', p_station_id,
        'schema_version', '20260825000018',
        'telemetry_timestamp', v_now,
        'kiosks', jsonb_build_object(
            'total', v_total_kiosks,
            'online', v_online_kiosks,
            'offline', v_offline_kiosks
        ),
        'exports_24h', jsonb_build_object(
            'total', v_exports_total_24h,
            'failed', v_exports_failed_24h,
            'pending_active', v_exports_pending
        ),
        -- Phase 8 / Flutter compatibility aliases
        'exports', jsonb_build_object(
            'total_24h', v_exports_total_24h,
            'failed_24h', v_exports_failed_24h,
            'pending_active', v_exports_pending
        ),
        'anomalies', jsonb_build_object(
            'stale_open_sessions', v_stale_open_sessions,
            'failed_identity_attempts', v_failed_identity_attempts
        ),
        'server_time', v_now,
        'attendance', jsonb_build_object(
            'stale_open_sessions_16h', v_stale_open_sessions
        ),
        'identity', jsonb_build_object(
            'failures_24h', v_failed_identity_attempts
        ),
        'notifications', jsonb_build_object(
            'pending_outbox', v_pending_notifications
        ),
        'storage_buckets', jsonb_build_object(
            'reports_bucket_accessible', true
        )
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 13. Execution grants — no PUBLIC/anon on privileged platform functions
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.get_platform_schema_version() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_platform_schema_version() TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_station_system_health(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_station_system_health(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_update_membership(UUID, UUID, public.station_role, public.membership_status, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_membership(UUID, UUID, public.station_role, public.membership_status, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.platform_create_station(TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN, UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.platform_create_station(TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN, UUID, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.platform_update_station(UUID, TEXT, TEXT, TEXT, TEXT, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.platform_update_station(UUID, TEXT, TEXT, TEXT, TEXT, INTEGER) TO authenticated;

REVOKE ALL ON FUNCTION public.platform_set_station_active(UUID, BOOLEAN, TEXT, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.platform_set_station_active(UUID, BOOLEAN, TEXT, BOOLEAN) TO authenticated;

REVOKE ALL ON FUNCTION public.platform_assign_station_admin(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.platform_assign_station_admin(UUID, UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.platform_remove_station_admin(UUID, UUID, TEXT, public.station_role, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.platform_remove_station_admin(UUID, UUID, TEXT, public.station_role, BOOLEAN) TO authenticated;

REVOKE ALL ON FUNCTION public.platform_replace_station_admin(UUID, UUID, UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.platform_replace_station_admin(UUID, UUID, UUID, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.platform_list_stations() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.platform_list_stations() TO authenticated;

REVOKE ALL ON FUNCTION public.platform_get_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.platform_get_overview() TO authenticated;

REVOKE ALL ON FUNCTION public.platform_get_health_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.platform_get_health_overview() TO authenticated;

REVOKE ALL ON FUNCTION public.platform_get_station_managers(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.platform_get_station_managers(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.platform_query_audit_logs(UUID, TEXT, UUID, TIMESTAMPTZ, TIMESTAMPTZ, INTEGER, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.platform_query_audit_logs(UUID, TEXT, UUID, TIMESTAMPTZ, TIMESTAMPTZ, INTEGER, INTEGER) TO authenticated;

REVOKE ALL ON FUNCTION public.platform_lookup_user_by_email(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.platform_lookup_user_by_email(TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.enforce_station_admin_role_authority() FROM PUBLIC, anon, authenticated;
