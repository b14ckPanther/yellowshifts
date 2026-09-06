-- Migration: 20260906000003_fix_get_manager_live_attendance.sql
-- Description: Fix column references (sa.membership_id, wss.shift_name_snapshot) in get_manager_live_attendance and nfc_check_in

-- 1. Fix get_manager_live_attendance RPC
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
        public.has_station_permission(p_station_id, v_caller_id, 'attendance.read') OR
        public.has_station_permission(p_station_id, v_caller_id, 'schedule.read') OR
        public.is_platform_admin(v_caller_id)
    ) THEN
        RAISE EXCEPTION 'Access denied: cannot view live attendance' USING ERRCODE = '42501';
    END IF;

    v_now := timezone('utc'::text, now());

    -- Build Roster for Target Date
    WITH daily_schedule AS (
        SELECT 
            wss.id AS shift_id,
            wss.shift_name_snapshot AS shift_name,
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
        JOIN public.station_memberships sm ON sa.membership_id = sm.id
        JOIN public.profiles p ON sm.user_id = p.id
        LEFT JOIN public.attendance_records ar ON (
            ar.work_schedule_shift_id = wss.id AND ar.employee_user_id = sm.user_id
        )
        WHERE wss.station_id = p_station_id
          AND ws.status = 'PUBLISHED'
          AND (wss.operational_date = p_target_date OR DATE(timezone('Asia/Jerusalem', wss.starts_at)) = p_target_date)
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

REVOKE ALL ON FUNCTION public.get_manager_live_attendance(UUID, DATE) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_manager_live_attendance(UUID, DATE) TO authenticated, service_role;


-- 2. Fix nfc_check_in RPC column references
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
      AND status = 'ACTIVE';

    IF v_membership.id IS NULL THEN
        RAISE EXCEPTION 'You are not an active member of this station' USING ERRCODE = 'P0023';
    END IF;

    -- 4. Check Open Attendance Invariant
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
      AND v_now >= (wss.starts_at - (COALESCE(v_station.check_in_early_minutes, 15) || ' minutes')::INTERVAL)
      AND v_now <= wss.ends_at
    ORDER BY wss.starts_at ASC
    LIMIT 1;

    IF v_shift.work_schedule_shift_id IS NOT NULL THEN
        v_shift_name := v_shift.shift_name;
        -- Late Minutes Calculation
        IF v_now > (v_shift.starts_at + (COALESCE(v_station.late_grace_minutes, 5) || ' minutes')::INTERVAL) THEN
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
        actor_user_id,
        event_type,
        target_entity,
        target_id,
        details
    ) VALUES (
        v_tag.station_id,
        v_caller_id,
        'NFC_ATTENDANCE_CHECK_IN',
        'attendance_records',
        v_rec_id,
        jsonb_build_object(
            'tag_id', v_tag.id,
            'tag_identifier', v_tag.tag_identifier,
            'check_in_time', v_now,
            'late_minutes', v_late_minutes,
            'matched_shift', v_shift.work_schedule_shift_id IS NOT NULL
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

REVOKE ALL ON FUNCTION public.nfc_check_in(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nfc_check_in(TEXT, TEXT) TO authenticated, service_role;
