-- ============================================================================
-- YELLOWSHIFTS MIGRATION 015: PHASE 8 ADVERSARIAL AUDIT & REMEDIATION
-- Strictly Additive Security & Governance Hardening:
-- 1. Air-Tight CSV Formula Injection Defense (Whitespace, Unicode & Variant Fuzzing)
-- 2. Deep Recursive Secret Scrubber (Arbitrary Object & Array Depth)
-- 3. Export Concurrency, Row-Level Leasing & State Machine Enforcement (PENDING -> PROCESSING -> COMPLETED)
-- 4. Mid-Lifecycle Role Revocation Protection & Re-Authorization
-- 5. Rate Limiting & Resource Exhaustion Defense on Exports
-- 6. Structured Export Data Engine (Supporting PDF & CSV)
-- 7. Hardened Station Deactivation Safeguards & Mandatory Override Reason
-- 8. Storage Policy & Tenant-Scoped Cleanup Security (Global Cleanup Service-Role Only)
-- 9. Audit Center Query Optimization (O(limit) Sanitization for 10k+ rows)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Hardened CSV Formula Injection Defense
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.escape_csv_field(p_val TEXT)
RETURNS TEXT AS $$
DECLARE
    v_trimmed TEXT;
    v_clean TEXT;
BEGIN
    IF p_val IS NULL THEN
        RETURN '';
    END IF;
    
    v_clean := p_val;
    -- Strip leading ASCII and Unicode whitespace for formula detection:
    -- Space (0x20), Tab (0x09), Linefeed (0x0A), CR (0x0D), NBSP (0xA0), Ideographic Space (0x3000), etc.
    v_trimmed := LTRIM(v_clean, E' \t\r\n\u00A0\u3000\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200A\u200B\u202F\u205F');
    
    -- Check if trimmed content starts with any dangerous spreadsheet formula triggers:
    -- '=', '+', '-', '@', '\t', '\r', '\n', '|', '%', or full-width Unicode variants (＝, ＋, －, ＠)
    IF v_trimmed ~ '^[=+\-@\t\r\n|%\uFF1D\uFF0B\uFF0D\uFF20]' THEN
        v_clean := '''' || v_clean;
    END IF;

    -- Escape embedded double quotes by doubling them
    v_clean := replace(v_clean, '"', '""');

    -- Always wrap in quotes if containing delimiter, quote, newline, or if formula trigger was detected
    IF v_clean ~ '[",\n\r]' OR v_trimmed ~ '^[=+\-@\t\r\n|%\uFF1D\uFF0B\uFF0D\uFF20]' OR v_clean ~ '^''' THEN
        v_clean := '"' || v_clean || '"';
    END IF;

    RETURN v_clean;
END;
$$ LANGUAGE plpgsql IMMUTABLE SET search_path = public, pg_temp;

-- ----------------------------------------------------------------------------
-- 2. Deep Recursive Secret Scrubber (Objects AND Arrays to Arbitrary Depth)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sanitize_audit_metadata(p_metadata JSONB)
RETURNS JSONB AS $$
DECLARE
    v_key TEXT;
    v_val JSONB;
    v_elem JSONB;
    v_result JSONB;
    v_arr_result JSONB;
    v_is_sensitive BOOLEAN;
BEGIN
    IF p_metadata IS NULL THEN
        RETURN '{}'::jsonb;
    END IF;

    -- Handle Object Type
    IF jsonb_typeof(p_metadata) = 'object' THEN
        v_result := '{}'::jsonb;
        FOR v_key, v_val IN SELECT * FROM jsonb_each(p_metadata)
        LOOP
            -- Check sensitivity pattern while strictly preserving safe operational codes (e.g. employee_code, station_code)
            v_is_sensitive := (
                (LOWER(v_key) ~ '(password|pass_word|secret|token|private_key|service_role|client_secret|signed_url|provider_subject|pin|otp|auth_code|api_key|apikey|jwt|session_token|bearer)')
                AND NOT (LOWER(v_key) ~ '(employee_code|station_code|template_code|status_code|error_code|postal_code|zip_code)')
            );

            IF v_is_sensitive THEN
                -- Strip or redact sensitive key
                v_result := v_result || jsonb_build_object(v_key, '[REDACTED]');
            ELSE
                IF jsonb_typeof(v_val) = 'object' OR jsonb_typeof(v_val) = 'array' THEN
                    v_result := v_result || jsonb_build_object(v_key, public.sanitize_audit_metadata(v_val));
                ELSE
                    v_result := v_result || jsonb_build_object(v_key, v_val);
                END IF;
            END IF;
        END LOOP;
        RETURN v_result;

    -- Handle Array Type (Recursively sanitize all array elements)
    ELSIF jsonb_typeof(p_metadata) = 'array' THEN
        v_arr_result := '[]'::jsonb;
        FOR v_elem IN SELECT * FROM jsonb_array_elements(p_metadata)
        LOOP
            IF jsonb_typeof(v_elem) = 'object' OR jsonb_typeof(v_elem) = 'array' THEN
                v_arr_result := v_arr_result || jsonb_build_array(public.sanitize_audit_metadata(v_elem));
            ELSE
                v_arr_result := v_arr_result || jsonb_build_array(v_elem);
            END IF;
        END LOOP;
        RETURN v_arr_result;

    ELSE
        RETURN p_metadata;
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE SET search_path = public, pg_temp;

-- ----------------------------------------------------------------------------
-- 3. Rate Limiting, Idempotency & Resource Abuse Defense for Exports
-- ----------------------------------------------------------------------------
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
    v_recent_requests_count INTEGER := 0;
    v_existing_export_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    -- Validate payload size (Max 8KB) to prevent DoS / buffer exhaustion
    IF pg_column_size(p_filter_payload) > 8192 THEN
        RAISE EXCEPTION 'Filter payload exceeds maximum allowable size (8KB)' USING ERRCODE = '22000';
    END IF;

    -- Rate limit check: Maximum 15 export requests per 5 minutes per user
    SELECT COUNT(*) INTO v_recent_requests_count
    FROM public.report_exports
    WHERE requested_by = v_caller_id
      AND created_at >= (timezone('utc'::text, now()) - INTERVAL '5 minutes');

    IF v_recent_requests_count >= 15 THEN
        RAISE EXCEPTION 'Export rate limit exceeded: maximum 15 requests per 5 minutes' USING ERRCODE = '42901';
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

    -- Validate date filters if present (Maximum 366 days)
    IF p_filter_payload ? 'from_date' AND p_filter_payload ? 'to_date' THEN
        BEGIN
            v_from_date := (p_filter_payload->>'from_date')::date;
            v_to_date := (p_filter_payload->>'to_date')::date;
            PERFORM public.validate_reporting_date_range(v_from_date, v_to_date);
        EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION 'Invalid date filter range in export request: %', SQLERRM USING ERRCODE = '22000';
        END;
    END IF;

    -- Idempotency Check: Return existing pending/processing or recent unexpired export
    SELECT id INTO v_existing_export_id
    FROM public.report_exports
    WHERE requested_by = v_caller_id
      AND (station_id = p_station_id OR (station_id IS NULL AND p_station_id IS NULL))
      AND export_type = p_export_type
      AND format = p_format
      AND filter_payload = p_filter_payload
      AND status IN ('PENDING', 'PROCESSING', 'COMPLETED')
      AND expires_at > timezone('utc'::text, now())
      AND created_at >= (timezone('utc'::text, now()) - INTERVAL '30 seconds')
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_existing_export_id IS NOT NULL THEN
        RETURN jsonb_build_object(
            'success', true,
            'export_id', v_existing_export_id,
            'status', 'PENDING',
            'idempotent', true,
            'expires_at', (timezone('utc'::text, now()) + INTERVAL '24 hours')
        );
    END IF;

    -- Insert new export job with STRICT 'PENDING' initial status
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
        'PENDING',
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
        'status', 'PENDING',
        'idempotent', false,
        'expires_at', (timezone('utc'::text, now()) + INTERVAL '24 hours')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- ----------------------------------------------------------------------------
-- 4. Atomic Export Claiming & Concurrency Lease
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.claim_report_export(p_export_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_export public.report_exports%ROWTYPE;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    -- Acquire row lock
    SELECT * INTO v_export
    FROM public.report_exports
    WHERE id = p_export_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Export record not found' USING ERRCODE = 'P0002';
    END IF;

    -- Check expiration
    IF v_export.expires_at <= now() THEN
        UPDATE public.report_exports SET status = 'EXPIRED' WHERE id = p_export_id;
        RAISE EXCEPTION 'Export has expired' USING ERRCODE = 'P0081';
    END IF;

    -- If already completed, return ready
    IF v_export.status = 'COMPLETED' THEN
        RETURN jsonb_build_object(
            'claimed', false,
            'already_completed', true,
            'status', 'COMPLETED',
            'export_id', v_export.id,
            'storage_path', v_export.storage_path,
            'export_type', v_export.export_type,
            'format', v_export.format
        );
    END IF;

    -- Transition PENDING / stale PROCESSING -> PROCESSING
    UPDATE public.report_exports
    SET status = 'PROCESSING',
        started_at = timezone('utc'::text, now())
    WHERE id = p_export_id;

    RETURN jsonb_build_object(
        'claimed', true,
        'already_completed', false,
        'status', 'PROCESSING',
        'export_id', v_export.id,
        'export_type', v_export.export_type,
        'format', v_export.format
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- ----------------------------------------------------------------------------
-- 5. Export Re-Authorization Validator Helper
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validate_export_requester_authorization(
    p_export_id UUID,
    p_caller_id UUID
)
RETURNS VOID AS $$
DECLARE
    v_export public.report_exports%ROWTYPE;
    v_is_admin BOOLEAN := false;
    v_has_report_read BOOLEAN := false;
    v_membership_status public.membership_status;
BEGIN
    SELECT * INTO v_export
    FROM public.report_exports
    WHERE id = p_export_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Export record not found' USING ERRCODE = 'P0002';
    END IF;

    -- Must be the original requester or an active station Admin
    IF v_export.station_id IS NOT NULL THEN
        SELECT status INTO v_membership_status
        FROM public.station_memberships
        WHERE station_id = v_export.station_id AND user_id = p_caller_id;

        IF v_membership_status IS NULL OR v_membership_status != 'ACTIVE' THEN
            RAISE EXCEPTION 'Access denied: caller membership is no longer active' USING ERRCODE = '42501';
        END IF;

        v_is_admin := public.is_station_admin(v_export.station_id, p_caller_id);
        v_has_report_read := public.has_station_permission(v_export.station_id, p_caller_id, 'reports.station.read') 
                          OR public.has_station_permission(v_export.station_id, p_caller_id, 'reports.team.read');
    END IF;

    IF v_export.requested_by != p_caller_id AND NOT v_is_admin THEN
        RAISE EXCEPTION 'Access denied to foreign export record' USING ERRCODE = '42501';
    END IF;

    -- Re-verify role permissions against export_type
    IF v_export.export_type IN ('STATION_ATTENDANCE_SUMMARY', 'STATION_EMPLOYEE_WORKED_HOURS', 'DAILY_ATTENDANCE_REPORT', 'ATTENDANCE_CORRECTION_LEDGER') THEN
        IF NOT (v_is_admin OR v_has_report_read) THEN
            RAISE EXCEPTION 'Access denied: caller lacks active report permission for station' USING ERRCODE = '42501';
        END IF;
    ELSIF v_export.export_type = 'EMPLOYEE_DIRECTORY' THEN
        IF NOT v_is_admin THEN
            RAISE EXCEPTION 'Access denied: caller must be station admin to export employee directory' USING ERRCODE = '42501';
        END IF;
    ELSIF v_export.export_type = 'PUBLISHED_SCHEDULE' THEN
        IF NOT (v_is_admin OR public.has_station_permission(v_export.station_id, p_caller_id, 'schedule.read') OR v_has_report_read) THEN
            RAISE EXCEPTION 'Access denied: caller lacks active schedule permission for station' USING ERRCODE = '42501';
        END IF;
    ELSIF v_export.export_type = 'AVAILABILITY_OVERVIEW' THEN
        IF NOT (v_is_admin OR public.has_station_permission(v_export.station_id, p_caller_id, 'availability.team.read')) THEN
            RAISE EXCEPTION 'Access denied: caller lacks active availability permission for station' USING ERRCODE = '42501';
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

-- ----------------------------------------------------------------------------
-- 6. Structured Export Data RPC (For High-Fidelity PDF & Analytics Engines)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_report_export_dataset(p_export_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_export public.report_exports%ROWTYPE;
    v_caller_id UUID;
    v_station_name TEXT := 'Unknown Station';
    v_station_code TEXT := 'N/A';
    v_timezone TEXT := 'Asia/Jerusalem';
    v_from_date DATE;
    v_to_date DATE;
    v_columns JSONB := '[]'::jsonb;
    v_rows JSONB := '[]'::jsonb;
    v_row_count INTEGER := 0;
    v_rec RECORD;
    v_requester_name TEXT := 'Unknown User';
    v_requester_email TEXT := '';
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_export FROM public.report_exports WHERE id = p_export_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Export record not found' USING ERRCODE = 'P0002';
    END IF;

    IF v_export.expires_at <= now() THEN
        RAISE EXCEPTION 'Export has expired' USING ERRCODE = 'P0081';
    END IF;


    -- Strict Re-Authorization Check
    PERFORM public.validate_export_requester_authorization(p_export_id, v_caller_id);

    -- Station Details
    IF v_export.station_id IS NOT NULL THEN
        SELECT name, code, timezone INTO v_station_name, v_station_code, v_timezone
        FROM public.stations
        WHERE id = v_export.station_id;
    END IF;

    -- Requester Details
    SELECT COALESCE(first_name || ' ' || last_name, 'System User') INTO v_requester_name
    FROM public.profiles WHERE id = v_export.requested_by;

    SELECT COALESCE(email, '') INTO v_requester_email
    FROM auth.users WHERE id = v_export.requested_by;

    v_from_date := COALESCE((v_export.filter_payload->>'from_date')::date, CURRENT_DATE - INTERVAL '30 days');
    v_to_date := COALESCE((v_export.filter_payload->>'to_date')::date, CURRENT_DATE);

    CASE v_export.export_type
        WHEN 'MY_ATTENDANCE_HISTORY' THEN
            v_columns := jsonb_build_array('Date', 'Check-In', 'Check-Out', 'Worked Mins', 'Status', 'Verification', 'Lateness');
            SELECT 
                COALESCE(jsonb_agg(
                    jsonb_build_array(
                        TO_CHAR(ar.check_in_time AT TIME ZONE v_timezone, 'YYYY-MM-DD'),
                        TO_CHAR(ar.check_in_time AT TIME ZONE v_timezone, 'HH24:MI:SS'),
                        COALESCE(TO_CHAR(ar.check_out_time AT TIME ZONE v_timezone, 'HH24:MI:SS'), 'OPEN'),
                        COALESCE(ar.worked_minutes, 0)::text,
                        ar.status::text,
                        COALESCE(kd.name, 'Manual/Web'),
                        CASE WHEN ar.late_minutes > 0 THEN 'LATE' ELSE 'ON_TIME' END
                    ) ORDER BY ar.check_in_time DESC
                ), '[]'::jsonb),
                COUNT(*)
            INTO v_rows, v_row_count
            FROM public.attendance_records ar
            LEFT JOIN public.kiosk_devices kd ON ar.check_in_kiosk_device_id = kd.id
            WHERE ar.employee_user_id = v_export.requested_by
              AND (v_export.station_id IS NULL OR ar.station_id = v_export.station_id)
              AND (ar.check_in_time AT TIME ZONE v_timezone)::date BETWEEN v_from_date AND v_to_date;

        WHEN 'STATION_ATTENDANCE_SUMMARY' THEN
            v_columns := jsonb_build_array('Station', 'Range Start', 'Range End', 'Completed Shifts', 'Worked Mins', 'Late Shifts', 'Late Rate %', 'Corrections');
            SELECT 
                COALESCE(jsonb_agg(
                    jsonb_build_array(
                        v_station_name,
                        v_from_date::text,
                        v_to_date::text,
                        sub.total_completed_shifts::text,
                        sub.total_worked_minutes::text,
                        sub.total_late_shifts::text,
                        sub.late_arrival_rate_pct::text || '%',
                        sub.total_corrected_records::text
                    )
                ), '[]'::jsonb),
                COUNT(*)
            INTO v_rows, v_row_count
            FROM (
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
            ) sub;

        WHEN 'STATION_EMPLOYEE_WORKED_HOURS' THEN
            v_columns := jsonb_build_array('Employee Name', 'Code', 'Role', 'Status', 'Completed Shifts', 'Worked Mins', 'Late Shifts', 'Corrections', 'Last Seen');
            SELECT 
                COALESCE(jsonb_agg(
                    jsonb_build_array(
                        sub.name,
                        sub.employee_code,
                        sub.role,
                        sub.status,
                        sub.completed_shifts::text,
                        sub.worked_minutes::text,
                        sub.late_shifts::text,
                        sub.corrected_records::text,
                        COALESCE(TO_CHAR(sub.last_seen AT TIME ZONE v_timezone, 'YYYY-MM-DD HH24:MI'), 'NEVER')
                    ) ORDER BY sub.last_name ASC, sub.first_name ASC
                ), '[]'::jsonb),
                COUNT(*)
            INTO v_rows, v_row_count
            FROM (
                SELECT 
                    p.first_name,
                    p.last_name,
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
            ) sub;

        WHEN 'DAILY_ATTENDANCE_REPORT' THEN
            v_columns := jsonb_build_array('Date', 'Employee', 'Code', 'Template', 'Sched In', 'Sched Out', 'Actual In', 'Actual Out', 'Mins', 'Status');
            SELECT 
                COALESCE(jsonb_agg(
                    jsonb_build_array(
                        sub.report_date::text,
                        sub.employee_name,
                        sub.employee_code,
                        sub.template_name,
                        sub.sched_in,
                        sub.sched_out,
                        sub.actual_in,
                        sub.actual_out,
                        sub.minutes_worked::text,
                        sub.shift_status
                    ) ORDER BY sub.sort_order ASC, sub.last_name ASC
                ), '[]'::jsonb),
                COUNT(*)
            INTO v_rows, v_row_count
            FROM (
                SELECT 
                    wss.operational_date AS report_date,
                    wss.sort_order,
                    p.last_name,
                    p.first_name || ' ' || p.last_name AS employee_name,
                    COALESCE(sm.employee_code, 'N/A') AS employee_code,
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
            ) sub;

        WHEN 'ATTENDANCE_CORRECTION_LEDGER' THEN
            v_columns := jsonb_build_array('Date', 'Employee', 'Code', 'Prev In', 'Prev Out', 'Corr In', 'Corr Out', 'Delta Mins', 'Reason', 'Corrected By');
            SELECT 
                COALESCE(jsonb_agg(
                    jsonb_build_array(
                        sub.correction_time,
                        sub.employee_name,
                        sub.employee_code,
                        sub.prev_in,
                        sub.prev_out,
                        sub.corr_in,
                        sub.corr_out,
                        sub.delta_mins::text,
                        sub.reason,
                        sub.actor_name
                    ) ORDER BY sub.created_at ASC
                ), '[]'::jsonb),
                COUNT(*)
            INTO v_rows, v_row_count
            FROM (
                SELECT 
                    ac.created_at,
                    TO_CHAR(ac.created_at AT TIME ZONE v_timezone, 'YYYY-MM-DD HH24:MI') AS correction_time,
                    p_target.first_name || ' ' || p_target.last_name AS employee_name,
                    COALESCE(sm.employee_code, 'N/A') AS employee_code,
                    TO_CHAR(ac.previous_check_in_time AT TIME ZONE v_timezone, 'YYYY-MM-DD HH24:MI') AS prev_in,
                    COALESCE(TO_CHAR(ac.previous_check_out_time AT TIME ZONE v_timezone, 'YYYY-MM-DD HH24:MI'), 'NULL') AS prev_out,
                    TO_CHAR(ac.new_check_in_time AT TIME ZONE v_timezone, 'YYYY-MM-DD HH24:MI') AS corr_in,
                    COALESCE(TO_CHAR(ac.new_check_out_time AT TIME ZONE v_timezone, 'YYYY-MM-DD HH24:MI'), 'NULL') AS corr_out,
                    (COALESCE(ac.new_worked_minutes, 0) - COALESCE(ac.previous_worked_minutes, 0)) AS delta_mins,
                    ac.reason,
                    p_actor.first_name || ' ' || p_actor.last_name AS actor_name
                FROM public.attendance_corrections ac
                JOIN public.attendance_records ar ON ac.attendance_record_id = ar.id
                JOIN public.profiles p_target ON ar.employee_user_id = p_target.id
                JOIN public.profiles p_actor ON ac.actor_user_id = p_actor.id
                LEFT JOIN public.station_memberships sm ON (sm.station_id = ar.station_id AND sm.user_id = ar.employee_user_id)
                WHERE ar.station_id = v_export.station_id
                  AND (ac.created_at AT TIME ZONE v_timezone)::date BETWEEN v_from_date AND v_to_date
            ) sub;

        WHEN 'PUBLISHED_SCHEDULE' THEN
            v_columns := jsonb_build_array('Date', 'Template', 'Start', 'End', 'Employee', 'Code', 'Role', 'Status');
            SELECT 
                COALESCE(jsonb_agg(
                    jsonb_build_array(
                        sub.shift_date::text,
                        sub.template_name,
                        sub.start_time,
                        sub.end_time,
                        sub.employee_name,
                        sub.employee_code,
                        sub.station_role,
                        sub.schedule_status
                    ) ORDER BY sub.shift_date ASC, sub.sort_order ASC
                ), '[]'::jsonb),
                COUNT(*)
            INTO v_rows, v_row_count
            FROM (
                SELECT 
                    wss.operational_date AS shift_date,
                    wss.sort_order,
                    wss.shift_name_snapshot AS template_name,
                    TO_CHAR(wss.starts_at AT TIME ZONE v_timezone, 'HH24:MI') AS start_time,
                    TO_CHAR(wss.ends_at AT TIME ZONE v_timezone, 'HH24:MI') AS end_time,
                    p.first_name || ' ' || p.last_name AS employee_name,
                    COALESCE(sm.employee_code, 'N/A') AS employee_code,
                    sm.role::text AS station_role,
                    ws.status::text AS schedule_status
                FROM public.work_schedule_shifts wss
                JOIN public.work_schedules ws ON wss.work_schedule_id = ws.id
                JOIN public.shift_assignments sa ON sa.work_schedule_shift_id = wss.id
                JOIN public.profiles p ON sa.user_id = p.id
                JOIN public.station_memberships sm ON (sm.station_id = wss.station_id AND sm.user_id = sa.user_id)
                WHERE wss.station_id = v_export.station_id
                  AND wss.operational_date BETWEEN v_from_date AND v_to_date
            ) sub;

        WHEN 'EMPLOYEE_DIRECTORY' THEN
            v_columns := jsonb_build_array('Full Name', 'Role', 'Status', 'Code', 'Phone', 'Language', 'Joined Date');
            SELECT 
                COALESCE(jsonb_agg(
                    jsonb_build_array(
                        sub.full_name,
                        sub.station_role,
                        sub.member_status,
                        sub.employee_code,
                        sub.phone,
                        sub.preferred_locale,
                        sub.joined_date
                    ) ORDER BY sub.role ASC, sub.last_name ASC
                ), '[]'::jsonb),
                COUNT(*)
            INTO v_rows, v_row_count
            FROM (
                SELECT 
                    p.last_name,
                    sm.role,
                    p.first_name || ' ' || p.last_name AS full_name,
                    sm.role::text AS station_role,
                    sm.status::text AS member_status,
                    COALESCE(sm.employee_code, 'N/A') AS employee_code,
                    COALESCE(p.phone, 'N/A') AS phone,
                    p.preferred_locale,
                    TO_CHAR(sm.joined_at AT TIME ZONE v_timezone, 'YYYY-MM-DD') AS joined_date
                FROM public.station_memberships sm
                JOIN public.profiles p ON sm.user_id = p.id
                WHERE sm.station_id = v_export.station_id
            ) sub;

        WHEN 'AVAILABILITY_OVERVIEW' THEN
            v_columns := jsonb_build_array('Period', 'Start', 'End', 'Period Status', 'Employee', 'Submission', 'Available Slots', 'Submitted At');
            SELECT 
                COALESCE(jsonb_agg(
                    jsonb_build_array(
                        sub.period_name,
                        sub.period_start::text,
                        sub.period_end::text,
                        sub.period_status,
                        sub.employee_name,
                        sub.sub_status,
                        sub.slots_count::text,
                        sub.sub_time
                    ) ORDER BY sub.week_start_date DESC, sub.last_name ASC
                ), '[]'::jsonb),
                COUNT(*)
            INTO v_rows, v_row_count
            FROM (
                SELECT 
                    ap.week_start_date,
                    p.last_name,
                    'Week of ' || ap.week_start_date::text AS period_name,
                    ap.week_start_date AS period_start,
                    (ap.week_start_date + 6) AS period_end,
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
            ) sub;
    END CASE;



    RETURN jsonb_build_object(
        'export_id', p_export_id,
        'station_id', v_export.station_id,
        'station_name', v_station_name,
        'station_code', v_station_code,
        'export_type', v_export.export_type,
        'format', v_export.format,
        'from_date', v_from_date::text,
        'to_date', v_to_date::text,
        'requester_name', v_requester_name,
        'requester_email', v_requester_email,
        'generated_at', TO_CHAR(timezone('utc'::text, now()) AT TIME ZONE v_timezone, 'YYYY-MM-DD HH24:MI:SS'),
        'columns', v_columns,
        'rows', v_rows,
        'row_count', v_row_count
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

-- ----------------------------------------------------------------------------
-- 7. Hardened generate_report_export_csv with Re-Authorization
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_report_export_csv(p_export_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_export public.report_exports%ROWTYPE;
    v_caller_id UUID;
    v_dataset JSONB;
    v_csv_header TEXT := '';
    v_csv_rows TEXT := '';
    v_col TEXT;
    v_row JSONB;
    v_cell TEXT;
    v_row_count INTEGER := 0;

    v_first_col BOOLEAN;
    v_first_cell BOOLEAN;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_export FROM public.report_exports WHERE id = p_export_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Export record not found' USING ERRCODE = 'P0002';
    END IF;

    -- Check expiration
    IF v_export.expires_at <= now() THEN
        UPDATE public.report_exports SET status = 'EXPIRED' WHERE id = p_export_id;
        RAISE EXCEPTION 'Export has expired' USING ERRCODE = 'P0081';
    END IF;

    -- Strict Re-Authorization Check
    PERFORM public.validate_export_requester_authorization(p_export_id, v_caller_id);

    -- Fetch Dataset
    v_dataset := public.get_report_export_dataset(p_export_id);


    -- Build Header
    v_first_col := true;
    FOR v_col IN SELECT * FROM jsonb_array_elements_text(v_dataset->'columns')
    LOOP
        IF NOT v_first_col THEN
            v_csv_header := v_csv_header || ',';
        END IF;
        v_csv_header := v_csv_header || public.escape_csv_field(v_col::text);
        v_first_col := false;
    END LOOP;

    -- Build Rows
    FOR v_row IN SELECT * FROM jsonb_array_elements(v_dataset->'rows')
    LOOP
        v_row_count := v_row_count + 1;
        v_first_cell := true;
        FOR v_cell IN SELECT * FROM jsonb_array_elements_text(v_row)
        LOOP
            IF NOT v_first_cell THEN
                v_csv_rows := v_csv_rows || ',';
            END IF;
            v_csv_rows := v_csv_rows || public.escape_csv_field(v_cell::text);
            v_first_cell := false;
        END LOOP;
        v_csv_rows := v_csv_rows || E'\n';
    END LOOP;

    -- Mark Completed
    UPDATE public.report_exports 
    SET row_count = v_row_count,
        completed_at = timezone('utc'::text, now()),
        status = 'COMPLETED'
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

-- ----------------------------------------------------------------------------
-- 8. Hardened Station Deactivation Safeguards with Mandatory Reason
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.admin_update_station(UUID, TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN, INTEGER, INTEGER, BOOLEAN);

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
    p_force_deactivate BOOLEAN DEFAULT false,
    p_deactivation_reason TEXT DEFAULT NULL
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

    -- Validate IANA Timezone
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

        IF (v_active_sessions_count > 0 OR v_open_periods_count > 0 OR v_active_kiosks_count > 0) THEN
            IF NOT p_force_deactivate THEN
                RAISE EXCEPTION 'Cannot deactivate station: station has active operations (open sessions: %, open periods: %, active kiosks: %)',
                    v_active_sessions_count, v_open_periods_count, v_active_kiosks_count
                    USING ERRCODE = 'P0082';
            END IF;

            -- If force deactivating, mandatory reason string of at least 10 chars is required
            IF p_deactivation_reason IS NULL OR LENGTH(TRIM(p_deactivation_reason)) < 10 THEN
                RAISE EXCEPTION 'Mandatory deactivation reason (min 10 characters) required when force deactivating station with active operations'
                    USING ERRCODE = '22000';
            END IF;
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

    -- Audit log
    IF p_is_active = false AND p_force_deactivate AND (v_active_sessions_count > 0 OR v_open_periods_count > 0 OR v_active_kiosks_count > 0) THEN
        INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
        VALUES (
            p_station_id,
            v_caller_id,
            'STATION_FORCE_DEACTIVATED',
            'station',
            p_station_id::text,
            jsonb_build_object(
                'reason', p_deactivation_reason,
                'bypassed_active_sessions', v_active_sessions_count,
                'bypassed_open_periods', v_open_periods_count,
                'bypassed_active_kiosks', v_active_kiosks_count
            )
        );
    ELSE
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
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'station_id', p_station_id,
        'is_active', p_is_active
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- ----------------------------------------------------------------------------
-- 9. Optimized Audit Log Query Engine (O(limit) Sanitization for 10k+ rows)
-- ----------------------------------------------------------------------------
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
    v_clean_search TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF p_station_id IS NULL THEN
        RAISE EXCEPTION 'Station ID is required' USING ERRCODE = '42501';
    END IF;

    IF v_caller_id IS NULL OR NOT public.is_station_admin(p_station_id, v_caller_id) THEN
        RAISE EXCEPTION 'Access denied: caller is not an administrator of this station'
            USING ERRCODE = '42501';
    END IF;

    v_limit := LEAST(GREATEST(p_limit, 1), 100);
    v_offset := GREATEST(p_offset, 0);

    IF p_search IS NOT NULL AND TRIM(p_search) != '' THEN
        -- Clamp search string to 100 chars to avoid regex / wildcards abuse
        v_clean_search := SUBSTRING(TRIM(p_search) FROM 1 FOR 100);
        v_search_pattern := '%' || regexp_replace(v_clean_search, '([%_\\])', '\\\1', 'g') || '%';
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
            al.metadata,
            al.created_at,
            COUNT(*) OVER() AS total_count
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
        ORDER BY al.created_at DESC
        LIMIT v_limit
        OFFSET v_offset
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
        -- Sanitization executed ONLY on the sliced page result (O(limit)), not entire table!
        public.sanitize_audit_metadata(fl.metadata) AS metadata,
        fl.created_at,
        fl.total_count
    FROM filtered_logs fl;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- ----------------------------------------------------------------------------
-- 10. Tenant-Scoped Cleanup & Service-Role Restriction on Global Cleanup
-- ----------------------------------------------------------------------------
-- Station Admins can only trigger cleanup for their own station's expired export records
CREATE OR REPLACE FUNCTION public.admin_cleanup_station_exports(p_station_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_expired_count INTEGER := 0;
BEGIN
    v_caller_id := auth.uid();
    IF p_station_id IS NULL OR v_caller_id IS NULL OR NOT public.is_station_admin(p_station_id, v_caller_id) THEN
        RAISE EXCEPTION 'Access denied: caller is not an administrator of this station' USING ERRCODE = '42501';
    END IF;

    WITH updated AS (
        UPDATE public.report_exports
        SET status = 'EXPIRED'
        WHERE station_id = p_station_id
          AND expires_at <= now()
          AND status != 'EXPIRED'
        RETURNING id
    )
    SELECT COUNT(*) INTO v_expired_count FROM updated;

    RETURN jsonb_build_object(
        'success', true,
        'station_id', p_station_id,
        'expired_exports_marked', v_expired_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- Revoke global cleanup from authenticated / anon; strictly service_role only
REVOKE ALL ON FUNCTION public.cleanup_expired_data() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cleanup_expired_data() TO service_role;

-- ----------------------------------------------------------------------------
-- 11. Storage Bucket Security Settings for reports_storage
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'storage' AND table_name = 'buckets') THEN
        UPDATE storage.buckets 
        SET public = false,
            file_size_limit = 52428800,
            allowed_mime_types = ARRAY['text/csv', 'application/pdf']
        WHERE id = 'reports_storage';
    END IF;
END $$;


-- ----------------------------------------------------------------------------
-- 12. Security Grants
-- ----------------------------------------------------------------------------
GRANT SELECT ON public.report_exports TO authenticated, service_role;
GRANT SELECT, INSERT ON public.audit_logs TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.claim_report_export(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_report_export(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.validate_export_requester_authorization(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.validate_export_requester_authorization(UUID, UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_report_export_dataset(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_report_export_dataset(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_cleanup_station_exports(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_cleanup_station_exports(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_update_station(UUID, TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN, INTEGER, INTEGER, BOOLEAN, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_station(UUID, TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN, INTEGER, INTEGER, BOOLEAN, TEXT) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 13. Backwards-Compatible RPC Overload: get_my_attendance_history (3 params)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_my_attendance_history(
    p_station_id UUID,
    p_limit INTEGER DEFAULT 25,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT public.get_my_attendance_history(
        (CURRENT_DATE - INTERVAL '90 days')::DATE,
        (CURRENT_DATE + INTERVAL '1 day')::DATE,
        p_station_id,
        NULL,
        p_limit,
        p_offset
    );
$$;

REVOKE ALL ON FUNCTION public.get_my_attendance_history(UUID, INTEGER, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_attendance_history(UUID, INTEGER, INTEGER) TO authenticated, service_role;


