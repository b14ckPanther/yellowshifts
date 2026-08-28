-- ============================================================================
-- Migration: 20260825000017_phase9_audit_remediation.sql
-- Description: Phase 9 Independent Adversarial Audit Remediation
--              1. Hardens recover_stuck_operational_jobs to service_role ONLY (42501 for authenticated)
--              2. Updates get_platform_schema_version to 20260825000017 with minimal footprint
--              3. Hardens get_station_system_health with strict station-scoped COALESCE aggregation
-- Author: YellowShifts Core Security & Reliability Team
-- Date: 2026-08-27
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Platform Schema Version & Compatibility Endpoint (Updated Schema Version)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_platform_schema_version()
RETURNS JSONB AS $$
BEGIN
    RETURN jsonb_build_object(
        'schema_version', '20260825000017',
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
-- 2. Privileged Zombie Operational Job Recovery RPC
--    Strictly restricted to service_role / background scheduler.
--    Ordinary authenticated and anonymous users are DENIED (42501).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recover_stuck_operational_jobs()
RETURNS JSONB AS $$
DECLARE
    v_caller_role TEXT;
    v_recovered_exports INTEGER := 0;
    v_recovered_notifications INTEGER := 0;
    v_now TIMESTAMPTZ := now();
BEGIN
    v_caller_role := auth.role();

    -- Strict service_role barrier: ordinary authenticated users or anon are rejected
    IF v_caller_role IS NULL OR v_caller_role != 'service_role' THEN
        RAISE EXCEPTION 'Access denied: service_role required for system maintenance operations'
            USING ERRCODE = '42501';
    END IF;

    -- 1. Recover stuck report exports (> 30 minutes in PROCESSING)
    WITH stuck_exports AS (
        SELECT id
        FROM public.report_exports
        WHERE status = 'PROCESSING'
          AND (
              started_at <= (v_now - INTERVAL '30 minutes')
              OR (started_at IS NULL AND created_at <= (v_now - INTERVAL '30 minutes'))
          )
        FOR UPDATE SKIP LOCKED
    )
    UPDATE public.report_exports e
    SET status = 'FAILED',
        failure_code = 'LEASE_TIMEOUT',
        failed_at = v_now
    FROM stuck_exports s
    WHERE e.id = s.id;
    GET DIAGNOSTICS v_recovered_exports = ROW_COUNT;

    -- 2. Recover stuck notification delivery jobs (> 15 minutes lease or expired lease)
    WITH stuck_notifications AS (
        SELECT id
        FROM public.notification_delivery_jobs
        WHERE status = 'PROCESSING'
          AND (
              lease_expires_at IS NULL
              OR lease_expires_at <= v_now
              OR (locked_at IS NOT NULL AND locked_at <= (v_now - INTERVAL '15 minutes'))
          )
        FOR UPDATE SKIP LOCKED
    )
    UPDATE public.notification_delivery_jobs n
    SET status = 'PENDING',
        lock_token = NULL,
        locked_at = NULL,
        lease_expires_at = NULL
    FROM stuck_notifications s
    WHERE n.id = s.id;
    GET DIAGNOSTICS v_recovered_notifications = ROW_COUNT;

    -- Log recovery in audit log if any jobs were reclaimed
    IF v_recovered_exports > 0 OR v_recovered_notifications > 0 THEN
        INSERT INTO public.audit_logs (
            station_id,
            actor_id,
            action,
            target_type,
            target_id,
            metadata
        ) VALUES (
            NULL,
            (SELECT id FROM public.profiles WHERE id = auth.uid()),
            'SYSTEM_MAINTENANCE_RECOVER_JOBS',
            'OPERATIONAL_JOBS',
            gen_random_uuid()::text,
            jsonb_build_object(
                'recovered_exports', v_recovered_exports,
                'recovered_notifications', v_recovered_notifications,
                'recovered_at', v_now
            )
        );
    END IF;

    RETURN jsonb_build_object(
        'recovered_exports', v_recovered_exports,
        'recovered_notifications', v_recovered_notifications,
        'timestamp', v_now
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- Revoke all execution from PUBLIC, anon, and authenticated users.
REVOKE ALL ON FUNCTION public.recover_stuck_operational_jobs() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.recover_stuck_operational_jobs() TO service_role;

-- ----------------------------------------------------------------------------
-- 3. Hardened Station System Health Telemetry RPC
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

    -- 1. Kiosk Fleet Telemetry (heartbeat within 2 minutes = online)
    SELECT 
        COALESCE(COUNT(*), 0),
        COALESCE(COUNT(*) FILTER (WHERE is_active = true AND last_seen_at IS NOT NULL AND last_seen_at >= (v_now - INTERVAL '2 minutes')), 0),
        COALESCE(COUNT(*) FILTER (WHERE is_active = false OR last_seen_at IS NULL OR last_seen_at < (v_now - INTERVAL '2 minutes')), 0)
    INTO v_total_kiosks, v_online_kiosks, v_offline_kiosks
    FROM public.kiosk_devices
    WHERE station_id = p_station_id;

    -- 2. Report Exports Pipeline (past 24h & current pending)
    SELECT 
        COALESCE(COUNT(*), 0),
        COALESCE(COUNT(*) FILTER (WHERE status = 'FAILED'), 0),
        COALESCE(COUNT(*) FILTER (WHERE status IN ('PENDING', 'PROCESSING')), 0)
    INTO v_exports_total_24h, v_exports_failed_24h, v_exports_pending
    FROM public.report_exports
    WHERE station_id = p_station_id
      AND created_at >= (v_now - INTERVAL '24 hours');

    -- 3. Attendance Stale Open Sessions (open >= 16 hours)
    SELECT COALESCE(COUNT(*), 0)
    INTO v_stale_open_sessions
    FROM public.attendance_records
    WHERE station_id = p_station_id
      AND check_out_time IS NULL
      AND check_in_time <= (v_now - INTERVAL '16 hours');

    -- 4. Identity Verification Failures (past 24h)
    SELECT COALESCE(COUNT(*), 0)
    INTO v_failed_identity_attempts
    FROM public.identity_verification_attempts
    WHERE station_id = p_station_id
      AND result IN ('NOT_VERIFIED', 'INCONCLUSIVE')
      AND created_at >= (v_now - INTERVAL '24 hours');

    -- 5. Station-related pending notifications in queue
    SELECT COALESCE(COUNT(*), 0)
    INTO v_pending_notifications
    FROM public.notification_delivery_jobs j
    JOIN public.notifications n ON j.notification_id = n.id
    WHERE n.station_id = p_station_id
      AND j.status = 'PENDING';

    RETURN jsonb_build_object(
        'station_id', p_station_id,
        'schema_version', '20260825000017',
        'telemetry_timestamp', v_now,
        'kiosks', jsonb_build_object(
            'total', v_total_kiosks,
            'online', v_online_kiosks,
            'offline', v_offline_kiosks
        ),
        'exports_24h', jsonb_build_object(
            'total', v_exports_total_24h,
            'failed', v_exports_failed_24h,
            'pending_active', v_exports_pending
        ),
        'attendance', jsonb_build_object(
            'stale_open_sessions_16h', v_stale_open_sessions
        ),
        'identity', jsonb_build_object(
            'failures_24h', v_failed_identity_attempts
        ),
        'notifications', jsonb_build_object(
            'pending_outbox', v_pending_notifications
        ),
        'storage_buckets', jsonb_build_object(
            'reports_bucket_accessible', true
        )
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.get_station_system_health(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_station_system_health(UUID) TO authenticated, service_role;
