-- ======================================================================
-- YELLOWSHIFTS — FIX KIOSK DEACTIVATE/REACTIVATE AUDIT LOG COLUMNS
-- Migration: 20260828000001_fix_kiosk_audit_log_columns.sql
-- ======================================================================

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
    SET is_active = false, updated_at = timezone('utc'::text, now())
    WHERE id = p_kiosk_device_id;

    UPDATE public.kiosk_qr_challenges
    SET revoked_at = timezone('utc'::text, now())
    WHERE kiosk_device_id = p_kiosk_device_id AND revoked_at IS NULL;

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id)
    VALUES (v_station_id, v_caller_id, 'KIOSK_DEVICE_DEACTIVATED', 'kiosk_devices', p_kiosk_device_id::text);

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
    SET is_active = true, updated_at = timezone('utc'::text, now())
    WHERE id = p_kiosk_device_id;

    INSERT INTO public.audit_logs (station_id, actor_id, action, target_type, target_id)
    VALUES (v_station_id, v_caller_id, 'KIOSK_DEVICE_REACTIVATED', 'kiosk_devices', p_kiosk_device_id::text);

    RETURN jsonb_build_object('success', true, 'kiosk_id', p_kiosk_device_id, 'is_active', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;
