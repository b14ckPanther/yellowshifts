-- ======================================================================
-- YELLOWSHIFTS — PHASE 5 AUDIT REMEDIATION
-- Migration: 20260825000008_phase5_audit_remediation.sql
-- ======================================================================

-- 1. Hardened cleanup_ephemeral_identity_data with FK Preservation
DROP FUNCTION IF EXISTS public.cleanup_ephemeral_identity_data();
CREATE OR REPLACE FUNCTION public.cleanup_ephemeral_identity_data()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_purged_sessions INTEGER := 0;
    v_purged_proofs INTEGER := 0;
BEGIN
    -- Only service_role can execute global cleanup
    -- (auth.uid() is null when invoked by postgres/service_role)
    v_caller_id := auth.uid();
    IF v_caller_id IS NOT NULL THEN
        RAISE EXCEPTION 'Access denied: Ephemeral cleanup requires service_role privilege' USING ERRCODE = '42501';
    END IF;

    -- Purge expired enrollment sessions older than 1 day
    WITH deleted_ses AS (
        DELETE FROM public.identity_enrollment_sessions
        WHERE expires_at < now() - INTERVAL '1 day'
        RETURNING id
    )
    SELECT count(*) INTO v_purged_sessions FROM deleted_ses;

    -- Purge expired identity proofs that are NOT referenced by attendance_records
    WITH deleted_proofs AS (
        DELETE FROM public.identity_verification_proofs
        WHERE (
            -- Unused expired proofs older than 1 day
            (used_at IS NULL AND expires_at < now() - INTERVAL '1 day')
            OR
            -- Used proofs older than 30 days that are NOT referenced by any attendance record
            (used_at IS NOT NULL AND expires_at < now() - INTERVAL '30 days' AND NOT EXISTS (
                SELECT 1 FROM public.attendance_records ar WHERE ar.identity_verification_proof_id = identity_verification_proofs.id
            ))
        )
        RETURNING id
    )
    SELECT count(*) INTO v_purged_proofs FROM deleted_proofs;

    RETURN jsonb_build_object(
        'success', true,
        'purged_sessions', v_purged_sessions,
        'purged_identity_proofs', v_purged_proofs
    );
END;
$$;

-- Revoke cleanup from authenticated and anon, grant only to service_role
REVOKE ALL ON FUNCTION public.cleanup_ephemeral_identity_data() FROM PUBLIC, anon, authenticated;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        GRANT EXECUTE ON FUNCTION public.cleanup_ephemeral_identity_data() TO service_role;
    END IF;
END $$;

-- 2. Hardened start_identity_enrollment with Production Fail-Closed, Consent & Notice Recording
DROP FUNCTION IF EXISTS public.start_identity_enrollment(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.start_identity_enrollment(TEXT);
CREATE OR REPLACE FUNCTION public.start_identity_enrollment(
    p_provider TEXT,
    p_notice_version TEXT DEFAULT 'v1.0'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_session_id UUID;
    v_provider_session_id TEXT;
    v_expires_at TIMESTAMPTZ;
    v_now TIMESTAMPTZ;
    v_clean_provider TEXT;
    v_clean_notice TEXT;
    v_env TEXT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_clean_provider := trim(p_provider);
    IF v_clean_provider IS NULL OR v_clean_provider = '' THEN
        RAISE EXCEPTION 'Provider is required' USING ERRCODE = 'P0041';
    END IF;

    IF length(v_clean_provider) > 100 THEN
        RAISE EXCEPTION 'Provider identifier exceeds maximum allowed length' USING ERRCODE = '22001';
    END IF;

    v_clean_notice := trim(p_notice_version);
    IF v_clean_notice IS NULL OR v_clean_notice = '' THEN
        RAISE EXCEPTION 'Notice version is required' USING ERRCODE = 'P0041';
    END IF;

    IF length(v_clean_notice) > 50 THEN
        RAISE EXCEPTION 'Notice version exceeds maximum allowed length' USING ERRCODE = '22001';
    END IF;

    -- Fail-Closed in Production
    BEGIN
        v_env := current_setting('app.settings.env', true);
    EXCEPTION WHEN OTHERS THEN
        v_env := 'development';
    END;

    IF v_env = 'production' THEN
        IF v_clean_provider ILIKE '%sandbox%' OR v_clean_provider ILIKE '%mock%' OR v_clean_provider ILIKE '%dev%' THEN
            RAISE EXCEPTION 'Sandbox identity providers are strictly prohibited in production environment'
                USING ERRCODE = 'P0040';
        END IF;
    END IF;

    v_now := now();
    v_session_id := gen_random_uuid();
    v_provider_session_id := 'SES_' || encode(gen_random_bytes(16), 'hex');
    v_expires_at := v_now + INTERVAL '300 seconds';

    -- Expire any existing pending sessions for this user
    UPDATE public.identity_enrollment_sessions
    SET status = 'EXPIRED'
    WHERE employee_user_id = v_user_id AND status = 'PENDING';

    -- Insert active enrollment session
    INSERT INTO public.identity_enrollment_sessions (
        id, employee_user_id, provider, provider_session_id, status, notice_version, expires_at, created_at
    ) VALUES (
        v_session_id, v_user_id, v_clean_provider, v_provider_session_id, 'PENDING', v_clean_notice, v_expires_at, v_now
    );

    -- Ensure profile row exists with recorded consent
    INSERT INTO public.employee_identity_profiles (
        employee_user_id, provider, status, notice_version, consented_at, created_at, updated_at
    ) VALUES (
        v_user_id, v_clean_provider, 'PENDING', v_clean_notice, v_now, v_now, v_now
    )
    ON CONFLICT (employee_user_id) DO UPDATE SET
        provider = EXCLUDED.provider,
        notice_version = EXCLUDED.notice_version,
        consented_at = v_now,
        updated_at = v_now;

    -- Record consent in audit logs
    INSERT INTO public.audit_logs (
        station_id, actor_id, action, target_type, target_id, metadata
    ) VALUES (
        NULL, v_user_id, 'BIOMETRIC_CONSENT_RECORDED', 'identity_enrollment_sessions', v_session_id::text,
        jsonb_build_object(
            'notice_version', v_clean_notice,
            'provider', v_clean_provider,
            'session_id', v_session_id,
            'consented_at', v_now
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'session_id', v_session_id,
        'provider_session_id', v_provider_session_id,
        'expires_at', v_expires_at,
        'ttl_seconds', 300
    );
END;
$$;

-- 3. Hardened complete_identity_enrollment with Row Locking, Global Uniqueness & Lifecycle Support
DROP FUNCTION IF EXISTS public.complete_identity_enrollment(UUID, TEXT, BOOLEAN, TEXT);
DROP FUNCTION IF EXISTS public.complete_identity_enrollment(UUID, TEXT, BOOLEAN);
DROP FUNCTION IF EXISTS public.complete_identity_enrollment(UUID, TEXT);
CREATE OR REPLACE FUNCTION public.complete_identity_enrollment(
    p_session_id UUID,
    p_provider_subject_id TEXT,
    p_is_success BOOLEAN DEFAULT true,
    p_failure_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_session RECORD;
    v_now TIMESTAMPTZ;
    v_clean_subject_id TEXT;
    v_existing_user_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_now := now();

    -- Lock session row for update
    SELECT * INTO v_session
    FROM public.identity_enrollment_sessions
    WHERE id = p_session_id AND employee_user_id = v_user_id
    FOR UPDATE;

    IF v_session.id IS NULL THEN
        RAISE EXCEPTION 'Enrollment session not found' USING ERRCODE = 'P0042';
    END IF;

    IF v_session.status != 'PENDING' THEN
        RAISE EXCEPTION 'Enrollment session is no longer pending' USING ERRCODE = 'P0043';
    END IF;

    IF v_now >= v_session.expires_at THEN
        UPDATE public.identity_enrollment_sessions
        SET status = 'EXPIRED'
        WHERE id = p_session_id;

        RAISE EXCEPTION 'Enrollment session has expired' USING ERRCODE = 'P0044';
    END IF;

    IF p_is_success THEN
        v_clean_subject_id := trim(p_provider_subject_id);
        IF v_clean_subject_id IS NULL OR v_clean_subject_id = '' THEN
            RAISE EXCEPTION 'Provider subject ID is required' USING ERRCODE = 'P0045';
        END IF;

        IF length(v_clean_subject_id) > 255 THEN
            RAISE EXCEPTION 'Provider subject ID exceeds maximum allowed length of 255 characters' USING ERRCODE = '22001';
        END IF;

        -- Concurrency Protection: Lock profile row to serialize concurrent completions
        PERFORM id FROM public.profiles WHERE id = v_user_id FOR UPDATE;

        -- Global Uniqueness Defense: Ensure provider_subject_id is not already linked to another active profile
        SELECT employee_user_id INTO v_existing_user_id
        FROM public.employee_identity_profiles
        WHERE provider_subject_id = v_clean_subject_id AND employee_user_id != v_user_id AND status = 'ACTIVE';

        IF v_existing_user_id IS NOT NULL THEN
            RAISE EXCEPTION 'Provider subject ID is already associated with another employee profile'
                USING ERRCODE = 'P0046';
        END IF;

        -- Upsert employee identity profile
        INSERT INTO public.employee_identity_profiles (
            employee_user_id, status, provider, provider_subject_id,
            enrolled_at, notice_version, consented_at, updated_at
        ) VALUES (
            v_user_id, 'ACTIVE', v_session.provider, v_clean_subject_id,
            v_now, v_session.notice_version, v_now, v_now
        )
        ON CONFLICT (employee_user_id) DO UPDATE
        SET status = 'ACTIVE',
            provider = EXCLUDED.provider,
            provider_subject_id = EXCLUDED.provider_subject_id,
            enrolled_at = EXCLUDED.enrolled_at,
            notice_version = EXCLUDED.notice_version,
            revoked_at = NULL,
            updated_at = EXCLUDED.updated_at;

        -- Mark session as completed
        UPDATE public.identity_enrollment_sessions
        SET status = 'COMPLETED', completed_at = v_now
        WHERE id = p_session_id;

        -- Audit log
        INSERT INTO public.audit_logs (
            station_id, actor_id, action, target_type, target_id, metadata
        ) VALUES (
            NULL, v_user_id, 'IDENTITY_ENROLLMENT_COMPLETED', 'employee_identity_profiles', v_user_id::text,
            jsonb_build_object(
                'provider', v_session.provider,
                'session_id', p_session_id,
                'completed_at', v_now
            )
        );

        RETURN jsonb_build_object(
            'success', true,
            'status', 'ACTIVE',
            'enrolled_at', v_now
        );
    ELSE
        UPDATE public.identity_enrollment_sessions
        SET status = 'FAILED', completed_at = v_now
        WHERE id = p_session_id;

        UPDATE public.employee_identity_profiles
        SET status = 'FAILED', updated_at = v_now
        WHERE employee_user_id = v_user_id;

        RETURN jsonb_build_object(
            'success', false,
            'status', 'FAILED',
            'failure_reason', p_failure_reason
        );
    END IF;
END;
$$;

-- 4. Hardened revoke_identity_profile (Self or Station Admin)
DROP FUNCTION IF EXISTS public.revoke_identity_profile(UUID, TEXT);
DROP FUNCTION IF EXISTS public.revoke_identity_profile(UUID);
CREATE OR REPLACE FUNCTION public.revoke_identity_profile(
    p_employee_user_id UUID,
    p_reason TEXT DEFAULT 'Revoked by user or admin'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_actor_id UUID;
    v_profile RECORD;
    v_now TIMESTAMPTZ;
    v_clean_reason TEXT;
BEGIN
    v_actor_id := auth.uid();
    IF v_actor_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    -- Self-revocation OR Station Admin revocation
    IF v_actor_id != p_employee_user_id THEN
        -- Check if actor is an Admin in ANY station where target employee belongs
        IF NOT EXISTS (
            SELECT 1 
            FROM public.station_memberships sm_target
            JOIN public.station_memberships sm_actor 
              ON sm_target.station_id = sm_actor.station_id
            WHERE sm_target.user_id = p_employee_user_id 
              AND sm_target.status = 'ACTIVE'
              AND sm_actor.user_id = v_actor_id 
              AND sm_actor.role = 'ADMIN' 
              AND sm_actor.status = 'ACTIVE'
        ) THEN
            RAISE EXCEPTION 'Access denied: Only station admins can revoke employee identity profiles'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    v_clean_reason := trim(COALESCE(p_reason, 'Revoked by user or admin'));
    IF length(v_clean_reason) > 500 THEN
        v_clean_reason := substring(v_clean_reason from 1 for 500);
    END IF;

    v_now := now();

    SELECT * INTO v_profile
    FROM public.employee_identity_profiles
    WHERE employee_user_id = p_employee_user_id
    FOR UPDATE;

    IF v_profile.id IS NULL THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'No active profile found to revoke',
            'status', 'NOT_ENROLLED'
        );
    END IF;

    UPDATE public.employee_identity_profiles
    SET status = 'REVOKED',
        provider_subject_id = NULL,
        revoked_at = v_now,
        updated_at = v_now
    WHERE id = v_profile.id;

    INSERT INTO public.audit_logs (
        station_id, actor_id, action, target_type, target_id, metadata
    ) VALUES (
        NULL, v_actor_id, 'IDENTITY_PROFILE_REVOKED', 'employee_identity_profiles', v_profile.id::text,
        jsonb_build_object(
            'employee_user_id', p_employee_user_id,
            'revoked_by', v_actor_id,
            'reason', v_clean_reason,
            'revoked_at', v_now
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'status', 'REVOKED',
        'revoked_at', v_now
    );
END;
$$;

-- 5. Hardened update_station_identity_policy with Fail-Closed Verification
DROP FUNCTION IF EXISTS public.update_station_identity_policy(UUID, public.identity_verification_mode, TEXT);
DROP FUNCTION IF EXISTS public.update_station_identity_policy(UUID, public.identity_verification_mode);
CREATE OR REPLACE FUNCTION public.update_station_identity_policy(
    p_station_id UUID,
    p_mode public.identity_verification_mode
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_admin_id UUID;
    v_prev_mode public.identity_verification_mode;
    v_now TIMESTAMPTZ;
    v_env TEXT;
BEGIN
    v_admin_id := auth.uid();
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    IF NOT public.is_station_admin(p_station_id, v_admin_id) THEN
        RAISE EXCEPTION 'Access denied: Only station admins can configure identity policies' USING ERRCODE = '42501';
    END IF;

    SELECT identity_verification_mode INTO v_prev_mode
    FROM public.stations WHERE id = p_station_id
    FOR UPDATE;

    IF v_prev_mode IS NULL THEN
        RAISE EXCEPTION 'Station not found' USING ERRCODE = 'P0016';
    END IF;

    -- Fail-Closed in Production
    BEGIN
        v_env := current_setting('app.settings.env', true);
    EXCEPTION WHEN OTHERS THEN
        v_env := 'development';
    END;

    IF v_env = 'production' AND p_mode != 'DISABLED' THEN
        RAISE EXCEPTION 'Cannot enable biometric policy in production without a verified production provider'
            USING ERRCODE = 'P0040';
    END IF;

    v_now := now();

    UPDATE public.stations
    SET identity_verification_mode = p_mode,
        updated_at = v_now
    WHERE id = p_station_id;

    -- Audit log
    INSERT INTO public.audit_logs (
        station_id, actor_id, action, target_type, target_id, metadata
    ) VALUES (
        p_station_id, v_admin_id, 'IDENTITY_VERIFICATION_POLICY_UPDATED', 'stations', p_station_id::text,
        jsonb_build_object(
            'previous_mode', v_prev_mode,
            'new_mode', p_mode,
            'updated_at', v_now
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'station_id', p_station_id,
        'identity_verification_mode', p_mode
    );
END;
$$;

-- 6. Hardened Kiosk Provisioning & Authentication RPCs (Native sha256)
DROP FUNCTION IF EXISTS public.provision_kiosk_device(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.provision_kiosk_device(UUID, TEXT);
CREATE OR REPLACE FUNCTION public.provision_kiosk_device(
    p_station_id UUID,
    p_name TEXT,
    p_device_identifier TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_clean_name TEXT;
    v_clean_identifier TEXT;
    v_raw_secret TEXT;
    v_secret_hash TEXT;
    v_device_id UUID;
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    IF NOT public.has_station_permission(p_station_id, 'MANAGE_SETTINGS') THEN
        RAISE EXCEPTION 'Access denied: caller cannot provision kiosk devices' USING ERRCODE = '42501';
    END IF;

    v_clean_name := trim(p_name);
    v_clean_identifier := trim(p_device_identifier);

    IF v_clean_identifier = '' OR v_clean_name = '' THEN
        RAISE EXCEPTION 'Device identifier and name cannot be blank' USING ERRCODE = 'P0015';
    END IF;

    v_raw_secret := 'KS_' || encode(gen_random_bytes(32), 'hex');
    v_secret_hash := encode(sha256(v_raw_secret::bytea), 'hex');

    INSERT INTO public.kiosk_devices (
        station_id, device_identifier, name, secret_hash, credential_version, is_active
    ) VALUES (
        p_station_id, v_clean_identifier, v_clean_name, v_secret_hash, 1, true
    )
    ON CONFLICT (station_id, device_identifier) DO UPDATE
    SET name = EXCLUDED.name,
        secret_hash = EXCLUDED.secret_hash,
        credential_version = public.kiosk_devices.credential_version + 1,
        is_active = true,
        updated_at = now()
    RETURNING id INTO v_device_id;

    RETURN jsonb_build_object(
        'success', true,
        'kiosk_device_id', v_device_id,
        'device_identifier', v_clean_identifier,
        'device_secret', v_raw_secret,
        'station_id', p_station_id,
        'message', 'Store device_secret securely. It is only returned once.'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP FUNCTION IF EXISTS public.rotate_kiosk_credentials(UUID, UUID);
CREATE OR REPLACE FUNCTION public.rotate_kiosk_credentials(
    p_station_id UUID,
    p_kiosk_device_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_kiosk RECORD;
    v_raw_secret TEXT;
    v_secret_hash TEXT;
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    IF NOT public.has_station_permission(p_station_id, 'MANAGE_SETTINGS') THEN
        RAISE EXCEPTION 'Access denied: caller cannot rotate kiosk credentials' USING ERRCODE = '42501';
    END IF;

    SELECT id, credential_version INTO v_kiosk
    FROM public.kiosk_devices
    WHERE id = p_kiosk_device_id AND station_id = p_station_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Kiosk device not found' USING ERRCODE = 'P0016';
    END IF;

    v_raw_secret := 'KS_' || encode(gen_random_bytes(32), 'hex');
    v_secret_hash := encode(sha256(v_raw_secret::bytea), 'hex');

    UPDATE public.kiosk_devices
    SET secret_hash = v_secret_hash,
        credential_version = v_kiosk.credential_version + 1,
        updated_at = now()
    WHERE id = v_kiosk.id;

    UPDATE public.kiosk_qr_challenges
    SET revoked_at = now()
    WHERE kiosk_device_id = v_kiosk.id AND revoked_at IS NULL;

    RETURN jsonb_build_object(
        'success', true,
        'kiosk_device_id', v_kiosk.id,
        'new_device_secret', v_raw_secret,
        'new_version', v_kiosk.credential_version + 1
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP FUNCTION IF EXISTS public.kiosk_authenticate_and_mint_qr(UUID, TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.kiosk_authenticate_and_mint_qr(
    p_station_id UUID,
    p_device_identifier TEXT,
    p_device_secret TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_kiosk RECORD;
    v_station_name TEXT;
    v_station_active BOOLEAN;
    v_provided_hash TEXT;
    v_qr_token TEXT;
    v_challenge_hash TEXT;
    v_display_code TEXT;
    v_expires_at TIMESTAMPTZ;
    v_recent_failed_attempts INTEGER;
BEGIN
    SELECT count(*) INTO v_recent_failed_attempts
    FROM public.attendance_rate_limit_attempts
    WHERE target_identifier = trim(p_device_identifier)
      AND action = 'KIOSK_AUTH'
      AND is_success = false
      AND attempted_at > (now() - INTERVAL '5 minutes');

    IF v_recent_failed_attempts >= 10 THEN
        RAISE EXCEPTION 'Too many failed authentication attempts. Device temporarily locked.'
            USING ERRCODE = 'P0038';
    END IF;

    SELECT name, is_active INTO v_station_name, v_station_active
    FROM public.stations WHERE id = p_station_id;

    IF NOT FOUND OR NOT v_station_active THEN
        INSERT INTO public.attendance_rate_limit_attempts (target_identifier, action, is_success)
        VALUES (trim(p_device_identifier), 'KIOSK_AUTH', false);
        RAISE EXCEPTION 'Station not found or inactive' USING ERRCODE = 'P0017';
    END IF;

    SELECT id, secret_hash, credential_version, is_active
    INTO v_kiosk
    FROM public.kiosk_devices
    WHERE station_id = p_station_id AND device_identifier = trim(p_device_identifier);

    IF NOT FOUND THEN
        INSERT INTO public.attendance_rate_limit_attempts (target_identifier, action, is_success)
        VALUES (trim(p_device_identifier), 'KIOSK_AUTH', false);
        RAISE EXCEPTION 'Kiosk device not found' USING ERRCODE = 'P0016';
    END IF;

    IF NOT v_kiosk.is_active THEN
        INSERT INTO public.attendance_rate_limit_attempts (target_identifier, action, is_success)
        VALUES (trim(p_device_identifier), 'KIOSK_AUTH', false);
        RAISE EXCEPTION 'Kiosk device is inactive' USING ERRCODE = 'P0018';
    END IF;

    v_provided_hash := encode(sha256(p_device_secret::bytea), 'hex');
    IF v_provided_hash <> v_kiosk.secret_hash THEN
        INSERT INTO public.attendance_rate_limit_attempts (target_identifier, action, is_success)
        VALUES (trim(p_device_identifier), 'KIOSK_AUTH', false);
        RAISE EXCEPTION 'Invalid kiosk credentials' USING ERRCODE = 'P0019';
    END IF;

    INSERT INTO public.attendance_rate_limit_attempts (target_identifier, action, is_success)
    VALUES (trim(p_device_identifier), 'KIOSK_AUTH', true);

    UPDATE public.kiosk_devices
    SET last_seen_at = now()
    WHERE id = v_kiosk.id;

    v_qr_token := 'YQ_' || encode(gen_random_bytes(16), 'hex');
    v_challenge_hash := encode(sha256(v_qr_token::bytea), 'hex');
    
    LOOP
        v_display_code := upper(substring(encode(gen_random_bytes(4), 'hex') from 1 for 6));
        EXIT WHEN NOT EXISTS (
            SELECT 1 FROM public.kiosk_qr_challenges
            WHERE display_code = v_display_code 
              AND revoked_at IS NULL 
              AND expires_at > now()
        );
    END LOOP;

    v_expires_at := now() + INTERVAL '30 seconds';

    UPDATE public.kiosk_qr_challenges
    SET revoked_at = now()
    WHERE kiosk_device_id = v_kiosk.id AND revoked_at IS NULL;

    INSERT INTO public.kiosk_qr_challenges (
        station_id, kiosk_device_id, challenge_hash, display_code, expires_at
    ) VALUES (
        p_station_id, v_kiosk.id, v_challenge_hash, v_display_code, v_expires_at
    );

    RETURN jsonb_build_object(
        'success', true,
        'qr_token', v_qr_token,
        'display_code', v_display_code,
        'expires_at', v_expires_at,
        'ttl_seconds', 30,
        'station_id', p_station_id,
        'station_name', v_station_name,
        'server_time', now()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 7. Hardened scan_attendance_qr (Native sha256)
DROP FUNCTION IF EXISTS public.scan_attendance_qr(TEXT);
CREATE OR REPLACE FUNCTION public.scan_attendance_qr(
    p_qr_token_or_code TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_clean_input TEXT;
    v_input_hash TEXT;
    v_challenge RECORD;
    v_membership RECORD;
    v_open_record RECORD;
    v_action public.attendance_action;
    v_shift RECORD;
    v_presence_token TEXT;
    v_token_hash TEXT;
    v_proof_expires_at TIMESTAMPTZ;
    v_shift_preview JSONB := NULL;
    v_now TIMESTAMPTZ := now();
    v_matching_shift_count INTEGER := 0;
    v_recent_failed_scans INTEGER;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    -- Brute force rate limit: max 30 failed scans per minute per employee
    SELECT count(*) INTO v_recent_failed_scans
    FROM public.attendance_rate_limit_attempts
    WHERE actor_id = v_user_id
      AND action = 'QR_SCAN'
      AND is_success = false
      AND attempted_at > (v_now - INTERVAL '1 minute');

    IF v_recent_failed_scans >= 30 THEN
        RAISE EXCEPTION 'Too many invalid scan attempts. Please wait a minute.'
            USING ERRCODE = 'P0037';
    END IF;

    v_clean_input := trim(p_qr_token_or_code);
    v_input_hash := encode(sha256(v_clean_input::bytea), 'hex');

    -- Lookup challenge by token hash or display code
    SELECT c.id, c.station_id, c.kiosk_device_id, c.expires_at, c.revoked_at,
           k.is_active AS kiosk_active, s.is_active AS station_active, s.name AS station_name,
           s.check_in_early_minutes, s.late_grace_minutes
    INTO v_challenge
    FROM public.kiosk_qr_challenges c
    JOIN public.kiosk_devices k ON c.kiosk_device_id = k.id
    JOIN public.stations s ON c.station_id = s.id
    WHERE (c.challenge_hash = v_input_hash OR upper(c.display_code) = upper(v_clean_input))
      AND c.revoked_at IS NULL
    ORDER BY c.created_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
        INSERT INTO public.attendance_rate_limit_attempts (actor_id, target_identifier, action, is_success)
        VALUES (v_user_id, v_clean_input, 'QR_SCAN', false);
        RAISE EXCEPTION 'Invalid attendance QR or manual code' USING ERRCODE = 'P0020';
    END IF;

    IF v_challenge.expires_at <= v_now THEN
        INSERT INTO public.attendance_rate_limit_attempts (actor_id, target_identifier, action, is_success)
        VALUES (v_user_id, v_clean_input, 'QR_SCAN', false);
        RAISE EXCEPTION 'QR challenge has expired' USING ERRCODE = 'P0021';
    END IF;

    IF NOT v_challenge.kiosk_active OR NOT v_challenge.station_active THEN
        INSERT INTO public.attendance_rate_limit_attempts (actor_id, target_identifier, action, is_success)
        VALUES (v_user_id, v_clean_input, 'QR_SCAN', false);
        RAISE EXCEPTION 'Kiosk or station is inactive' USING ERRCODE = 'P0022';
    END IF;

    -- Verify employee has ACTIVE membership for this station
    SELECT id, role, status INTO v_membership
    FROM public.station_memberships
    WHERE station_id = v_challenge.station_id AND user_id = v_user_id;

    IF NOT FOUND OR v_membership.status <> 'ACTIVE' THEN
        INSERT INTO public.attendance_rate_limit_attempts (actor_id, target_identifier, action, is_success)
        VALUES (v_user_id, v_clean_input, 'QR_SCAN', false);
        RAISE EXCEPTION 'Access denied: caller is not an active member of this station' USING ERRCODE = '42501';
    END IF;

    -- Check if employee already has an open attendance session anywhere globally
    SELECT id, station_id, check_in_time, shift_name_snapshot, scheduled_start_at_snapshot, scheduled_end_at_snapshot
    INTO v_open_record
    FROM public.attendance_records
    WHERE employee_user_id = v_user_id AND check_out_time IS NULL;

    IF FOUND THEN
        IF v_open_record.station_id <> v_challenge.station_id THEN
            RAISE EXCEPTION 'Employee already has an open attendance session at another station'
                USING ERRCODE = 'P0023';
        END IF;

        -- Action is CHECK_OUT for current station
        v_action := 'CHECK_OUT';
        v_shift_preview := jsonb_build_object(
            'attendance_id', v_open_record.id,
            'shift_name', v_open_record.shift_name_snapshot,
            'check_in_time', v_open_record.check_in_time,
            'elapsed_minutes', GREATEST(0, floor(extract(epoch from (v_now - v_open_record.check_in_time)) / 60.0)::INTEGER)
        );
    ELSE
        -- Action is CHECK_IN -> Resolve published shift assignment
        v_action := 'CHECK_IN';

        -- Check matching published shifts count for ambiguity detection
        SELECT count(*) INTO v_matching_shift_count
        FROM public.shift_assignments sa
        JOIN public.work_schedule_shifts wss ON sa.work_schedule_shift_id = wss.id
        JOIN public.work_schedules ws ON wss.work_schedule_id = ws.id
        WHERE sa.user_id = v_user_id
          AND wss.station_id = v_challenge.station_id
          AND ws.status = 'PUBLISHED'
          AND (v_now >= (wss.starts_at - (v_challenge.check_in_early_minutes * INTERVAL '1 minute')))
          AND (v_now < wss.ends_at);

        IF v_matching_shift_count = 0 THEN
            RAISE EXCEPTION 'No published shift assignment found for check-in window' USING ERRCODE = 'P0024';
        END IF;

        -- If multiple shifts match at identical start time / distance, raise ambiguous shift error
        IF v_matching_shift_count > 1 THEN
            IF EXISTS (
                SELECT 1
                FROM (
                    SELECT wss.starts_at, count(*) AS c
                    FROM public.shift_assignments sa
                    JOIN public.work_schedule_shifts wss ON sa.work_schedule_shift_id = wss.id
                    JOIN public.work_schedules ws ON wss.work_schedule_id = ws.id
                    WHERE sa.user_id = v_user_id
                      AND wss.station_id = v_challenge.station_id
                      AND ws.status = 'PUBLISHED'
                      AND (v_now >= (wss.starts_at - (v_challenge.check_in_early_minutes * INTERVAL '1 minute')))
                      AND (v_now < wss.ends_at)
                    GROUP BY wss.starts_at
                    HAVING count(*) > 1
                ) sub
            ) THEN
                RAISE EXCEPTION 'Multiple conflicting shift assignments found. Please contact station manager.'
                    USING ERRCODE = 'P0036';
            END IF;
        END IF;

        SELECT wss.id AS shift_id, wss.work_schedule_id, sa.id AS assignment_id,
               ws.version AS schedule_version, wss.shift_name_snapshot,
               wss.starts_at, wss.ends_at, wss.operational_date
        INTO v_shift
        FROM public.shift_assignments sa
        JOIN public.work_schedule_shifts wss ON sa.work_schedule_shift_id = wss.id
        JOIN public.work_schedules ws ON wss.work_schedule_id = ws.id
        WHERE sa.user_id = v_user_id
          AND wss.station_id = v_challenge.station_id
          AND ws.status = 'PUBLISHED'
          AND (v_now >= (wss.starts_at - (v_challenge.check_in_early_minutes * INTERVAL '1 minute')))
          AND (v_now < wss.ends_at)
        ORDER BY abs(extract(epoch from (v_now - wss.starts_at))) ASC, wss.starts_at ASC, wss.id ASC
        LIMIT 1;

        v_shift_preview := jsonb_build_object(
            'shift_id', v_shift.shift_id,
            'shift_name', v_shift.shift_name_snapshot,
            'operational_date', v_shift.operational_date,
            'starts_at', v_shift.starts_at,
            'ends_at', v_shift.ends_at
        );
    END IF;

    -- Issue 60-second single-use presence proof
    v_presence_token := 'PP_' || encode(gen_random_bytes(16), 'hex');
    v_token_hash := encode(sha256(v_presence_token::bytea), 'hex');
    v_proof_expires_at := v_now + INTERVAL '60 seconds';

    INSERT INTO public.attendance_presence_proofs (
        station_id, employee_user_id, station_membership_id, kiosk_device_id,
        qr_challenge_id, action, token_hash, expires_at
    ) VALUES (
        v_challenge.station_id, v_user_id, v_membership.id, v_challenge.kiosk_device_id,
        v_challenge.id, v_action, v_token_hash, v_proof_expires_at
    );

    -- Log scan attempt success
    INSERT INTO public.attendance_rate_limit_attempts (actor_id, target_identifier, action, is_success)
    VALUES (v_user_id, v_clean_input, 'QR_SCAN', true);

    RETURN jsonb_build_object(
        'success', true,
        'presence_proof_token', v_presence_token,
        'action', v_action,
        'expires_at', v_proof_expires_at,
        'station_id', v_challenge.station_id,
        'station_name', v_challenge.station_name,
        'shift_preview', v_shift_preview
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 8. Hardened start_identity_verification with Presence Binding & Bounded Bridge
DROP FUNCTION IF EXISTS public.start_identity_verification(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.start_identity_verification(TEXT);
CREATE OR REPLACE FUNCTION public.start_identity_verification(
    p_presence_proof_token TEXT,
    p_provider TEXT DEFAULT 'SANDBOX_PROVIDER'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_token_hash TEXT;
    v_proof RECORD;
    v_profile RECORD;
    v_station RECORD;
    v_attempt_id UUID;
    v_provider_session_id TEXT;
    v_now TIMESTAMPTZ;
    v_clean_provider TEXT;
    v_env TEXT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_clean_provider := trim(COALESCE(p_provider, 'SANDBOX_PROVIDER'));
    IF length(v_clean_provider) > 100 THEN
        RAISE EXCEPTION 'Provider identifier exceeds maximum allowed length' USING ERRCODE = '22001';
    END IF;

    -- Fail-Closed in Production
    BEGIN
        v_env := current_setting('app.settings.env', true);
    EXCEPTION WHEN OTHERS THEN
        v_env := 'development';
    END;

    IF v_env = 'production' THEN
        IF v_clean_provider ILIKE '%sandbox%' OR v_clean_provider ILIKE '%mock%' OR v_clean_provider ILIKE '%dev%' THEN
            RAISE EXCEPTION 'Sandbox identity providers are strictly prohibited in production environment'
                USING ERRCODE = 'P0040';
        END IF;
    END IF;

    v_now := now();
    v_token_hash := encode(sha256(p_presence_proof_token::bytea), 'hex');

    -- Validate presence proof
    SELECT * INTO v_proof
    FROM public.attendance_presence_proofs
    WHERE token_hash = v_token_hash
    FOR UPDATE;

    IF v_proof.id IS NULL THEN
        RAISE EXCEPTION 'Invalid presence proof token' USING ERRCODE = 'P0025';
    END IF;

    IF v_proof.used_at IS NOT NULL THEN
        RAISE EXCEPTION 'Presence proof has already been used' USING ERRCODE = 'P0026';
    END IF;

    IF v_now >= v_proof.expires_at THEN
        RAISE EXCEPTION 'Presence proof has expired' USING ERRCODE = 'P0027';
    END IF;

    IF v_proof.employee_user_id != v_user_id THEN
        RAISE EXCEPTION 'Presence proof belongs to another employee' USING ERRCODE = 'P0028';
    END IF;

    -- Validate station policy
    SELECT * INTO v_station FROM public.stations WHERE id = v_proof.station_id;

    -- Validate employee identity profile
    SELECT * INTO v_profile
    FROM public.employee_identity_profiles
    WHERE employee_user_id = v_user_id;

    IF v_profile.id IS NULL OR v_profile.status != 'ACTIVE' THEN
        RAISE EXCEPTION 'Employee is not actively enrolled in identity verification' USING ERRCODE = 'P0047';
    END IF;

    v_attempt_id := gen_random_uuid();
    v_provider_session_id := 'VER_' || encode(gen_random_bytes(16), 'hex');

    -- Create pending attempt record
    INSERT INTO public.identity_verification_attempts (
        id, employee_user_id, station_id, presence_proof_id, provider, provider_session_id, result, created_at
    ) VALUES (
        v_attempt_id, v_user_id, v_proof.station_id, v_proof.id, v_clean_provider, v_provider_session_id, 'INCONCLUSIVE', v_now
    );

    RETURN jsonb_build_object(
        'success', true,
        'attempt_id', v_attempt_id,
        'provider_session_id', v_provider_session_id,
        'station_id', v_proof.station_id,
        'action', v_proof.action,
        'presence_proof_id', v_proof.id
    );
END;
$$;

-- 9. Hardened complete_identity_verification with Row Locking & Mid-Flow Revocation Defense
DROP FUNCTION IF EXISTS public.complete_identity_verification(UUID, BOOLEAN, TEXT);
DROP FUNCTION IF EXISTS public.complete_identity_verification(UUID, BOOLEAN);
CREATE OR REPLACE FUNCTION public.complete_identity_verification(
    p_attempt_id UUID,
    p_is_verified BOOLEAN,
    p_failure_category TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_attempt RECORD;
    v_proof_token TEXT;
    v_token_hash TEXT;
    v_proof_id UUID;
    v_now TIMESTAMPTZ;
    v_expires_at TIMESTAMPTZ;
    v_presence_proof RECORD;
    v_profile RECORD;
    v_clean_reason TEXT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_clean_reason := trim(p_failure_category);
    IF v_clean_reason IS NOT NULL AND length(v_clean_reason) > 100 THEN
        v_clean_reason := substring(v_clean_reason from 1 for 100);
    END IF;

    v_now := now();

    -- Lock and validate attempt
    SELECT * INTO v_attempt
    FROM public.identity_verification_attempts
    WHERE id = p_attempt_id
    FOR UPDATE;

    IF v_attempt.id IS NULL THEN
        RAISE EXCEPTION 'Verification attempt not found' USING ERRCODE = 'P0048';
    END IF;

    IF v_attempt.employee_user_id != v_user_id THEN
        RAISE EXCEPTION 'Verification attempt belongs to another employee' USING ERRCODE = 'P0048';
    END IF;

    IF v_attempt.completed_at IS NOT NULL THEN
        RAISE EXCEPTION 'Verification attempt has already been finalized' USING ERRCODE = 'P0049';
    END IF;

    IF v_now >= v_attempt.created_at + INTERVAL '120 seconds' THEN
        UPDATE public.identity_verification_attempts
        SET result = 'NOT_VERIFIED', failure_category = 'EXPIRED', completed_at = v_now
        WHERE id = p_attempt_id;

        RAISE EXCEPTION 'Verification attempt has expired' USING ERRCODE = 'P0044';
    END IF;

    -- Verify presence proof is still linked and unconsumed
    SELECT * INTO v_presence_proof
    FROM public.attendance_presence_proofs
    WHERE id = v_attempt.presence_proof_id
    FOR UPDATE;

    IF v_presence_proof.id IS NULL OR v_presence_proof.used_at IS NOT NULL THEN
        RAISE EXCEPTION 'Associated presence proof has already been used' USING ERRCODE = 'P0026';
    END IF;

    -- Mid-Flow Revocation Defense: Re-verify employee identity profile is still active
    SELECT * INTO v_profile
    FROM public.employee_identity_profiles
    WHERE employee_user_id = v_user_id
    FOR UPDATE;

    IF v_profile.id IS NULL OR v_profile.status != 'ACTIVE' THEN
        UPDATE public.identity_verification_attempts
        SET result = 'NOT_VERIFIED',
            failure_category = 'PROFILE_REVOKED',
            completed_at = v_now
        WHERE id = p_attempt_id;

        RAISE EXCEPTION 'Employee identity profile is revoked or inactive' USING ERRCODE = 'P0047';
    END IF;

    IF p_is_verified THEN
        -- Generate single-use identity proof token (120s TTL)
        v_proof_token := 'IDP_' || encode(gen_random_bytes(24), 'hex');
        v_token_hash := encode(sha256(v_proof_token::bytea), 'hex');
        v_expires_at := v_now + INTERVAL '120 seconds';
        v_proof_id := gen_random_uuid();

        UPDATE public.identity_verification_attempts
        SET result = 'VERIFIED', completed_at = v_now
        WHERE id = v_attempt.id;

        INSERT INTO public.identity_verification_proofs (
            id, employee_user_id, station_id, presence_proof_id, verification_attempt_id,
            action, token_hash, is_override, expires_at, created_at
        ) VALUES (
            v_proof_id, v_user_id, v_attempt.station_id, v_attempt.presence_proof_id, v_attempt.id,
            v_presence_proof.action, v_token_hash, false, v_expires_at, v_now
        );

        UPDATE public.employee_identity_profiles
        SET last_verified_at = v_now, updated_at = v_now
        WHERE employee_user_id = v_user_id;

        RETURN jsonb_build_object(
            'success', true,
            'result', 'VERIFIED',
            'identity_proof_token', v_proof_token,
            'expires_at', v_expires_at,
            'action', v_presence_proof.action
        );
    ELSE
        UPDATE public.identity_verification_attempts
        SET result = 'NOT_VERIFIED',
            failure_category = coalesce(v_clean_reason, 'VERIFICATION_FAILED'),
            completed_at = v_now
        WHERE id = v_attempt.id;

        RETURN jsonb_build_object(
            'success', false,
            'result', 'NOT_VERIFIED',
            'failure_category', coalesce(v_clean_reason, 'VERIFICATION_FAILED')
        );
    END IF;
END;
$$;

-- 10. Hardened create_identity_admin_override (Native sha256)
DROP FUNCTION IF EXISTS public.create_identity_admin_override(TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.create_identity_admin_override(
    p_presence_proof_token TEXT,
    p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_admin_id UUID;
    v_token_hash TEXT;
    v_proof RECORD;
    v_attempt_id UUID;
    v_id_proof_id UUID;
    v_id_proof_token TEXT;
    v_id_token_hash TEXT;
    v_now TIMESTAMPTZ;
    v_expires_at TIMESTAMPTZ;
    v_clean_reason TEXT;
BEGIN
    v_admin_id := auth.uid();
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_clean_reason := trim(p_reason);
    IF v_clean_reason IS NULL OR length(v_clean_reason) < 3 THEN
        RAISE EXCEPTION 'Override reason must be at least 3 characters long' USING ERRCODE = 'P0032';
    END IF;

    IF length(v_clean_reason) > 500 THEN
        v_clean_reason := substring(v_clean_reason from 1 for 500);
    END IF;

    v_now := now();
    v_token_hash := encode(sha256(p_presence_proof_token::bytea), 'hex');

    -- Validate presence proof
    SELECT * INTO v_proof
    FROM public.attendance_presence_proofs
    WHERE token_hash = v_token_hash
    FOR UPDATE;

    IF v_proof.id IS NULL THEN
        RAISE EXCEPTION 'Invalid presence proof token' USING ERRCODE = 'P0025';
    END IF;

    IF v_proof.used_at IS NOT NULL THEN
        RAISE EXCEPTION 'Presence proof has already been used' USING ERRCODE = 'P0026';
    END IF;

    IF v_now >= v_proof.expires_at THEN
        RAISE EXCEPTION 'Presence proof has expired' USING ERRCODE = 'P0027';
    END IF;

    -- Must be admin of target station
    IF NOT public.is_station_admin(v_proof.station_id, v_admin_id) THEN
        RAISE EXCEPTION 'Access denied: Only station admins can authorize identity overrides' USING ERRCODE = '42501';
    END IF;

    v_attempt_id := gen_random_uuid();
    v_id_proof_id := gen_random_uuid();
    v_id_proof_token := 'IDO_' || encode(gen_random_bytes(24), 'hex');
    v_id_token_hash := encode(sha256(v_id_proof_token::bytea), 'hex');
    v_expires_at := v_now + INTERVAL '120 seconds';

    -- Record override attempt in ledger
    INSERT INTO public.identity_verification_attempts (
        id, employee_user_id, station_id, presence_proof_id, provider,
        result, is_override, override_actor_id, override_reason, created_at, completed_at
    ) VALUES (
        v_attempt_id, v_proof.employee_user_id, v_proof.station_id, v_proof.id, 'MANUAL_ADMIN_OVERRIDE',
        'VERIFIED', true, v_admin_id, v_clean_reason, v_now, v_now
    );

    -- Mint presence-bound override identity proof
    INSERT INTO public.identity_verification_proofs (
        id, employee_user_id, station_id, presence_proof_id, verification_attempt_id,
        action, token_hash, is_override, expires_at, created_at
    ) VALUES (
        v_id_proof_id, v_proof.employee_user_id, v_proof.station_id, v_proof.id, v_attempt_id,
        v_proof.action, v_id_token_hash, true, v_expires_at, v_now
    );

    -- Log audit trail
    INSERT INTO public.audit_logs (
        station_id, actor_id, action, target_type, target_id, metadata
    ) VALUES (
        v_proof.station_id, v_admin_id, 'IDENTITY_VERIFICATION_OVERRIDE', 'attendance_presence_proofs', v_proof.id::text,
        jsonb_build_object(
            'employee_user_id', v_proof.employee_user_id,
            'reason', v_clean_reason,
            'action', v_proof.action,
            'created_at', v_now
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'override_id', v_attempt_id,
        'identity_proof_token', v_id_proof_token,
        'expires_at', v_expires_at,
        'action', v_proof.action
    );
END;
$$;

-- 11. Drop Obsolete 1-Parameter Overloads to Guarantee Unambiguous Resolution
DROP FUNCTION IF EXISTS public.check_in_with_presence_proof(TEXT);
DROP FUNCTION IF EXISTS public.check_in_with_presence_proof(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.check_out_with_presence_proof(TEXT);
DROP FUNCTION IF EXISTS public.check_out_with_presence_proof(TEXT, TEXT);

-- 12. Hardened check_in_with_presence_proof with Authoritative Bounded Bridge & Policy Enforcement (2 Arguments, No Defaults)
CREATE OR REPLACE FUNCTION public.check_in_with_presence_proof(
    p_presence_proof_token TEXT,
    p_identity_proof_token TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_token_hash TEXT;
    v_proof RECORD;
    v_station RECORD;
    v_kiosk RECORD;
    v_membership RECORD;
    v_shift RECORD;
    v_open_rec RECORD;
    v_id_proof RECORD;
    v_id_token_hash TEXT;
    v_profile RECORD;
    v_now TIMESTAMPTZ;
    v_new_att_id UUID;
    v_has_valid_id_proof BOOLEAN := false;
    v_ver_method public.attendance_verification_method := 'QR_ONLY';
    v_id_proof_id UUID := NULL;
    v_diff_minutes INTEGER;
    v_late_minutes INTEGER;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_now := now();
    v_token_hash := encode(sha256(p_presence_proof_token::bytea), 'hex');

    -- Lock presence proof row
    SELECT * INTO v_proof
    FROM public.attendance_presence_proofs
    WHERE token_hash = v_token_hash
    FOR UPDATE;

    IF v_proof.id IS NULL THEN
        RAISE EXCEPTION 'Invalid presence proof token' USING ERRCODE = 'P0025';
    END IF;

    IF v_proof.used_at IS NOT NULL THEN
        RAISE EXCEPTION 'Presence proof has already been used' USING ERRCODE = 'P0026';
    END IF;

    IF v_proof.employee_user_id != v_user_id THEN
        RAISE EXCEPTION 'Presence proof belongs to another employee' USING ERRCODE = 'P0028';
    END IF;

    IF v_proof.action != 'CHECK_IN' THEN
        RAISE EXCEPTION 'Presence proof action mismatch' USING ERRCODE = 'P0029';
    END IF;

    -- Fetch station configuration
    SELECT * INTO v_station FROM public.stations WHERE id = v_proof.station_id;
    IF v_station.id IS NULL OR NOT v_station.is_active THEN
        RAISE EXCEPTION 'Station is inactive or deactivated' USING ERRCODE = 'P0017';
    END IF;

    -- Identity Verification Policy Enforcement
    IF v_station.identity_verification_mode IN ('CHECK_IN_ONLY', 'CHECK_IN_AND_CHECK_OUT') THEN
        IF p_identity_proof_token IS NULL OR trim(p_identity_proof_token) = '' THEN
            RAISE EXCEPTION 'Identity verification is required for check-in at this station'
                USING ERRCODE = 'P0040';
        END IF;

        v_id_token_hash := encode(sha256(trim(p_identity_proof_token)::bytea), 'hex');

        SELECT * INTO v_id_proof
        FROM public.identity_verification_proofs
        WHERE token_hash = v_id_token_hash
        FOR UPDATE;

        IF v_id_proof.id IS NULL THEN
            RAISE EXCEPTION 'Invalid identity verification proof token' USING ERRCODE = 'P0050';
        END IF;

        IF v_id_proof.used_at IS NOT NULL THEN
            RAISE EXCEPTION 'Identity verification proof has already been used' USING ERRCODE = 'P0051';
        END IF;

        IF v_now >= v_id_proof.expires_at THEN
            RAISE EXCEPTION 'Identity verification proof has expired' USING ERRCODE = 'P0052';
        END IF;

        IF v_id_proof.employee_user_id != v_user_id THEN
            RAISE EXCEPTION 'Identity verification proof belongs to another employee' USING ERRCODE = 'P0053';
        END IF;

        IF v_id_proof.station_id != v_proof.station_id THEN
            RAISE EXCEPTION 'Identity verification proof belongs to another station' USING ERRCODE = 'P0054';
        END IF;

        IF v_id_proof.presence_proof_id != v_proof.id THEN
            RAISE EXCEPTION 'Identity verification proof is not bound to this presence challenge' USING ERRCODE = 'P0055';
        END IF;

        IF v_id_proof.action != 'CHECK_IN' THEN
            RAISE EXCEPTION 'Identity verification proof action mismatch' USING ERRCODE = 'P0056';
        END IF;

        -- Re-verify employee identity profile is still active (unless override)
        IF NOT v_id_proof.is_override THEN
            SELECT * INTO v_profile
            FROM public.employee_identity_profiles
            WHERE employee_user_id = v_user_id
            FOR UPDATE;

            IF v_profile.id IS NULL OR v_profile.status != 'ACTIVE' THEN
                RAISE EXCEPTION 'Employee identity profile is revoked or inactive' USING ERRCODE = 'P0047';
            END IF;
        END IF;

        -- Mark identity proof as used
        UPDATE public.identity_verification_proofs
        SET used_at = v_now
        WHERE id = v_id_proof.id;

        v_id_proof_id := v_id_proof.id;
        v_has_valid_id_proof := true;
        IF v_id_proof.is_override THEN
            v_ver_method := 'MANUAL_ADMIN';
        ELSE
            v_ver_method := 'QR_PLUS_IDENTITY';
        END IF;
    ELSE
        -- If identity proof was optionally provided, validate and bridge
        IF p_identity_proof_token IS NOT NULL AND trim(p_identity_proof_token) != '' THEN
            v_id_token_hash := encode(sha256(trim(p_identity_proof_token)::bytea), 'hex');
            SELECT * INTO v_id_proof
            FROM public.identity_verification_proofs
            WHERE token_hash = v_id_token_hash AND used_at IS NULL AND expires_at > v_now 
              AND employee_user_id = v_user_id AND presence_proof_id = v_proof.id
            FOR UPDATE;

            IF v_id_proof.id IS NOT NULL THEN
                UPDATE public.identity_verification_proofs SET used_at = v_now WHERE id = v_id_proof.id;
                v_id_proof_id := v_id_proof.id;
                v_has_valid_id_proof := true;
                IF v_id_proof.is_override THEN
                    v_ver_method := 'MANUAL_ADMIN';
                ELSE
                    v_ver_method := 'QR_PLUS_IDENTITY';
                END IF;
            END IF;
        END IF;
    END IF;

    -- Presence Proof Expiry & Bounded Bridge Check
    IF v_has_valid_id_proof THEN
        IF v_proof.created_at < v_now - INTERVAL '180 seconds' THEN
            RAISE EXCEPTION 'Presence challenge has exceeded maximum bridge lifetime' USING ERRCODE = 'P0027';
        END IF;
    ELSE
        IF v_now >= v_proof.expires_at THEN
            RAISE EXCEPTION 'Presence proof has expired' USING ERRCODE = 'P0027';
        END IF;
    END IF;

    -- Validate kiosk device
    SELECT * INTO v_kiosk FROM public.kiosk_devices WHERE id = v_proof.kiosk_device_id;
    IF v_kiosk.id IS NULL OR NOT v_kiosk.is_active THEN
        RAISE EXCEPTION 'Kiosk device is inactive or deactivated' USING ERRCODE = 'P0018';
    END IF;

    -- Validate membership
    SELECT * INTO v_membership FROM public.station_memberships WHERE id = v_proof.station_membership_id;
    IF v_membership.id IS NULL OR v_membership.status != 'ACTIVE' THEN
        RAISE EXCEPTION 'Employee membership is not active' USING ERRCODE = 'P0022';
    END IF;

    -- Concurrency: Verify no global open session
    SELECT * INTO v_open_rec
    FROM public.attendance_records
    WHERE employee_user_id = v_user_id AND check_out_time IS NULL
    FOR UPDATE;

    IF v_open_rec.id IS NOT NULL THEN
        RAISE EXCEPTION 'Employee already has an open attendance session' USING ERRCODE = 'P0023';
    END IF;

    -- Resolve published shift assignment
    SELECT wss.id AS shift_id, wss.work_schedule_id, sa.id AS assignment_id,
           ws.version AS schedule_version, wss.shift_name_snapshot,
           wss.starts_at, wss.ends_at, wss.operational_date
    INTO v_shift
    FROM public.shift_assignments sa
    JOIN public.work_schedule_shifts wss ON sa.work_schedule_shift_id = wss.id
    JOIN public.work_schedules ws ON wss.work_schedule_id = ws.id
    WHERE sa.user_id = v_user_id
      AND wss.station_id = v_proof.station_id
      AND ws.status = 'PUBLISHED'
      AND (v_now >= (wss.starts_at - (v_station.check_in_early_minutes * INTERVAL '1 minute')))
      AND (v_now < wss.ends_at)
    ORDER BY abs(extract(epoch from (v_now - wss.starts_at))) ASC, wss.starts_at ASC, wss.id ASC
    LIMIT 1;

    IF v_shift.shift_id IS NULL THEN
        RAISE EXCEPTION 'No published shift assignment found for check-in window' USING ERRCODE = 'P0024';
    END IF;

    -- Calculate Lateness with grace policy
    v_diff_minutes := floor(extract(epoch from (v_now - v_shift.starts_at)) / 60.0)::INTEGER;
    IF v_diff_minutes > v_station.late_grace_minutes THEN
        v_late_minutes := v_diff_minutes;
    ELSE
        v_late_minutes := 0;
    END IF;

    v_new_att_id := gen_random_uuid();

    -- Insert attendance record
    INSERT INTO public.attendance_records (
        id, station_id, employee_user_id, station_membership_id,
        work_schedule_id, work_schedule_shift_id, shift_assignment_id,
        schedule_version_at_check_in, shift_name_snapshot,
        scheduled_start_at_snapshot, scheduled_end_at_snapshot,
        check_in_kiosk_device_id, check_in_time, late_minutes, status,
        verification_method, identity_verification_proof_id,
        created_at, updated_at
    ) VALUES (
        v_new_att_id, v_proof.station_id, v_user_id, v_membership.id,
        v_shift.work_schedule_id, v_shift.shift_id, v_shift.assignment_id,
        v_shift.schedule_version, v_shift.shift_name_snapshot,
        v_shift.starts_at, v_shift.ends_at,
        v_proof.kiosk_device_id, v_now, v_late_minutes, 'OPEN',
        v_ver_method, v_id_proof_id,
        v_now, v_now
    );

    -- Mark presence proof as consumed
    UPDATE public.attendance_presence_proofs
    SET used_at = v_now
    WHERE id = v_proof.id;

    RETURN jsonb_build_object(
        'success', true,
        'attendance_id', v_new_att_id,
        'station_id', v_proof.station_id,
        'employee_user_id', v_user_id,
        'check_in_time', v_now,
        'shift_name', v_shift.shift_name_snapshot,
        'status', 'OPEN',
        'late_minutes', v_late_minutes,
        'verification_method', v_ver_method
    );
END;
$$;

-- 13. Hardened check_out_with_presence_proof with Authoritative Bounded Bridge & Policy Enforcement (2 Arguments, No Defaults)
CREATE OR REPLACE FUNCTION public.check_out_with_presence_proof(
    p_presence_proof_token TEXT,
    p_identity_proof_token TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_token_hash TEXT;
    v_proof RECORD;
    v_station RECORD;
    v_kiosk RECORD;
    v_att RECORD;
    v_id_proof RECORD;
    v_id_token_hash TEXT;
    v_profile RECORD;
    v_now TIMESTAMPTZ;
    v_worked_minutes INTEGER;
    v_has_valid_id_proof BOOLEAN := false;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_now := now();
    v_token_hash := encode(sha256(p_presence_proof_token::bytea), 'hex');

    -- Lock presence proof row
    SELECT * INTO v_proof
    FROM public.attendance_presence_proofs
    WHERE token_hash = v_token_hash
    FOR UPDATE;

    IF v_proof.id IS NULL THEN
        RAISE EXCEPTION 'Invalid presence proof token' USING ERRCODE = 'P0025';
    END IF;

    IF v_proof.used_at IS NOT NULL THEN
        RAISE EXCEPTION 'Presence proof has already been used' USING ERRCODE = 'P0026';
    END IF;

    IF v_proof.employee_user_id != v_user_id THEN
        RAISE EXCEPTION 'Presence proof belongs to another employee' USING ERRCODE = 'P0028';
    END IF;

    IF v_proof.action != 'CHECK_OUT' THEN
        RAISE EXCEPTION 'Presence proof action mismatch' USING ERRCODE = 'P0029';
    END IF;

    -- Fetch station configuration
    SELECT * INTO v_station FROM public.stations WHERE id = v_proof.station_id;
    IF v_station.id IS NULL OR NOT v_station.is_active THEN
        RAISE EXCEPTION 'Station is inactive or deactivated' USING ERRCODE = 'P0017';
    END IF;

    -- Identity Verification Policy Enforcement
    IF v_station.identity_verification_mode = 'CHECK_IN_AND_CHECK_OUT' THEN
        IF p_identity_proof_token IS NULL OR trim(p_identity_proof_token) = '' THEN
            RAISE EXCEPTION 'Identity verification is required for check-out at this station'
                USING ERRCODE = 'P0040';
        END IF;

        v_id_token_hash := encode(sha256(trim(p_identity_proof_token)::bytea), 'hex');

        SELECT * INTO v_id_proof
        FROM public.identity_verification_proofs
        WHERE token_hash = v_id_token_hash
        FOR UPDATE;

        IF v_id_proof.id IS NULL THEN
            RAISE EXCEPTION 'Invalid identity verification proof token' USING ERRCODE = 'P0050';
        END IF;

        IF v_id_proof.used_at IS NOT NULL THEN
            RAISE EXCEPTION 'Identity verification proof has already been used' USING ERRCODE = 'P0051';
        END IF;

        IF v_now >= v_id_proof.expires_at THEN
            RAISE EXCEPTION 'Identity verification proof has expired' USING ERRCODE = 'P0052';
        END IF;

        IF v_id_proof.employee_user_id != v_user_id THEN
            RAISE EXCEPTION 'Identity verification proof belongs to another employee' USING ERRCODE = 'P0053';
        END IF;

        IF v_id_proof.station_id != v_proof.station_id THEN
            RAISE EXCEPTION 'Identity verification proof belongs to another station' USING ERRCODE = 'P0054';
        END IF;

        IF v_id_proof.presence_proof_id != v_proof.id THEN
            RAISE EXCEPTION 'Identity verification proof is not bound to this presence challenge' USING ERRCODE = 'P0055';
        END IF;

        IF v_id_proof.action != 'CHECK_OUT' THEN
            RAISE EXCEPTION 'Identity verification proof action mismatch' USING ERRCODE = 'P0056';
        END IF;

        -- Re-verify employee identity profile is still active (unless override)
        IF NOT v_id_proof.is_override THEN
            SELECT * INTO v_profile
            FROM public.employee_identity_profiles
            WHERE employee_user_id = v_user_id
            FOR UPDATE;

            IF v_profile.id IS NULL OR v_profile.status != 'ACTIVE' THEN
                RAISE EXCEPTION 'Employee identity profile is revoked or inactive' USING ERRCODE = 'P0047';
            END IF;
        END IF;

        -- Mark identity proof as used
        UPDATE public.identity_verification_proofs
        SET used_at = v_now
        WHERE id = v_id_proof.id;

        v_has_valid_id_proof := true;
    ELSE
        -- If identity proof was optionally provided, validate and bridge
        IF p_identity_proof_token IS NOT NULL AND trim(p_identity_proof_token) != '' THEN
            v_id_token_hash := encode(sha256(trim(p_identity_proof_token)::bytea), 'hex');
            SELECT * INTO v_id_proof
            FROM public.identity_verification_proofs
            WHERE token_hash = v_id_token_hash AND used_at IS NULL AND expires_at > v_now 
              AND employee_user_id = v_user_id AND presence_proof_id = v_proof.id
            FOR UPDATE;

            IF v_id_proof.id IS NOT NULL THEN
                UPDATE public.identity_verification_proofs SET used_at = v_now WHERE id = v_id_proof.id;
                v_has_valid_id_proof := true;
            END IF;
        END IF;
    END IF;

    -- Presence Proof Expiry & Bounded Bridge Check
    IF v_has_valid_id_proof THEN
        IF v_proof.created_at < v_now - INTERVAL '180 seconds' THEN
            RAISE EXCEPTION 'Presence challenge has exceeded maximum bridge lifetime' USING ERRCODE = 'P0027';
        END IF;
    ELSE
        IF v_now >= v_proof.expires_at THEN
            RAISE EXCEPTION 'Presence proof has expired' USING ERRCODE = 'P0027';
        END IF;
    END IF;

    -- Validate kiosk device
    SELECT * INTO v_kiosk FROM public.kiosk_devices WHERE id = v_proof.kiosk_device_id;
    IF v_kiosk.id IS NULL OR NOT v_kiosk.is_active THEN
        RAISE EXCEPTION 'Kiosk device is inactive or deactivated' USING ERRCODE = 'P0018';
    END IF;

    -- Find open attendance record
    SELECT * INTO v_att
    FROM public.attendance_records
    WHERE employee_user_id = v_user_id AND check_out_time IS NULL
    FOR UPDATE;

    IF v_att.id IS NULL THEN
        RAISE EXCEPTION 'No open attendance record found for employee' USING ERRCODE = 'P0030';
    END IF;

    -- Invariant: Must check out at the same station where checked in
    IF v_att.station_id != v_proof.station_id THEN
        RAISE EXCEPTION 'Cannot check out at Station % while checked in at Station %', v_proof.station_id, v_att.station_id
            USING ERRCODE = 'P0031';
    END IF;

    -- Compute real UTC elapsed minutes
    v_worked_minutes := floor(extract(epoch from (v_now - v_att.check_in_time)) / 60.0)::INTEGER;
    IF v_worked_minutes < 0 THEN
        v_worked_minutes := 0;
    END IF;

    -- Complete attendance record
    UPDATE public.attendance_records
    SET check_out_time = v_now,
        worked_minutes = v_worked_minutes,
        status = 'COMPLETED',
        check_out_kiosk_device_id = v_proof.kiosk_device_id,
        updated_at = v_now
    WHERE id = v_att.id;

    -- Mark presence proof as consumed
    UPDATE public.attendance_presence_proofs
    SET used_at = v_now
    WHERE id = v_proof.id;

    RETURN jsonb_build_object(
        'success', true,
        'attendance_id', v_att.id,
        'station_id', v_att.station_id,
        'employee_user_id', v_user_id,
        'check_in_time', v_att.check_in_time,
        'check_out_time', v_now,
        'worked_minutes', v_worked_minutes,
        'status', 'COMPLETED'
    );
END;
$$;

-- 14. 1-Argument Backward Compatibility Overloads (Explicit Forwarding)
CREATE OR REPLACE FUNCTION public.check_in_with_presence_proof(
    p_presence_proof_token TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN public.check_in_with_presence_proof(p_presence_proof_token, NULL::TEXT);
END;
$$;

CREATE OR REPLACE FUNCTION public.check_out_with_presence_proof(
    p_presence_proof_token TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN public.check_out_with_presence_proof(p_presence_proof_token, NULL::TEXT);
END;
$$;

-- 15. Execution Grants Hardening
REVOKE ALL ON FUNCTION public.start_identity_enrollment(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_identity_enrollment(TEXT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.complete_identity_enrollment(UUID, TEXT, BOOLEAN, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_identity_enrollment(UUID, TEXT, BOOLEAN, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.revoke_identity_profile(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.revoke_identity_profile(UUID, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.update_station_identity_policy(UUID, public.identity_verification_mode) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_station_identity_policy(UUID, public.identity_verification_mode) TO authenticated;

REVOKE ALL ON FUNCTION public.start_identity_verification(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_identity_verification(TEXT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.complete_identity_verification(UUID, BOOLEAN, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_identity_verification(UUID, BOOLEAN, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.create_identity_admin_override(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_identity_admin_override(TEXT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.get_my_identity_profile() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_identity_profile() TO authenticated;

REVOKE ALL ON FUNCTION public.get_station_team_identity_status(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_station_team_identity_status(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.check_in_with_presence_proof(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_in_with_presence_proof(TEXT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.check_out_with_presence_proof(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_out_with_presence_proof(TEXT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.check_in_with_presence_proof(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_in_with_presence_proof(TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.check_out_with_presence_proof(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_out_with_presence_proof(TEXT) TO authenticated;
