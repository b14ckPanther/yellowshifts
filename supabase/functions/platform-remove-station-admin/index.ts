import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json(401, { error: { code: "UNAUTHORIZED", message: "Missing Authorization header" } });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    const jwt = authHeader.replace(/^Bearer\s+/i, "");
    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    const { data: { user: callerUser }, error: callerError } = await adminClient.auth.getUser(jwt);
    if (callerError || !callerUser) {
      return json(401, { error: { code: "UNAUTHORIZED", message: "Invalid or expired session" } });
    }

    const callerClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: isPlatformAdmin, error: adminCheckError } = await callerClient.rpc("is_platform_admin");
    if (adminCheckError || isPlatformAdmin !== true) {
      return json(403, { error: { code: "NOT_PLATFORM_ADMIN", message: "Platform administrator required" } });
    }

    const body = await req.json().catch(() => ({}));
    const { station_id, user_id, reason, demote_to, deactivate } = body;

    if (!station_id || !user_id || !reason) {
      return json(400, {
        error: { code: "VALIDATION_ERROR", message: "station_id, user_id, and reason are required" },
      });
    }

    const { data, error } = await callerClient.rpc("platform_remove_station_admin", {
      p_station_id: station_id,
      p_user_id: user_id,
      p_reason: String(reason),
      p_demote_to: demote_to === "SHIFT_MANAGER" ? "SHIFT_MANAGER" : "EMPLOYEE",
      p_deactivate: deactivate === true,
    });

    if (error) {
      const code = error.code || "REMOVE_FAILED";
      const status = code === "P0001" ? 409 : 400;
      return json(status, { error: { code, message: error.message } });
    }

    return json(200, data);
  } catch (_) {
    return json(500, { error: { code: "INTERNAL_ERROR", message: "Station Manager removal failed" } });
  }
});
