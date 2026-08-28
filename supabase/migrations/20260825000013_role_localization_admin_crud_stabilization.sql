-- ==============================================================================
-- YellowShifts Migration 013: Role Isolation, Authorization, Localization & Admin CRUD Stabilization
-- ==============================================================================

-- 1. Canonical Phone Normalization Helper
CREATE OR REPLACE FUNCTION public.normalize_phone(p_phone TEXT)
RETURNS TEXT AS $$
DECLARE
    v_clean TEXT;
BEGIN
    IF p_phone IS NULL OR TRIM(p_phone) = '' THEN
        RETURN NULL;
    END IF;

    -- Strip all characters except digits and leading plus
    v_clean := regexp_replace(TRIM(p_phone), '[^\d+]', '', 'g');

    IF v_clean = '' OR v_clean = '+' THEN
        RETURN NULL;
    END IF;

    -- Convert local Israeli numbers (05XXXXXXXX) to E.164 (+9725XXXXXXXX)
    IF v_clean ~ '^05\d{8}$' THEN
        v_clean := '+972' || SUBSTRING(v_clean FROM 2);
    -- Convert 9725XXXXXXXX without plus
    ELSIF v_clean ~ '^9725\d{8}$' THEN
        v_clean := '+' || v_clean;
    -- If starts with a digit without plus, prefix with plus if international format
    ELSIF v_clean ~ '^[1-9]\d{7,14}$' THEN
        v_clean := '+' || v_clean;
    END IF;

    -- Validate E.164 compliance (+ followed by 8 to 15 digits)
    IF NOT (v_clean ~ '^\+[1-9]\d{7,14}$') THEN
        RAISE EXCEPTION 'Invalid phone number format: %', p_phone USING ERRCODE = '22000';
    END IF;

    RETURN v_clean;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;

-- 2. Secure Server-Side RPC: admin_update_employee_profile
-- Allows Station Administrators to update global profile fields (name, phone, locale)
-- with strict station admin verification, anti-cross-station IDOR shield, phone uniqueness validation, and audit logging.
CREATE OR REPLACE FUNCTION public.admin_update_employee_profile(
    p_station_id UUID,
    p_target_user_id UUID,
    p_first_name TEXT,
    p_last_name TEXT,
    p_phone TEXT DEFAULT NULL,
    p_preferred_locale TEXT DEFAULT 'he'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_clean_first TEXT;
    v_clean_last TEXT;
    v_norm_phone TEXT;
    v_locale TEXT;
    v_old_first TEXT;
    v_old_last TEXT;
    v_old_phone TEXT;
    v_old_locale TEXT;
    v_changed_fields TEXT[] := ARRAY[]::TEXT[];
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    -- 1. Verify caller is active ADMIN in target station
    IF NOT public.is_station_admin(p_station_id, v_caller_id) THEN
        RAISE EXCEPTION 'Access denied: only station administrators can edit employee profiles'
            USING ERRCODE = '42501';
    END IF;

    -- 2. Verify target user belongs to target station (anti-cross-station IDOR)
    IF NOT EXISTS (
        SELECT 1 FROM public.station_memberships
        WHERE station_id = p_station_id AND user_id = p_target_user_id
    ) THEN
        RAISE EXCEPTION 'Employee not found in station' USING ERRCODE = 'P0002';
    END IF;

    -- 3. Input Validation & Trimming
    v_clean_first := TRIM(COALESCE(p_first_name, ''));
    v_clean_last := TRIM(COALESCE(p_last_name, ''));

    IF length(v_clean_first) < 1 OR length(v_clean_first) > 100 THEN
        RAISE EXCEPTION 'First name must be between 1 and 100 characters' USING ERRCODE = '22000';
    END IF;

    IF length(v_clean_last) < 1 OR length(v_clean_last) > 100 THEN
        RAISE EXCEPTION 'Last name must be between 1 and 100 characters' USING ERRCODE = '22000';
    END IF;

    -- Normalize Phone
    v_norm_phone := public.normalize_phone(p_phone);
    IF v_norm_phone IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM public.profiles
            WHERE phone = v_norm_phone AND id <> p_target_user_id
        ) THEN
            RAISE EXCEPTION 'Phone number is already associated with another account'
                USING ERRCODE = '23505';
        END IF;
    END IF;

    -- Normalize Locale
    v_locale := LOWER(TRIM(COALESCE(p_preferred_locale, 'he')));
    IF v_locale NOT IN ('he', 'en') THEN
        v_locale := 'he';
    END IF;

    -- 4. Fetch old profile data for audit diff
    SELECT first_name, last_name, phone, preferred_locale
    INTO v_old_first, v_old_last, v_old_phone, v_old_locale
    FROM public.profiles
    WHERE id = p_target_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User profile not found' USING ERRCODE = 'P0002';
    END IF;

    IF v_old_first IS DISTINCT FROM v_clean_first THEN
        v_changed_fields := array_append(v_changed_fields, 'first_name');
    END IF;
    IF v_old_last IS DISTINCT FROM v_clean_last THEN
        v_changed_fields := array_append(v_changed_fields, 'last_name');
    END IF;
    IF v_old_phone IS DISTINCT FROM v_norm_phone THEN
        v_changed_fields := array_append(v_changed_fields, 'phone');
    END IF;
    IF v_old_locale IS DISTINCT FROM v_locale THEN
        v_changed_fields := array_append(v_changed_fields, 'preferred_locale');
    END IF;

    -- 5. Update Profile
    UPDATE public.profiles
    SET first_name = v_clean_first,
        last_name = v_clean_last,
        phone = v_norm_phone,
        preferred_locale = v_locale,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_target_user_id;

    -- 6. Immutable Audit Log
    IF cardinality(v_changed_fields) > 0 THEN
        INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
        VALUES (
            p_station_id,
            v_caller_id,
            'EMPLOYEE_PROFILE_UPDATED',
            'profile',
            p_target_user_id::text,
            jsonb_build_object(
                'target_user_id', p_target_user_id,
                'changed_fields', v_changed_fields,
                'phone_updated', (v_old_phone IS DISTINCT FROM v_norm_phone)
            )
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'user_id', p_target_user_id,
        'first_name', v_clean_first,
        'last_name', v_clean_last,
        'phone', v_norm_phone,
        'preferred_locale', v_locale,
        'changed_fields', v_changed_fields
    );
END;
$$;

-- 3. Hardened admin_update_membership with Last-Admin Invariant Protection
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
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    IF NOT public.is_station_admin(p_station_id, v_caller_id) THEN
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

    -- Last Admin Invariant Protection:
    -- If target is currently an ACTIVE ADMIN and the update attempts to change role to non-ADMIN or status to non-ACTIVE:
    IF v_old_role = 'ADMIN' AND v_old_status = 'ACTIVE' AND (p_role <> 'ADMIN' OR p_status <> 'ACTIVE') THEN
        SELECT COUNT(*) INTO v_active_admins_count
        FROM public.station_memberships
        WHERE station_id = p_station_id AND role = 'ADMIN' AND status = 'ACTIVE';

        IF v_active_admins_count <= 1 THEN
            RAISE EXCEPTION 'Cannot demote or deactivate the last active Administrator of this station'
                USING ERRCODE = 'P0001';
        END IF;
    END IF;

    -- Clean employee code
    v_clean_code := NULLIF(TRIM(COALESCE(p_employee_code, '')), '');
    IF v_clean_code IS NOT NULL AND length(v_clean_code) > 50 THEN
        RAISE EXCEPTION 'Employee code cannot exceed 50 characters' USING ERRCODE = '22000';
    END IF;

    -- Update membership
    UPDATE public.station_memberships
    SET role = p_role,
        status = p_status,
        employee_code = v_clean_code,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_membership_id AND station_id = p_station_id;

    -- Append audit logs
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

    IF v_old_code IS DISTINCT FROM v_clean_code THEN
        INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
        VALUES (
            p_station_id,
            v_caller_id,
            'EMPLOYEE_CODE_UPDATED',
            'station_membership',
            p_membership_id::text,
            jsonb_build_object('old_code', v_old_code, 'new_code', v_clean_code, 'target_user_id', v_target_user_id)
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

-- 4. Hardened admin_get_station_members with Strict Admin Authorization & Email Joining
-- Restricts full administrative directory access to station Administrators (denies raw EMPLOYEEs with 42501).
DROP FUNCTION IF EXISTS public.admin_get_station_members(UUID, TEXT, TEXT, TEXT, INTEGER, INTEGER);

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
    avatar_url TEXT,
    email TEXT
) AS $$
DECLARE
    v_caller_id UUID;
    v_clean_search TEXT;
    v_safe_limit INTEGER;
    v_safe_offset INTEGER;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    -- Restrict directory access to station Administrators (or delegated managers with employees.manage permission)
    IF NOT public.has_station_permission(p_station_id, v_caller_id, 'employees.manage') 
       AND NOT public.is_station_admin(p_station_id, v_caller_id) THEN
        RAISE EXCEPTION 'Access denied: caller does not have employee directory management authority'
            USING ERRCODE = '42501';
    END IF;

    -- Bound limit between 1 and 100
    v_safe_limit := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
    v_safe_offset := GREATEST(COALESCE(p_offset, 0), 0);

    -- Sanitize search input against wildcard DOS
    IF p_search IS NOT NULL AND TRIM(p_search) <> '' THEN
        v_clean_search := SUBSTRING(TRIM(p_search), 1, 100);
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
        p.avatar_url,
        u.email::text AS email
    FROM public.station_memberships sm
    JOIN public.profiles p ON p.id = sm.user_id
    LEFT JOIN auth.users u ON u.id = sm.user_id
    WHERE sm.station_id = p_station_id
      AND (p_role IS NULL OR sm.role::text = p_role)
      AND (p_status IS NULL OR sm.status::text = p_status)
      AND (
          v_clean_search IS NULL OR
          p.first_name ILIKE '%' || v_clean_search || '%' OR
          p.last_name ILIKE '%' || v_clean_search || '%' OR
          p.phone ILIKE '%' || v_clean_search || '%' OR
          sm.employee_code ILIKE '%' || v_clean_search || '%' OR
          u.email ILIKE '%' || v_clean_search || '%'
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp STABLE;

-- Grant execution to authenticated users (functions enforce their own authorization internally)
GRANT EXECUTE ON FUNCTION public.normalize_phone(TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_employee_profile(UUID, UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_membership(UUID, UUID, public.station_role, public.membership_status, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_station_members(UUID, TEXT, TEXT, TEXT, INTEGER, INTEGER) TO authenticated;
