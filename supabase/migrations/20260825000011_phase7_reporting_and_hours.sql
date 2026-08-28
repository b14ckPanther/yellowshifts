-- ==============================================================================
-- YELLOWSHIFTS — PHASE 7: WORKED HOURS ANALYTICS, ATTENDANCE HISTORY, 
-- OPERATIONAL REPORTING & TIME RECORDS
-- Migration: 20260825000011_phase7_reporting_and_hours.sql
-- ==============================================================================

-- 1. Optimized Composite & Partial Indexes for Time Analytics & Reporting
CREATE INDEX IF NOT EXISTS idx_attendance_records_station_sched_start 
ON public.attendance_records(station_id, scheduled_start_at_snapshot);

CREATE INDEX IF NOT EXISTS idx_attendance_records_user_sched_start 
ON public.attendance_records(employee_user_id, scheduled_start_at_snapshot);

CREATE INDEX IF NOT EXISTS idx_attendance_records_station_checkin_opt 
ON public.attendance_records(station_id, check_in_time);

CREATE INDEX IF NOT EXISTS idx_attendance_records_user_checkin_opt 
ON public.attendance_records(employee_user_id, check_in_time);

CREATE INDEX IF NOT EXISTS idx_attendance_records_open_session_opt 
ON public.attendance_records(employee_user_id, check_in_time) 
WHERE check_out_time IS NULL;

CREATE INDEX IF NOT EXISTS idx_attendance_records_completed_opt 
ON public.attendance_records(station_id, employee_user_id, check_in_time) 
WHERE check_out_time IS NOT NULL AND worked_minutes IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_attendance_corrections_rec_created_opt 
ON public.attendance_corrections(attendance_record_id, created_at DESC);

-- 2. Extend Permission Matrix with Reporting Capabilities
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

    SELECT role, status INTO v_role, v_status
    FROM public.station_memberships
    WHERE station_id = p_station_id AND user_id = p_user_id;

    IF NOT FOUND OR v_status <> 'ACTIVE' THEN
        RETURN FALSE;
    END IF;

    -- Station Administrators have full authority across all operations
    IF v_role = 'ADMIN' THEN
        RETURN TRUE;
    END IF;

    -- Employees have self-service access only
    IF v_role = 'EMPLOYEE' THEN
        IF p_permission IN (
            'shift_templates.read', 'availability.period.read', 'availability.submit', 
            'schedule.read', 'attendance.read', 'reports.self.read'
        ) THEN
            RETURN TRUE;
        END IF;
        RETURN FALSE;
    END IF;

    -- Shift Managers: check capability overrides with safe operational defaults
    IF v_role = 'SHIFT_MANAGER' THEN
        SELECT is_enabled INTO v_override_enabled
        FROM public.station_shift_manager_permissions
        WHERE station_id = p_station_id AND permission = p_permission;

        IF FOUND THEN
            RETURN v_override_enabled;
        END IF;

        -- Safe default permissions for Shift Managers
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
            WHEN 'shift_templates.manage' THEN RETURN FALSE;
            WHEN 'availability.period.create' THEN RETURN FALSE;
            WHEN 'availability.period.open' THEN RETURN FALSE;
            WHEN 'availability.period.close' THEN RETURN FALSE;
            WHEN 'schedule.manage' THEN RETURN FALSE;
            WHEN 'schedule.publish' THEN RETURN FALSE;
            WHEN 'attendance.kiosk.manage' THEN RETURN FALSE;
            WHEN 'attendance.correct' THEN RETURN FALSE;
            ELSE RETURN FALSE;
        END CASE;
    END IF;

    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp STABLE;

-- 3. RPC: get_my_attendance_summary
-- Calculates employee personal summary across completed and open shifts
CREATE OR REPLACE FUNCTION public.get_my_attendance_summary(
    p_from DATE,
    p_to DATE,
    p_station_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_timezone TEXT := 'Asia/Jerusalem';
    v_range_start_utc TIMESTAMPTZ;
    v_range_end_utc TIMESTAMPTZ;
    v_total_worked_minutes INTEGER := 0;
    v_completed_shifts INTEGER := 0;
    v_late_shifts INTEGER := 0;
    v_total_late_minutes INTEGER := 0;
    v_corrected_records INTEGER := 0;
    v_open_session_count INTEGER := 0;
    v_stations_worked_count INTEGER := 0;
    v_first_shift_date DATE := NULL;
    v_last_shift_date DATE := NULL;
    v_active_open_session JSONB := NULL;
    v_open_rec RECORD;
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    IF p_from IS NULL OR p_to IS NULL THEN
        RAISE EXCEPTION 'Date range parameters are required' USING ERRCODE = '22000';
    END IF;

    IF p_from > p_to THEN
        RAISE EXCEPTION 'Start date cannot be after end date' USING ERRCODE = '22000';
    END IF;

    IF (p_to - p_from) > 366 THEN
        RAISE EXCEPTION 'Date range cannot exceed 366 days' USING ERRCODE = '22000';
    END IF;

    -- Resolve timezone context if station provided
    IF p_station_id IS NOT NULL THEN
        SELECT timezone INTO v_timezone FROM public.stations WHERE id = p_station_id;
        IF v_timezone IS NULL THEN v_timezone := 'Asia/Jerusalem'; END IF;
    END IF;

    v_range_start_utc := (p_from::TEXT || ' 00:00:00')::TIMESTAMP AT TIME ZONE v_timezone;
    v_range_end_utc := ((p_to + 1)::TEXT || ' 00:00:00')::TIMESTAMP AT TIME ZONE v_timezone;

    -- Aggregate completed attendance metrics
    SELECT
        COALESCE(SUM(ar.worked_minutes) FILTER (WHERE ar.check_out_time IS NOT NULL AND ar.worked_minutes >= 0), 0),
        COALESCE(COUNT(*) FILTER (WHERE ar.check_out_time IS NOT NULL AND ar.worked_minutes >= 0), 0),
        COALESCE(COUNT(*) FILTER (WHERE ar.check_out_time IS NOT NULL AND ar.late_minutes > 0), 0),
        COALESCE(SUM(ar.late_minutes) FILTER (WHERE ar.check_out_time IS NOT NULL AND ar.late_minutes > 0), 0),
        COALESCE(COUNT(DISTINCT ar.id) FILTER (WHERE ar.check_out_time IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.attendance_corrections ac WHERE ac.attendance_record_id = ar.id
        )), 0),
        COALESCE(COUNT(DISTINCT ar.station_id) FILTER (WHERE ar.check_out_time IS NOT NULL), 0),
        MIN((COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) AT TIME ZONE v_timezone)::DATE) FILTER (WHERE ar.check_out_time IS NOT NULL),
        MAX((COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) AT TIME ZONE v_timezone)::DATE) FILTER (WHERE ar.check_out_time IS NOT NULL)
    INTO
        v_total_worked_minutes,
        v_completed_shifts,
        v_late_shifts,
        v_total_late_minutes,
        v_corrected_records,
        v_stations_worked_count,
        v_first_shift_date,
        v_last_shift_date
    FROM public.attendance_records ar
    WHERE ar.employee_user_id = v_caller_id
      AND (p_station_id IS NULL OR ar.station_id = p_station_id)
      AND COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) >= v_range_start_utc
      AND COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) < v_range_end_utc;

    -- Check for open sessions in range
    SELECT COUNT(*) INTO v_open_session_count
    FROM public.attendance_records ar
    WHERE ar.employee_user_id = v_caller_id
      AND ar.check_out_time IS NULL
      AND (p_station_id IS NULL OR ar.station_id = p_station_id)
      AND ar.check_in_time >= v_range_start_utc
      AND ar.check_in_time < v_range_end_utc;

    -- Query active global open session (if any currently open)
    SELECT 
        ar.id,
        ar.station_id,
        st.name AS station_name,
        ar.check_in_time,
        ar.shift_name_snapshot,
        ar.scheduled_start_at_snapshot,
        ar.scheduled_end_at_snapshot,
        GREATEST(0, floor(extract(epoch from (now() - ar.check_in_time)) / 60.0)::INTEGER) AS elapsed_minutes
    INTO v_open_rec
    FROM public.attendance_records ar
    JOIN public.stations st ON st.id = ar.station_id
    WHERE ar.employee_user_id = v_caller_id
      AND ar.check_out_time IS NULL
    LIMIT 1;

    IF FOUND THEN
        v_active_open_session := jsonb_build_object(
            'id', v_open_rec.id,
            'station_id', v_open_rec.station_id,
            'station_name', v_open_rec.station_name,
            'check_in_time', v_open_rec.check_in_time,
            'shift_name_snapshot', v_open_rec.shift_name_snapshot,
            'scheduled_start_at_snapshot', v_open_rec.scheduled_start_at_snapshot,
            'scheduled_end_at_snapshot', v_open_rec.scheduled_end_at_snapshot,
            'elapsed_minutes', v_open_rec.elapsed_minutes,
            'needs_attention', (v_open_rec.elapsed_minutes >= 960) -- >16h operational flag
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'from_date', p_from,
        'to_date', p_to,
        'station_id', p_station_id,
        'total_worked_minutes', v_total_worked_minutes,
        'completed_shifts', v_completed_shifts,
        'late_shifts', v_late_shifts,
        'total_late_minutes', v_total_late_minutes,
        'corrected_records', v_corrected_records,
        'open_session_count', v_open_session_count,
        'stations_worked_count', v_stations_worked_count,
        'first_shift_date', v_first_shift_date,
        'last_shift_date', v_last_shift_date,
        'active_open_session', v_active_open_session
    );
END;
$$;

-- 4. RPC: get_my_attendance_history
-- Drop legacy signature from Phase 4 to avoid function resolution ambiguity
DROP FUNCTION IF EXISTS public.get_my_attendance_history(UUID, INTEGER, INTEGER);

-- Returns paginated personal attendance timeline
CREATE OR REPLACE FUNCTION public.get_my_attendance_history(
    p_from DATE,
    p_to DATE,
    p_station_id UUID DEFAULT NULL,
    p_status_filter TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 25,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_timezone TEXT := 'Asia/Jerusalem';
    v_range_start_utc TIMESTAMPTZ;
    v_range_end_utc TIMESTAMPTZ;
    v_limit INTEGER;
    v_offset INTEGER;
    v_total_count INTEGER := 0;
    v_items JSONB := '[]'::jsonb;
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    IF p_from IS NULL OR p_to IS NULL THEN
        RAISE EXCEPTION 'Date range parameters are required' USING ERRCODE = '22000';
    END IF;

    IF p_from > p_to THEN
        RAISE EXCEPTION 'Start date cannot be after end date' USING ERRCODE = '22000';
    END IF;

    IF (p_to - p_from) > 366 THEN
        RAISE EXCEPTION 'Date range cannot exceed 366 days' USING ERRCODE = '22000';
    END IF;

    v_limit := GREATEST(1, LEAST(COALESCE(p_limit, 25), 50));
    v_offset := GREATEST(0, COALESCE(p_offset, 0));

    IF p_station_id IS NOT NULL THEN
        SELECT timezone INTO v_timezone FROM public.stations WHERE id = p_station_id;
        IF v_timezone IS NULL THEN v_timezone := 'Asia/Jerusalem'; END IF;
    END IF;

    v_range_start_utc := (p_from::TEXT || ' 00:00:00')::TIMESTAMP AT TIME ZONE v_timezone;
    v_range_end_utc := ((p_to + 1)::TEXT || ' 00:00:00')::TIMESTAMP AT TIME ZONE v_timezone;

    -- Total count matching filters
    SELECT COUNT(*) INTO v_total_count
    FROM public.attendance_records ar
    WHERE ar.employee_user_id = v_caller_id
      AND (p_station_id IS NULL OR ar.station_id = p_station_id)
      AND COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) >= v_range_start_utc
      AND COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) < v_range_end_utc
      AND (
          p_status_filter IS NULL
          OR (p_status_filter = 'COMPLETED' AND ar.check_out_time IS NOT NULL)
          OR (p_status_filter = 'OPEN' AND ar.check_out_time IS NULL)
          OR (p_status_filter = 'LATE' AND ar.late_minutes > 0)
          OR (p_status_filter = 'CORRECTED' AND EXISTS (
              SELECT 1 FROM public.attendance_corrections ac WHERE ac.attendance_record_id = ar.id
          ))
      );

    -- Query items
    SELECT COALESCE(jsonb_agg(item), '[]'::jsonb) INTO v_items
    FROM (
        SELECT jsonb_build_object(
            'id', ar.id,
            'station_id', ar.station_id,
            'station_name', st.name,
            'station_code', st.code,
            'work_schedule_shift_id', ar.work_schedule_shift_id,
            'shift_name_snapshot', ar.shift_name_snapshot,
            'scheduled_start_at_snapshot', ar.scheduled_start_at_snapshot,
            'scheduled_end_at_snapshot', ar.scheduled_end_at_snapshot,
            'check_in_time', ar.check_in_time,
            'check_out_time', ar.check_out_time,
            'worked_minutes', ar.worked_minutes,
            'late_minutes', ar.late_minutes,
            'status', ar.status,
            'verification_method', ar.verification_method,
            'operational_date', (COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) AT TIME ZONE v_timezone)::DATE,
            'is_late', (ar.late_minutes > 0),
            'is_corrected', EXISTS (
                SELECT 1 FROM public.attendance_corrections ac WHERE ac.attendance_record_id = ar.id
            ),
            'correction_count', (
                SELECT COUNT(*) FROM public.attendance_corrections ac WHERE ac.attendance_record_id = ar.id
            ),
            'created_at', ar.created_at
        ) AS item
        FROM public.attendance_records ar
        JOIN public.stations st ON st.id = ar.station_id
        WHERE ar.employee_user_id = v_caller_id
          AND (p_station_id IS NULL OR ar.station_id = p_station_id)
          AND COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) >= v_range_start_utc
          AND COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) < v_range_end_utc
          AND (
              p_status_filter IS NULL
              OR (p_status_filter = 'COMPLETED' AND ar.check_out_time IS NOT NULL)
              OR (p_status_filter = 'OPEN' AND ar.check_out_time IS NULL)
              OR (p_status_filter = 'LATE' AND ar.late_minutes > 0)
              OR (p_status_filter = 'CORRECTED' AND EXISTS (
                  SELECT 1 FROM public.attendance_corrections ac WHERE ac.attendance_record_id = ar.id
              ))
          )
        ORDER BY COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) DESC, ar.id DESC
        LIMIT v_limit OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'success', true,
        'items', v_items,
        'total_count', v_total_count,
        'limit', v_limit,
        'offset', v_offset,
        'has_more', (v_offset + v_limit < v_total_count)
    );
END;
$$;

-- 5. RPC: get_station_attendance_summary
-- Station-level aggregated summary for managers and administrators
CREATE OR REPLACE FUNCTION public.get_station_attendance_summary(
    p_station_id UUID,
    p_from DATE,
    p_to DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_station RECORD;
    v_range_start_utc TIMESTAMPTZ;
    v_range_end_utc TIMESTAMPTZ;
    v_total_worked_minutes INTEGER := 0;
    v_completed_shifts INTEGER := 0;
    v_late_shifts INTEGER := 0;
    v_total_late_minutes INTEGER := 0;
    v_corrected_records INTEGER := 0;
    v_open_sessions INTEGER := 0;
    v_employees_with_attendance_count INTEGER := 0;
    v_active_employees_count INTEGER := 0;
    v_repeated_lateness_count INTEGER := 0;
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    IF p_station_id IS NULL OR p_from IS NULL OR p_to IS NULL THEN
        RAISE EXCEPTION 'Station and date range parameters are required' USING ERRCODE = '22000';
    END IF;

    IF p_from > p_to THEN
        RAISE EXCEPTION 'Start date cannot be after end date' USING ERRCODE = '22000';
    END IF;

    IF (p_to - p_from) > 366 THEN
        RAISE EXCEPTION 'Date range cannot exceed 366 days' USING ERRCODE = '22000';
    END IF;

    SELECT * INTO v_station FROM public.stations WHERE id = p_station_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Station not found' USING ERRCODE = 'P0002';
    END IF;

    -- Authorization check
    IF NOT public.has_station_permission(p_station_id, v_caller_id, 'reports.team.read') THEN
        RAISE EXCEPTION 'Access denied: caller lacks reporting authorization for this station' USING ERRCODE = '42501';
    END IF;

    v_range_start_utc := (p_from::TEXT || ' 00:00:00')::TIMESTAMP AT TIME ZONE v_station.timezone;
    v_range_end_utc := ((p_to + 1)::TEXT || ' 00:00:00')::TIMESTAMP AT TIME ZONE v_station.timezone;

    -- Station summary aggregate
    SELECT
        COALESCE(SUM(ar.worked_minutes) FILTER (WHERE ar.check_out_time IS NOT NULL AND ar.worked_minutes >= 0), 0),
        COALESCE(COUNT(*) FILTER (WHERE ar.check_out_time IS NOT NULL AND ar.worked_minutes >= 0), 0),
        COALESCE(COUNT(*) FILTER (WHERE ar.check_out_time IS NOT NULL AND ar.late_minutes > 0), 0),
        COALESCE(SUM(ar.late_minutes) FILTER (WHERE ar.check_out_time IS NOT NULL AND ar.late_minutes > 0), 0),
        COALESCE(COUNT(DISTINCT ar.id) FILTER (WHERE ar.check_out_time IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.attendance_corrections ac WHERE ac.attendance_record_id = ar.id
        )), 0),
        COALESCE(COUNT(*) FILTER (WHERE ar.check_out_time IS NULL), 0),
        COALESCE(COUNT(DISTINCT ar.employee_user_id), 0)
    INTO
        v_total_worked_minutes,
        v_completed_shifts,
        v_late_shifts,
        v_total_late_minutes,
        v_corrected_records,
        v_open_sessions,
        v_employees_with_attendance_count
    FROM public.attendance_records ar
    WHERE ar.station_id = p_station_id
      AND COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) >= v_range_start_utc
      AND COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) < v_range_end_utc;

    -- Active employees currently in station
    SELECT COUNT(*) INTO v_active_employees_count
    FROM public.station_memberships
    WHERE station_id = p_station_id AND status = 'ACTIVE';

    -- Repeated lateness count (employees with >= 3 late shifts in period)
    SELECT COUNT(*) INTO v_repeated_lateness_count
    FROM (
        SELECT ar.employee_user_id
        FROM public.attendance_records ar
        WHERE ar.station_id = p_station_id
          AND ar.check_out_time IS NOT NULL
          AND ar.late_minutes > 0
          AND COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) >= v_range_start_utc
          AND COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) < v_range_end_utc
        GROUP BY ar.employee_user_id
        HAVING COUNT(*) >= 3
    ) late_emps;

    RETURN jsonb_build_object(
        'success', true,
        'station_id', p_station_id,
        'station_name', v_station.name,
        'from_date', p_from,
        'to_date', p_to,
        'total_worked_minutes', v_total_worked_minutes,
        'completed_shifts', v_completed_shifts,
        'late_shifts', v_late_shifts,
        'total_late_minutes', v_total_late_minutes,
        'corrected_records', v_corrected_records,
        'open_sessions', v_open_sessions,
        'employees_with_attendance_count', v_employees_with_attendance_count,
        'active_employees_count', v_active_employees_count,
        'repeated_lateness_employee_count', v_repeated_lateness_count
    );
END;
$$;

-- 6. RPC: get_station_employee_attendance_summary
-- Employee breakdown table for station managers
CREATE OR REPLACE FUNCTION public.get_station_employee_attendance_summary(
    p_station_id UUID,
    p_from DATE,
    p_to DATE,
    p_search TEXT DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'name',
    p_sort_order TEXT DEFAULT 'asc',
    p_limit INTEGER DEFAULT 25,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_station RECORD;
    v_range_start_utc TIMESTAMPTZ;
    v_range_end_utc TIMESTAMPTZ;
    v_clean_search TEXT;
    v_limit INTEGER;
    v_offset INTEGER;
    v_total_count INTEGER := 0;
    v_items JSONB := '[]'::jsonb;
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    IF p_station_id IS NULL OR p_from IS NULL OR p_to IS NULL THEN
        RAISE EXCEPTION 'Station and date range parameters are required' USING ERRCODE = '22000';
    END IF;

    IF p_from > p_to THEN
        RAISE EXCEPTION 'Start date cannot be after end date' USING ERRCODE = '22000';
    END IF;

    IF (p_to - p_from) > 366 THEN
        RAISE EXCEPTION 'Date range cannot exceed 366 days' USING ERRCODE = '22000';
    END IF;

    SELECT * INTO v_station FROM public.stations WHERE id = p_station_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Station not found' USING ERRCODE = 'P0002';
    END IF;

    IF NOT public.has_station_permission(p_station_id, v_caller_id, 'reports.team.read') THEN
        RAISE EXCEPTION 'Access denied: caller lacks reporting authorization for this station' USING ERRCODE = '42501';
    END IF;

    v_range_start_utc := (p_from::TEXT || ' 00:00:00')::TIMESTAMP AT TIME ZONE v_station.timezone;
    v_range_end_utc := ((p_to + 1)::TEXT || ' 00:00:00')::TIMESTAMP AT TIME ZONE v_station.timezone;

    v_clean_search := trim(regexp_replace(COALESCE(p_search, ''), '[%_]', '', 'g'));
    v_limit := GREATEST(1, LEAST(COALESCE(p_limit, 25), 50));
    v_offset := GREATEST(0, COALESCE(p_offset, 0));

    -- Total distinct employees who worked in range OR have active membership matching search
    WITH candidate_employees AS (
        SELECT DISTINCT p.id AS user_id
        FROM public.profiles p
        LEFT JOIN public.station_memberships sm ON sm.user_id = p.id AND sm.station_id = p_station_id
        LEFT JOIN public.attendance_records ar ON ar.employee_user_id = p.id AND ar.station_id = p_station_id
            AND COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) >= v_range_start_utc
            AND COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) < v_range_end_utc
        WHERE (sm.station_id = p_station_id OR ar.station_id = p_station_id)
          AND (
              v_clean_search = ''
              OR (p.first_name || ' ' || p.last_name) ILIKE '%' || v_clean_search || '%'
              OR COALESCE(sm.employee_code, '') ILIKE '%' || v_clean_search || '%'
          )
    )
    SELECT COUNT(*) INTO v_total_count FROM candidate_employees;

    -- Aggregate breakdown per employee
    WITH emp_metrics AS (
        SELECT 
            p.id AS user_id,
            p.first_name,
            p.last_name,
            sm.employee_code,
            sm.status AS membership_status,
            sm.role AS station_role,
            COALESCE(SUM(ar.worked_minutes) FILTER (WHERE ar.check_out_time IS NOT NULL AND ar.worked_minutes >= 0), 0) AS total_worked_minutes,
            COALESCE(COUNT(*) FILTER (WHERE ar.check_out_time IS NOT NULL AND ar.worked_minutes >= 0), 0) AS completed_shifts,
            COALESCE(COUNT(*) FILTER (WHERE ar.check_out_time IS NOT NULL AND ar.late_minutes > 0), 0) AS late_shifts,
            COALESCE(SUM(ar.late_minutes) FILTER (WHERE ar.check_out_time IS NOT NULL AND ar.late_minutes > 0), 0) AS total_late_minutes,
            COALESCE(COUNT(DISTINCT ar.id) FILTER (WHERE ar.check_out_time IS NOT NULL AND EXISTS (
                SELECT 1 FROM public.attendance_corrections ac WHERE ac.attendance_record_id = ar.id
            )), 0) AS corrected_records,
            COALESCE(COUNT(*) FILTER (WHERE ar.check_out_time IS NULL), 0) AS open_session_count,
            MIN((COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) AT TIME ZONE v_station.timezone)::DATE) FILTER (WHERE ar.check_out_time IS NOT NULL) AS first_shift_date,
            MAX((COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) AT TIME ZONE v_station.timezone)::DATE) FILTER (WHERE ar.check_out_time IS NOT NULL) AS last_shift_date,
            MAX(ar.check_in_time) AS latest_check_in
        FROM public.profiles p
        LEFT JOIN public.station_memberships sm ON sm.user_id = p.id AND sm.station_id = p_station_id
        LEFT JOIN public.attendance_records ar ON ar.employee_user_id = p.id AND ar.station_id = p_station_id
            AND COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) >= v_range_start_utc
            AND COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) < v_range_end_utc
        WHERE (sm.station_id = p_station_id OR ar.station_id = p_station_id)
          AND (
              v_clean_search = ''
              OR (p.first_name || ' ' || p.last_name) ILIKE '%' || v_clean_search || '%'
              OR COALESCE(sm.employee_code, '') ILIKE '%' || v_clean_search || '%'
          )
        GROUP BY p.id, p.first_name, p.last_name, sm.employee_code, sm.status, sm.role
    )
    SELECT COALESCE(jsonb_agg(item), '[]'::jsonb) INTO v_items
    FROM (
        SELECT jsonb_build_object(
            'employee_user_id', em.user_id,
            'first_name', em.first_name,
            'last_name', em.last_name,
            'employee_code', em.employee_code,
            'membership_status', em.membership_status,
            'station_role', em.station_role,
            'total_worked_minutes', em.total_worked_minutes,
            'completed_shifts', em.completed_shifts,
            'late_shifts', em.late_shifts,
            'total_late_minutes', em.total_late_minutes,
            'corrected_records', em.corrected_records,
            'open_session_count', em.open_session_count,
            'has_repeated_lateness', (em.late_shifts >= 3),
            'first_shift_date', em.first_shift_date,
            'last_shift_date', em.last_shift_date
        ) AS item
        FROM emp_metrics em
        ORDER BY 
            CASE WHEN p_sort_by = 'name' AND p_sort_order = 'desc' THEN em.first_name END DESC,
            CASE WHEN p_sort_by = 'name' THEN em.first_name END ASC,
            CASE WHEN p_sort_by = 'employee_code' AND p_sort_order = 'desc' THEN em.employee_code END DESC,
            CASE WHEN p_sort_by = 'employee_code' THEN em.employee_code END ASC,
            CASE WHEN p_sort_by = 'worked_minutes' AND p_sort_order = 'asc' THEN em.total_worked_minutes END ASC,
            CASE WHEN p_sort_by = 'worked_minutes' THEN em.total_worked_minutes END DESC,
            CASE WHEN p_sort_by = 'completed_shifts' AND p_sort_order = 'asc' THEN em.completed_shifts END ASC,
            CASE WHEN p_sort_by = 'completed_shifts' THEN em.completed_shifts END DESC,
            CASE WHEN p_sort_by = 'late_shifts' AND p_sort_order = 'asc' THEN em.late_shifts END ASC,
            CASE WHEN p_sort_by = 'late_shifts' THEN em.late_shifts END DESC,
            CASE WHEN p_sort_by = 'corrected_records' AND p_sort_order = 'asc' THEN em.corrected_records END ASC,
            CASE WHEN p_sort_by = 'corrected_records' THEN em.corrected_records END DESC,
            CASE WHEN p_sort_by = 'last_seen' AND p_sort_order = 'asc' THEN em.latest_check_in END ASC,
            CASE WHEN p_sort_by = 'last_seen' THEN em.latest_check_in END DESC,
            em.user_id ASC
        LIMIT v_limit OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'success', true,
        'station_id', p_station_id,
        'items', v_items,
        'total_count', v_total_count,
        'limit', v_limit,
        'offset', v_offset,
        'has_more', (v_offset + v_limit < v_total_count)
    );
END;
$$;

-- 7. RPC: get_station_daily_attendance_report
-- Daily operational report grouped by scheduled shifts and walk-in attendance
CREATE OR REPLACE FUNCTION public.get_station_daily_attendance_report(
    p_station_id UUID,
    p_date DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_station RECORD;
    v_day_start_utc TIMESTAMPTZ;
    v_day_end_utc TIMESTAMPTZ;
    v_schedule RECORD;
    v_shifts JSONB := '[]'::jsonb;
    v_walk_ins JSONB := '[]'::jsonb;
    v_total_worked_minutes INTEGER := 0;
    v_completed_shifts INTEGER := 0;
    v_late_shifts INTEGER := 0;
    v_open_sessions INTEGER := 0;
    v_walk_in_count INTEGER := 0;
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    IF p_station_id IS NULL OR p_date IS NULL THEN
        RAISE EXCEPTION 'Station and operational date are required' USING ERRCODE = '22000';
    END IF;

    SELECT * INTO v_station FROM public.stations WHERE id = p_station_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Station not found' USING ERRCODE = 'P0002';
    END IF;

    IF NOT public.has_station_permission(p_station_id, v_caller_id, 'reports.team.read') THEN
        RAISE EXCEPTION 'Access denied: caller lacks reporting authorization for this station' USING ERRCODE = '42501';
    END IF;

    v_day_start_utc := (p_date::TEXT || ' 00:00:00')::TIMESTAMP AT TIME ZONE v_station.timezone;
    v_day_end_utc := ((p_date + 1)::TEXT || ' 00:00:00')::TIMESTAMP AT TIME ZONE v_station.timezone;

    -- Day-level overall attendance totals
    SELECT
        COALESCE(SUM(ar.worked_minutes) FILTER (WHERE ar.check_out_time IS NOT NULL AND ar.worked_minutes >= 0), 0),
        COALESCE(COUNT(*) FILTER (WHERE ar.check_out_time IS NOT NULL AND ar.worked_minutes >= 0), 0),
        COALESCE(COUNT(*) FILTER (WHERE ar.check_out_time IS NOT NULL AND ar.late_minutes > 0), 0),
        COALESCE(COUNT(*) FILTER (WHERE ar.check_out_time IS NULL), 0),
        COALESCE(COUNT(*) FILTER (WHERE ar.work_schedule_shift_id IS NULL), 0)
    INTO
        v_total_worked_minutes,
        v_completed_shifts,
        v_late_shifts,
        v_open_sessions,
        v_walk_in_count
    FROM public.attendance_records ar
    WHERE ar.station_id = p_station_id
      AND COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) >= v_day_start_utc
      AND COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) < v_day_end_utc;

    -- Query scheduled shifts for the day
    SELECT COALESCE(jsonb_agg(s_item), '[]'::jsonb) INTO v_shifts
    FROM (
        SELECT jsonb_build_object(
            'shift_id', wss.id,
            'shift_name', wss.shift_name_snapshot,
            'starts_at', wss.starts_at,
            'ends_at', wss.ends_at,
            'required_staff_count', wss.required_staff_count,
            'assigned_count', (
                SELECT COUNT(*) FROM public.shift_assignments sa WHERE sa.work_schedule_shift_id = wss.id
            ),
            'checked_in_count', (
                SELECT COUNT(*) FROM public.attendance_records ar 
                WHERE ar.work_schedule_shift_id = wss.id AND ar.station_id = p_station_id
            ),
            'completed_count', (
                SELECT COUNT(*) FROM public.attendance_records ar 
                WHERE ar.work_schedule_shift_id = wss.id AND ar.station_id = p_station_id AND ar.check_out_time IS NOT NULL
            ),
            'late_count', (
                SELECT COUNT(*) FROM public.attendance_records ar 
                WHERE ar.work_schedule_shift_id = wss.id AND ar.station_id = p_station_id AND ar.late_minutes > 0
            ),
            'open_count', (
                SELECT COUNT(*) FROM public.attendance_records ar 
                WHERE ar.work_schedule_shift_id = wss.id AND ar.station_id = p_station_id AND ar.check_out_time IS NULL
            ),
            'attendance_records', (
                SELECT COALESCE(jsonb_agg(jsonb_build_object(
                    'record_id', ar.id,
                    'user_id', ar.employee_user_id,
                    'first_name', p.first_name,
                    'last_name', p.last_name,
                    'employee_code', sm.employee_code,
                    'check_in_time', ar.check_in_time,
                    'check_out_time', ar.check_out_time,
                    'worked_minutes', ar.worked_minutes,
                    'late_minutes', ar.late_minutes,
                    'status', ar.status,
                    'verification_method', ar.verification_method,
                    'is_corrected', EXISTS (
                        SELECT 1 FROM public.attendance_corrections ac WHERE ac.attendance_record_id = ar.id
                    )
                )), '[]'::jsonb)
                FROM public.attendance_records ar
                JOIN public.profiles p ON p.id = ar.employee_user_id
                LEFT JOIN public.station_memberships sm ON sm.user_id = p.id AND sm.station_id = p_station_id
                WHERE ar.work_schedule_shift_id = wss.id AND ar.station_id = p_station_id
            )
        ) AS s_item
        FROM public.work_schedule_shifts wss
        JOIN public.work_schedules ws ON ws.id = wss.work_schedule_id
        WHERE wss.station_id = p_station_id
          AND wss.operational_date = p_date
          AND ws.status = 'PUBLISHED'
        ORDER BY wss.starts_at ASC
    ) shift_sub;

    -- Query unscheduled walk-in records on that day
    SELECT COALESCE(jsonb_agg(w_item), '[]'::jsonb) INTO v_walk_ins
    FROM (
        SELECT jsonb_build_object(
            'record_id', ar.id,
            'user_id', ar.employee_user_id,
            'first_name', p.first_name,
            'last_name', p.last_name,
            'employee_code', sm.employee_code,
            'check_in_time', ar.check_in_time,
            'check_out_time', ar.check_out_time,
            'worked_minutes', ar.worked_minutes,
            'late_minutes', ar.late_minutes,
            'status', ar.status,
            'verification_method', ar.verification_method,
            'is_corrected', EXISTS (
                SELECT 1 FROM public.attendance_corrections ac WHERE ac.attendance_record_id = ar.id
            )
        ) AS w_item
        FROM public.attendance_records ar
        JOIN public.profiles p ON p.id = ar.employee_user_id
        LEFT JOIN public.station_memberships sm ON sm.user_id = p.id AND sm.station_id = p_station_id
        WHERE ar.station_id = p_station_id
          AND ar.work_schedule_shift_id IS NULL
          AND ar.check_in_time >= v_day_start_utc
          AND ar.check_in_time < v_day_end_utc
        ORDER BY ar.check_in_time ASC
    ) walkin_sub;

    RETURN jsonb_build_object(
        'success', true,
        'station_id', p_station_id,
        'station_name', v_station.name,
        'date', p_date,
        'day_summary', jsonb_build_object(
            'total_worked_minutes', v_total_worked_minutes,
            'completed_shifts', v_completed_shifts,
            'late_shifts', v_late_shifts,
            'open_sessions', v_open_sessions,
            'walk_in_count', v_walk_in_count
        ),
        'shifts', v_shifts,
        'walk_ins', v_walk_ins
    );
END;
$$;

-- 8. RPC: get_station_employee_attendance_detail
-- Detailed drilldown into employee attendance and full correction history
CREATE OR REPLACE FUNCTION public.get_station_employee_attendance_detail(
    p_station_id UUID,
    p_employee_user_id UUID,
    p_from DATE,
    p_to DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_station RECORD;
    v_profile RECORD;
    v_membership RECORD;
    v_range_start_utc TIMESTAMPTZ;
    v_range_end_utc TIMESTAMPTZ;
    v_summary JSONB;
    v_records JSONB := '[]'::jsonb;
    v_total_worked_minutes INTEGER := 0;
    v_completed_shifts INTEGER := 0;
    v_late_shifts INTEGER := 0;
    v_total_late_minutes INTEGER := 0;
    v_corrected_records INTEGER := 0;
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    IF p_station_id IS NULL OR p_employee_user_id IS NULL OR p_from IS NULL OR p_to IS NULL THEN
        RAISE EXCEPTION 'Station, employee, and date range parameters are required' USING ERRCODE = '22000';
    END IF;

    IF p_from > p_to THEN
        RAISE EXCEPTION 'Start date cannot be after end date' USING ERRCODE = '22000';
    END IF;

    IF (p_to - p_from) > 366 THEN
        RAISE EXCEPTION 'Date range cannot exceed 366 days' USING ERRCODE = '22000';
    END IF;

    SELECT * INTO v_station FROM public.stations WHERE id = p_station_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Station not found' USING ERRCODE = 'P0002';
    END IF;

    -- Authorization check: caller must be the employee themselves OR have station manager authorization
    IF v_caller_id <> p_employee_user_id THEN
        IF NOT public.has_station_permission(p_station_id, v_caller_id, 'reports.team.read') THEN
            RAISE EXCEPTION 'Access denied: caller lacks authorization to view employee drilldown' USING ERRCODE = '42501';
        END IF;
    END IF;

    SELECT * INTO v_profile FROM public.profiles WHERE id = p_employee_user_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Employee profile not found' USING ERRCODE = 'P0002';
    END IF;

    SELECT * INTO v_membership FROM public.station_memberships WHERE station_id = p_station_id AND user_id = p_employee_user_id;

    v_range_start_utc := (p_from::TEXT || ' 00:00:00')::TIMESTAMP AT TIME ZONE v_station.timezone;
    v_range_end_utc := ((p_to + 1)::TEXT || ' 00:00:00')::TIMESTAMP AT TIME ZONE v_station.timezone;

    -- Summary metrics
    SELECT
        COALESCE(SUM(ar.worked_minutes) FILTER (WHERE ar.check_out_time IS NOT NULL AND ar.worked_minutes >= 0), 0),
        COALESCE(COUNT(*) FILTER (WHERE ar.check_out_time IS NOT NULL AND ar.worked_minutes >= 0), 0),
        COALESCE(COUNT(*) FILTER (WHERE ar.check_out_time IS NOT NULL AND ar.late_minutes > 0), 0),
        COALESCE(SUM(ar.late_minutes) FILTER (WHERE ar.check_out_time IS NOT NULL AND ar.late_minutes > 0), 0),
        COALESCE(COUNT(DISTINCT ar.id) FILTER (WHERE ar.check_out_time IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.attendance_corrections ac WHERE ac.attendance_record_id = ar.id
        )), 0)
    INTO
        v_total_worked_minutes,
        v_completed_shifts,
        v_late_shifts,
        v_total_late_minutes,
        v_corrected_records
    FROM public.attendance_records ar
    WHERE ar.station_id = p_station_id
      AND ar.employee_user_id = p_employee_user_id
      AND COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) >= v_range_start_utc
      AND COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) < v_range_end_utc;

    v_summary := jsonb_build_object(
        'total_worked_minutes', v_total_worked_minutes,
        'completed_shifts', v_completed_shifts,
        'late_shifts', v_late_shifts,
        'total_late_minutes', v_total_late_minutes,
        'corrected_records', v_corrected_records,
        'has_repeated_lateness', (v_late_shifts >= 3)
    );

    -- Records with deterministic correction history
    SELECT COALESCE(jsonb_agg(r_item), '[]'::jsonb) INTO v_records
    FROM (
        SELECT jsonb_build_object(
            'id', ar.id,
            'work_schedule_shift_id', ar.work_schedule_shift_id,
            'shift_name_snapshot', ar.shift_name_snapshot,
            'scheduled_start_at_snapshot', ar.scheduled_start_at_snapshot,
            'scheduled_end_at_snapshot', ar.scheduled_end_at_snapshot,
            'check_in_time', ar.check_in_time,
            'check_out_time', ar.check_out_time,
            'worked_minutes', ar.worked_minutes,
            'late_minutes', ar.late_minutes,
            'status', ar.status,
            'verification_method', ar.verification_method,
            'operational_date', (COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) AT TIME ZONE v_station.timezone)::DATE,
            'is_late', (ar.late_minutes > 0),
            'corrections', (
                SELECT COALESCE(jsonb_agg(jsonb_build_object(
                    'id', ac.id,
                    'actor_user_id', ac.actor_user_id,
                    'actor_name', (ap.first_name || ' ' || ap.last_name),
                    'previous_check_in_time', ac.previous_check_in_time,
                    'new_check_in_time', ac.new_check_in_time,
                    'previous_check_out_time', ac.previous_check_out_time,
                    'new_check_out_time', ac.new_check_out_time,
                    'previous_worked_minutes', ac.previous_worked_minutes,
                    'new_worked_minutes', ac.new_worked_minutes,
                    'reason', ac.reason,
                    'created_at', ac.created_at
                ) ORDER BY ac.created_at ASC), '[]'::jsonb)
                FROM public.attendance_corrections ac
                JOIN public.profiles ap ON ap.id = ac.actor_user_id
                WHERE ac.attendance_record_id = ar.id
            ),
            'created_at', ar.created_at
        ) AS r_item
        FROM public.attendance_records ar
        WHERE ar.station_id = p_station_id
          AND ar.employee_user_id = p_employee_user_id
          AND COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) >= v_range_start_utc
          AND COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) < v_range_end_utc
        ORDER BY COALESCE(ar.scheduled_start_at_snapshot, ar.check_in_time) DESC, ar.id DESC
    ) rec_sub;

    RETURN jsonb_build_object(
        'success', true,
        'station_id', p_station_id,
        'station_name', v_station.name,
        'employee', jsonb_build_object(
            'id', v_profile.id,
            'first_name', v_profile.first_name,
            'last_name', v_profile.last_name,
            'employee_code', v_membership.employee_code,
            'membership_status', v_membership.status,
            'station_role', v_membership.role
        ),
        'from_date', p_from,
        'to_date', p_to,
        'summary', v_summary,
        'records', v_records
    );
END;
$$;

-- 9. Grants for Authenticated Users on Reporting Functions
GRANT EXECUTE ON FUNCTION public.get_my_attendance_summary(DATE, DATE, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_attendance_history(DATE, DATE, UUID, TEXT, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_station_attendance_summary(UUID, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_station_employee_attendance_summary(UUID, DATE, DATE, TEXT, TEXT, TEXT, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_station_daily_attendance_report(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_station_employee_attendance_detail(UUID, UUID, DATE, DATE) TO authenticated;
