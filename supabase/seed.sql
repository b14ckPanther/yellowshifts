-- YellowShifts Phase 0 Development Seed Data
-- CAUTION: This seed script is strictly for isolated local development and integration testing.
-- It demonstrates multi-station tenancy and role variance across stations.
-- Fixture emails use the .local suffix. Fixture passwords are not production credentials.

DO $$
DECLARE
    v_user1_id UUID := '11111111-1111-1111-1111-111111111111';
    v_user2_id UUID := '22222222-2222-2222-2222-222222222222';
    v_user3_id UUID := '33333333-3333-3333-3333-333333333333';
    v_station_north_id UUID := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    v_station_south_id UUID := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
BEGIN
    -- 1. Create Auth Users (Local Dev Fixture)
    INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    VALUES
    (
        v_user1_id,
        '00000000-0000-0000-0000-000000000000',
        'authenticated',
        'authenticated',
        'admin.david@yellowshifts.local',
        crypt('LocalDevOnly!', gen_salt('bf')),
        now(),
        '{"provider":"email","providers":["email"]}',
        '{"first_name":"David","last_name":"Cohen","preferred_locale":"he"}',
        now(),
        now()
    ),
    (
        v_user2_id,
        '00000000-0000-0000-0000-000000000000',
        'authenticated',
        'authenticated',
        'manager.sarah@yellowshifts.local',
        crypt('LocalDevOnly!', gen_salt('bf')),
        now(),
        '{"provider":"email","providers":["email"]}',
        '{"first_name":"Sarah","last_name":"Levi","preferred_locale":"he"}',
        now(),
        now()
    ),
    (
        v_user3_id,
        '00000000-0000-0000-0000-000000000000',
        'authenticated',
        'authenticated',
        'employee.yossi@yellowshifts.local',
        crypt('LocalDevOnly!', gen_salt('bf')),
        now(),
        '{"provider":"email","providers":["email"]}',
        '{"first_name":"Yossi","last_name":"Mizrahi","preferred_locale":"he"}',
        now(),
        now()
    )
    ON CONFLICT (id) DO NOTHING;

    -- 2. Upsert Profiles
    INSERT INTO public.profiles (id, first_name, last_name, phone, preferred_locale)
    VALUES
    (v_user1_id, 'David', 'Cohen', '+972501234567', 'he'),
    (v_user2_id, 'Sarah', 'Levi', '+972522345678', 'he'),
    (v_user3_id, 'Yossi', 'Mizrahi', '+972543456789', 'he')
    ON CONFLICT (id) DO UPDATE
    SET first_name = EXCLUDED.first_name,
        last_name = EXCLUDED.last_name,
        phone = EXCLUDED.phone,
        preferred_locale = EXCLUDED.preferred_locale;

    -- 3. Create Multi-Station Fixtures
    INSERT INTO public.stations (id, name, code, timezone, locale, week_start, is_active)
    VALUES
    (v_station_north_id, 'Galil Central Hub', 'YS-GAL-01', 'Asia/Jerusalem', 'he', 0, true),
    (v_station_south_id, 'Negev Operations Center', 'YS-NGV-02', 'Asia/Jerusalem', 'he', 0, true)
    ON CONFLICT (id) DO UPDATE
    SET name = EXCLUDED.name,
        code = EXCLUDED.code,
        timezone = EXCLUDED.timezone,
        locale = EXCLUDED.locale,
        is_active = EXCLUDED.is_active;

    -- 4. Station Memberships (Demonstrating multi-station role variance)
    -- User 1: ADMIN in Galil Central Hub, SHIFT_MANAGER in Negev Operations Center
    INSERT INTO public.station_memberships (station_id, user_id, role, status)
    VALUES
    (v_station_north_id, v_user1_id, 'ADMIN', 'ACTIVE'),
    (v_station_south_id, v_user1_id, 'SHIFT_MANAGER', 'ACTIVE')
    ON CONFLICT (station_id, user_id) DO UPDATE
    SET role = EXCLUDED.role, status = EXCLUDED.status;

    -- User 2: SHIFT_MANAGER in Galil Central Hub, EMPLOYEE in Negev Operations Center
    INSERT INTO public.station_memberships (station_id, user_id, role, status)
    VALUES
    (v_station_north_id, v_user2_id, 'SHIFT_MANAGER', 'ACTIVE'),
    (v_station_south_id, v_user2_id, 'EMPLOYEE', 'ACTIVE')
    ON CONFLICT (station_id, user_id) DO UPDATE
    SET role = EXCLUDED.role, status = EXCLUDED.status;

    -- User 3: EMPLOYEE in Galil Central Hub only
    INSERT INTO public.station_memberships (station_id, user_id, role, status)
    VALUES
    (v_station_north_id, v_user3_id, 'EMPLOYEE', 'ACTIVE')
    ON CONFLICT (station_id, user_id) DO UPDATE
    SET role = EXCLUDED.role, status = EXCLUDED.status;

    -- 5. Audit Log Entry (Foundation verification)
    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id, metadata)
    VALUES
    (v_station_north_id, v_user1_id, 'SYSTEM_INITIALIZED', 'station', v_station_north_id::text, '{"environment":"development"}'::jsonb),
    (v_station_south_id, v_user1_id, 'SYSTEM_INITIALIZED', 'station', v_station_south_id::text, '{"environment":"development"}'::jsonb);

END $$;
