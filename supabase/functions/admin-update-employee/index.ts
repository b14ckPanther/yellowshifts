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

    // 1. Verify caller session with anon client + JWT
    const callerClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user: callerUser }, error: callerError } = await callerClient.auth.getUser();
    if (callerError || !callerUser) {
      return new Response(
        JSON.stringify({ error: { code: "UNAUTHORIZED", message: "Invalid or expired session" } }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const body = await req.json().catch(() => ({}));
    const {
      station_id,
      user_id,
      membership_id,
      first_name,
      last_name,
      email,
      phone,
      preferred_locale,
      employee_code,
    } = body;
    let { role, status } = body;

    if (!station_id || !user_id || !first_name || !last_name) {
      return new Response(
        JSON.stringify({ error: { code: "VALIDATION_ERROR", message: "Missing required fields" } }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Privileged admin client for admin verification & mutations
    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    // Verify caller is active ADMIN for station_id, or a Platform Admin.
    const { data: adminMembership, error: adminCheckError } = await adminClient
      .from("station_memberships")
      .select("id, role, status")
      .eq("station_id", station_id)
      .eq("user_id", callerUser.id)
      .eq("role", "ADMIN")
      .eq("status", "ACTIVE")
      .single();

    const { data: platformAdminFlag } = await callerClient.rpc("is_platform_admin");
    const isPlatformAdmin = platformAdminFlag === true;

    if ((adminCheckError || !adminMembership) && !isPlatformAdmin) {
      return new Response(
        JSON.stringify({ error: { code: "FORBIDDEN", message: "Caller is not an active Administrator of this station" } }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Verify target user is a member of station_id
    const { data: targetMembership, error: targetCheckError } = await adminClient
      .from("station_memberships")
      .select("id, role, status, employee_code")
      .eq("station_id", station_id)
      .eq("user_id", user_id)
      .single();

    if (targetCheckError || !targetMembership) {
      return new Response(
        JSON.stringify({ error: { code: "NOT_FOUND", message: "Target user is not a member of this station" } }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // P00105: station admins may not grant/revoke ADMIN. Profile fields on an
    // existing ADMIN (including self) remain allowed.
    if (!isPlatformAdmin) {
      if (targetMembership.role === "ADMIN") {
        if ((role && role !== "ADMIN") || (status && status !== targetMembership.status)) {
          return new Response(
            JSON.stringify({
              error: {
                code: "P00105",
                message: "Station administrators cannot grant or revoke Station Manager privileges",
              },
            }),
            { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
        role = undefined;
        status = undefined;
      } else if (role === "ADMIN") {
        return new Response(
          JSON.stringify({
            error: {
              code: "P00105",
              message: "Station administrators cannot grant or revoke Station Manager privileges",
            },
          }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      } else if (role && !["EMPLOYEE", "SHIFT_MANAGER"].includes(role)) {
        return new Response(
          JSON.stringify({ error: { code: "VALIDATION_ERROR", message: "Invalid role specified" } }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // 3. Handle Email Update if specified and changed
    const cleanEmail = (email || "").trim().toLowerCase();
    if (cleanEmail) {
      // Check current auth user email
      const { data: targetAuthUser, error: authGetError } = await adminClient.auth.admin.getUserById(user_id);
      if (!authGetError && targetAuthUser?.user) {
        const currentEmail = (targetAuthUser.user.email || "").toLowerCase();
        if (currentEmail !== cleanEmail) {
          // Update email via Supabase Auth Admin API
          const { error: emailUpdateError } = await adminClient.auth.admin.updateUserById(user_id, {
            email: cleanEmail,
            email_confirm: true,
          });

          if (emailUpdateError) {
            return new Response(
              JSON.stringify({ error: { code: "EMAIL_UPDATE_FAILED", message: emailUpdateError.message } }),
              { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
          }

          // Audit log for email update
          await adminClient.from("audit_logs").insert({
            station_id,
            actor_id: callerUser.id,
            action: "EMPLOYEE_EMAIL_UPDATED",
            target_type: "user",
            target_id: user_id,
            metadata: { old_email: currentEmail, new_email: cleanEmail },
          });
        }
      }
    }

    // 4. Update Profile via admin_update_employee_profile RPC (or direct authenticated RPC)
    const { data: profileResult, error: profileError } = await callerClient.rpc(
      "admin_update_employee_profile",
      {
        p_station_id: station_id,
        p_target_user_id: user_id,
        p_first_name: first_name.trim(),
        p_last_name: last_name.trim(),
        p_phone: phone?.trim() || null,
        p_preferred_locale: preferred_locale || "he",
      }
    );

    if (profileError) {
      return new Response(
        JSON.stringify({ error: { code: profileError.code || "PROFILE_UPDATE_FAILED", message: profileError.message } }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 5. Update Station Membership (role, status, employee_code) if membership fields provided
    const targetMembershipId = membership_id || targetMembership.id;
    if (role && status) {
      const { data: membershipResult, error: membershipError } = await callerClient.rpc(
        "admin_update_membership",
        {
          p_station_id: station_id,
          p_membership_id: targetMembershipId,
          p_role: role,
          p_status: status,
          p_employee_code: employee_code?.trim() || null,
        }
      );

      if (membershipError) {
        return new Response(
          JSON.stringify({ error: { code: membershipError.code || "MEMBERSHIP_UPDATE_FAILED", message: membershipError.message } }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        user_id,
        station_id,
        first_name: first_name.trim(),
        last_name: last_name.trim(),
        email: cleanEmail || null,
        phone: profileResult?.phone,
        preferred_locale: preferred_locale || "he",
        role: role || targetMembership.role,
        status: status || targetMembership.status,
        employee_code: employee_code?.trim() || targetMembership.employee_code,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: { code: "INTERNAL_ERROR", message: err.message || "Internal server error" } }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
