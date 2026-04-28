import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { CORS_HEADERS, jsonResponse } from "../_shared/cors.ts";
import { AuthError, verifyAuth } from "../_shared/auth.ts";
import { callGemini } from "../_shared/gemini.ts";
import { assertNumber, assertString, assertStringArray } from "../_shared/validate.ts";

// NOTE: must mirror Swift's `PackingCategory` enum raw values. If you add a
// category here, also add it in Cashew/Core/Models/PackingCategory.swift.
const validCategories = [
  "clothing", "toiletries", "electronics", "documents",
  "medicine", "accessories", "entertainment", "snacks", "other",
];

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
    const tripDurationDays = assertNumber(body.tripDurationDays, "tripDurationDays");
    const activities = body.activities ? assertStringArray(body.activities, "activities") : [];
    const interests = body.interests ? assertStringArray(body.interests, "interests") : [];
    const weatherSummary = body.weatherSummary
      ? assertString(body.weatherSummary, "weatherSummary")
      : null;
    const travelerCount = body.travelerCount ? assertNumber(body.travelerCount, "travelerCount") : 1;
    const preferences = body.preferences ? assertStringArray(body.preferences, "preferences") : [];

    // ── Build Prompt ─────────────────────────────────────────────────
    const weatherContext = weatherSummary
      ? `Expected weather: ${weatherSummary}.`
      : "Weather data not available — pack for typical conditions at the destination.";

    const activitiesContext = activities.length > 0
      ? `Planned activities: ${activities.join(", ")}.`
      : "No specific activities planned.";

    const interestsContext = interests.length > 0
      ? `Traveler interests: ${interests.join(", ")}.`
      : "";

    const preferencesContext = preferences.length > 0
      ? `Packing preferences: ${preferences.join(", ")}.`
      : "";

    const prompt =
      `You are an expert travel packing assistant.

Destination: ${destination}
Trip duration: ${tripDurationDays} days
Number of travelers: ${travelerCount}
${weatherContext}
${activitiesContext}
${interestsContext}
${preferencesContext}

Requirements:
1. Generate a comprehensive packing list organized by category.
2. For the "category" field use ONLY one of these exact strings: ${validCategories.join(", ")}.
3. Each item must have a name, suggested quantity, and whether it's essential (must-pack).
4. Weight suggestions toward the destination, weather, trip duration, and planned activities.
5. Include practical items people commonly forget.
6. Keep quantities realistic for ${tripDurationDays} days and ${travelerCount} traveler(s).

Return ONLY a valid JSON object with no markdown fences or extra text:
{
  "categories": [
    {
      "category": "string — one of the valid categories above",
      "items": [
        {
          "name": "string — item name",
          "quantity": number,
          "essential": boolean
        }
      ]
    }
  ]
}`;

    const parsed = await callGemini(prompt, {
      generationConfig: { temperature: 0.7, maxOutputTokens: 4096 },
    });

    const categories = (parsed.categories ?? []).map((cat: any) => ({
      category: validCategories.includes(cat.category) ? cat.category : "other",
      items: (cat.items ?? []).map((item: any) => ({
        name: String(item.name ?? "Item"),
        quantity: Math.max(1, Number(item.quantity) || 1),
        essential: Boolean(item.essential),
      })),
    }));

    return jsonResponse({ categories });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    const status = err instanceof AuthError ? 401 : 500;
    return jsonResponse({ error: message }, status);
  }
});
