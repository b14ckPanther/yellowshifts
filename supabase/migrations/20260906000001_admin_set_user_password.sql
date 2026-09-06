-- ============================================================================
-- Migration: 20260906000001_admin_set_user_password.sql
-- Additive. Does not modify existing migrations.
--
-- Enables Station Administrators and Platform Administrators to reset and set
-- custom passwords for any station member (employees, shift managers, admins)
-- at any time without requiring the old password.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_set_user_password(
    p_station_id UUID,
    p_target_user_id UUID,
    p_new_password TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_is_platform BOOLEAN;
    v_is_station_admin BOOLEAN;
    v_target_exists BOOLEAN;
    v_clean_password TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_is_platform := public.is_platform_admin(v_caller_id);
    v_is_station_admin := public.is_station_membership_admin(p_station_id, v_caller_id);

    IF NOT v_is_platform AND NOT v_is_station_admin THEN
        RAISE EXCEPTION 'Access denied: caller is not an administrator of this station'
            USING ERRCODE = '42501';
    END IF;

    -- Verify target user exists and belongs to the station (unless platform admin)
    IF NOT v_is_platform THEN
        SELECT EXISTS (
            SELECT 1 FROM public.station_memberships
            WHERE station_id = p_station_id AND user_id = p_target_user_id
        ) INTO v_target_exists;

        IF NOT v_target_exists THEN
            RAISE EXCEPTION 'Target user is not a member of this station'
                USING ERRCODE = 'P0002';
        END IF;
    ELSE
        SELECT EXISTS (
            SELECT 1 FROM auth.users WHERE id = p_target_user_id
        ) INTO v_target_exists;

        IF NOT v_target_exists THEN
            RAISE EXCEPTION 'Target user not found'
                USING ERRCODE = 'P0002';
        END IF;
    END IF;

    v_clean_password := TRIM(p_new_password);
    IF v_clean_password IS NULL OR length(v_clean_password) < 6 THEN
        RAISE EXCEPTION 'Password must be at least 6 characters'
            USING ERRCODE = '22000';
    END IF;

    -- Update password in auth.users using bcrypt salt
    UPDATE auth.users
    SET encrypted_password = extensions.crypt(v_clean_password, extensions.gen_salt('bf')),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_target_user_id;

    -- Invalidate existing sessions and refresh tokens for target user
    BEGIN
        DELETE FROM auth.sessions WHERE user_id = p_target_user_id;
    EXCEPTION WHEN OTHERS THEN
        -- Sessions table might be empty or restricted
    END;

    BEGIN
        DELETE FROM auth.refresh_tokens WHERE user_id = p_target_user_id::text;
    EXCEPTION WHEN OTHERS THEN
        -- Best effort cleanup
    END;

    -- Record audit log
    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        p_station_id,
        v_caller_id,
        'PASSWORD_RESET_COMPLETED',
        'user',
        p_target_user_id::text,
        public.sanitize_audit_metadata(jsonb_build_object(
            'target_user_id', p_target_user_id,
            'actor_scope', CASE WHEN v_is_platform THEN 'PLATFORM_ADMIN' ELSE 'STATION_ADMIN' END
        ))
    );

    RETURN jsonb_build_object(
        'success', true,
        'user_id', p_target_user_id,
        'temporary_password', v_clean_password
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_user_password(UUID, UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_user_password(UUID, UUID, TEXT) TO authenticated, service_role;
