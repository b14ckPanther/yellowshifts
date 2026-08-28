-- ======================================================================
-- YELLOWSHIFTS — PHASE 5: IDENTITY VERIFICATION, ACCOUNT ASSURANCE,
-- OPTIONAL LIVENESS, PRIVACY-FIRST BIOMETRIC GATE & ATTENDANCE BINDING
-- Migration: 20260825000007_phase5_identity_verification.sql
-- ======================================================================

-- 1. Identity Enums
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'identity_verification_mode') THEN
        CREATE TYPE public.identity_verification_mode AS ENUM (
            'DISABLED',
            'CHECK_IN_ONLY',
            'CHECK_IN_AND_CHECK_OUT'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'identity_profile_status') THEN
        CREATE TYPE public.identity_profile_status AS ENUM (
            'PENDING',
            'ACTIVE',
            'REVOKED',
            'FAILED'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'enrollment_session_status') THEN
        CREATE TYPE public.enrollment_session_status AS ENUM (
            'PENDING',
            'COMPLETED',
            'EXPIRED',
            'CANCELLED',
            'FAILED'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'identity_verification_result') THEN
        CREATE TYPE public.identity_verification_result AS ENUM (
            'VERIFIED',
            'NOT_VERIFIED',
            'INCONCLUSIVE'
        );
    END IF;
END $$;

-- 2. Extend Stations Table with Identity Verification Policy
ALTER TABLE public.stations 
ADD COLUMN IF NOT EXISTS identity_verification_mode public.identity_verification_mode NOT NULL DEFAULT 'DISABLED';

-- 3. Employee Identity Profiles Table (Global 1:1 Identity Assurance Profile)
-- PRIVACY INVARIANT: Zero raw images, zero selfies, zero embeddings stored in DB.
CREATE TABLE IF NOT EXISTS public.employee_identity_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_user_id UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    provider TEXT NOT NULL,
    provider_subject_id TEXT NULL UNIQUE,
    status public.identity_profile_status NOT NULL DEFAULT 'PENDING',
    notice_version TEXT NOT NULL DEFAULT 'v1.0',
    consented_at TIMESTAMPTZ NULL,
    enrolled_at TIMESTAMPTZ NULL,
    revoked_at TIMESTAMPTZ NULL,
    last_verified_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_identity_profiles_user ON public.employee_identity_profiles(employee_user_id);
CREATE INDEX IF NOT EXISTS idx_identity_profiles_status ON public.employee_identity_profiles(status);

-- 4. Identity Enrollment Sessions Table (Ephemeral 15-min TTL)
CREATE TABLE IF NOT EXISTS public.identity_enrollment_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    provider TEXT NOT NULL,
    provider_session_id TEXT NOT NULL,
    status public.enrollment_session_status NOT NULL DEFAULT 'PENDING',
    notice_version TEXT NOT NULL DEFAULT 'v1.0',
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    completed_at TIMESTAMPTZ NULL
);

CREATE INDEX IF NOT EXISTS idx_enrollment_sessions_user ON public.identity_enrollment_sessions(employee_user_id, status);
CREATE INDEX IF NOT EXISTS idx_enrollment_sessions_expiry ON public.identity_enrollment_sessions(expires_at);

-- 5. Identity Verification Attempts Table (Immutable Categorical Audit Ledger)
CREATE TABLE IF NOT EXISTS public.identity_verification_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    presence_proof_id UUID NOT NULL REFERENCES public.attendance_presence_proofs(id) ON DELETE CASCADE,
    provider TEXT NOT NULL,
    provider_session_id TEXT NULL,
    result public.identity_verification_result NOT NULL,
    failure_category TEXT NULL,
    is_override BOOLEAN NOT NULL DEFAULT false,
    override_actor_id UUID NULL REFERENCES public.profiles(id),
    override_reason TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    completed_at TIMESTAMPTZ NULL
);

CREATE INDEX IF NOT EXISTS idx_verification_attempts_user ON public.identity_verification_attempts(employee_user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_verification_attempts_station ON public.identity_verification_attempts(station_id, created_at);
CREATE INDEX IF NOT EXISTS idx_verification_attempts_presence ON public.identity_verification_attempts(presence_proof_id);

-- 6. Identity Verification Proofs Table (Ephemeral Single-Use 120s TTL)
CREATE TABLE IF NOT EXISTS public.identity_verification_proofs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    presence_proof_id UUID NOT NULL REFERENCES public.attendance_presence_proofs(id) ON DELETE CASCADE,
    verification_attempt_id UUID NOT NULL REFERENCES public.identity_verification_attempts(id) ON DELETE CASCADE,
    action TEXT NOT NULL CHECK (action IN ('CHECK_IN', 'CHECK_OUT')),
    token_hash TEXT NOT NULL UNIQUE,
    is_override BOOLEAN NOT NULL DEFAULT false,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_identity_proofs_lookup ON public.identity_verification_proofs(token_hash, used_at, expires_at);
CREATE INDEX IF NOT EXISTS idx_identity_proofs_presence ON public.identity_verification_proofs(presence_proof_id);

-- 7. Extend Attendance Records Table with Identity Proof Reference
ALTER TABLE public.attendance_records 
ADD COLUMN IF NOT EXISTS identity_verification_proof_id UUID NULL REFERENCES public.identity_verification_proofs(id);

-- 8. Row Level Security Policies
ALTER TABLE public.employee_identity_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.identity_enrollment_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.identity_verification_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.identity_verification_proofs ENABLE ROW LEVEL SECURITY;

-- 8.1 Employee Identity Profiles RLS
DROP POLICY IF EXISTS "identity_profiles_select_own" ON public.employee_identity_profiles;
CREATE POLICY "identity_profiles_select_own" ON public.employee_identity_profiles
    FOR SELECT TO authenticated
    USING (employee_user_id = auth.uid());

DROP POLICY IF EXISTS "identity_profiles_no_direct_write" ON public.employee_identity_profiles;
CREATE POLICY "identity_profiles_no_direct_write" ON public.employee_identity_profiles
    FOR ALL TO authenticated
    USING (false)
    WITH CHECK (false);

-- 8.2 Identity Enrollment Sessions RLS
DROP POLICY IF EXISTS "enrollment_sessions_select_own" ON public.identity_enrollment_sessions;
CREATE POLICY "enrollment_sessions_select_own" ON public.identity_enrollment_sessions
    FOR SELECT TO authenticated
    USING (employee_user_id = auth.uid());

DROP POLICY IF EXISTS "enrollment_sessions_no_direct_write" ON public.identity_enrollment_sessions;
CREATE POLICY "enrollment_sessions_no_direct_write" ON public.identity_enrollment_sessions
    FOR ALL TO authenticated
    USING (false)
    WITH CHECK (false);

-- 8.3 Identity Verification Attempts RLS
DROP POLICY IF EXISTS "verification_attempts_select_own" ON public.identity_verification_attempts;
CREATE POLICY "verification_attempts_select_own" ON public.identity_verification_attempts
    FOR SELECT TO authenticated
    USING (
        employee_user_id = auth.uid() OR 
        public.is_station_manager_or_admin(station_id, auth.uid())
    );

DROP POLICY IF EXISTS "verification_attempts_no_direct_write" ON public.identity_verification_attempts;
CREATE POLICY "verification_attempts_no_direct_write" ON public.identity_verification_attempts
    FOR ALL TO authenticated
    USING (false)
    WITH CHECK (false);

-- 8.4 Identity Verification Proofs RLS
DROP POLICY IF EXISTS "identity_proofs_no_direct_access" ON public.identity_verification_proofs;
CREATE POLICY "identity_proofs_no_direct_access" ON public.identity_verification_proofs
    FOR ALL TO authenticated
    USING (false)
    WITH CHECK (false);

-- ======================================================================
-- 9. OPERATIONAL PROCEDURES & RPCS (SECURITY DEFINER, SEARCH_PATH PINNED)
-- ======================================================================

-- 9.1 Start Identity Enrollment
CREATE OR REPLACE FUNCTION public.start_identity_enrollment(
    p_provider TEXT,
    p_notice_version TEXT DEFAULT 'v1.0'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_session_id UUID;
    v_provider_session_id TEXT;
    v_expires_at TIMESTAMPTZ;
    v_now TIMESTAMPTZ;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    IF p_provider IS NULL OR trim(p_provider) = '' THEN
        RAISE EXCEPTION 'Provider is required' USING ERRCODE = 'P0041';
    END IF;

    v_now := now();
    v_expires_at := v_now + INTERVAL '15 minutes';
    v_session_id := gen_random_uuid();
    v_provider_session_id := 'SES_' || encode(gen_random_bytes(16), 'hex');

    -- Expire any existing pending sessions for this user
    UPDATE public.identity_enrollment_sessions
    SET status = 'EXPIRED'
    WHERE employee_user_id = v_user_id AND status = 'PENDING';

    -- Insert new enrollment session
    INSERT INTO public.identity_enrollment_sessions (
        id, employee_user_id, provider, provider_session_id, status, notice_version, expires_at, created_at
    ) VALUES (
        v_session_id, v_user_id, trim(p_provider), v_provider_session_id, 'PENDING', trim(p_notice_version), v_expires_at, v_now
    );

    -- Ensure profile row exists in PENDING state with recorded consent
    INSERT INTO public.employee_identity_profiles (
        employee_user_id, provider, status, notice_version, consented_at, created_at, updated_at
    ) VALUES (
        v_user_id, trim(p_provider), 'PENDING', trim(p_notice_version), v_now, v_now, v_now
    )
    ON CONFLICT (employee_user_id) DO UPDATE SET
        provider = EXCLUDED.provider,
        notice_version = EXCLUDED.notice_version,
        consented_at = v_now,
        updated_at = v_now;

    RETURN jsonb_build_object(
        'success', true,
        'session_id', v_session_id,
        'provider_session_id', v_provider_session_id,
        'provider', trim(p_provider),
        'notice_version', trim(p_notice_version),
        'expires_at', v_expires_at
    );
END;
$$;

-- 9.2 Complete Identity Enrollment
CREATE OR REPLACE FUNCTION public.complete_identity_enrollment(
    p_session_id UUID,
    p_provider_subject_id TEXT,
    p_is_success BOOLEAN,
    p_failure_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_session RECORD;
    v_now TIMESTAMPTZ;
    v_subject_id TEXT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_now := now();

    -- Lock and validate session
    SELECT * INTO v_session
    FROM public.identity_enrollment_sessions
    WHERE id = p_session_id AND employee_user_id = v_user_id
    FOR UPDATE;

    IF v_session.id IS NULL THEN
        RAISE EXCEPTION 'Enrollment session not found' USING ERRCODE = 'P0042';
    END IF;

    IF v_session.status != 'PENDING' THEN
        RAISE EXCEPTION 'Enrollment session is no longer active' USING ERRCODE = 'P0043';
    END IF;

    IF v_now >= v_session.expires_at THEN
        UPDATE public.identity_enrollment_sessions
        SET status = 'EXPIRED'
        WHERE id = v_session.id;
        RAISE EXCEPTION 'Enrollment session has expired' USING ERRCODE = 'P0044';
    END IF;

    IF p_is_success THEN
        v_subject_id := trim(p_provider_subject_id);
        IF v_subject_id IS NULL OR v_subject_id = '' THEN
            RAISE EXCEPTION 'Provider subject ID is required for successful enrollment' USING ERRCODE = 'P0045';
        END IF;

        -- Update session status
        UPDATE public.identity_enrollment_sessions
        SET status = 'COMPLETED', completed_at = v_now
        WHERE id = v_session.id;

        -- Update or activate profile
        UPDATE public.employee_identity_profiles
        SET provider = v_session.provider,
            provider_subject_id = v_subject_id,
            status = 'ACTIVE',
            enrolled_at = v_now,
            revoked_at = NULL,
            updated_at = v_now
        WHERE employee_user_id = v_user_id;

        RETURN jsonb_build_object(
            'success', true,
            'status', 'ACTIVE',
            'enrolled_at', v_now
        );
    ELSE
        UPDATE public.identity_enrollment_sessions
        SET status = 'FAILED', completed_at = v_now
        WHERE id = v_session.id;

        UPDATE public.employee_identity_profiles
        SET status = 'FAILED', updated_at = v_now
        WHERE employee_user_id = v_user_id;

        RETURN jsonb_build_object(
            'success', false,
            'status', 'FAILED',
            'failure_reason', p_failure_reason
        );
    END IF;
END;
$$;

-- 9.3 Revoke Identity Profile
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
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_now := now();

    -- User can revoke self; Station Admin can revoke members of their station
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

    -- Deactivate profile
    UPDATE public.employee_identity_profiles
    SET status = 'REVOKED',
        revoked_at = v_now,
        provider_subject_id = NULL,
        updated_at = v_now
    WHERE employee_user_id = p_employee_user_id;

    -- Invalidate all unused identity proofs
    UPDATE public.identity_verification_proofs
    SET used_at = v_now
    WHERE employee_user_id = p_employee_user_id AND used_at IS NULL;

    RETURN jsonb_build_object(
        'success', true,
        'status', 'REVOKED',
        'revoked_at', v_now
    );
END;
$$;

-- 9.4 Update Station Identity Policy (Admin Only)
CREATE OR REPLACE FUNCTION public.update_station_identity_policy(
    p_station_id UUID,
    p_mode public.identity_verification_mode
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_admin_id UUID;
    v_prev_mode public.identity_verification_mode;
    v_now TIMESTAMPTZ;
BEGIN
    v_admin_id := auth.uid();
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    -- Must be station admin
    IF NOT public.is_station_admin(p_station_id, v_admin_id) THEN
        RAISE EXCEPTION 'Access denied: Only station admins can configure identity policies' USING ERRCODE = '42501';
    END IF;

    SELECT identity_verification_mode INTO v_prev_mode
    FROM public.stations WHERE id = p_station_id
    FOR UPDATE;

    IF v_prev_mode IS NULL THEN
        RAISE EXCEPTION 'Station not found' USING ERRCODE = 'P0016';
    END IF;

    v_now := now();

    UPDATE public.stations
    SET identity_verification_mode = p_mode,
        updated_at = v_now
    WHERE id = p_station_id;

    -- Log audit change
    INSERT INTO public.audit_logs (
        station_id, actor_id, action, target_type, target_id, metadata
    ) VALUES (
        p_station_id, v_admin_id, 'IDENTITY_VERIFICATION_POLICY_UPDATED', 'stations', p_station_id::text,
        jsonb_build_object('previous_mode', v_prev_mode, 'new_mode', p_mode, 'updated_at', v_now)
    );

    RETURN jsonb_build_object(
        'success', true,
        'station_id', p_station_id,
        'identity_verification_mode', p_mode
    );
END;
$$;

-- 9.5 Start Identity Verification (Bound to Fresh Presence Proof)
CREATE OR REPLACE FUNCTION public.start_identity_verification(
    p_presence_proof_token TEXT,
    p_provider TEXT
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
    v_profile RECORD;
    v_station RECORD;
    v_attempt_id UUID;
    v_provider_session_id TEXT;
    v_now TIMESTAMPTZ;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_now := now();
    v_token_hash := encode(digest(p_presence_proof_token, 'sha256'), 'hex');

    -- Validate presence proof
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

    IF v_proof.employee_user_id != v_user_id THEN
        RAISE EXCEPTION 'Presence proof belongs to another employee' USING ERRCODE = 'P0028';
    END IF;

    -- Validate station policy
    SELECT * INTO v_station FROM public.stations WHERE id = v_proof.station_id;

    -- Validate employee identity profile
    SELECT * INTO v_profile
    FROM public.employee_identity_profiles
    WHERE employee_user_id = v_user_id;

    IF v_profile.id IS NULL OR v_profile.status != 'ACTIVE' THEN
        RAISE EXCEPTION 'Employee is not actively enrolled in identity verification' USING ERRCODE = 'P0047';
    END IF;

    v_attempt_id := gen_random_uuid();
    v_provider_session_id := 'VER_' || encode(gen_random_bytes(16), 'hex');

    -- Create pending attempt record
    INSERT INTO public.identity_verification_attempts (
        id, employee_user_id, station_id, presence_proof_id, provider, provider_session_id, result, created_at
    ) VALUES (
        v_attempt_id, v_user_id, v_proof.station_id, v_proof.id, trim(p_provider), v_provider_session_id, 'INCONCLUSIVE', v_now
    );

    RETURN jsonb_build_object(
        'success', true,
        'attempt_id', v_attempt_id,
        'provider_session_id', v_provider_session_id,
        'station_id', v_proof.station_id,
        'action', v_proof.action,
        'presence_proof_id', v_proof.id
    );
END;
$$;

-- 9.6 Complete Identity Verification (Server Authoritative Issuance of Proof)
CREATE OR REPLACE FUNCTION public.complete_identity_verification(
    p_attempt_id UUID,
    p_is_verified BOOLEAN,
    p_failure_category TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_attempt RECORD;
    v_proof_token TEXT;
    v_token_hash TEXT;
    v_proof_id UUID;
    v_now TIMESTAMPTZ;
    v_expires_at TIMESTAMPTZ;
    v_presence_proof RECORD;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_now := now();

    -- Lock and validate attempt
    SELECT * INTO v_attempt
    FROM public.identity_verification_attempts
    WHERE id = p_attempt_id AND employee_user_id = v_user_id
    FOR UPDATE;

    IF v_attempt.id IS NULL THEN
        RAISE EXCEPTION 'Verification attempt not found' USING ERRCODE = 'P0048';
    END IF;

    IF v_attempt.completed_at IS NOT NULL THEN
        RAISE EXCEPTION 'Verification attempt has already been finalized' USING ERRCODE = 'P0049';
    END IF;

    -- Verify presence proof is still linked and unconsumed
    SELECT * INTO v_presence_proof
    FROM public.attendance_presence_proofs
    WHERE id = v_attempt.presence_proof_id
    FOR UPDATE;

    IF v_presence_proof.used_at IS NOT NULL THEN
        RAISE EXCEPTION 'Associated presence proof has already been used' USING ERRCODE = 'P0026';
    END IF;

    IF p_is_verified THEN
        -- Generate single-use identity proof token (120s TTL)
        v_proof_token := 'IDP_' || encode(gen_random_bytes(24), 'hex');
        v_token_hash := encode(digest(v_proof_token, 'sha256'), 'hex');
        v_expires_at := v_now + INTERVAL '120 seconds';
        v_proof_id := gen_random_uuid();

        UPDATE public.identity_verification_attempts
        SET result = 'VERIFIED', completed_at = v_now
        WHERE id = v_attempt.id;

        INSERT INTO public.identity_verification_proofs (
            id, employee_user_id, station_id, presence_proof_id, verification_attempt_id,
            action, token_hash, is_override, expires_at, created_at
        ) VALUES (
            v_proof_id, v_user_id, v_attempt.station_id, v_attempt.presence_proof_id, v_attempt.id,
            v_presence_proof.action, v_token_hash, false, v_expires_at, v_now
        );

        UPDATE public.employee_identity_profiles
        SET last_verified_at = v_now, updated_at = v_now
        WHERE employee_user_id = v_user_id;

        RETURN jsonb_build_object(
            'success', true,
            'result', 'VERIFIED',
            'identity_proof_token', v_proof_token,
            'expires_at', v_expires_at,
            'action', v_presence_proof.action
        );
    ELSE
        UPDATE public.identity_verification_attempts
        SET result = 'NOT_VERIFIED',
            failure_category = coalesce(trim(p_failure_category), 'VERIFICATION_FAILED'),
            completed_at = v_now
        WHERE id = v_attempt.id;

        RETURN jsonb_build_object(
            'success', false,
            'result', 'NOT_VERIFIED',
            'failure_category', coalesce(trim(p_failure_category), 'VERIFICATION_FAILED')
        );
    END IF;
END;
$$;

-- 9.7 Create Identity Admin Manual Override (Requires Fresh Presence Proof)
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
BEGIN
    v_admin_id := auth.uid();
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_clean_reason := trim(p_reason);
    IF v_clean_reason IS NULL OR length(v_clean_reason) < 3 THEN
        RAISE EXCEPTION 'Override reason must be at least 3 characters long' USING ERRCODE = 'P0032';
    END IF;

    v_now := now();
    v_token_hash := encode(digest(p_presence_proof_token, 'sha256'), 'hex');

    -- Validate presence proof
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

    -- Must be admin of target station
    IF NOT public.is_station_admin(v_proof.station_id, v_admin_id) THEN
        RAISE EXCEPTION 'Access denied: Only station admins can authorize identity overrides' USING ERRCODE = '42501';
    END IF;

    v_attempt_id := gen_random_uuid();
    v_id_proof_id := gen_random_uuid();
    v_id_proof_token := 'IDO_' || encode(gen_random_bytes(24), 'hex');
    v_id_token_hash := encode(digest(v_id_proof_token, 'sha256'), 'hex');
    v_expires_at := v_now + INTERVAL '120 seconds';

    -- Record override attempt in ledger
    INSERT INTO public.identity_verification_attempts (
        id, employee_user_id, station_id, presence_proof_id, provider,
        result, is_override, override_actor_id, override_reason, created_at, completed_at
    ) VALUES (
        v_attempt_id, v_proof.employee_user_id, v_proof.station_id, v_proof.id, 'MANUAL_ADMIN_OVERRIDE',
        'VERIFIED', true, v_admin_id, v_clean_reason, v_now, v_now
    );

    -- Mint presence-bound override identity proof
    INSERT INTO public.identity_verification_proofs (
        id, employee_user_id, station_id, presence_proof_id, verification_attempt_id,
        action, token_hash, is_override, expires_at, created_at
    ) VALUES (
        v_id_proof_id, v_proof.employee_user_id, v_proof.station_id, v_proof.id, v_attempt_id,
        v_proof.action, v_id_token_hash, true, v_expires_at, v_now
    );

    -- Log audit trail
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

    RETURN jsonb_build_object(
        'success', true,
        'override_id', v_attempt_id,
        'identity_proof_token', v_id_proof_token,
        'expires_at', v_expires_at,
        'action', v_proof.action
    );
END;
$$;

-- 9.8 Get My Identity Profile
CREATE OR REPLACE FUNCTION public.get_my_identity_profile()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_profile RECORD;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_profile
    FROM public.employee_identity_profiles
    WHERE employee_user_id = v_user_id;

    IF v_profile.id IS NULL THEN
        RETURN jsonb_build_object(
            'enrolled', false,
            'status', 'NOT_ENROLLED'
        );
    END IF;

    RETURN jsonb_build_object(
        'enrolled', (v_profile.status = 'ACTIVE'),
        'status', v_profile.status,
        'provider', v_profile.provider,
        'notice_version', v_profile.notice_version,
        'consented_at', v_profile.consented_at,
        'enrolled_at', v_profile.enrolled_at,
        'revoked_at', v_profile.revoked_at,
        'last_verified_at', v_profile.last_verified_at
    );
END;
$$;

-- 9.9 Get Station Team Identity Status (Admin / Manager View)
CREATE OR REPLACE FUNCTION public.get_station_team_identity_status(
    p_station_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_station RECORD;
    v_roster JSONB;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    IF NOT public.is_station_manager_or_admin(p_station_id, v_caller_id) THEN
        RAISE EXCEPTION 'Access denied: Manager or Admin role required' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_station FROM public.stations WHERE id = p_station_id;

    SELECT coalesce(jsonb_agg(
        jsonb_build_object(
            'membership_id', sm.id,
            'user_id', sm.user_id,
            'employee_code', sm.employee_code,
            'first_name', p.first_name,
            'last_name', p.last_name,
            'role', sm.role,
            'identity_status', coalesce(ip.status::text, 'NOT_ENROLLED'),
            'enrolled_at', ip.enrolled_at,
            'last_verified_at', ip.last_verified_at
        ) ORDER BY sm.role ASC, p.first_name ASC
    ), '[]'::jsonb) INTO v_roster
    FROM public.station_memberships sm
    JOIN public.profiles p ON sm.user_id = p.id
    LEFT JOIN public.employee_identity_profiles ip ON sm.user_id = ip.employee_user_id
    WHERE sm.station_id = p_station_id AND sm.status = 'ACTIVE';

    RETURN jsonb_build_object(
        'success', true,
        'station_id', p_station_id,
        'identity_verification_mode', v_station.identity_verification_mode,
        'team_roster', v_roster
    );
END;
$$;

-- 9.10 Ephemeral Identity Data Cleanup
CREATE OR REPLACE FUNCTION public.cleanup_ephemeral_identity_data()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_purged_sessions INTEGER := 0;
    v_purged_proofs INTEGER := 0;
BEGIN
    -- Purge expired enrollment sessions older than 1 day
    WITH deleted_ses AS (
        DELETE FROM public.identity_enrollment_sessions
        WHERE expires_at < now() - INTERVAL '1 day'
        RETURNING id
    )
    SELECT count(*) INTO v_purged_sessions FROM deleted_ses;

    -- Purge expired identity proofs older than 1 day
    WITH deleted_proofs AS (
        DELETE FROM public.identity_verification_proofs
        WHERE expires_at < now() - INTERVAL '1 day'
        RETURNING id
    )
    SELECT count(*) INTO v_purged_proofs FROM deleted_proofs;

    RETURN jsonb_build_object(
        'success', true,
        'purged_sessions', v_purged_sessions,
        'purged_identity_proofs', v_purged_proofs
    );
END;
$$;

-- ======================================================================
-- 10. HARDENED ATOMIC CHECK-IN & CHECK-OUT WITH IDENTITY GATE
-- ======================================================================

DROP FUNCTION IF EXISTS public.check_in_with_presence_proof(TEXT);
DROP FUNCTION IF EXISTS public.check_out_with_presence_proof(TEXT);

-- 10.1 Check-In with Presence Proof & Optional Identity Proof
CREATE OR REPLACE FUNCTION public.check_in_with_presence_proof(
    p_presence_proof_token TEXT,
    p_identity_proof_token TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_token_hash TEXT;
    v_id_token_hash TEXT;
    v_proof RECORD;
    v_id_proof RECORD;
    v_id_proof_id UUID := NULL;
    v_station RECORD;
    v_membership RECORD;
    v_kiosk RECORD;
    v_shift RECORD;
    v_now TIMESTAMPTZ;
    v_att_id UUID;
    v_diff_minutes INTEGER;
    v_late_minutes INTEGER := 0;
    v_shift_start TIMESTAMPTZ;
    v_ver_method public.attendance_verification_method := 'QR_ONLY';
    v_requires_identity BOOLEAN := false;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_now := now();
    v_token_hash := encode(digest(p_presence_proof_token, 'sha256'), 'hex');

    -- Lock and validate presence proof row
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

    IF v_proof.employee_user_id != v_user_id THEN
        RAISE EXCEPTION 'Presence proof belongs to another employee' USING ERRCODE = 'P0028';
    END IF;

    IF v_proof.action != 'CHECK_IN' THEN
        RAISE EXCEPTION 'Presence proof is for % action; Expected CHECK_IN', v_proof.action
            USING ERRCODE = 'P0029';
    END IF;

    -- Validate station policy
    SELECT * INTO v_station FROM public.stations WHERE id = v_proof.station_id;
    IF v_station.id IS NULL OR NOT v_station.is_active THEN
        RAISE EXCEPTION 'Station is inactive or not found' USING ERRCODE = 'P0016';
    END IF;

    -- Check if station identity verification mode requires identity proof
    IF v_station.identity_verification_mode IN ('CHECK_IN_ONLY', 'CHECK_IN_AND_CHECK_OUT') THEN
        v_requires_identity := true;
    END IF;

    IF v_requires_identity THEN
        IF p_identity_proof_token IS NULL OR trim(p_identity_proof_token) = '' THEN
            RAISE EXCEPTION 'Identity verification is required for check-in at this station'
                USING ERRCODE = 'P0040';
        END IF;

        v_id_token_hash := encode(digest(trim(p_identity_proof_token), 'sha256'), 'hex');

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

        -- Mark identity proof as used atomically
        UPDATE public.identity_verification_proofs
        SET used_at = v_now
        WHERE id = v_id_proof.id;

        v_id_proof_id := v_id_proof.id;

        IF v_id_proof.is_override THEN
            v_ver_method := 'MANUAL_ADMIN';
        ELSE
            v_ver_method := 'QR_PLUS_IDENTITY';
        END IF;
    ELSE
        -- If identity proof was optionally provided under DISABLED policy, validate if present
        IF p_identity_proof_token IS NOT NULL AND trim(p_identity_proof_token) != '' THEN
            v_id_token_hash := encode(digest(trim(p_identity_proof_token), 'sha256'), 'hex');
            SELECT * INTO v_id_proof
            FROM public.identity_verification_proofs
            WHERE token_hash = v_id_token_hash AND used_at IS NULL AND expires_at > v_now AND employee_user_id = v_user_id AND presence_proof_id = v_proof.id
            FOR UPDATE;

            IF v_id_proof.id IS NOT NULL THEN
                UPDATE public.identity_verification_proofs SET used_at = v_now WHERE id = v_id_proof.id;
                v_id_proof_id := v_id_proof.id;
                v_ver_method := 'QR_PLUS_IDENTITY';
            END IF;
        END IF;
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

    -- Check membership status
    SELECT * INTO v_membership
    FROM public.station_memberships
    WHERE id = v_proof.station_membership_id;

    IF v_membership.id IS NULL OR v_membership.status != 'ACTIVE' THEN
        RAISE EXCEPTION 'Employee membership is not active at this station' USING ERRCODE = 'P0022';
    END IF;

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

    -- Consume presence proof atomically
    UPDATE public.attendance_presence_proofs
    SET used_at = v_now
    WHERE id = v_proof.id;

    -- Insert attendance record with frozen snapshot and optional identity proof reference
    INSERT INTO public.attendance_records (
        station_id, employee_user_id, station_membership_id,
        work_schedule_id, work_schedule_shift_id, shift_assignment_id,
        schedule_version_at_check_in, shift_name_snapshot,
        scheduled_start_at_snapshot, scheduled_end_at_snapshot,
        check_in_time, late_minutes, status, verification_method,
        check_in_kiosk_device_id, identity_verification_proof_id
    ) VALUES (
        v_proof.station_id, v_user_id, v_membership.id,
        v_shift.work_schedule_id, v_shift.shift_id, v_shift.assignment_id,
        v_shift.schedule_version, v_shift.shift_name_snapshot,
        v_shift.starts_at, v_shift.ends_at,
        v_now, v_late_minutes, 'OPEN', v_ver_method,
        v_proof.kiosk_device_id, v_id_proof_id
    ) RETURNING id INTO v_att_id;

    RETURN jsonb_build_object(
        'success', true,
        'attendance_id', v_att_id,
        'station_id', v_proof.station_id,
        'employee_user_id', v_user_id,
        'check_in_time', v_now,
        'status', 'OPEN',
        'late_minutes', v_late_minutes,
        'shift_name', v_shift.shift_name_snapshot,
        'verification_method', v_ver_method
    );
END;
$$;

-- 10.2 Check-Out with Presence Proof & Optional Identity Proof
CREATE OR REPLACE FUNCTION public.check_out_with_presence_proof(
    p_presence_proof_token TEXT,
    p_identity_proof_token TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_token_hash TEXT;
    v_id_token_hash TEXT;
    v_proof RECORD;
    v_id_proof RECORD;
    v_att RECORD;
    v_station RECORD;
    v_kiosk RECORD;
    v_now TIMESTAMPTZ;
    v_worked_minutes INTEGER;
    v_requires_identity BOOLEAN := false;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    v_now := now();
    v_token_hash := encode(digest(p_presence_proof_token, 'sha256'), 'hex');

    -- Lock and validate presence proof
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

    IF v_proof.employee_user_id != v_user_id THEN
        RAISE EXCEPTION 'Presence proof belongs to another employee' USING ERRCODE = 'P0028';
    END IF;

    IF v_proof.action != 'CHECK_OUT' THEN
        RAISE EXCEPTION 'Presence proof is for % action; Expected CHECK_OUT', v_proof.action
            USING ERRCODE = 'P0029';
    END IF;

    -- Validate station policy
    SELECT * INTO v_station FROM public.stations WHERE id = v_proof.station_id;
    IF v_station.id IS NULL OR NOT v_station.is_active THEN
        RAISE EXCEPTION 'Station is inactive or not found' USING ERRCODE = 'P0016';
    END IF;

    -- Check if check-out requires identity verification
    IF v_station.identity_verification_mode = 'CHECK_IN_AND_CHECK_OUT' THEN
        v_requires_identity := true;
    END IF;

    IF v_requires_identity THEN
        IF p_identity_proof_token IS NULL OR trim(p_identity_proof_token) = '' THEN
            RAISE EXCEPTION 'Identity verification is required for check-out at this station'
                USING ERRCODE = 'P0040';
        END IF;

        v_id_token_hash := encode(digest(trim(p_identity_proof_token), 'sha256'), 'hex');

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

        -- Mark identity proof as used
        UPDATE public.identity_verification_proofs
        SET used_at = v_now
        WHERE id = v_id_proof.id;
    END IF;

    -- Validate kiosk device
    SELECT * INTO v_kiosk FROM public.kiosk_devices WHERE id = v_proof.kiosk_device_id;
    IF v_kiosk.id IS NULL OR NOT v_kiosk.is_active THEN
        RAISE EXCEPTION 'Kiosk device is inactive or deactivated' USING ERRCODE = 'P0018';
    END IF;

    -- Find open attendance record
    SELECT * INTO v_att
    FROM public.attendance_records
    WHERE employee_user_id = v_user_id AND check_out_time IS NULL
    FOR UPDATE;

    IF v_att.id IS NULL THEN
        RAISE EXCEPTION 'No open attendance record found for employee' USING ERRCODE = 'P0030';
    END IF;

    -- Invariant: Must check out at the same station where checked in
    IF v_att.station_id != v_proof.station_id THEN
        RAISE EXCEPTION 'Cannot check out at Station % while checked in at Station %', v_proof.station_id, v_att.station_id
            USING ERRCODE = 'P0031';
    END IF;

    -- Compute real UTC elapsed minutes
    v_worked_minutes := floor(extract(epoch from (v_now - v_att.check_in_time)) / 60.0)::INTEGER;
    IF v_worked_minutes < 0 THEN
        v_worked_minutes := 0;
    END IF;

    -- Complete attendance record
    UPDATE public.attendance_records
    SET check_out_time = v_now,
        worked_minutes = v_worked_minutes,
        status = 'COMPLETED',
        check_out_kiosk_device_id = v_proof.kiosk_device_id,
        updated_at = v_now
    WHERE id = v_att.id;

    -- Mark presence proof as consumed
    UPDATE public.attendance_presence_proofs
    SET used_at = v_now
    WHERE id = v_proof.id;

    RETURN jsonb_build_object(
        'success', true,
        'attendance_id', v_att.id,
        'station_id', v_att.station_id,
        'check_in_time', v_att.check_in_time,
        'check_out_time', v_now,
        'worked_minutes', v_worked_minutes,
        'status', 'COMPLETED'
    );
END;
$$;

-- 10.3 1-Argument Backward Compatibility Overloads
CREATE OR REPLACE FUNCTION public.check_in_with_presence_proof(
    p_presence_proof_token TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN public.check_in_with_presence_proof(p_presence_proof_token, NULL::TEXT);
END;
$$;

CREATE OR REPLACE FUNCTION public.check_out_with_presence_proof(
    p_presence_proof_token TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN public.check_out_with_presence_proof(p_presence_proof_token, NULL::TEXT);
END;
$$;

-- ======================================================================
-- 11. GRANT EXECUTION MATRIX HARDENING
-- ======================================================================

REVOKE ALL ON FUNCTION public.start_identity_enrollment(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_identity_enrollment(TEXT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.complete_identity_enrollment(UUID, TEXT, BOOLEAN, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_identity_enrollment(UUID, TEXT, BOOLEAN, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.revoke_identity_profile(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.revoke_identity_profile(UUID, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.update_station_identity_policy(UUID, public.identity_verification_mode) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_station_identity_policy(UUID, public.identity_verification_mode) TO authenticated;

REVOKE ALL ON FUNCTION public.start_identity_verification(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_identity_verification(TEXT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.complete_identity_verification(UUID, BOOLEAN, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_identity_verification(UUID, BOOLEAN, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.create_identity_admin_override(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_identity_admin_override(TEXT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.get_my_identity_profile() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_identity_profile() TO authenticated;

REVOKE ALL ON FUNCTION public.get_station_team_identity_status(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_station_team_identity_status(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.cleanup_ephemeral_identity_data() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cleanup_ephemeral_identity_data() TO authenticated;

REVOKE ALL ON FUNCTION public.check_in_with_presence_proof(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_in_with_presence_proof(TEXT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.check_out_with_presence_proof(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_out_with_presence_proof(TEXT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.check_in_with_presence_proof(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_in_with_presence_proof(TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.check_out_with_presence_proof(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_out_with_presence_proof(TEXT) TO authenticated;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        GRANT EXECUTE ON FUNCTION public.start_identity_enrollment(TEXT, TEXT) TO service_role;
        GRANT EXECUTE ON FUNCTION public.complete_identity_enrollment(UUID, TEXT, BOOLEAN, TEXT) TO service_role;
        GRANT EXECUTE ON FUNCTION public.revoke_identity_profile(UUID, TEXT) TO service_role;
        GRANT EXECUTE ON FUNCTION public.update_station_identity_policy(UUID, public.identity_verification_mode) TO service_role;
        GRANT EXECUTE ON FUNCTION public.start_identity_verification(TEXT, TEXT) TO service_role;
        GRANT EXECUTE ON FUNCTION public.complete_identity_verification(UUID, BOOLEAN, TEXT) TO service_role;
        GRANT EXECUTE ON FUNCTION public.create_identity_admin_override(TEXT, TEXT) TO service_role;
        GRANT EXECUTE ON FUNCTION public.get_my_identity_profile() TO service_role;
        GRANT EXECUTE ON FUNCTION public.get_station_team_identity_status(UUID) TO service_role;
        GRANT EXECUTE ON FUNCTION public.cleanup_ephemeral_identity_data() TO service_role;
        GRANT EXECUTE ON FUNCTION public.check_in_with_presence_proof(TEXT, TEXT) TO service_role;
        GRANT EXECUTE ON FUNCTION public.check_out_with_presence_proof(TEXT, TEXT) TO service_role;
        GRANT EXECUTE ON FUNCTION public.check_in_with_presence_proof(TEXT) TO service_role;
        GRANT EXECUTE ON FUNCTION public.check_out_with_presence_proof(TEXT) TO service_role;
    END IF;
END $$;
