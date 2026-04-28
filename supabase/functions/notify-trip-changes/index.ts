import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create, getNumericDate } from "https://deno.land/x/djwt@v2.8/mod.ts";

// ─── Types ───────────────────────────────────────────────────────────────────

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  record: Record<string, unknown> | null;
  old_record: Record<string, unknown> | null;
  schema: string;
}

// ─── Main ─────────────────────────────────────────────────────────────────────

serve(async (req: Request) => {
  try {
    const payload: WebhookPayload = await req.json();

    // Only handle trip updates
    if (payload.type !== "UPDATE" || payload.table !== "trips") {
      return new Response("ok", { status: 200 });
    }

    const tripId = payload.record?.id as string;
    const ownerId = payload.record?.owner_id as string;

    if (!tripId || !ownerId) {
      return new Response("missing fields", { status: 200 });
    }

    // ── Supabase admin client ──────────────────────────────────────────────
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // ── Find who just updated the trip (latest activity log entry) ─────────
    const { data: activity } = await supabase
      .from("trip_activity_log")
      .select("user_id, summary")
      .eq("trip_id", tripId)
      .order("created_at", { ascending: false })
      .limit(1)
      .single();

    const editorId = (activity?.user_id as string) ?? null;
    const changeSummary = (activity?.summary as string) ?? "Trip was updated";

    // ── Collect all users who have access to this trip ─────────────────────
    const { data: shares } = await supabase
      .from("trip_shares")
      .select("user_id")
      .eq("trip_id", tripId)
      .not("accepted_at", "is", null);

    const accessUserIds = new Set<string>([ownerId]);
    (shares ?? []).forEach((s: { user_id: string }) => accessUserIds.add(s.user_id));

    // Remove the editor so they don't get notified about their own change
    if (editorId) accessUserIds.delete(editorId);

    if (accessUserIds.size === 0) {
      return new Response("no recipients", { status: 200 });
    }

    // ── Get editor's display name ──────────────────────────────────────────
    let editorName = "A collaborator";
    if (editorId) {
      const { data: user } = await supabase
        .from("users")
        .select("display_name")
        .eq("id", editorId)
        .single();
      if (user?.display_name) editorName = user.display_name;
    }

    // ── Collect device tokens ──────────────────────────────────────────────
    const { data: tokens } = await supabase
      .from("device_push_tokens")
      .select("token")
      .in("user_id", Array.from(accessUserIds))
      .eq("platform", "ios");

    if (!tokens || tokens.length === 0) {
      return new Response("no tokens", { status: 200 });
    }

    // ── Get trip name ──────────────────────────────────────────────────────
    const tripName = (payload.record?.name as string) ?? "your trip";

    // ── Build APNs JWT ─────────────────────────────────────────────────────
    const apnsKey = Deno.env.get("APNS_KEY");
    const apnsKeyId = Deno.env.get("APNS_KEY_ID");
    const apnsTeamId = Deno.env.get("APNS_TEAM_ID");
    const bundleId = Deno.env.get("APNS_BUNDLE_ID") ?? "com.bohdanlysenko.Cashew";

    if (!apnsKey || !apnsKeyId || !apnsTeamId) {
      console.error("Missing APNs configuration secrets");
      return new Response("missing apns config", { status: 500 });
    }

    // Import the ECDSA P-256 key from the .p8 PEM content
    const pemBody = apnsKey
      .replace("-----BEGIN PRIVATE KEY-----", "")
      .replace("-----END PRIVATE KEY-----", "")
      .replace(/\s/g, "");
    const keyData = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

    const cryptoKey = await crypto.subtle.importKey(
      "pkcs8",
      keyData,
      { name: "ECDSA", namedCurve: "P-256" },
      false,
      ["sign"]
    );

    const now = Math.floor(Date.now() / 1000);
    const jwtPayload = { iss: apnsTeamId, iat: now };
    const jwtHeader = { alg: "ES256" as const, kid: apnsKeyId };

    const apnsToken = await create(jwtHeader, jwtPayload, cryptoKey);

    // ── Send to each device token ──────────────────────────────────────────
    const apnsHost = "https://api.push.apple.com"; // use api.sandbox.push.apple.com for testing
    const notificationBody: Record<string, unknown> = {
      aps: {
        alert: {
          title: tripName,
          body: `${editorName}: ${changeSummary}`,
        },
        sound: "default",
        badge: 1,
        "content-available": 1,
      },
      type: "trip",
      tripId: tripId,
    };

    await Promise.allSettled(
      tokens.map(({ token }: { token: string }) =>
        fetch(`${apnsHost}/3/device/${token}`, {
          method: "POST",
          headers: {
            authorization: `bearer ${apnsToken}`,
            "apns-topic": bundleId,
            "apns-push-type": "alert",
            "apns-priority": "10",
            "content-type": "application/json",
          },
          body: JSON.stringify(notificationBody),
        })
      )
    );

    return new Response("sent", { status: 200 });
  } catch (err) {
    console.error("notify-trip-changes error:", err);
    return new Response("error", { status: 500 });
  }
});
