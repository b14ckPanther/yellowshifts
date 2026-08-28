-- YellowShifts Phase 3 Migration
-- Shift Scheduling, Assignment Engine, Draft/Publish Lifecycle,
-- Staffing Requirements, Conflict Detection, Realtime Sync & Employee My Shifts

-- 1. Create Enums
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'work_schedule_status') THEN
        CREATE TYPE public.work_schedule_status AS ENUM ('DRAFT', 'PUBLISHED', 'ARCHIVED');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'schedule_change_type') THEN
        CREATE TYPE public.schedule_change_type AS ENUM (
            'ASSIGNMENT_ADDED', 'ASSIGNMENT_REMOVED', 'ASSIGNMENT_MOVED',
            'STAFFING_UPDATED', 'PUBLISHED', 'UNPUBLISHED', 'REVISED'
        );
    END IF;
END $$;

-- 2. Work Schedules Table
CREATE TABLE IF NOT EXISTS public.work_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    availability_period_id UUID NOT NULL REFERENCES public.availability_periods(id) ON DELETE RESTRICT,
    week_start_date DATE NOT NULL,
    status public.work_schedule_status NOT NULL DEFAULT 'DRAFT',
    version INTEGER NOT NULL DEFAULT 1,
    created_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    published_by UUID NULL REFERENCES public.profiles(id) ON DELETE SET NULL,
    published_at TIMESTAMPTZ NULL,
    notes TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_work_schedules_station_week UNIQUE (station_id, week_start_date),
    CONSTRAINT uq_work_schedules_period UNIQUE (availability_period_id)
);

CREATE INDEX IF NOT EXISTS idx_work_schedules_station_week ON public.work_schedules(station_id, week_start_date);
CREATE INDEX IF NOT EXISTS idx_work_schedules_status ON public.work_schedules(station_id, status);

-- 3. Work Schedule Shifts Table (Generated from frozen period shift templates)
CREATE TABLE IF NOT EXISTS public.work_schedule_shifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    work_schedule_id UUID NOT NULL REFERENCES public.work_schedules(id) ON DELETE CASCADE,
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    operational_date DATE NOT NULL,
    period_shift_template_id UUID NOT NULL REFERENCES public.availability_period_shift_templates(id) ON DELETE RESTRICT,
    shift_name_snapshot TEXT NOT NULL,
    shift_code_snapshot TEXT NULL,
    start_time_snapshot TIME NOT NULL,
    end_time_snapshot TIME NOT NULL,
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    required_staff_count INTEGER NOT NULL DEFAULT 1,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT chk_schedule_shift_staff_positive CHECK (required_staff_count >= 0)
);

CREATE INDEX IF NOT EXISTS idx_work_schedule_shifts_schedule ON public.work_schedule_shifts(work_schedule_id, operational_date, sort_order);
CREATE INDEX IF NOT EXISTS idx_work_schedule_shifts_instants ON public.work_schedule_shifts(station_id, starts_at, ends_at);

-- 4. Shift Assignments Table (Membership-scoped assignment with global user tracking)
CREATE TABLE IF NOT EXISTS public.shift_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    work_schedule_shift_id UUID NOT NULL REFERENCES public.work_schedule_shifts(id) ON DELETE CASCADE,
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    membership_id UUID NOT NULL REFERENCES public.station_memberships(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    availability_state_snapshot TEXT NOT NULL, -- 'AVAILABLE', 'UNAVAILABLE', 'NOT_SUBMITTED'
    availability_override BOOLEAN NOT NULL DEFAULT false,
    availability_override_reason TEXT NULL,
    assigned_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_shift_assignments_membership UNIQUE (work_schedule_shift_id, membership_id)
);

CREATE INDEX IF NOT EXISTS idx_shift_assignments_shift ON public.shift_assignments(work_schedule_shift_id);
CREATE INDEX IF NOT EXISTS idx_shift_assignments_user ON public.shift_assignments(user_id);
CREATE INDEX IF NOT EXISTS idx_shift_assignments_station_membership ON public.shift_assignments(station_id, membership_id);

-- 5. Work Schedule Changes Table (Immutable audit trail of post-publish revisions)
CREATE TABLE IF NOT EXISTS public.work_schedule_changes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    work_schedule_id UUID NOT NULL REFERENCES public.work_schedules(id) ON DELETE CASCADE,
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    version_before INTEGER NOT NULL,
    version_after INTEGER NOT NULL,
    change_type public.schedule_change_type NOT NULL,
    actor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    reason TEXT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_work_schedule_changes_schedule ON public.work_schedule_changes(work_schedule_id, created_at DESC);

-- 6. Automatic updated_at Triggers
DROP TRIGGER IF EXISTS tr_work_schedules_updated_at ON public.work_schedules;
CREATE TRIGGER tr_work_schedules_updated_at
    BEFORE UPDATE ON public.work_schedules
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS tr_work_schedule_shifts_updated_at ON public.work_schedule_shifts;
CREATE TRIGGER tr_work_schedule_shifts_updated_at
    BEFORE UPDATE ON public.work_schedule_shifts
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS tr_shift_assignments_updated_at ON public.shift_assignments;
CREATE TRIGGER tr_shift_assignments_updated_at
    BEFORE UPDATE ON public.shift_assignments
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- 7. Phase 3 Permissions Integration in has_station_permission
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
        IF p_permission IN ('shift_templates.read', 'availability.period.read', 'availability.submit', 'schedule.read') THEN
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
            WHEN 'shift_templates.manage' THEN RETURN FALSE;
            WHEN 'availability.period.create' THEN RETURN FALSE;
            WHEN 'availability.period.open' THEN RETURN FALSE;
            WHEN 'availability.period.close' THEN RETURN FALSE;
            WHEN 'schedule.manage' THEN RETURN FALSE;
            WHEN 'schedule.publish' THEN RETURN FALSE;
            ELSE RETURN FALSE;
        END CASE;
    END IF;

    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public, pg_temp;

-- 8. Row Level Security Policies
ALTER TABLE public.work_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_schedule_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shift_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_schedule_changes ENABLE ROW LEVEL SECURITY;

-- Work Schedules RLS
DROP POLICY IF EXISTS work_schedules_select ON public.work_schedules;
CREATE POLICY work_schedules_select ON public.work_schedules
    FOR SELECT TO authenticated
    USING (
        (status = 'PUBLISHED' AND public.is_station_member(station_id, (SELECT auth.uid()))) OR
        public.has_station_permission(station_id, (SELECT auth.uid()), 'schedule.read')
    );

-- Work Schedule Shifts RLS
DROP POLICY IF EXISTS work_schedule_shifts_select ON public.work_schedule_shifts;
CREATE POLICY work_schedule_shifts_select ON public.work_schedule_shifts
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.work_schedules ws
            WHERE ws.id = work_schedule_shifts.work_schedule_id
              AND (
                  (ws.status = 'PUBLISHED' AND public.is_station_member(ws.station_id, (SELECT auth.uid()))) OR
                  public.has_station_permission(ws.station_id, (SELECT auth.uid()), 'schedule.read')
              )
        )
    );

-- Shift Assignments RLS:
-- Managers with schedule.read can see all assignments;
-- Employees can ONLY see their own assignments (user_id = auth.uid()) on PUBLISHED schedules.
DROP POLICY IF EXISTS shift_assignments_select ON public.shift_assignments;
CREATE POLICY shift_assignments_select ON public.shift_assignments
    FOR SELECT TO authenticated
    USING (
        public.has_station_permission(station_id, (SELECT auth.uid()), 'schedule.read') OR
        (
            user_id = (SELECT auth.uid()) AND
            EXISTS (
                SELECT 1 FROM public.work_schedule_shifts wss
                JOIN public.work_schedules ws ON wss.work_schedule_id = ws.id
                WHERE wss.id = shift_assignments.work_schedule_shift_id
                  AND ws.status = 'PUBLISHED'
            )
        )
    );

-- Work Schedule Changes RLS
DROP POLICY IF EXISTS work_schedule_changes_select ON public.work_schedule_changes;
CREATE POLICY work_schedule_changes_select ON public.work_schedule_changes
    FOR SELECT TO authenticated
    USING (
        public.has_station_permission(station_id, (SELECT auth.uid()), 'schedule.read')
    );

-- 9. Server-Authoritative Scheduling RPC Functions

-- RPC: Create Work Schedule from Frozen Availability Period Snapshot
CREATE OR REPLACE FUNCTION public.create_work_schedule(p_availability_period_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_station_id UUID;
    v_week_start DATE;
    v_period_status public.availability_period_status;
    v_station_tz TEXT;
    v_schedule_id UUID;
    v_template RECORD;
    v_day_offset INTEGER;
    v_op_date DATE;
    v_starts_at TIMESTAMPTZ;
    v_ends_at TIMESTAMPTZ;
    v_shift_count INTEGER := 0;
BEGIN
    v_caller_id := auth.uid();

    -- Fetch and validate availability period
    SELECT ap.station_id, ap.week_start_date, ap.status, s.timezone
    INTO v_station_id, v_week_start, v_period_status, v_station_tz
    FROM public.availability_periods ap
    JOIN public.stations s ON ap.station_id = s.id
    WHERE ap.id = p_availability_period_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Availability period not found' USING ERRCODE = 'P0002';
    END IF;

    IF NOT public.has_station_permission(v_station_id, v_caller_id, 'schedule.manage') THEN
        RAISE EXCEPTION 'Access denied: caller does not have schedule.manage permission'
            USING ERRCODE = '42501';
    END IF;

    -- Validate period has frozen template snapshots
    IF NOT EXISTS (
        SELECT 1 FROM public.availability_period_shift_templates
        WHERE availability_period_id = p_availability_period_id
    ) THEN
        RAISE EXCEPTION 'Availability period has zero frozen shift templates'
            USING ERRCODE = 'P0003';
    END IF;

    -- Validate schedule does not already exist for this week
    IF EXISTS (
        SELECT 1 FROM public.work_schedules
        WHERE station_id = v_station_id AND week_start_date = v_week_start
    ) THEN
        RAISE EXCEPTION 'A work schedule already exists for this station and week'
            USING ERRCODE = '23505';
    END IF;

    -- 1. Create Work Schedule (DRAFT, Version 1)
    INSERT INTO public.work_schedules (
        station_id, availability_period_id, week_start_date, status, version, created_by
    ) VALUES (
        v_station_id, p_availability_period_id, v_week_start, 'DRAFT', 1, v_caller_id
    ) RETURNING id INTO v_schedule_id;

    -- 2. Generate all weekly operational shifts from frozen templates
    FOR v_day_offset IN 0..6 LOOP
        v_op_date := v_week_start + v_day_offset;

        FOR v_template IN (
            SELECT id, name_snapshot, code_snapshot, start_time_snapshot, end_time_snapshot, sort_order_snapshot
            FROM public.availability_period_shift_templates
            WHERE availability_period_id = p_availability_period_id
            ORDER BY sort_order_snapshot ASC, name_snapshot ASC
        ) LOOP
            -- Compute timezone-aware starts_at and ends_at instants
            v_starts_at := timezone(v_station_tz, (v_op_date + v_template.start_time_snapshot)::timestamp);

            IF v_template.start_time_snapshot < v_template.end_time_snapshot THEN
                -- Standard daytime shift
                v_ends_at := timezone(v_station_tz, (v_op_date + v_template.end_time_snapshot)::timestamp);
            ELSE
                -- Cross-midnight shift (ends on next calendar day)
                v_ends_at := timezone(v_station_tz, ((v_op_date + 1) + v_template.end_time_snapshot)::timestamp);
            END IF;

            INSERT INTO public.work_schedule_shifts (
                work_schedule_id, station_id, operational_date, period_shift_template_id,
                shift_name_snapshot, shift_code_snapshot, start_time_snapshot, end_time_snapshot,
                starts_at, ends_at, required_staff_count, sort_order
            ) VALUES (
                v_schedule_id, v_station_id, v_op_date, v_template.id,
                v_template.name_snapshot, v_template.code_snapshot, v_template.start_time_snapshot, v_template.end_time_snapshot,
                v_starts_at, v_ends_at, 1, v_template.sort_order_snapshot
            );

            v_shift_count := v_shift_count + 1;
        END LOOP;
    END LOOP;

    -- 3. Audit Log
    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        v_station_id, v_caller_id, 'WORK_SCHEDULE_CREATED', 'work_schedule', v_schedule_id::text,
        jsonb_build_object('week_start_date', v_week_start, 'generated_shifts', v_shift_count)
    );

    RETURN jsonb_build_object(
        'success', true,
        'schedule_id', v_schedule_id,
        'station_id', v_station_id,
        'week_start_date', v_week_start,
        'status', 'DRAFT',
        'version', 1,
        'generated_shifts_count', v_shift_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- RPC: Get Full Work Schedule Details (Shifts, Assignments, Staffing Status)
CREATE OR REPLACE FUNCTION public.get_schedule_details(p_schedule_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_schedule RECORD;
    v_shifts JSONB;
    v_assignments JSONB;
BEGIN
    v_caller_id := auth.uid();

    SELECT ws.*, s.name AS station_name, s.timezone AS station_timezone
    INTO v_schedule
    FROM public.work_schedules ws
    JOIN public.stations s ON ws.station_id = s.id
    WHERE ws.id = p_schedule_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Work schedule not found' USING ERRCODE = 'P0002';
    END IF;

    -- Check access permission
    IF v_schedule.status = 'PUBLISHED' THEN
        IF NOT public.is_station_member(v_schedule.station_id, v_caller_id) THEN
            RAISE EXCEPTION 'Access denied: caller is not a member of this station' USING ERRCODE = '42501';
        END IF;
    ELSE
        IF NOT public.has_station_permission(v_schedule.station_id, v_caller_id, 'schedule.read') THEN
            RAISE EXCEPTION 'Access denied: caller does not have schedule.read permission' USING ERRCODE = '42501';
        END IF;
    END IF;

    -- Aggregate shifts with assignments
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', wss.id,
            'work_schedule_id', wss.work_schedule_id,
            'station_id', wss.station_id,
            'operational_date', wss.operational_date,
            'period_shift_template_id', wss.period_shift_template_id,
            'shift_name', wss.shift_name_snapshot,
            'shift_code', wss.shift_code_snapshot,
            'start_time', wss.start_time_snapshot,
            'end_time', wss.end_time_snapshot,
            'starts_at', wss.starts_at,
            'ends_at', wss.ends_at,
            'required_staff_count', wss.required_staff_count,
            'assigned_staff_count', (
                SELECT COUNT(*) FROM public.shift_assignments sa WHERE sa.work_schedule_shift_id = wss.id
            ),
            'sort_order', wss.sort_order,
            'assignments', COALESCE((
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', sa.id,
                        'membership_id', sa.membership_id,
                        'user_id', sa.user_id,
                        'first_name', p.first_name,
                        'last_name', p.last_name,
                        'employee_code', sm.employee_code,
                        'role', sm.role,
                        'availability_state_snapshot', sa.availability_state_snapshot,
                        'availability_override', sa.availability_override,
                        'availability_override_reason', sa.availability_override_reason,
                        'assigned_by', sa.assigned_by,
                        'created_at', sa.created_at
                    ) ORDER BY p.first_name ASC, p.last_name ASC
                )
                FROM public.shift_assignments sa
                JOIN public.station_memberships sm ON sa.membership_id = sm.id
                JOIN public.profiles p ON sa.user_id = p.id
                WHERE sa.work_schedule_shift_id = wss.id
                  AND (
                      public.has_station_permission(v_schedule.station_id, v_caller_id, 'schedule.read') OR
                      (v_schedule.status = 'PUBLISHED' AND sa.user_id = v_caller_id)
                  )
            ), '[]'::jsonb)
        ) ORDER BY wss.operational_date ASC, wss.sort_order ASC
    ), '[]'::jsonb)
    INTO v_shifts
    FROM public.work_schedule_shifts wss
    WHERE wss.work_schedule_id = p_schedule_id;

    RETURN jsonb_build_object(
        'id', v_schedule.id,
        'station_id', v_schedule.station_id,
        'station_name', v_schedule.station_name,
        'station_timezone', v_schedule.station_timezone,
        'availability_period_id', v_schedule.availability_period_id,
        'week_start_date', v_schedule.week_start_date,
        'status', v_schedule.status,
        'version', v_schedule.version,
        'created_by', v_schedule.created_by,
        'published_by', v_schedule.published_by,
        'published_at', v_schedule.published_at,
        'notes', v_schedule.notes,
        'created_at', v_schedule.created_at,
        'updated_at', v_schedule.updated_at,
        'shifts', v_shifts
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- RPC: Candidate Resolution for Shift Assignment
CREATE OR REPLACE FUNCTION public.get_shift_assignment_candidates(
    p_schedule_shift_id UUID,
    p_search TEXT DEFAULT NULL,
    p_filter TEXT DEFAULT 'ALL'
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_shift RECORD;
    v_schedule RECORD;
    v_candidates JSONB;
    v_clean_search TEXT;
BEGIN
    v_caller_id := auth.uid();

    SELECT wss.*, ws.availability_period_id, ws.week_start_date, ws.station_id AS ws_station_id, ws.version AS ws_version
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

    v_clean_search := NULLIF(trim(p_search), '');
    IF v_clean_search IS NOT NULL THEN
        v_clean_search := regexp_replace(v_clean_search, '([%_\\])', '\\\1', 'g');
    END IF;

    -- Query all active members in the station and compute availability + overlap state
    WITH member_candidates AS (
        SELECT 
            sm.id AS membership_id,
            sm.user_id,
            p.first_name,
            p.last_name,
            sm.employee_code,
            sm.role,
            -- Check already assigned to this shift
            EXISTS (
                SELECT 1 FROM public.shift_assignments sa
                WHERE sa.work_schedule_shift_id = p_schedule_shift_id AND sa.membership_id = sm.id
            ) AS already_assigned,
            -- Determine finalized availability from Phase 2
            COALESCE((
                SELECT 
                    CASE 
                        WHEN ae.is_available = true THEN 'AVAILABLE'
                        WHEN ae.is_available = false THEN 'UNAVAILABLE'
                        ELSE 'NOT_SUBMITTED'
                    END
                FROM public.availability_submissions asub
                JOIN public.availability_entries ae ON ae.submission_id = asub.id
                WHERE asub.availability_period_id = v_shift.availability_period_id
                  AND asub.membership_id = sm.id
                  AND asub.status = 'SUBMITTED'
                  AND ae.period_shift_template_id = v_shift.period_shift_template_id
                  AND ae.date = v_shift.operational_date
            ), 'NOT_SUBMITTED') AS availability_state,
            -- Overlap conflict detection across ALL stations (half-open interval [starts_at, ends_at))
            (
                SELECT 
                    CASE 
                        WHEN other_wss.station_id = v_shift.station_id THEN 'OVERLAPPING_ASSIGNMENT'
                        ELSE 'CROSS_STATION_OVERLAP'
                    END
                FROM public.shift_assignments other_sa
                JOIN public.work_schedule_shifts other_wss ON other_sa.work_schedule_shift_id = other_wss.id
                WHERE other_sa.user_id = sm.user_id
                  AND other_sa.work_schedule_shift_id <> p_schedule_shift_id
                  AND other_wss.starts_at < v_shift.ends_at
                  AND v_shift.starts_at < other_wss.ends_at
                LIMIT 1
            ) AS conflict_state,
            -- Weekly assignment count in this schedule
            (
                SELECT COUNT(*)
                FROM public.shift_assignments sa2
                JOIN public.work_schedule_shifts wss2 ON sa2.work_schedule_shift_id = wss2.id
                WHERE sa2.membership_id = sm.id AND wss2.work_schedule_id = v_shift.work_schedule_id
            ) AS weekly_shifts_count
        FROM public.station_memberships sm
        JOIN public.profiles p ON sm.user_id = p.id
        WHERE sm.station_id = v_shift.station_id
          AND sm.status = 'ACTIVE'
    )
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'membership_id', mc.membership_id,
            'user_id', mc.user_id,
            'first_name', mc.first_name,
            'last_name', mc.last_name,
            'employee_code', mc.employee_code,
            'role', mc.role,
            'already_assigned', mc.already_assigned,
            'availability_state', mc.availability_state,
            'conflict_state', COALESCE(mc.conflict_state, 'NONE'),
            'weekly_shifts_count', mc.weekly_shifts_count
        ) ORDER BY 
            mc.already_assigned DESC,
            CASE mc.availability_state 
                WHEN 'AVAILABLE' THEN 0 
                WHEN 'NOT_SUBMITTED' THEN 1 
                ELSE 2 
            END ASC,
            mc.first_name ASC, mc.last_name ASC
    ), '[]'::jsonb)
    INTO v_candidates
    FROM member_candidates mc
    WHERE (
        v_clean_search IS NULL OR
        mc.first_name ILIKE '%' || v_clean_search || '%' OR
        mc.last_name ILIKE '%' || v_clean_search || '%' OR
        (mc.first_name || ' ' || mc.last_name) ILIKE '%' || v_clean_search || '%' OR
        COALESCE(mc.employee_code, '') ILIKE '%' || v_clean_search || '%'
    )
    AND (
        p_filter = 'ALL' OR
        (p_filter = 'AVAILABLE' AND mc.availability_state = 'AVAILABLE') OR
        (p_filter = 'UNAVAILABLE' AND mc.availability_state = 'UNAVAILABLE') OR
        (p_filter = 'NOT_SUBMITTED' AND mc.availability_state = 'NOT_SUBMITTED') OR
        (p_filter = 'CONFLICT' AND mc.conflict_state IS NOT NULL)
    );

    RETURN jsonb_build_object(
        'schedule_shift_id', p_schedule_shift_id,
        'shift_name', v_shift.shift_name_snapshot,
        'operational_date', v_shift.operational_date,
        'starts_at', v_shift.starts_at,
        'ends_at', v_shift.ends_at,
        'schedule_version', v_shift.ws_version,
        'candidates', v_candidates
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- RPC: Assign Employee to Shift (Atomic OCC, Global Overlap Defense, Override Governance)
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
    v_schedule RECORD;
    v_membership RECORD;
    v_user_id UUID;
    v_new_version INTEGER;
    v_assignment_id UUID;
    v_availability_state TEXT;
    v_overlap_record RECORD;
BEGIN
    v_caller_id := auth.uid();

    -- Fetch shift and parent schedule
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

    -- Validate and fetch membership
    SELECT * INTO v_membership
    FROM public.station_memberships
    WHERE id = p_membership_id AND station_id = v_shift.station_id;

    IF NOT FOUND OR v_membership.status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Employee membership is not active for this station' USING ERRCODE = '22000';
    END IF;

    v_user_id := v_membership.user_id;

    -- CONCURRENCY CONTROL:
    -- 1. Row lock on the global user profile to serialize concurrent multi-station assignments
    PERFORM 1 FROM public.profiles WHERE id = v_user_id FOR UPDATE;

    -- 2. OCC Version Check and atomic increment on work_schedules
    UPDATE public.work_schedules
    SET version = version + 1, updated_at = timezone('utc'::text, now())
    WHERE id = v_shift.work_schedule_id AND version = p_expected_version
    RETURNING version INTO v_new_version;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Schedule version conflict: expected version %, but current version has changed', p_expected_version
            USING ERRCODE = 'P0005';
    END IF;

    -- Check duplicate assignment on the same shift
    IF EXISTS (
        SELECT 1 FROM public.shift_assignments
        WHERE work_schedule_shift_id = p_schedule_shift_id AND membership_id = p_membership_id
    ) THEN
        RAISE EXCEPTION 'Employee is already assigned to this shift' USING ERRCODE = '23505';
    END IF;

    -- 3. Resolve Finalized Phase 2 Availability State
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

    -- Validate Availability Override requirement
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

    -- 4. Global Overlap & Cross-Station Conflict Check [starts_at, ends_at)
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
            -- Cross-station conflict: sanitize foreign station internal details
            RAISE EXCEPTION 'Cross-station overlap conflict: employee is already assigned at another station during this time window'
                USING ERRCODE = 'P0009';
        END IF;
    END IF;

    -- 5. If schedule is PUBLISHED, require a change reason
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
                'user_id', v_user_id,
                'availability_state', v_availability_state,
                'override', p_override,
                'override_reason', p_override_reason
            )
        );
    END IF;

    -- 6. Insert Assignment
    INSERT INTO public.shift_assignments (
        work_schedule_shift_id, station_id, membership_id, user_id,
        availability_state_snapshot, availability_override, availability_override_reason, assigned_by
    ) VALUES (
        p_schedule_shift_id, v_shift.station_id, p_membership_id, v_user_id,
        v_availability_state, COALESCE(p_override, false), p_override_reason, v_caller_id
    ) RETURNING id INTO v_assignment_id;

    -- 7. Audit Log
    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        v_shift.station_id, v_caller_id, 'SHIFT_ASSIGNMENT_CREATED', 'shift_assignment', v_assignment_id::text,
        jsonb_build_object(
            'schedule_id', v_shift.work_schedule_id,
            'shift_id', p_schedule_shift_id,
            'membership_id', p_membership_id,
            'availability_state', v_availability_state,
            'override', p_override,
            'new_version', v_new_version
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'assignment_id', v_assignment_id,
        'new_version', v_new_version,
        'availability_state', v_availability_state
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- RPC: Remove Shift Assignment
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

    SELECT sa.*, wss.work_schedule_id, ws.status AS schedule_status, ws.version AS current_version
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

    -- OCC Version check and atomic increment
    UPDATE public.work_schedules
    SET version = version + 1, updated_at = timezone('utc'::text, now())
    WHERE id = v_assignment.work_schedule_id AND version = p_expected_version
    RETURNING version INTO v_new_version;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Schedule version conflict: expected version %, but current version has changed', p_expected_version
            USING ERRCODE = 'P0005';
    END IF;

    -- If PUBLISHED, require reason
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

    RETURN jsonb_build_object(
        'success', true,
        'new_version', v_new_version
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- RPC: Move Shift Assignment (Atomic Source Deletion + Target Creation)
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

    SELECT sa.*, wss.work_schedule_id, ws.status AS schedule_status, ws.availability_period_id
    INTO v_assignment
    FROM public.shift_assignments sa
    JOIN public.work_schedule_shifts wss ON sa.work_schedule_shift_id = wss.id
    JOIN public.work_schedules ws ON wss.work_schedule_id = ws.id
    WHERE sa.id = p_assignment_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Shift assignment not found' USING ERRCODE = 'P0002';
    END IF;

    -- Fetch target shift
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

    -- Concurrency lock on user profile
    PERFORM 1 FROM public.profiles WHERE id = v_assignment.user_id FOR UPDATE;

    -- OCC Version check and atomic increment
    UPDATE public.work_schedules
    SET version = version + 1, updated_at = timezone('utc'::text, now())
    WHERE id = v_assignment.work_schedule_id AND version = p_expected_version
    RETURNING version INTO v_new_version;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Schedule version conflict: expected version %, but current version has changed', p_expected_version
            USING ERRCODE = 'P0005';
    END IF;

    -- Check duplicate assignment on target shift
    IF EXISTS (
        SELECT 1 FROM public.shift_assignments
        WHERE work_schedule_shift_id = p_target_shift_id AND membership_id = v_assignment.membership_id
    ) THEN
        RAISE EXCEPTION 'Employee is already assigned to target shift' USING ERRCODE = '23505';
    END IF;

    -- Resolve target availability
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
            RAISE EXCEPTION 'Availability override required for % employee', v_availability_state
                USING ERRCODE = 'P0006';
        END IF;

        IF p_override_reason IS NULL OR length(trim(p_override_reason)) < 3 THEN
            RAISE EXCEPTION 'A valid override reason (at least 3 characters) is required'
                USING ERRCODE = 'P0007';
        END IF;
    END IF;

    -- Overlap check excluding source assignment
    SELECT other_wss.station_id, other_wss.shift_name_snapshot, other_wss.starts_at, other_wss.ends_at
    INTO v_overlap_record
    FROM public.shift_assignments other_sa
    JOIN public.work_schedule_shifts other_wss ON other_sa.work_schedule_shift_id = other_wss.id
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

    -- If PUBLISHED, log change
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

    -- Update Assignment atomically
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
            'target_shift_id', p_target_shift_id,
            'new_version', v_new_version
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'assignment_id', p_assignment_id,
        'new_version', v_new_version,
        'availability_state', v_availability_state
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- RPC: Update Schedule Shift Required Staff Count
CREATE OR REPLACE FUNCTION public.update_schedule_shift_staffing(
    p_schedule_shift_id UUID,
    p_required_count INTEGER,
    p_expected_version INTEGER,
    p_change_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_shift RECORD;
    v_new_version INTEGER;
BEGIN
    v_caller_id := auth.uid();

    IF p_required_count < 0 THEN
        RAISE EXCEPTION 'Required staff count must be greater than or equal to 0' USING ERRCODE = '22000';
    END IF;

    SELECT wss.*, ws.status AS schedule_status
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

    -- OCC Version check and atomic increment
    UPDATE public.work_schedules
    SET version = version + 1, updated_at = timezone('utc'::text, now())
    WHERE id = v_shift.work_schedule_id AND version = p_expected_version
    RETURNING version INTO v_new_version;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Schedule version conflict: expected version %, but current version has changed', p_expected_version
            USING ERRCODE = 'P0005';
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
            'STAFFING_UPDATED', v_caller_id, trim(p_change_reason),
            jsonb_build_object(
                'shift_id', p_schedule_shift_id,
                'old_required', v_shift.required_staff_count,
                'new_required', p_required_count
            )
        );
    END IF;

    UPDATE public.work_schedule_shifts
    SET required_staff_count = p_required_count,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_schedule_shift_id;

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        v_shift.station_id, v_caller_id, 'SHIFT_STAFFING_UPDATED', 'work_schedule_shift', p_schedule_shift_id::text,
        jsonb_build_object('new_required', p_required_count, 'new_version', v_new_version)
    );

    RETURN jsonb_build_object(
        'success', true,
        'new_version', v_new_version,
        'required_staff_count', p_required_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- RPC: Validate Work Schedule Preconditions and Warnings
CREATE OR REPLACE FUNCTION public.validate_work_schedule(p_schedule_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_schedule RECORD;
    v_hard_errors JSONB := '[]'::jsonb;
    v_warnings JSONB := '[]'::jsonb;
    v_total_shifts INTEGER := 0;
    v_fully_staffed INTEGER := 0;
    v_understaffed INTEGER := 0;
    v_overstaffed INTEGER := 0;
    v_total_assignments INTEGER := 0;
    v_rec RECORD;
BEGIN
    v_caller_id := auth.uid();

    SELECT * INTO v_schedule
    FROM public.work_schedules
    WHERE id = p_schedule_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Work schedule not found' USING ERRCODE = 'P0002';
    END IF;

    IF NOT public.has_station_permission(v_schedule.station_id, v_caller_id, 'schedule.read') THEN
        RAISE EXCEPTION 'Access denied: caller does not have schedule.read permission' USING ERRCODE = '42501';
    END IF;

    -- 1. Check for Inactive Membership Assignments (Hard Conflict)
    FOR v_rec IN (
        SELECT sa.id, p.first_name || ' ' || p.last_name AS employee_name, sm.status, wss.shift_name_snapshot, wss.operational_date
        FROM public.shift_assignments sa
        JOIN public.station_memberships sm ON sa.membership_id = sm.id
        JOIN public.profiles p ON sa.user_id = p.id
        JOIN public.work_schedule_shifts wss ON sa.work_schedule_shift_id = wss.id
        WHERE wss.work_schedule_id = p_schedule_id
          AND sm.status <> 'ACTIVE'
    ) LOOP
        v_hard_errors := v_hard_errors || jsonb_build_object(
            'code', 'INACTIVE_MEMBERSHIP',
            'message', 'Assigned employee ' || v_rec.employee_name || ' is inactive on ' || v_rec.shift_name_snapshot || ' (' || v_rec.operational_date || ')',
            'assignment_id', v_rec.id
        );
    END LOOP;

    -- 2. Check for Overlapping Shifts for Same User (Hard Conflict)
    FOR v_rec IN (
        SELECT sa1.user_id, p.first_name || ' ' || p.last_name AS employee_name,
               wss1.shift_name_snapshot AS shift1_name, wss2.shift_name_snapshot AS shift2_name,
               wss1.starts_at, wss1.ends_at
        FROM public.shift_assignments sa1
        JOIN public.work_schedule_shifts wss1 ON sa1.work_schedule_shift_id = wss1.id
        JOIN public.shift_assignments sa2 ON sa1.user_id = sa2.user_id AND sa1.id < sa2.id
        JOIN public.work_schedule_shifts wss2 ON sa2.work_schedule_shift_id = wss2.id
        JOIN public.profiles p ON sa1.user_id = p.id
        WHERE wss1.work_schedule_id = p_schedule_id
          AND wss2.work_schedule_id = p_schedule_id
          AND wss1.starts_at < wss2.ends_at
          AND wss2.starts_at < wss1.ends_at
    ) LOOP
        v_hard_errors := v_hard_errors || jsonb_build_object(
            'code', 'OVERLAPPING_ASSIGNMENT',
            'message', 'Employee ' || v_rec.employee_name || ' has overlapping shifts: ' || v_rec.shift1_name || ' and ' || v_rec.shift2_name
        );
    END LOOP;

    -- 3. Check Staffing Levels & Warnings
    FOR v_rec IN (
        SELECT wss.id, wss.shift_name_snapshot, wss.operational_date, wss.required_staff_count,
               COUNT(sa.id) AS assigned_count
        FROM public.work_schedule_shifts wss
        LEFT JOIN public.shift_assignments sa ON sa.work_schedule_shift_id = wss.id
        WHERE wss.work_schedule_id = p_schedule_id
        GROUP BY wss.id, wss.shift_name_snapshot, wss.operational_date, wss.required_staff_count
    ) LOOP
        v_total_shifts := v_total_shifts + 1;
        v_total_assignments := v_total_assignments + v_rec.assigned_count;

        IF v_rec.assigned_count = v_rec.required_staff_count THEN
            v_fully_staffed := v_fully_staffed + 1;
        ELSIF v_rec.assigned_count < v_rec.required_staff_count THEN
            v_understaffed := v_understaffed + 1;
            v_warnings := v_warnings || jsonb_build_object(
                'code', 'UNDERSTAFFED_SHIFT',
                'message', v_rec.shift_name_snapshot || ' on ' || v_rec.operational_date || ' is understaffed (' || v_rec.assigned_count || '/' || v_rec.required_staff_count || ')',
                'shift_id', v_rec.id
            );
        ELSE
            v_overstaffed := v_overstaffed + 1;
            v_warnings := v_warnings || jsonb_build_object(
                'code', 'OVERSTAFFED_SHIFT',
                'message', v_rec.shift_name_snapshot || ' on ' || v_rec.operational_date || ' is overstaffed (' || v_rec.assigned_count || '/' || v_rec.required_staff_count || ')',
                'shift_id', v_rec.id
            );
        END IF;
    END LOOP;

    -- 4. Check for Availability Overrides & Availability Drift (Warnings)
    FOR v_rec IN (
        SELECT sa.id, p.first_name || ' ' || p.last_name AS employee_name,
               wss.shift_name_snapshot, wss.operational_date, sa.availability_state_snapshot, sa.availability_override,
               COALESCE((
                   SELECT CASE 
                       WHEN ae.is_available = true THEN 'AVAILABLE'
                       WHEN ae.is_available = false THEN 'UNAVAILABLE'
                       ELSE 'NOT_SUBMITTED'
                   END
                   FROM public.availability_submissions asub
                   JOIN public.availability_entries ae ON ae.submission_id = asub.id
                   WHERE asub.availability_period_id = v_schedule.availability_period_id
                     AND asub.membership_id = sa.membership_id
                     AND asub.status = 'SUBMITTED'
                     AND ae.period_shift_template_id = wss.period_shift_template_id
                     AND ae.date = wss.operational_date
               ), 'NOT_SUBMITTED') AS current_availability
        FROM public.shift_assignments sa
        JOIN public.work_schedule_shifts wss ON sa.work_schedule_shift_id = wss.id
        JOIN public.profiles p ON sa.user_id = p.id
        WHERE wss.work_schedule_id = p_schedule_id
    ) LOOP
        IF v_rec.availability_override THEN
            v_warnings := v_warnings || jsonb_build_object(
                'code', 'AVAILABILITY_OVERRIDE',
                'message', 'Employee ' || v_rec.employee_name || ' assigned with override (' || v_rec.availability_state_snapshot || ') on ' || v_rec.shift_name_snapshot || ' (' || v_rec.operational_date || ')',
                'assignment_id', v_rec.id
            );
        ELSIF v_rec.availability_state_snapshot = 'AVAILABLE' AND v_rec.current_availability <> 'AVAILABLE' THEN
            -- Availability Drift Warning
            v_warnings := v_warnings || jsonb_build_object(
                'code', 'AVAILABILITY_DRIFT',
                'message', 'Employee ' || v_rec.employee_name || ' availability changed to ' || v_rec.current_availability || ' after draft assignment on ' || v_rec.shift_name_snapshot || ' (' || v_rec.operational_date || ')',
                'assignment_id', v_rec.id
            );
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'schedule_id', p_schedule_id,
        'is_valid', (jsonb_array_length(v_hard_errors) = 0),
        'can_publish', (jsonb_array_length(v_hard_errors) = 0),
        'hard_errors_count', jsonb_array_length(v_hard_errors),
        'warnings_count', jsonb_array_length(v_warnings),
        'hard_errors', v_hard_errors,
        'warnings', v_warnings,
        'summary', jsonb_build_object(
            'total_shifts', v_total_shifts,
            'fully_staffed_shifts', v_fully_staffed,
            'understaffed_shifts', v_understaffed,
            'overstaffed_shifts', v_overstaffed,
            'total_assignments', v_total_assignments
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- RPC: Publish Work Schedule (Atomic Freeze, Precondition Validation, Warning Confirmation)
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

    -- OCC Version Check
    IF v_schedule.version <> p_expected_version THEN
        RAISE EXCEPTION 'Schedule version conflict: expected version %, but current version has changed', p_expected_version
            USING ERRCODE = 'P0005';
    END IF;

    -- Authoritative Pre-Publish Validation
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

    -- Publish Atomic Update
    UPDATE public.work_schedules
    SET status = 'PUBLISHED',
        published_by = v_caller_id,
        published_at = timezone('utc'::text, now()),
        version = version + 1,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_schedule_id
    RETURNING version INTO v_new_version;

    -- Record in changes history
    INSERT INTO public.work_schedule_changes (
        work_schedule_id, station_id, version_before, version_after, change_type, actor_id, reason, metadata
    ) VALUES (
        p_schedule_id, v_schedule.station_id, p_expected_version, v_new_version,
        'PUBLISHED', v_caller_id, 'Initial schedule publication',
        jsonb_build_object(
            'published_at', timezone('utc'::text, now()),
            'warnings_confirmed', p_confirm_warnings,
            'summary', v_validation->'summary'
        )
    );

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES (
        v_schedule.station_id, v_caller_id, 'WORK_SCHEDULE_PUBLISHED', 'work_schedule', p_schedule_id::text,
        jsonb_build_object('published_at', timezone('utc'::text, now()), 'new_version', v_new_version)
    );

    RETURN jsonb_build_object(
        'success', true,
        'schedule_id', p_schedule_id,
        'status', 'PUBLISHED',
        'published_at', timezone('utc'::text, now()),
        'new_version', v_new_version
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- RPC: Get Employee My Shifts (Published assignments for active station)
CREATE OR REPLACE FUNCTION public.get_my_shifts(
    p_station_id UUID,
    p_week_start_date DATE
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_schedule RECORD;
    v_shifts JSONB;
BEGIN
    v_caller_id := auth.uid();

    IF NOT public.is_station_member(p_station_id, v_caller_id) THEN
        RAISE EXCEPTION 'Access denied: caller is not a member of this station' USING ERRCODE = '42501';
    END IF;

    SELECT ws.*, s.name AS station_name, s.timezone AS station_timezone
    INTO v_schedule
    FROM public.work_schedules ws
    JOIN public.stations s ON ws.station_id = s.id
    WHERE ws.station_id = p_station_id
      AND ws.week_start_date = p_week_start_date
      AND ws.status = 'PUBLISHED';

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'has_published_schedule', false,
            'station_id', p_station_id,
            'week_start_date', p_week_start_date,
            'shifts', '[]'::jsonb
        );
    END IF;

    -- Fetch caller's assigned shifts
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'assignment_id', sa.id,
            'shift_id', wss.id,
            'station_id', wss.station_id,
            'station_name', v_schedule.station_name,
            'operational_date', wss.operational_date,
            'shift_name', wss.shift_name_snapshot,
            'shift_code', wss.shift_code_snapshot,
            'start_time', wss.start_time_snapshot,
            'end_time', wss.end_time_snapshot,
            'starts_at', wss.starts_at,
            'ends_at', wss.ends_at,
            'is_cross_midnight', (wss.start_time_snapshot > wss.end_time_snapshot),
            'availability_state_snapshot', sa.availability_state_snapshot,
            'availability_override', sa.availability_override
        ) ORDER BY wss.operational_date ASC, wss.starts_at ASC
    ), '[]'::jsonb)
    INTO v_shifts
    FROM public.shift_assignments sa
    JOIN public.work_schedule_shifts wss ON sa.work_schedule_shift_id = wss.id
    WHERE wss.work_schedule_id = v_schedule.id
      AND sa.user_id = v_caller_id;

    RETURN jsonb_build_object(
        'has_published_schedule', true,
        'schedule_id', v_schedule.id,
        'station_id', p_station_id,
        'station_name', v_schedule.station_name,
        'week_start_date', p_week_start_date,
        'published_at', v_schedule.published_at,
        'shifts_count', jsonb_array_length(v_shifts),
        'shifts', v_shifts
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 10. Realtime Publications
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.work_schedules;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.work_schedule_shifts;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.shift_assignments;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.work_schedule_changes;
    END IF;
END $$;
