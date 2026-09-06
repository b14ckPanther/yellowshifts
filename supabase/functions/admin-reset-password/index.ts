import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function generateSecureTempPassword(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%&*";
  const array = new Uint8Array(12);
  crypto.getRandomValues(array);
  let result = "Ys#";
  for (let i = 0; i < 12; i++) {
    result += chars[array[i] % chars.length];
  }
  return result;
}

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

    const jwt = authHeader.replace(/^Bearer\s+/i, "");
    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    // Verify caller session using JWT token
    const { data: { user: callerUser }, error: callerError } = await adminClient.auth.getUser(jwt);
    if (callerError || !callerUser) {
      return new Response(
        JSON.stringify({ error: { code: "UNAUTHORIZED", message: "Invalid or expired session" } }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const body = await req.json().catch(() => ({}));
    const { station_id, user_id, new_password } = body;

    if (!station_id || !user_id) {
      return new Response(
        JSON.stringify({ error: { code: "VALIDATION_ERROR", message: "Missing station_id or user_id" } }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Verify caller is active ADMIN for station_id or a Platform Admin
    let isAuthorized = false;
    let actorScope = "STATION_ADMIN";

    // Check platform admin status
    const callerClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: platformAdminFlag } = await callerClient.rpc("is_platform_admin");
    if (platformAdminFlag === true) {
      isAuthorized = true;
      actorScope = "PLATFORM_ADMIN";
    }

    if (!isAuthorized) {
      const { data: adminMembership } = await adminClient
        .from("station_memberships")
        .select("id")
        .eq("station_id", station_id)
        .eq("user_id", callerUser.id)
        .eq("role", "ADMIN")
        .eq("status", "ACTIVE")
        .single();

      if (adminMembership) {
        isAuthorized = true;
      }
    }

    if (!isAuthorized) {
      return new Response(
        JSON.stringify({ error: { code: "FORBIDDEN", message: "Caller is not an active Administrator of this station" } }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Verify target user is member of station_id (unless caller is platform admin operating system)
    if (actorScope !== "PLATFORM_ADMIN") {
      const { data: targetMembership } = await adminClient
        .from("station_memberships")
        .select("id")
        .eq("station_id", station_id)
        .eq("user_id", user_id)
        .single();

      if (!targetMembership) {
        return new Response(
          JSON.stringify({ error: { code: "NOT_FOUND", message: "Target user is not a member of this station" } }),
          { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // 3. Determine password to set (custom password or generated secure temp password)
    let passwordToSet: string;
    if (typeof new_password === "string" && new_password.trim().length > 0) {
      const trimmed = new_password.trim();
      if (trimmed.length < 6) {
        return new Response(
          JSON.stringify({ error: { code: "VALIDATION_ERROR", message: "Password must be at least 6 characters" } }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      passwordToSet = trimmed;
    } else {
      passwordToSet = generateSecureTempPassword();
    }

    const { error: updateAuthError } = await adminClient.auth.admin.updateUserById(user_id, {
      password: passwordToSet,
    });

    if (updateAuthError) {
      return new Response(
        JSON.stringify({ error: { code: "UPDATE_FAILED", message: updateAuthError.message } }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. Revoke active sessions for target user
    await adminClient.auth.admin.signOut(user_id);

    // 5. Append audit logs
    await adminClient.from("audit_logs").insert([
      {
        station_id,
        actor_id: callerUser.id,
        action: "PASSWORD_RESET_INITIATED",
        target_type: "user",
        target_id: user_id,
        metadata: { initiated_by: actorScope },
      },
      {
        station_id,
        actor_id: callerUser.id,
        action: "CREDENTIAL_ISSUED",
        target_type: "auth_credential",
        target_id: user_id,
        metadata: { delivery: "ADMIN_SET_DIRECT" },
      },
    ]);

    return new Response(
      JSON.stringify({
        status: "PASSWORD_RESET",
        user_id,
        temporary_password: passwordToSet,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: { code: "INTERNAL_ERROR", message: err.message || "Internal error" } }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
