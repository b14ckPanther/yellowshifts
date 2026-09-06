-- ============================================================================
-- Migration: 20260906000002_platform_station_admin_management.sql
-- Additive. Does not modify existing migrations.
--
-- Enables Platform Administrators (Super Admins) to edit existing station
-- managers' details (name, email, phone, employee code) across any station.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.platform_update_station_manager(
    p_station_id UUID,
    p_target_user_id UUID,
    p_first_name TEXT,
    p_last_name TEXT,
    p_email TEXT DEFAULT NULL,
    p_phone TEXT DEFAULT NULL,
    p_employee_code TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_clean_first TEXT;
    v_clean_last TEXT;
    v_clean_email TEXT;
    v_norm_phone TEXT;
    v_clean_code TEXT;
    v_existing_email_user UUID;
BEGIN
    v_caller_id := auth.uid();
    PERFORM public.require_platform_admin();

    -- 1. Validate station exists
    IF NOT EXISTS (SELECT 1 FROM public.stations WHERE id = p_station_id) THEN
        RAISE EXCEPTION 'Station not found' USING ERRCODE = 'P0002';
    END IF;

    -- 2. Validate target user is a member of station
    IF NOT EXISTS (
        SELECT 1 FROM public.station_memberships
        WHERE station_id = p_station_id AND user_id = p_target_user_id
    ) THEN
        RAISE EXCEPTION 'Target user is not a member of this station' USING ERRCODE = 'P0002';
    END IF;

    -- 3. Sanitize inputs
    v_clean_first := TRIM(COALESCE(p_first_name, ''));
    v_clean_last := TRIM(COALESCE(p_last_name, ''));
    IF char_length(v_clean_first) < 1 THEN
        RAISE EXCEPTION 'First name cannot be empty' USING ERRCODE = '22000';
    END IF;
    IF char_length(v_clean_last) < 1 THEN
        RAISE EXCEPTION 'Last name cannot be empty' USING ERRCODE = '22000';
    END IF;

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

    IF p_employee_code IS NOT NULL AND TRIM(p_employee_code) <> '' THEN
        v_clean_code := TRIM(p_employee_code);
    ELSE
        v_clean_code := NULL;
    END IF;

    -- 4. Update Profile
    UPDATE public.profiles
    SET first_name = v_clean_first,
        last_name = v_clean_last,
        phone = v_norm_phone,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_target_user_id;

    -- 5. Update Station Membership employee code
    UPDATE public.station_memberships
    SET employee_code = v_clean_code,
        updated_at = timezone('utc'::text, now())
    WHERE station_id = p_station_id AND user_id = p_target_user_id;

    -- 6. Update Email in auth.users if requested and changed
    IF p_email IS NOT NULL AND TRIM(p_email) <> '' THEN
        v_clean_email := LOWER(TRIM(p_email));
        IF v_clean_email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
            RAISE EXCEPTION 'Invalid email format: %', v_clean_email USING ERRCODE = '22000';
        END IF;

        SELECT id INTO v_existing_email_user
        FROM auth.users
        WHERE email = v_clean_email AND id <> p_target_user_id;

        IF v_existing_email_user IS NOT NULL THEN
            RAISE EXCEPTION 'Email is already in use by another user' USING ERRCODE = '23505';
        END IF;

        UPDATE auth.users
        SET email = v_clean_email,
            raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object(
                'email', v_clean_email,
                'first_name', v_clean_first,
                'last_name', v_clean_last
            ),
            updated_at = timezone('utc'::text, now())
        WHERE id = p_target_user_id;
    END IF;

    -- 7. Audit Log
    INSERT INTO public.audit_logs (
        station_id,
        actor_id,
        action,
        target_type,
        target_id,
        metadata
    ) VALUES (
        p_station_id,
        v_caller_id,
        'PLATFORM_ADMIN_UPDATED_MANAGER_PROFILE',
        'station_membership',
        p_target_user_id::text,
        jsonb_build_object(
            'station_id', p_station_id,
            'target_user_id', p_target_user_id,
            'first_name', v_clean_first,
            'last_name', v_clean_last,
            'email', v_clean_email,
            'phone', v_norm_phone,
            'employee_code', v_clean_code
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'station_id', p_station_id,
        'target_user_id', p_target_user_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.platform_update_station_manager(UUID, UUID, TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.platform_update_station_manager(UUID, UUID, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;
