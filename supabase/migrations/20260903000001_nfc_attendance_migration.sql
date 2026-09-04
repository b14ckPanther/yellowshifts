-- ======================================================================
-- YELLOWSHIFTS — NFC-ONLY ATTENDANCE VERIFICATION MIGRATION
-- Migration: 20260903000001_nfc_attendance_migration.sql
-- ======================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Create Station NFC Tags Table
CREATE TABLE IF NOT EXISTS public.station_nfc_tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    tag_identifier TEXT NOT NULL UNIQUE,
    secret_hash TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_by UUID NOT NULL REFERENCES public.profiles(id),
    revoked_by UUID NULL REFERENCES public.profiles(id),
    revoked_at TIMESTAMPTZ NULL,
    last_scanned_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_station_nfc_tags_station ON public.station_nfc_tags(station_id, is_active);
CREATE INDEX IF NOT EXISTS idx_station_nfc_tags_identifier ON public.station_nfc_tags(tag_identifier);

-- 2. Modify Attendance Records Table for NFC
ALTER TABLE public.attendance_records 
    ADD COLUMN IF NOT EXISTS check_in_nfc_tag_id UUID NULL REFERENCES public.station_nfc_tags(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS check_out_nfc_tag_id UUID NULL REFERENCES public.station_nfc_tags(id) ON DELETE SET NULL;

-- Drop obsolete kiosk foreign keys and columns if they exist
ALTER TABLE public.attendance_records 
    DROP COLUMN IF EXISTS check_in_kiosk_device_id CASCADE,
    DROP COLUMN IF EXISTS check_out_kiosk_device_id CASCADE;

-- Update or replace attendance_verification_method enum if present
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'attendance_verification_method') THEN
        ALTER TYPE public.attendance_verification_method ADD VALUE IF NOT EXISTS 'NFC';
    END IF;
END $$;

-- 3. Drop Obsolete Attendance & Identity Tables (Clean Architecture)
DROP TABLE IF EXISTS public.attendance_presence_proofs CASCADE;
DROP TABLE IF EXISTS public.kiosk_qr_challenges CASCADE;
DROP TABLE IF EXISTS public.kiosk_devices CASCADE;
DROP TABLE IF EXISTS public.identity_proof_tokens CASCADE;
DROP TABLE IF EXISTS public.identity_verification_attempts CASCADE;
DROP TABLE IF EXISTS public.identity_enrollment_sessions CASCADE;
DROP TABLE IF EXISTS public.employee_identity_profiles CASCADE;

-- 4. Drop Obsolete Station Policy Columns
ALTER TABLE public.stations 
    DROP COLUMN IF EXISTS identity_verification_mode CASCADE;

-- 5. Drop Obsolete Enums
DROP TYPE IF EXISTS public.identity_verification_mode CASCADE;
DROP TYPE IF EXISTS public.identity_profile_status CASCADE;
DROP TYPE IF EXISTS public.enrollment_session_status CASCADE;
DROP TYPE IF EXISTS public.identity_verification_result CASCADE;

-- 6. Update Permission System for NFC Management
CREATE OR REPLACE FUNCTION public.has_station_permission(
    p_station_id UUID,
    p_user_id UUID,
    p_permission TEXT
)
RETURNS BOOLEAN AS $$
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

    IF v_status IS NULL OR v_status != 'active' THEN
        RETURN FALSE;
    END IF;

    -- Station Admin has all station-scoped capabilities
    IF v_role = 'admin' THEN
        RETURN TRUE;
    END IF;

    -- Employees have strictly self-service permissions
    IF v_role = 'employee' THEN
        RETURN p_permission IN (
            'availability.submit',
            'attendance.clock_in_out',
            'attendance.read_own'
        );
    END IF;

    -- Shift Manager Capabilities
    IF v_role = 'shift_manager' THEN
        SELECT is_enabled INTO v_override_enabled
        FROM public.shift_manager_permissions_override
        WHERE station_id = p_station_id 
          AND permission_key = p_permission;

        IF v_override_enabled IS NOT NULL THEN
            RETURN v_override_enabled;
        END IF;

        -- Default Shift Manager Matrix
        CASE p_permission
            WHEN 'shift_templates.manage' THEN RETURN FALSE;
            WHEN 'availability.period.create' THEN RETURN FALSE;
            WHEN 'availability.period.open' THEN RETURN FALSE;
            WHEN 'availability.period.close' THEN RETURN FALSE;
            WHEN 'availability.team.read' THEN RETURN TRUE;
            WHEN 'schedule.manage' THEN RETURN FALSE;
            WHEN 'schedule.publish' THEN RETURN FALSE;
            WHEN 'attendance.correct' THEN RETURN FALSE;
            WHEN 'attendance.nfc.manage' THEN RETURN FALSE;
            WHEN 'reports.team.read' THEN RETURN TRUE;
            WHEN 'reports.station.read' THEN RETURN TRUE;
            WHEN 'availability.submit' THEN RETURN TRUE;
            WHEN 'attendance.clock_in_out' THEN RETURN TRUE;
            WHEN 'attendance.read_own' THEN RETURN TRUE;
            ELSE RETURN FALSE;
        END CASE;
    END IF;

    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public;

-- 7. Enable RLS and Configure Policies for station_nfc_tags
ALTER TABLE public.station_nfc_tags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_station_nfc_tags_select ON public.station_nfc_tags;
CREATE POLICY p_station_nfc_tags_select ON public.station_nfc_tags
    FOR SELECT TO authenticated
    USING (
        public.has_station_permission(station_id, auth.uid(), 'attendance.nfc.manage') OR
        public.is_platform_admin(auth.uid())
    );

DROP POLICY IF EXISTS p_station_nfc_tags_insert ON public.station_nfc_tags;
CREATE POLICY p_station_nfc_tags_insert ON public.station_nfc_tags
    FOR INSERT TO authenticated
    WITH CHECK (
        public.has_station_permission(station_id, auth.uid(), 'attendance.nfc.manage') OR
        public.is_platform_admin(auth.uid())
    );

DROP POLICY IF EXISTS p_station_nfc_tags_update ON public.station_nfc_tags;
CREATE POLICY p_station_nfc_tags_update ON public.station_nfc_tags
    FOR UPDATE TO authenticated
    USING (
        public.has_station_permission(station_id, auth.uid(), 'attendance.nfc.manage') OR
        public.is_platform_admin(auth.uid())
    )
    WITH CHECK (
        public.has_station_permission(station_id, auth.uid(), 'attendance.nfc.manage') OR
        public.is_platform_admin(auth.uid())
    );

DROP POLICY IF EXISTS p_station_nfc_tags_delete ON public.station_nfc_tags;
CREATE POLICY p_station_nfc_tags_delete ON public.station_nfc_tags
    FOR DELETE TO authenticated
    USING (
        public.has_station_permission(station_id, auth.uid(), 'attendance.nfc.manage') OR
        public.is_platform_admin(auth.uid())
    );

-- 8. NFC Station Tag Provisioning & Management RPCs

-- 8.1 Provision Station NFC Tag
CREATE OR REPLACE FUNCTION public.provision_station_nfc_tag(
    p_station_id UUID,
    p_name TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_station_code TEXT;
    v_tag_id UUID;
    v_tag_identifier TEXT;
    v_raw_secret TEXT;
    v_secret_hash TEXT;
    v_clean_name TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    IF NOT public.has_station_permission(p_station_id, v_caller_id, 'attendance.nfc.manage') THEN
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

    -- Record in Station Audit Logs
    INSERT INTO public.station_audit_logs (
        station_id,
        actor_id,
        action,
        resource_type,
        resource_id,
        after_state
    ) VALUES (
        p_station_id,
        v_caller_id,
        'NFC_TAG_PROVISIONED',
        'station_nfc_tags',
        v_tag_id,
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 8.2 Revoke Station NFC Tag
CREATE OR REPLACE FUNCTION public.revoke_station_nfc_tag(
    p_tag_id UUID
)
RETURNS JSONB AS $$
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

    IF NOT public.has_station_permission(v_station_id, v_caller_id, 'attendance.nfc.manage') THEN
        RAISE EXCEPTION 'Access denied: caller cannot revoke NFC tags for this station' USING ERRCODE = '42501';
    END IF;

    UPDATE public.station_nfc_tags
    SET is_active = false,
        revoked_by = v_caller_id,
        revoked_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_tag_id;

    -- Record Audit Log
    INSERT INTO public.station_audit_logs (
        station_id,
        actor_id,
        action,
        resource_type,
        resource_id,
        after_state
    ) VALUES (
        v_station_id,
        v_caller_id,
        'NFC_TAG_REVOKED',
        'station_nfc_tags',
        p_tag_id,
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 8.3 Reactivate Station NFC Tag
CREATE OR REPLACE FUNCTION public.reactivate_station_nfc_tag(
    p_tag_id UUID
)
RETURNS JSONB AS $$
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

    IF NOT public.has_station_permission(v_station_id, v_caller_id, 'attendance.nfc.manage') THEN
        RAISE EXCEPTION 'Access denied: caller cannot reactivate NFC tags' USING ERRCODE = '42501';
    END IF;

    UPDATE public.station_nfc_tags
    SET is_active = true,
        revoked_by = NULL,
        revoked_at = NULL,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_tag_id;

    INSERT INTO public.station_audit_logs (
        station_id,
        actor_id,
        action,
        resource_type,
        resource_id,
        after_state
    ) VALUES (
        v_station_id,
        v_caller_id,
        'NFC_TAG_REACTIVATED',
        'station_nfc_tags',
        p_tag_id,
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 8.4 Replace Station NFC Tag (Atomic Revoke + Provision New)
CREATE OR REPLACE FUNCTION public.replace_station_nfc_tag(
    p_old_tag_id UUID,
    p_new_name TEXT
)
RETURNS JSONB AS $$
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

    INSERT INTO public.station_audit_logs (
        station_id,
        actor_id,
        action,
        resource_type,
        resource_id,
        after_state
    ) VALUES (
        v_station_id,
        v_caller_id,
        'NFC_TAG_REPLACED',
        'station_nfc_tags',
        (v_res->>'id')::UUID,
        jsonb_build_object(
            'replaced_old_tag_id', p_old_tag_id,
            'new_tag_id', v_res->>'id'
        )
    );

    RETURN v_res;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 8.5 List Station NFC Tags (Safe Metadata, No Secrets)
CREATE OR REPLACE FUNCTION public.list_station_nfc_tags(
    p_station_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_result JSONB;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    IF NOT public.has_station_permission(p_station_id, v_caller_id, 'attendance.nfc.manage') THEN
        RAISE EXCEPTION 'Access denied: caller cannot view NFC tags for this station' USING ERRCODE = '42501';
    END IF;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', t.id,
            'station_id', t.station_id,
            'name', t.name,
            'tag_identifier', t.tag_identifier,
            'is_active', t.is_active,
            'created_at', t.created_at,
            'revoked_at', t.revoked_at,
            'last_scanned_at', t.last_scanned_at,
            'created_by_name', NULLIF(TRIM(CONCAT(cp.first_name, ' ', cp.last_name)), ''),
            'revoked_by_name', NULLIF(TRIM(CONCAT(rp.first_name, ' ', rp.last_name)), '')
        ) ORDER BY t.created_at DESC
    ), '[]'::jsonb) INTO v_result
    FROM public.station_nfc_tags t
    LEFT JOIN public.profiles cp ON t.created_by = cp.id
    LEFT JOIN public.profiles rp ON t.revoked_by = rp.id
    WHERE t.station_id = p_station_id;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public;

-- 9. Server-Authoritative NFC Attendance RPCs

-- 9.1 Employee Check-In via Physical Station NFC Tag
CREATE OR REPLACE FUNCTION public.nfc_check_in(
    p_tag_identifier TEXT,
    p_tag_secret TEXT
)
RETURNS JSONB AS $$
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
      AND status = 'active';

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
        wss.shift_name,
        wss.starts_at,
        wss.ends_at
    INTO v_shift
    FROM public.shift_assignments sa
    JOIN public.work_schedule_shifts wss ON sa.work_schedule_shift_id = wss.id
    JOIN public.work_schedules ws ON wss.work_schedule_id = ws.id
    WHERE sa.station_membership_id = v_membership.id
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
    INSERT INTO public.station_audit_logs (
        station_id,
        actor_id,
        action,
        resource_type,
        resource_id,
        after_state
    ) VALUES (
        v_tag.station_id,
        v_caller_id,
        'ATTENDANCE_CHECK_IN_NFC',
        'attendance_records',
        v_rec_id,
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
        'check_in_time', v_now,
        'shift_name', v_shift_name,
        'late_minutes', v_late_minutes,
        'status', 'OPEN'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 9.2 Employee Check-Out via Physical Station NFC Tag
CREATE OR REPLACE FUNCTION public.nfc_check_out(
    p_tag_identifier TEXT,
    p_tag_secret TEXT
)
RETURNS JSONB AS $$
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
    INSERT INTO public.station_audit_logs (
        station_id,
        actor_id,
        action,
        resource_type,
        resource_id,
        after_state
    ) VALUES (
        v_tag.station_id,
        v_caller_id,
        'ATTENDANCE_CHECK_OUT_NFC',
        'attendance_records',
        v_record.id,
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 10. Update Manager Live Attendance Roster
CREATE OR REPLACE FUNCTION public.get_manager_live_attendance(
    p_station_id UUID,
    p_target_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_now TIMESTAMPTZ;
    v_roster JSONB;
    v_kpis JSONB;
    v_working_count INT := 0;
    v_upcoming_count INT := 0;
    v_late_count INT := 0;
    v_completed_count INT := 0;
    v_not_checked_in_count INT := 0;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    IF NOT (
        public.has_station_permission(p_station_id, v_caller_id, 'reports.station.read') OR
        public.has_station_permission(p_station_id, v_caller_id, 'reports.team.read') OR
        public.is_platform_admin(v_caller_id)
    ) THEN
        RAISE EXCEPTION 'Access denied: cannot view live attendance' USING ERRCODE = '42501';
    END IF;

    v_now := timezone('utc'::text, now());

    -- Build Roster for Target Date
    WITH daily_schedule AS (
        SELECT 
            wss.id AS shift_id,
            wss.shift_name,
            wss.starts_at,
            wss.ends_at,
            sa.id AS assignment_id,
            sm.user_id,
            p.first_name,
            p.last_name,
            p.employee_code,
            ar.id AS attendance_id,
            ar.check_in_time,
            ar.check_out_time,
            ar.worked_minutes,
            ar.late_minutes,
            CASE
                WHEN ar.id IS NOT NULL AND ar.check_out_time IS NULL THEN 'WORKING'
                WHEN ar.id IS NOT NULL AND ar.check_out_time IS NOT NULL THEN 'COMPLETED'
                WHEN ar.id IS NULL AND v_now < wss.starts_at THEN 'UPCOMING'
                WHEN ar.id IS NULL AND v_now >= wss.starts_at THEN 'NOT_CHECKED_IN'
                ELSE 'UNKNOWN'
            END AS operational_status,
            CASE
                WHEN ar.id IS NOT NULL AND ar.check_out_time IS NULL THEN
                    GREATEST(0, ROUND(EXTRACT(EPOCH FROM (v_now - ar.check_in_time)) / 60))::INT
                ELSE NULL
            END AS elapsed_minutes
        FROM public.work_schedule_shifts wss
        JOIN public.work_schedules ws ON wss.work_schedule_id = ws.id
        JOIN public.shift_assignments sa ON sa.work_schedule_shift_id = wss.id
        JOIN public.station_memberships sm ON sa.station_membership_id = sm.id
        JOIN public.profiles p ON sm.user_id = p.id
        LEFT JOIN public.attendance_records ar ON ar.work_schedule_shift_id = wss.id AND ar.employee_user_id = sm.user_id
        WHERE wss.station_id = p_station_id
          AND ws.status = 'PUBLISHED'
          AND DATE(timezone('Asia/Jerusalem', wss.starts_at)) = p_target_date
    )
    SELECT 
        COALESCE(jsonb_agg(
            jsonb_build_object(
                'shift_id', shift_id,
                'shift_name', shift_name,
                'starts_at', starts_at,
                'ends_at', ends_at,
                'assignment_id', assignment_id,
                'user_id', user_id,
                'first_name', first_name,
                'last_name', last_name,
                'employee_code', employee_code,
                'attendance_id', attendance_id,
                'check_in_time', check_in_time,
                'check_out_time', check_out_time,
                'worked_minutes', worked_minutes,
                'late_minutes', late_minutes,
                'operational_status', operational_status,
                'elapsed_minutes', elapsed_minutes
            ) ORDER BY starts_at ASC, first_name ASC
        ), '[]'::jsonb),
        COUNT(*) FILTER (WHERE operational_status = 'WORKING'),
        COUNT(*) FILTER (WHERE operational_status = 'UPCOMING'),
        COUNT(*) FILTER (WHERE late_minutes > 0 AND operational_status IN ('WORKING', 'COMPLETED')),
        COUNT(*) FILTER (WHERE operational_status = 'COMPLETED'),
        COUNT(*) FILTER (WHERE operational_status = 'NOT_CHECKED_IN')
    INTO 
        v_roster,
        v_working_count,
        v_upcoming_count,
        v_late_count,
        v_completed_count,
        v_not_checked_in_count
    FROM daily_schedule;

    v_kpis := jsonb_build_object(
        'currently_working', v_working_count,
        'scheduled_upcoming', v_upcoming_count,
        'late_checked_in', v_late_count,
        'completed', v_completed_count,
        'not_checked_in', v_not_checked_in_count
    );

    RETURN jsonb_build_object(
        'success', true,
        'station_id', p_station_id,
        'target_date', p_target_date::TEXT,
        'kpis', v_kpis,
        'roster', v_roster
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public;

-- 11. Cleanup Ephemeral Attendance Data (Updated for NFC)
CREATE OR REPLACE FUNCTION public.cleanup_ephemeral_attendance_data()
RETURNS JSONB AS $$
DECLARE
    v_count INT := 0;
BEGIN
    -- No temporary QR tokens to clean up; attendance is clean and permanent.
    RETURN jsonb_build_object(
        'success', true,
        'expired_records_cleaned', 0,
        'cleaned_at', now()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 12. Update Station Health and Platform Overview for NFC Tags
CREATE OR REPLACE FUNCTION public.get_station_system_health(
    p_station_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_nfc_total INT := 0;
    v_nfc_active INT := 0;
    v_stale_open INT := 0;
    v_exports_total INT := 0;
    v_exports_failed INT := 0;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    IF NOT (public.has_station_permission(p_station_id, v_caller_id, 'attendance.nfc.manage') OR public.is_platform_admin(v_caller_id)) THEN
        RAISE EXCEPTION 'Access denied' USING ERRCODE = '42501';
    END IF;

    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE is_active = true)
    INTO v_nfc_total, v_nfc_active
    FROM public.station_nfc_tags
    WHERE station_id = p_station_id;

    SELECT COUNT(*) INTO v_stale_open
    FROM public.attendance_records
    WHERE station_id = p_station_id 
      AND check_out_time IS NULL 
      AND check_in_time < (now() - INTERVAL '16 hours');

    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE status = 'FAILED')
    INTO v_exports_total, v_exports_failed
    FROM public.export_artifacts
    WHERE station_id = p_station_id 
      AND created_at >= (now() - INTERVAL '24 hours');

    RETURN jsonb_build_object(
        'station_id', p_station_id,
        'nfc_tags', jsonb_build_object(
            'total', v_nfc_total,
            'active', v_nfc_active
        ),
        'exports_24h', jsonb_build_object(
            'total', v_exports_total,
            'failed', v_exports_failed
        ),
        'anomalies', jsonb_build_object(
            'stale_open_sessions', v_stale_open
        ),
        'server_time', now()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public;

-- 13. Drop Obsolete Functions
DROP FUNCTION IF EXISTS public.provision_kiosk_device(UUID, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.rotate_kiosk_credentials(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.deactivate_kiosk_device(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.reactivate_kiosk_device(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.kiosk_authenticate_and_mint_qr(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.scan_attendance_qr(TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.check_in_with_presence_proof(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.check_in_with_presence_proof(TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.check_out_with_presence_proof(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.check_out_with_presence_proof(TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.start_identity_enrollment(TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.complete_identity_enrollment(UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.revoke_identity_profile() CASCADE;
DROP FUNCTION IF EXISTS public.start_identity_verification(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.complete_identity_verification(UUID, BOOLEAN, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.override_identity_verification(UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.get_team_identity_roster(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.update_station_identity_policy(UUID, TEXT) CASCADE;
