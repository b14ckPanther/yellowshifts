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
    const { station_id, first_name, last_name, email, phone, role, employee_code } = body;

    if (!station_id || !first_name || !last_name) {
      return new Response(
        JSON.stringify({ error: { code: "VALIDATION_ERROR", message: "Missing required fields" } }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const assignedRole = role || "EMPLOYEE";
    if (!["SHIFT_MANAGER", "EMPLOYEE"].includes(assignedRole)) {
      return new Response(
        JSON.stringify({
          error: {
            code: "P00105",
            message: "Station administrators may only create Employee or Shift Manager accounts",
          },
        }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Privileged service-role client for DB & Auth admin operations
    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    // 1. Verify caller is active ADMIN for target station
    const { data: adminMembership, error: adminCheckError } = await adminClient
      .from("station_memberships")
      .select("id, role, status")
      .eq("station_id", station_id)
      .eq("user_id", callerUser.id)
      .eq("role", "ADMIN")
      .eq("status", "ACTIVE")
      .single();

    if (adminCheckError || !adminMembership) {
      const { data: isPlatformAdmin } = await callerClient.rpc("is_platform_admin");
      if (isPlatformAdmin !== true) {
        return new Response(
          JSON.stringify({ error: { code: "FORBIDDEN", message: "Caller is not an active Administrator of this station" } }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // 2. Normalize phone and email
    const cleanEmail = (email || "").trim().toLowerCase();
    const cleanPhone = (phone || "").trim().replace(/[^\d+]/g, "");

    // 3. Check for existing user by email or phone
    let existingUserId: string | null = null;

    if (cleanEmail) {
      try {
        const { data: userList } = await adminClient.auth.admin.listUsers();
        const found = userList?.users?.find(
          (u: any) => u.email?.toLowerCase() === cleanEmail
        );
        if (found) existingUserId = found.id;
      } catch (_) {
        // Fallback to direct creation
      }
    }

    if (!existingUserId && cleanPhone) {
      const { data: profileByPhone } = await adminClient
        .from("profiles")
        .select("id")
        .eq("phone", cleanPhone)
        .maybeSingle();
      if (profileByPhone) existingUserId = profileByPhone.id;
    }

    // 4. If user already exists: attach station membership
    if (existingUserId) {
      // Check if membership already exists in this station
      const { data: existingMembership } = await adminClient
        .from("station_memberships")
        .select("id, status, role")
        .eq("station_id", station_id)
        .eq("user_id", existingUserId)
        .maybeSingle();

      if (existingMembership) {
        if (existingMembership.status === "ACTIVE") {
          return new Response(
            JSON.stringify({ error: { code: "DUPLICATE_MEMBERSHIP", message: "User is already an active member of this station" } }),
            { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        } else {
          // Reactivate existing membership with new role/code
          const { data: updatedMem, error: updateMemError } = await adminClient
            .from("station_memberships")
            .update({
              status: "ACTIVE",
              role: assignedRole,
              employee_code: employee_code || null,
              updated_at: new Date().toISOString(),
            })
            .eq("id", existingMembership.id)
            .select()
            .single();

          if (updateMemError) throw updateMemError;

          // Audit log
          await adminClient.from("audit_logs").insert({
            station_id,
            actor_id: callerUser.id,
            action: "MEMBERSHIP_REACTIVATED",
            target_type: "station_membership",
            target_id: existingMembership.id,
            metadata: { user_id: existingUserId, role: assignedRole, reason: "Re-provisioned by Admin" },
          });

          return new Response(
            JSON.stringify({
              status: "EXISTING_USER_REACTIVATED",
              user_id: existingUserId,
              membership_id: updatedMem.id,
              is_new_user: false,
            }),
            { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
      }

      // Create new membership in target station
      const { data: newMem, error: newMemError } = await adminClient
        .from("station_memberships")
        .insert({
          station_id,
          user_id: existingUserId,
          role: assignedRole,
          status: "ACTIVE",
          employee_code: employee_code || null,
        })
        .select()
        .single();

      if (newMemError) throw newMemError;

      // Audit log
      await adminClient.from("audit_logs").insert({
        station_id,
        actor_id: callerUser.id,
        action: "MEMBERSHIP_CREATED",
        target_type: "station_membership",
        target_id: newMem.id,
        metadata: { user_id: existingUserId, role: assignedRole, type: "MULTI_STATION_ADD" },
      });

      return new Response(
        JSON.stringify({
          status: "EXISTING_USER_ASSIGNED",
          user_id: existingUserId,
          membership_id: newMem.id,
          is_new_user: false,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 5. New User Flow: Provision Auth User + Profile + Membership
    const targetEmail = cleanEmail || `${cleanPhone || crypto.randomUUID().slice(0, 8)}@station.yellowshifts.local`;
    const tempPassword = generateSecureTempPassword();

    const { data: newAuthData, error: createAuthError } = await adminClient.auth.admin.createUser({
      email: targetEmail,
      password: tempPassword,
      email_confirm: true,
      user_metadata: {
        first_name: first_name.trim(),
        last_name: last_name.trim(),
        phone: cleanPhone || null,
      },
    });

    if (createAuthError || !newAuthData.user) {
      return new Response(
        JSON.stringify({ error: { code: "AUTH_CREATION_FAILED", message: createAuthError?.message || "Failed to create user account" } }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const newUserId = newAuthData.user.id;

    // Upsert Profile
    const { error: profileError } = await adminClient.from("profiles").upsert({
      id: newUserId,
      first_name: first_name.trim(),
      last_name: last_name.trim(),
      phone: cleanPhone || null,
      preferred_locale: "he",
      updated_at: new Date().toISOString(),
    });

    if (profileError) {
      // Rollback Auth user if profile failed
      await adminClient.auth.admin.deleteUser(newUserId);
      throw profileError;
    }

    // Create Station Membership
    const { data: createdMem, error: memError } = await adminClient
      .from("station_memberships")
      .insert({
        station_id,
        user_id: newUserId,
        role: assignedRole,
        status: "ACTIVE",
        employee_code: employee_code || null,
      })
      .select()
      .single();

    if (memError) {
      await adminClient.auth.admin.deleteUser(newUserId);
      throw memError;
    }

    // Audit logs (No passwords or secrets recorded in audit metadata)
    await adminClient.from("audit_logs").insert([
      {
        station_id,
        actor_id: callerUser.id,
        action: "EMPLOYEE_ACCOUNT_CREATED",
        target_type: "profile",
        target_id: newUserId,
        metadata: { first_name: first_name.trim(), last_name: last_name.trim(), role: assignedRole },
      },
      {
        station_id,
        actor_id: callerUser.id,
        action: "MEMBERSHIP_CREATED",
        target_type: "station_membership",
        target_id: createdMem.id,
        metadata: { role: assignedRole, status: "ACTIVE" },
      },
      {
        station_id,
        actor_id: callerUser.id,
        action: "TEMPORARY_CREDENTIAL_ISSUED",
        target_type: "auth_credential",
        target_id: newUserId,
        metadata: { delivery: "ONE_TIME_ADMIN_DISPLAY" },
      },
    ]);

    return new Response(
      JSON.stringify({
        status: "NEW_USER_CREATED",
        user_id: newUserId,
        membership_id: createdMem.id,
        email: targetEmail,
        temporary_password: tempPassword,
        is_new_user: true,
      }),
      { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: { code: "INTERNAL_ERROR", message: err.message || "Internal server error" } }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
