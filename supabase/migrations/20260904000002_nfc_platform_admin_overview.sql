-- Migration: 20260904000002_nfc_platform_admin_overview.sql
-- Description: Align platform administration and system health RPCs with NFC-only attendance architecture

-- 1. Platform Overview RPC (NFC-aligned)
CREATE OR REPLACE FUNCTION public.platform_get_overview()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_now TIMESTAMPTZ := now();
    v_total_stations INTEGER := 0;
    v_active_stations INTEGER := 0;
    v_inactive_stations INTEGER := 0;
    v_active_memberships INTEGER := 0;
    v_admin_count INTEGER := 0;
    v_shift_manager_count INTEGER := 0;
    v_nfc_tags_total INTEGER := 0;
    v_nfc_tags_active INTEGER := 0;
    v_stale_sessions INTEGER := 0;
    v_failed_exports INTEGER := 0;
    v_pending_notifications INTEGER := 0;
    v_alert_count INTEGER := 0;
BEGIN
    PERFORM public.require_platform_admin();

    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE is_active),
        COUNT(*) FILTER (WHERE NOT is_active)
    INTO v_total_stations, v_active_stations, v_inactive_stations
    FROM public.stations;

    SELECT
        COUNT(*) FILTER (WHERE status = 'ACTIVE'),
        COUNT(*) FILTER (WHERE status = 'ACTIVE' AND role = 'ADMIN'),
        COUNT(*) FILTER (WHERE status = 'ACTIVE' AND role = 'SHIFT_MANAGER')
    INTO v_active_memberships, v_admin_count, v_shift_manager_count
    FROM public.station_memberships;

    SELECT
        COALESCE(COUNT(*), 0),
        COALESCE(COUNT(*) FILTER (WHERE is_active = true), 0)
    INTO v_nfc_tags_total, v_nfc_tags_active
    FROM public.station_nfc_tags;

    SELECT COALESCE(COUNT(*), 0) INTO v_stale_sessions
    FROM public.attendance_records
    WHERE check_out_time IS NULL
      AND check_in_time <= (v_now - INTERVAL '16 hours');

    SELECT COALESCE(COUNT(*), 0) INTO v_failed_exports
    FROM public.report_exports
    WHERE status = 'FAILED'
      AND created_at >= (v_now - INTERVAL '24 hours');

    SELECT COALESCE(COUNT(*), 0) INTO v_pending_notifications
    FROM public.notification_delivery_jobs
    WHERE status = 'PENDING';

    v_alert_count :=
        (CASE WHEN v_stale_sessions > 0 THEN 1 ELSE 0 END) +
        (CASE WHEN v_failed_exports > 0 THEN 1 ELSE 0 END) +
        (CASE WHEN v_inactive_stations > 0 THEN 1 ELSE 0 END);

    RETURN jsonb_build_object(
        'total_stations', v_total_stations,
        'active_stations', v_active_stations,
        'inactive_stations', v_inactive_stations,
        'active_memberships', v_active_memberships,
        'station_admin_count', v_admin_count,
        'shift_manager_count', v_shift_manager_count,
        'nfc_tags_total', v_nfc_tags_total,
        'nfc_tags_active', v_nfc_tags_active,
        'stale_open_sessions', v_stale_sessions,
        'failed_exports_24h', v_failed_exports,
        'pending_notifications', v_pending_notifications,
        'operational_alert_count', v_alert_count,
        'schema_version', '20260904000002',
        'telemetry_timestamp', v_now
    );
END;
$$;

-- 2. Platform List Stations RPC (NFC-aligned)
CREATE OR REPLACE FUNCTION public.platform_list_stations()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_now TIMESTAMPTZ := now();
BEGIN
    PERFORM public.require_platform_admin();

    RETURN COALESCE((
        SELECT jsonb_agg(q.row_data ORDER BY q.name ASC)
        FROM (
            SELECT jsonb_build_object(
                'id', s.id,
                'name', s.name,
                'code', s.code,
                'timezone', s.timezone,
                'locale', s.locale,
                'is_active', s.is_active,
                'created_at', s.created_at,
                'updated_at', s.updated_at,
                'active_members', COALESCE(m.active_members, 0),
                'admin_count', COALESCE(m.admin_count, 0),
                'shift_manager_count', COALESCE(m.shift_manager_count, 0),
                'employee_count', COALESCE(m.employee_count, 0),
                'nfc_tags_total', COALESCE(n.nfc_tags_total, 0),
                'nfc_tags_active', COALESCE(n.nfc_tags_active, 0),
                'stale_open_sessions', COALESCE(a.stale_open_sessions, 0),
                'exports_failed_24h', COALESCE(e.exports_failed_24h, 0)
            ) AS row_data,
            s.name
            FROM public.stations s
            LEFT JOIN LATERAL (
                SELECT
                    COUNT(*) FILTER (WHERE sm.status = 'ACTIVE') AS active_members,
                    COUNT(*) FILTER (WHERE sm.status = 'ACTIVE' AND sm.role = 'ADMIN') AS admin_count,
                    COUNT(*) FILTER (WHERE sm.status = 'ACTIVE' AND sm.role = 'SHIFT_MANAGER') AS shift_manager_count,
                    COUNT(*) FILTER (WHERE sm.status = 'ACTIVE' AND sm.role = 'EMPLOYEE') AS employee_count
                FROM public.station_memberships sm
                WHERE sm.station_id = s.id
            ) m ON true
            LEFT JOIN LATERAL (
                SELECT
                    COUNT(*) AS nfc_tags_total,
                    COUNT(*) FILTER (WHERE nt.is_active = true) AS nfc_tags_active
                FROM public.station_nfc_tags nt
                WHERE nt.station_id = s.id
            ) n ON true
            LEFT JOIN LATERAL (
                SELECT COUNT(*) AS stale_open_sessions
                FROM public.attendance_records ar
                WHERE ar.station_id = s.id
                  AND ar.check_out_time IS NULL
                  AND ar.check_in_time <= (v_now - INTERVAL '16 hours')
            ) a ON true
            LEFT JOIN LATERAL (
                SELECT COUNT(*) FILTER (WHERE re.status = 'FAILED') AS exports_failed_24h
                FROM public.report_exports re
                WHERE re.station_id = s.id
                  AND re.created_at >= (v_now - INTERVAL '24 hours')
            ) e ON true
        ) q
    ), '[]'::jsonb);
END;
$$;

-- 3. Platform Health Overview Alias RPC
CREATE OR REPLACE FUNCTION public.platform_get_health_overview()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN public.platform_get_overview();
END;
$$;

-- 4. Station System Health RPC (NFC-aligned)
CREATE OR REPLACE FUNCTION public.get_station_system_health(p_station_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_nfc_total INT := 0;
    v_nfc_active INT := 0;
    v_stale_open INT := 0;
    v_exports_total INT := 0;
    v_exports_failed INT := 0;
    v_exports_pending INT := 0;
    v_now TIMESTAMPTZ := now();
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    IF NOT (public.has_station_permission(p_station_id, v_caller_id, 'attendance.nfc.manage') OR public.is_station_admin(p_station_id, v_caller_id) OR public.is_platform_admin(v_caller_id)) THEN
        RAISE EXCEPTION 'Access denied: caller cannot view system health for this station' USING ERRCODE = '42501';
    END IF;

    SELECT 
        COALESCE(COUNT(*), 0),
        COALESCE(COUNT(*) FILTER (WHERE is_active = true), 0)
    INTO v_nfc_total, v_nfc_active
    FROM public.station_nfc_tags
    WHERE station_id = p_station_id;

    SELECT COALESCE(COUNT(*), 0) INTO v_stale_open
    FROM public.attendance_records
    WHERE station_id = p_station_id 
      AND check_out_time IS NULL 
      AND check_in_time <= (v_now - INTERVAL '16 hours');

    SELECT 
        COALESCE(COUNT(*), 0),
        COALESCE(COUNT(*) FILTER (WHERE status = 'FAILED'), 0),
        COALESCE(COUNT(*) FILTER (WHERE status IN ('PENDING', 'PROCESSING')), 0)
    INTO v_exports_total, v_exports_failed, v_exports_pending
    FROM public.report_exports
    WHERE station_id = p_station_id 
      AND created_at >= (v_now - INTERVAL '24 hours');

    RETURN jsonb_build_object(
        'station_id', p_station_id,
        'schema_version', '20260904000002',
        'telemetry_timestamp', v_now,
        'server_time', v_now,
        'nfc_tags', jsonb_build_object(
            'total', v_nfc_total,
            'active', v_nfc_active
        ),
        'nfc_tags_total', v_nfc_total,
        'nfc_tags_active', v_nfc_active,
        'exports_24h', jsonb_build_object(
            'total', v_exports_total,
            'failed', v_exports_failed,
            'pending_active', v_exports_pending
        ),
        'exports', jsonb_build_object(
            'total_24h', v_exports_total,
            'failed_24h', v_exports_failed
        ),
        'anomalies', jsonb_build_object(
            'stale_open_sessions', v_stale_open
        ),
        'stale_open_sessions', v_stale_open
    );
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
        'schema_version', '20260904000004',
        'platform_version', '1.0.6',
        'min_compatible_client_version', '1.0.0',
        'migration_cutoff', '20260904000004',
        'status', 'HEALTHY',
        'nfc_only_attendance', true,
        'server_timestamp', now()
    );
END;
$$;

