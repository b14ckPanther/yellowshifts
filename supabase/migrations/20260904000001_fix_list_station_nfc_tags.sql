-- Fix list_station_nfc_tags RPC to use first_name and last_name from profiles
CREATE OR REPLACE FUNCTION public.list_station_nfc_tags(
    p_station_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_caller_id UUID;
    v_result JSONB;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    IF NOT public.has_station_permission(p_station_id, v_caller_id, 'attendance.nfc.manage') THEN
        RAISE EXCEPTION 'Access denied: caller cannot view NFC tags for this station' USING ERRCODE = '42501';
    END IF;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', t.id,
            'station_id', t.station_id,
            'name', t.name,
            'tag_identifier', t.tag_identifier,
            'is_active', t.is_active,
            'created_at', t.created_at,
            'revoked_at', t.revoked_at,
            'last_scanned_at', t.last_scanned_at,
            'created_by_name', NULLIF(TRIM(CONCAT(cp.first_name, ' ', cp.last_name)), ''),
            'revoked_by_name', NULLIF(TRIM(CONCAT(rp.first_name, ' ', rp.last_name)), '')
        ) ORDER BY t.created_at DESC
    ), '[]'::jsonb) INTO v_result
    FROM public.station_nfc_tags t
    LEFT JOIN public.profiles cp ON t.created_by = cp.id
    LEFT JOIN public.profiles rp ON t.revoked_by = rp.id
    WHERE t.station_id = p_station_id;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public;
