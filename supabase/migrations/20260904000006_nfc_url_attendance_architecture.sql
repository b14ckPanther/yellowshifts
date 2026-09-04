-- Migration: 20260904000006_nfc_url_attendance_architecture.sql
-- Description: Server-authoritative NFC URL deep-link attendance architecture for Flutter Web & iOS Safari

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Index on secret_hash for O(1) token lookup
CREATE UNIQUE INDEX IF NOT EXISTS idx_station_nfc_tags_secret_hash ON public.station_nfc_tags(secret_hash);

-- 2. Provision Station NFC Tag with High-Entropy URL Token
CREATE OR REPLACE FUNCTION public.provision_station_nfc_tag(
    p_station_id UUID,
    p_name TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_tag_id UUID;
    v_tag_identifier TEXT;
    v_station_code TEXT;
    v_raw_token TEXT;
    v_token_hash TEXT;
    v_clean_name TEXT;
    v_now TIMESTAMPTZ := now();
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    IF NOT (public.has_station_permission(p_station_id, v_caller_id, 'attendance.nfc.manage') 
            OR public.is_station_admin(p_station_id, v_caller_id) 
            OR public.is_platform_admin(v_caller_id)) THEN
        RAISE EXCEPTION 'Access denied: caller cannot manage NFC tags for this station' USING ERRCODE = '42501';
    END IF;

    v_clean_name := trim(p_name);
    IF v_clean_name IS NULL OR length(v_clean_name) < 2 THEN
        RAISE EXCEPTION 'Tag name must be at least 2 characters long' USING ERRCODE = 'P0002';
    END IF;

    SELECT code INTO v_station_code FROM public.stations WHERE id = p_station_id AND is_active = true;
    IF v_station_code IS NULL THEN
        RAISE EXCEPTION 'Station not found or inactive' USING ERRCODE = 'P0003';
    END IF;

    -- Generate high-entropy 64-char hex token (256-bit cryptographic entropy)
    v_raw_token := encode(sha256((gen_random_uuid()::text || clock_timestamp()::text || random()::text || p_station_id::text)::bytea), 'hex');
    v_token_hash := encode(sha256(v_raw_token::bytea), 'hex');
    v_tag_identifier := 'ytag_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 20);

    INSERT INTO public.station_nfc_tags (
        station_id,
        name,
        tag_identifier,
        secret_hash,
        is_active,
        created_by,
        created_at,
        updated_at
    ) VALUES (
        p_station_id,
        v_clean_name,
        v_tag_identifier,
        v_token_hash,
        true,
        v_caller_id,
        v_now,
        v_now
    ) RETURNING id INTO v_tag_id;

    -- Record in Immutable Audit Logs
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
        'NFC_TAG_PROVISIONED',
        'station_nfc_tags',
        v_tag_id::text,
        jsonb_build_object(
            'name', v_clean_name,
            'tag_identifier', v_tag_identifier
        )
    );

    RETURN jsonb_build_object(
        'id', v_tag_id,
        'station_id', p_station_id,
        'station_code', v_station_code,
        'name', v_clean_name,
        'tag_identifier', v_tag_identifier,
        'token', v_raw_token,
        'raw_secret', v_raw_token,
        'nfc_url', '/nfc/t/' || v_raw_token,
        'is_active', true,
        'created_at', v_now
    );
END;
$$;

-- 3. Regenerate Station NFC Tag Token RPC
CREATE OR REPLACE FUNCTION public.regenerate_station_nfc_tag(
    p_tag_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_tag RECORD;
    v_station_code TEXT;
    v_raw_token TEXT;
    v_token_hash TEXT;
    v_now TIMESTAMPTZ := now();
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_tag FROM public.station_nfc_tags WHERE id = p_tag_id;
    IF v_tag.id IS NULL THEN
        RAISE EXCEPTION 'Station NFC tag not found' USING ERRCODE = 'P0003';
    END IF;

    IF NOT (public.has_station_permission(v_tag.station_id, v_caller_id, 'attendance.nfc.manage') 
            OR public.is_station_admin(v_tag.station_id, v_caller_id) 
            OR public.is_platform_admin(v_caller_id)) THEN
        RAISE EXCEPTION 'Access denied: caller cannot manage NFC tags for this station' USING ERRCODE = '42501';
    END IF;

    SELECT code INTO v_station_code FROM public.stations WHERE id = v_tag.station_id;

    -- Generate fresh 64-char hex token
    v_raw_token := encode(sha256((gen_random_uuid()::text || clock_timestamp()::text || random()::text || v_tag.station_id::text)::bytea), 'hex');
    v_token_hash := encode(sha256(v_raw_token::bytea), 'hex');

    UPDATE public.station_nfc_tags
    SET secret_hash = v_token_hash,
        is_active = true,
        revoked_at = NULL,
        revoked_by = NULL,
        updated_at = v_now
    WHERE id = p_tag_id;

    INSERT INTO public.audit_logs (
        station_id,
        actor_id,
        action,
        target_type,
        target_id,
        metadata
    ) VALUES (
        v_tag.station_id,
        v_caller_id,
        'NFC_TAG_REGENERATED',
        'station_nfc_tags',
        p_tag_id::text,
        jsonb_build_object(
            'name', v_tag.name,
            'tag_identifier', v_tag.tag_identifier
        )
    );

    RETURN jsonb_build_object(
        'id', p_tag_id,
        'station_id', v_tag.station_id,
        'station_code', v_station_code,
        'name', v_tag.name,
        'tag_identifier', v_tag.tag_identifier,
        'token', v_raw_token,
        'raw_secret', v_raw_token,
        'nfc_url', '/nfc/t/' || v_raw_token,
        'is_active', true,
        'updated_at', v_now
    );
END;
$$;

-- 4. Server-Authoritative Unified NFC Attendance Punch RPC
CREATE OR REPLACE FUNCTION public.nfc_process_attendance(
    p_token TEXT,
    p_client_location JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_now TIMESTAMPTZ := now();
    v_token TEXT;
    v_token_hash TEXT;
    v_tag RECORD;
    v_station RECORD;
    v_membership RECORD;
    v_open_record RECORD;
    v_recent_record RECORD;
    v_worked_minutes INT;
    v_rec_id UUID;
    v_shift RECORD;
    v_shift_name TEXT := NULL;
    v_late_minutes INT := 0;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    v_token := trim(p_token);
    IF v_token IS NULL OR length(v_token) < 16 THEN
        RAISE EXCEPTION 'Invalid or missing NFC station token' USING ERRCODE = 'P0020';
    END IF;

    v_token_hash := encode(sha256(v_token::bytea), 'hex');

    -- 1. Validate Station NFC Tag from Token Hash
    SELECT * INTO v_tag
    FROM public.station_nfc_tags
    WHERE secret_hash = v_token_hash;

    IF v_tag.id IS NULL THEN
        RAISE EXCEPTION 'Unrecognized or invalid station NFC tag' USING ERRCODE = 'P0020';
    END IF;

    IF NOT v_tag.is_active OR v_tag.revoked_at IS NOT NULL THEN
        RAISE EXCEPTION 'Station NFC tag is deactivated or revoked' USING ERRCODE = 'P0021';
    END IF;

    -- 2. Validate Station
    SELECT * INTO v_station
    FROM public.stations
    WHERE id = v_tag.station_id;

    IF v_station.id IS NULL OR NOT v_station.is_active THEN
        RAISE EXCEPTION 'Station is inactive or not found' USING ERRCODE = 'P0022';
    END IF;

    -- 3. Strict Tenant Isolation: Validate Employee Station Membership
    SELECT * INTO v_membership
    FROM public.station_memberships
    WHERE station_id = v_tag.station_id
      AND user_id = v_caller_id
      AND UPPER(status::text) = 'ACTIVE';

    IF v_membership.id IS NULL THEN
        RAISE EXCEPTION 'Access denied: caller is not an active member of this station' USING ERRCODE = 'P0023';
    END IF;

    -- 4. Check Open Attendance Session for this Employee
    SELECT * INTO v_open_record
    FROM public.attendance_records
    WHERE employee_user_id = v_caller_id
      AND check_out_time IS NULL
    ORDER BY check_in_time DESC
    LIMIT 1;

    -- =========================================================================
    -- CASE A: Open session exists -> Perform CHECK-OUT
    -- =========================================================================
    IF v_open_record.id IS NOT NULL THEN
        -- Station isolation check: cannot clock out of Station A using Station B tag
        IF v_open_record.station_id != v_tag.station_id THEN
            RAISE EXCEPTION 'Station mismatch: active attendance session belongs to another station' USING ERRCODE = 'P0026';
        END IF;

        -- Prevent accidental immediate double punch (cooldown 10s)
        IF (v_now - v_open_record.check_in_time) < INTERVAL '10 seconds' THEN
            RAISE EXCEPTION 'Duplicate punch detected: please wait a moment before clocking out' USING ERRCODE = 'P0028';
        END IF;

        v_worked_minutes := GREATEST(1, ROUND(EXTRACT(EPOCH FROM (v_now - v_open_record.check_in_time)) / 60));

        UPDATE public.attendance_records
        SET check_out_time = v_now,
            worked_minutes = v_worked_minutes,
            check_out_nfc_tag_id = v_tag.id,
            status = 'COMPLETED',
            updated_at = v_now
        WHERE id = v_open_record.id;

        -- Update Tag Scan Telemetry
        UPDATE public.station_nfc_tags
        SET last_scanned_at = v_now,
            updated_at = v_now
        WHERE id = v_tag.id;

        -- Audit Log
        INSERT INTO public.audit_logs (
            station_id,
            actor_id,
            action,
            target_type,
            target_id,
            metadata
        ) VALUES (
            v_tag.station_id,
            v_caller_id,
            'ATTENDANCE_CHECK_OUT_NFC',
            'attendance_records',
            v_open_record.id::text,
            jsonb_build_object(
                'check_in_time', v_open_record.check_in_time,
                'check_out_time', v_now,
                'worked_minutes', v_worked_minutes,
                'nfc_tag_id', v_tag.id,
                'tag_name', v_tag.name,
                'tag_identifier', v_tag.tag_identifier,
                'client_location', p_client_location
            )
        );

        RETURN jsonb_build_object(
            'success', true,
            'action', 'CHECK_OUT',
            'attendance_id', v_open_record.id,
            'station_id', v_tag.station_id,
            'station_name', v_station.name,
            'station_code', v_station.code,
            'tag_name', v_tag.name,
            'check_in_time', v_open_record.check_in_time,
            'check_out_time', v_now,
            'worked_minutes', v_worked_minutes,
            'status', 'COMPLETED',
            'server_timestamp', v_now
        );

    -- =========================================================================
    -- CASE B: No open session -> Perform CHECK-IN
    -- =========================================================================
    ELSE
        -- Prevent accidental immediate double punch after check-out (cooldown 10s)
        SELECT * INTO v_recent_record
        FROM public.attendance_records
        WHERE employee_user_id = v_caller_id
          AND check_out_time IS NOT NULL
          AND check_out_time >= (v_now - INTERVAL '10 seconds')
        ORDER BY check_out_time DESC
        LIMIT 1;

        IF v_recent_record.id IS NOT NULL THEN
            RAISE EXCEPTION 'Duplicate punch detected: please wait a moment before clocking in again' USING ERRCODE = 'P0028';
        END IF;

        -- Match published schedule shift if available
        SELECT 
            wss.id AS work_schedule_shift_id,
            wss.work_schedule_id,
            sa.id AS shift_assignment_id,
            ws.version AS schedule_version,
            wss.shift_name_snapshot AS shift_name,
            wss.starts_at,
            wss.ends_at
        INTO v_shift
        FROM public.shift_assignments sa
        JOIN public.work_schedule_shifts wss ON sa.work_schedule_shift_id = wss.id
        JOIN public.work_schedules ws ON wss.work_schedule_id = ws.id
        WHERE sa.membership_id = v_membership.id
          AND sa.station_id = v_tag.station_id
          AND ws.status = 'PUBLISHED'
          AND v_now >= (wss.starts_at - (COALESCE(v_station.check_in_early_minutes, 15) || ' minutes')::INTERVAL)
          AND v_now <= wss.ends_at
        ORDER BY wss.starts_at ASC
        LIMIT 1;

        IF v_shift.work_schedule_shift_id IS NOT NULL THEN
            v_shift_name := v_shift.shift_name;
            IF v_now > (v_shift.starts_at + (COALESCE(v_station.late_grace_minutes, 5) || ' minutes')::INTERVAL) THEN
                v_late_minutes := GREATEST(1, ROUND(EXTRACT(EPOCH FROM (v_now - v_shift.starts_at)) / 60));
            END IF;
        END IF;

        INSERT INTO public.attendance_records (
            station_id,
            employee_user_id,
            station_membership_id,
            work_schedule_id,
            work_schedule_shift_id,
            shift_assignment_id,
            schedule_version_at_check_in,
            shift_name_snapshot,
            scheduled_start_at_snapshot,
            scheduled_end_at_snapshot,
            check_in_time,
            check_out_time,
            late_minutes,
            status,
            verification_method,
            check_in_nfc_tag_id,
            created_at,
            updated_at
        ) VALUES (
            v_tag.station_id,
            v_caller_id,
            v_membership.id,
            v_shift.work_schedule_id,
            v_shift.work_schedule_shift_id,
            v_shift.shift_assignment_id,
            v_shift.schedule_version,
            v_shift_name,
            v_shift.starts_at,
            v_shift.ends_at,
            v_now,
            NULL,
            v_late_minutes,
            'OPEN',
            'NFC',
            v_tag.id,
            v_now,
            v_now
        ) RETURNING id INTO v_rec_id;

        -- Update Tag Scan Telemetry
        UPDATE public.station_nfc_tags
        SET last_scanned_at = v_now,
            updated_at = v_now
        WHERE id = v_tag.id;

        -- Audit Log
        INSERT INTO public.audit_logs (
            station_id,
            actor_id,
            action,
            target_type,
            target_id,
            metadata
        ) VALUES (
            v_tag.station_id,
            v_caller_id,
            'ATTENDANCE_CHECK_IN_NFC',
            'attendance_records',
            v_rec_id::text,
            jsonb_build_object(
                'check_in_time', v_now,
                'nfc_tag_id', v_tag.id,
                'tag_name', v_tag.name,
                'tag_identifier', v_tag.tag_identifier,
                'work_schedule_shift_id', v_shift.work_schedule_shift_id,
                'shift_name', v_shift_name,
                'late_minutes', v_late_minutes,
                'client_location', p_client_location
            )
        );

        RETURN jsonb_build_object(
            'success', true,
            'action', 'CHECK_IN',
            'attendance_id', v_rec_id,
            'station_id', v_tag.station_id,
            'station_name', v_station.name,
            'station_code', v_station.code,
            'tag_name', v_tag.name,
            'shift_name', v_shift_name,
            'check_in_time', v_now,
            'status', 'OPEN',
            'server_timestamp', v_now,
            'late_minutes', v_late_minutes
        );
    END IF;
END;
$$;

-- 5. Platform Schema Version RPC
CREATE OR REPLACE FUNCTION public.get_platform_schema_version()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN jsonb_build_object(
        'schema_version', '20260904000006',
        'platform_version', '1.0.6',
        'min_compatible_client_version', '1.0.0',
        'migration_cutoff', '20260904000006',
        'status', 'HEALTHY',
        'nfc_only_attendance', true,
        'server_timestamp', now()
    );
END;
$$;

-- 6. Permissions and Execution Grants
REVOKE ALL ON FUNCTION public.provision_station_nfc_tag(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.provision_station_nfc_tag(UUID, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.regenerate_station_nfc_tag(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.regenerate_station_nfc_tag(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.nfc_process_attendance(TEXT, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.nfc_process_attendance(TEXT, JSONB) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_platform_schema_version() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_platform_schema_version() TO anon, authenticated, service_role;
