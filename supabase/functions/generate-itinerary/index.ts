import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const GEMINI_MODEL = "gemini-3-flash-preview";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  try {
    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) throw new Error("GEMINI_API_KEY not configured in Vault");

    const {
      destination,
      destinationLatitude,
      destinationLongitude,
      startDate,
      endDate,
      tripCurrency,
      budgetAllocation,
      interests,
      existingActivityTitles,
      targetDate,
    } = await req.json();

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

    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${apiKey}`;

    const geminiRes = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig: {
          responseMimeType: "application/json",
          maxOutputTokens: 8192,
          thinkingConfig: { thinkingLevel: "minimal" },
        },
      }),
    });

    if (!geminiRes.ok) {
      const errText = await geminiRes.text();
      throw new Error(`Gemini API error ${geminiRes.status}: ${errText}`);
    }

    const geminiData = await geminiRes.json();
    // Gemini 3 includes thought parts — grab the last non-thought text part
    const parts = geminiData?.candidates?.[0]?.content?.parts ?? [];
    const textPart = parts.filter((p: any) => !p.thought && p.text).pop();
    const rawText = textPart?.text;
    if (!rawText) throw new Error("Empty response from Gemini");

    const parsed = JSON.parse(rawText);

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

    return new Response(JSON.stringify({ activities }), {
      headers: { "Content-Type": "application/json", ...CORS_HEADERS },
    });
  } catch (err) {
    return new Response(
      JSON.stringify({
        error: err instanceof Error ? err.message : String(err),
      }),
      {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          ...CORS_HEADERS,
        },
      },
    );
  }
});
