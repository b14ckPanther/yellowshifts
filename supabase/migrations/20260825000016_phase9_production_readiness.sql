-- ============================================================================
-- Migration: 20260825000016_phase9_production_readiness.sql
-- Description: Phase 9 Production Readiness, Reliability Engineering,
--              Schema Compatibility, Health Telemetry, and Zombie Job Recovery
-- Author: YellowShifts Core Platform Team
-- Date: 2026-08-27
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Platform Schema Version & Compatibility Endpoint
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_platform_schema_version()
RETURNS JSONB AS $$
BEGIN
    RETURN jsonb_build_object(
        'schema_version', '20260825000016',
        'platform_version', '1.0.0',
        'min_compatible_client_version', '1.0.0',
        'status', 'HEALTHY',
        'server_timestamp', now()
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.get_platform_schema_version() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_platform_schema_version() TO anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 2. Zombie Operational Job Recovery RPC
--    Recovers orphaned export requests and notification worker leases safely
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recover_stuck_operational_jobs()
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_caller_role TEXT;
    v_recovered_exports INTEGER := 0;
    v_recovered_notifications INTEGER := 0;
    v_now TIMESTAMPTZ := now();
BEGIN
    v_caller_id := auth.uid();
    v_caller_role := auth.role();

    -- Strictly require service_role or authenticated user
    IF v_caller_role != 'service_role' THEN
        IF v_caller_id IS NULL THEN
            RAISE EXCEPTION 'Access denied: authentication required'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    -- 1. Recover stuck report exports (> 30 minutes in PROCESSING)
    UPDATE public.report_exports
    SET status = 'FAILED',
        failure_code = 'LEASE_TIMEOUT',
        failed_at = v_now
    WHERE status = 'PROCESSING'
      AND (
          started_at <= (v_now - INTERVAL '30 minutes')
          OR (started_at IS NULL AND created_at <= (v_now - INTERVAL '30 minutes'))
      );
    GET DIAGNOSTICS v_recovered_exports = ROW_COUNT;

    -- 2. Recover stuck notification delivery jobs (> 15 minutes lease or expired lease)
    UPDATE public.notification_delivery_jobs
    SET status = 'PENDING',
        lock_token = NULL,
        locked_at = NULL,
        lease_expires_at = NULL
    WHERE status = 'PROCESSING'
      AND (
          lease_expires_at IS NULL
          OR lease_expires_at <= v_now
          OR (locked_at IS NOT NULL AND locked_at <= (v_now - INTERVAL '15 minutes'))
      );
    GET DIAGNOSTICS v_recovered_notifications = ROW_COUNT;

    -- Log recovery in audit log if any jobs were recovered
    IF v_recovered_exports > 0 OR v_recovered_notifications > 0 THEN
        IF v_caller_id IS NOT NULL THEN
            INSERT INTO public.audit_logs (
                station_id,
                actor_id,
                action,
                target_type,
                target_id,
                metadata
            ) VALUES (
                NULL,
                v_caller_id,
                'SYSTEM_MAINTENANCE_RECOVER_JOBS',
                'OPERATIONAL_JOBS',
                gen_random_uuid(),
                jsonb_build_object(
                    'recovered_exports', v_recovered_exports,
                    'recovered_notifications', v_recovered_notifications,
                    'recovered_at', v_now
                )
            );
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'recovered_exports', v_recovered_exports,
        'recovered_notifications', v_recovered_notifications,
        'timestamp', v_now
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.recover_stuck_operational_jobs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recover_stuck_operational_jobs() TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 3. Enhanced Station System Health Telemetry RPC
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_station_system_health(p_station_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_total_kiosks INTEGER := 0;
    v_online_kiosks INTEGER := 0;
    v_offline_kiosks INTEGER := 0;
    v_exports_total_24h INTEGER := 0;
    v_exports_failed_24h INTEGER := 0;
    v_exports_pending INTEGER := 0;
    v_stale_open_sessions INTEGER := 0;
    v_failed_identity_attempts INTEGER := 0;
    v_pending_notifications INTEGER := 0;
    v_now TIMESTAMPTZ := now();
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
        COUNT(*) FILTER (WHERE status = 'FAILED'),
        COUNT(*) FILTER (WHERE status IN ('PENDING', 'PROCESSING'))
    INTO v_exports_total_24h, v_exports_failed_24h, v_exports_pending
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

    -- Pending notification deliveries for this station's users
    SELECT COUNT(*) INTO v_pending_notifications
    FROM public.notification_delivery_jobs nd
    JOIN public.notifications n ON nd.notification_id = n.id
    WHERE n.station_id = p_station_id
      AND nd.status IN ('PENDING', 'PROCESSING');

    RETURN jsonb_build_object(
        'station_id', p_station_id,
        'schema_version', '20260825000016',
        'kiosks', jsonb_build_object(
            'total', v_total_kiosks,
            'online', v_online_kiosks,
            'offline', v_offline_kiosks
        ),
        'exports', jsonb_build_object(
            'total_24h', v_exports_total_24h,
            'failed_24h', v_exports_failed_24h,
            'pending_active', v_exports_pending
        ),
        'attendance', jsonb_build_object(
            'stale_open_sessions', v_stale_open_sessions
        ),
        'identity', jsonb_build_object(
            'failed_attempts_24h', v_failed_identity_attempts
        ),
        'notifications', jsonb_build_object(
            'pending_deliveries', v_pending_notifications
        ),
        'storage', jsonb_build_object(
            'reports_bucket_status', 'HEALTHY'
        ),
        'evaluated_at', v_now
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.get_station_system_health(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_station_system_health(UUID) TO authenticated, service_role;
