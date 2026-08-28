-- YellowShifts Phase 4 Audit Remediation Migration
-- Station Kiosk Security, Atomic Proof Concurrency, Overlap Query Fix, Ambiguous Shift Resolution & Hardened Invariants
-- Canonical Migration: 20260825000006_phase4_audit_remediation.sql

-- 1. Rate Limiting Table for QR Scan & Kiosk Auth Attempts
CREATE TABLE IF NOT EXISTS public.attendance_rate_limit_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID NULL,
    target_identifier TEXT NOT NULL,
    action TEXT NOT NULL,
    is_success BOOLEAN NOT NULL,
    attempted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rate_limit_target_time 
ON public.attendance_rate_limit_attempts(target_identifier, action, attempted_at DESC);

-- RLS: Zero direct client access
ALTER TABLE public.attendance_rate_limit_attempts ENABLE ROW LEVEL SECURITY;
CREATE POLICY rate_limit_all_deny ON public.attendance_rate_limit_attempts FOR ALL TO authenticated USING (false);
CREATE POLICY rate_limit_anon_deny ON public.attendance_rate_limit_attempts FOR ALL TO anon USING (false);

-- 2. Hardened Kiosk Authentication & Dynamic QR Challenge Minting
CREATE OR REPLACE FUNCTION public.kiosk_authenticate_and_mint_qr(
    p_station_id UUID,
    p_device_identifier TEXT,
    p_device_secret TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_kiosk RECORD;
    v_provided_hash TEXT;
    v_qr_token TEXT;
    v_challenge_hash TEXT;
    v_display_code TEXT;
    v_expires_at TIMESTAMPTZ;
    v_station_name TEXT;
    v_station_active BOOLEAN;
    v_recent_failed_attempts INTEGER;
BEGIN
    -- Check brute force rate limit on kiosk device identifier (Max 30 failed attempts per 5 minutes)
    SELECT count(*) INTO v_recent_failed_attempts
    FROM public.attendance_rate_limit_attempts
    WHERE target_identifier = trim(p_device_identifier)
      AND action = 'KIOSK_AUTH'
      AND is_success = false
      AND attempted_at > (now() - INTERVAL '5 minutes');

    IF v_recent_failed_attempts >= 30 THEN
        RAISE EXCEPTION 'Too many failed authentication attempts. Device temporarily locked.'
            USING ERRCODE = 'P0038';
    END IF;

    -- Verify station exists and active
    SELECT name, is_active INTO v_station_name, v_station_active
    FROM public.stations WHERE id = p_station_id;

    IF NOT FOUND OR NOT v_station_active THEN
        INSERT INTO public.attendance_rate_limit_attempts (target_identifier, action, is_success)
        VALUES (trim(p_device_identifier), 'KIOSK_AUTH', false);
        RAISE EXCEPTION 'Station not found or inactive' USING ERRCODE = 'P0017';
    END IF;

    -- Lookup kiosk device
    SELECT id, secret_hash, credential_version, is_active
    INTO v_kiosk
    FROM public.kiosk_devices
    WHERE station_id = p_station_id AND device_identifier = trim(p_device_identifier);

    IF NOT FOUND THEN
        INSERT INTO public.attendance_rate_limit_attempts (target_identifier, action, is_success)
        VALUES (trim(p_device_identifier), 'KIOSK_AUTH', false);
        RAISE EXCEPTION 'Kiosk device not found' USING ERRCODE = 'P0016';
    END IF;

    IF NOT v_kiosk.is_active THEN
        INSERT INTO public.attendance_rate_limit_attempts (target_identifier, action, is_success)
        VALUES (trim(p_device_identifier), 'KIOSK_AUTH', false);
        RAISE EXCEPTION 'Kiosk device is inactive' USING ERRCODE = 'P0018';
    END IF;

    -- Validate secret hash
    v_provided_hash := encode(digest(p_device_secret, 'sha256'), 'hex');
    IF v_provided_hash <> v_kiosk.secret_hash THEN
        INSERT INTO public.attendance_rate_limit_attempts (target_identifier, action, is_success)
        VALUES (trim(p_device_identifier), 'KIOSK_AUTH', false);
        RAISE EXCEPTION 'Invalid kiosk credentials' USING ERRCODE = 'P0019';
    END IF;

    -- Success -> Log success
    INSERT INTO public.attendance_rate_limit_attempts (target_identifier, action, is_success)
    VALUES (trim(p_device_identifier), 'KIOSK_AUTH', true);

    -- Update last seen
    UPDATE public.kiosk_devices
    SET last_seen_at = now()
    WHERE id = v_kiosk.id;

    -- Generate random token (32 hex characters) and collision-free 6-char display code
    v_qr_token := 'YQ_' || encode(gen_random_bytes(16), 'hex');
    v_challenge_hash := encode(digest(v_qr_token, 'sha256'), 'hex');
    
    LOOP
        v_display_code := upper(substring(encode(gen_random_bytes(4), 'hex') from 1 for 6));
        EXIT WHEN NOT EXISTS (
            SELECT 1 FROM public.kiosk_qr_challenges
            WHERE display_code = v_display_code 
              AND revoked_at IS NULL 
              AND expires_at > now()
        );
    END LOOP;

    v_expires_at := now() + INTERVAL '30 seconds';

    -- Revoke existing active challenges for this kiosk
    UPDATE public.kiosk_qr_challenges
    SET revoked_at = now()
    WHERE kiosk_device_id = v_kiosk.id AND revoked_at IS NULL;

    -- Insert new challenge
    INSERT INTO public.kiosk_qr_challenges (
        station_id, kiosk_device_id, challenge_hash, display_code, expires_at
    ) VALUES (
        p_station_id, v_kiosk.id, v_challenge_hash, v_display_code, v_expires_at
    );

    RETURN jsonb_build_object(
        'success', true,
        'qr_token', v_qr_token,
        'display_code', v_display_code,
        'expires_at', v_expires_at,
        'ttl_seconds', 30,
        'station_id', p_station_id,
        'station_name', v_station_name,
        'server_time', now()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 3. Hardened Employee Scan QR & Issue Presence Proof
CREATE OR REPLACE FUNCTION public.scan_attendance_qr(
    p_qr_token_or_code TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_clean_input TEXT;
    v_input_hash TEXT;
    v_challenge RECORD;
    v_membership RECORD;
    v_open_record RECORD;
    v_action public.attendance_action;
    v_shift RECORD;
    v_presence_token TEXT;
    v_token_hash TEXT;
    v_proof_expires_at TIMESTAMPTZ;
    v_shift_preview JSONB := NULL;
    v_now TIMESTAMPTZ := now();
    v_matching_shift_count INTEGER := 0;
    v_recent_failed_scans INTEGER;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    -- Brute force rate limit: max 30 failed scans per minute per employee
    SELECT count(*) INTO v_recent_failed_scans
    FROM public.attendance_rate_limit_attempts
    WHERE actor_id = v_user_id
      AND action = 'QR_SCAN'
      AND is_success = false
      AND attempted_at > (v_now - INTERVAL '1 minute');

    IF v_recent_failed_scans >= 30 THEN
        RAISE EXCEPTION 'Too many invalid scan attempts. Please wait a minute.'
            USING ERRCODE = 'P0037';
    END IF;

    v_clean_input := trim(p_qr_token_or_code);
    v_input_hash := encode(digest(v_clean_input, 'sha256'), 'hex');

    -- Lookup challenge by token hash or display code
    SELECT c.id, c.station_id, c.kiosk_device_id, c.expires_at, c.revoked_at,
           k.is_active AS kiosk_active, s.is_active AS station_active, s.name AS station_name,
           s.check_in_early_minutes, s.late_grace_minutes
    INTO v_challenge
    FROM public.kiosk_qr_challenges c
    JOIN public.kiosk_devices k ON c.kiosk_device_id = k.id
    JOIN public.stations s ON c.station_id = s.id
    WHERE (c.challenge_hash = v_input_hash OR upper(c.display_code) = upper(v_clean_input))
      AND c.revoked_at IS NULL
    ORDER BY c.created_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
        INSERT INTO public.attendance_rate_limit_attempts (actor_id, target_identifier, action, is_success)
        VALUES (v_user_id, v_clean_input, 'QR_SCAN', false);
        RAISE EXCEPTION 'Invalid attendance QR or manual code' USING ERRCODE = 'P0020';
    END IF;

    IF v_challenge.expires_at <= v_now THEN
        INSERT INTO public.attendance_rate_limit_attempts (actor_id, target_identifier, action, is_success)
        VALUES (v_user_id, v_clean_input, 'QR_SCAN', false);
        RAISE EXCEPTION 'QR challenge has expired' USING ERRCODE = 'P0021';
    END IF;

    IF NOT v_challenge.kiosk_active OR NOT v_challenge.station_active THEN
        INSERT INTO public.attendance_rate_limit_attempts (actor_id, target_identifier, action, is_success)
        VALUES (v_user_id, v_clean_input, 'QR_SCAN', false);
        RAISE EXCEPTION 'Kiosk or station is inactive' USING ERRCODE = 'P0022';
    END IF;

    -- Verify employee has ACTIVE membership for this station
    SELECT id, role, status INTO v_membership
    FROM public.station_memberships
    WHERE station_id = v_challenge.station_id AND user_id = v_user_id;

    IF NOT FOUND OR v_membership.status <> 'ACTIVE' THEN
        INSERT INTO public.attendance_rate_limit_attempts (actor_id, target_identifier, action, is_success)
        VALUES (v_user_id, v_clean_input, 'QR_SCAN', false);
        RAISE EXCEPTION 'Access denied: caller is not an active member of this station' USING ERRCODE = '42501';
    END IF;

    -- Check if employee already has an open attendance session anywhere globally
    SELECT id, station_id, check_in_time, shift_name_snapshot, scheduled_start_at_snapshot, scheduled_end_at_snapshot
    INTO v_open_record
    FROM public.attendance_records
    WHERE employee_user_id = v_user_id AND check_out_time IS NULL;

    IF FOUND THEN
        IF v_open_record.station_id <> v_challenge.station_id THEN
            RAISE EXCEPTION 'Employee already has an open attendance session at another station'
                USING ERRCODE = 'P0023';
        END IF;

        -- Action is CHECK_OUT for current station
        v_action := 'CHECK_OUT';
        v_shift_preview := jsonb_build_object(
            'attendance_id', v_open_record.id,
            'shift_name', v_open_record.shift_name_snapshot,
            'check_in_time', v_open_record.check_in_time,
            'elapsed_minutes', GREATEST(0, floor(extract(epoch from (v_now - v_open_record.check_in_time)) / 60.0)::INTEGER)
        );
    ELSE
        -- Action is CHECK_IN -> Resolve published shift assignment
        v_action := 'CHECK_IN';

        -- Check matching published shifts count for ambiguity detection
        SELECT count(*) INTO v_matching_shift_count
        FROM public.shift_assignments sa
        JOIN public.work_schedule_shifts wss ON sa.work_schedule_shift_id = wss.id
        JOIN public.work_schedules ws ON wss.work_schedule_id = ws.id
        WHERE sa.user_id = v_user_id
          AND wss.station_id = v_challenge.station_id
          AND ws.status = 'PUBLISHED'
          AND (v_now >= (wss.starts_at - (v_challenge.check_in_early_minutes * INTERVAL '1 minute')))
          AND (v_now < wss.ends_at);

        IF v_matching_shift_count = 0 THEN
            RAISE EXCEPTION 'No published shift assignment found for check-in window' USING ERRCODE = 'P0024';
        END IF;

        -- If multiple shifts match at identical start time / distance, raise ambiguous shift error
        IF v_matching_shift_count > 1 THEN
            IF EXISTS (
                SELECT 1
                FROM (
                    SELECT wss.starts_at, count(*) AS c
                    FROM public.shift_assignments sa
                    JOIN public.work_schedule_shifts wss ON sa.work_schedule_shift_id = wss.id
                    JOIN public.work_schedules ws ON wss.work_schedule_id = ws.id
                    WHERE sa.user_id = v_user_id
                      AND wss.station_id = v_challenge.station_id
                      AND ws.status = 'PUBLISHED'
                      AND (v_now >= (wss.starts_at - (v_challenge.check_in_early_minutes * INTERVAL '1 minute')))
                      AND (v_now < wss.ends_at)
                    GROUP BY wss.starts_at
                    HAVING count(*) > 1
                ) sub
            ) THEN
                RAISE EXCEPTION 'Multiple conflicting shift assignments found. Please contact station manager.'
                    USING ERRCODE = 'P0036';
            END IF;
        END IF;

        SELECT wss.id AS shift_id, wss.work_schedule_id, sa.id AS assignment_id,
               ws.version AS schedule_version, wss.shift_name_snapshot,
               wss.starts_at, wss.ends_at, wss.operational_date
        INTO v_shift
        FROM public.shift_assignments sa
        JOIN public.work_schedule_shifts wss ON sa.work_schedule_shift_id = wss.id
        JOIN public.work_schedules ws ON wss.work_schedule_id = ws.id
        WHERE sa.user_id = v_user_id
          AND wss.station_id = v_challenge.station_id
          AND ws.status = 'PUBLISHED'
          AND (v_now >= (wss.starts_at - (v_challenge.check_in_early_minutes * INTERVAL '1 minute')))
          AND (v_now < wss.ends_at)
        ORDER BY abs(extract(epoch from (v_now - wss.starts_at))) ASC, wss.starts_at ASC, wss.id ASC
        LIMIT 1;

        v_shift_preview := jsonb_build_object(
            'shift_id', v_shift.shift_id,
            'shift_name', v_shift.shift_name_snapshot,
            'operational_date', v_shift.operational_date,
            'starts_at', v_shift.starts_at,
            'ends_at', v_shift.ends_at
        );
    END IF;

    -- Issue 60-second single-use presence proof
    v_presence_token := 'PP_' || encode(gen_random_bytes(16), 'hex');
    v_token_hash := encode(digest(v_presence_token, 'sha256'), 'hex');
    v_proof_expires_at := v_now + INTERVAL '60 seconds';

    INSERT INTO public.attendance_presence_proofs (
        station_id, employee_user_id, station_membership_id, kiosk_device_id,
        qr_challenge_id, action, token_hash, expires_at
    ) VALUES (
        v_challenge.station_id, v_user_id, v_membership.id, v_challenge.kiosk_device_id,
        v_challenge.id, v_action, v_token_hash, v_proof_expires_at
    );

    -- Log scan attempt success
    INSERT INTO public.attendance_rate_limit_attempts (actor_id, target_identifier, action, is_success)
    VALUES (v_user_id, v_clean_input, 'QR_SCAN', true);

    RETURN jsonb_build_object(
        'success', true,
        'presence_proof_token', v_presence_token,
        'action', v_action,
        'expires_at', v_proof_expires_at,
        'station_id', v_challenge.station_id,
        'station_name', v_challenge.station_name,
        'shift_preview', v_shift_preview
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 4. Hardened Check In with Presence Proof (Row lock on proof & kiosk active check)
CREATE OR REPLACE FUNCTION public.check_in_with_presence_proof(
    p_presence_proof_token TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_token_hash TEXT;
    v_proof RECORD;
    v_station RECORD;
    v_shift RECORD;
    v_attendance_id UUID;
    v_diff_minutes INTEGER;
    v_late_minutes INTEGER := 0;
    v_now TIMESTAMPTZ := now();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_token_hash := encode(digest(trim(p_presence_proof_token), 'sha256'), 'hex');

    -- Lookup and lock presence proof
    SELECT id, station_id, employee_user_id, station_membership_id, kiosk_device_id,
           action, expires_at, used_at
    INTO v_proof
    FROM public.attendance_presence_proofs
    WHERE token_hash = v_token_hash
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid presence proof' USING ERRCODE = 'P0025';
    END IF;

    IF v_proof.used_at IS NOT NULL THEN
        RAISE EXCEPTION 'Presence proof has already been used' USING ERRCODE = 'P0026';
    END IF;

    IF v_proof.expires_at <= v_now THEN
        RAISE EXCEPTION 'Presence proof has expired' USING ERRCODE = 'P0027';
    END IF;

    IF v_proof.employee_user_id <> v_user_id THEN
        RAISE EXCEPTION 'Presence proof belongs to another employee' USING ERRCODE = 'P0028';
    END IF;

    IF v_proof.action <> 'CHECK_IN' THEN
        RAISE EXCEPTION 'Presence proof action mismatch (Expected CHECK_IN)' USING ERRCODE = 'P0029';
    END IF;

    -- Verify issuing kiosk is currently active
    IF NOT EXISTS (
        SELECT 1 FROM public.kiosk_devices WHERE id = v_proof.kiosk_device_id AND is_active = true
    ) THEN
        RAISE EXCEPTION 'Kiosk device is inactive' USING ERRCODE = 'P0018';
    END IF;

    -- Global Employee Profile Lock for race serialization
    PERFORM 1 FROM public.profiles WHERE id = v_user_id FOR UPDATE;

    -- Assert no open session exists globally
    IF EXISTS (
        SELECT 1 FROM public.attendance_records
        WHERE employee_user_id = v_user_id AND check_out_time IS NULL
    ) THEN
        RAISE EXCEPTION 'Employee already has an open attendance session' USING ERRCODE = 'P0023';
    END IF;

    -- Load station policy
    SELECT name, is_active, check_in_early_minutes, late_grace_minutes
    INTO v_station
    FROM public.stations WHERE id = v_proof.station_id;

    -- Resolve published shift assignment
    SELECT wss.id AS shift_id, wss.work_schedule_id, sa.id AS assignment_id,
           ws.version AS schedule_version, wss.shift_name_snapshot,
           wss.starts_at, wss.ends_at
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

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No matching published shift assignment found for check-in' USING ERRCODE = 'P0024';
    END IF;

    -- Calculate Lateness with grace policy
    v_diff_minutes := floor(extract(epoch from (v_now - v_shift.starts_at)) / 60.0)::INTEGER;
    IF v_diff_minutes > v_station.late_grace_minutes THEN
        v_late_minutes := v_diff_minutes;
    ELSE
        v_late_minutes := 0;
    END IF;

    -- Consume proof atomically
    UPDATE public.attendance_presence_proofs
    SET used_at = v_now
    WHERE id = v_proof.id;

    -- Insert attendance record with frozen snapshot
    INSERT INTO public.attendance_records (
        station_id, employee_user_id, station_membership_id,
        work_schedule_id, work_schedule_shift_id, shift_assignment_id,
        schedule_version_at_check_in, shift_name_snapshot,
        scheduled_start_at_snapshot, scheduled_end_at_snapshot,
        check_in_time, late_minutes, status, verification_method,
        check_in_kiosk_device_id
    ) VALUES (
        v_proof.station_id, v_user_id, v_proof.station_membership_id,
        v_shift.work_schedule_id, v_shift.shift_id, v_shift.assignment_id,
        v_shift.schedule_version, v_shift.shift_name_snapshot,
        v_shift.starts_at, v_shift.ends_at,
        v_now, v_late_minutes, 'OPEN', 'QR_ONLY',
        v_proof.kiosk_device_id
    ) RETURNING id INTO v_attendance_id;

    -- Audit log
    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        v_proof.station_id, v_user_id, 'ATTENDANCE_CHECKED_IN', 'attendance_records', v_attendance_id,
        jsonb_build_object(
            'shift_name', v_shift.shift_name_snapshot,
            'late_minutes', v_late_minutes,
            'check_in_time', v_now
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'attendance_id', v_attendance_id,
        'station_id', v_proof.station_id,
        'station_name', v_station.name,
        'shift_name', v_shift.shift_name_snapshot,
        'check_in_time', v_now,
        'late_minutes', v_late_minutes,
        'status', 'OPEN'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 5. Hardened Check Out with Presence Proof (Row lock on proof)
CREATE OR REPLACE FUNCTION public.check_out_with_presence_proof(
    p_presence_proof_token TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_token_hash TEXT;
    v_proof RECORD;
    v_rec RECORD;
    v_worked_minutes INTEGER;
    v_now TIMESTAMPTZ := now();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_token_hash := encode(digest(trim(p_presence_proof_token), 'sha256'), 'hex');

    -- Lookup and lock presence proof
    SELECT id, station_id, employee_user_id, kiosk_device_id, action, expires_at, used_at
    INTO v_proof
    FROM public.attendance_presence_proofs
    WHERE token_hash = v_token_hash
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid presence proof' USING ERRCODE = 'P0025';
    END IF;

    IF v_proof.used_at IS NOT NULL THEN
        RAISE EXCEPTION 'Presence proof has already been used' USING ERRCODE = 'P0026';
    END IF;

    IF v_proof.expires_at <= v_now THEN
        RAISE EXCEPTION 'Presence proof has expired' USING ERRCODE = 'P0027';
    END IF;

    IF v_proof.employee_user_id <> v_user_id THEN
        RAISE EXCEPTION 'Presence proof belongs to another employee' USING ERRCODE = 'P0028';
    END IF;

    IF v_proof.action <> 'CHECK_OUT' THEN
        RAISE EXCEPTION 'Presence proof action mismatch (Expected CHECK_OUT)' USING ERRCODE = 'P0029';
    END IF;

    -- Global Employee Profile Lock for race serialization
    PERFORM 1 FROM public.profiles WHERE id = v_user_id FOR UPDATE;

    -- Locate open record for caller
    SELECT id, station_id, check_in_time, shift_name_snapshot
    INTO v_rec
    FROM public.attendance_records
    WHERE employee_user_id = v_user_id AND check_out_time IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No open attendance record found for checkout' USING ERRCODE = 'P0030';
    END IF;

    IF v_rec.station_id <> v_proof.station_id THEN
        RAISE EXCEPTION 'Checkout station mismatch: must checkout at the same station where checked in'
            USING ERRCODE = 'P0031';
    END IF;

    -- Calculate worked minutes from real UTC elapsed duration
    v_worked_minutes := GREATEST(0, floor(extract(epoch from (v_now - v_rec.check_in_time)) / 60.0)::INTEGER);

    -- Consume proof atomically
    UPDATE public.attendance_presence_proofs
    SET used_at = v_now
    WHERE id = v_proof.id;

    -- Finalize attendance record
    UPDATE public.attendance_records
    SET check_out_time = v_now,
        worked_minutes = v_worked_minutes,
        status = 'COMPLETED',
        check_out_kiosk_device_id = v_proof.kiosk_device_id,
        updated_at = v_now
    WHERE id = v_rec.id;

    -- Audit log
    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        v_rec.station_id, v_user_id, 'ATTENDANCE_CHECKED_OUT', 'attendance_records', v_rec.id,
        jsonb_build_object(
            'check_in_time', v_rec.check_in_time,
            'check_out_time', v_now,
            'worked_minutes', v_worked_minutes
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'attendance_id', v_rec.id,
        'station_id', v_rec.station_id,
        'shift_name', v_rec.shift_name_snapshot,
        'check_in_time', v_rec.check_in_time,
        'check_out_time', v_now,
        'worked_minutes', v_worked_minutes,
        'status', 'COMPLETED'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 6. Remediated Admin Manual Attendance Correction (Exact half-open interval overlap fix)
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
    WHERE id = p_attendance_record_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Attendance record not found' USING ERRCODE = 'P0033';
    END IF;

    IF NOT public.has_station_permission(v_rec.station_id, v_caller_id, 'attendance.correct') THEN
        RAISE EXCEPTION 'Access denied: caller cannot perform manual attendance corrections' USING ERRCODE = '42501';
    END IF;

    IF p_new_check_out IS NOT NULL AND p_new_check_out <= p_new_check_in THEN
        RAISE EXCEPTION 'Check-out time must be after check-in time' USING ERRCODE = 'P0034';
    END IF;

    -- Validate no half-open overlap [p_new_check_in, p_new_check_out) with other attendance records
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
        -- Record remains open: check that p_new_check_in <= now()
        IF p_new_check_in > now() THEN
            RAISE EXCEPTION 'Check-in time cannot be in the future' USING ERRCODE = 'P0034';
        END IF;
        v_new_worked_minutes := NULL;
    END IF;

    -- Insert into immutable correction ledger
    INSERT INTO public.attendance_corrections (
        attendance_record_id, station_id, actor_user_id,
        previous_check_in_time, new_check_in_time,
        previous_check_out_time, new_check_out_time,
        previous_worked_minutes, new_worked_minutes,
        reason
    ) VALUES (
        p_attendance_record_id, v_rec.station_id, v_caller_id,
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
        updated_at = now()
    WHERE id = p_attendance_record_id;

    -- Audit log
    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        v_rec.station_id, v_caller_id, 'ATTENDANCE_MANUALLY_CORRECTED', 'attendance_records', p_attendance_record_id,
        jsonb_build_object(
            'reason', v_clean_reason,
            'previous_check_in', v_rec.check_in_time,
            'new_check_in', p_new_check_in,
            'previous_check_out', v_rec.check_out_time,
            'new_check_out', p_new_check_out
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'attendance_id', p_attendance_record_id,
        'check_in_time', p_new_check_in,
        'check_out_time', p_new_check_out,
        'worked_minutes', v_new_worked_minutes,
        'status', 'CORRECTED'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 7. Grant Execution Matrix Hardening
REVOKE ALL ON FUNCTION public.kiosk_authenticate_and_mint_qr(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kiosk_authenticate_and_mint_qr(UUID, TEXT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.scan_attendance_qr(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.scan_attendance_qr(TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.check_in_with_presence_proof(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_in_with_presence_proof(TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.check_out_with_presence_proof(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_out_with_presence_proof(TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.correct_attendance_record(UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.correct_attendance_record(UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.get_manager_live_attendance(UUID, DATE) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_manager_live_attendance(UUID, DATE) TO authenticated;

REVOKE ALL ON FUNCTION public.get_my_attendance_history(UUID, INTEGER, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_attendance_history(UUID, INTEGER, INTEGER) TO authenticated;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        GRANT EXECUTE ON FUNCTION public.kiosk_authenticate_and_mint_qr(UUID, TEXT, TEXT) TO service_role;
        GRANT EXECUTE ON FUNCTION public.scan_attendance_qr(TEXT) TO service_role;
        GRANT EXECUTE ON FUNCTION public.check_in_with_presence_proof(TEXT) TO service_role;
        GRANT EXECUTE ON FUNCTION public.check_out_with_presence_proof(TEXT) TO service_role;
        GRANT EXECUTE ON FUNCTION public.correct_attendance_record(UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) TO service_role;
        GRANT EXECUTE ON FUNCTION public.get_manager_live_attendance(UUID, DATE) TO service_role;
        GRANT EXECUTE ON FUNCTION public.get_my_attendance_history(UUID, INTEGER, INTEGER) TO service_role;
    END IF;
END $$;
