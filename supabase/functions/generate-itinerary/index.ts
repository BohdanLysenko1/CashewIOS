import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { CORS_HEADERS, jsonResponse } from "../_shared/cors.ts";
import { AuthError, verifyAuth } from "../_shared/auth.ts";
import { callGemini } from "../_shared/gemini.ts";
import {
  assertDate,
  assertNumber,
  assertString,
  assertStringArray,
} from "../_shared/validate.ts";

// ── Handler ──────────────────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  try {
    await verifyAuth(req);

    const body = await req.json();

    // ── Validate inputs ──────────────────────────────────────────────
    const destination = assertString(body.destination, "destination");
    const destinationLatitude = body.destinationLatitude != null
      ? assertNumber(body.destinationLatitude, "destinationLatitude")
      : null;
    const destinationLongitude = body.destinationLongitude != null
      ? assertNumber(body.destinationLongitude, "destinationLongitude")
      : null;
    const startDate = assertDate(body.startDate, "startDate");
    const endDate = assertDate(body.endDate, "endDate");
    if (startDate > endDate)
      throw new Error(`"startDate" must be on or before "endDate"`);
    const tripCurrency = assertString(body.tripCurrency, "tripCurrency");
    const budgetAllocation = assertNumber(body.budgetAllocation, "budgetAllocation");
    const interests = assertStringArray(body.interests, "interests");
    const existingActivityTitles = body.existingActivityTitles
      ? assertStringArray(body.existingActivityTitles, "existingActivityTitles")
      : [];
    const targetDate = body.targetDate ? assertDate(body.targetDate, "targetDate") : null;

    // Build a list of trip dates (or just the target date)
    let dates: string[];
    if (targetDate) {
      dates = [targetDate];
    } else {
      dates = [];
      const start = new Date(startDate);
      const end = new Date(endDate);
      for (
        const d = new Date(start);
        d <= end;
        d.setDate(d.getDate() + 1)
      ) {
        dates.push(d.toISOString().split("T")[0]);
      }
    }

    // NOTE: must mirror Swift's `ActivityCategory` enum raw values. If you add
    // a category here, also add it in Cashew/Core/Models/ActivityCategory.swift.
    const validCategories = [
      "flight",
      "train",
      "bus",
      "car",
      "ferry",
      "hotel",
      "restaurant",
      "museum",
      "tour",
      "beach",
      "hiking",
      "shopping",
      "nightlife",
      "activity",
      "other",
    ];

    const coordInfo =
      destinationLatitude != null && destinationLongitude != null
        ? ` (coordinates: ${destinationLatitude}, ${destinationLongitude})`
        : "";

    const alreadyPlanned =
      Array.isArray(existingActivityTitles) &&
      existingActivityTitles.length > 0
        ? existingActivityTitles.join(", ")
        : "none";

    const dayContext = targetDate
      ? `Generate activities for a SINGLE day (${targetDate}) of a trip to ${destination}${coordInfo}. This is a regeneration — create fresh, different suggestions.`
      : `Generate a detailed day-by-day itinerary for a trip to ${destination}${coordInfo}.`;

    const budgetContext = targetDate
      ? `Budget for this day: ${Math.round(budgetAllocation / dates.length)} ${tripCurrency} (from total ${budgetAllocation} ${tripCurrency})`
      : `Total budget allocation: ${budgetAllocation} ${tripCurrency}`;

    const prompt =
      `You are an expert travel itinerary planner. ${dayContext}

Trip dates: ${dates.join(", ")}
${budgetContext}
Traveler interests: ${(interests as string[]).join(", ")}
Activities already planned — do NOT duplicate these: ${alreadyPlanned}

Requirements:
1. Generate 3-5 activities per day, spread evenly across all trip dates.
2. Each activity MUST include accurate real-world GPS coordinates (latitude and longitude).
3. Within each day, order activities by geographic proximity to minimize travel between consecutive stops.
4. Assign realistic, non-overlapping start and end times (HH:MM format) for each activity within a day.
5. Keep the sum of all estimatedCost values within ${budgetAllocation} ${tripCurrency}.
6. For the "category" field use ONLY one of these exact strings: ${
        validCategories.join(", ")
      }.
7. Weight suggestions heavily toward the traveler's stated interests: ${
        (interests as string[]).join(", ")
      }.
8. Include a mix of free and paid activities.
9. Add a concise practical note per activity (e.g. booking tips, opening hours, best time to visit).

Return ONLY a valid JSON object with no markdown fences or extra text:
{
  "activities": [
    {
      "title": "string — specific place or activity name",
      "date": "YYYY-MM-DD",
      "startTime": "HH:MM",
      "endTime": "HH:MM",
      "location": "string — venue or place name",
      "address": "string — full street address",
      "notes": "string — practical tip",
      "category": "string — one of the valid categories above",
      "estimatedCost": number,
      "latitude": number,
      "longitude": number
    }
  ]
}`;

    const parsed = await callGemini(prompt, {
      generationConfig: {
        responseMimeType: "application/json",
        maxOutputTokens: 8192,
        thinkingConfig: { thinkingLevel: "minimal" },
      },
    });

    // Normalize activities to guarantee camelCase keys and correct types
    const activities = (parsed.activities ?? []).map((a: any) => ({
      title: String(a.title ?? ""),
      date: String(a.date ?? ""),
      startTime: a.startTime ?? a.start_time ?? null,
      endTime: a.endTime ?? a.end_time ?? null,
      location: String(a.location ?? ""),
      address: String(a.address ?? ""),
      notes: String(a.notes ?? ""),
      category: String(a.category ?? "activity"),
      estimatedCost: a.estimatedCost ?? a.estimated_cost ?? null,
      latitude: a.latitude != null ? Number(a.latitude) : null,
      longitude: a.longitude != null ? Number(a.longitude) : null,
    }));

    return jsonResponse({ activities });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    const status = err instanceof AuthError ? 401 : 500;
    return jsonResponse({ error: message }, status);
  }
});
