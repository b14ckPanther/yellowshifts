-- Migration: 20260904000005_update_platform_schema_version_probe.sql
-- Description: Update get_platform_schema_version RPC with healthy status and timestamp

CREATE OR REPLACE FUNCTION public.get_platform_schema_version()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN jsonb_build_object(
        'schema_version', '20260904000005',
        'platform_version', '1.0.6',
        'min_compatible_client_version', '1.0.0',
        'migration_cutoff', '20260904000005',
        'status', 'HEALTHY',
        'nfc_only_attendance', true,
        'server_timestamp', now()
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_platform_schema_version() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_platform_schema_version() TO anon, authenticated, service_role;
