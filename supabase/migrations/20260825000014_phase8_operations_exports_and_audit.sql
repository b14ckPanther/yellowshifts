-- ============================================================================
-- YELLOWSHIFTS MIGRATION 014: PHASE 8 OPERATIONS, EXPORTS & AUDIT
-- Authoritative Export Engine, Audit Center, Station Admin Expansion,
-- System Health & Data Lifecycle Retention.
-- ============================================================================

-- 1. Create Report Exports Table
CREATE TABLE IF NOT EXISTS public.report_exports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    station_id UUID REFERENCES public.stations(id) ON DELETE CASCADE,
    requested_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    export_type TEXT NOT NULL,
    format TEXT NOT NULL DEFAULT 'CSV',
    status TEXT NOT NULL DEFAULT 'PENDING',
    filter_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    storage_path TEXT,
    row_count INTEGER,
    file_size_bytes BIGINT,
    failure_code TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (timezone('utc'::text, now()) + INTERVAL '24 hours'),
    failed_at TIMESTAMPTZ,
    CONSTRAINT check_export_format CHECK (format IN ('CSV', 'PDF')),
    CONSTRAINT check_export_status CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'EXPIRED')),
    CONSTRAINT check_export_type CHECK (export_type IN (
        'MY_ATTENDANCE_HISTORY',
        'STATION_ATTENDANCE_SUMMARY',
        'STATION_EMPLOYEE_WORKED_HOURS',
        'DAILY_ATTENDANCE_REPORT',
        'ATTENDANCE_CORRECTION_LEDGER',
        'PUBLISHED_SCHEDULE',
        'EMPLOYEE_DIRECTORY',
        'AVAILABILITY_OVERVIEW'
    ))
);

-- Indexes for Export Performance
CREATE INDEX IF NOT EXISTS idx_report_exports_station_created 
    ON public.report_exports(station_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_report_exports_requested_by 
    ON public.report_exports(requested_by, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_report_exports_expires 
    ON public.report_exports(expires_at) WHERE status != 'EXPIRED';

-- RLS on Report Exports
ALTER TABLE public.report_exports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS report_exports_select_policy ON public.report_exports;
CREATE POLICY report_exports_select_policy ON public.report_exports
    FOR SELECT
    TO authenticated
    USING (
        requested_by = auth.uid()
        OR (
            station_id IS NOT NULL 
            AND public.is_station_admin(station_id, auth.uid())
        )
    );

-- Direct client mutations disallowed; strictly managed via SECURITY DEFINER RPCs
REVOKE INSERT, UPDATE, DELETE ON public.report_exports FROM authenticated, anon, PUBLIC;

-- 2. Storage Bucket Setup (reports_storage)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'storage' AND table_name = 'buckets') THEN
        INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
        VALUES ('reports_storage', 'reports_storage', false, 52428800, ARRAY['text/csv', 'application/pdf'])
        ON CONFLICT (id) DO UPDATE SET public = false;
    END IF;
END $$;

-- 3. CSV Sanitization Helper Function (Prevents Formula Injection: =, +, -, @, \t, \r)
CREATE OR REPLACE FUNCTION public.escape_csv_field(p_val TEXT)
RETURNS TEXT AS $$
DECLARE
    v_clean TEXT;
BEGIN
    IF p_val IS NULL THEN
        RETURN '';
    END IF;
    
    v_clean := p_val;
    -- Prepend single quote if field starts with dangerous spreadsheet formula character
    IF v_clean ~ '^[=+\-@\t\r]' THEN
        v_clean := '''' || v_clean;
    END IF;

    -- Escape quotes and wrap in quotes if containing delimiter, quote, or newline
    IF v_clean ~ '[",\n\r]' OR v_clean ~ '^[=+\-@]' THEN
        v_clean := '"' || replace(v_clean, '"', '""') || '"';
    END IF;

    RETURN v_clean;
END;
$$ LANGUAGE plpgsql IMMUTABLE SET search_path = public, pg_temp;

-- 4. Recursive Server-Side Audit Metadata Sanitizer (Strips all credentials & private tokens)
CREATE OR REPLACE FUNCTION public.sanitize_audit_metadata(p_metadata JSONB)
RETURNS JSONB AS $$
DECLARE
    v_key TEXT;
    v_val JSONB;
    v_result JSONB := '{}'::jsonb;
    v_forbidden_keys TEXT[] := ARRAY[
        'password', 'temporary_password', 'token', 'access_token', 'refresh_token',
        'authorization', 'service_role', 'secret', 'raw_secret', 'device_token',
        'signed_url', 'provider_subject_id', 'client_secret', 'kiosk_secret', 'pin'
    ];
BEGIN
    IF p_metadata IS NULL OR jsonb_typeof(p_metadata) != 'object' THEN
        RETURN '{}'::jsonb;
    END IF;

    FOR v_key, v_val IN SELECT * FROM jsonb_each(p_metadata)
    LOOP
        -- Check if key matches or contains forbidden credential substrings
        IF NOT (LOWER(v_key) = ANY(v_forbidden_keys)) 
           AND NOT (LOWER(v_key) ~ '(password|secret|token|private_key|service_role|client_secret|signed_url|provider_subject|pin)') THEN
            IF jsonb_typeof(v_val) = 'object' THEN
                v_result := v_result || jsonb_build_object(v_key, public.sanitize_audit_metadata(v_val));
            ELSE
                v_result := v_result || jsonb_build_object(v_key, v_val);
            END IF;
        END IF;

    END LOOP;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql IMMUTABLE SET search_path = public, pg_temp;

-- 5. RPC: Request Report Export
CREATE OR REPLACE FUNCTION public.request_report_export(
    p_station_id UUID,
    p_export_type TEXT,
    p_format TEXT DEFAULT 'CSV',
    p_filter_payload JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_is_admin BOOLEAN := false;
    v_has_report_read BOOLEAN := false;
    v_export_id UUID;
    v_from_date DATE;
    v_to_date DATE;
    v_membership_status public.membership_status;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    -- Validate format
    IF p_format NOT IN ('CSV', 'PDF') THEN
        RAISE EXCEPTION 'Unsupported export format: %', p_format USING ERRCODE = '22000';
    END IF;

    -- Validate export type
    IF p_export_type NOT IN (
        'MY_ATTENDANCE_HISTORY',
        'STATION_ATTENDANCE_SUMMARY',
        'STATION_EMPLOYEE_WORKED_HOURS',
        'DAILY_ATTENDANCE_REPORT',
        'ATTENDANCE_CORRECTION_LEDGER',
        'PUBLISHED_SCHEDULE',
        'EMPLOYEE_DIRECTORY',
        'AVAILABILITY_OVERVIEW'
    ) THEN
        RAISE EXCEPTION 'Invalid export type: %', p_export_type USING ERRCODE = '22000';
    END IF;

    -- Verify active station membership
    IF p_station_id IS NOT NULL THEN
        SELECT status INTO v_membership_status
        FROM public.station_memberships
        WHERE station_id = p_station_id AND user_id = v_caller_id;

        IF v_membership_status IS NULL OR v_membership_status != 'ACTIVE' THEN
            RAISE EXCEPTION 'Access denied: caller does not have an active membership in this station'
                USING ERRCODE = '42501';
        END IF;

        v_is_admin := public.is_station_admin(p_station_id, v_caller_id);
        v_has_report_read := public.has_station_permission(p_station_id, v_caller_id, 'reports.station.read') 
                          OR public.has_station_permission(p_station_id, v_caller_id, 'reports.team.read');
    END IF;

    -- Export Authorization Matrix
    IF p_export_type = 'MY_ATTENDANCE_HISTORY' THEN
        -- Allowed for any active station member for their own data
        NULL;
    ELSIF p_export_type IN ('STATION_ATTENDANCE_SUMMARY', 'STATION_EMPLOYEE_WORKED_HOURS', 'DAILY_ATTENDANCE_REPORT', 'ATTENDANCE_CORRECTION_LEDGER') THEN
        IF p_station_id IS NULL OR NOT (v_is_admin OR v_has_report_read) THEN
            RAISE EXCEPTION 'Access denied: caller lacks report read capability for station'
                USING ERRCODE = '42501';
        END IF;
    ELSIF p_export_type = 'PUBLISHED_SCHEDULE' THEN
        IF p_station_id IS NULL OR NOT (v_is_admin OR public.has_station_permission(p_station_id, v_caller_id, 'schedule.read') OR v_has_report_read) THEN
            RAISE EXCEPTION 'Access denied: caller lacks schedule read capability for station'
                USING ERRCODE = '42501';
        END IF;
    ELSIF p_export_type = 'EMPLOYEE_DIRECTORY' THEN
        IF p_station_id IS NULL OR NOT v_is_admin THEN
            RAISE EXCEPTION 'Access denied: caller must be station admin to export employee directory'
                USING ERRCODE = '42501';
        END IF;
    ELSIF p_export_type = 'AVAILABILITY_OVERVIEW' THEN
        IF p_station_id IS NULL OR NOT (v_is_admin OR public.has_station_permission(p_station_id, v_caller_id, 'availability.team.read')) THEN
            RAISE EXCEPTION 'Access denied: caller lacks availability read capability for station'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    -- Validate date filters if present
    IF p_filter_payload ? 'from_date' AND p_filter_payload ? 'to_date' THEN
        BEGIN
            v_from_date := (p_filter_payload->>'from_date')::date;
            v_to_date := (p_filter_payload->>'to_date')::date;
            PERFORM public.validate_reporting_date_range(v_from_date, v_to_date);
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION 'Invalid date filter range in export request: %', SQLERRM USING ERRCODE = '22000';
        END;
    END IF;

    -- Insert new export job
    INSERT INTO public.report_exports (
        station_id,
        requested_by,
        export_type,
        format,
        status,
        filter_payload,
        expires_at
    ) VALUES (
        p_station_id,
        v_caller_id,
        p_export_type,
        p_format,
        'COMPLETED',
        p_filter_payload,
        timezone('utc'::text, now()) + INTERVAL '24 hours'
    ) RETURNING id INTO v_export_id;

    -- Audit log
    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        p_station_id,
        v_caller_id,
        'REPORT_EXPORT_REQUESTED',
        'report_export',
        v_export_id::text,
        jsonb_build_object(
            'export_type', p_export_type,
            'format', p_format,
            'filters', p_filter_payload
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'export_id', v_export_id,
        'status', 'COMPLETED',
        'expires_at', (timezone('utc'::text, now()) + INTERVAL '24 hours')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 6. RPC: Server-Authoritative CSV Generator
CREATE OR REPLACE FUNCTION public.generate_report_export_csv(p_export_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_export public.report_exports%ROWTYPE;
    v_caller_id UUID;
    v_is_admin BOOLEAN := false;
    v_station_name TEXT := 'Unknown Station';
    v_timezone TEXT := 'Asia/Jerusalem';
    v_from_date DATE;
    v_to_date DATE;
    v_csv_header TEXT;
    v_csv_rows TEXT := '';
    v_row_count INTEGER := 0;
    v_rec RECORD;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_export
    FROM public.report_exports
    WHERE id = p_export_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Export record not found' USING ERRCODE = 'P0002';
    END IF;

    -- Check expiration
    IF v_export.expires_at <= now() THEN
        UPDATE public.report_exports SET status = 'EXPIRED' WHERE id = p_export_id;
        RAISE EXCEPTION 'Export has expired' USING ERRCODE = 'P0081';
    END IF;


    -- Authorization check
    IF v_export.station_id IS NOT NULL THEN
        v_is_admin := public.is_station_admin(v_export.station_id, v_caller_id);
    END IF;

    IF v_export.requested_by != v_caller_id AND NOT v_is_admin THEN
        RAISE EXCEPTION 'Access denied to this export payload' USING ERRCODE = '42501';
    END IF;

    -- Extract station metadata
    IF v_export.station_id IS NOT NULL THEN
        SELECT name, timezone INTO v_station_name, v_timezone
        FROM public.stations
        WHERE id = v_export.station_id;
    END IF;

    v_from_date := COALESCE((v_export.filter_payload->>'from_date')::date, CURRENT_DATE - INTERVAL '30 days');
    v_to_date := COALESCE((v_export.filter_payload->>'to_date')::date, CURRENT_DATE);

    -- =========================================================================
    -- GENERATE SPECIFIC EXPORT TYPE CONTENT (UTF-8 with Formula Protection)
    -- =========================================================================
    CASE v_export.export_type
        -- 1. MY ATTENDANCE HISTORY
        WHEN 'MY_ATTENDANCE_HISTORY' THEN
            v_csv_header := 'Date,Check-In Time,Check-Out Time,Worked Minutes,Status,Verified By,Flags';
            FOR v_rec IN 
                SELECT 
                    TO_CHAR(ar.check_in_time AT TIME ZONE v_timezone, 'YYYY-MM-DD') AS work_date,
                    TO_CHAR(ar.check_in_time AT TIME ZONE v_timezone, 'HH24:MI:SS') AS in_time,
                    COALESCE(TO_CHAR(ar.check_out_time AT TIME ZONE v_timezone, 'HH24:MI:SS'), 'OPEN') AS out_time,
                    COALESCE(ar.worked_minutes, 0) AS minutes,
                    ar.status::text AS record_status,
                    COALESCE(kd.name, 'Manual/Web') AS verified_method,
                    CASE WHEN ar.late_minutes > 0 THEN 'LATE' ELSE 'ON_TIME' END AS lateness
                FROM public.attendance_records ar
                LEFT JOIN public.kiosk_devices kd ON ar.check_in_kiosk_device_id = kd.id
                WHERE ar.employee_user_id = v_export.requested_by
                  AND (v_export.station_id IS NULL OR ar.station_id = v_export.station_id)
                  AND (ar.check_in_time AT TIME ZONE v_timezone)::date BETWEEN v_from_date AND v_to_date
                ORDER BY ar.check_in_time DESC
            LOOP
                v_row_count := v_row_count + 1;
                v_csv_rows := v_csv_rows || 
                    public.escape_csv_field(v_rec.work_date) || ',' ||
                    public.escape_csv_field(v_rec.in_time) || ',' ||
                    public.escape_csv_field(v_rec.out_time) || ',' ||
                    v_rec.minutes::text || ',' ||
                    public.escape_csv_field(v_rec.record_status) || ',' ||
                    public.escape_csv_field(v_rec.verified_method) || ',' ||
                    public.escape_csv_field(v_rec.lateness) || E'\n';
            END LOOP;

        -- 2. STATION ATTENDANCE SUMMARY
        WHEN 'STATION_ATTENDANCE_SUMMARY' THEN
            v_csv_header := 'Station Name,Report Range Start,Report Range End,Total Completed Shifts,Total Worked Minutes,Total Late Shifts,Late Arrival Rate %,Corrections Count';
            FOR v_rec IN 
                SELECT 
                    COUNT(ar.id) FILTER (WHERE ar.status = 'COMPLETED') AS total_completed_shifts,
                    COALESCE(SUM(ar.worked_minutes) FILTER (WHERE ar.status = 'COMPLETED'), 0) AS total_worked_minutes,
                    COUNT(ar.id) FILTER (WHERE ar.late_minutes > 0) AS total_late_shifts,
                    CASE 
                        WHEN COUNT(ar.id) FILTER (WHERE ar.status = 'COMPLETED') > 0 THEN 
                            ROUND((COUNT(ar.id) FILTER (WHERE ar.late_minutes > 0)::numeric / COUNT(ar.id) FILTER (WHERE ar.status = 'COMPLETED')::numeric) * 100, 1)
                        ELSE 0 
                    END AS late_arrival_rate_pct,
                    COUNT(ac.id) AS total_corrected_records
                FROM public.attendance_records ar
                LEFT JOIN public.attendance_corrections ac ON ac.attendance_record_id = ar.id
                WHERE ar.station_id = v_export.station_id
                  AND (ar.check_in_time AT TIME ZONE v_timezone)::date BETWEEN v_from_date AND v_to_date
            LOOP
                v_row_count := v_row_count + 1;
                v_csv_rows := v_csv_rows || 
                    public.escape_csv_field(v_station_name) || ',' ||
                    v_from_date::text || ',' ||
                    v_to_date::text || ',' ||
                    v_rec.total_completed_shifts::text || ',' ||
                    v_rec.total_worked_minutes::text || ',' ||
                    v_rec.total_late_shifts::text || ',' ||
                    v_rec.late_arrival_rate_pct::text || '%,' ||
                    v_rec.total_corrected_records::text || E'\n';
            END LOOP;

        -- 3. STATION EMPLOYEE WORKED HOURS
        WHEN 'STATION_EMPLOYEE_WORKED_HOURS' THEN
            v_csv_header := 'Employee Name,Employee Code,Role,Status,Completed Shifts,Worked Minutes,Late Shifts,Corrections Count,Last Active';
            FOR v_rec IN 
                SELECT 
                    p.first_name || ' ' || p.last_name AS name,
                    COALESCE(sm.employee_code, 'N/A') AS employee_code,
                    sm.role::text AS role,
                    sm.status::text AS status,
                    COUNT(ar.id) FILTER (WHERE ar.status = 'COMPLETED') AS completed_shifts,
                    COALESCE(SUM(ar.worked_minutes) FILTER (WHERE ar.status = 'COMPLETED'), 0) AS worked_minutes,
                    COUNT(ar.id) FILTER (WHERE ar.late_minutes > 0) AS late_shifts,
                    COUNT(ac.id) AS corrected_records,
                    MAX(ar.check_in_time) AS last_seen
                FROM public.station_memberships sm
                JOIN public.profiles p ON sm.user_id = p.id
                LEFT JOIN public.attendance_records ar ON (
                    ar.station_membership_id = sm.id 
                    AND (ar.check_in_time AT TIME ZONE v_timezone)::date BETWEEN v_from_date AND v_to_date
                )
                LEFT JOIN public.attendance_corrections ac ON ac.attendance_record_id = ar.id
                WHERE sm.station_id = v_export.station_id
                GROUP BY p.id, p.first_name, p.last_name, sm.id, sm.employee_code, sm.role, sm.status
                ORDER BY p.last_name ASC, p.first_name ASC
            LOOP
                v_row_count := v_row_count + 1;
                v_csv_rows := v_csv_rows || 
                    public.escape_csv_field(v_rec.name) || ',' ||
                    public.escape_csv_field(v_rec.employee_code) || ',' ||
                    public.escape_csv_field(v_rec.role) || ',' ||
                    public.escape_csv_field(v_rec.status) || ',' ||
                    v_rec.completed_shifts::text || ',' ||
                    v_rec.worked_minutes::text || ',' ||
                    v_rec.late_shifts::text || ',' ||
                    v_rec.corrected_records::text || ',' ||
                    COALESCE(public.escape_csv_field(TO_CHAR(v_rec.last_seen AT TIME ZONE v_timezone, 'YYYY-MM-DD HH24:MI')), 'NEVER') || E'\n';
            END LOOP;


        -- 4. DAILY ATTENDANCE REPORT
        WHEN 'DAILY_ATTENDANCE_REPORT' THEN
            v_csv_header := 'Date,Employee Name,Employee Code,Shift Template,Scheduled Start,Scheduled End,Check-In,Check-Out,Worked Minutes,Status';
            FOR v_rec IN 
                SELECT 
                    wss.operational_date AS report_date,
                    p.first_name || ' ' || p.last_name AS employee_name,
                    sm.employee_code,
                    wss.shift_name_snapshot AS template_name,
                    TO_CHAR(wss.starts_at AT TIME ZONE v_timezone, 'HH24:MI') AS sched_in,
                    TO_CHAR(wss.ends_at AT TIME ZONE v_timezone, 'HH24:MI') AS sched_out,
                    COALESCE(TO_CHAR(ar.check_in_time AT TIME ZONE v_timezone, 'HH24:MI'), 'NO_SHOW') AS actual_in,
                    COALESCE(TO_CHAR(ar.check_out_time AT TIME ZONE v_timezone, 'HH24:MI'), 'OPEN') AS actual_out,
                    COALESCE(ar.worked_minutes, 0) AS minutes_worked,
                    COALESCE(ar.status::text, 'UNATTENDED') AS shift_status
                FROM public.work_schedule_shifts wss
                JOIN public.shift_assignments sa ON sa.work_schedule_shift_id = wss.id
                JOIN public.profiles p ON sa.user_id = p.id
                LEFT JOIN public.station_memberships sm ON (sm.station_id = v_export.station_id AND sm.user_id = sa.user_id)
                LEFT JOIN public.attendance_records ar ON (ar.station_id = v_export.station_id AND ar.employee_user_id = sa.user_id AND (ar.check_in_time AT TIME ZONE v_timezone)::date = v_from_date)
                WHERE wss.station_id = v_export.station_id
                  AND wss.operational_date = v_from_date
                ORDER BY wss.sort_order ASC, p.last_name ASC
            LOOP
                v_row_count := v_row_count + 1;
                v_csv_rows := v_csv_rows || 
                    v_rec.report_date::text || ',' ||
                    public.escape_csv_field(v_rec.employee_name) || ',' ||
                    public.escape_csv_field(v_rec.employee_code) || ',' ||
                    public.escape_csv_field(v_rec.template_name) || ',' ||
                    public.escape_csv_field(v_rec.sched_in) || ',' ||
                    public.escape_csv_field(v_rec.sched_out) || ',' ||
                    public.escape_csv_field(v_rec.actual_in) || ',' ||
                    public.escape_csv_field(v_rec.actual_out) || ',' ||
                    v_rec.minutes_worked::text || ',' ||
                    public.escape_csv_field(v_rec.shift_status) || E'\n';
            END LOOP;

        -- 5. ATTENDANCE CORRECTION LEDGER
        WHEN 'ATTENDANCE_CORRECTION_LEDGER' THEN
            v_csv_header := 'Correction Date,Employee Name,Employee Code,Original In,Original Out,Corrected In,Corrected Out,Delta Minutes,Reason,Corrected By';
            FOR v_rec IN 
                SELECT 
                    TO_CHAR(ac.created_at AT TIME ZONE v_timezone, 'YYYY-MM-DD HH24:MI') AS correction_time,
                    p_target.first_name || ' ' || p_target.last_name AS employee_name,
                    sm.employee_code,
                    TO_CHAR(ac.previous_check_in AT TIME ZONE v_timezone, 'YYYY-MM-DD HH24:MI') AS prev_in,
                    COALESCE(TO_CHAR(ac.previous_check_out AT TIME ZONE v_timezone, 'YYYY-MM-DD HH24:MI'), 'NULL') AS prev_out,
                    TO_CHAR(ac.corrected_check_in AT TIME ZONE v_timezone, 'YYYY-MM-DD HH24:MI') AS corr_in,
                    COALESCE(TO_CHAR(ac.corrected_check_out AT TIME ZONE v_timezone, 'YYYY-MM-DD HH24:MI'), 'NULL') AS corr_out,
                    (COALESCE(ar.worked_minutes, 0) - COALESCE(ac.previous_worked_minutes, 0)) AS delta_mins,
                    ac.reason,
                    p_actor.first_name || ' ' || p_actor.last_name AS actor_name
                FROM public.attendance_corrections ac
                JOIN public.attendance_records ar ON ac.attendance_record_id = ar.id
                JOIN public.profiles p_target ON ar.employee_user_id = p_target.id
                JOIN public.profiles p_actor ON ac.actor_id = p_actor.id
                LEFT JOIN public.station_memberships sm ON (sm.station_id = ar.station_id AND sm.user_id = ar.employee_user_id)
                WHERE ar.station_id = v_export.station_id
                  AND (ac.created_at AT TIME ZONE v_timezone)::date BETWEEN v_from_date AND v_to_date
                ORDER BY ac.created_at ASC, ac.id ASC
            LOOP
                v_row_count := v_row_count + 1;
                v_csv_rows := v_csv_rows || 
                    public.escape_csv_field(v_rec.correction_time) || ',' ||
                    public.escape_csv_field(v_rec.employee_name) || ',' ||
                    public.escape_csv_field(v_rec.employee_code) || ',' ||
                    public.escape_csv_field(v_rec.prev_in) || ',' ||
                    public.escape_csv_field(v_rec.prev_out) || ',' ||
                    public.escape_csv_field(v_rec.corr_in) || ',' ||
                    public.escape_csv_field(v_rec.corr_out) || ',' ||
                    v_rec.delta_mins::text || ',' ||
                    public.escape_csv_field(v_rec.reason) || ',' ||
                    public.escape_csv_field(v_rec.actor_name) || E'\n';
            END LOOP;

        -- 6. PUBLISHED SCHEDULE
        WHEN 'PUBLISHED_SCHEDULE' THEN
            v_csv_header := 'Shift Date,Shift Template,Start Time,End Time,Assigned Employee,Employee Code,Role,Status';
            FOR v_rec IN 
                SELECT 
                    wss.operational_date AS shift_date,
                    wss.shift_name_snapshot AS template_name,
                    TO_CHAR(wss.starts_at AT TIME ZONE v_timezone, 'HH24:MI') AS start_time,
                    TO_CHAR(wss.ends_at AT TIME ZONE v_timezone, 'HH24:MI') AS end_time,
                    p.first_name || ' ' || p.last_name AS employee_name,
                    sm.employee_code,
                    sm.role::text AS station_role,
                    ws.status::text AS schedule_status
                FROM public.work_schedule_shifts wss
                JOIN public.work_schedules ws ON wss.work_schedule_id = ws.id
                JOIN public.shift_assignments sa ON sa.work_schedule_shift_id = wss.id
                JOIN public.profiles p ON sa.user_id = p.id
                JOIN public.station_memberships sm ON (sm.station_id = wss.station_id AND sm.user_id = sa.user_id)
                WHERE wss.station_id = v_export.station_id
                  AND wss.operational_date BETWEEN v_from_date AND v_to_date
                ORDER BY wss.operational_date ASC, wss.sort_order ASC
            LOOP
                v_row_count := v_row_count + 1;
                v_csv_rows := v_csv_rows || 
                    v_rec.shift_date::text || ',' ||
                    public.escape_csv_field(v_rec.template_name) || ',' ||
                    v_rec.start_time::text || ',' ||
                    v_rec.end_time::text || ',' ||
                    public.escape_csv_field(v_rec.employee_name) || ',' ||
                    public.escape_csv_field(v_rec.employee_code) || ',' ||
                    public.escape_csv_field(v_rec.station_role) || ',' ||
                    public.escape_csv_field(v_rec.schedule_status) || E'\n';
            END LOOP;

        -- 7. EMPLOYEE DIRECTORY
        WHEN 'EMPLOYEE_DIRECTORY' THEN
            v_csv_header := 'Full Name,Station Role,Status,Employee Code,Phone,Preferred Language,Joined Date';
            FOR v_rec IN 
                SELECT 
                    p.first_name || ' ' || p.last_name AS full_name,
                    sm.role::text AS station_role,
                    sm.status::text AS member_status,
                    sm.employee_code,
                    COALESCE(p.phone, 'N/A') AS phone,
                    p.preferred_locale,
                    TO_CHAR(sm.joined_at AT TIME ZONE v_timezone, 'YYYY-MM-DD') AS joined_date
                FROM public.station_memberships sm
                JOIN public.profiles p ON sm.user_id = p.id
                WHERE sm.station_id = v_export.station_id
                ORDER BY sm.role ASC, p.last_name ASC
            LOOP
                v_row_count := v_row_count + 1;
                v_csv_rows := v_csv_rows || 
                    public.escape_csv_field(v_rec.full_name) || ',' ||
                    public.escape_csv_field(v_rec.station_role) || ',' ||
                    public.escape_csv_field(v_rec.member_status) || ',' ||
                    public.escape_csv_field(v_rec.employee_code) || ',' ||
                    public.escape_csv_field(v_rec.phone) || ',' ||
                    public.escape_csv_field(v_rec.preferred_locale) || ',' ||
                    v_rec.joined_date || E'\n';
            END LOOP;

        -- 8. AVAILABILITY OVERVIEW
        WHEN 'AVAILABILITY_OVERVIEW' THEN
            v_csv_header := 'Period Name,Start Date,End Date,Period Status,Employee Name,Submission Status,Total Slots Available,Submitted At';
            FOR v_rec IN 
                SELECT 
                    ap.name AS period_name,
                    ap.starts_at AS period_start,
                    ap.ends_at AS period_end,
                    ap.status::text AS period_status,
                    p.first_name || ' ' || p.last_name AS employee_name,
                    COALESCE(asub.status::text, 'NOT_SUBMITTED') AS sub_status,
                    COALESCE((SELECT COUNT(*) FROM public.availability_entries ae WHERE ae.submission_id = asub.id AND ae.is_available = true), 0) AS slots_count,
                    COALESCE(TO_CHAR(asub.submitted_at AT TIME ZONE v_timezone, 'YYYY-MM-DD HH24:MI'), 'N/A') AS sub_time
                FROM public.availability_periods ap
                CROSS JOIN public.station_memberships sm
                JOIN public.profiles p ON sm.user_id = p.id
                LEFT JOIN public.availability_submissions asub ON (asub.availability_period_id = ap.id AND asub.membership_id = sm.id)
                WHERE ap.station_id = v_export.station_id
                  AND sm.station_id = v_export.station_id
                  AND sm.status = 'ACTIVE'
                ORDER BY ap.starts_at DESC, p.last_name ASC
            LOOP
                v_row_count := v_row_count + 1;
                v_csv_rows := v_csv_rows || 
                    public.escape_csv_field(v_rec.period_name) || ',' ||
                    v_rec.period_start::text || ',' ||
                    v_rec.period_end::text || ',' ||
                    public.escape_csv_field(v_rec.period_status) || ',' ||
                    public.escape_csv_field(v_rec.employee_name) || ',' ||
                    public.escape_csv_field(v_rec.sub_status) || ',' ||
                    v_rec.slots_count::text || ',' ||
                    public.escape_csv_field(v_rec.sub_time) || E'\n';
            END LOOP;
    END CASE;

    -- Update row count on export record
    UPDATE public.report_exports 
    SET row_count = v_row_count,
        completed_at = timezone('utc'::text, now())
    WHERE id = p_export_id;

    RETURN jsonb_build_object(
        'success', true,
        'export_id', p_export_id,
        'export_type', v_export.export_type,
        'format', 'CSV',
        'row_count', v_row_count,
        'csv_content', E'\uFEFF' || v_csv_header || E'\n' || v_csv_rows
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 7. RPC: Admin Query Sanitized Audit Logs
CREATE OR REPLACE FUNCTION public.admin_query_audit_logs(
    p_station_id UUID,
    p_from TIMESTAMPTZ DEFAULT NULL,
    p_to TIMESTAMPTZ DEFAULT NULL,
    p_action_category TEXT DEFAULT NULL,
    p_actor_id UUID DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    id UUID,
    station_id UUID,
    actor_id UUID,
    actor_name TEXT,
    actor_email TEXT,
    action TEXT,
    target_type TEXT,
    target_id TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ,
    total_count BIGINT
) AS $$
DECLARE
    v_caller_id UUID;
    v_limit INTEGER;
    v_offset INTEGER;
    v_search_pattern TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL OR NOT public.is_station_admin(p_station_id, v_caller_id) THEN
        RAISE EXCEPTION 'Access denied: caller is not an administrator of this station'
            USING ERRCODE = '42501';
    END IF;

    v_limit := LEAST(GREATEST(p_limit, 1), 100);
    v_offset := GREATEST(p_offset, 0);

    IF p_search IS NOT NULL AND TRIM(p_search) != '' THEN
        v_search_pattern := '%' || regexp_replace(TRIM(p_search), '([%_\\])', '\\\1', 'g') || '%';
    END IF;

    RETURN QUERY
    WITH filtered_logs AS (
        SELECT 
            al.id,
            al.station_id,
            al.actor_id,
            COALESCE(p.first_name || ' ' || p.last_name, 'System/Unknown') AS actor_name,
            COALESCE(u.email, 'internal@system') AS actor_email,
            al.action,
            al.target_type,
            al.target_id,
            public.sanitize_audit_metadata(al.metadata) AS metadata,
            al.created_at
        FROM public.audit_logs al
        LEFT JOIN public.profiles p ON al.actor_id = p.id
        LEFT JOIN auth.users u ON al.actor_id = u.id
        WHERE al.station_id = p_station_id
          AND (p_from IS NULL OR al.created_at >= p_from)
          AND (p_to IS NULL OR al.created_at <= p_to)
          AND (p_actor_id IS NULL OR al.actor_id = p_actor_id)
          AND (
              p_action_category IS NULL 
              OR (p_action_category = 'MEMBERSHIP' AND al.action ~ 'MEMBERSHIP')
              OR (p_action_category = 'EMPLOYEE' AND al.action ~ 'EMPLOYEE')
              OR (p_action_category = 'SCHEDULE' AND al.action ~ 'SCHEDULE')
              OR (p_action_category = 'ATTENDANCE' AND al.action ~ 'ATTENDANCE')
              OR (p_action_category = 'KIOSK' AND al.action ~ 'KIOSK')
              OR (p_action_category = 'STATION' AND al.action ~ 'STATION')
              OR (p_action_category = 'EXPORT' AND al.action ~ 'EXPORT')
              OR (p_action_category = 'AVAILABILITY' AND al.action ~ 'AVAILABILITY')
          )
          AND (
              v_search_pattern IS NULL 
              OR al.action ILIKE v_search_pattern
              OR al.target_type ILIKE v_search_pattern
              OR COALESCE(al.target_id, '') ILIKE v_search_pattern
              OR COALESCE(p.first_name || ' ' || p.last_name, '') ILIKE v_search_pattern
              OR COALESCE(u.email, '') ILIKE v_search_pattern
          )
    )
    SELECT 
        fl.id,
        fl.station_id,
        fl.actor_id,
        fl.actor_name,
        fl.actor_email,
        fl.action,
        fl.target_type,
        fl.target_id,
        fl.metadata,
        fl.created_at,
        COUNT(*) OVER() AS total_count
    FROM filtered_logs fl
    ORDER BY fl.created_at DESC
    LIMIT v_limit
    OFFSET v_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 8. RPC: Station Settings Administration Expansion (Timezone Validation & Safe Deactivation)
CREATE OR REPLACE FUNCTION public.admin_update_station(
    p_station_id UUID,
    p_name TEXT,
    p_code TEXT,
    p_timezone TEXT,
    p_locale TEXT,
    p_week_start INTEGER,
    p_is_active BOOLEAN,
    p_late_grace_minutes INTEGER DEFAULT 5,
    p_check_in_early_minutes INTEGER DEFAULT 15,
    p_force_deactivate BOOLEAN DEFAULT false
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_clean_code TEXT;
    v_clean_timezone TEXT;
    v_active_sessions_count INTEGER := 0;
    v_open_periods_count INTEGER := 0;
    v_active_kiosks_count INTEGER := 0;
BEGIN
    v_caller_id := auth.uid();
    IF NOT public.is_station_admin(p_station_id, v_caller_id) THEN
        RAISE EXCEPTION 'Access denied: caller is not an administrator of this station'
            USING ERRCODE = '42501';
    END IF;

    -- Validate Name & Code
    IF LENGTH(TRIM(p_name)) < 2 THEN
        RAISE EXCEPTION 'Station name must be at least 2 characters' USING ERRCODE = '22000';
    END IF;

    v_clean_code := UPPER(TRIM(p_code));
    IF LENGTH(v_clean_code) < 2 THEN
        RAISE EXCEPTION 'Station code must be at least 2 characters' USING ERRCODE = '22000';
    END IF;

    -- Validate IANA Timezone against PostgreSQL system timezones
    v_clean_timezone := TRIM(p_timezone);
    IF NOT EXISTS (SELECT 1 FROM pg_timezone_names WHERE name = v_clean_timezone) THEN
        RAISE EXCEPTION 'Invalid IANA timezone: %', v_clean_timezone USING ERRCODE = '22000';
    END IF;

    -- Validate Grace Windows
    IF p_late_grace_minutes < 0 OR p_late_grace_minutes > 120 THEN
        RAISE EXCEPTION 'Late grace minutes must be between 0 and 120' USING ERRCODE = '22000';
    END IF;

    IF p_check_in_early_minutes < 0 OR p_check_in_early_minutes > 180 THEN
        RAISE EXCEPTION 'Check-in early minutes must be between 0 and 180' USING ERRCODE = '22000';
    END IF;

    -- Safe Station Deactivation Check
    IF p_is_active = false THEN
        -- Check open attendance sessions
        SELECT COUNT(*) INTO v_active_sessions_count
        FROM public.attendance_records
        WHERE station_id = p_station_id AND check_out_time IS NULL;

        -- Check open availability periods
        SELECT COUNT(*) INTO v_open_periods_count
        FROM public.availability_periods
        WHERE station_id = p_station_id AND status = 'OPEN';

        -- Check active kiosks
        SELECT COUNT(*) INTO v_active_kiosks_count
        FROM public.kiosk_devices
        WHERE station_id = p_station_id AND is_active = true;

        IF (v_active_sessions_count > 0 OR v_open_periods_count > 0 OR v_active_kiosks_count > 0) AND NOT p_force_deactivate THEN
            RAISE EXCEPTION 'Cannot deactivate station: station has active operations (open sessions: %, open periods: %, active kiosks: %)',
                v_active_sessions_count, v_open_periods_count, v_active_kiosks_count
                USING ERRCODE = 'P0082';
        END IF;
    END IF;

    -- Apply update
    UPDATE public.stations
    SET name = TRIM(p_name),
        code = v_clean_code,
        timezone = v_clean_timezone,
        locale = p_locale,
        week_start = p_week_start,
        is_active = p_is_active,
        late_grace_minutes = p_late_grace_minutes,
        check_in_early_minutes = p_check_in_early_minutes,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_station_id;

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        p_station_id,
        v_caller_id,
        'STATION_UPDATED',
        'station',
        p_station_id::text,
        jsonb_build_object(
            'name', p_name,
            'code', v_clean_code,
            'timezone', v_clean_timezone,
            'is_active', p_is_active,
            'late_grace_minutes', p_late_grace_minutes,
            'check_in_early_minutes', p_check_in_early_minutes
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'station_id', p_station_id,
        'is_active', p_is_active
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 9. RPC: Station System Health & Operational Telemetry
CREATE OR REPLACE FUNCTION public.get_station_system_health(p_station_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_total_kiosks INTEGER := 0;
    v_online_kiosks INTEGER := 0;
    v_offline_kiosks INTEGER := 0;
    v_exports_total_24h INTEGER := 0;
    v_exports_failed_24h INTEGER := 0;
    v_stale_open_sessions INTEGER := 0;
    v_failed_identity_attempts INTEGER := 0;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL OR NOT public.is_station_admin(p_station_id, v_caller_id) THEN
        RAISE EXCEPTION 'Access denied: caller is not an administrator of this station'
            USING ERRCODE = '42501';
    END IF;

    -- Kiosk Fleet Telemetry (heartbeat within 2 minutes = online)
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE is_active = true AND last_seen_at >= (v_now - INTERVAL '2 minutes')),
        COUNT(*) FILTER (WHERE is_active = true AND (last_seen_at IS NULL OR last_seen_at < (v_now - INTERVAL '2 minutes')))
    INTO v_total_kiosks, v_online_kiosks, v_offline_kiosks
    FROM public.kiosk_devices
    WHERE station_id = p_station_id;

    -- Export Pipeline 24h Telemetry
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE status = 'FAILED')
    INTO v_exports_total_24h, v_exports_failed_24h
    FROM public.report_exports
    WHERE station_id = p_station_id AND created_at >= (v_now - INTERVAL '24 hours');

    -- Stale Open Attendance Sessions (Open >= 16h)
    SELECT COUNT(*) INTO v_stale_open_sessions
    FROM public.attendance_records
    WHERE station_id = p_station_id
      AND check_out_time IS NULL
      AND check_in_time <= (v_now - INTERVAL '16 hours');

    -- Identity Verification Failures (aggregate count only)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'identity_verification_attempts') THEN
        SELECT COUNT(*) INTO v_failed_identity_attempts
        FROM public.identity_verification_attempts
        WHERE station_id = p_station_id 
          AND result IN ('NOT_VERIFIED', 'INCONCLUSIVE')
          AND created_at >= (v_now - INTERVAL '24 hours');
    END IF;


    RETURN jsonb_build_object(
        'station_id', p_station_id,
        'kiosks', jsonb_build_object(
            'total', v_total_kiosks,
            'online', v_online_kiosks,
            'offline', v_offline_kiosks
        ),
        'exports', jsonb_build_object(
            'total_24h', v_exports_total_24h,
            'failed_24h', v_exports_failed_24h
        ),
        'anomalies', jsonb_build_object(
            'stale_open_sessions', v_stale_open_sessions,
            'failed_identity_attempts', v_failed_identity_attempts
        ),
        'server_time', v_now
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 10. Data Lifecycle & Retention Cleanup Engine (Zero Historical Attendance Deletion)
CREATE OR REPLACE FUNCTION public.cleanup_expired_data()
RETURNS JSONB AS $$
DECLARE
    v_expired_exports_count INTEGER := 0;
    v_expired_challenges_count INTEGER := 0;
BEGIN
    -- 1. Mark expired report exports
    WITH updated AS (
        UPDATE public.report_exports
        SET status = 'EXPIRED'
        WHERE expires_at <= now()
          AND status != 'EXPIRED'
        RETURNING id
    )
    SELECT COUNT(*) INTO v_expired_exports_count FROM updated;

    -- 2. Cleanup expired QR kiosk challenges (older than 1 hour)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'kiosk_qr_challenges') THEN
        WITH deleted AS (
            DELETE FROM public.kiosk_qr_challenges
            WHERE expires_at <= (now() - INTERVAL '1 hour')
            RETURNING id
        )
        SELECT COUNT(*) INTO v_expired_challenges_count FROM deleted;
    END IF;

    -- ABSOLUTE ZERO DELETION of attendance_records, attendance_corrections, shifts, audit_logs!
    RETURN jsonb_build_object(
        'success', true,
        'expired_exports_marked', v_expired_exports_count,
        'expired_qr_challenges_cleared', v_expired_challenges_count,
        'timestamp', now()
    );

END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 11. Security Grants
REVOKE ALL ON FUNCTION public.escape_csv_field(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.escape_csv_field(TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.sanitize_audit_metadata(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sanitize_audit_metadata(JSONB) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.request_report_export(UUID, TEXT, TEXT, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_report_export(UUID, TEXT, TEXT, JSONB) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.generate_report_export_csv(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.generate_report_export_csv(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_query_audit_logs(UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT, UUID, TEXT, INTEGER, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_query_audit_logs(UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT, UUID, TEXT, INTEGER, INTEGER) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_update_station(UUID, TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN, INTEGER, INTEGER, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_station(UUID, TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN, INTEGER, INTEGER, BOOLEAN) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_station_system_health(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_station_system_health(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.cleanup_expired_data() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cleanup_expired_data() TO authenticated, service_role;
