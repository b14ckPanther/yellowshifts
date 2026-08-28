import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: { code: "UNAUTHORIZED", message: "Missing Authorization header" } }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    const callerClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user: callerUser }, error: callerError } = await callerClient.auth.getUser();
    if (callerError || !callerUser) {
      return new Response(
        JSON.stringify({ error: { code: "UNAUTHORIZED", message: "Invalid session" } }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const body = await req.json().catch(() => ({}));
    const { station_id, user_id } = body;

    if (!station_id || !user_id) {
      return new Response(
        JSON.stringify({ error: { code: "VALIDATION_ERROR", message: "Missing station_id or user_id" } }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    // Verify caller is active ADMIN for station_id
    const { data: adminMembership } = await adminClient
      .from("station_memberships")
      .select("id")
      .eq("station_id", station_id)
      .eq("user_id", callerUser.id)
      .eq("role", "ADMIN")
      .eq("status", "ACTIVE")
      .single();

    if (!adminMembership) {
      return new Response(
        JSON.stringify({ error: { code: "FORBIDDEN", message: "Caller is not an active Admin of this station" } }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Revoke sessions via Supabase Auth Admin API
    await adminClient.auth.admin.signOut(user_id);

    // Append audit log
    await adminClient.from("audit_logs").insert({
      station_id,
      actor_id: callerUser.id,
      action: "SESSIONS_REVOKED",
      target_type: "user",
      target_id: user_id,
      metadata: { initiated_by: "STATION_ADMIN" },
    });

    return new Response(
      JSON.stringify({ status: "SESSIONS_REVOKED", user_id }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: { code: "INTERNAL_ERROR", message: err.message || "Internal error" } }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
