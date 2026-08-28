-- YellowShifts Phase 1 Migration (Hardened & Audited)
-- Secure Admin Provisioning, Station Management, Employee Lifecycle, Memberships & Role Administration

-- 1. Alter station_memberships to add employee_code
ALTER TABLE public.station_memberships 
ADD COLUMN IF NOT EXISTS employee_code TEXT;

-- 2. Add Unique Index for Normalized Phone on Profiles (where phone is present)
CREATE UNIQUE INDEX IF NOT EXISTS uq_profiles_phone 
ON public.profiles(phone) 
WHERE phone IS NOT NULL AND phone <> '';

-- 3. Last-Admin Protection Function & Trigger with Concurrency Lock
-- A station must not end up with zero active Admins even under race conditions.
CREATE OR REPLACE FUNCTION public.check_last_admin_on_station_membership()
RETURNS TRIGGER AS $$
DECLARE
    v_admin_count INTEGER;
    v_station_id UUID;
BEGIN
    v_station_id := COALESCE(OLD.station_id, NEW.station_id);

    -- Check only if modifying or deleting an existing ACTIVE ADMIN
    IF (TG_OP = 'DELETE' AND OLD.role = 'ADMIN' AND OLD.status = 'ACTIVE') OR
       (TG_OP = 'UPDATE' AND OLD.role = 'ADMIN' AND OLD.status = 'ACTIVE' AND (NEW.role <> 'ADMIN' OR NEW.status <> 'ACTIVE')) THEN
       
        -- Concurrency Lock: Lock the parent station row to serialize concurrent admin modifications
        PERFORM 1 FROM public.stations WHERE id = v_station_id FOR UPDATE;

        SELECT COUNT(*)
        INTO v_admin_count
        FROM public.station_memberships
        WHERE station_id = v_station_id
          AND role = 'ADMIN'
          AND status = 'ACTIVE'
          AND id <> OLD.id;

        IF v_admin_count = 0 THEN
            RAISE EXCEPTION 'Cannot demote, deactivate, or remove the last active Administrator of this station.'
                USING ERRCODE = 'P0001';
        END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS tr_prevent_last_admin_removal ON public.station_memberships;
CREATE TRIGGER tr_prevent_last_admin_removal
    BEFORE UPDATE OR DELETE ON public.station_memberships
    FOR EACH ROW EXECUTE FUNCTION public.check_last_admin_on_station_membership();

-- 4. Single-argument convenience wrappers for helper functions
CREATE OR REPLACE FUNCTION public.is_station_member(lookup_station_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN public.is_station_member(lookup_station_id, auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION public.is_station_admin(lookup_station_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN public.is_station_admin(lookup_station_id, auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION public.is_station_manager_or_admin(lookup_station_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN public.is_station_manager_or_admin(lookup_station_id, auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION public.shares_active_station_with(target_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN public.shares_active_station_with(target_user_id, auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public, pg_temp;

-- 5. Station Admin Update Policy (Admins can manage their assigned station settings)
DROP POLICY IF EXISTS stations_update_admins ON public.stations;
CREATE POLICY stations_update_admins ON public.stations
    FOR UPDATE
    TO authenticated
    USING (public.is_station_admin(id, (SELECT auth.uid())))
    WITH CHECK (public.is_station_admin(id, (SELECT auth.uid())));

-- 6. Station Memberships Admin Management Policies
DROP POLICY IF EXISTS station_memberships_update_admins ON public.station_memberships;
CREATE POLICY station_memberships_update_admins ON public.station_memberships
    FOR UPDATE
    TO authenticated
    USING (public.is_station_admin(station_id, (SELECT auth.uid())))
    WITH CHECK (public.is_station_admin(station_id, (SELECT auth.uid())));

DROP POLICY IF EXISTS station_memberships_insert_admins ON public.station_memberships;
CREATE POLICY station_memberships_insert_admins ON public.station_memberships
    FOR INSERT
    TO authenticated
    WITH CHECK (public.is_station_admin(station_id, (SELECT auth.uid())));

-- 7. Colleague Profile Directory View Projection & RLS
-- Station members can see colleagues in their shared active stations
DROP POLICY IF EXISTS profiles_select_colleagues ON public.profiles;
CREATE POLICY profiles_select_colleagues ON public.profiles
    FOR SELECT
    TO authenticated
    USING (
        id = (SELECT auth.uid()) OR
        public.shares_active_station_with(id, (SELECT auth.uid()))
    );

-- Only user themselves or station Admins managing the member can update profile
DROP POLICY IF EXISTS profiles_update_station_admins ON public.profiles;
CREATE POLICY profiles_update_station_admins ON public.profiles
    FOR UPDATE
    TO authenticated
    USING (
        id = (SELECT auth.uid()) OR
        EXISTS (
            SELECT 1 FROM public.station_memberships sm_admin
            JOIN public.station_memberships sm_target ON sm_admin.station_id = sm_target.station_id
            WHERE sm_admin.user_id = (SELECT auth.uid())
              AND sm_admin.role = 'ADMIN'
              AND sm_admin.status = 'ACTIVE'
              AND sm_target.user_id = profiles.id
        )
    )
    WITH CHECK (
        id = (SELECT auth.uid()) OR
        EXISTS (
            SELECT 1 FROM public.station_memberships sm_admin
            JOIN public.station_memberships sm_target ON sm_admin.station_id = sm_target.station_id
            WHERE sm_admin.user_id = (SELECT auth.uid())
              AND sm_admin.role = 'ADMIN'
              AND sm_admin.status = 'ACTIVE'
              AND sm_target.user_id = profiles.id
        )
    );

-- 8. Audit Log Anti-Forgery Hardening
-- Direct client INSERT on audit_logs is disallowed; only trusted SECURITY DEFINER functions write audit logs
DROP POLICY IF EXISTS audit_logs_insert_members ON public.audit_logs;
REVOKE INSERT, UPDATE, DELETE ON public.audit_logs FROM authenticated, anon, PUBLIC;

-- 9. Secure Server-Side RPC Functions for Workforce Operations

-- RPC: List station employees with search, filter, bounded pagination, and deterministic sorting
CREATE OR REPLACE FUNCTION public.admin_get_station_members(
    p_station_id UUID,
    p_search TEXT DEFAULT NULL,
    p_role TEXT DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    membership_id UUID,
    station_id UUID,
    user_id UUID,
    role public.station_role,
    status public.membership_status,
    employee_code TEXT,
    joined_at TIMESTAMPTZ,
    first_name TEXT,
    last_name TEXT,
    phone TEXT,
    preferred_locale TEXT,
    avatar_url TEXT
) AS $$
DECLARE
    v_clean_search TEXT;
    v_safe_limit INTEGER;
    v_safe_offset INTEGER;
BEGIN
    -- Verify caller is an active member of the target station
    IF NOT public.is_station_member(p_station_id, auth.uid()) THEN
        RAISE EXCEPTION 'Access denied: caller is not an active member of this station'
            USING ERRCODE = '42501';
    END IF;

    -- Bound limit between 1 and 100
    v_safe_limit := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
    v_safe_offset := GREATEST(COALESCE(p_offset, 0), 0);

    -- Sanitize search input against wildcard DOS
    IF p_search IS NOT NULL AND TRIM(p_search) <> '' THEN
        v_clean_search := SUBSTRING(TRIM(p_search), 1, 100);
        -- Escape LIKE wildcards for literal matching
        v_clean_search := regexp_replace(v_clean_search, '([%_\\])', '\\\1', 'g');
    ELSE
        v_clean_search := NULL;
    END IF;

    RETURN QUERY
    SELECT 
        sm.id AS membership_id,
        sm.station_id,
        sm.user_id,
        sm.role,
        sm.status,
        sm.employee_code,
        sm.joined_at,
        p.first_name,
        p.last_name,
        p.phone,
        p.preferred_locale,
        p.avatar_url
    FROM public.station_memberships sm
    JOIN public.profiles p ON p.id = sm.user_id
    WHERE sm.station_id = p_station_id
      AND (p_role IS NULL OR sm.role::text = p_role)
      AND (p_status IS NULL OR sm.status::text = p_status)
      AND (
          v_clean_search IS NULL OR
          p.first_name ILIKE '%' || v_clean_search || '%' OR
          p.last_name ILIKE '%' || v_clean_search || '%' OR
          p.phone ILIKE '%' || v_clean_search || '%' OR
          sm.employee_code ILIKE '%' || v_clean_search || '%'
      )
    ORDER BY 
        CASE WHEN sm.status = 'ACTIVE' THEN 0 ELSE 1 END,
        CASE sm.role WHEN 'ADMIN' THEN 0 WHEN 'SHIFT_MANAGER' THEN 1 ELSE 2 END,
        p.last_name ASC,
        p.first_name ASC,
        sm.id ASC
    LIMIT v_safe_limit
    OFFSET v_safe_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- RPC: Admin updates station membership (role, status, employee_code) with audit log
CREATE OR REPLACE FUNCTION public.admin_update_membership(
    p_station_id UUID,
    p_membership_id UUID,
    p_role public.station_role,
    p_status public.membership_status,
    p_employee_code TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_old_role public.station_role;
    v_old_status public.membership_status;
    v_target_user_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF NOT public.is_station_admin(p_station_id, v_caller_id) THEN
        RAISE EXCEPTION 'Access denied: caller is not an administrator of this station'
            USING ERRCODE = '42501';
    END IF;

    SELECT role, status, user_id INTO v_old_role, v_old_status, v_target_user_id
    FROM public.station_memberships
    WHERE id = p_membership_id AND station_id = p_station_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Membership not found in station' USING ERRCODE = 'P0002';
    END IF;

    UPDATE public.station_memberships
    SET role = p_role,
        status = p_status,
        employee_code = p_employee_code,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_membership_id AND station_id = p_station_id;

    -- Append audit logs for sensitive changes
    IF v_old_role <> p_role THEN
        INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
        VALUES (
            p_station_id,
            v_caller_id,
            'MEMBERSHIP_ROLE_CHANGED',
            'station_membership',
            p_membership_id::text,
            jsonb_build_object('old_role', v_old_role, 'new_role', p_role, 'target_user_id', v_target_user_id)
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
            jsonb_build_object('old_status', v_old_status, 'new_status', p_status, 'target_user_id', v_target_user_id)
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'membership_id', p_membership_id,
        'role', p_role,
        'status', p_status
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- RPC: Admin updates station settings with audit log
CREATE OR REPLACE FUNCTION public.admin_update_station(
    p_station_id UUID,
    p_name TEXT,
    p_code TEXT,
    p_timezone TEXT,
    p_locale TEXT,
    p_week_start INTEGER,
    p_is_active BOOLEAN
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_clean_code TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF NOT public.is_station_admin(p_station_id, v_caller_id) THEN
        RAISE EXCEPTION 'Access denied: caller is not an administrator of this station'
            USING ERRCODE = '42501';
    END IF;

    v_clean_code := UPPER(TRIM(p_code));

    IF LENGTH(v_clean_code) < 2 THEN
        RAISE EXCEPTION 'Station code must be at least 2 characters' USING ERRCODE = '22000';
    END IF;

    UPDATE public.stations
    SET name = TRIM(p_name),
        code = v_clean_code,
        timezone = p_timezone,
        locale = p_locale,
        week_start = p_week_start,
        is_active = p_is_active,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_station_id;

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        p_station_id,
        v_caller_id,
        'STATION_UPDATED',
        'station',
        p_station_id::text,
        jsonb_build_object('name', p_name, 'code', v_clean_code, 'timezone', p_timezone)
    );

    RETURN jsonb_build_object('success', true, 'station_id', p_station_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- RPC: Station Pulse Counts (Real Phase 1 Metrics)
CREATE OR REPLACE FUNCTION public.get_station_pulse_counts(p_station_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_total_members INTEGER;
    v_admin_count INTEGER;
    v_manager_count INTEGER;
    v_employee_count INTEGER;
BEGIN
    IF NOT public.is_station_member(p_station_id, auth.uid()) THEN
        RAISE EXCEPTION 'Access denied: caller is not a member of this station'
            USING ERRCODE = '42501';
    END IF;

    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE role = 'ADMIN' AND status = 'ACTIVE'),
        COUNT(*) FILTER (WHERE role = 'SHIFT_MANAGER' AND status = 'ACTIVE'),
        COUNT(*) FILTER (WHERE role = 'EMPLOYEE' AND status = 'ACTIVE')
    INTO 
        v_total_members,
        v_admin_count,
        v_manager_count,
        v_employee_count
    FROM public.station_memberships
    WHERE station_id = p_station_id
      AND status = 'ACTIVE';

    RETURN jsonb_build_object(
        'total_active_members', v_total_members,
        'admin_count', v_admin_count,
        'shift_manager_count', v_manager_count,
        'employee_count', v_employee_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;
