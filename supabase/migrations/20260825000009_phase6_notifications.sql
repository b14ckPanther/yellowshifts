-- ======================================================================
-- YELLOWSHIFTS — PHASE 6 NOTIFICATIONS & OPERATIONAL ALERTS ARCHITECTURE
-- Migration: 20260825000009_phase6_notifications.sql
-- ======================================================================

-- 1. Custom Types & Enums
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_category') THEN
        CREATE TYPE public.notification_category AS ENUM (
            'SCHEDULE', 'ATTENDANCE', 'AVAILABILITY', 'OPERATIONS', 'IDENTITY', 'SYSTEM'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_priority') THEN
        CREATE TYPE public.notification_priority AS ENUM (
            'LOW', 'NORMAL', 'HIGH', 'CRITICAL'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'delivery_channel') THEN
        CREATE TYPE public.delivery_channel AS ENUM (
            'IN_APP', 'PUSH', 'EMAIL', 'SMS'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'delivery_job_status') THEN
        CREATE TYPE public.delivery_job_status AS ENUM (
            'PENDING', 'PROCESSING', 'DELIVERED', 'RETRY', 'FAILED', 'CANCELLED'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'delivery_attempt_outcome') THEN
        CREATE TYPE public.delivery_attempt_outcome AS ENUM (
            'SUCCESS', 'TEMPORARY_FAILURE', 'PERMANENT_FAILURE'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_event_status') THEN
        CREATE TYPE public.notification_event_status AS ENUM (
            'PENDING', 'PROCESSED', 'FAILED'
        );
    END IF;
END $$;

-- 2. Domain Events Ledger (Transactional Outbox Source)
CREATE TABLE IF NOT EXISTS public.notification_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    station_id UUID REFERENCES public.stations(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    category public.notification_category NOT NULL,
    priority public.notification_priority NOT NULL DEFAULT 'NORMAL',
    aggregate_type TEXT NOT NULL,
    aggregate_id UUID NULL,
    actor_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    deduplication_key TEXT NOT NULL UNIQUE,
    status public.notification_event_status NOT NULL DEFAULT 'PENDING',
    processed_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT check_notification_event_type_nonempty CHECK (length(trim(event_type)) > 0),
    CONSTRAINT check_notification_aggregate_type_nonempty CHECK (length(trim(aggregate_type)) > 0),
    CONSTRAINT check_notification_dedup_nonempty CHECK (length(trim(deduplication_key)) > 0),
    CONSTRAINT check_notification_payload_size CHECK (pg_column_size(payload) <= 65536)
);

-- 3. Authoritative User Notification Inbox
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    station_id UUID NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    event_id UUID NULL REFERENCES public.notification_events(id) ON DELETE SET NULL,
    category public.notification_category NOT NULL,
    event_type TEXT NOT NULL,
    priority public.notification_priority NOT NULL DEFAULT 'NORMAL',
    title_key TEXT NOT NULL,
    body_key TEXT NOT NULL,
    render_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    action_type TEXT NULL,
    action_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_mandatory BOOLEAN NOT NULL DEFAULT false,
    deduplication_key TEXT NOT NULL UNIQUE,
    read_at TIMESTAMPTZ NULL,
    seen_at TIMESTAMPTZ NULL,
    archived_at TIMESTAMPTZ NULL,
    expires_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT check_notification_read_after_created CHECK (read_at IS NULL OR read_at >= created_at - INTERVAL '1 second'),
    CONSTRAINT check_notification_seen_after_created CHECK (seen_at IS NULL OR seen_at >= created_at - INTERVAL '1 second'),
    CONSTRAINT check_notification_render_data_size CHECK (pg_column_size(render_data) <= 16384)
);

-- 4. User Notification Preferences
CREATE TABLE IF NOT EXISTS public.notification_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    category public.notification_category NOT NULL,
    in_app_enabled BOOLEAN NOT NULL DEFAULT true,
    push_enabled BOOLEAN NOT NULL DEFAULT true,
    email_enabled BOOLEAN NOT NULL DEFAULT false,
    sms_enabled BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_notification_category UNIQUE (user_id, category)
);

-- 5. Notification Delivery Queue (Outbox Jobs)
CREATE TABLE IF NOT EXISTS public.notification_delivery_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID NOT NULL REFERENCES public.notifications(id) ON DELETE CASCADE,
    recipient_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    channel public.delivery_channel NOT NULL,
    status public.delivery_job_status NOT NULL DEFAULT 'PENDING',
    attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
    max_attempts INTEGER NOT NULL DEFAULT 5 CHECK (max_attempts > 0),
    next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    lock_token UUID NULL,
    locked_at TIMESTAMPTZ NULL,
    lease_expires_at TIMESTAMPTZ NULL,
    provider TEXT NULL,
    provider_message_id TEXT NULL,
    last_error_category TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    started_at TIMESTAMPTZ NULL,
    delivered_at TIMESTAMPTZ NULL,
    failed_at TIMESTAMPTZ NULL,
    CONSTRAINT check_job_delivered_status CHECK (
        (status = 'DELIVERED' AND delivered_at IS NOT NULL) OR (status <> 'DELIVERED')
    ),
    CONSTRAINT check_job_failed_status CHECK (
        (status = 'FAILED' AND failed_at IS NOT NULL) OR (status <> 'FAILED')
    )
);

-- 6. Notification Delivery Attempts (Append-Only Audit Ledger)
CREATE TABLE IF NOT EXISTS public.notification_delivery_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    delivery_job_id UUID NOT NULL REFERENCES public.notification_delivery_jobs(id) ON DELETE CASCADE,
    attempt_number INTEGER NOT NULL CHECK (attempt_number >= 1),
    provider TEXT NOT NULL,
    channel public.delivery_channel NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    outcome public.delivery_attempt_outcome NOT NULL,
    error_category TEXT NULL,
    provider_response_code TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7. Notification Devices (Push Notification Token Registry)
CREATE TABLE IF NOT EXISTS public.notification_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web', 'macos', 'windows')),
    provider TEXT NOT NULL CHECK (provider IN ('fcm', 'apns', 'webpush', 'mock')),
    device_token_hash TEXT NOT NULL,
    device_label TEXT NOT NULL DEFAULT 'Device',
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at TIMESTAMPTZ NULL,
    CONSTRAINT uq_user_device_token UNIQUE (user_id, device_token_hash)
);

-- 8. Kiosk Health State Tracker (State Transition Deduplication)
CREATE TABLE IF NOT EXISTS public.kiosk_health_states (
    kiosk_device_id UUID PRIMARY KEY REFERENCES public.kiosk_devices(id) ON DELETE CASCADE,
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    current_status TEXT NOT NULL DEFAULT 'ONLINE' CHECK (current_status IN ('ONLINE', 'OFFLINE')),
    last_transition_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 9. Indexes
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_created
    ON public.notifications(recipient_user_id, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_recipient_unread
    ON public.notifications(recipient_user_id, created_at DESC)
    WHERE read_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_dedup
    ON public.notifications(deduplication_key);

CREATE INDEX IF NOT EXISTS idx_notification_events_dedup
    ON public.notification_events(deduplication_key);

CREATE INDEX IF NOT EXISTS idx_notification_events_status
    ON public.notification_events(status, occurred_at);

CREATE INDEX IF NOT EXISTS idx_delivery_jobs_pending
    ON public.notification_delivery_jobs(status, next_attempt_at)
    WHERE status IN ('PENDING', 'RETRY');

CREATE INDEX IF NOT EXISTS idx_delivery_jobs_processing
    ON public.notification_delivery_jobs(lock_token, lease_expires_at)
    WHERE status = 'PROCESSING';

CREATE INDEX IF NOT EXISTS idx_delivery_jobs_notification
    ON public.notification_delivery_jobs(notification_id);

CREATE INDEX IF NOT EXISTS idx_notification_devices_active
    ON public.notification_devices(user_id)
    WHERE is_active = true AND revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_notification_preferences_user
    ON public.notification_preferences(user_id);

-- 10. Table Permissions & Row Level Security (RLS)
GRANT SELECT, UPDATE ON TABLE public.notifications TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.notification_preferences TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.notification_devices TO authenticated;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        GRANT ALL ON TABLE public.notification_events TO service_role;
        GRANT ALL ON TABLE public.notifications TO service_role;
        GRANT ALL ON TABLE public.notification_preferences TO service_role;
        GRANT ALL ON TABLE public.notification_delivery_jobs TO service_role;
        GRANT ALL ON TABLE public.notification_delivery_attempts TO service_role;
        GRANT ALL ON TABLE public.notification_devices TO service_role;
        GRANT ALL ON TABLE public.kiosk_health_states TO service_role;
    END IF;
END $$;

ALTER TABLE public.notification_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_delivery_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_delivery_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kiosk_health_states ENABLE ROW LEVEL SECURITY;

-- Notifications RLS
DROP POLICY IF EXISTS notifications_select_policy ON public.notifications;
CREATE POLICY notifications_select_policy ON public.notifications
    FOR SELECT TO authenticated
    USING (recipient_user_id = auth.uid());

DROP POLICY IF EXISTS notifications_update_policy ON public.notifications;
CREATE POLICY notifications_update_policy ON public.notifications
    FOR UPDATE TO authenticated
    USING (recipient_user_id = auth.uid())
    WITH CHECK (recipient_user_id = auth.uid());

DROP POLICY IF EXISTS notifications_insert_policy ON public.notifications;
CREATE POLICY notifications_insert_policy ON public.notifications
    FOR INSERT TO authenticated
    WITH CHECK (false);

DROP POLICY IF EXISTS notifications_delete_policy ON public.notifications;
CREATE POLICY notifications_delete_policy ON public.notifications
    FOR DELETE TO authenticated
    USING (false);

-- Events RLS
DROP POLICY IF EXISTS notification_events_select_policy ON public.notification_events;
CREATE POLICY notification_events_select_policy ON public.notification_events
    FOR SELECT TO authenticated
    USING (false);

DROP POLICY IF EXISTS notification_events_insert_policy ON public.notification_events;
CREATE POLICY notification_events_insert_policy ON public.notification_events
    FOR INSERT TO authenticated
    WITH CHECK (false);

-- Preferences RLS
DROP POLICY IF EXISTS preferences_select_policy ON public.notification_preferences;
CREATE POLICY preferences_select_policy ON public.notification_preferences
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS preferences_insert_policy ON public.notification_preferences;
CREATE POLICY preferences_insert_policy ON public.notification_preferences
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS preferences_update_policy ON public.notification_preferences;
CREATE POLICY preferences_update_policy ON public.notification_preferences
    FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS preferences_delete_policy ON public.notification_preferences;
CREATE POLICY preferences_delete_policy ON public.notification_preferences
    FOR DELETE TO authenticated
    USING (user_id = auth.uid());

-- Devices RLS
DROP POLICY IF EXISTS devices_select_policy ON public.notification_devices;
CREATE POLICY devices_select_policy ON public.notification_devices
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS devices_insert_policy ON public.notification_devices;
CREATE POLICY devices_insert_policy ON public.notification_devices
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS devices_update_policy ON public.notification_devices;
CREATE POLICY devices_update_policy ON public.notification_devices
    FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS devices_delete_policy ON public.notification_devices;
CREATE POLICY devices_delete_policy ON public.notification_devices
    FOR DELETE TO authenticated
    USING (user_id = auth.uid());

-- Outbox RLS
DROP POLICY IF EXISTS delivery_jobs_policy ON public.notification_delivery_jobs;
CREATE POLICY delivery_jobs_policy ON public.notification_delivery_jobs
    FOR ALL TO authenticated
    USING (false);

DROP POLICY IF EXISTS delivery_attempts_policy ON public.notification_delivery_attempts;
CREATE POLICY delivery_attempts_policy ON public.notification_delivery_attempts
    FOR ALL TO authenticated
    USING (false);

DROP POLICY IF EXISTS kiosk_health_states_policy ON public.kiosk_health_states;
CREATE POLICY kiosk_health_states_policy ON public.kiosk_health_states
    FOR ALL TO authenticated
    USING (false);

-- 11. Helper Function: Resolve Station Managers
CREATE OR REPLACE FUNCTION public.get_station_manager_recipients(
    p_station_id UUID,
    p_permission TEXT DEFAULT NULL
)
RETURNS TABLE (
    recipient_user_id UUID,
    role public.station_role
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN QUERY
    SELECT sm.user_id, sm.role
    FROM public.station_memberships sm
    WHERE sm.station_id = p_station_id
      AND sm.status = 'ACTIVE'
      AND sm.role IN ('ADMIN', 'SHIFT_MANAGER')
      AND (
          p_permission IS NULL
          OR sm.role = 'ADMIN'
          OR public.has_station_permission(p_station_id, sm.user_id, p_permission)
      );
END;
$$;

-- 12. Internal Dispatcher: Emit Notification Event & Route Inbox/Outbox
CREATE OR REPLACE FUNCTION public.emit_notification_event(
    p_station_id UUID,
    p_event_type TEXT,
    p_category public.notification_category,
    p_priority public.notification_priority,
    p_aggregate_type TEXT,
    p_aggregate_id UUID,
    p_actor_user_id UUID,
    p_payload JSONB,
    p_deduplication_key TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_event_id UUID;
    v_recipient_id UUID;
    v_title_key TEXT;
    v_body_key TEXT;
    v_action_type TEXT := NULL;
    v_action_data JSONB := '{}'::jsonb;
    v_render_data JSONB := '{}'::jsonb;
    v_is_mandatory BOOLEAN := false;
    v_notification_id UUID;
    v_in_app_enabled BOOLEAN;
    v_push_enabled BOOLEAN;
    v_email_enabled BOOLEAN;
    v_sms_enabled BOOLEAN;
    v_notif_dedup TEXT;
    v_now TIMESTAMPTZ := now();
    v_rec RECORD;
    v_station_name TEXT := '';
BEGIN
    IF p_station_id IS NOT NULL THEN
        SELECT name INTO v_station_name FROM public.stations WHERE id = p_station_id;
    END IF;

    -- Insert durable domain event (Idempotent deduplication)
    INSERT INTO public.notification_events (
        station_id, event_type, category, priority, aggregate_type, aggregate_id,
        actor_user_id, occurred_at, payload, deduplication_key, status
    ) VALUES (
        p_station_id, p_event_type, p_category, p_priority, p_aggregate_type, p_aggregate_id,
        p_actor_user_id, v_now, COALESCE(p_payload, '{}'::jsonb), p_deduplication_key, 'PROCESSED'
    )
    ON CONFLICT (deduplication_key) DO NOTHING
    RETURNING id INTO v_event_id;

    IF v_event_id IS NULL THEN
        SELECT id INTO v_event_id FROM public.notification_events WHERE deduplication_key = p_deduplication_key;
        RETURN v_event_id;
    END IF;

    -- Configure title, body, action, and render data templates based on event taxonomy
    CASE p_event_type
        -- Scheduling Events
        WHEN 'SCHEDULE_PUBLISHED' THEN
            v_title_key := 'notif_schedule_published_title';
            v_body_key := 'notif_schedule_published_body';
            v_action_type := 'NAVIGATE_SCHEDULE';
            v_action_data := jsonb_build_object('schedule_id', p_aggregate_id, 'station_id', p_station_id);
            v_render_data := jsonb_build_object(
                'station_name', v_station_name,
                'week_start_date', p_payload->>'week_start_date',
                'version', p_payload->>'version'
            );

        WHEN 'SCHEDULE_PUBLICATION_COMPLETED' THEN
            v_title_key := 'notif_schedule_pub_complete_title';
            v_body_key := 'notif_schedule_pub_complete_body';
            v_action_type := 'NAVIGATE_SCHEDULE';
            v_action_data := jsonb_build_object('schedule_id', p_aggregate_id, 'station_id', p_station_id);
            v_render_data := jsonb_build_object('station_name', v_station_name, 'version', p_payload->>'version');

        WHEN 'SHIFT_ASSIGNED' THEN
            v_title_key := 'notif_shift_assigned_title';
            v_body_key := 'notif_shift_assigned_body';
            v_action_type := 'NAVIGATE_SCHEDULE';
            v_action_data := jsonb_build_object('schedule_id', p_aggregate_id, 'station_id', p_station_id);
            v_render_data := jsonb_build_object(
                'shift_name', p_payload->>'shift_name',
                'operational_date', p_payload->>'operational_date',
                'station_name', v_station_name
            );

        WHEN 'SHIFT_REMOVED' THEN
            v_title_key := 'notif_shift_removed_title';
            v_body_key := 'notif_shift_removed_body';
            v_action_type := 'NAVIGATE_SCHEDULE';
            v_action_data := jsonb_build_object('schedule_id', p_aggregate_id, 'station_id', p_station_id);
            v_render_data := jsonb_build_object(
                'shift_name', p_payload->>'shift_name',
                'operational_date', p_payload->>'operational_date',
                'station_name', v_station_name
            );

        -- Attendance Events
        WHEN 'EMPLOYEE_CHECKED_IN' THEN
            v_title_key := 'notif_emp_checked_in_title';
            v_body_key := 'notif_emp_checked_in_body';
            v_action_type := 'NAVIGATE_ATTENDANCE';
            v_action_data := jsonb_build_object('attendance_id', p_aggregate_id, 'station_id', p_station_id);
            v_render_data := jsonb_build_object(
                'employee_name', p_payload->>'employee_name',
                'shift_name', p_payload->>'shift_name',
                'station_name', v_station_name,
                'check_in_time', p_payload->>'check_in_time'
            );

        WHEN 'EMPLOYEE_CHECKED_OUT' THEN
            v_title_key := 'notif_emp_checked_out_title';
            v_body_key := 'notif_emp_checked_out_body';
            v_action_type := 'NAVIGATE_ATTENDANCE';
            v_action_data := jsonb_build_object('attendance_id', p_aggregate_id, 'station_id', p_station_id);
            v_render_data := jsonb_build_object(
                'employee_name', p_payload->>'employee_name',
                'shift_name', p_payload->>'shift_name',
                'station_name', v_station_name,
                'worked_minutes', p_payload->>'worked_minutes'
            );

        WHEN 'CHECK_IN_CONFIRMED' THEN
            v_title_key := 'notif_check_in_confirmed_title';
            v_body_key := 'notif_check_in_confirmed_body';
            v_action_type := 'NAVIGATE_ATTENDANCE';
            v_action_data := jsonb_build_object('attendance_id', p_aggregate_id, 'station_id', p_station_id);
            v_render_data := jsonb_build_object(
                'shift_name', p_payload->>'shift_name',
                'station_name', v_station_name
            );

        WHEN 'CHECK_OUT_CONFIRMED' THEN
            v_title_key := 'notif_check_out_confirmed_title';
            v_body_key := 'notif_check_out_confirmed_body';
            v_action_type := 'NAVIGATE_ATTENDANCE';
            v_action_data := jsonb_build_object('attendance_id', p_aggregate_id, 'station_id', p_station_id);
            v_render_data := jsonb_build_object(
                'worked_minutes', p_payload->>'worked_minutes',
                'station_name', v_station_name
            );

        WHEN 'EMPLOYEE_LATE' THEN
            v_title_key := 'notif_emp_late_title';
            v_body_key := 'notif_emp_late_body';
            v_action_type := 'NAVIGATE_ATTENDANCE';
            v_action_data := jsonb_build_object('attendance_id', p_aggregate_id, 'station_id', p_station_id);
            v_render_data := jsonb_build_object(
                'employee_name', p_payload->>'employee_name',
                'shift_name', p_payload->>'shift_name',
                'late_minutes', p_payload->>'late_minutes',
                'station_name', v_station_name
            );

        WHEN 'EMPLOYEE_MISSED_CHECK_IN' THEN
            v_title_key := 'notif_emp_missed_check_in_title';
            v_body_key := 'notif_emp_missed_check_in_body';
            v_action_type := 'NAVIGATE_ATTENDANCE';
            v_action_data := jsonb_build_object('station_id', p_station_id);
            v_render_data := jsonb_build_object(
                'employee_name', p_payload->>'employee_name',
                'shift_name', p_payload->>'shift_name',
                'starts_at', p_payload->>'starts_at',
                'station_name', v_station_name
            );

        WHEN 'ATTENDANCE_MANUALLY_CORRECTED' THEN
            v_title_key := 'notif_attendance_corrected_title';
            v_body_key := 'notif_attendance_corrected_body';
            v_action_type := 'NAVIGATE_ATTENDANCE';
            v_action_data := jsonb_build_object('attendance_id', p_aggregate_id, 'station_id', p_station_id);
            v_render_data := jsonb_build_object(
                'employee_name', p_payload->>'employee_name',
                'reason', p_payload->>'reason',
                'station_name', v_station_name
            );
            v_is_mandatory := true;

        -- Availability Reminders
        WHEN 'AVAILABILITY_SUBMISSION_REMINDER' THEN
            v_title_key := 'notif_avail_reminder_title';
            v_body_key := 'notif_avail_reminder_body';
            v_action_type := 'NAVIGATE_AVAILABILITY';
            v_action_data := jsonb_build_object('period_id', p_aggregate_id, 'station_id', p_station_id);
            v_render_data := jsonb_build_object(
                'station_name', v_station_name,
                'deadline', p_payload->>'deadline'
            );

        WHEN 'AVAILABILITY_DEADLINE_APPROACHING' THEN
            v_title_key := 'notif_avail_deadline_title';
            v_body_key := 'notif_avail_deadline_body';
            v_action_type := 'NAVIGATE_AVAILABILITY';
            v_action_data := jsonb_build_object('period_id', p_aggregate_id, 'station_id', p_station_id);
            v_render_data := jsonb_build_object(
                'station_name', v_station_name,
                'hours_remaining', p_payload->>'hours_remaining'
            );

        -- Kiosk Events
        WHEN 'KIOSK_OFFLINE' THEN
            v_title_key := 'notif_kiosk_offline_title';
            v_body_key := 'notif_kiosk_offline_body';
            v_action_type := 'NAVIGATE_KIOSK';
            v_action_data := jsonb_build_object('kiosk_id', p_aggregate_id, 'station_id', p_station_id);
            v_render_data := jsonb_build_object(
                'kiosk_name', p_payload->>'kiosk_name',
                'station_name', v_station_name,
                'minutes_offline', p_payload->>'minutes_offline'
            );
            v_is_mandatory := true;

        WHEN 'KIOSK_RECOVERED' THEN
            v_title_key := 'notif_kiosk_recovered_title';
            v_body_key := 'notif_kiosk_recovered_body';
            v_action_type := 'NAVIGATE_KIOSK';
            v_action_data := jsonb_build_object('kiosk_id', p_aggregate_id, 'station_id', p_station_id);
            v_render_data := jsonb_build_object(
                'kiosk_name', p_payload->>'kiosk_name',
                'station_name', v_station_name
            );

        -- Identity Verification Events
        WHEN 'IDENTITY_ADMIN_OVERRIDE_USED' THEN
            v_title_key := 'notif_identity_override_title';
            v_body_key := 'notif_identity_override_body';
            v_action_type := 'NAVIGATE_IDENTITY';
            v_action_data := jsonb_build_object('proof_id', p_aggregate_id, 'station_id', p_station_id);
            v_render_data := jsonb_build_object(
                'employee_name', p_payload->>'employee_name',
                'admin_name', p_payload->>'admin_name',
                'reason', p_payload->>'reason',
                'station_name', v_station_name
            );
            v_is_mandatory := true;

        WHEN 'IDENTITY_VERIFICATION_EXCEPTION' THEN
            v_title_key := 'notif_identity_exception_title';
            v_body_key := 'notif_identity_exception_body';
            v_action_type := 'NAVIGATE_IDENTITY';
            v_action_data := jsonb_build_object('station_id', p_station_id);
            v_render_data := jsonb_build_object(
                'employee_name', p_payload->>'employee_name',
                'failure_category', p_payload->>'failure_category',
                'station_name', v_station_name
            );

        WHEN 'IDENTITY_PROFILE_REVOKED' THEN
            v_title_key := 'notif_identity_revoked_title';
            v_body_key := 'notif_identity_revoked_body';
            v_action_type := 'NAVIGATE_IDENTITY';
            v_action_data := jsonb_build_object('station_id', p_station_id);
            v_render_data := jsonb_build_object(
                'employee_name', p_payload->>'employee_name',
                'reason', p_payload->>'reason',
                'station_name', v_station_name
            );
            v_is_mandatory := true;

        ELSE
            v_title_key := 'notif_generic_title';
            v_body_key := 'notif_generic_body';
            v_render_data := jsonb_build_object('event_type', p_event_type, 'station_name', v_station_name);
    END CASE;

    -- Resolve Recipients Loop
    FOR v_rec IN (
        -- 1. Explicit recipient passed in payload
        SELECT (p_payload->>'target_user_id')::UUID AS user_id
        WHERE p_payload ? 'target_user_id' AND (p_payload->>'target_user_id') IS NOT NULL
        UNION
        -- 2. Station management recipients for operational alerts
        SELECT r.recipient_user_id AS user_id
        FROM public.get_station_manager_recipients(p_station_id) r
        WHERE p_event_type IN (
            'EMPLOYEE_CHECKED_IN', 'EMPLOYEE_CHECKED_OUT', 'EMPLOYEE_LATE', 'EMPLOYEE_MISSED_CHECK_IN',
            'ATTENDANCE_MANUALLY_CORRECTED', 'KIOSK_OFFLINE', 'KIOSK_RECOVERED',
            'IDENTITY_ADMIN_OVERRIDE_USED', 'IDENTITY_VERIFICATION_EXCEPTION', 'IDENTITY_PROFILE_REVOKED',
            'SCHEDULE_PUBLICATION_COMPLETED'
        )
        UNION
        -- 3. All assigned employees in published schedule
        SELECT DISTINCT sa.user_id
        FROM public.shift_assignments sa
        JOIN public.work_schedule_shifts wss ON sa.work_schedule_shift_id = wss.id
        WHERE p_event_type = 'SCHEDULE_PUBLISHED' AND wss.work_schedule_id = p_aggregate_id
    ) LOOP
        v_recipient_id := v_rec.user_id;
        IF v_recipient_id IS NULL THEN
            CONTINUE;
        END IF;

        -- Resolve user preference for this category
        SELECT in_app_enabled, push_enabled, email_enabled, sms_enabled
        INTO v_in_app_enabled, v_push_enabled, v_email_enabled, v_sms_enabled
        FROM public.notification_preferences
        WHERE user_id = v_recipient_id AND category = p_category;

        IF NOT FOUND THEN
            v_in_app_enabled := true;
            v_push_enabled := true;
            v_email_enabled := false;
            v_sms_enabled := false;
        END IF;

        IF v_is_mandatory THEN
            v_in_app_enabled := true;
        END IF;

        IF v_in_app_enabled THEN
            v_notif_dedup := p_deduplication_key || ':' || v_recipient_id::text;
            v_notification_id := gen_random_uuid();

            INSERT INTO public.notifications (
                id, recipient_user_id, station_id, event_id, category, event_type,
                priority, title_key, body_key, render_data, action_type, action_data,
                is_mandatory, deduplication_key, created_at
            ) VALUES (
                v_notification_id, v_recipient_id, p_station_id, v_event_id, p_category, p_event_type,
                p_priority, v_title_key, v_body_key, v_render_data, v_action_type, v_action_data,
                v_is_mandatory, v_notif_dedup, v_now
            )
            ON CONFLICT (deduplication_key) DO NOTHING
            RETURNING id INTO v_notification_id;

            IF v_notification_id IS NOT NULL THEN
                IF v_push_enabled AND EXISTS (
                    SELECT 1 FROM public.notification_devices
                    WHERE user_id = v_recipient_id AND is_active = true AND revoked_at IS NULL
                ) THEN
                    INSERT INTO public.notification_delivery_jobs (
                        notification_id, recipient_user_id, channel, status, next_attempt_at
                    ) VALUES (
                        v_notification_id, v_recipient_id, 'PUSH', 'PENDING', v_now
                    );
                END IF;

                IF v_email_enabled THEN
                    INSERT INTO public.notification_delivery_jobs (
                        notification_id, recipient_user_id, channel, status, next_attempt_at
                    ) VALUES (
                        v_notification_id, v_recipient_id, 'EMAIL', 'PENDING', v_now
                    );
                END IF;

                IF v_sms_enabled THEN
                    INSERT INTO public.notification_delivery_jobs (
                        notification_id, recipient_user_id, channel, status, next_attempt_at
                    ) VALUES (
                        v_notification_id, v_recipient_id, 'SMS', 'PENDING', v_now
                    );
                END IF;
            END IF;
        END IF;
    END LOOP;

    RETURN v_event_id;
END;
$$;

-- 13. Public RPC: Get My Notifications
CREATE OR REPLACE FUNCTION public.get_my_notifications(
    p_limit INTEGER DEFAULT 20,
    p_cursor_created_at TIMESTAMPTZ DEFAULT NULL,
    p_cursor_id UUID DEFAULT NULL,
    p_category public.notification_category DEFAULT NULL,
    p_unread_only BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_limit INTEGER;
    v_items JSONB := '[]'::jsonb;
    v_has_more BOOLEAN := false;
    v_next_cursor_created_at TIMESTAMPTZ := NULL;
    v_next_cursor_id UUID := NULL;
    v_count INTEGER := 0;
    v_row RECORD;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_limit := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 50);

    FOR v_row IN
        SELECT n.*
        FROM public.notifications n
        WHERE n.recipient_user_id = v_caller_id
          AND (p_category IS NULL OR n.category = p_category)
          AND (NOT p_unread_only OR n.read_at IS NULL)
          AND (
              p_cursor_created_at IS NULL
              OR (n.created_at, n.id) < (p_cursor_created_at, p_cursor_id)
          )
        ORDER BY n.created_at DESC, n.id DESC
        LIMIT v_limit + 1
    LOOP
        v_count := v_count + 1;
        IF v_count <= v_limit THEN
            v_items := v_items || jsonb_build_array(
                jsonb_build_object(
                    'id', v_row.id,
                    'station_id', v_row.station_id,
                    'category', v_row.category,
                    'event_type', v_row.event_type,
                    'priority', v_row.priority,
                    'title_key', v_row.title_key,
                    'body_key', v_row.body_key,
                    'render_data', v_row.render_data,
                    'action_type', v_row.action_type,
                    'action_data', v_row.action_data,
                    'is_mandatory', v_row.is_mandatory,
                    'read_at', v_row.read_at,
                    'seen_at', v_row.seen_at,
                    'created_at', v_row.created_at
                )
            );
            v_next_cursor_created_at := v_row.created_at;
            v_next_cursor_id := v_row.id;
        ELSE
            v_has_more := true;
        END IF;
    END LOOP;

    IF NOT v_has_more THEN
        v_next_cursor_created_at := NULL;
        v_next_cursor_id := NULL;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'items', v_items,
        'has_more', v_has_more,
        'next_cursor_created_at', v_next_cursor_created_at,
        'next_cursor_id', v_next_cursor_id
    );
END;
$$;

-- 14. Public RPC: Get Unread Notification Count
CREATE OR REPLACE FUNCTION public.get_unread_notification_count()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_unread_count INTEGER;
    v_critical_count INTEGER;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    SELECT count(*) INTO v_unread_count
    FROM public.notifications
    WHERE recipient_user_id = v_caller_id AND read_at IS NULL;

    SELECT count(*) INTO v_critical_count
    FROM public.notifications
    WHERE recipient_user_id = v_caller_id AND read_at IS NULL AND priority = 'CRITICAL';

    RETURN jsonb_build_object(
        'success', true,
        'unread_count', v_unread_count,
        'critical_count', v_critical_count
    );
END;
$$;

-- 15. Public RPC: Mark Notification Read
CREATE OR REPLACE FUNCTION public.mark_notification_read(p_notification_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_notif RECORD;
    v_now TIMESTAMPTZ := now();
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_notif
    FROM public.notifications
    WHERE id = p_notification_id AND recipient_user_id = v_caller_id
    FOR UPDATE;

    IF v_notif.id IS NULL THEN
        RAISE EXCEPTION 'Notification not found' USING ERRCODE = 'P0060';
    END IF;

    IF v_notif.read_at IS NULL THEN
        UPDATE public.notifications
        SET read_at = v_now,
            seen_at = COALESCE(seen_at, v_now)
        WHERE id = v_notif.id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'notification_id', v_notif.id,
        'read_at', COALESCE(v_notif.read_at, v_now)
    );
END;
$$;

-- 16. Public RPC: Mark All Notifications Read
CREATE OR REPLACE FUNCTION public.mark_all_notifications_read(
    p_category public.notification_category DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_updated_count INTEGER;
    v_now TIMESTAMPTZ := now();
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    WITH updated AS (
        UPDATE public.notifications
        SET read_at = v_now,
            seen_at = COALESCE(seen_at, v_now)
        WHERE recipient_user_id = v_caller_id
          AND read_at IS NULL
          AND (p_category IS NULL OR category = p_category)
        RETURNING id
    )
    SELECT count(*) INTO v_updated_count FROM updated;

    RETURN jsonb_build_object(
        'success', true,
        'marked_read_count', v_updated_count
    );
END;
$$;

-- 17. Public RPC: Get & Update Notification Preferences
CREATE OR REPLACE FUNCTION public.get_my_notification_preferences()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_prefs JSONB;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    WITH all_categories AS (
        SELECT unnest(enum_range(NULL::public.notification_category)) AS cat
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'category', c.cat,
            'in_app_enabled', COALESCE(p.in_app_enabled, true),
            'push_enabled', COALESCE(p.push_enabled, true),
            'email_enabled', COALESCE(p.email_enabled, false),
            'sms_enabled', COALESCE(p.sms_enabled, false)
        ) ORDER BY c.cat
    )
    INTO v_prefs
    FROM all_categories c
    LEFT JOIN public.notification_preferences p
      ON p.user_id = v_caller_id AND p.category = c.cat;

    RETURN jsonb_build_object(
        'success', true,
        'preferences', COALESCE(v_prefs, '[]'::jsonb)
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.update_my_notification_preferences(
    p_category public.notification_category,
    p_in_app_enabled BOOLEAN,
    p_push_enabled BOOLEAN,
    p_email_enabled BOOLEAN,
    p_sms_enabled BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_now TIMESTAMPTZ := now();
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.notification_preferences (
        user_id, category, in_app_enabled, push_enabled, email_enabled, sms_enabled, created_at, updated_at
    ) VALUES (
        v_caller_id, p_category, p_in_app_enabled, p_push_enabled, p_email_enabled, p_sms_enabled, v_now, v_now
    )
    ON CONFLICT (user_id, category) DO UPDATE
    SET in_app_enabled = EXCLUDED.in_app_enabled,
        push_enabled = EXCLUDED.push_enabled,
        email_enabled = EXCLUDED.email_enabled,
        sms_enabled = EXCLUDED.sms_enabled,
        updated_at = v_now;

    RETURN jsonb_build_object(
        'success', true,
        'category', p_category,
        'in_app_enabled', p_in_app_enabled,
        'push_enabled', p_push_enabled,
        'email_enabled', p_email_enabled,
        'sms_enabled', p_sms_enabled
    );
END;
$$;

-- 18. Public RPC: Register / Revoke Push Device
CREATE OR REPLACE FUNCTION public.register_notification_device(
    p_platform TEXT,
    p_provider TEXT,
    p_device_token TEXT,
    p_device_label TEXT DEFAULT 'Device'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_clean_token TEXT;
    v_token_hash TEXT;
    v_device_id UUID;
    v_now TIMESTAMPTZ := now();
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_clean_token := trim(p_device_token);
    IF v_clean_token IS NULL OR length(v_clean_token) < 8 THEN
        RAISE EXCEPTION 'Invalid device push token' USING ERRCODE = 'P0061';
    END IF;

    IF p_platform NOT IN ('ios', 'android', 'web', 'macos', 'windows') THEN
        RAISE EXCEPTION 'Unsupported platform' USING ERRCODE = 'P0062';
    END IF;

    IF p_provider NOT IN ('fcm', 'apns', 'webpush', 'mock') THEN
        RAISE EXCEPTION 'Unsupported push provider' USING ERRCODE = 'P0063';
    END IF;

    v_token_hash := encode(sha256(v_clean_token::bytea), 'hex');

    INSERT INTO public.notification_devices (
        user_id, platform, provider, device_token_hash, device_label, is_active, last_seen_at, created_at, revoked_at
    ) VALUES (
        v_caller_id, p_platform, p_provider, v_token_hash, COALESCE(trim(p_device_label), 'Device'), true, v_now, v_now, NULL
    )
    ON CONFLICT (user_id, device_token_hash) DO UPDATE
    SET is_active = true,
        device_label = EXCLUDED.device_label,
        last_seen_at = v_now,
        revoked_at = NULL
    RETURNING id INTO v_device_id;

    RETURN jsonb_build_object(
        'success', true,
        'device_id', v_device_id,
        'platform', p_platform,
        'is_active', true
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.revoke_notification_device(p_device_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_now TIMESTAMPTZ := now();
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    UPDATE public.notification_devices
    SET is_active = false,
        revoked_at = v_now
    WHERE id = p_device_id AND user_id = v_caller_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Device not found or not owned by user' USING ERRCODE = 'P0064';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'device_id', p_device_id,
        'revoked_at', v_now
    );
END;
$$;

-- 19. Outbox Worker Claiming & Retry Management (Service-Role Only)
CREATE OR REPLACE FUNCTION public.claim_notification_delivery_jobs(
    p_batch_size INTEGER DEFAULT 10,
    p_lease_seconds INTEGER DEFAULT 60
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_lock_token UUID;
    v_now TIMESTAMPTZ := now();
    v_lease_expires TIMESTAMPTZ;
    v_claimed_jobs JSONB;
    v_limit INTEGER;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NOT NULL THEN
        RAISE EXCEPTION 'Access denied: Worker claiming requires service_role privilege' USING ERRCODE = '42501';
    END IF;

    v_limit := LEAST(GREATEST(COALESCE(p_batch_size, 10), 1), 100);
    v_lock_token := gen_random_uuid();
    v_lease_expires := v_now + (LEAST(GREATEST(COALESCE(p_lease_seconds, 60), 10), 600) * INTERVAL '1 second');

    WITH candidate_jobs AS (
        SELECT j.id
        FROM public.notification_delivery_jobs j
        WHERE (
            (j.status IN ('PENDING', 'RETRY') AND j.next_attempt_at <= v_now)
            OR
            (j.status = 'PROCESSING' AND j.lease_expires_at < v_now)
        )
        ORDER BY j.next_attempt_at ASC, j.created_at ASC
        LIMIT v_limit
        FOR UPDATE SKIP LOCKED
    ),
    locked_jobs AS (
        UPDATE public.notification_delivery_jobs j
        SET status = 'PROCESSING',
            lock_token = v_lock_token,
            locked_at = v_now,
            lease_expires_at = v_lease_expires,
            started_at = COALESCE(j.started_at, v_now),
            attempt_count = j.attempt_count + 1
        FROM candidate_jobs c
        WHERE j.id = c.id
        RETURNING j.id, j.notification_id, j.recipient_user_id, j.channel, j.attempt_count, j.max_attempts
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'job_id', lj.id,
            'notification_id', lj.notification_id,
            'recipient_user_id', lj.recipient_user_id,
            'channel', lj.channel,
            'attempt_count', lj.attempt_count,
            'max_attempts', lj.max_attempts,
            'lock_token', v_lock_token,
            'title_key', n.title_key,
            'body_key', n.body_key,
            'render_data', n.render_data,
            'priority', n.priority
        )
    )
    INTO v_claimed_jobs
    FROM locked_jobs lj
    JOIN public.notifications n ON lj.notification_id = n.id;

    RETURN jsonb_build_object(
        'success', true,
        'lock_token', v_lock_token,
        'claimed_count', COALESCE(jsonb_array_length(v_claimed_jobs), 0),
        'jobs', COALESCE(v_claimed_jobs, '[]'::jsonb)
    );
END;
$$;

-- 20. Outbox Worker: Record Delivery Attempt Outcome (Service-Role Only)
CREATE OR REPLACE FUNCTION public.record_delivery_attempt_outcome(
    p_job_id UUID,
    p_lock_token UUID,
    p_outcome public.delivery_attempt_outcome,
    p_provider TEXT,
    p_provider_response_code TEXT DEFAULT NULL,
    p_error_category TEXT DEFAULT NULL,
    p_provider_message_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_job RECORD;
    v_now TIMESTAMPTZ := now();
    v_next_delay INTEGER;
    v_new_status public.delivery_job_status;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NOT NULL THEN
        RAISE EXCEPTION 'Access denied: Attempt recording requires service_role privilege' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_job
    FROM public.notification_delivery_jobs
    WHERE id = p_job_id AND lock_token = p_lock_token
    FOR UPDATE;

    IF v_job.id IS NULL THEN
        RAISE EXCEPTION 'Delivery job not found or lock token mismatch' USING ERRCODE = 'P0065';
    END IF;

    INSERT INTO public.notification_delivery_attempts (
        delivery_job_id, attempt_number, provider, channel, started_at, finished_at,
        outcome, error_category, provider_response_code
    ) VALUES (
        p_job_id, v_job.attempt_count, COALESCE(trim(p_provider), 'UNKNOWN'), v_job.channel,
        COALESCE(v_job.locked_at, v_now), v_now, p_outcome, p_error_category, p_provider_response_code
    );

    IF p_outcome = 'SUCCESS' THEN
        UPDATE public.notification_delivery_jobs
        SET status = 'DELIVERED',
            delivered_at = v_now,
            provider = p_provider,
            provider_message_id = p_provider_message_id,
            lock_token = NULL,
            lease_expires_at = NULL
        WHERE id = p_job_id;

        RETURN jsonb_build_object('success', true, 'status', 'DELIVERED');
    ELSIF p_outcome = 'TEMPORARY_FAILURE' AND v_job.attempt_count < v_job.max_attempts THEN
        CASE v_job.attempt_count
            WHEN 1 THEN v_next_delay := 60;
            WHEN 2 THEN v_next_delay := 300;
            WHEN 3 THEN v_next_delay := 900;
            ELSE v_next_delay := 3600;
        END CASE;

        UPDATE public.notification_delivery_jobs
        SET status = 'RETRY',
            next_attempt_at = v_now + (v_next_delay * INTERVAL '1 second'),
            provider = p_provider,
            last_error_category = p_error_category,
            lock_token = NULL,
            lease_expires_at = NULL
        WHERE id = p_job_id;

        RETURN jsonb_build_object('success', true, 'status', 'RETRY', 'next_attempt_at', v_now + (v_next_delay * INTERVAL '1 second'));
    ELSE
        UPDATE public.notification_delivery_jobs
        SET status = 'FAILED',
            failed_at = v_now,
            provider = p_provider,
            last_error_category = p_error_category,
            lock_token = NULL,
            lease_expires_at = NULL
        WHERE id = p_job_id;

        RETURN jsonb_build_object('success', true, 'status', 'FAILED');
    END IF;
END;
$$;

-- 21. Scheduled Evaluator: Kiosk Health & Offline Transitions
CREATE OR REPLACE FUNCTION public.evaluate_kiosk_health_transitions(
    p_station_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_kiosk RECORD;
    v_offline_threshold INTERVAL := INTERVAL '3 minutes';
    v_now TIMESTAMPTZ := now();
    v_is_offline BOOLEAN;
    v_health RECORD;
    v_offline_transitions INTEGER := 0;
    v_recovery_transitions INTEGER := 0;
    v_minutes_offline INTEGER;
    v_dedup TEXT;
BEGIN
    FOR v_kiosk IN (
        SELECT k.id, k.station_id, k.name, k.last_seen_at, k.is_active, s.name AS station_name
        FROM public.kiosk_devices k
        JOIN public.stations s ON k.station_id = s.id
        WHERE k.is_active = true AND s.is_active = true
          AND (p_station_id IS NULL OR k.station_id = p_station_id)
    ) LOOP
        v_is_offline := (v_kiosk.last_seen_at IS NULL OR v_kiosk.last_seen_at < (v_now - v_offline_threshold));

        SELECT * INTO v_health
        FROM public.kiosk_health_states
        WHERE kiosk_device_id = v_kiosk.id
        FOR UPDATE;

        IF v_health.kiosk_device_id IS NULL THEN
            INSERT INTO public.kiosk_health_states (
                kiosk_device_id, station_id, current_status, last_transition_at, updated_at
            ) VALUES (
                v_kiosk.id, v_kiosk.station_id, 'ONLINE', v_now, v_now
            )
            ON CONFLICT (kiosk_device_id) DO NOTHING;
            v_health.current_status := 'ONLINE';
        END IF;

        IF v_is_offline AND v_health.current_status = 'ONLINE' THEN
            v_minutes_offline := GREATEST(3, floor(extract(epoch from (v_now - COALESCE(v_kiosk.last_seen_at, v_now - INTERVAL '3 minutes'))) / 60.0)::INTEGER);
            v_dedup := 'kiosk-offline:' || v_kiosk.id::text || ':' || to_char(v_now, 'YYYYMMDD-HH24MI');

            PERFORM public.emit_notification_event(
                v_kiosk.station_id,
                'KIOSK_OFFLINE',
                'OPERATIONS',
                'HIGH',
                'kiosk_device',
                v_kiosk.id,
                NULL,
                jsonb_build_object(
                    'kiosk_name', v_kiosk.name,
                    'minutes_offline', v_minutes_offline
                ),
                v_dedup
            );

            UPDATE public.kiosk_health_states
            SET current_status = 'OFFLINE', last_transition_at = v_now, updated_at = v_now
            WHERE kiosk_device_id = v_kiosk.id;

            v_offline_transitions := v_offline_transitions + 1;

        ELSIF NOT v_is_offline AND v_health.current_status = 'OFFLINE' THEN
            v_dedup := 'kiosk-recovered:' || v_kiosk.id::text || ':' || to_char(v_now, 'YYYYMMDD-HH24MI');

            PERFORM public.emit_notification_event(
                v_kiosk.station_id,
                'KIOSK_RECOVERED',
                'OPERATIONS',
                'NORMAL',
                'kiosk_device',
                v_kiosk.id,
                NULL,
                jsonb_build_object(
                    'kiosk_name', v_kiosk.name
                ),
                v_dedup
            );

            UPDATE public.kiosk_health_states
            SET current_status = 'ONLINE', last_transition_at = v_now, updated_at = v_now
            WHERE kiosk_device_id = v_kiosk.id;

            v_recovery_transitions := v_recovery_transitions + 1;
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'offline_transitions', v_offline_transitions,
        'recovery_transitions', v_recovery_transitions
    );
END;
$$;

-- 22. Scheduled Evaluator: Due Reminders & Missed Check-Ins (Cron / Edge Function Entry Point)
CREATE OR REPLACE FUNCTION public.generate_due_notification_reminders()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_now TIMESTAMPTZ := now();
    v_reminders_count INTEGER := 0;
    v_missed_checkins INTEGER := 0;
    v_rec RECORD;
    v_dedup TEXT;
BEGIN
    -- 1. Availability Period Deadlines Approaching (e.g. within 24 hours of deadline)
    FOR v_rec IN (
        SELECT ap.id AS period_id, ap.station_id, ap.submission_deadline, ap.week_start_date,
               sm.user_id, p.first_name, p.last_name
        FROM public.availability_periods ap
        JOIN public.station_memberships sm ON ap.station_id = sm.station_id
        JOIN public.profiles p ON sm.user_id = p.id
        WHERE ap.status = 'OPEN'
          AND sm.status = 'ACTIVE'
          AND sm.role = 'EMPLOYEE'
          AND ap.submission_deadline > v_now
          AND ap.submission_deadline <= (v_now + INTERVAL '24 hours')
          -- Exclude employees who already submitted
          AND NOT EXISTS (
              SELECT 1 FROM public.availability_submissions sub
              WHERE sub.availability_period_id = ap.id AND sub.membership_id = sm.id AND sub.status = 'SUBMITTED'
          )
    ) LOOP
        v_dedup := 'avail-deadline-24h:' || v_rec.period_id::text || ':' || v_rec.user_id::text;

        PERFORM public.emit_notification_event(
            v_rec.station_id,
            'AVAILABILITY_DEADLINE_APPROACHING',
            'AVAILABILITY',
            'NORMAL',
            'availability_period',
            v_rec.period_id,
            NULL,
            jsonb_build_object(
                'target_user_id', v_rec.user_id,
                'hours_remaining', GREATEST(1, floor(extract(epoch from (v_rec.submission_deadline - v_now)) / 3600.0)::INTEGER),
                'deadline', v_rec.submission_deadline
            ),
            v_dedup
        );
        v_reminders_count := v_reminders_count + 1;
    END LOOP;

    -- 2. Missed Check-Ins: Scheduled shifts whose start time + late_grace_minutes + 15m passed without open record
    FOR v_rec IN (
        SELECT wss.id AS shift_id, wss.station_id, wss.shift_name_snapshot, wss.starts_at,
               sa.user_id, p.first_name, p.last_name, s.late_grace_minutes
        FROM public.shift_assignments sa
        JOIN public.work_schedule_shifts wss ON sa.work_schedule_shift_id = wss.id
        JOIN public.work_schedules ws ON wss.work_schedule_id = ws.id
        JOIN public.stations s ON wss.station_id = s.id
        JOIN public.profiles p ON sa.user_id = p.id
        WHERE ws.status = 'PUBLISHED'
          AND v_now >= (wss.starts_at + ((s.late_grace_minutes + 15) * INTERVAL '1 minute'))
          AND v_now < wss.ends_at
          AND NOT EXISTS (
              SELECT 1 FROM public.attendance_records ar
              WHERE ar.shift_assignment_id = sa.id
          )
    ) LOOP
        v_dedup := 'missed-checkin:' || v_rec.shift_id::text || ':' || v_rec.user_id::text;

        PERFORM public.emit_notification_event(
            v_rec.station_id,
            'EMPLOYEE_MISSED_CHECK_IN',
            'ATTENDANCE',
            'HIGH',
            'work_schedule_shift',
            v_rec.shift_id,
            NULL,
            jsonb_build_object(
                'employee_name', v_rec.first_name || ' ' || v_rec.last_name,
                'shift_name', v_rec.shift_name_snapshot,
                'starts_at', v_rec.starts_at
            ),
            v_dedup
        );
        v_missed_checkins := v_missed_checkins + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'availability_reminders_emitted', v_reminders_count,
        'missed_checkins_emitted', v_missed_checkins
    );
END;
$$;

-- 23. Retention & Maintenance RPC (Service-Role Only)
CREATE OR REPLACE FUNCTION public.cleanup_expired_notifications(
    p_retention_days INTEGER DEFAULT 90
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_days INTEGER;
    v_purged_jobs INTEGER := 0;
    v_purged_events INTEGER := 0;
    v_purged_notifs INTEGER := 0;
    v_cutoff TIMESTAMPTZ;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NOT NULL THEN
        RAISE EXCEPTION 'Access denied: Maintenance requires service_role privilege' USING ERRCODE = '42501';
    END IF;

    v_days := LEAST(GREATEST(COALESCE(p_retention_days, 90), 30), 365);
    v_cutoff := now() - (v_days * INTERVAL '1 day');

    WITH deleted_jobs AS (
        DELETE FROM public.notification_delivery_jobs
        WHERE status IN ('DELIVERED', 'FAILED', 'CANCELLED')
          AND created_at < v_cutoff
        RETURNING id
    )
    SELECT count(*) INTO v_purged_jobs FROM deleted_jobs;

    WITH deleted_notifs AS (
        DELETE FROM public.notifications
        WHERE read_at IS NOT NULL
          AND created_at < v_cutoff
          AND NOT EXISTS (
              SELECT 1 FROM public.notification_delivery_jobs j
              WHERE j.notification_id = notifications.id AND j.status IN ('PENDING', 'PROCESSING', 'RETRY')
          )
        RETURNING id
    )
    SELECT count(*) INTO v_purged_notifs FROM deleted_notifs;

    WITH deleted_events AS (
        DELETE FROM public.notification_events
        WHERE status = 'PROCESSED'
          AND occurred_at < v_cutoff
          AND NOT EXISTS (
              SELECT 1 FROM public.notifications n WHERE n.event_id = notification_events.id
          )
        RETURNING id
    )
    SELECT count(*) INTO v_purged_events FROM deleted_events;

    RETURN jsonb_build_object(
        'success', true,
        'purged_delivery_jobs', v_purged_jobs,
        'purged_notifications', v_purged_notifs,
        'purged_events', v_purged_events
    );
END;
$$;

-- 24. INTEGRATION: Update Existing Domain RPCs with Notification Emission

-- A. Publish Schedule Notification Integration
CREATE OR REPLACE FUNCTION public.publish_work_schedule(
    p_schedule_id UUID,
    p_expected_version INTEGER,
    p_confirm_warnings BOOLEAN DEFAULT false
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_schedule RECORD;
    v_validation JSONB;
    v_new_version INTEGER;
    v_dedup TEXT;
BEGIN
    v_caller_id := auth.uid();

    SELECT * INTO v_schedule
    FROM public.work_schedules
    WHERE id = p_schedule_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Work schedule not found' USING ERRCODE = 'P0002';
    END IF;

    IF NOT public.has_station_permission(v_schedule.station_id, v_caller_id, 'schedule.publish') THEN
        RAISE EXCEPTION 'Access denied: caller does not have schedule.publish permission'
            USING ERRCODE = '42501';
    END IF;

    IF v_schedule.status <> 'DRAFT' THEN
        RAISE EXCEPTION 'Only DRAFT schedules can be published' USING ERRCODE = '22000';
    END IF;

    IF v_schedule.version <> p_expected_version THEN
        RAISE EXCEPTION 'Schedule version conflict: expected version %, but current version has changed', p_expected_version
            USING ERRCODE = 'P0005';
    END IF;

    v_validation := public.validate_work_schedule(p_schedule_id);

    IF (v_validation->>'hard_errors_count')::integer > 0 THEN
        RAISE EXCEPTION 'Cannot publish schedule with % hard errors: %',
            v_validation->>'hard_errors_count', v_validation->'hard_errors'
            USING ERRCODE = 'P0011';
    END IF;

    IF (v_validation->>'warnings_count')::integer > 0 AND NOT COALESCE(p_confirm_warnings, false) THEN
        RAISE EXCEPTION 'Schedule has % warnings that require explicit confirmation before publishing',
            v_validation->>'warnings_count'
            USING ERRCODE = 'P0012';
    END IF;

    UPDATE public.work_schedules
    SET status = 'PUBLISHED',
        published_by = v_caller_id,
        published_at = now(),
        version = version + 1,
        updated_at = now()
    WHERE id = p_schedule_id
    RETURNING version INTO v_new_version;

    INSERT INTO public.work_schedule_changes (
        work_schedule_id, station_id, version_before, version_after, change_type, actor_id, reason, metadata
    ) VALUES (
        p_schedule_id, v_schedule.station_id, p_expected_version, v_new_version,
        'PUBLISHED', v_caller_id, 'Initial schedule publication',
        jsonb_build_object(
            'published_at', now(),
            'warnings_confirmed', p_confirm_warnings,
            'summary', v_validation->'summary'
        )
    );

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        v_schedule.station_id, v_caller_id, 'WORK_SCHEDULE_PUBLISHED', 'work_schedule', p_schedule_id::text,
        jsonb_build_object('published_at', now(), 'new_version', v_new_version)
    );

    v_dedup := 'schedule-published:' || p_schedule_id::text || ':' || v_new_version::text;
    PERFORM public.emit_notification_event(
        v_schedule.station_id,
        'SCHEDULE_PUBLISHED',
        'SCHEDULE',
        'NORMAL',
        'work_schedule',
        p_schedule_id,
        v_caller_id,
        jsonb_build_object(
            'week_start_date', v_schedule.week_start_date,
            'version', v_new_version
        ),
        v_dedup
    );

    PERFORM public.emit_notification_event(
        v_schedule.station_id,
        'SCHEDULE_PUBLICATION_COMPLETED',
        'SCHEDULE',
        'LOW',
        'work_schedule',
        p_schedule_id,
        v_caller_id,
        jsonb_build_object('version', v_new_version),
        'schedule-pub-comp:' || p_schedule_id::text || ':' || v_new_version::text
    );

    RETURN jsonb_build_object(
        'success', true,
        'schedule_id', p_schedule_id,
        'status', 'PUBLISHED',
        'published_at', now(),
        'new_version', v_new_version
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- B. Attendance Check-In Notification Integration
CREATE OR REPLACE FUNCTION public.check_in_with_presence_proof(
    p_presence_proof_token TEXT,
    p_identity_proof_token TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_token_hash TEXT;
    v_proof RECORD;
    v_station RECORD;
    v_kiosk RECORD;
    v_membership RECORD;
    v_shift RECORD;
    v_open_rec RECORD;
    v_id_proof RECORD;
    v_id_token_hash TEXT;
    v_profile RECORD;
    v_now TIMESTAMPTZ;
    v_new_att_id UUID;
    v_has_valid_id_proof BOOLEAN := false;
    v_ver_method public.attendance_verification_method := 'QR_ONLY';
    v_id_proof_id UUID := NULL;
    v_diff_minutes INTEGER;
    v_late_minutes INTEGER;
    v_emp_name TEXT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_now := now();
    v_token_hash := encode(sha256(p_presence_proof_token::bytea), 'hex');

    SELECT * INTO v_proof
    FROM public.attendance_presence_proofs
    WHERE token_hash = v_token_hash
    FOR UPDATE;

    IF v_proof.id IS NULL THEN
        RAISE EXCEPTION 'Invalid presence proof token' USING ERRCODE = 'P0025';
    END IF;

    IF v_proof.used_at IS NOT NULL THEN
        RAISE EXCEPTION 'Presence proof has already been used' USING ERRCODE = 'P0026';
    END IF;

    IF v_proof.employee_user_id != v_user_id THEN
        RAISE EXCEPTION 'Presence proof belongs to another employee' USING ERRCODE = 'P0028';
    END IF;

    IF v_proof.action != 'CHECK_IN' THEN
        RAISE EXCEPTION 'Presence proof action mismatch' USING ERRCODE = 'P0029';
    END IF;

    SELECT * INTO v_station FROM public.stations WHERE id = v_proof.station_id;
    IF v_station.id IS NULL OR NOT v_station.is_active THEN
        RAISE EXCEPTION 'Station is inactive or deactivated' USING ERRCODE = 'P0017';
    END IF;

    IF v_station.identity_verification_mode IN ('CHECK_IN_ONLY', 'CHECK_IN_AND_CHECK_OUT') THEN
        IF p_identity_proof_token IS NULL OR trim(p_identity_proof_token) = '' THEN
            RAISE EXCEPTION 'Identity verification is required for check-in at this station'
                USING ERRCODE = 'P0040';
        END IF;

        v_id_token_hash := encode(sha256(trim(p_identity_proof_token)::bytea), 'hex');

        SELECT * INTO v_id_proof
        FROM public.identity_verification_proofs
        WHERE token_hash = v_id_token_hash
        FOR UPDATE;

        IF v_id_proof.id IS NULL THEN
            RAISE EXCEPTION 'Invalid identity verification proof token' USING ERRCODE = 'P0050';
        END IF;

        IF v_id_proof.used_at IS NOT NULL THEN
            RAISE EXCEPTION 'Identity verification proof has already been used' USING ERRCODE = 'P0051';
        END IF;

        IF v_now >= v_id_proof.expires_at THEN
            RAISE EXCEPTION 'Identity verification proof has expired' USING ERRCODE = 'P0052';
        END IF;

        IF v_id_proof.employee_user_id != v_user_id THEN
            RAISE EXCEPTION 'Identity verification proof belongs to another employee' USING ERRCODE = 'P0053';
        END IF;

        IF v_id_proof.station_id != v_proof.station_id THEN
            RAISE EXCEPTION 'Identity verification proof belongs to another station' USING ERRCODE = 'P0054';
        END IF;

        IF v_id_proof.presence_proof_id != v_proof.id THEN
            RAISE EXCEPTION 'Identity verification proof is not bound to this presence challenge' USING ERRCODE = 'P0055';
        END IF;

        IF v_id_proof.action != 'CHECK_IN' THEN
            RAISE EXCEPTION 'Identity verification proof action mismatch' USING ERRCODE = 'P0056';
        END IF;

        IF NOT v_id_proof.is_override THEN
            SELECT * INTO v_profile
            FROM public.employee_identity_profiles
            WHERE employee_user_id = v_user_id
            FOR UPDATE;

            IF v_profile.id IS NULL OR v_profile.status != 'ACTIVE' THEN
                RAISE EXCEPTION 'Employee identity profile is revoked or inactive' USING ERRCODE = 'P0047';
            END IF;
        END IF;

        UPDATE public.identity_verification_proofs
        SET used_at = v_now
        WHERE id = v_id_proof.id;

        v_id_proof_id := v_id_proof.id;
        v_has_valid_id_proof := true;
        IF v_id_proof.is_override THEN
            v_ver_method := 'MANUAL_ADMIN';
        ELSE
            v_ver_method := 'QR_PLUS_IDENTITY';
        END IF;
    ELSE
        IF p_identity_proof_token IS NOT NULL AND trim(p_identity_proof_token) != '' THEN
            v_id_token_hash := encode(sha256(trim(p_identity_proof_token)::bytea), 'hex');
            SELECT * INTO v_id_proof
            FROM public.identity_verification_proofs
            WHERE token_hash = v_id_token_hash AND used_at IS NULL AND expires_at > v_now 
              AND employee_user_id = v_user_id AND presence_proof_id = v_proof.id
            FOR UPDATE;

            IF v_id_proof.id IS NOT NULL THEN
                UPDATE public.identity_verification_proofs SET used_at = v_now WHERE id = v_id_proof.id;
                v_id_proof_id := v_id_proof.id;
                v_has_valid_id_proof := true;
                IF v_id_proof.is_override THEN
                    v_ver_method := 'MANUAL_ADMIN';
                ELSE
                    v_ver_method := 'QR_PLUS_IDENTITY';
                END IF;
            END IF;
        END IF;
    END IF;

    IF v_has_valid_id_proof THEN
        IF v_proof.created_at < v_now - INTERVAL '180 seconds' THEN
            RAISE EXCEPTION 'Presence challenge has exceeded maximum bridge lifetime' USING ERRCODE = 'P0027';
        END IF;
    ELSE
        IF v_now >= v_proof.expires_at THEN
            RAISE EXCEPTION 'Presence proof has expired' USING ERRCODE = 'P0027';
        END IF;
    END IF;

    SELECT * INTO v_kiosk FROM public.kiosk_devices WHERE id = v_proof.kiosk_device_id;
    IF v_kiosk.id IS NULL OR NOT v_kiosk.is_active THEN
        RAISE EXCEPTION 'Kiosk device is inactive or deactivated' USING ERRCODE = 'P0018';
    END IF;

    SELECT * INTO v_membership FROM public.station_memberships WHERE id = v_proof.station_membership_id;
    IF v_membership.id IS NULL OR v_membership.status != 'ACTIVE' THEN
        RAISE EXCEPTION 'Employee membership is not active' USING ERRCODE = 'P0022';
    END IF;

    SELECT * INTO v_open_rec
    FROM public.attendance_records
    WHERE employee_user_id = v_user_id AND check_out_time IS NULL
    FOR UPDATE;

    IF v_open_rec.id IS NOT NULL THEN
        RAISE EXCEPTION 'Employee already has an open attendance session' USING ERRCODE = 'P0023';
    END IF;

    SELECT wss.id AS shift_id, wss.work_schedule_id, sa.id AS assignment_id,
           ws.version AS schedule_version, wss.shift_name_snapshot,
           wss.starts_at, wss.ends_at, wss.operational_date
    INTO v_shift
    FROM public.shift_assignments sa
    JOIN public.work_schedule_shifts wss ON sa.work_schedule_shift_id = wss.id
    JOIN public.work_schedules ws ON wss.work_schedule_id = ws.id
    WHERE sa.user_id = v_user_id
      AND wss.station_id = v_proof.station_id
      AND ws.status = 'PUBLISHED'
      AND (v_now >= (wss.starts_at - (v_station.check_in_early_minutes * INTERVAL '1 minute')))
      AND (v_now < wss.ends_at)
    ORDER BY abs(extract(epoch from (v_now - wss.starts_at))) ASC, wss.starts_at ASC, wss.id ASC
    LIMIT 1;

    IF v_shift.shift_id IS NULL THEN
        RAISE EXCEPTION 'No published shift assignment found for check-in window' USING ERRCODE = 'P0024';
    END IF;

    v_diff_minutes := floor(extract(epoch from (v_now - v_shift.starts_at)) / 60.0)::INTEGER;
    IF v_diff_minutes > v_station.late_grace_minutes THEN
        v_late_minutes := v_diff_minutes;
    ELSE
        v_late_minutes := 0;
    END IF;

    v_new_att_id := gen_random_uuid();

    INSERT INTO public.attendance_records (
        id, station_id, employee_user_id, station_membership_id,
        work_schedule_id, work_schedule_shift_id, shift_assignment_id,
        schedule_version_at_check_in, shift_name_snapshot,
        scheduled_start_at_snapshot, scheduled_end_at_snapshot,
        check_in_kiosk_device_id, check_in_time, late_minutes, status,
        verification_method, identity_verification_proof_id,
        created_at, updated_at
    ) VALUES (
        v_new_att_id, v_proof.station_id, v_user_id, v_membership.id,
        v_shift.work_schedule_id, v_shift.shift_id, v_shift.assignment_id,
        v_shift.schedule_version, v_shift.shift_name_snapshot,
        v_shift.starts_at, v_shift.ends_at,
        v_proof.kiosk_device_id, v_now, v_late_minutes, 'OPEN',
        v_ver_method, v_id_proof_id,
        v_now, v_now
    );

    UPDATE public.attendance_presence_proofs
    SET used_at = v_now
    WHERE id = v_proof.id;

    SELECT first_name || ' ' || last_name INTO v_emp_name FROM public.profiles WHERE id = v_user_id;

    -- 1. Emit EMPLOYEE_CHECKED_IN to station management
    PERFORM public.emit_notification_event(
        v_proof.station_id,
        'EMPLOYEE_CHECKED_IN',
        'ATTENDANCE',
        'NORMAL',
        'attendance_record',
        v_new_att_id,
        v_user_id,
        jsonb_build_object(
            'employee_name', COALESCE(v_emp_name, 'Employee'),
            'shift_name', v_shift.shift_name_snapshot,
            'check_in_time', v_now
        ),
        'att-checkin-mgr:' || v_new_att_id::text
    );

    -- 2. If late, emit EMPLOYEE_LATE (HIGH priority) to station management
    IF v_late_minutes > 0 THEN
        PERFORM public.emit_notification_event(
            v_proof.station_id,
            'EMPLOYEE_LATE',
            'ATTENDANCE',
            'HIGH',
            'attendance_record',
            v_new_att_id,
            v_user_id,
            jsonb_build_object(
                'employee_name', COALESCE(v_emp_name, 'Employee'),
                'shift_name', v_shift.shift_name_snapshot,
                'late_minutes', v_late_minutes
            ),
            'att-late-mgr:' || v_new_att_id::text
        );
    END IF;

    -- 3. Emit CHECK_IN_CONFIRMED to the employee
    PERFORM public.emit_notification_event(
        v_proof.station_id,
        'CHECK_IN_CONFIRMED',
        'ATTENDANCE',
        'LOW',
        'attendance_record',
        v_new_att_id,
        v_user_id,
        jsonb_build_object(
            'target_user_id', v_user_id,
            'shift_name', v_shift.shift_name_snapshot
        ),
        'att-checkin-self:' || v_new_att_id::text
    );

    RETURN jsonb_build_object(
        'success', true,
        'attendance_id', v_new_att_id,
        'station_id', v_proof.station_id,
        'employee_user_id', v_user_id,
        'check_in_time', v_now,
        'shift_name', v_shift.shift_name_snapshot,
        'status', 'OPEN',
        'late_minutes', v_late_minutes,
        'verification_method', v_ver_method
    );
END;
$$;

-- C. Attendance Check-Out Notification Integration
CREATE OR REPLACE FUNCTION public.check_out_with_presence_proof(
    p_presence_proof_token TEXT,
    p_identity_proof_token TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_token_hash TEXT;
    v_proof RECORD;
    v_station RECORD;
    v_kiosk RECORD;
    v_att RECORD;
    v_id_proof RECORD;
    v_id_token_hash TEXT;
    v_profile RECORD;
    v_now TIMESTAMPTZ;
    v_worked_minutes INTEGER;
    v_has_valid_id_proof BOOLEAN := false;
    v_emp_name TEXT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_now := now();
    v_token_hash := encode(sha256(p_presence_proof_token::bytea), 'hex');

    SELECT * INTO v_proof
    FROM public.attendance_presence_proofs
    WHERE token_hash = v_token_hash
    FOR UPDATE;

    IF v_proof.id IS NULL THEN
        RAISE EXCEPTION 'Invalid presence proof token' USING ERRCODE = 'P0025';
    END IF;

    IF v_proof.used_at IS NOT NULL THEN
        RAISE EXCEPTION 'Presence proof has already been used' USING ERRCODE = 'P0026';
    END IF;

    IF v_proof.employee_user_id != v_user_id THEN
        RAISE EXCEPTION 'Presence proof belongs to another employee' USING ERRCODE = 'P0028';
    END IF;

    IF v_proof.action != 'CHECK_OUT' THEN
        RAISE EXCEPTION 'Presence proof action mismatch' USING ERRCODE = 'P0029';
    END IF;

    SELECT * INTO v_station FROM public.stations WHERE id = v_proof.station_id;
    IF v_station.id IS NULL OR NOT v_station.is_active THEN
        RAISE EXCEPTION 'Station is inactive or deactivated' USING ERRCODE = 'P0017';
    END IF;

    IF v_station.identity_verification_mode = 'CHECK_IN_AND_CHECK_OUT' THEN
        IF p_identity_proof_token IS NULL OR trim(p_identity_proof_token) = '' THEN
            RAISE EXCEPTION 'Identity verification is required for check-out at this station'
                USING ERRCODE = 'P0040';
        END IF;

        v_id_token_hash := encode(sha256(trim(p_identity_proof_token)::bytea), 'hex');

        SELECT * INTO v_id_proof
        FROM public.identity_verification_proofs
        WHERE token_hash = v_id_token_hash
        FOR UPDATE;

        IF v_id_proof.id IS NULL THEN
            RAISE EXCEPTION 'Invalid identity verification proof token' USING ERRCODE = 'P0050';
        END IF;

        IF v_id_proof.used_at IS NOT NULL THEN
            RAISE EXCEPTION 'Identity verification proof has already been used' USING ERRCODE = 'P0051';
        END IF;

        IF v_now >= v_id_proof.expires_at THEN
            RAISE EXCEPTION 'Identity verification proof has expired' USING ERRCODE = 'P0052';
        END IF;

        IF v_id_proof.employee_user_id != v_user_id THEN
            RAISE EXCEPTION 'Identity verification proof belongs to another employee' USING ERRCODE = 'P0053';
        END IF;

        IF v_id_proof.station_id != v_proof.station_id THEN
            RAISE EXCEPTION 'Identity verification proof belongs to another station' USING ERRCODE = 'P0054';
        END IF;

        IF v_id_proof.presence_proof_id != v_proof.id THEN
            RAISE EXCEPTION 'Identity verification proof is not bound to this presence challenge' USING ERRCODE = 'P0055';
        END IF;

        IF v_id_proof.action != 'CHECK_OUT' THEN
            RAISE EXCEPTION 'Identity verification proof action mismatch' USING ERRCODE = 'P0056';
        END IF;

        IF NOT v_id_proof.is_override THEN
            SELECT * INTO v_profile
            FROM public.employee_identity_profiles
            WHERE employee_user_id = v_user_id
            FOR UPDATE;

            IF v_profile.id IS NULL OR v_profile.status != 'ACTIVE' THEN
                RAISE EXCEPTION 'Employee identity profile is revoked or inactive' USING ERRCODE = 'P0047';
            END IF;
        END IF;

        UPDATE public.identity_verification_proofs
        SET used_at = v_now
        WHERE id = v_id_proof.id;

        v_has_valid_id_proof := true;
    ELSE
        IF p_identity_proof_token IS NOT NULL AND trim(p_identity_proof_token) != '' THEN
            v_id_token_hash := encode(sha256(trim(p_identity_proof_token)::bytea), 'hex');
            SELECT * INTO v_id_proof
            FROM public.identity_verification_proofs
            WHERE token_hash = v_id_token_hash AND used_at IS NULL AND expires_at > v_now 
              AND employee_user_id = v_user_id AND presence_proof_id = v_proof.id
            FOR UPDATE;

            IF v_id_proof.id IS NOT NULL THEN
                UPDATE public.identity_verification_proofs SET used_at = v_now WHERE id = v_id_proof.id;
                v_has_valid_id_proof := true;
            END IF;
        END IF;
    END IF;

    IF v_has_valid_id_proof THEN
        IF v_proof.created_at < v_now - INTERVAL '180 seconds' THEN
            RAISE EXCEPTION 'Presence challenge has exceeded maximum bridge lifetime' USING ERRCODE = 'P0027';
        END IF;
    ELSE
        IF v_now >= v_proof.expires_at THEN
            RAISE EXCEPTION 'Presence proof has expired' USING ERRCODE = 'P0027';
        END IF;
    END IF;

    SELECT * INTO v_kiosk FROM public.kiosk_devices WHERE id = v_proof.kiosk_device_id;
    IF v_kiosk.id IS NULL OR NOT v_kiosk.is_active THEN
        RAISE EXCEPTION 'Kiosk device is inactive or deactivated' USING ERRCODE = 'P0018';
    END IF;

    SELECT * INTO v_att
    FROM public.attendance_records
    WHERE employee_user_id = v_user_id AND check_out_time IS NULL
    FOR UPDATE;

    IF v_att.id IS NULL THEN
        RAISE EXCEPTION 'No open attendance record found for employee' USING ERRCODE = 'P0030';
    END IF;

    IF v_att.station_id != v_proof.station_id THEN
        RAISE EXCEPTION 'Cannot check out at Station % while checked in at Station %', v_proof.station_id, v_att.station_id
            USING ERRCODE = 'P0031';
    END IF;

    v_worked_minutes := floor(extract(epoch from (v_now - v_att.check_in_time)) / 60.0)::INTEGER;
    IF v_worked_minutes < 0 THEN
        v_worked_minutes := 0;
    END IF;

    UPDATE public.attendance_records
    SET check_out_time = v_now,
        worked_minutes = v_worked_minutes,
        status = 'COMPLETED',
        check_out_kiosk_device_id = v_proof.kiosk_device_id,
        updated_at = v_now
    WHERE id = v_att.id;

    UPDATE public.attendance_presence_proofs
    SET used_at = v_now
    WHERE id = v_proof.id;

    SELECT first_name || ' ' || last_name INTO v_emp_name FROM public.profiles WHERE id = v_user_id;

    -- 1. Emit EMPLOYEE_CHECKED_OUT to station management
    PERFORM public.emit_notification_event(
        v_proof.station_id,
        'EMPLOYEE_CHECKED_OUT',
        'ATTENDANCE',
        'NORMAL',
        'attendance_record',
        v_att.id,
        v_user_id,
        jsonb_build_object(
            'employee_name', COALESCE(v_emp_name, 'Employee'),
            'shift_name', v_att.shift_name_snapshot,
            'worked_minutes', v_worked_minutes
        ),
        'att-checkout-mgr:' || v_att.id::text
    );

    -- 2. Emit CHECK_OUT_CONFIRMED to the employee
    PERFORM public.emit_notification_event(
        v_proof.station_id,
        'CHECK_OUT_CONFIRMED',
        'ATTENDANCE',
        'LOW',
        'attendance_record',
        v_att.id,
        v_user_id,
        jsonb_build_object(
            'target_user_id', v_user_id,
            'worked_minutes', v_worked_minutes
        ),
        'att-checkout-self:' || v_att.id::text
    );

    RETURN jsonb_build_object(
        'success', true,
        'attendance_id', v_att.id,
        'station_id', v_att.station_id,
        'employee_user_id', v_user_id,
        'check_in_time', v_att.check_in_time,
        'check_out_time', v_now,
        'worked_minutes', v_worked_minutes,
        'status', 'COMPLETED'
    );
END;
$$;

-- D. Attendance Correction Notification Integration (correct_attendance_record)
DROP FUNCTION IF EXISTS public.correct_attendance_record(UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT);
DROP FUNCTION IF EXISTS public.record_attendance_correction(UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT);

CREATE OR REPLACE FUNCTION public.correct_attendance_record(
    p_attendance_record_id UUID,
    p_new_check_in TIMESTAMPTZ,
    p_new_check_out TIMESTAMPTZ,
    p_reason TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_clean_reason TEXT;
    v_rec RECORD;
    v_new_worked_minutes INTEGER;
    v_overlap_rec RECORD;
    v_correction_id UUID := gen_random_uuid();
    v_emp_name TEXT;
    v_now TIMESTAMPTZ := now();
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_clean_reason := trim(p_reason);
    IF v_clean_reason IS NULL OR length(v_clean_reason) < 3 THEN
        RAISE EXCEPTION 'A valid correction reason (at least 3 characters) is required' USING ERRCODE = 'P0032';
    END IF;

    SELECT * INTO v_rec
    FROM public.attendance_records
    WHERE id = p_attendance_record_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Attendance record not found' USING ERRCODE = 'P0033';
    END IF;

    IF NOT public.has_station_permission(v_rec.station_id, v_caller_id, 'attendance.correct') THEN
        RAISE EXCEPTION 'Access denied: caller cannot perform manual attendance corrections' USING ERRCODE = '42501';
    END IF;

    IF p_new_check_in IS NULL THEN
        RAISE EXCEPTION 'Check-in time is required' USING ERRCODE = 'P0033';
    END IF;

    IF p_new_check_out IS NOT NULL AND p_new_check_out <= p_new_check_in THEN
        RAISE EXCEPTION 'Check-out time must be after check-in time' USING ERRCODE = 'P0034';
    END IF;

    IF p_new_check_out IS NOT NULL THEN
        SELECT id, check_in_time, check_out_time INTO v_overlap_rec
        FROM public.attendance_records
        WHERE employee_user_id = v_rec.employee_user_id
          AND id <> p_attendance_record_id
          AND check_out_time IS NOT NULL
          AND (p_new_check_in < check_out_time AND check_in_time < p_new_check_out)
        LIMIT 1;

        IF FOUND THEN
            RAISE EXCEPTION 'Corrected time range overlaps with another attendance record for this employee'
                USING ERRCODE = 'P0035';
        END IF;

        v_new_worked_minutes := GREATEST(0, floor(extract(epoch from (p_new_check_out - p_new_check_in)) / 60.0)::INTEGER);
    ELSE
        IF p_new_check_in > v_now THEN
            RAISE EXCEPTION 'Check-in time cannot be in the future' USING ERRCODE = 'P0034';
        END IF;
        v_new_worked_minutes := NULL;
    END IF;

    -- Insert into immutable correction ledger
    INSERT INTO public.attendance_corrections (
        id, attendance_record_id, station_id, actor_user_id,
        previous_check_in_time, new_check_in_time,
        previous_check_out_time, new_check_out_time,
        previous_worked_minutes, new_worked_minutes,
        reason
    ) VALUES (
        v_correction_id, p_attendance_record_id, v_rec.station_id, v_caller_id,
        v_rec.check_in_time, p_new_check_in,
        v_rec.check_out_time, p_new_check_out,
        v_rec.worked_minutes, v_new_worked_minutes,
        v_clean_reason
    );

    -- Update attendance record
    UPDATE public.attendance_records
    SET check_in_time = p_new_check_in,
        check_out_time = p_new_check_out,
        worked_minutes = v_new_worked_minutes,
        status = 'CORRECTED',
        updated_at = v_now
    WHERE id = p_attendance_record_id;

    SELECT first_name || ' ' || last_name INTO v_emp_name FROM public.profiles WHERE id = v_rec.employee_user_id;

    -- Emit ATTENDANCE_MANUALLY_CORRECTED
    PERFORM public.emit_notification_event(
        v_rec.station_id,
        'ATTENDANCE_MANUALLY_CORRECTED',
        'ATTENDANCE',
        'HIGH',
        'attendance_record',
        p_attendance_record_id,
        v_caller_id,
        jsonb_build_object(
            'target_user_id', v_rec.employee_user_id,
            'employee_name', COALESCE(v_emp_name, 'Employee'),
            'reason', v_clean_reason
        ),
        'att-corrected:' || v_correction_id::text
    );

    RETURN jsonb_build_object(
        'success', true,
        'correction_id', v_correction_id,
        'attendance_record_id', p_attendance_record_id,
        'new_worked_minutes', v_new_worked_minutes,
        'status', 'CORRECTED'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- Optional alias
CREATE OR REPLACE FUNCTION public.record_attendance_correction(
    p_attendance_record_id UUID,
    p_new_check_in_time TIMESTAMPTZ,
    p_new_check_out_time TIMESTAMPTZ,
    p_reason TEXT
)
RETURNS JSONB AS $$
BEGIN
    RETURN public.correct_attendance_record(p_attendance_record_id, p_new_check_in_time, p_new_check_out_time, p_reason);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- E. Identity Admin Override Notification Integration
CREATE OR REPLACE FUNCTION public.create_identity_admin_override(
    p_presence_proof_token TEXT,
    p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_admin_id UUID;
    v_token_hash TEXT;
    v_proof RECORD;
    v_attempt_id UUID;
    v_id_proof_id UUID;
    v_id_proof_token TEXT;
    v_id_token_hash TEXT;
    v_now TIMESTAMPTZ;
    v_expires_at TIMESTAMPTZ;
    v_clean_reason TEXT;
    v_emp_name TEXT;
    v_admin_name TEXT;
BEGIN
    v_admin_id := auth.uid();
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_clean_reason := trim(p_reason);
    IF v_clean_reason IS NULL OR length(v_clean_reason) < 3 THEN
        RAISE EXCEPTION 'Override reason must be at least 3 characters long' USING ERRCODE = 'P0032';
    END IF;

    IF length(v_clean_reason) > 500 THEN
        v_clean_reason := substring(v_clean_reason from 1 for 500);
    END IF;

    v_now := now();
    v_token_hash := encode(sha256(p_presence_proof_token::bytea), 'hex');

    SELECT * INTO v_proof
    FROM public.attendance_presence_proofs
    WHERE token_hash = v_token_hash
    FOR UPDATE;

    IF v_proof.id IS NULL THEN
        RAISE EXCEPTION 'Invalid presence proof token' USING ERRCODE = 'P0025';
    END IF;

    IF v_proof.used_at IS NOT NULL THEN
        RAISE EXCEPTION 'Presence proof has already been used' USING ERRCODE = 'P0026';
    END IF;

    IF v_now >= v_proof.expires_at THEN
        RAISE EXCEPTION 'Presence proof has expired' USING ERRCODE = 'P0027';
    END IF;

    IF NOT public.is_station_admin(v_proof.station_id, v_admin_id) THEN
        RAISE EXCEPTION 'Access denied: Only station admins can authorize identity overrides' USING ERRCODE = '42501';
    END IF;

    v_attempt_id := gen_random_uuid();
    v_id_proof_id := gen_random_uuid();
    v_id_proof_token := 'IDO_' || encode(gen_random_bytes(24), 'hex');
    v_id_token_hash := encode(sha256(v_id_proof_token::bytea), 'hex');
    v_expires_at := v_now + INTERVAL '120 seconds';

    INSERT INTO public.identity_verification_attempts (
        id, employee_user_id, station_id, presence_proof_id, provider,
        result, is_override, override_actor_id, override_reason, created_at, completed_at
    ) VALUES (
        v_attempt_id, v_proof.employee_user_id, v_proof.station_id, v_proof.id, 'MANUAL_ADMIN_OVERRIDE',
        'VERIFIED', true, v_admin_id, v_clean_reason, v_now, v_now
    );

    INSERT INTO public.identity_verification_proofs (
        id, employee_user_id, station_id, presence_proof_id, verification_attempt_id,
        action, token_hash, is_override, expires_at, created_at
    ) VALUES (
        v_id_proof_id, v_proof.employee_user_id, v_proof.station_id, v_proof.id, v_attempt_id,
        v_proof.action, v_id_token_hash, true, v_expires_at, v_now
    );

    INSERT INTO public.audit_logs (
        station_id, actor_id, action, target_type, target_id, metadata
    ) VALUES (
        v_proof.station_id, v_admin_id, 'IDENTITY_VERIFICATION_OVERRIDE', 'attendance_presence_proofs', v_proof.id::text,
        jsonb_build_object(
            'employee_user_id', v_proof.employee_user_id,
            'reason', v_clean_reason,
            'action', v_proof.action,
            'created_at', v_now
        )
    );

    SELECT first_name || ' ' || last_name INTO v_emp_name FROM public.profiles WHERE id = v_proof.employee_user_id;
    SELECT first_name || ' ' || last_name INTO v_admin_name FROM public.profiles WHERE id = v_admin_id;

    -- Emit IDENTITY_ADMIN_OVERRIDE_USED
    PERFORM public.emit_notification_event(
        v_proof.station_id,
        'IDENTITY_ADMIN_OVERRIDE_USED',
        'IDENTITY',
        'HIGH',
        'identity_verification_proof',
        v_id_proof_id,
        v_admin_id,
        jsonb_build_object(
            'target_user_id', v_proof.employee_user_id,
            'employee_name', COALESCE(v_emp_name, 'Employee'),
            'admin_name', COALESCE(v_admin_name, 'Admin'),
            'reason', v_clean_reason
        ),
        'id-override:' || v_attempt_id::text
    );

    RETURN jsonb_build_object(
        'success', true,
        'override_id', v_attempt_id,
        'identity_proof_token', v_id_proof_token,
        'expires_at', v_expires_at,
        'action', v_proof.action
    );
END;
$$;

-- 25. Grants Hardening
REVOKE ALL ON FUNCTION public.get_my_notifications(INTEGER, TIMESTAMPTZ, UUID, public.notification_category, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_notifications(INTEGER, TIMESTAMPTZ, UUID, public.notification_category, BOOLEAN) TO authenticated;

REVOKE ALL ON FUNCTION public.get_unread_notification_count() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_unread_notification_count() TO authenticated;

REVOKE ALL ON FUNCTION public.mark_notification_read(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_notification_read(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.mark_all_notifications_read(public.notification_category) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read(public.notification_category) TO authenticated;

REVOKE ALL ON FUNCTION public.get_my_notification_preferences() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_notification_preferences() TO authenticated;

REVOKE ALL ON FUNCTION public.update_my_notification_preferences(public.notification_category, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_my_notification_preferences(public.notification_category, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN) TO authenticated;

REVOKE ALL ON FUNCTION public.register_notification_device(TEXT, TEXT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_notification_device(TEXT, TEXT, TEXT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.revoke_notification_device(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.revoke_notification_device(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.correct_attendance_record(UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.correct_attendance_record(UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.record_attendance_correction(UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_attendance_correction(UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) TO authenticated;

-- Service-Role restricted functions
REVOKE ALL ON FUNCTION public.claim_notification_delivery_jobs(INTEGER, INTEGER) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.record_delivery_attempt_outcome(UUID, UUID, public.delivery_attempt_outcome, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.cleanup_expired_notifications(INTEGER) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.evaluate_kiosk_health_transitions(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.generate_due_notification_reminders() FROM PUBLIC, anon, authenticated;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        GRANT EXECUTE ON FUNCTION public.claim_notification_delivery_jobs(INTEGER, INTEGER) TO service_role;
        GRANT EXECUTE ON FUNCTION public.record_delivery_attempt_outcome(UUID, UUID, public.delivery_attempt_outcome, TEXT, TEXT, TEXT, TEXT) TO service_role;
        GRANT EXECUTE ON FUNCTION public.cleanup_expired_notifications(INTEGER) TO service_role;
        GRANT EXECUTE ON FUNCTION public.evaluate_kiosk_health_transitions(UUID) TO service_role;
        GRANT EXECUTE ON FUNCTION public.generate_due_notification_reminders() TO service_role;
    END IF;
END $$;

-- 26. Realtime Publication
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
END $$;
