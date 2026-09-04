-- ============================================================================
-- Migration: 20260825000020_station_admin_profile_updates.sql
-- Additive. Does not modify 001–019.
--
-- P00105 forbids grant/revoke (and deactivation) of station ADMIN.
-- It must not block Station Managers from updating their own profile
-- fields or non-privilege membership columns (employee_code) while
-- remaining ADMIN + ACTIVE.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.enforce_station_admin_role_authority()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_jwt_role TEXT;
    v_uid UUID;
    v_admin_privilege_change BOOLEAN := false;
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
        v_admin_privilege_change := (NEW.role = 'ADMIN');
    ELSIF TG_OP = 'UPDATE' THEN
        v_admin_privilege_change :=
            (
                OLD.role IS DISTINCT FROM NEW.role
                AND (OLD.role = 'ADMIN' OR NEW.role = 'ADMIN')
            )
            OR (
                OLD.role = 'ADMIN'
                AND OLD.status IS DISTINCT FROM NEW.status
            );
    ELSIF TG_OP = 'DELETE' THEN
        v_admin_privilege_change := (OLD.role = 'ADMIN');
    END IF;

    IF v_admin_privilege_change AND NOT public.is_platform_admin(v_uid) THEN
        RAISE EXCEPTION 'Only platform administrators may grant or revoke station ADMIN privileges'
            USING ERRCODE = 'P00105';
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

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
        IF p_role = 'ADMIN' AND v_old_role IS DISTINCT FROM 'ADMIN' THEN
            RAISE EXCEPTION 'Station administrators cannot grant or revoke Station Manager (ADMIN) privileges'
                USING ERRCODE = 'P00105';
        END IF;
        IF v_old_role = 'ADMIN' AND (p_role IS DISTINCT FROM 'ADMIN' OR p_status IS DISTINCT FROM v_old_status) THEN
            RAISE EXCEPTION 'Station administrators cannot grant or revoke Station Manager (ADMIN) privileges'
                USING ERRCODE = 'P00105';
        END IF;
        IF v_old_role IS DISTINCT FROM 'ADMIN' AND p_role NOT IN ('EMPLOYEE', 'SHIFT_MANAGER') THEN
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

GRANT EXECUTE ON FUNCTION public.admin_update_membership(UUID, UUID, public.station_role, public.membership_status, TEXT) TO authenticated;
