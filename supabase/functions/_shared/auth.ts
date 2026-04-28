import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

/// Marker class so callers can map auth failures to HTTP 401 instead of 500.
export class AuthError extends Error {}

/// Verifies the request carries a valid Supabase user JWT.
/// Throws `AuthError` for missing/invalid tokens, plain `Error` for misconfiguration.
export async function verifyAuth(req: Request): Promise<void> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) throw new AuthError("Missing Authorization header");

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    throw new Error("Supabase credentials not configured (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY)");
  }
  const supabase = createClient(supabaseUrl, serviceKey);

  const token = authHeader.replace("Bearer ", "");
  const { error } = await supabase.auth.getUser(token);
  if (error) throw new AuthError("Invalid or expired token");
}
