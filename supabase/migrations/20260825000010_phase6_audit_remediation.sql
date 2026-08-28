-- ======================================================================
-- YELLOWSHIFTS — PHASE 6 INDEPENDENT AUDIT & REMEDIATION MIGRATION
-- Migration: 20260825000010_phase6_audit_remediation.sql
-- ======================================================================

-- 1. Schema Extensions
-- A. Push Device Token Storage for Delivery Worker
ALTER TABLE public.notification_devices
    ADD COLUMN IF NOT EXISTS encrypted_device_token TEXT NULL;

-- B. Kiosk Incident Tracking for Deterministic Deduplication
ALTER TABLE public.kiosk_health_states
    ADD COLUMN IF NOT EXISTS incident_id UUID NOT NULL DEFAULT gen_random_uuid(),
    ADD COLUMN IF NOT EXISTS transition_count INTEGER NOT NULL DEFAULT 1;

-- C. Enforce System Category In-App Mandatory Constraint
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'check_system_in_app_mandatory'
    ) THEN
        ALTER TABLE public.notification_preferences
        ADD CONSTRAINT check_system_in_app_mandatory
        CHECK (category <> 'SYSTEM' OR in_app_enabled = true);
    END IF;
END $$;

-- 2. Column Immutability Trigger on Notifications
CREATE OR REPLACE FUNCTION public.check_notification_column_immutability()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NEW.recipient_user_id <> OLD.recipient_user_id OR
       NEW.station_id IS DISTINCT FROM OLD.station_id OR
       NEW.event_id IS DISTINCT FROM OLD.event_id OR
       NEW.category <> OLD.category OR
       NEW.event_type <> OLD.event_type OR
       NEW.priority <> OLD.priority OR
       NEW.title_key <> OLD.title_key OR
       NEW.body_key <> OLD.body_key OR
       NEW.render_data <> OLD.render_data OR
       NEW.action_type IS DISTINCT FROM OLD.action_type OR
       NEW.action_data <> OLD.action_data OR
       NEW.is_mandatory <> OLD.is_mandatory OR
       NEW.deduplication_key <> OLD.deduplication_key OR
       NEW.created_at <> OLD.created_at THEN
        RAISE EXCEPTION 'Immutable notification columns cannot be modified' USING ERRCODE = '42501';
    END IF;

    -- Ensure read_at / seen_at cannot be spoofed to future timestamps
    IF NEW.read_at IS NOT NULL AND NEW.read_at > now() + INTERVAL '1 minute' THEN
        RAISE EXCEPTION 'read_at cannot be set to a future timestamp' USING ERRCODE = '22000';
    END IF;

    IF NEW.seen_at IS NOT NULL AND NEW.seen_at > now() + INTERVAL '1 minute' THEN
        RAISE EXCEPTION 'seen_at cannot be set to a future timestamp' USING ERRCODE = '22000';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_notification_immutability ON public.notifications;
CREATE TRIGGER trg_enforce_notification_immutability
BEFORE UPDATE ON public.notifications
FOR EACH ROW
EXECUTE FUNCTION public.check_notification_column_immutability();

-- 3. Hardened Table-Level Privileges
REVOKE UPDATE ON TABLE public.notifications FROM authenticated, anon, PUBLIC;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.notification_preferences FROM authenticated, anon, PUBLIC;

-- 4. Recreate/Harden Functions

-- A. Register Notification Device (Stores encrypted device token for worker dispatch)
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
        user_id, platform, provider, device_token_hash, encrypted_device_token,
        device_label, is_active, last_seen_at, created_at, revoked_at
    ) VALUES (
        v_caller_id, p_platform, p_provider, v_token_hash, v_clean_token,
        COALESCE(trim(p_device_label), 'Device'), true, v_now, v_now, NULL
    )
    ON CONFLICT (user_id, device_token_hash) DO UPDATE
    SET is_active = true,
        encrypted_device_token = EXCLUDED.encrypted_device_token,
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

-- B. Update My Notification Preferences (Guarantees mandatory SYSTEM in-app channel)
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
    v_in_app BOOLEAN;
    v_now TIMESTAMPTZ := now();
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    -- SYSTEM category in-app channel is mandatory and cannot be disabled
    IF p_category = 'SYSTEM' THEN
        v_in_app := true;
    ELSE
        v_in_app := COALESCE(p_in_app_enabled, true);
    END IF;

    INSERT INTO public.notification_preferences (
        user_id, category, in_app_enabled, push_enabled, email_enabled, sms_enabled, created_at, updated_at
    ) VALUES (
        v_caller_id, p_category, v_in_app, COALESCE(p_push_enabled, true),
        COALESCE(p_email_enabled, false), COALESCE(p_sms_enabled, false), v_now, v_now
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
        'in_app_enabled', v_in_app,
        'push_enabled', COALESCE(p_push_enabled, true),
        'email_enabled', COALESCE(p_email_enabled, false),
        'sms_enabled', COALESCE(p_sms_enabled, false)
    );
END;
$$;

-- C. Outbox Worker Claiming (Unified parameter support & push token retrieval)
DROP FUNCTION IF EXISTS public.claim_notification_delivery_jobs(INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION public.claim_notification_delivery_jobs(
    p_batch_size INTEGER DEFAULT 10,
    p_lease_seconds INTEGER DEFAULT 60,
    p_lock_token UUID DEFAULT NULL
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
    v_lease_duration INTEGER;
    v_lease_expires TIMESTAMPTZ;
    v_claimed_jobs JSONB;
    v_limit INTEGER;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NOT NULL THEN
        RAISE EXCEPTION 'Access denied: Worker claiming requires service_role privilege' USING ERRCODE = '42501';
    END IF;

    v_limit := LEAST(GREATEST(COALESCE(p_batch_size, 10), 1), 100);
    v_lease_duration := LEAST(GREATEST(COALESCE(p_lease_seconds, 60), 10), 600);
    v_lock_token := COALESCE(p_lock_token, gen_random_uuid());
    v_lease_expires := v_now + (v_lease_duration * INTERVAL '1 second');

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
            'idempotency_key', 'job:' || lj.id::text || ':attempt:' || lj.attempt_count::text,
            'title_key', n.title_key,
            'body_key', n.body_key,
            'render_data', n.render_data,
            'priority', n.priority,
            'device_tokens', (
                CASE WHEN lj.channel = 'PUSH' THEN (
                    SELECT jsonb_agg(
                        jsonb_build_object(
                            'device_id', d.id,
                            'platform', d.platform,
                            'provider', d.provider,
                            'token', d.encrypted_device_token
                        )
                    )
                    FROM public.notification_devices d
                    WHERE d.user_id = lj.recipient_user_id
                      AND d.is_active = true
                      AND d.revoked_at IS NULL
                ) ELSE NULL END
            )
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

-- D. Outbox Worker: Record Delivery Attempt Outcome
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

    IF v_job.status <> 'PROCESSING' THEN
        RAISE EXCEPTION 'Invalid job state for outcome recording: %', v_job.status USING ERRCODE = 'P0066';
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

-- E. Emit Notification Event (Expanded Event Catalog Coverage)
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

    -- Configure title, body, action, and render data templates
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

        WHEN 'SCHEDULE_REVISED' THEN
            v_title_key := 'notif_schedule_revised_title';
            v_body_key := 'notif_schedule_revised_body';
            v_action_type := 'NAVIGATE_SCHEDULE';
            v_action_data := jsonb_build_object('schedule_id', p_aggregate_id, 'station_id', p_station_id);
            v_render_data := jsonb_build_object(
                'station_name', v_station_name,
                'version', p_payload->>'version',
                'change_type', p_payload->>'change_type'
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

        WHEN 'SHIFT_CHANGED' THEN
            v_title_key := 'notif_shift_changed_title';
            v_body_key := 'notif_shift_changed_body';
            v_action_type := 'NAVIGATE_SCHEDULE';
            v_action_data := jsonb_build_object('schedule_id', p_aggregate_id, 'station_id', p_station_id);
            v_render_data := jsonb_build_object(
                'shift_name', p_payload->>'shift_name',
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

        WHEN 'AVAILABILITY_SUBMITTED_CONFIRMATION' THEN
            v_title_key := 'notif_avail_submitted_title';
            v_body_key := 'notif_avail_submitted_body';
            v_action_type := 'NAVIGATE_AVAILABILITY';
            v_action_data := jsonb_build_object('period_id', p_aggregate_id, 'station_id', p_station_id);
            v_render_data := jsonb_build_object(
                'station_name', v_station_name
            );

        WHEN 'AVAILABILITY_MISSING_EMPLOYEES' THEN
            v_title_key := 'notif_avail_missing_title';
            v_body_key := 'notif_avail_missing_body';
            v_action_type := 'NAVIGATE_AVAILABILITY';
            v_action_data := jsonb_build_object('period_id', p_aggregate_id, 'station_id', p_station_id);
            v_render_data := jsonb_build_object(
                'station_name', v_station_name,
                'missing_count', p_payload->>'missing_count'
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
        WHEN 'IDENTITY_ENROLLMENT_REQUIRED' THEN
            v_title_key := 'notif_identity_enroll_req_title';
            v_body_key := 'notif_identity_enroll_req_body';
            v_action_type := 'NAVIGATE_IDENTITY';
            v_action_data := jsonb_build_object('station_id', p_station_id);
            v_render_data := jsonb_build_object('station_name', v_station_name);

        WHEN 'IDENTITY_ENROLLMENT_COMPLETED' THEN
            v_title_key := 'notif_identity_enrolled_title';
            v_body_key := 'notif_identity_enrolled_body';
            v_action_type := 'NAVIGATE_IDENTITY';
            v_action_data := jsonb_build_object('station_id', p_station_id);
            v_render_data := jsonb_build_object('station_name', v_station_name);

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
            'SCHEDULE_PUBLICATION_COMPLETED', 'AVAILABILITY_MISSING_EMPLOYEES'
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

-- F. Evaluator: Kiosk Health Transitions (15m onboarding grace period & incident UUIDs)
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
    v_onboarding_grace INTERVAL := INTERVAL '15 minutes';
    v_now TIMESTAMPTZ := now();
    v_is_offline BOOLEAN;
    v_health RECORD;
    v_offline_transitions INTEGER := 0;
    v_recovery_transitions INTEGER := 0;
    v_minutes_offline INTEGER;
    v_new_incident_id UUID;
    v_dedup TEXT;
BEGIN
    FOR v_kiosk IN (
        SELECT k.id, k.station_id, k.name, k.last_seen_at, k.is_active, k.created_at, s.name AS station_name
        FROM public.kiosk_devices k
        JOIN public.stations s ON k.station_id = s.id
        WHERE k.is_active = true AND s.is_active = true
          AND (p_station_id IS NULL OR k.station_id = p_station_id)
    ) LOOP
        -- Apply 15-minute grace period to newly provisioned kiosks before first heartbeat
        IF v_kiosk.last_seen_at IS NULL THEN
            v_is_offline := (v_kiosk.created_at < (v_now - v_onboarding_grace));
        ELSE
            v_is_offline := (v_kiosk.last_seen_at < (v_now - v_offline_threshold));
        END IF;

        SELECT * INTO v_health
        FROM public.kiosk_health_states
        WHERE kiosk_device_id = v_kiosk.id
        FOR UPDATE;

        IF v_health.kiosk_device_id IS NULL THEN
            v_new_incident_id := gen_random_uuid();
            INSERT INTO public.kiosk_health_states (
                kiosk_device_id, station_id, current_status, incident_id, transition_count, last_transition_at, updated_at
            ) VALUES (
                v_kiosk.id, v_kiosk.station_id, 'ONLINE', v_new_incident_id, 1, v_now, v_now
            )
            ON CONFLICT (kiosk_device_id) DO NOTHING;
            v_health.current_status := 'ONLINE';
            v_health.incident_id := v_new_incident_id;
            v_health.transition_count := 1;
        END IF;

        IF v_is_offline AND v_health.current_status = 'ONLINE' THEN
            v_new_incident_id := gen_random_uuid();
            v_minutes_offline := GREATEST(3, floor(extract(epoch from (v_now - COALESCE(v_kiosk.last_seen_at, v_now - INTERVAL '3 minutes'))) / 60.0)::INTEGER);
            v_dedup := 'kiosk-offline:' || v_kiosk.id::text || ':' || v_new_incident_id::text;

            UPDATE public.kiosk_health_states
            SET current_status = 'OFFLINE',
                incident_id = v_new_incident_id,
                transition_count = transition_count + 1,
                last_transition_at = v_now,
                updated_at = v_now
            WHERE kiosk_device_id = v_kiosk.id;

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

            v_offline_transitions := v_offline_transitions + 1;

        ELSIF NOT v_is_offline AND v_health.current_status = 'OFFLINE' THEN
            v_new_incident_id := gen_random_uuid();
            v_dedup := 'kiosk-recovered:' || v_kiosk.id::text || ':' || v_new_incident_id::text;

            UPDATE public.kiosk_health_states
            SET current_status = 'ONLINE',
                incident_id = v_new_incident_id,
                transition_count = transition_count + 1,
                last_transition_at = v_now,
                updated_at = v_now
            WHERE kiosk_device_id = v_kiosk.id;

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

-- G. Evaluator: Due Reminders & Missed Check-Ins (Active member guard & epoch deduplication)
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
    v_missing_count INTEGER;
    v_rec RECORD;
    v_period RECORD;
    v_dedup TEXT;
BEGIN
    -- 1. Availability Period Deadlines Approaching (within 24 hours of deadline)
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
          AND NOT EXISTS (
              SELECT 1 FROM public.availability_submissions sub
              WHERE sub.availability_period_id = ap.id AND sub.membership_id = sm.id AND sub.status = 'SUBMITTED'
          )
    ) LOOP
        -- Deduplication incorporates submission deadline epoch so deadline updates trigger fresh reminders
        v_dedup := 'avail-deadline-24h:' || v_rec.period_id::text || ':' || extract(epoch from v_rec.submission_deadline)::bigint::text || ':' || v_rec.user_id::text;

        IF NOT EXISTS (SELECT 1 FROM public.notification_events WHERE deduplication_key = v_dedup) THEN
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
        END IF;
    END LOOP;

    -- 2. Notify Station Managers if Availability Period has missing submissions within 24h
    FOR v_period IN (
        SELECT ap.id AS period_id, ap.station_id, ap.submission_deadline
        FROM public.availability_periods ap
        WHERE ap.status = 'OPEN'
          AND ap.submission_deadline > v_now
          AND ap.submission_deadline <= (v_now + INTERVAL '24 hours')
    ) LOOP
        SELECT count(*) INTO v_missing_count
        FROM public.station_memberships sm
        WHERE sm.station_id = v_period.station_id
          AND sm.status = 'ACTIVE'
          AND sm.role = 'EMPLOYEE'
          AND NOT EXISTS (
              SELECT 1 FROM public.availability_submissions sub
              WHERE sub.availability_period_id = v_period.period_id AND sub.membership_id = sm.id AND sub.status = 'SUBMITTED'
          );

        IF v_missing_count > 0 THEN
            v_dedup := 'avail-missing-mgr:' || v_period.period_id::text || ':' || extract(epoch from v_period.submission_deadline)::bigint::text;
            IF NOT EXISTS (SELECT 1 FROM public.notification_events WHERE deduplication_key = v_dedup) THEN
                PERFORM public.emit_notification_event(
                    v_period.station_id,
                    'AVAILABILITY_MISSING_EMPLOYEES',
                    'AVAILABILITY',
                    'HIGH',
                    'availability_period',
                    v_period.period_id,
                    NULL,
                    jsonb_build_object(
                        'missing_count', v_missing_count
                    ),
                    v_dedup
                );
            END IF;
        END IF;
    END LOOP;

    -- 3. Missed Check-Ins: Active employees whose start time + late_grace_minutes + 15m passed without open record
    FOR v_rec IN (
        SELECT wss.id AS shift_id, wss.station_id, wss.shift_name_snapshot, wss.starts_at,
               sa.user_id, p.first_name, p.last_name, s.late_grace_minutes
        FROM public.shift_assignments sa
        JOIN public.station_memberships sm ON sa.membership_id = sm.id
        JOIN public.work_schedule_shifts wss ON sa.work_schedule_shift_id = wss.id
        JOIN public.work_schedules ws ON wss.work_schedule_id = ws.id
        JOIN public.stations s ON wss.station_id = s.id
        JOIN public.profiles p ON sa.user_id = p.id
        WHERE ws.status = 'PUBLISHED'
          AND sm.status = 'ACTIVE'
          AND v_now >= (wss.starts_at + ((s.late_grace_minutes + 15) * INTERVAL '1 minute'))
          AND v_now < wss.ends_at
          AND NOT EXISTS (
              SELECT 1 FROM public.attendance_records ar
              WHERE (ar.shift_assignment_id = sa.id OR (ar.employee_user_id = sa.user_id AND ar.work_schedule_shift_id = wss.id))
          )
    ) LOOP
        v_dedup := 'missed-checkin:' || v_rec.shift_id::text || ':' || v_rec.user_id::text;

        IF NOT EXISTS (SELECT 1 FROM public.notification_events WHERE deduplication_key = v_dedup) THEN
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
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'availability_reminders_emitted', v_reminders_count,
        'missed_checkins_emitted', v_missed_checkins
    );
END;
$$;

-- H. Retention & Maintenance (Guarantees preservation of mandatory compliance notifications)
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

    -- CRITICAL AUDIT FIX: Preserve mandatory compliance notifications (is_mandatory = false only)
    WITH deleted_notifs AS (
        DELETE FROM public.notifications
        WHERE read_at IS NOT NULL
          AND is_mandatory = false
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

-- I. Domain RPC Integration: Phase 3 Assign Employee to Shift (Emits SHIFT_ASSIGNED and SCHEDULE_REVISED)
CREATE OR REPLACE FUNCTION public.assign_employee_to_shift(
    p_schedule_shift_id UUID,
    p_membership_id UUID,
    p_expected_version INTEGER,
    p_override BOOLEAN DEFAULT false,
    p_override_reason TEXT DEFAULT NULL,
    p_change_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_shift RECORD;
    v_membership RECORD;
    v_user_id UUID;
    v_new_version INTEGER;
    v_assignment_id UUID;
    v_availability_state TEXT;
    v_overlap_record RECORD;
BEGIN
    v_caller_id := auth.uid();

    SELECT wss.*, ws.status AS schedule_status, ws.version AS current_version, ws.availability_period_id
    INTO v_shift
    FROM public.work_schedule_shifts wss
    JOIN public.work_schedules ws ON wss.work_schedule_id = ws.id
    WHERE wss.id = p_schedule_shift_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Schedule shift not found' USING ERRCODE = 'P0002';
    END IF;

    IF NOT public.has_station_permission(v_shift.station_id, v_caller_id, 'schedule.manage') THEN
        RAISE EXCEPTION 'Access denied: caller does not have schedule.manage permission'
            USING ERRCODE = '42501';
    END IF;

    IF v_shift.schedule_status = 'ARCHIVED' THEN
        RAISE EXCEPTION 'Cannot modify an ARCHIVED work schedule' USING ERRCODE = '22000';
    END IF;

    SELECT * INTO v_membership
    FROM public.station_memberships
    WHERE id = p_membership_id AND station_id = v_shift.station_id;

    IF NOT FOUND OR v_membership.status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Employee membership is not active for this station' USING ERRCODE = '22000';
    END IF;

    v_user_id := v_membership.user_id;

    PERFORM 1 FROM public.profiles WHERE id = v_user_id FOR UPDATE;

    UPDATE public.work_schedules
    SET version = version + 1, updated_at = timezone('utc'::text, now())
    WHERE id = v_shift.work_schedule_id AND version = p_expected_version
    RETURNING version INTO v_new_version;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Schedule version conflict: expected version %, but current version has changed', p_expected_version
            USING ERRCODE = 'P0005';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.shift_assignments
        WHERE work_schedule_shift_id = p_schedule_shift_id AND membership_id = p_membership_id
    ) THEN
        RAISE EXCEPTION 'Employee is already assigned to this shift' USING ERRCODE = '23505';
    END IF;

    SELECT 
        CASE 
            WHEN ae.is_available = true THEN 'AVAILABLE'
            WHEN ae.is_available = false THEN 'UNAVAILABLE'
            ELSE 'NOT_SUBMITTED'
        END
    INTO v_availability_state
    FROM public.availability_submissions asub
    JOIN public.availability_entries ae ON ae.submission_id = asub.id
    WHERE asub.availability_period_id = v_shift.availability_period_id
      AND asub.membership_id = p_membership_id
      AND asub.status = 'SUBMITTED'
      AND ae.period_shift_template_id = v_shift.period_shift_template_id
      AND ae.date = v_shift.operational_date;

    IF v_availability_state IS NULL THEN
        v_availability_state := 'NOT_SUBMITTED';
    END IF;

    IF v_availability_state <> 'AVAILABLE' THEN
        IF NOT COALESCE(p_override, false) THEN
            RAISE EXCEPTION 'Availability override required for % employee', v_availability_state
                USING ERRCODE = 'P0006';
        END IF;

        IF p_override_reason IS NULL OR length(trim(p_override_reason)) < 3 THEN
            RAISE EXCEPTION 'A valid override reason (at least 3 characters) is required'
                USING ERRCODE = 'P0007';
        END IF;
    END IF;

    SELECT other_wss.station_id, s.name AS other_station_name, other_wss.shift_name_snapshot,
           other_wss.starts_at, other_wss.ends_at
    INTO v_overlap_record
    FROM public.shift_assignments other_sa
    JOIN public.work_schedule_shifts other_wss ON other_sa.work_schedule_shift_id = other_wss.id
    JOIN public.stations s ON other_wss.station_id = s.id
    WHERE other_sa.user_id = v_user_id
      AND other_sa.work_schedule_shift_id <> p_schedule_shift_id
      AND other_wss.starts_at < v_shift.ends_at
      AND v_shift.starts_at < other_wss.ends_at
    LIMIT 1;

    IF FOUND THEN
        IF v_overlap_record.station_id = v_shift.station_id THEN
            RAISE EXCEPTION 'Overlapping assignment conflict: employee is already assigned to % (%)',
                v_overlap_record.shift_name_snapshot, v_overlap_record.starts_at
                USING ERRCODE = 'P0008';
        ELSE
            RAISE EXCEPTION 'Cross-station overlap conflict: employee is already assigned at another station during this time window'
                USING ERRCODE = 'P0009';
        END IF;
    END IF;

    IF v_shift.schedule_status = 'PUBLISHED' THEN
        IF p_change_reason IS NULL OR length(trim(p_change_reason)) < 3 THEN
            RAISE EXCEPTION 'A change reason is required for modifying an official PUBLISHED schedule'
                USING ERRCODE = 'P0010';
        END IF;

        INSERT INTO public.work_schedule_changes (
            work_schedule_id, station_id, version_before, version_after, change_type, actor_id, reason, metadata
        ) VALUES (
            v_shift.work_schedule_id, v_shift.station_id, p_expected_version, v_new_version,
            'ASSIGNMENT_ADDED', v_caller_id, trim(p_change_reason),
            jsonb_build_object(
                'shift_id', p_schedule_shift_id,
                'membership_id', p_membership_id,
                'availability_state', v_availability_state,
                'override', p_override,
                'override_reason', p_override_reason
            )
        );
    END IF;

    INSERT INTO public.shift_assignments (
        work_schedule_shift_id, membership_id, user_id, station_id,
        availability_state_snapshot, availability_override, availability_override_reason, assigned_by
    ) VALUES (
        p_schedule_shift_id, p_membership_id, v_user_id, v_shift.station_id,
        v_availability_state, COALESCE(p_override, false), p_override_reason, v_caller_id
    ) RETURNING id INTO v_assignment_id;

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        v_shift.station_id, v_caller_id, 'SHIFT_ASSIGNMENT_CREATED', 'shift_assignment', v_assignment_id::text,
        jsonb_build_object(
            'schedule_id', v_shift.work_schedule_id,
            'shift_id', p_schedule_shift_id,
            'user_id', v_user_id,
            'new_version', v_new_version
        )
    );

    -- Emit notification if published
    IF v_shift.schedule_status = 'PUBLISHED' THEN
        PERFORM public.emit_notification_event(
            v_shift.station_id,
            'SHIFT_ASSIGNED',
            'SCHEDULE',
            'NORMAL',
            'work_schedule',
            v_shift.work_schedule_id,
            v_caller_id,
            jsonb_build_object(
                'target_user_id', v_user_id,
                'shift_name', v_shift.shift_name_snapshot,
                'operational_date', v_shift.operational_date,
                'version', v_new_version
            ),
            'shift-assigned:' || p_schedule_shift_id::text || ':' || v_user_id::text || ':v' || v_new_version::text
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'assignment_id', v_assignment_id,
        'new_version', v_new_version
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- J. Domain RPC Integration: Phase 3 Remove Shift Assignment (Emits SHIFT_REMOVED)
CREATE OR REPLACE FUNCTION public.remove_shift_assignment(
    p_assignment_id UUID,
    p_expected_version INTEGER,
    p_change_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_assignment RECORD;
    v_new_version INTEGER;
BEGIN
    v_caller_id := auth.uid();

    SELECT sa.*, wss.work_schedule_id, wss.shift_name_snapshot, wss.operational_date,
           ws.status AS schedule_status, ws.version AS current_version
    INTO v_assignment
    FROM public.shift_assignments sa
    JOIN public.work_schedule_shifts wss ON sa.work_schedule_shift_id = wss.id
    JOIN public.work_schedules ws ON wss.work_schedule_id = ws.id
    WHERE sa.id = p_assignment_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Shift assignment not found' USING ERRCODE = 'P0002';
    END IF;

    IF NOT public.has_station_permission(v_assignment.station_id, v_caller_id, 'schedule.manage') THEN
        RAISE EXCEPTION 'Access denied: caller does not have schedule.manage permission'
            USING ERRCODE = '42501';
    END IF;

    IF v_assignment.schedule_status = 'ARCHIVED' THEN
        RAISE EXCEPTION 'Cannot modify an ARCHIVED work schedule' USING ERRCODE = '22000';
    END IF;

    UPDATE public.work_schedules
    SET version = version + 1, updated_at = timezone('utc'::text, now())
    WHERE id = v_assignment.work_schedule_id AND version = p_expected_version
    RETURNING version INTO v_new_version;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Schedule version conflict: expected version %, but current version has changed', p_expected_version
            USING ERRCODE = 'P0005';
    END IF;

    IF v_assignment.schedule_status = 'PUBLISHED' THEN
        IF p_change_reason IS NULL OR length(trim(p_change_reason)) < 3 THEN
            RAISE EXCEPTION 'A change reason is required for modifying an official PUBLISHED schedule'
                USING ERRCODE = 'P0010';
        END IF;

        INSERT INTO public.work_schedule_changes (
            work_schedule_id, station_id, version_before, version_after, change_type, actor_id, reason, metadata
        ) VALUES (
            v_assignment.work_schedule_id, v_assignment.station_id, p_expected_version, v_new_version,
            'ASSIGNMENT_REMOVED', v_caller_id, trim(p_change_reason),
            jsonb_build_object(
                'assignment_id', p_assignment_id,
                'shift_id', v_assignment.work_schedule_shift_id,
                'membership_id', v_assignment.membership_id
            )
        );
    END IF;

    DELETE FROM public.shift_assignments WHERE id = p_assignment_id;

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        v_assignment.station_id, v_caller_id, 'SHIFT_ASSIGNMENT_REMOVED', 'shift_assignment', p_assignment_id::text,
        jsonb_build_object('schedule_id', v_assignment.work_schedule_id, 'new_version', v_new_version)
    );

    IF v_assignment.schedule_status = 'PUBLISHED' THEN
        PERFORM public.emit_notification_event(
            v_assignment.station_id,
            'SHIFT_REMOVED',
            'SCHEDULE',
            'HIGH',
            'work_schedule',
            v_assignment.work_schedule_id,
            v_caller_id,
            jsonb_build_object(
                'target_user_id', v_assignment.user_id,
                'shift_name', v_assignment.shift_name_snapshot,
                'operational_date', v_assignment.operational_date,
                'version', v_new_version
            ),
            'shift-removed:' || p_assignment_id::text || ':' || v_assignment.user_id::text || ':v' || v_new_version::text
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'new_version', v_new_version
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- K. Domain RPC Integration: Phase 3 Move Shift Assignment (Emits SHIFT_CHANGED)
CREATE OR REPLACE FUNCTION public.move_shift_assignment(
    p_assignment_id UUID,
    p_target_shift_id UUID,
    p_expected_version INTEGER,
    p_override BOOLEAN DEFAULT false,
    p_override_reason TEXT DEFAULT NULL,
    p_change_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_assignment RECORD;
    v_target_shift RECORD;
    v_new_version INTEGER;
    v_availability_state TEXT;
    v_overlap_record RECORD;
BEGIN
    v_caller_id := auth.uid();

    SELECT sa.*, wss.work_schedule_id, wss.shift_name_snapshot AS source_shift_name,
           ws.status AS schedule_status, ws.availability_period_id
    INTO v_assignment
    FROM public.shift_assignments sa
    JOIN public.work_schedule_shifts wss ON sa.work_schedule_shift_id = wss.id
    JOIN public.work_schedules ws ON wss.work_schedule_id = ws.id
    WHERE sa.id = p_assignment_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Shift assignment not found' USING ERRCODE = 'P0002';
    END IF;

    SELECT wss.*, ws.status AS schedule_status, ws.availability_period_id
    INTO v_target_shift
    FROM public.work_schedule_shifts wss
    JOIN public.work_schedules ws ON wss.work_schedule_id = ws.id
    WHERE wss.id = p_target_shift_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Target schedule shift not found' USING ERRCODE = 'P0002';
    END IF;

    IF v_assignment.work_schedule_id <> v_target_shift.work_schedule_id THEN
        RAISE EXCEPTION 'Cannot move assignment to a different work schedule' USING ERRCODE = '22000';
    END IF;

    IF NOT public.has_station_permission(v_assignment.station_id, v_caller_id, 'schedule.manage') THEN
        RAISE EXCEPTION 'Access denied: caller does not have schedule.manage permission'
            USING ERRCODE = '42501';
    END IF;

    PERFORM 1 FROM public.profiles WHERE id = v_assignment.user_id FOR UPDATE;

    UPDATE public.work_schedules
    SET version = version + 1, updated_at = timezone('utc'::text, now())
    WHERE id = v_assignment.work_schedule_id AND version = p_expected_version
    RETURNING version INTO v_new_version;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Schedule version conflict: expected version %, but current version has changed', p_expected_version
            USING ERRCODE = 'P0005';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.shift_assignments
        WHERE work_schedule_shift_id = p_target_shift_id AND membership_id = v_assignment.membership_id
    ) THEN
        RAISE EXCEPTION 'Employee is already assigned to target shift' USING ERRCODE = '23505';
    END IF;

    SELECT 
        CASE 
            WHEN ae.is_available = true THEN 'AVAILABLE'
            WHEN ae.is_available = false THEN 'UNAVAILABLE'
            ELSE 'NOT_SUBMITTED'
        END
    INTO v_availability_state
    FROM public.availability_submissions asub
    JOIN public.availability_entries ae ON ae.submission_id = asub.id
    WHERE asub.availability_period_id = v_target_shift.availability_period_id
      AND asub.membership_id = v_assignment.membership_id
      AND asub.status = 'SUBMITTED'
      AND ae.period_shift_template_id = v_target_shift.period_shift_template_id
      AND ae.date = v_target_shift.operational_date;

    IF v_availability_state IS NULL THEN
        v_availability_state := 'NOT_SUBMITTED';
    END IF;

    IF v_availability_state <> 'AVAILABLE' THEN
        IF NOT COALESCE(p_override, false) THEN
            RAISE EXCEPTION 'Availability override required for target shift (% employee)', v_availability_state
                USING ERRCODE = 'P0006';
        END IF;

        IF p_override_reason IS NULL OR length(trim(p_override_reason)) < 3 THEN
            RAISE EXCEPTION 'A valid override reason (at least 3 characters) is required'
                USING ERRCODE = 'P0007';
        END IF;
    END IF;

    SELECT other_wss.station_id, s.name AS other_station_name, other_wss.shift_name_snapshot,
           other_wss.starts_at, other_wss.ends_at
    INTO v_overlap_record
    FROM public.shift_assignments other_sa
    JOIN public.work_schedule_shifts other_wss ON other_sa.work_schedule_shift_id = other_wss.id
    JOIN public.stations s ON other_wss.station_id = s.id
    WHERE other_sa.user_id = v_assignment.user_id
      AND other_sa.id <> p_assignment_id
      AND other_sa.work_schedule_shift_id <> p_target_shift_id
      AND other_wss.starts_at < v_target_shift.ends_at
      AND v_target_shift.starts_at < other_wss.ends_at
    LIMIT 1;

    IF FOUND THEN
        IF v_overlap_record.station_id = v_assignment.station_id THEN
            RAISE EXCEPTION 'Overlapping assignment conflict: employee is already assigned to % (%)',
                v_overlap_record.shift_name_snapshot, v_overlap_record.starts_at
                USING ERRCODE = 'P0008';
        ELSE
            RAISE EXCEPTION 'Cross-station overlap conflict: employee is already assigned at another station during this time window'
                USING ERRCODE = 'P0009';
        END IF;
    END IF;

    IF v_assignment.schedule_status = 'PUBLISHED' THEN
        IF p_change_reason IS NULL OR length(trim(p_change_reason)) < 3 THEN
            RAISE EXCEPTION 'A change reason is required for modifying an official PUBLISHED schedule'
                USING ERRCODE = 'P0010';
        END IF;

        INSERT INTO public.work_schedule_changes (
            work_schedule_id, station_id, version_before, version_after, change_type, actor_id, reason, metadata
        ) VALUES (
            v_assignment.work_schedule_id, v_assignment.station_id, p_expected_version, v_new_version,
            'ASSIGNMENT_MOVED', v_caller_id, trim(p_change_reason),
            jsonb_build_object(
                'assignment_id', p_assignment_id,
                'source_shift_id', v_assignment.work_schedule_shift_id,
                'target_shift_id', p_target_shift_id,
                'membership_id', v_assignment.membership_id,
                'availability_state', v_availability_state
            )
        );
    END IF;

    UPDATE public.shift_assignments
    SET work_schedule_shift_id = p_target_shift_id,
        availability_state_snapshot = v_availability_state,
        availability_override = COALESCE(p_override, false),
        availability_override_reason = p_override_reason,
        assigned_by = v_caller_id,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_assignment_id;

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        v_assignment.station_id, v_caller_id, 'SHIFT_ASSIGNMENT_MOVED', 'shift_assignment', p_assignment_id::text,
        jsonb_build_object(
            'schedule_id', v_assignment.work_schedule_id,
            'source_shift_id', v_assignment.work_schedule_shift_id,
            'target_shift_id', p_target_shift_id,
            'new_version', v_new_version
        )
    );

    IF v_assignment.schedule_status = 'PUBLISHED' THEN
        PERFORM public.emit_notification_event(
            v_assignment.station_id,
            'SHIFT_CHANGED',
            'SCHEDULE',
            'HIGH',
            'work_schedule',
            v_assignment.work_schedule_id,
            v_caller_id,
            jsonb_build_object(
                'target_user_id', v_assignment.user_id,
                'shift_name', v_target_shift.shift_name_snapshot,
                'source_shift_name', v_assignment.source_shift_name,
                'version', v_new_version
            ),
            'shift-moved:' || p_assignment_id::text || ':' || v_assignment.user_id::text || ':v' || v_new_version::text
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'assignment_id', p_assignment_id,
        'new_version', v_new_version
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- L. Domain RPC Integration: Phase 2 Submit Availability (Emits AVAILABILITY_SUBMITTED_CONFIRMATION)
CREATE OR REPLACE FUNCTION public.submit_availability(
    p_period_id UUID,
    p_entries JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_station_id UUID;
    v_period_status public.availability_period_status;
    v_deadline TIMESTAMPTZ;
    v_week_start DATE;
    v_membership_id UUID;
    v_submission_id UUID;
    v_template_count INTEGER;
    v_required_slots INTEGER;
    v_submitted_count INTEGER;
    v_entry JSONB;
    v_date DATE;
    v_template_id UUID;
    v_is_available BOOLEAN;
BEGIN
    v_caller_id := auth.uid();

    SELECT station_id, status, submission_deadline, week_start_date
    INTO v_station_id, v_period_status, v_deadline, v_week_start
    FROM public.availability_periods
    WHERE id = p_period_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Availability period not found' USING ERRCODE = 'P0002';
    END IF;

    IF v_period_status <> 'OPEN' THEN
        RAISE EXCEPTION 'Availability period is not open for submission' USING ERRCODE = '22000';
    END IF;

    IF v_deadline <= timezone('utc'::text, now()) THEN
        RAISE EXCEPTION 'Submission deadline has passed' USING ERRCODE = '22000';
    END IF;

    SELECT id INTO v_membership_id
    FROM public.station_memberships
    WHERE station_id = v_station_id AND user_id = v_caller_id AND status = 'ACTIVE';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Caller is not an active member of this station' USING ERRCODE = '42501';
    END IF;

    SELECT COUNT(*) INTO v_template_count
    FROM public.availability_period_shift_templates
    WHERE availability_period_id = p_period_id;

    v_required_slots := v_template_count * 7;

    INSERT INTO public.availability_submissions (
        availability_period_id, membership_id, status, submitted_at, updated_at
    ) VALUES (
        p_period_id, v_membership_id, 'DRAFT', NULL, timezone('utc'::text, now())
    )
    ON CONFLICT (availability_period_id, membership_id)
    DO UPDATE SET updated_at = timezone('utc'::text, now())
    RETURNING id INTO v_submission_id;

    FOR v_entry IN SELECT * FROM jsonb_array_elements(p_entries) LOOP
        v_date := (v_entry->>'date')::date;
        v_template_id := (v_entry->>'period_shift_template_id')::uuid;
        v_is_available := (v_entry->>'is_available')::boolean;

        IF v_date < v_week_start OR v_date > (v_week_start + INTERVAL '6 days')::date THEN
            RAISE EXCEPTION 'Entry date is outside the period operational week' USING ERRCODE = '22000';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM public.availability_period_shift_templates
            WHERE id = v_template_id AND availability_period_id = p_period_id
        ) THEN
            RAISE EXCEPTION 'Invalid period shift template' USING ERRCODE = '22000';
        END IF;

        INSERT INTO public.availability_entries (
            submission_id, date, period_shift_template_id, is_available, updated_at
        ) VALUES (
            v_submission_id, v_date, v_template_id, v_is_available, timezone('utc'::text, now())
        )
        ON CONFLICT (submission_id, date, period_shift_template_id)
        DO UPDATE SET 
            is_available = EXCLUDED.is_available,
            updated_at = timezone('utc'::text, now());
    END LOOP;

    SELECT COUNT(*) INTO v_submitted_count
    FROM public.availability_entries
    WHERE submission_id = v_submission_id;

    IF v_submitted_count < v_required_slots THEN
        RAISE EXCEPTION 'Cannot submit incomplete availability: % of % slots answered', v_submitted_count, v_required_slots
            USING ERRCODE = 'P0004';
    END IF;

    UPDATE public.availability_submissions
    SET status = 'SUBMITTED',
        submitted_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    WHERE id = v_submission_id;

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        v_station_id, v_caller_id, 'AVAILABILITY_SUBMITTED', 'availability_submission', v_submission_id::text,
        jsonb_build_object('period_id', p_period_id, 'submitted_slots', v_submitted_count)
    );

    PERFORM public.emit_notification_event(
        v_station_id,
        'AVAILABILITY_SUBMITTED_CONFIRMATION',
        'AVAILABILITY',
        'LOW',
        'availability_period',
        p_period_id,
        v_caller_id,
        jsonb_build_object(
            'target_user_id', v_caller_id
        ),
        'avail-submit:' || p_period_id::text || ':' || v_caller_id::text
    );

    RETURN jsonb_build_object(
        'success', true,
        'submission_id', v_submission_id,
        'status', 'SUBMITTED',
        'submitted_slots', v_submitted_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- M. Domain RPC Integration: Phase 5 Revoke Identity Profile (Emits IDENTITY_PROFILE_REVOKED)
CREATE OR REPLACE FUNCTION public.revoke_identity_profile(
    p_employee_user_id UUID,
    p_reason TEXT DEFAULT 'Revoked by user or admin'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_profile RECORD;
    v_now TIMESTAMPTZ;
    v_is_authorized BOOLEAN := false;
    v_st RECORD;
    v_emp_name TEXT;
    v_clean_reason TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_now := now();
    v_clean_reason := trim(p_reason);

    IF v_caller_id = p_employee_user_id THEN
        v_is_authorized := true;
    ELSE
        SELECT true INTO v_is_authorized
        FROM public.station_memberships sm_target
        JOIN public.station_memberships sm_admin 
          ON sm_target.station_id = sm_admin.station_id
        WHERE sm_target.user_id = p_employee_user_id
          AND sm_admin.user_id = v_caller_id
          AND sm_admin.role = 'ADMIN'
          AND sm_admin.status = 'ACTIVE'
        LIMIT 1;
    END IF;

    IF NOT coalesce(v_is_authorized, false) THEN
        RAISE EXCEPTION 'Access denied: Cannot revoke this identity profile' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_profile
    FROM public.employee_identity_profiles
    WHERE employee_user_id = p_employee_user_id
    FOR UPDATE;

    IF v_profile.id IS NULL THEN
        RAISE EXCEPTION 'Identity profile not found' USING ERRCODE = 'P0046';
    END IF;

    UPDATE public.employee_identity_profiles
    SET status = 'REVOKED',
        revoked_at = v_now,
        provider_subject_id = NULL,
        updated_at = v_now
    WHERE employee_user_id = p_employee_user_id;

    UPDATE public.identity_verification_proofs
    SET used_at = v_now
    WHERE employee_user_id = p_employee_user_id AND used_at IS NULL;

    SELECT first_name || ' ' || last_name INTO v_emp_name FROM public.profiles WHERE id = p_employee_user_id;

    -- Emit mandatory notification to all active stations of the employee
    FOR v_st IN (
        SELECT DISTINCT station_id
        FROM public.station_memberships
        WHERE user_id = p_employee_user_id AND status = 'ACTIVE'
    ) LOOP
        PERFORM public.emit_notification_event(
            v_st.station_id,
            'IDENTITY_PROFILE_REVOKED',
            'IDENTITY',
            'HIGH',
            'employee_identity_profile',
            v_profile.id,
            v_caller_id,
            jsonb_build_object(
                'target_user_id', p_employee_user_id,
                'employee_name', COALESCE(v_emp_name, 'Employee'),
                'reason', v_clean_reason
            ),
            'id-revoked:' || v_profile.id::text || ':' || v_st.station_id::text || ':' || extract(epoch from v_now)::bigint::text
        );
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'status', 'REVOKED',
        'revoked_at', v_now
    );
END;
$$;

-- 5. Final Grants & Execution Hardening
REVOKE ALL ON FUNCTION public.claim_notification_delivery_jobs(INTEGER, INTEGER, UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_notification_delivery_jobs(INTEGER, INTEGER, UUID) TO service_role;

REVOKE ALL ON FUNCTION public.record_delivery_attempt_outcome(UUID, UUID, public.delivery_attempt_outcome, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_delivery_attempt_outcome(UUID, UUID, public.delivery_attempt_outcome, TEXT, TEXT, TEXT, TEXT) TO service_role;

REVOKE ALL ON FUNCTION public.cleanup_expired_notifications(INTEGER) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cleanup_expired_notifications(INTEGER) TO service_role;

REVOKE ALL ON FUNCTION public.evaluate_kiosk_health_transitions(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.evaluate_kiosk_health_transitions(UUID) TO service_role;

REVOKE ALL ON FUNCTION public.generate_due_notification_reminders() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.generate_due_notification_reminders() TO service_role;

REVOKE ALL ON FUNCTION public.assign_employee_to_shift(UUID, UUID, INTEGER, BOOLEAN, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assign_employee_to_shift(UUID, UUID, INTEGER, BOOLEAN, TEXT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.remove_shift_assignment(UUID, INTEGER, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.remove_shift_assignment(UUID, INTEGER, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.move_shift_assignment(UUID, UUID, INTEGER, BOOLEAN, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.move_shift_assignment(UUID, UUID, INTEGER, BOOLEAN, TEXT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.submit_availability(UUID, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_availability(UUID, JSONB) TO authenticated;

REVOKE ALL ON FUNCTION public.revoke_identity_profile(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.revoke_identity_profile(UUID, TEXT) TO authenticated;
