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

    const callerClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user: callerUser }, error: callerError } = await callerClient.auth.getUser();
    if (callerError || !callerUser) {
      return json(401, { error: { code: "UNAUTHORIZED", message: "Invalid or expired session" } });
    }

    const { data: isPlatformAdmin, error: adminCheckError } = await callerClient.rpc("is_platform_admin");
    if (adminCheckError || isPlatformAdmin !== true) {
      return json(403, { error: { code: "NOT_PLATFORM_ADMIN", message: "Platform administrator required" } });
    }

    const body = await req.json().catch(() => ({}));
    const {
      name,
      code,
      timezone,
      locale,
      week_start,
      is_active,
      idempotency_key,
      initial_admin_user_id,
      initial_admin_email,
      initial_admin_first_name,
      initial_admin_last_name,
      initial_admin_phone,
    } = body;

    if (!name || !code) {
      return json(400, { error: { code: "VALIDATION_ERROR", message: "Station name and code are required" } });
    }

    const adminClient = createClient(supabaseUrl, supabaseServiceKey);
    let adminUserId: string | null = initial_admin_user_id || null;
    let temporaryPassword: string | null = null;
    let provisionedEmail: string | null = null;
    let isNewUser = false;

    const cleanEmail = (initial_admin_email || "").trim().toLowerCase();
    if (!adminUserId && cleanEmail) {
      const { data: lookup } = await callerClient.rpc("platform_lookup_user_by_email", {
        p_email: cleanEmail,
      });
      const lookupMap = lookup && typeof lookup === "object" ? lookup as { found?: boolean; user_id?: string } : null;
      if (lookupMap?.found && lookupMap.user_id) {
        adminUserId = lookupMap.user_id;
      } else {
        const firstName = (initial_admin_first_name || "").trim();
        const lastName = (initial_admin_last_name || "").trim();
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
          user_metadata: {
            first_name: firstName,
            last_name: lastName,
            phone: initial_admin_phone || null,
          },
        });
        if (createAuthError || !newAuthData.user) {
          return json(500, {
            error: { code: "AUTH_CREATION_FAILED", message: "Failed to create Station Manager account" },
          });
        }
        createdAuthUserId = newAuthData.user.id;
        adminUserId = createdAuthUserId;
        provisionedEmail = cleanEmail;
        isNewUser = true;

        const { error: profileError } = await adminClient.from("profiles").upsert({
          id: adminUserId,
          first_name: firstName,
          last_name: lastName,
          phone: (initial_admin_phone || "").trim() || null,
          preferred_locale: locale === "en" ? "en" : "he",
          updated_at: new Date().toISOString(),
        });
        if (profileError) {
          await adminClient.auth.admin.deleteUser(adminUserId);
          createdAuthUserId = null;
          throw profileError;
        }
      }
    }

    const { data: stationResult, error: rpcError } = await callerClient.rpc("platform_create_station", {
      p_name: String(name).trim(),
      p_code: String(code).trim(),
      p_timezone: timezone || "Asia/Jerusalem",
      p_locale: locale || "he",
      p_week_start: typeof week_start === "number" ? week_start : 0,
      p_is_active: is_active !== false,
      p_initial_admin_user_id: adminUserId,
      p_idempotency_key: idempotency_key || null,
    });

    if (rpcError) {
      if (createdAuthUserId) {
        await adminClient.auth.admin.deleteUser(createdAuthUserId);
      }
      const codeHint = (rpcError as { code?: string }).code || "STATION_PROVISIONING_FAILED";
      const message = rpcError.message || "Station provisioning failed";
      const status = codeHint === "P00106" || message.toLowerCase().includes("already exists") ? 409 : 400;
      return json(status, { error: { code: codeHint, message } });
    }

    return json(isNewUser ? 201 : 200, {
      ...stationResult,
      initial_admin_user_id: adminUserId,
      is_new_user: isNewUser,
      email: provisionedEmail,
      temporary_password: temporaryPassword,
    });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : "Internal server error";
    if (createdAuthUserId && supabaseUrl && supabaseServiceKey) {
      try {
        const adminClient = createClient(supabaseUrl, supabaseServiceKey);
        await adminClient.auth.admin.deleteUser(createdAuthUserId);
      } catch (_) {
        // Compensating cleanup best-effort; do not leak internals.
      }
    }
    return json(500, { error: { code: "STATION_PROVISIONING_FAILED", message: "Station provisioning failed" } });
  }
});
