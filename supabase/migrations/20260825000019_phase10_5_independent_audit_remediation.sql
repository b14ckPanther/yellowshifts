-- ============================================================================
-- Migration: 20260825000019_phase10_5_independent_audit_remediation.sql
-- Additive. Does not modify 001–018. Applied after 018 on the linked project.
-- ============================================================================

-- Internal primitive: not granted to client roles.
CREATE OR REPLACE FUNCTION public._active_platform_admin(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF p_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    RETURN EXISTS (
        SELECT 1
        FROM public.platform_admins pa
        WHERE pa.user_id = p_user_id
          AND pa.is_active = true
    );
END;
$$;

REVOKE ALL ON FUNCTION public._active_platform_admin(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._active_platform_admin(UUID) TO service_role;

-- Public primitive uses JWT identity only. Client-supplied UUIDs are ignored.
CREATE OR REPLACE FUNCTION public.is_platform_admin(p_user_id UUID DEFAULT NULL)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN public._active_platform_admin(auth.uid());
END;
$$;

CREATE OR REPLACE FUNCTION public.is_station_admin(p_station_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF p_station_id IS NULL OR p_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    IF public.is_station_membership_admin(p_station_id, p_user_id) THEN
        RETURN TRUE;
    END IF;
    -- Platform-admin shortcut only for the authenticated caller (prevents PA oracle).
    RETURN public._active_platform_admin(p_user_id)
        AND auth.uid() IS NOT DISTINCT FROM p_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.is_station_member(p_station_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF p_station_id IS NULL OR p_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.station_memberships
        WHERE station_id = p_station_id
          AND user_id = p_user_id
          AND status = 'ACTIVE'
    ) THEN
        RETURN TRUE;
    END IF;
    RETURN public._active_platform_admin(p_user_id)
        AND auth.uid() IS NOT DISTINCT FROM p_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.is_station_manager_or_admin(p_station_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF p_station_id IS NULL OR p_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.station_memberships
        WHERE station_id = p_station_id
          AND user_id = p_user_id
          AND role IN ('ADMIN', 'SHIFT_MANAGER')
          AND status = 'ACTIVE'
    ) THEN
        RETURN TRUE;
    END IF;
    RETURN public._active_platform_admin(p_user_id)
        AND auth.uid() IS NOT DISTINCT FROM p_user_id;
END;
$$;

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

    IF public._active_platform_admin(p_user_id)
       AND auth.uid() IS NOT DISTINCT FROM p_user_id THEN
        RETURN TRUE;
    END IF;

    SELECT role, status INTO v_role, v_status
    FROM public.station_memberships
    WHERE station_id = p_station_id AND user_id = p_user_id;

    IF NOT FOUND OR v_status <> 'ACTIVE' THEN
        RETURN FALSE;
    END IF;

    IF v_role = 'ADMIN' THEN
        RETURN TRUE;
    END IF;

    IF v_role = 'EMPLOYEE' THEN
        IF p_permission IN (
            'shift_templates.read', 'availability.period.read', 'availability.submit',
            'schedule.read', 'attendance.read', 'reports.self.read'
        ) THEN
            RETURN TRUE;
        END IF;
        RETURN FALSE;
    END IF;

    IF v_role = 'SHIFT_MANAGER' THEN
        SELECT is_enabled INTO v_override_enabled
        FROM public.station_shift_manager_permissions
        WHERE station_id = p_station_id AND permission = p_permission;

        IF FOUND THEN
            RETURN v_override_enabled;
        END IF;

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
$$;

-- Idempotency: keys are caller-scoped; lost races delete the orphaned station.
CREATE OR REPLACE FUNCTION public.platform_create_station(
    p_name TEXT,
    p_code TEXT,
    p_timezone TEXT DEFAULT 'Asia/Jerusalem',
    p_locale TEXT DEFAULT 'he',
    p_week_start INTEGER DEFAULT 0,
    p_is_active BOOLEAN DEFAULT true,
    p_initial_admin_user_id UUID DEFAULT NULL,
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_clean_name TEXT;
    v_clean_code TEXT;
    v_clean_tz TEXT;
    v_locale TEXT;
    v_station_id UUID;
    v_membership_id UUID;
    v_existing_station UUID;
    v_key_owner UUID;
    v_key TEXT;
    v_result JSONB;
BEGIN
    v_caller_id := auth.uid();
    PERFORM public.require_platform_admin();

    v_key := NULLIF(TRIM(COALESCE(p_idempotency_key, '')), '');
    IF v_key IS NOT NULL THEN
        SELECT station_id, created_by INTO v_existing_station, v_key_owner
        FROM public.platform_provisioning_keys
        WHERE idempotency_key = v_key;
        IF FOUND THEN
            IF v_key_owner IS DISTINCT FROM v_caller_id AND v_key_owner IS NOT NULL THEN
                RAISE EXCEPTION 'Idempotency key already used'
                    USING ERRCODE = 'P00107';
            END IF;
            SELECT jsonb_build_object(
                'success', true,
                'station_id', s.id,
                'name', s.name,
                'code', s.code,
                'timezone', s.timezone,
                'locale', s.locale,
                'is_active', s.is_active,
                'idempotent', true
            )
            INTO v_result
            FROM public.stations s
            WHERE s.id = v_existing_station;
            RETURN v_result;
        END IF;
    END IF;

    v_clean_name := TRIM(COALESCE(p_name, ''));
    IF char_length(v_clean_name) < 2 OR char_length(v_clean_name) > 120 THEN
        RAISE EXCEPTION 'Station name must be between 2 and 120 characters'
            USING ERRCODE = '22000';
    END IF;

    v_clean_code := public.normalize_station_code(p_code);
    IF EXISTS (SELECT 1 FROM public.stations WHERE code = v_clean_code) THEN
        RAISE EXCEPTION 'Station code already exists: %', v_clean_code
            USING ERRCODE = 'P00106';
    END IF;

    v_clean_tz := TRIM(COALESCE(p_timezone, 'Asia/Jerusalem'));
    IF v_clean_tz = '' THEN
        v_clean_tz := 'Asia/Jerusalem';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_timezone_names WHERE name = v_clean_tz) THEN
        RAISE EXCEPTION 'Invalid IANA timezone: %', v_clean_tz
            USING ERRCODE = '22000';
    END IF;

    v_locale := LOWER(TRIM(COALESCE(p_locale, 'he')));
    IF v_locale NOT IN ('he', 'en') THEN
        v_locale := 'he';
    END IF;

    IF p_week_start NOT IN (0, 1) THEN
        RAISE EXCEPTION 'week_start must be 0 (Sunday) or 1 (Monday)'
            USING ERRCODE = '22000';
    END IF;

    IF p_initial_admin_user_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_initial_admin_user_id) THEN
            RAISE EXCEPTION 'Initial station manager profile not found'
                USING ERRCODE = 'P0002';
        END IF;
    END IF;

    INSERT INTO public.stations (name, code, timezone, locale, week_start, is_active)
    VALUES (v_clean_name, v_clean_code, v_clean_tz, v_locale, p_week_start, COALESCE(p_is_active, true))
    RETURNING id INTO v_station_id;

    IF p_initial_admin_user_id IS NOT NULL THEN
        INSERT INTO public.station_memberships (station_id, user_id, role, status)
        VALUES (v_station_id, p_initial_admin_user_id, 'ADMIN', 'ACTIVE')
        RETURNING id INTO v_membership_id;
    END IF;

    IF v_key IS NOT NULL THEN
        INSERT INTO public.platform_provisioning_keys (idempotency_key, station_id, created_by)
        VALUES (v_key, v_station_id, v_caller_id)
        ON CONFLICT (idempotency_key) DO NOTHING;

        SELECT station_id, created_by INTO v_existing_station, v_key_owner
        FROM public.platform_provisioning_keys
        WHERE idempotency_key = v_key;

        IF v_existing_station IS DISTINCT FROM v_station_id THEN
            DELETE FROM public.station_memberships WHERE station_id = v_station_id;
            DELETE FROM public.audit_logs WHERE station_id = v_station_id;
            DELETE FROM public.stations WHERE id = v_station_id;
            IF v_key_owner IS DISTINCT FROM v_caller_id AND v_key_owner IS NOT NULL THEN
                RAISE EXCEPTION 'Idempotency key already used'
                    USING ERRCODE = 'P00107';
            END IF;
            SELECT jsonb_build_object(
                'success', true,
                'station_id', s.id,
                'name', s.name,
                'code', s.code,
                'timezone', s.timezone,
                'locale', s.locale,
                'is_active', s.is_active,
                'idempotent', true
            )
            INTO v_result
            FROM public.stations s
            WHERE s.id = v_existing_station;
            RETURN v_result;
        END IF;
    END IF;

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        v_station_id,
        v_caller_id,
        'platform.station.created',
        'station',
        v_station_id::text,
        public.sanitize_audit_metadata(jsonb_build_object(
            'name', v_clean_name,
            'code', v_clean_code,
            'timezone', v_clean_tz,
            'locale', v_locale,
            'initial_admin_user_id', p_initial_admin_user_id
        ))
    );

    IF v_membership_id IS NOT NULL THEN
        INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
        VALUES (
            v_station_id,
            v_caller_id,
            'platform.station_admin.assigned',
            'station_membership',
            v_membership_id::text,
            public.sanitize_audit_metadata(jsonb_build_object(
                'target_user_id', p_initial_admin_user_id,
                'via', 'station_create'
            ))
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'station_id', v_station_id,
        'name', v_clean_name,
        'code', v_clean_code,
        'timezone', v_clean_tz,
        'locale', v_locale,
        'week_start', p_week_start,
        'is_active', COALESCE(p_is_active, true),
        'membership_id', v_membership_id,
        'idempotent', false
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_platform_schema_version()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN jsonb_build_object(
        'schema_version', '20260825000019',
        'platform_version', '1.0.5',
        'min_compatible_client_version', '1.0.0',
        'status', 'HEALTHY',
        'server_timestamp', now()
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_station_system_health(p_station_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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

    SELECT
        COALESCE(COUNT(*), 0),
        COALESCE(COUNT(*) FILTER (WHERE is_active = true AND last_seen_at IS NOT NULL AND last_seen_at >= (v_now - INTERVAL '2 minutes')), 0),
        COALESCE(COUNT(*) FILTER (WHERE is_active = false OR last_seen_at IS NULL OR last_seen_at < (v_now - INTERVAL '2 minutes')), 0)
    INTO v_total_kiosks, v_online_kiosks, v_offline_kiosks
    FROM public.kiosk_devices
    WHERE station_id = p_station_id;

    SELECT
        COALESCE(COUNT(*), 0),
        COALESCE(COUNT(*) FILTER (WHERE status = 'FAILED'), 0),
        COALESCE(COUNT(*) FILTER (WHERE status IN ('PENDING', 'PROCESSING')), 0)
    INTO v_exports_total_24h, v_exports_failed_24h, v_exports_pending
    FROM public.report_exports
    WHERE station_id = p_station_id
      AND created_at >= (v_now - INTERVAL '24 hours');

    SELECT COALESCE(COUNT(*), 0)
    INTO v_stale_open_sessions
    FROM public.attendance_records
    WHERE station_id = p_station_id
      AND check_out_time IS NULL
      AND check_in_time <= (v_now - INTERVAL '16 hours');

    SELECT COALESCE(COUNT(*), 0)
    INTO v_failed_identity_attempts
    FROM public.identity_verification_attempts
    WHERE station_id = p_station_id
      AND result IN ('NOT_VERIFIED', 'INCONCLUSIVE')
      AND created_at >= (v_now - INTERVAL '24 hours');

    SELECT COALESCE(COUNT(*), 0)
    INTO v_pending_notifications
    FROM public.notification_delivery_jobs j
    JOIN public.notifications n ON j.notification_id = n.id
    WHERE n.station_id = p_station_id
      AND j.status = 'PENDING';

    RETURN jsonb_build_object(
        'station_id', p_station_id,
        'schema_version', '20260825000019',
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
        'exports', jsonb_build_object(
            'total_24h', v_exports_total_24h,
            'failed_24h', v_exports_failed_24h,
            'pending_active', v_exports_pending
        ),
        'anomalies', jsonb_build_object(
            'stale_open_sessions', v_stale_open_sessions,
            'failed_identity_attempts', v_failed_identity_attempts
        ),
        'server_time', v_now,
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
$$;

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
    v_kiosks_online INTEGER := 0;
    v_kiosks_offline INTEGER := 0;
    v_stale_sessions INTEGER := 0;
    v_failed_exports INTEGER := 0;
    v_pending_notifications INTEGER := 0;
    v_identity_failures INTEGER := 0;
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
        COUNT(*) FILTER (
            WHERE is_active = true
              AND last_seen_at IS NOT NULL
              AND last_seen_at >= (v_now - INTERVAL '2 minutes')
        ),
        COUNT(*) FILTER (
            WHERE is_active = false
               OR last_seen_at IS NULL
               OR last_seen_at < (v_now - INTERVAL '2 minutes')
        )
    INTO v_kiosks_online, v_kiosks_offline
    FROM public.kiosk_devices;

    SELECT COUNT(*) INTO v_stale_sessions
    FROM public.attendance_records
    WHERE check_out_time IS NULL
      AND check_in_time <= (v_now - INTERVAL '16 hours');

    SELECT COUNT(*) INTO v_failed_exports
    FROM public.report_exports
    WHERE status = 'FAILED'
      AND created_at >= (v_now - INTERVAL '24 hours');

    SELECT COUNT(*) INTO v_pending_notifications
    FROM public.notification_delivery_jobs
    WHERE status = 'PENDING';

    SELECT COUNT(*) INTO v_identity_failures
    FROM public.identity_verification_attempts
    WHERE result IN ('NOT_VERIFIED', 'INCONCLUSIVE')
      AND created_at >= (v_now - INTERVAL '24 hours');

    v_alert_count :=
        (CASE WHEN v_kiosks_offline > 0 THEN 1 ELSE 0 END) +
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
        'kiosks_online', v_kiosks_online,
        'kiosks_offline', v_kiosks_offline,
        'stale_open_sessions', v_stale_sessions,
        'failed_exports_24h', v_failed_exports,
        'pending_notifications', v_pending_notifications,
        'identity_failures_24h', v_identity_failures,
        'operational_alert_count', v_alert_count,
        'schema_version', public.get_platform_schema_version()->>'schema_version',
        'telemetry_timestamp', v_now
    );
END;
$$;
