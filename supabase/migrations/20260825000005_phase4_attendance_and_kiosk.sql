-- YellowShifts Phase 4 Migration
-- Live Attendance, Station Kiosk, Dynamic QR Presence Proof, Check-In / Check-Out, Realtime Operations & Attendance Integrity
-- Canonical Migration: 20260825000005_phase4_attendance_and_kiosk.sql

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Enums
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'attendance_action') THEN
        CREATE TYPE public.attendance_action AS ENUM ('CHECK_IN', 'CHECK_OUT');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'attendance_status') THEN
        CREATE TYPE public.attendance_status AS ENUM ('OPEN', 'COMPLETED', 'CORRECTED');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'attendance_verification_method') THEN
        CREATE TYPE public.attendance_verification_method AS ENUM ('QR_ONLY', 'QR_PLUS_IDENTITY', 'MANUAL_ADMIN');
    END IF;
END $$;

-- 2. Station Policy Extensions
ALTER TABLE public.stations ADD COLUMN IF NOT EXISTS check_in_early_minutes INTEGER NOT NULL DEFAULT 60;
ALTER TABLE public.stations ADD COLUMN IF NOT EXISTS late_grace_minutes INTEGER NOT NULL DEFAULT 5;

-- 3. Kiosk Devices Table
CREATE TABLE IF NOT EXISTS public.kiosk_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    device_identifier TEXT NOT NULL,
    secret_hash TEXT NOT NULL,
    credential_version INTEGER NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_seen_at TIMESTAMPTZ NULL,
    created_by UUID NOT NULL REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_kiosk_station_device UNIQUE (station_id, device_identifier)
);

CREATE INDEX IF NOT EXISTS idx_kiosk_devices_station ON public.kiosk_devices(station_id, is_active);

-- 4. Dynamic QR Challenges Table (Short-lived 30s broadcast)
CREATE TABLE IF NOT EXISTS public.kiosk_qr_challenges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    kiosk_device_id UUID NOT NULL REFERENCES public.kiosk_devices(id) ON DELETE CASCADE,
    challenge_hash TEXT NOT NULL UNIQUE,
    display_code TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_kiosk_challenges_hash ON public.kiosk_qr_challenges(challenge_hash);
CREATE INDEX IF NOT EXISTS idx_kiosk_challenges_code ON public.kiosk_qr_challenges(display_code);
CREATE INDEX IF NOT EXISTS idx_kiosk_challenges_kiosk ON public.kiosk_qr_challenges(kiosk_device_id, expires_at);

-- 5. Presence Proofs Table (Single-use 60s employee proof)
CREATE TABLE IF NOT EXISTS public.attendance_presence_proofs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    employee_user_id UUID NOT NULL REFERENCES public.profiles(id),
    station_membership_id UUID NOT NULL REFERENCES public.station_memberships(id),
    kiosk_device_id UUID NOT NULL REFERENCES public.kiosk_devices(id),
    qr_challenge_id UUID NOT NULL REFERENCES public.kiosk_qr_challenges(id),
    action public.attendance_action NOT NULL,
    token_hash TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_presence_proofs_hash ON public.attendance_presence_proofs(token_hash);
CREATE INDEX IF NOT EXISTS idx_presence_proofs_user ON public.attendance_presence_proofs(employee_user_id, expires_at);

-- 6. Attendance Records Table
CREATE TABLE IF NOT EXISTS public.attendance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE RESTRICT,
    employee_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    station_membership_id UUID NOT NULL REFERENCES public.station_memberships(id) ON DELETE RESTRICT,
    work_schedule_id UUID NULL REFERENCES public.work_schedules(id) ON DELETE SET NULL,
    work_schedule_shift_id UUID NULL REFERENCES public.work_schedule_shifts(id) ON DELETE SET NULL,
    shift_assignment_id UUID NULL REFERENCES public.shift_assignments(id) ON DELETE SET NULL,
    schedule_version_at_check_in INTEGER NULL,
    shift_name_snapshot TEXT NULL,
    scheduled_start_at_snapshot TIMESTAMPTZ NULL,
    scheduled_end_at_snapshot TIMESTAMPTZ NULL,
    check_in_time TIMESTAMPTZ NOT NULL,
    check_out_time TIMESTAMPTZ NULL,
    worked_minutes INTEGER NULL,
    late_minutes INTEGER NOT NULL DEFAULT 0,
    status public.attendance_status NOT NULL DEFAULT 'OPEN',
    verification_method public.attendance_verification_method NOT NULL DEFAULT 'QR_ONLY',
    check_in_kiosk_device_id UUID NOT NULL REFERENCES public.kiosk_devices(id),
    check_out_kiosk_device_id UUID NULL REFERENCES public.kiosk_devices(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Invariant: One open session globally per employee
CREATE UNIQUE INDEX IF NOT EXISTS uq_attendance_single_open_session 
ON public.attendance_records (employee_user_id) 
WHERE check_out_time IS NULL;

CREATE INDEX IF NOT EXISTS idx_attendance_records_station_date 
ON public.attendance_records(station_id, check_in_time DESC);

CREATE INDEX IF NOT EXISTS idx_attendance_records_user_date 
ON public.attendance_records(employee_user_id, check_in_time DESC);

CREATE INDEX IF NOT EXISTS idx_attendance_records_shift 
ON public.attendance_records(work_schedule_shift_id);

-- 7. Attendance Corrections Table (Append-only manual ledger)
CREATE TABLE IF NOT EXISTS public.attendance_corrections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    attendance_record_id UUID NOT NULL REFERENCES public.attendance_records(id) ON DELETE RESTRICT,
    station_id UUID NOT NULL REFERENCES public.stations(id),
    actor_user_id UUID NOT NULL REFERENCES public.profiles(id),
    previous_check_in_time TIMESTAMPTZ NULL,
    new_check_in_time TIMESTAMPTZ NULL,
    previous_check_out_time TIMESTAMPTZ NULL,
    new_check_out_time TIMESTAMPTZ NULL,
    previous_worked_minutes INTEGER NULL,
    new_worked_minutes INTEGER NULL,
    reason TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_attendance_corrections_record 
ON public.attendance_corrections(attendance_record_id, created_at DESC);

-- 8. Extend Permission System
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
            'schedule.read', 'attendance.read'
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

-- 9. Row Level Security Policies
ALTER TABLE public.kiosk_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kiosk_qr_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_presence_proofs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_corrections ENABLE ROW LEVEL SECURITY;

-- Kiosk Devices Policies:
-- Admins and authorized managers can view device metadata (excluding raw secret)
CREATE POLICY kiosk_devices_select_manager ON public.kiosk_devices
    FOR SELECT TO authenticated
    USING (
        public.has_station_permission(station_id, auth.uid(), 'attendance.kiosk.manage') OR
        public.has_station_permission(station_id, auth.uid(), 'attendance.team.read')
    );

-- Zero direct client INSERT/UPDATE/DELETE on kiosk_devices
CREATE POLICY kiosk_devices_insert_deny ON public.kiosk_devices FOR INSERT TO authenticated WITH CHECK (false);
CREATE POLICY kiosk_devices_update_deny ON public.kiosk_devices FOR UPDATE TO authenticated USING (false);
CREATE POLICY kiosk_devices_delete_deny ON public.kiosk_devices FOR DELETE TO authenticated USING (false);

-- Challenges & Presence Proofs: Zero direct client table queries (RPC only)
CREATE POLICY challenges_all_deny ON public.kiosk_qr_challenges FOR ALL TO authenticated USING (false);
CREATE POLICY proofs_all_deny ON public.attendance_presence_proofs FOR ALL TO authenticated USING (false);

-- Attendance Records Policies:
-- Employees view own attendance; Managers/Admins view station attendance
CREATE POLICY attendance_records_select ON public.attendance_records
    FOR SELECT TO authenticated
    USING (
        employee_user_id = auth.uid() OR
        public.has_station_permission(station_id, auth.uid(), 'attendance.team.read')
    );

-- Zero direct client mutation on attendance_records (must use check_in/check_out/correction RPCs)
CREATE POLICY attendance_records_insert_deny ON public.attendance_records FOR INSERT TO authenticated WITH CHECK (false);
CREATE POLICY attendance_records_update_deny ON public.attendance_records FOR UPDATE TO authenticated USING (false);
CREATE POLICY attendance_records_delete_deny ON public.attendance_records FOR DELETE TO authenticated USING (false);

-- Attendance Corrections Policies:
CREATE POLICY attendance_corrections_select ON public.attendance_corrections
    FOR SELECT TO authenticated
    USING (
        public.has_station_permission(station_id, auth.uid(), 'attendance.team.read') OR
        EXISTS (
            SELECT 1 FROM public.attendance_records ar 
            WHERE ar.id = attendance_record_id AND ar.employee_user_id = auth.uid()
        )
    );

CREATE POLICY attendance_corrections_write_deny ON public.attendance_corrections FOR INSERT TO authenticated WITH CHECK (false);
CREATE POLICY attendance_corrections_update_deny ON public.attendance_corrections FOR UPDATE TO authenticated USING (false);
CREATE POLICY attendance_corrections_delete_deny ON public.attendance_corrections FOR DELETE TO authenticated USING (false);

-- Anonymous role lockout across all tables
CREATE POLICY kiosk_devices_anon_deny ON public.kiosk_devices FOR ALL TO anon USING (false);
CREATE POLICY challenges_anon_deny ON public.kiosk_qr_challenges FOR ALL TO anon USING (false);
CREATE POLICY proofs_anon_deny ON public.attendance_presence_proofs FOR ALL TO anon USING (false);
CREATE POLICY attendance_records_anon_deny ON public.attendance_records FOR ALL TO anon USING (false);
CREATE POLICY attendance_corrections_anon_deny ON public.attendance_corrections FOR ALL TO anon USING (false);


-- ====================================================================
-- 10. SERVER-AUTHORITATIVE RPC FUNCTIONS
-- ====================================================================

-- 10.1 Provision Kiosk Device (Admin or attendance.kiosk.manage)
CREATE OR REPLACE FUNCTION public.provision_kiosk_device(
    p_station_id UUID,
    p_name TEXT,
    p_device_identifier TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_clean_name TEXT;
    v_clean_ident TEXT;
    v_raw_secret TEXT;
    v_secret_hash TEXT;
    v_kiosk_id UUID;
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    IF NOT public.has_station_permission(p_station_id, v_caller_id, 'attendance.kiosk.manage') THEN
        RAISE EXCEPTION 'Access denied: caller cannot manage kiosk devices for this station' USING ERRCODE = '42501';
    END IF;

    v_clean_name := trim(p_name);
    v_clean_ident := trim(p_device_identifier);

    IF length(v_clean_name) < 2 OR length(v_clean_ident) < 2 THEN
        RAISE EXCEPTION 'Invalid device name or identifier' USING ERRCODE = 'P0015';
    END IF;

    -- Generate a strong 32-character hexadecimal secret
    v_raw_secret := encode(gen_random_bytes(24), 'hex');
    v_secret_hash := encode(digest(v_raw_secret, 'sha256'), 'hex');

    INSERT INTO public.kiosk_devices (
        station_id, name, device_identifier, secret_hash, credential_version, is_active, created_by
    ) VALUES (
        p_station_id, v_clean_name, v_clean_ident, v_secret_hash, 1, true, v_caller_id
    ) RETURNING id INTO v_kiosk_id;

    -- Audit log
    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        p_station_id, v_caller_id, 'KIOSK_DEVICE_CREATED', 'kiosk_devices', v_kiosk_id,
        jsonb_build_object('name', v_clean_name, 'device_identifier', v_clean_ident)
    );

    RETURN jsonb_build_object(
        'success', true,
        'kiosk_id', v_kiosk_id,
        'name', v_clean_name,
        'device_identifier', v_clean_ident,
        'raw_secret', v_raw_secret
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 10.2 Rotate Kiosk Credentials
CREATE OR REPLACE FUNCTION public.rotate_kiosk_credentials(
    p_kiosk_device_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_station_id UUID;
    v_raw_secret TEXT;
    v_secret_hash TEXT;
    v_new_version INTEGER;
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    SELECT station_id INTO v_station_id
    FROM public.kiosk_devices WHERE id = p_kiosk_device_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Kiosk device not found' USING ERRCODE = 'P0016';
    END IF;

    IF NOT public.has_station_permission(v_station_id, v_caller_id, 'attendance.kiosk.manage') THEN
        RAISE EXCEPTION 'Access denied: caller cannot rotate kiosk credentials' USING ERRCODE = '42501';
    END IF;

    v_raw_secret := encode(gen_random_bytes(24), 'hex');
    v_secret_hash := encode(digest(v_raw_secret, 'sha256'), 'hex');

    UPDATE public.kiosk_devices
    SET secret_hash = v_secret_hash,
        credential_version = credential_version + 1,
        updated_at = now()
    WHERE id = p_kiosk_device_id
    RETURNING credential_version INTO v_new_version;

    -- Invalidate any existing active challenges
    UPDATE public.kiosk_qr_challenges
    SET revoked_at = now()
    WHERE kiosk_device_id = p_kiosk_device_id AND revoked_at IS NULL;

    -- Audit log
    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        v_station_id, v_caller_id, 'KIOSK_CREDENTIAL_ROTATED', 'kiosk_devices', p_kiosk_device_id,
        jsonb_build_object('new_version', v_new_version)
    );

    RETURN jsonb_build_object(
        'success', true,
        'kiosk_id', p_kiosk_device_id,
        'credential_version', v_new_version,
        'raw_secret', v_raw_secret
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 10.3 Deactivate / Reactivate Kiosk Device
CREATE OR REPLACE FUNCTION public.deactivate_kiosk_device(
    p_kiosk_device_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_station_id UUID;
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    SELECT station_id INTO v_station_id
    FROM public.kiosk_devices WHERE id = p_kiosk_device_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Kiosk device not found' USING ERRCODE = 'P0016';
    END IF;

    IF NOT public.has_station_permission(v_station_id, v_caller_id, 'attendance.kiosk.manage') THEN
        RAISE EXCEPTION 'Access denied' USING ERRCODE = '42501';
    END IF;

    UPDATE public.kiosk_devices
    SET is_active = false, updated_at = now()
    WHERE id = p_kiosk_device_id;

    UPDATE public.kiosk_qr_challenges
    SET revoked_at = now()
    WHERE kiosk_device_id = p_kiosk_device_id AND revoked_at IS NULL;

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id)
    VALUES (v_station_id, v_caller_id, 'KIOSK_DEVICE_DEACTIVATED', 'kiosk_devices', p_kiosk_device_id);

    RETURN jsonb_build_object('success', true, 'kiosk_id', p_kiosk_device_id, 'is_active', false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION public.reactivate_kiosk_device(
    p_kiosk_device_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_station_id UUID;
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    SELECT station_id INTO v_station_id
    FROM public.kiosk_devices WHERE id = p_kiosk_device_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Kiosk device not found' USING ERRCODE = 'P0016';
    END IF;

    IF NOT public.has_station_permission(v_station_id, v_caller_id, 'attendance.kiosk.manage') THEN
        RAISE EXCEPTION 'Access denied' USING ERRCODE = '42501';
    END IF;

    UPDATE public.kiosk_devices
    SET is_active = true, updated_at = now()
    WHERE id = p_kiosk_device_id;

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id)
    VALUES (v_station_id, v_caller_id, 'KIOSK_DEVICE_REACTIVATED', 'kiosk_devices', p_kiosk_device_id);

    RETURN jsonb_build_object('success', true, 'kiosk_id', p_kiosk_device_id, 'is_active', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 10.4 Kiosk Authentication & Dynamic QR Challenge Minting (30s TTL)
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
BEGIN
    -- Verify station exists and active
    SELECT name, is_active INTO v_station_name, v_station_active
    FROM public.stations WHERE id = p_station_id;

    IF NOT FOUND OR NOT v_station_active THEN
        RAISE EXCEPTION 'Station not found or inactive' USING ERRCODE = 'P0017';
    END IF;

    -- Lookup kiosk device
    SELECT id, secret_hash, credential_version, is_active
    INTO v_kiosk
    FROM public.kiosk_devices
    WHERE station_id = p_station_id AND device_identifier = trim(p_device_identifier);

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Kiosk device not found' USING ERRCODE = 'P0016';
    END IF;

    IF NOT v_kiosk.is_active THEN
        RAISE EXCEPTION 'Kiosk device is inactive' USING ERRCODE = 'P0018';
    END IF;

    -- Validate secret
    v_provided_hash := encode(digest(p_device_secret, 'sha256'), 'hex');
    IF v_provided_hash <> v_kiosk.secret_hash THEN
        RAISE EXCEPTION 'Invalid kiosk credentials' USING ERRCODE = 'P0019';
    END IF;

    -- Update last seen
    UPDATE public.kiosk_devices
    SET last_seen_at = now()
    WHERE id = v_kiosk.id;

    -- Generate random token (32 hex characters) and short 6-char display code
    v_qr_token := 'YQ_' || encode(gen_random_bytes(16), 'hex');
    v_challenge_hash := encode(digest(v_qr_token, 'sha256'), 'hex');
    v_display_code := upper(substring(encode(gen_random_bytes(4), 'hex') from 1 for 6));
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

-- 10.5 Employee Scan QR & Issue Presence Proof (60s TTL)
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
    v_station RECORD;
    v_shift_preview JSONB := NULL;
    v_now TIMESTAMPTZ := now();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
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
      AND c.revoked_at IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid attendance QR or manual code' USING ERRCODE = 'P0020';
    END IF;

    IF v_challenge.expires_at <= v_now THEN
        RAISE EXCEPTION 'QR challenge has expired' USING ERRCODE = 'P0021';
    END IF;

    IF NOT v_challenge.kiosk_active OR NOT v_challenge.station_active THEN
        RAISE EXCEPTION 'Kiosk or station is inactive' USING ERRCODE = 'P0022';
    END IF;

    -- Verify employee has ACTIVE membership for this station
    SELECT id, role, status INTO v_membership
    FROM public.station_memberships
    WHERE station_id = v_challenge.station_id AND user_id = v_user_id;

    IF NOT FOUND OR v_membership.status <> 'ACTIVE' THEN
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
        ORDER BY abs(extract(epoch from (v_now - wss.starts_at))) ASC
        LIMIT 1;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'No published shift assignment found for check-in window' USING ERRCODE = 'P0024';
        END IF;

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

-- 10.6 Check In with Presence Proof
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

    -- Lookup presence proof
    SELECT id, station_id, employee_user_id, station_membership_id, kiosk_device_id,
           action, expires_at, used_at
    INTO v_proof
    FROM public.attendance_presence_proofs
    WHERE token_hash = v_token_hash;

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
    ORDER BY abs(extract(epoch from (v_now - wss.starts_at))) ASC
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

-- 10.7 Check Out with Presence Proof
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

    -- Lookup presence proof
    SELECT id, station_id, employee_user_id, kiosk_device_id, action, expires_at, used_at
    INTO v_proof
    FROM public.attendance_presence_proofs
    WHERE token_hash = v_token_hash;

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

    -- Calculate worked minutes from real UTC instants
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

-- 10.8 Manager Live Attendance Operational View & KPIs
CREATE OR REPLACE FUNCTION public.get_manager_live_attendance(
    p_station_id UUID,
    p_target_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_working_count INTEGER := 0;
    v_upcoming_count INTEGER := 0;
    v_late_count INTEGER := 0;
    v_completed_count INTEGER := 0;
    v_not_checked_in_count INTEGER := 0;
    v_roster JSONB;
    v_now TIMESTAMPTZ := now();
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    IF NOT public.has_station_permission(p_station_id, v_caller_id, 'attendance.team.read') THEN
        RAISE EXCEPTION 'Access denied: caller cannot view team attendance' USING ERRCODE = '42501';
    END IF;

    -- Build comprehensive roster combining scheduled assignments and actual attendance
    WITH station_scheduled AS (
        SELECT wss.id AS shift_id, wss.shift_name_snapshot, wss.starts_at, wss.ends_at,
               sa.id AS assignment_id, sa.user_id, p.first_name, p.last_name, sm.employee_code,
               ar.id AS attendance_id, ar.check_in_time, ar.check_out_time, ar.worked_minutes,
               ar.late_minutes, ar.status AS attendance_status,
               CASE 
                   WHEN ar.id IS NOT NULL AND ar.check_out_time IS NULL THEN 'WORKING'
                   WHEN ar.id IS NOT NULL AND ar.check_out_time IS NOT NULL THEN 'COMPLETED'
                   WHEN ar.id IS NULL AND v_now < wss.starts_at THEN 'UPCOMING'
                   WHEN ar.id IS NULL AND v_now >= wss.starts_at THEN 'NOT_CHECKED_IN'
                   ELSE 'UNKNOWN'
               END AS operational_status
        FROM public.work_schedule_shifts wss
        JOIN public.work_schedules ws ON wss.work_schedule_id = ws.id
        JOIN public.shift_assignments sa ON sa.work_schedule_shift_id = wss.id
        JOIN public.profiles p ON sa.user_id = p.id
        JOIN public.station_memberships sm ON (sm.station_id = p_station_id AND sm.user_id = sa.user_id)
        LEFT JOIN public.attendance_records ar ON (ar.work_schedule_shift_id = wss.id AND ar.employee_user_id = sa.user_id)
        WHERE wss.station_id = p_station_id
          AND wss.operational_date = p_target_date
          AND ws.status = 'PUBLISHED'
    )
    SELECT 
        COALESCE(count(*) FILTER (WHERE operational_status = 'WORKING'), 0),
        COALESCE(count(*) FILTER (WHERE operational_status = 'UPCOMING'), 0),
        COALESCE(count(*) FILTER (WHERE late_minutes > 0), 0),
        COALESCE(count(*) FILTER (WHERE operational_status = 'COMPLETED'), 0),
        COALESCE(count(*) FILTER (WHERE operational_status = 'NOT_CHECKED_IN'), 0),
        COALESCE(jsonb_agg(
            jsonb_build_object(
                'shift_id', shift_id,
                'shift_name', shift_name_snapshot,
                'starts_at', starts_at,
                'ends_at', ends_at,
                'assignment_id', assignment_id,
                'user_id', user_id,
                'first_name', first_name,
                'last_name', last_name,
                'employee_code', employee_code,
                'attendance_id', attendance_id,
                'check_in_time', check_in_time,
                'check_out_time', check_out_time,
                'worked_minutes', worked_minutes,
                'late_minutes', late_minutes,
                'operational_status', operational_status,
                'elapsed_minutes', CASE 
                    WHEN check_in_time IS NOT NULL AND check_out_time IS NULL 
                    THEN GREATEST(0, floor(extract(epoch from (v_now - check_in_time)) / 60.0)::INTEGER)
                    ELSE worked_minutes 
                END
            ) ORDER BY starts_at ASC, last_name ASC
        ), '[]'::jsonb)
    INTO v_working_count, v_upcoming_count, v_late_count, v_completed_count, v_not_checked_in_count, v_roster
    FROM station_scheduled;

    RETURN jsonb_build_object(
        'success', true,
        'station_id', p_station_id,
        'target_date', p_target_date,
        'kpis', jsonb_build_object(
            'currently_working', v_working_count,
            'scheduled_upcoming', v_upcoming_count,
            'late_checked_in', v_late_count,
            'completed', v_completed_count,
            'not_checked_in', v_not_checked_in_count
        ),
        'roster', v_roster
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp STABLE;

-- 10.9 Get Employee Attendance History
CREATE OR REPLACE FUNCTION public.get_my_attendance_history(
    p_station_id UUID,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_records JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', ar.id,
            'station_id', ar.station_id,
            'shift_name', ar.shift_name_snapshot,
            'scheduled_start_at', ar.scheduled_start_at_snapshot,
            'scheduled_end_at', ar.scheduled_end_at_snapshot,
            'check_in_time', ar.check_in_time,
            'check_out_time', ar.check_out_time,
            'worked_minutes', ar.worked_minutes,
            'late_minutes', ar.late_minutes,
            'status', ar.status,
            'verification_method', ar.verification_method
        ) ORDER BY ar.check_in_time DESC
    ), '[]'::jsonb)
    INTO v_records
    FROM (
        SELECT * FROM public.attendance_records
        WHERE employee_user_id = v_user_id AND station_id = p_station_id
        ORDER BY check_in_time DESC
        LIMIT LEAST(p_limit, 100) OFFSET GREATEST(p_offset, 0)
    ) ar;

    RETURN jsonb_build_object('success', true, 'records', v_records);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp STABLE;

-- 10.10 Admin Manual Attendance Correction & Immutable Ledger
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

    IF p_new_check_out <= p_new_check_in THEN
        RAISE EXCEPTION 'Check-out time must be after check-in time' USING ERRCODE = 'P0034';
    END IF;

    -- Validate no half-open overlap with other attendance records for the same employee [starts, ends)
    SELECT id, check_in_time, check_out_time INTO v_overlap_rec
    FROM public.attendance_records
    WHERE employee_user_id = v_rec.employee_user_id
      AND id <> p_attendance_record_id
      AND check_out_time IS NOT NULL
      AND (p_new_check_in < check_out_time AND v_rec.check_in_time < p_new_check_out)
    LIMIT 1;

    IF FOUND THEN
        RAISE EXCEPTION 'Corrected time range overlaps with another attendance record for this employee'
            USING ERRCODE = 'P0035';
    END IF;

    v_new_worked_minutes := GREATEST(0, floor(extract(epoch from (p_new_check_out - p_new_check_in)) / 60.0)::INTEGER);

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

-- 10.11 Ephemeral Data Cleanup
CREATE OR REPLACE FUNCTION public.cleanup_ephemeral_attendance_data()
RETURNS JSONB AS $$
DECLARE
    v_purged_challenges INTEGER;
    v_purged_proofs INTEGER;
BEGIN
    DELETE FROM public.kiosk_qr_challenges
    WHERE expires_at < (now() - INTERVAL '24 hours');
    GET DIAGNOSTICS v_purged_challenges = ROW_COUNT;

    DELETE FROM public.attendance_presence_proofs
    WHERE expires_at < (now() - INTERVAL '24 hours');
    GET DIAGNOSTICS v_purged_proofs = ROW_COUNT;

    RETURN jsonb_build_object(
        'success', true,
        'purged_challenges', v_purged_challenges,
        'purged_proofs', v_purged_proofs
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 11. Realtime Publication Grants
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'attendance_records'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.attendance_records;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'kiosk_devices'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.kiosk_devices;
    END IF;
END $$;
