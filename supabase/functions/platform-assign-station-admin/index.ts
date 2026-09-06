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

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  let createdAuthUserId: string | null = null;

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json(401, { error: { code: "UNAUTHORIZED", message: "Missing Authorization header" } });
    }

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
    const {
      station_id,
      user_id,
      email,
      first_name,
      last_name,
      phone,
      replace_user_id,
      reason,
    } = body;

    if (!station_id) {
      return json(400, { error: { code: "VALIDATION_ERROR", message: "station_id is required" } });
    }

    const adminClient = createClient(supabaseUrl, supabaseServiceKey);
    let targetUserId: string | null = user_id || null;
    let temporaryPassword: string | null = null;
    let isNewUser = false;
    const cleanEmail = (email || "").trim().toLowerCase();

    if (!targetUserId && cleanEmail) {
      const { data: lookup } = await callerClient.rpc("platform_lookup_user_by_email", {
        p_email: cleanEmail,
      });
      if (lookup?.found && lookup.user_id) {
        targetUserId = lookup.user_id;
      } else {
        const firstName = (first_name || "").trim();
        const lastName = (last_name || "").trim();
        if (!firstName || !lastName) {
          return json(400, {
            error: { code: "VALIDATION_ERROR", message: "First and last name are required to create a Station Manager" },
          });
        }
        temporaryPassword = generateSecureTempPassword();
        const { data: newAuthData, error: createAuthError } = await adminClient.auth.admin.createUser({
          email: cleanEmail,
          password: temporaryPassword,
          email_confirm: true,
          user_metadata: { first_name: firstName, last_name: lastName, phone: phone || null },
        });
        if (createAuthError || !newAuthData.user) {
          return json(500, { error: { code: "AUTH_CREATION_FAILED", message: "Failed to create Station Manager account" } });
        }
        createdAuthUserId = newAuthData.user.id;
        targetUserId = createdAuthUserId;
        isNewUser = true;
        const { error: profileError } = await adminClient.from("profiles").upsert({
          id: targetUserId,
          first_name: firstName,
          last_name: lastName,
          phone: (phone || "").trim() || null,
          preferred_locale: "he",
          updated_at: new Date().toISOString(),
        });
        if (profileError) {
          await adminClient.auth.admin.deleteUser(targetUserId);
          createdAuthUserId = null;
          throw profileError;
        }
      }
    }

    if (!targetUserId) {
      return json(400, { error: { code: "VALIDATION_ERROR", message: "user_id or email is required" } });
    }

    if (replace_user_id) {
      const { data: replaceResult, error: replaceError } = await callerClient.rpc("platform_replace_station_admin", {
        p_station_id: station_id,
        p_outgoing_user_id: replace_user_id,
        p_incoming_user_id: targetUserId,
        p_reason: reason || "Station Manager replacement",
      });
      if (replaceError) {
        if (createdAuthUserId) await adminClient.auth.admin.deleteUser(createdAuthUserId);
        return json(400, { error: { code: replaceError.code || "REPLACE_FAILED", message: replaceError.message } });
      }
      return json(isNewUser ? 201 : 200, {
        ...replaceResult,
        is_new_user: isNewUser,
        email: cleanEmail || null,
        temporary_password: temporaryPassword,
      });
    }

    const { data: assignResult, error: assignError } = await callerClient.rpc("platform_assign_station_admin", {
      p_station_id: station_id,
      p_user_id: targetUserId,
    });
    if (assignError) {
      if (createdAuthUserId) await adminClient.auth.admin.deleteUser(createdAuthUserId);
      return json(400, { error: { code: assignError.code || "ASSIGN_FAILED", message: assignError.message } });
    }

    return json(isNewUser ? 201 : 200, {
      ...assignResult,
      is_new_user: isNewUser,
      email: cleanEmail || null,
      temporary_password: temporaryPassword,
    });
  } catch (err: unknown) {
    if (createdAuthUserId && supabaseUrl && supabaseServiceKey) {
      try {
        const adminClient = createClient(supabaseUrl, supabaseServiceKey);
        await adminClient.auth.admin.deleteUser(createdAuthUserId);
      } catch (_) {
        // best-effort compensation
      }
    }
    return json(500, { error: { code: "INTERNAL_ERROR", message: "Station Manager assignment failed" } });
  }
});
