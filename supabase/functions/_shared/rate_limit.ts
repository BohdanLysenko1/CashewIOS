import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

/// Marker class so callers can map rate-limit denials to HTTP 429.
/// `retryAfterSeconds` is suitable for the `Retry-After` response header.
export class RateLimitError extends Error {
  constructor(message: string, public readonly retryAfterSeconds: number) {
    super(message);
    this.name = "RateLimitError";
  }
}

export interface RateLimitOptions {
  /// Max calls permitted per window. Default 10.
  maxPerWindow?: number;
  /// Window length in seconds. Default 3600 (1 hour).
  windowSeconds?: number;
}

/// Calls the `private.ai_rate_limit` RPC for the given user/function. If the
/// call is allowed, it is recorded in the log and this function returns. If
/// denied, throws `RateLimitError` carrying the seconds-until-next-allowed.
///
/// Infrastructure failures (RPC errors) are logged via `console.error` and
/// treated as "allowed" so a broken rate-limit table does not take down the
/// AI features. The Edge Function still benefits from the prompt caps and
/// auth check upstream.
export async function checkAIRateLimit(
  supabase: SupabaseClient,
  userId: string,
  functionName: string,
  options: RateLimitOptions = {},
): Promise<void> {
  const maxPerWindow = options.maxPerWindow ?? 10;
  const windowSeconds = options.windowSeconds ?? 3600;

  const { data, error } = await supabase.rpc("ai_rate_limit", {
    p_user_id: userId,
    p_function_name: functionName,
    p_max_per_window: maxPerWindow,
    p_window_seconds: windowSeconds,
  });

  if (error) {
    console.error(`[rate_limit] RPC failed for ${functionName}: ${error.message}`);
    return;
  }

  const retryAfter = typeof data === "number" ? data : 0;
  if (retryAfter > 0) {
    throw new RateLimitError(
      `Rate limit exceeded for ${functionName}. Try again in ${retryAfter} seconds.`,
      retryAfter,
    );
  }
}
