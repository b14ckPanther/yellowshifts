-- YellowShifts Phase 2 Migration
-- Shift Templates, Station Operational Configuration, Shift Manager Permissions & Weekly Availability

-- 1. Enums
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'availability_period_status') THEN
        CREATE TYPE public.availability_period_status AS ENUM ('DRAFT', 'OPEN', 'CLOSED');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'availability_submission_status') THEN
        CREATE TYPE public.availability_submission_status AS ENUM ('DRAFT', 'SUBMITTED');
    END IF;
END $$;

-- 2. Shift Templates Table
CREATE TABLE IF NOT EXISTS public.shift_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    code TEXT,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT chk_shift_template_non_zero_duration CHECK (start_time <> end_time)
);

CREATE INDEX IF NOT EXISTS idx_shift_templates_station_active 
ON public.shift_templates(station_id, is_active, sort_order);

CREATE UNIQUE INDEX IF NOT EXISTS uq_shift_templates_station_code 
ON public.shift_templates(station_id, UPPER(code)) 
WHERE code IS NOT NULL AND code <> '';

-- 3. Shift Manager Permissions Table (Station-scoped capability overrides)
CREATE TABLE IF NOT EXISTS public.station_shift_manager_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    permission TEXT NOT NULL,
    is_enabled BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_station_permission UNIQUE (station_id, permission)
);

CREATE INDEX IF NOT EXISTS idx_station_permissions_station 
ON public.station_shift_manager_permissions(station_id);

-- 4. Weekly Availability Periods Table
CREATE TABLE IF NOT EXISTS public.availability_periods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE RESTRICT,
    week_start_date DATE NOT NULL,
    status public.availability_period_status NOT NULL DEFAULT 'DRAFT',
    submission_deadline TIMESTAMPTZ NOT NULL,
    notes TEXT,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    opened_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_availability_periods_station_week UNIQUE (station_id, week_start_date)
);

CREATE INDEX IF NOT EXISTS idx_availability_periods_station_status 
ON public.availability_periods(station_id, status);

-- 5. Period Shift Templates Snapshot Table (Immutable frozen definition)
CREATE TABLE IF NOT EXISTS public.availability_period_shift_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    availability_period_id UUID NOT NULL REFERENCES public.availability_periods(id) ON DELETE CASCADE,
    shift_template_id UUID NOT NULL REFERENCES public.shift_templates(id) ON DELETE RESTRICT,
    name_snapshot TEXT NOT NULL,
    code_snapshot TEXT,
    start_time_snapshot TIME NOT NULL,
    end_time_snapshot TIME NOT NULL,
    sort_order_snapshot INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_period_template UNIQUE (availability_period_id, shift_template_id)
);

CREATE INDEX IF NOT EXISTS idx_period_templates_period 
ON public.availability_period_shift_templates(availability_period_id, sort_order_snapshot);

-- 6. Period Eligible Members Snapshot Table
CREATE TABLE IF NOT EXISTS public.availability_period_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    availability_period_id UUID NOT NULL REFERENCES public.availability_periods(id) ON DELETE CASCADE,
    membership_id UUID NOT NULL REFERENCES public.station_memberships(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    role_snapshot public.station_role NOT NULL,
    is_eligible BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_period_member UNIQUE (availability_period_id, membership_id)
);

CREATE INDEX IF NOT EXISTS idx_period_members_period 
ON public.availability_period_members(availability_period_id);

-- 7. Availability Submissions Table
CREATE TABLE IF NOT EXISTS public.availability_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    availability_period_id UUID NOT NULL REFERENCES public.availability_periods(id) ON DELETE CASCADE,
    membership_id UUID NOT NULL REFERENCES public.station_memberships(id) ON DELETE RESTRICT,
    status public.availability_submission_status NOT NULL DEFAULT 'DRAFT',
    submitted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_period_submission_membership UNIQUE (availability_period_id, membership_id)
);

CREATE INDEX IF NOT EXISTS idx_submissions_period_status 
ON public.availability_submissions(availability_period_id, status);

-- 8. Availability Slot Entries Table
CREATE TABLE IF NOT EXISTS public.availability_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    submission_id UUID NOT NULL REFERENCES public.availability_submissions(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    period_shift_template_id UUID NOT NULL REFERENCES public.availability_period_shift_templates(id) ON DELETE RESTRICT,
    is_available BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_submission_slot UNIQUE (submission_id, date, period_shift_template_id)
);

CREATE INDEX IF NOT EXISTS idx_entries_submission 
ON public.availability_entries(submission_id);

-- 9. Automatic Updated At Triggers
DROP TRIGGER IF EXISTS tr_shift_templates_updated_at ON public.shift_templates;
CREATE TRIGGER tr_shift_templates_updated_at
    BEFORE UPDATE ON public.shift_templates
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS tr_station_permissions_updated_at ON public.station_shift_manager_permissions;
CREATE TRIGGER tr_station_permissions_updated_at
    BEFORE UPDATE ON public.station_shift_manager_permissions
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS tr_availability_periods_updated_at ON public.availability_periods;
CREATE TRIGGER tr_availability_periods_updated_at
    BEFORE UPDATE ON public.availability_periods
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS tr_availability_submissions_updated_at ON public.availability_submissions;
CREATE TRIGGER tr_availability_submissions_updated_at
    BEFORE UPDATE ON public.availability_submissions
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS tr_availability_entries_updated_at ON public.availability_entries;
CREATE TRIGGER tr_availability_entries_updated_at
    BEFORE UPDATE ON public.availability_entries
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- 10. Server-Authoritative Station Permission Resolution Helper
CREATE OR REPLACE FUNCTION public.has_station_permission(
    p_station_id UUID,
    p_user_id UUID,
    p_permission TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_role public.station_role;
    v_status public.membership_status;
    v_enabled BOOLEAN;
BEGIN
    IF p_user_id IS NULL OR p_station_id IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT role, status INTO v_role, v_status
    FROM public.station_memberships
    WHERE station_id = p_station_id AND user_id = p_user_id;

    IF NOT FOUND OR v_status <> 'ACTIVE' THEN
        RETURN FALSE;
    END IF;

    -- Station Administrators have full operational authority
    IF v_role = 'ADMIN' THEN
        RETURN TRUE;
    END IF;

    -- Shift Manager permission resolution
    IF v_role = 'SHIFT_MANAGER' THEN
        -- Check explicit station permission override
        SELECT is_enabled INTO v_enabled
        FROM public.station_shift_manager_permissions
        WHERE station_id = p_station_id AND permission = p_permission;

        IF FOUND THEN
            RETURN v_enabled;
        END IF;

        -- Sensible defaults for Shift Managers when no override row exists
        IF p_permission IN ('shift_templates.read', 'availability.period.read', 'availability.team.read') THEN
            RETURN TRUE;
        END IF;

        RETURN FALSE;
    END IF;

    -- Employees have self-service rights only (handled per endpoint/RLS)
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public, pg_temp;

-- 11. Row Level Security Policies

-- A. Shift Templates RLS
ALTER TABLE public.shift_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS shift_templates_select_members ON public.shift_templates;
CREATE POLICY shift_templates_select_members ON public.shift_templates
    FOR SELECT TO authenticated
    USING (public.is_station_member(station_id, (SELECT auth.uid())));

DROP POLICY IF EXISTS shift_templates_insert_admins ON public.shift_templates;
CREATE POLICY shift_templates_insert_admins ON public.shift_templates
    FOR INSERT TO authenticated
    WITH CHECK (public.has_station_permission(station_id, (SELECT auth.uid()), 'shift_templates.manage'));

DROP POLICY IF EXISTS shift_templates_update_admins ON public.shift_templates;
CREATE POLICY shift_templates_update_admins ON public.shift_templates
    FOR UPDATE TO authenticated
    USING (public.has_station_permission(station_id, (SELECT auth.uid()), 'shift_templates.manage'))
    WITH CHECK (public.has_station_permission(station_id, (SELECT auth.uid()), 'shift_templates.manage'));

-- B. Station Shift Manager Permissions RLS
ALTER TABLE public.station_shift_manager_permissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS station_permissions_select_members ON public.station_shift_manager_permissions;
CREATE POLICY station_permissions_select_members ON public.station_shift_manager_permissions
    FOR SELECT TO authenticated
    USING (public.is_station_member(station_id, (SELECT auth.uid())));

DROP POLICY IF EXISTS station_permissions_update_admins ON public.station_shift_manager_permissions;
CREATE POLICY station_permissions_update_admins ON public.station_shift_manager_permissions
    FOR ALL TO authenticated
    USING (public.is_station_admin(station_id, (SELECT auth.uid())))
    WITH CHECK (public.is_station_admin(station_id, (SELECT auth.uid())));

-- C. Availability Periods RLS
ALTER TABLE public.availability_periods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS availability_periods_select_members ON public.availability_periods;
CREATE POLICY availability_periods_select_members ON public.availability_periods
    FOR SELECT TO authenticated
    USING (public.is_station_member(station_id, (SELECT auth.uid())));

-- D. Period Snapshots RLS
ALTER TABLE public.availability_period_shift_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS period_templates_select_members ON public.availability_period_shift_templates;
CREATE POLICY period_templates_select_members ON public.availability_period_shift_templates
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.availability_periods ap
            WHERE ap.id = availability_period_shift_templates.availability_period_id
              AND public.is_station_member(ap.station_id, (SELECT auth.uid()))
        )
    );

ALTER TABLE public.availability_period_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS period_members_select ON public.availability_period_members;
CREATE POLICY period_members_select ON public.availability_period_members
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.availability_periods ap
            WHERE ap.id = availability_period_members.availability_period_id
              AND (
                  public.has_station_permission(ap.station_id, (SELECT auth.uid()), 'availability.team.read') OR
                  availability_period_members.user_id = (SELECT auth.uid())
              )
        )
    );

-- E. Submissions & Entries RLS
ALTER TABLE public.availability_submissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS availability_submissions_select ON public.availability_submissions;
CREATE POLICY availability_submissions_select ON public.availability_submissions
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.availability_periods ap
            WHERE ap.id = availability_submissions.availability_period_id
              AND (
                  public.has_station_permission(ap.station_id, (SELECT auth.uid()), 'availability.team.read') OR
                  EXISTS (
                      SELECT 1 FROM public.station_memberships sm
                      WHERE sm.id = availability_submissions.membership_id
                        AND sm.user_id = (SELECT auth.uid())
                  )
              )
        )
    );

ALTER TABLE public.availability_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS availability_entries_select ON public.availability_entries;
CREATE POLICY availability_entries_select ON public.availability_entries
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.availability_submissions sub
            JOIN public.availability_periods ap ON ap.id = sub.availability_period_id
            WHERE sub.id = availability_entries.submission_id
              AND (
                  public.has_station_permission(ap.station_id, (SELECT auth.uid()), 'availability.team.read') OR
                  EXISTS (
                      SELECT 1 FROM public.station_memberships sm
                      WHERE sm.id = sub.membership_id
                        AND sm.user_id = (SELECT auth.uid())
                  )
              )
        )
    );

-- 12. Transactional Server-Side RPC Functions

-- RPC: Manage Shift Template (Create, Update, Deactivate, Reactivate)
CREATE OR REPLACE FUNCTION public.admin_manage_shift_template(
    p_station_id UUID,
    p_template_id UUID DEFAULT NULL,
    p_name TEXT DEFAULT NULL,
    p_code TEXT DEFAULT NULL,
    p_start_time TIME DEFAULT NULL,
    p_end_time TIME DEFAULT NULL,
    p_sort_order INTEGER DEFAULT 0,
    p_is_active BOOLEAN DEFAULT true,
    p_action TEXT DEFAULT 'UPSERT'
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_clean_name TEXT;
    v_clean_code TEXT;
    v_result_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF NOT public.has_station_permission(p_station_id, v_caller_id, 'shift_templates.manage') THEN
        RAISE EXCEPTION 'Access denied: caller does not have shift_templates.manage permission'
            USING ERRCODE = '42501';
    END IF;

    IF p_action = 'DEACTIVATE' THEN
        UPDATE public.shift_templates
        SET is_active = false, updated_at = timezone('utc'::text, now())
        WHERE id = p_template_id AND station_id = p_station_id;

        INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id)
        VALUES (p_station_id, v_caller_id, 'SHIFT_TEMPLATE_DEACTIVATED', 'shift_template', p_template_id::text);

        RETURN jsonb_build_object('success', true, 'template_id', p_template_id, 'is_active', false);
    END IF;

    IF p_action = 'REACTIVATE' THEN
        UPDATE public.shift_templates
        SET is_active = true, updated_at = timezone('utc'::text, now())
        WHERE id = p_template_id AND station_id = p_station_id;

        INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id)
        VALUES (p_station_id, v_caller_id, 'SHIFT_TEMPLATE_REACTIVATED', 'shift_template', p_template_id::text);

        RETURN jsonb_build_object('success', true, 'template_id', p_template_id, 'is_active', true);
    END IF;

    -- Validate input for UPSERT
    v_clean_name := TRIM(COALESCE(p_name, ''));
    IF LENGTH(v_clean_name) < 1 THEN
        RAISE EXCEPTION 'Shift template name cannot be empty' USING ERRCODE = '22000';
    END IF;

    IF p_start_time IS NULL OR p_end_time IS NULL THEN
        RAISE EXCEPTION 'Start and end times are required' USING ERRCODE = '22000';
    END IF;

    IF p_start_time = p_end_time THEN
        RAISE EXCEPTION 'Shift duration cannot be zero hours' USING ERRCODE = '22000';
    END IF;

    v_clean_code := NULLIF(UPPER(TRIM(COALESCE(p_code, ''))), '');

    IF p_template_id IS NULL THEN
        INSERT INTO public.shift_templates (
            station_id, name, code, start_time, end_time, sort_order, is_active
        ) VALUES (
            p_station_id, v_clean_name, v_clean_code, p_start_time, p_end_time, p_sort_order, p_is_active
        ) RETURNING id INTO v_result_id;

        INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
        VALUES (
            p_station_id, v_caller_id, 'SHIFT_TEMPLATE_CREATED', 'shift_template', v_result_id::text,
            jsonb_build_object('name', v_clean_name, 'start_time', p_start_time, 'end_time', p_end_time)
        );
    ELSE
        UPDATE public.shift_templates
        SET name = v_clean_name,
            code = v_clean_code,
            start_time = p_start_time,
            end_time = p_end_time,
            sort_order = p_sort_order,
            is_active = p_is_active,
            updated_at = timezone('utc'::text, now())
        WHERE id = p_template_id AND station_id = p_station_id
        RETURNING id INTO v_result_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Shift template not found' USING ERRCODE = 'P0002';
        END IF;

        INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
        VALUES (
            p_station_id, v_caller_id, 'SHIFT_TEMPLATE_UPDATED', 'shift_template', v_result_id::text,
            jsonb_build_object('name', v_clean_name, 'start_time', p_start_time, 'end_time', p_end_time)
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'template_id', v_result_id,
        'name', v_clean_name,
        'start_time', p_start_time,
        'end_time', p_end_time
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- RPC: Reorder Shift Templates
CREATE OR REPLACE FUNCTION public.admin_reorder_shift_templates(
    p_station_id UUID,
    p_template_ids UUID[]
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_idx INTEGER;
BEGIN
    v_caller_id := auth.uid();
    IF NOT public.has_station_permission(p_station_id, v_caller_id, 'shift_templates.manage') THEN
        RAISE EXCEPTION 'Access denied: caller does not have shift_templates.manage permission'
            USING ERRCODE = '42501';
    END IF;

    FOR v_idx IN 1..array_length(p_template_ids, 1) LOOP
        UPDATE public.shift_templates
        SET sort_order = v_idx - 1, updated_at = timezone('utc'::text, now())
        WHERE id = p_template_ids[v_idx] AND station_id = p_station_id;
    END LOOP;

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        p_station_id, v_caller_id, 'SHIFT_TEMPLATE_REORDERED', 'station', p_station_id::text,
        jsonb_build_object('ordered_ids', p_template_ids)
    );

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- RPC: Admin Sets Shift Manager Permissions
CREATE OR REPLACE FUNCTION public.admin_set_shift_manager_permissions(
    p_station_id UUID,
    p_permissions JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_perm TEXT;
    v_enabled BOOLEAN;
BEGIN
    v_caller_id := auth.uid();
    IF NOT public.is_station_admin(p_station_id, v_caller_id) THEN
        RAISE EXCEPTION 'Access denied: only station administrators can configure Shift Manager permissions'
            USING ERRCODE = '42501';
    END IF;

    FOR v_perm, v_enabled IN SELECT * FROM jsonb_each_text(p_permissions) LOOP
        INSERT INTO public.station_shift_manager_permissions (station_id, permission, is_enabled, updated_at)
        VALUES (p_station_id, v_perm, v_enabled::boolean, timezone('utc'::text, now()))
        ON CONFLICT (station_id, permission)
        DO UPDATE SET is_enabled = EXCLUDED.is_enabled, updated_at = timezone('utc'::text, now());
    END LOOP;

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        p_station_id, v_caller_id, 'SHIFT_MANAGER_PERMISSIONS_UPDATED', 'station', p_station_id::text,
        jsonb_build_object('permissions', p_permissions)
    );

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- RPC: Get Shift Manager Permissions for Station
CREATE OR REPLACE FUNCTION public.get_shift_manager_permissions(p_station_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_perms JSONB;
BEGIN
    v_caller_id := auth.uid();
    IF NOT public.is_station_member(p_station_id, v_caller_id) THEN
        RAISE EXCEPTION 'Access denied: caller is not a member of this station'
            USING ERRCODE = '42501';
    END IF;

    SELECT COALESCE(
        jsonb_object_agg(permission, is_enabled),
        '{}'::jsonb
    )
    INTO v_perms
    FROM public.station_shift_manager_permissions
    WHERE station_id = p_station_id;

    RETURN v_perms;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public, pg_temp;

-- RPC: Create Weekly Availability Period (DRAFT)
CREATE OR REPLACE FUNCTION public.create_availability_period(
    p_station_id UUID,
    p_week_start_date DATE,
    p_submission_deadline TIMESTAMPTZ,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_period_id UUID;
    v_station_week_start INTEGER;
BEGIN
    v_caller_id := auth.uid();
    IF NOT public.has_station_permission(p_station_id, v_caller_id, 'availability.period.create') THEN
        RAISE EXCEPTION 'Access denied: caller does not have availability.period.create permission'
            USING ERRCODE = '42501';
    END IF;

    -- Validate station week start configuration (0 = Sunday, 1 = Monday, etc.)
    SELECT week_start INTO v_station_week_start
    FROM public.stations
    WHERE id = p_station_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Station not found' USING ERRCODE = 'P0002';
    END IF;

    IF EXTRACT(DOW FROM p_week_start_date)::integer <> v_station_week_start THEN
        RAISE EXCEPTION 'Week start date (%) must align with station week_start configuration (expected %)',
            p_week_start_date, v_station_week_start USING ERRCODE = '22000';
    END IF;

    IF p_submission_deadline <= timezone('utc'::text, now()) THEN
        RAISE EXCEPTION 'Submission deadline must be in the future' USING ERRCODE = '22000';
    END IF;

    INSERT INTO public.availability_periods (
        station_id, week_start_date, status, submission_deadline, notes, created_by
    ) VALUES (
        p_station_id, p_week_start_date, 'DRAFT', p_submission_deadline, p_notes, v_caller_id
    ) RETURNING id INTO v_period_id;

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        p_station_id, v_caller_id, 'AVAILABILITY_PERIOD_CREATED', 'availability_period', v_period_id::text,
        jsonb_build_object('week_start_date', p_week_start_date, 'deadline', p_submission_deadline)
    );

    RETURN jsonb_build_object(
        'success', true,
        'period_id', v_period_id,
        'status', 'DRAFT'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- RPC: Open Availability Period (Atomic Snapshot & Status Transition)
CREATE OR REPLACE FUNCTION public.open_availability_period(p_period_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_station_id UUID;
    v_current_status public.availability_period_status;
    v_deadline TIMESTAMPTZ;
    v_template_count INTEGER;
    v_member_count INTEGER;
BEGIN
    v_caller_id := auth.uid();

    -- Concurrency Lock: Lock period row immediately on read
    SELECT station_id, status, submission_deadline 
    INTO v_station_id, v_current_status, v_deadline
    FROM public.availability_periods
    WHERE id = p_period_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Availability period not found' USING ERRCODE = 'P0002';
    END IF;

    IF NOT public.has_station_permission(v_station_id, v_caller_id, 'availability.period.open') THEN
        RAISE EXCEPTION 'Access denied: caller does not have availability.period.open permission'
            USING ERRCODE = '42501';
    END IF;

    IF v_current_status <> 'DRAFT' THEN
        RAISE EXCEPTION 'Only DRAFT periods can be opened' USING ERRCODE = '22000';
    END IF;

    IF v_deadline <= timezone('utc'::text, now()) THEN
        RAISE EXCEPTION 'Cannot open period with expired submission deadline' USING ERRCODE = '22000';
    END IF;

    -- Validate at least 1 active shift template exists in station
    SELECT COUNT(*) INTO v_template_count
    FROM public.shift_templates
    WHERE station_id = v_station_id AND is_active = true;

    IF v_template_count = 0 THEN
        RAISE EXCEPTION 'Cannot open availability period with zero active shift templates'
            USING ERRCODE = 'P0003';
    END IF;

    -- 1. Create Immutable Shift Template Snapshot
    INSERT INTO public.availability_period_shift_templates (
        availability_period_id, shift_template_id, name_snapshot, code_snapshot,
        start_time_snapshot, end_time_snapshot, sort_order_snapshot
    )
    SELECT 
        p_period_id, id, name, code, start_time, end_time, sort_order
    FROM public.shift_templates
    WHERE station_id = v_station_id AND is_active = true
    ORDER BY sort_order ASC, name ASC
    ON CONFLICT (availability_period_id, shift_template_id) DO NOTHING;

    -- 2. Create Eligible Members Snapshot
    INSERT INTO public.availability_period_members (
        availability_period_id, membership_id, user_id, role_snapshot, is_eligible
    )
    SELECT 
        p_period_id, sm.id, sm.user_id, sm.role, true
    FROM public.station_memberships sm
    WHERE sm.station_id = v_station_id AND sm.status = 'ACTIVE'
    ON CONFLICT (availability_period_id, membership_id) DO NOTHING;

    GET DIAGNOSTICS v_member_count = ROW_COUNT;

    -- 3. Set Status = OPEN
    UPDATE public.availability_periods
    SET status = 'OPEN',
        opened_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_period_id;

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        v_station_id, v_caller_id, 'AVAILABILITY_PERIOD_OPENED', 'availability_period', p_period_id::text,
        jsonb_build_object('templates_snapshotted', v_template_count, 'eligible_members', v_member_count)
    );

    RETURN jsonb_build_object(
        'success', true,
        'period_id', p_period_id,
        'status', 'OPEN',
        'templates_count', v_template_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- RPC: Close Availability Period
CREATE OR REPLACE FUNCTION public.close_availability_period(p_period_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_station_id UUID;
    v_current_status public.availability_period_status;
BEGIN
    v_caller_id := auth.uid();

    SELECT station_id, status INTO v_station_id, v_current_status
    FROM public.availability_periods
    WHERE id = p_period_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Availability period not found' USING ERRCODE = 'P0002';
    END IF;

    IF NOT public.has_station_permission(v_station_id, v_caller_id, 'availability.period.close') THEN
        RAISE EXCEPTION 'Access denied: caller does not have availability.period.close permission'
            USING ERRCODE = '42501';
    END IF;

    IF v_current_status <> 'OPEN' THEN
        RAISE EXCEPTION 'Only OPEN periods can be closed' USING ERRCODE = '22000';
    END IF;

    UPDATE public.availability_periods
    SET status = 'CLOSED',
        closed_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_period_id;

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id)
    VALUES (v_station_id, v_caller_id, 'AVAILABILITY_PERIOD_CLOSED', 'availability_period', p_period_id::text);

    RETURN jsonb_build_object('success', true, 'period_id', p_period_id, 'status', 'CLOSED');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- RPC: Reopen Availability Period
CREATE OR REPLACE FUNCTION public.reopen_availability_period(
    p_period_id UUID,
    p_new_deadline TIMESTAMPTZ
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_station_id UUID;
    v_current_status public.availability_period_status;
BEGIN
    v_caller_id := auth.uid();

    SELECT station_id, status INTO v_station_id, v_current_status
    FROM public.availability_periods
    WHERE id = p_period_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Availability period not found' USING ERRCODE = 'P0002';
    END IF;

    IF NOT public.has_station_permission(v_station_id, v_caller_id, 'availability.period.open') THEN
        RAISE EXCEPTION 'Access denied: caller does not have availability.period.open permission'
            USING ERRCODE = '42501';
    END IF;

    IF p_new_deadline <= timezone('utc'::text, now()) THEN
        RAISE EXCEPTION 'New submission deadline must be in the future' USING ERRCODE = '22000';
    END IF;

    UPDATE public.availability_periods
    SET status = 'OPEN',
        submission_deadline = p_new_deadline,
        closed_at = NULL,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_period_id;

    -- Sync any newly joined active members during reopen
    INSERT INTO public.availability_period_members (
        availability_period_id, membership_id, user_id, role_snapshot, is_eligible
    )
    SELECT 
        p_period_id, sm.id, sm.user_id, sm.role, true
    FROM public.station_memberships sm
    WHERE sm.station_id = v_station_id AND sm.status = 'ACTIVE'
    ON CONFLICT (availability_period_id, membership_id) DO NOTHING;

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        v_station_id, v_caller_id, 'AVAILABILITY_PERIOD_REOPENED', 'availability_period', p_period_id::text,
        jsonb_build_object('new_deadline', p_new_deadline)
    );

    RETURN jsonb_build_object('success', true, 'period_id', p_period_id, 'status', 'OPEN');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- RPC: Save Availability Draft (Debounced Partial Slot Upsert)
CREATE OR REPLACE FUNCTION public.save_availability_draft(
    p_period_id UUID,
    p_entries JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_station_id UUID;
    v_period_status public.availability_period_status;
    v_deadline TIMESTAMPTZ;
    v_membership_id UUID;
    v_submission_id UUID;
    v_entry JSONB;
    v_date DATE;
    v_template_id UUID;
    v_is_available BOOLEAN;
BEGIN
    v_caller_id := auth.uid();

    SELECT station_id, status, submission_deadline 
    INTO v_station_id, v_period_status, v_deadline
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

    -- Upsert Submission record in DRAFT status
    INSERT INTO public.availability_submissions (
        availability_period_id, membership_id, status, submitted_at, updated_at
    ) VALUES (
        p_period_id, v_membership_id, 'DRAFT', NULL, timezone('utc'::text, now())
    )
    ON CONFLICT (availability_period_id, membership_id)
    DO UPDATE SET 
        status = 'DRAFT',
        submitted_at = NULL,
        updated_at = timezone('utc'::text, now())
    RETURNING id INTO v_submission_id;

    -- Upsert entries
    FOR v_entry IN SELECT * FROM jsonb_array_elements(p_entries) LOOP
        v_date := (v_entry->>'date')::date;
        v_template_id := (v_entry->>'period_shift_template_id')::uuid;
        v_is_available := (v_entry->>'is_available')::boolean;

        -- Verify template belongs to this period
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

    RETURN jsonb_build_object(
        'success', true,
        'submission_id', v_submission_id,
        'status', 'DRAFT'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- RPC: Final Submit Availability (Atomic Completeness & Deadline Validation)
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

    -- Dynamic completeness calculation: Count snapshot templates * 7 operational days
    SELECT COUNT(*) INTO v_template_count
    FROM public.availability_period_shift_templates
    WHERE availability_period_id = p_period_id;

    v_required_slots := v_template_count * 7;

    -- Create or fetch submission record
    INSERT INTO public.availability_submissions (
        availability_period_id, membership_id, status, submitted_at, updated_at
    ) VALUES (
        p_period_id, v_membership_id, 'DRAFT', NULL, timezone('utc'::text, now())
    )
    ON CONFLICT (availability_period_id, membership_id)
    DO UPDATE SET updated_at = timezone('utc'::text, now())
    RETURNING id INTO v_submission_id;

    -- Upsert all passed entries
    FOR v_entry IN SELECT * FROM jsonb_array_elements(p_entries) LOOP
        v_date := (v_entry->>'date')::date;
        v_template_id := (v_entry->>'period_shift_template_id')::uuid;
        v_is_available := (v_entry->>'is_available')::boolean;

        -- Validate date falls within 7 days of week_start_date
        IF v_date < v_week_start OR v_date > (v_week_start + INTERVAL '6 days')::date THEN
            RAISE EXCEPTION 'Entry date is outside the period operational week' USING ERRCODE = '22000';
        END IF;

        -- Validate template belongs to period
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

    -- Verify all required slots have entries
    SELECT COUNT(*) INTO v_submitted_count
    FROM public.availability_entries
    WHERE submission_id = v_submission_id;

    IF v_submitted_count < v_required_slots THEN
        RAISE EXCEPTION 'Cannot submit incomplete availability: % of % slots answered', v_submitted_count, v_required_slots
            USING ERRCODE = 'P0004';
    END IF;

    -- Set status to SUBMITTED
    UPDATE public.availability_submissions
    SET status = 'SUBMITTED',
        submitted_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    WHERE id = v_submission_id;

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        v_station_id, v_caller_id, 'AVAILABILITY_SUBMITTED', 'availability_submission', v_submission_id::text,
        jsonb_build_object('period_id', p_period_id, 'slots_answered', v_submitted_count)
    );

    RETURN jsonb_build_object(
        'success', true,
        'submission_id', v_submission_id,
        'status', 'SUBMITTED',
        'submitted_at', timezone('utc'::text, now())
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- RPC: Get Availability Matrix for Management Review with Verified Invariants
CREATE OR REPLACE FUNCTION public.get_availability_matrix(
    p_period_id UUID,
    p_search TEXT DEFAULT NULL,
    p_status_filter TEXT DEFAULT NULL,
    p_role_filter TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_station_id UUID;
    v_eligible_count INTEGER;
    v_submitted_count INTEGER;
    v_draft_count INTEGER;
    v_not_started_count INTEGER;
    v_not_submitted_count INTEGER;
    v_templates JSONB;
    v_members JSONB;
    v_clean_search TEXT;
BEGIN
    v_caller_id := auth.uid();

    SELECT station_id INTO v_station_id
    FROM public.availability_periods
    WHERE id = p_period_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Availability period not found' USING ERRCODE = 'P0002';
    END IF;

    IF NOT public.has_station_permission(v_station_id, v_caller_id, 'availability.team.read') THEN
        RAISE EXCEPTION 'Access denied: caller does not have availability.team.read permission'
            USING ERRCODE = '42501';
    END IF;

    -- Fetch period templates snapshot
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', id,
            'name', name_snapshot,
            'code', code_snapshot,
            'start_time', start_time_snapshot,
            'end_time', end_time_snapshot,
            'sort_order', sort_order_snapshot
        ) ORDER BY sort_order_snapshot ASC
    ) INTO v_templates
    FROM public.availability_period_shift_templates
    WHERE availability_period_id = p_period_id;

    -- Calculate KPI Counts (Enforcing mathematical invariants)
    SELECT COUNT(*) INTO v_eligible_count
    FROM public.availability_period_members
    WHERE availability_period_id = p_period_id AND is_eligible = true;

    SELECT COUNT(*) INTO v_submitted_count
    FROM public.availability_period_members apm
    JOIN public.availability_submissions s 
      ON s.availability_period_id = apm.availability_period_id 
     AND s.membership_id = apm.membership_id
    WHERE apm.availability_period_id = p_period_id 
      AND apm.is_eligible = true
      AND s.status = 'SUBMITTED';

    SELECT COUNT(*) INTO v_draft_count
    FROM public.availability_period_members apm
    JOIN public.availability_submissions s 
      ON s.availability_period_id = apm.availability_period_id 
     AND s.membership_id = apm.membership_id
    WHERE apm.availability_period_id = p_period_id 
      AND apm.is_eligible = true
      AND s.status = 'DRAFT';

    v_not_started_count := v_eligible_count - (v_submitted_count + v_draft_count);
    v_not_submitted_count := v_draft_count + v_not_started_count;

    -- Sanitize search input
    IF p_search IS NOT NULL AND TRIM(p_search) <> '' THEN
        v_clean_search := SUBSTRING(TRIM(p_search), 1, 100);
        v_clean_search := regexp_replace(v_clean_search, '([%_\\])', '\\\1', 'g');
    ELSE
        v_clean_search := NULL;
    END IF;

    -- Build member matrix rows
    SELECT jsonb_agg(
        jsonb_build_object(
            'membership_id', apm.membership_id,
            'user_id', apm.user_id,
            'first_name', p.first_name,
            'last_name', p.last_name,
            'phone', p.phone,
            'role', apm.role_snapshot,
            'employee_code', sm.employee_code,
            'submission_status', COALESCE(s.status::text, 'NOT_STARTED'),
            'submitted_at', s.submitted_at,
            'entries', COALESCE(
                (
                    SELECT jsonb_object_agg(
                        e.date::text || '_' || e.period_shift_template_id::text,
                        e.is_available
                    )
                    FROM public.availability_entries e
                    WHERE e.submission_id = s.id
                ),
                '{}'::jsonb
            )
        )
        ORDER BY 
            CASE COALESCE(s.status::text, 'NOT_STARTED') 
                WHEN 'NOT_STARTED' THEN 0 
                WHEN 'DRAFT' THEN 1 
                ELSE 2 
            END,
            p.last_name ASC,
            p.first_name ASC
    ) INTO v_members
    FROM public.availability_period_members apm
    JOIN public.profiles p ON p.id = apm.user_id
    JOIN public.station_memberships sm ON sm.id = apm.membership_id
    LEFT JOIN public.availability_submissions s 
      ON s.availability_period_id = apm.availability_period_id 
     AND s.membership_id = apm.membership_id
    WHERE apm.availability_period_id = p_period_id
      AND apm.is_eligible = true
      AND (p_role_filter IS NULL OR apm.role_snapshot::text = p_role_filter)
      AND (
          p_status_filter IS NULL OR 
          COALESCE(s.status::text, 'NOT_STARTED') = p_status_filter
      )
      AND (
          v_clean_search IS NULL OR
          p.first_name ILIKE '%' || v_clean_search || '%' OR
          p.last_name ILIKE '%' || v_clean_search || '%' OR
          sm.employee_code ILIKE '%' || v_clean_search || '%'
      );

    RETURN jsonb_build_object(
        'period_id', p_period_id,
        'station_id', v_station_id,
        'metrics', jsonb_build_object(
            'eligible_employees', v_eligible_count,
            'submitted_employees', v_submitted_count,
            'draft_employees', v_draft_count,
            'not_started_employees', v_not_started_count,
            'not_submitted_employees', v_not_submitted_count
        ),
        'templates', COALESCE(v_templates, '[]'::jsonb),
        'members', COALESCE(v_members, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- RPC: Get My Availability Submission for Period
CREATE OR REPLACE FUNCTION public.get_my_availability_submission(p_period_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_station_id UUID;
    v_period RECORD;
    v_membership_id UUID;
    v_submission RECORD;
    v_templates JSONB;
    v_entries JSONB;
BEGIN
    v_caller_id := auth.uid();

    SELECT id, station_id, week_start_date, status, submission_deadline, notes
    INTO v_period
    FROM public.availability_periods
    WHERE id = p_period_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Availability period not found' USING ERRCODE = 'P0002';
    END IF;

    SELECT id INTO v_membership_id
    FROM public.station_memberships
    WHERE station_id = v_period.station_id AND user_id = v_caller_id AND status = 'ACTIVE';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Caller is not an active member of this station' USING ERRCODE = '42501';
    END IF;

    -- Templates snapshot
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', id,
            'name', name_snapshot,
            'code', code_snapshot,
            'start_time', start_time_snapshot,
            'end_time', end_time_snapshot,
            'sort_order', sort_order_snapshot
        ) ORDER BY sort_order_snapshot ASC
    ) INTO v_templates
    FROM public.availability_period_shift_templates
    WHERE availability_period_id = p_period_id;

    -- Submission record
    SELECT id, status, submitted_at
    INTO v_submission
    FROM public.availability_submissions
    WHERE availability_period_id = p_period_id AND membership_id = v_membership_id;

    -- Entries
    IF v_submission.id IS NOT NULL THEN
        SELECT jsonb_object_agg(
            date::text || '_' || period_shift_template_id::text,
            is_available
        ) INTO v_entries
        FROM public.availability_entries
        WHERE submission_id = v_submission.id;
    END IF;

    RETURN jsonb_build_object(
        'period_id', v_period.id,
        'station_id', v_period.station_id,
        'week_start_date', v_period.week_start_date,
        'period_status', v_period.status,
        'submission_deadline', v_period.submission_deadline,
        'notes', v_period.notes,
        'submission_id', v_submission.id,
        'submission_status', COALESCE(v_submission.status::text, 'NOT_STARTED'),
        'submitted_at', v_submission.submitted_at,
        'templates', COALESCE(v_templates, '[]'::jsonb),
        'entries', COALESCE(v_entries, '{}'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- RPC: Get Current Active Availability Period for Station
CREATE OR REPLACE FUNCTION public.get_current_availability_period(p_station_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_period RECORD;
    v_templates JSONB;
BEGIN
    v_caller_id := auth.uid();
    IF NOT public.is_station_member(p_station_id, v_caller_id) THEN
        RAISE EXCEPTION 'Access denied: caller is not a member of this station'
            USING ERRCODE = '42501';
    END IF;

    SELECT id, station_id, week_start_date, status, submission_deadline, notes, opened_at
    INTO v_period
    FROM public.availability_periods
    WHERE station_id = p_station_id
      AND status = 'OPEN'
    ORDER BY week_start_date ASC
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('has_active_period', false);
    END IF;

    SELECT jsonb_agg(
        jsonb_build_object(
            'id', id,
            'name', name_snapshot,
            'code', code_snapshot,
            'start_time', start_time_snapshot,
            'end_time', end_time_snapshot,
            'sort_order', sort_order_snapshot
        ) ORDER BY sort_order_snapshot ASC
    ) INTO v_templates
    FROM public.availability_period_shift_templates
    WHERE availability_period_id = v_period.id;

    RETURN jsonb_build_object(
        'has_active_period', true,
        'period', jsonb_build_object(
            'id', v_period.id,
            'station_id', v_period.station_id,
            'week_start_date', v_period.week_start_date,
            'status', v_period.status,
            'submission_deadline', v_period.submission_deadline,
            'notes', v_period.notes,
            'opened_at', v_period.opened_at,
            'templates', COALESCE(v_templates, '[]'::jsonb)
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 13. Enable Realtime Publications for Phase 2 Tables
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.shift_templates;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.station_shift_manager_permissions;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.availability_periods;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.availability_submissions;
    END IF;
END $$;

