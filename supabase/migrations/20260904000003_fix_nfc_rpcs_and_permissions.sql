-- Migration: 20260904000003_fix_nfc_rpcs_and_permissions.sql
-- Description: Fix has_station_permission enum checks, station_shift_manager_permissions lookup, and audit_logs table insertions across all NFC RPCs

-- 1. Correct has_station_permission
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

    -- Platform Admin Superuser Bypass
    IF public.is_platform_admin(p_user_id) THEN
        RETURN TRUE;
    END IF;

    SELECT role, status INTO v_role, v_status
    FROM public.station_memberships
    WHERE station_id = p_station_id 
      AND user_id = p_user_id;

    IF NOT FOUND OR v_status IS NULL OR UPPER(v_status::text) <> 'ACTIVE' THEN
        RETURN FALSE;
    END IF;

    -- Station Admin has all station-scoped capabilities
    IF UPPER(v_role::text) = 'ADMIN' THEN
        RETURN TRUE;
    END IF;

    -- Employees have strictly self-service permissions
    IF UPPER(v_role::text) = 'EMPLOYEE' THEN
        RETURN p_permission IN (
            'availability.submit',
            'attendance.clock_in_out',
            'attendance.read_own',
            'attendance.read',
            'shift_templates.read',
            'availability.period.read',
            'schedule.read',
            'reports.self.read'
        );
    END IF;

    -- Shift Manager Capabilities
    IF UPPER(v_role::text) = 'SHIFT_MANAGER' THEN
        SELECT is_enabled INTO v_override_enabled
        FROM public.station_shift_manager_permissions
        WHERE station_id = p_station_id 
          AND permission = p_permission;

        IF FOUND AND v_override_enabled IS NOT NULL THEN
            RETURN v_override_enabled;
        END IF;

        -- Default Shift Manager Matrix
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
            WHEN 'attendance.clock_in_out' THEN RETURN TRUE;
            WHEN 'attendance.read_own' THEN RETURN TRUE;
            WHEN 'shift_templates.manage' THEN RETURN FALSE;
            WHEN 'availability.period.create' THEN RETURN FALSE;
            WHEN 'availability.period.open' THEN RETURN FALSE;
            WHEN 'availability.period.close' THEN RETURN FALSE;
            WHEN 'schedule.manage' THEN RETURN FALSE;
            WHEN 'schedule.publish' THEN RETURN FALSE;
            WHEN 'attendance.correct' THEN RETURN FALSE;
            WHEN 'attendance.nfc.manage' THEN RETURN FALSE;
            ELSE RETURN FALSE;
        END CASE;
    END IF;

    RETURN FALSE;
END;
$$;

-- 2. Provision Station NFC Tag
CREATE OR REPLACE FUNCTION public.provision_station_nfc_tag(
    p_station_id UUID,
    p_name TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_tag_id UUID;
    v_tag_identifier TEXT;
    v_station_code TEXT;
    v_raw_secret TEXT;
    v_secret_hash TEXT;
    v_clean_name TEXT;
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

    -- Generate unique public tag identifier and high-entropy secret
    v_tag_identifier := 'ytag_' || encode(gen_random_bytes(12), 'hex');
    v_raw_secret := encode(gen_random_bytes(32), 'hex');
    v_secret_hash := encode(digest(v_raw_secret, 'sha256'), 'hex');

    INSERT INTO public.station_nfc_tags (
        station_id,
        name,
        tag_identifier,
        secret_hash,
        is_active,
        created_by
    ) VALUES (
        p_station_id,
        v_clean_name,
        v_tag_identifier,
        v_secret_hash,
        true,
        v_caller_id
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
        'raw_secret', v_raw_secret,
        'payload', jsonb_build_object(
            'v', 1,
            'station_code', v_station_code,
            'tag_id', v_tag_identifier,
            'secret', v_raw_secret
        )::text
    );
END;
$$;

-- 3. Revoke Station NFC Tag
CREATE OR REPLACE FUNCTION public.revoke_station_nfc_tag(
    p_tag_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_station_id UUID;
    v_tag_name TEXT;
    v_identifier TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    SELECT station_id, name, tag_identifier INTO v_station_id, v_tag_name, v_identifier
    FROM public.station_nfc_tags
    WHERE id = p_tag_id;

    IF v_station_id IS NULL THEN
        RAISE EXCEPTION 'NFC Tag not found' USING ERRCODE = 'P0016';
    END IF;

    IF NOT (public.has_station_permission(v_station_id, v_caller_id, 'attendance.nfc.manage')
            OR public.is_station_admin(v_station_id, v_caller_id)
            OR public.is_platform_admin(v_caller_id)) THEN
        RAISE EXCEPTION 'Access denied: caller cannot revoke NFC tags for this station' USING ERRCODE = '42501';
    END IF;

    UPDATE public.station_nfc_tags
    SET is_active = false,
        revoked_by = v_caller_id,
        revoked_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_tag_id;

    -- Record Audit Log
    INSERT INTO public.audit_logs (
        station_id,
        actor_id,
        action,
        target_type,
        target_id,
        metadata
    ) VALUES (
        v_station_id,
        v_caller_id,
        'NFC_TAG_REVOKED',
        'station_nfc_tags',
        p_tag_id::text,
        jsonb_build_object(
            'name', v_tag_name,
            'tag_identifier', v_identifier,
            'revoked_at', now()
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'id', p_tag_id,
        'is_active', false
    );
END;
$$;

-- 4. Reactivate Station NFC Tag
CREATE OR REPLACE FUNCTION public.reactivate_station_nfc_tag(
    p_tag_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_station_id UUID;
    v_tag_name TEXT;
    v_identifier TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    SELECT station_id, name, tag_identifier INTO v_station_id, v_tag_name, v_identifier
    FROM public.station_nfc_tags
    WHERE id = p_tag_id;

    IF v_station_id IS NULL THEN
        RAISE EXCEPTION 'NFC Tag not found' USING ERRCODE = 'P0016';
    END IF;

    IF NOT (public.has_station_permission(v_station_id, v_caller_id, 'attendance.nfc.manage')
            OR public.is_station_admin(v_station_id, v_caller_id)
            OR public.is_platform_admin(v_caller_id)) THEN
        RAISE EXCEPTION 'Access denied: caller cannot reactivate NFC tags' USING ERRCODE = '42501';
    END IF;

    UPDATE public.station_nfc_tags
    SET is_active = true,
        revoked_by = NULL,
        revoked_at = NULL,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_tag_id;

    INSERT INTO public.audit_logs (
        station_id,
        actor_id,
        action,
        target_type,
        target_id,
        metadata
    ) VALUES (
        v_station_id,
        v_caller_id,
        'NFC_TAG_REACTIVATED',
        'station_nfc_tags',
        p_tag_id::text,
        jsonb_build_object(
            'name', v_tag_name,
            'tag_identifier', v_identifier
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'id', p_tag_id,
        'is_active', true
    );
END;
$$;

-- 5. Replace Station NFC Tag (Atomic Revoke + Provision New)
CREATE OR REPLACE FUNCTION public.replace_station_nfc_tag(
    p_old_tag_id UUID,
    p_new_name TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_station_id UUID;
    v_res JSONB;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    SELECT station_id INTO v_station_id
    FROM public.station_nfc_tags
    WHERE id = p_old_tag_id;

    IF v_station_id IS NULL THEN
        RAISE EXCEPTION 'Old NFC Tag not found' USING ERRCODE = 'P0016';
    END IF;

    -- Revoke old tag
    PERFORM public.revoke_station_nfc_tag(p_old_tag_id);

    -- Provision new tag
    v_res := public.provision_station_nfc_tag(v_station_id, p_new_name);

    INSERT INTO public.audit_logs (
        station_id,
        actor_id,
        action,
        target_type,
        target_id,
        metadata
    ) VALUES (
        v_station_id,
        v_caller_id,
        'NFC_TAG_REPLACED',
        'station_nfc_tags',
        (v_res->>'id'),
        jsonb_build_object(
            'replaced_old_tag_id', p_old_tag_id,
            'new_tag_id', v_res->>'id'
        )
    );

    RETURN v_res;
END;
$$;

-- 6. NFC Check-In RPC
CREATE OR REPLACE FUNCTION public.nfc_check_in(
    p_tag_identifier TEXT,
    p_tag_secret TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_now TIMESTAMPTZ;
    v_tag RECORD;
    v_station RECORD;
    v_membership RECORD;
    v_open_rec_id UUID;
    v_secret_hash TEXT;
    v_shift RECORD;
    v_late_minutes INT := 0;
    v_rec_id UUID;
    v_station_name TEXT;
    v_shift_name TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    v_now := timezone('utc'::text, now());

    IF p_tag_identifier IS NULL OR trim(p_tag_identifier) = '' OR 
       p_tag_secret IS NULL OR trim(p_tag_secret) = '' THEN
        RAISE EXCEPTION 'Invalid NFC tag credentials' USING ERRCODE = 'P0020';
    END IF;

    v_secret_hash := encode(digest(trim(p_tag_secret), 'sha256'), 'hex');

    -- 1. Validate NFC Station Tag
    SELECT * INTO v_tag
    FROM public.station_nfc_tags
    WHERE tag_identifier = trim(p_tag_identifier)
      AND secret_hash = v_secret_hash;

    IF v_tag.id IS NULL THEN
        RAISE EXCEPTION 'Unrecognized or invalid station NFC tag' USING ERRCODE = 'P0020';
    END IF;

    IF NOT v_tag.is_active OR v_tag.revoked_at IS NOT NULL THEN
        RAISE EXCEPTION 'Station NFC tag has been revoked or deactivated' USING ERRCODE = 'P0021';
    END IF;

    -- 2. Validate Station
    SELECT * INTO v_station
    FROM public.stations
    WHERE id = v_tag.station_id;

    IF v_station.id IS NULL OR NOT v_station.is_active THEN
        RAISE EXCEPTION 'Station is inactive or not found' USING ERRCODE = 'P0022';
    END IF;
    v_station_name := v_station.name;

    -- 3. Validate Employee Station Membership
    SELECT * INTO v_membership
    FROM public.station_memberships
    WHERE station_id = v_tag.station_id 
      AND user_id = v_caller_id 
      AND UPPER(status::text) = 'ACTIVE';

    IF v_membership.id IS NULL THEN
        RAISE EXCEPTION 'Employee is not an active member of this station' USING ERRCODE = 'P0023';
    END IF;

    -- 4. Invariant: Prevent Concurrent / Duplicate Open Attendance Sessions
    SELECT id INTO v_open_rec_id
    FROM public.attendance_records
    WHERE employee_user_id = v_caller_id 
      AND check_out_time IS NULL;

    IF v_open_rec_id IS NOT NULL THEN
        RAISE EXCEPTION 'Active attendance session already exists. You must check out first.' USING ERRCODE = 'P0024';
    END IF;

    -- 5. Match Schedule & Shift (Scheduling Integration)
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
      AND v_now >= (wss.starts_at - (v_station.check_in_early_minutes || ' minutes')::INTERVAL)
      AND v_now <= wss.ends_at
    ORDER BY wss.starts_at ASC
    LIMIT 1;

    IF v_shift.work_schedule_shift_id IS NOT NULL THEN
        v_shift_name := v_shift.shift_name;
        -- Late Minutes Calculation
        IF v_now > (v_shift.starts_at + (v_station.late_grace_minutes || ' minutes')::INTERVAL) THEN
            v_late_minutes := GREATEST(1, ROUND(EXTRACT(EPOCH FROM (v_now - v_shift.starts_at)) / 60));
        END IF;
    END IF;

    -- 6. Insert Server-Authoritative Attendance Record
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
        check_in_nfc_tag_id
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
        v_tag.id
    ) RETURNING id INTO v_rec_id;

    -- 7. Update Tag Telemetry
    UPDATE public.station_nfc_tags
    SET last_scanned_at = v_now,
        updated_at = v_now
    WHERE id = v_tag.id;

    -- 8. Record Audit Log
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
            'tag_identifier', v_tag.tag_identifier,
            'late_minutes', v_late_minutes,
            'shift_name', v_shift_name
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'attendance_id', v_rec_id,
        'station_id', v_tag.station_id,
        'station_name', v_station_name,
        'shift_name', v_shift_name,
        'check_in_time', v_now,
        'late_minutes', v_late_minutes,
        'status', 'OPEN'
    );
END;
$$;

-- 7. NFC Check-Out RPC
CREATE OR REPLACE FUNCTION public.nfc_check_out(
    p_tag_identifier TEXT,
    p_tag_secret TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_now TIMESTAMPTZ;
    v_tag RECORD;
    v_secret_hash TEXT;
    v_record RECORD;
    v_worked_minutes INT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    v_now := timezone('utc'::text, now());

    IF p_tag_identifier IS NULL OR trim(p_tag_identifier) = '' OR 
       p_tag_secret IS NULL OR trim(p_tag_secret) = '' THEN
        RAISE EXCEPTION 'Invalid NFC tag credentials' USING ERRCODE = 'P0020';
    END IF;

    v_secret_hash := encode(digest(trim(p_tag_secret), 'sha256'), 'hex');

    -- 1. Validate NFC Station Tag
    SELECT * INTO v_tag
    FROM public.station_nfc_tags
    WHERE tag_identifier = trim(p_tag_identifier)
      AND secret_hash = v_secret_hash;

    IF v_tag.id IS NULL THEN
        RAISE EXCEPTION 'Unrecognized or invalid station NFC tag' USING ERRCODE = 'P0020';
    END IF;

    IF NOT v_tag.is_active OR v_tag.revoked_at IS NOT NULL THEN
        RAISE EXCEPTION 'Station NFC tag has been revoked or deactivated' USING ERRCODE = 'P0021';
    END IF;

    -- 2. Find Open Attendance Record with Mutex Lock
    SELECT * INTO v_record
    FROM public.attendance_records
    WHERE employee_user_id = v_caller_id 
      AND check_out_time IS NULL
    FOR UPDATE;

    IF v_record.id IS NULL THEN
        RAISE EXCEPTION 'No active attendance session found to check out' USING ERRCODE = 'P0025';
    END IF;

    -- 3. Strict Multi-Station Isolation Check
    IF v_record.station_id != v_tag.station_id THEN
        RAISE EXCEPTION 'Station mismatch: this NFC tag belongs to another station' USING ERRCODE = 'P0026';
    END IF;

    -- 4. Calculate Authoritative Worked Duration
    v_worked_minutes := GREATEST(1, ROUND(EXTRACT(EPOCH FROM (v_now - v_record.check_in_time)) / 60));

    -- 5. Complete Attendance Record
    UPDATE public.attendance_records
    SET check_out_time = v_now,
        worked_minutes = v_worked_minutes,
        check_out_nfc_tag_id = v_tag.id,
        status = 'COMPLETED',
        updated_at = v_now
    WHERE id = v_record.id;

    -- 6. Update Tag Telemetry
    UPDATE public.station_nfc_tags
    SET last_scanned_at = v_now,
        updated_at = v_now
    WHERE id = v_tag.id;

    -- 7. Record Audit Log
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
        v_record.id::text,
        jsonb_build_object(
            'check_out_time', v_now,
            'worked_minutes', v_worked_minutes,
            'nfc_tag_id', v_tag.id,
            'tag_identifier', v_tag.tag_identifier
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'attendance_id', v_record.id,
        'station_id', v_tag.station_id,
        'check_in_time', v_record.check_in_time,
        'check_out_time', v_now,
        'worked_minutes', v_worked_minutes,
        'status', 'COMPLETED'
    );
END;
$$;
