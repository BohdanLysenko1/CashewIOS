import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { CORS_HEADERS, jsonResponse } from "../_shared/cors.ts";
import { AuthError, verifyAuth } from "../_shared/auth.ts";
import { callGemini } from "../_shared/gemini.ts";
import { assertNumber, assertString } from "../_shared/validate.ts";

const VALID_TONES = ["warm", "poetic", "playful", "concise"] as const;
type Tone = typeof VALID_TONES[number];

const TONE_INSTRUCTIONS: Record<Tone, string> = {
  warm: "Write with warmth and nostalgia, like a friend recounting the trip over coffee. Use gentle, reflective language.",
  poetic: "Write lyrically, with vivid sensory imagery and rhythm. Favor evocative verbs and unexpected metaphors, but stay grounded in the actual events.",
  playful: "Write with light humor, charm, and a conversational spark. Short punchy sentences are welcome.",
  concise: "Write tightly and efficiently. Favor declarative sentences. No filler, no flourishes — every line should earn its place.",
};

// ── Handler ──────────────────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  try {
    await verifyAuth(req);

    const body = await req.json();

    // ── Validate inputs ──────────────────────────────────────────────
    const tripName = assertString(body.tripName, "tripName");
    const destination = assertString(body.destination, "destination");
    const startDate = assertString(body.startDate, "startDate");
    const endDate = assertString(body.endDate, "endDate");
    const currency = assertString(body.currency, "currency");
    const totalBudget = body.totalBudget != null ? assertNumber(body.totalBudget, "totalBudget") : null;
    const totalSpent = body.totalSpent != null ? assertNumber(body.totalSpent, "totalSpent") : null;

    const toneRaw = typeof body.tone === "string" ? body.tone : "warm";
    const tone: Tone = (VALID_TONES as readonly string[]).includes(toneRaw)
      ? (toneRaw as Tone)
      : "warm";

    const notes = typeof body.notes === "string" ? body.notes.trim() : "";
    const accommodationName = typeof body.accommodationName === "string" ? body.accommodationName.trim() : "";
    const accommodationAddress = typeof body.accommodationAddress === "string" ? body.accommodationAddress.trim() : "";
    const transportationType = typeof body.transportationType === "string" ? body.transportationType.trim() : "";
    const transportationDetails = typeof body.transportationDetails === "string" ? body.transportationDetails.trim() : "";

    const activities = Array.isArray(body.activities) ? body.activities : [];
    const expenses = Array.isArray(body.expenses) ? body.expenses : [];

    // ── Build Prompt ─────────────────────────────────────────────────
    const activitiesText = activities.length > 0
      ? activities.map((a: any) => {
          const parts: string[] = [`- ${a.title}`];
          parts.push(`date: ${a.date}`);
          if (a.startTime) parts.push(`time: ${a.startTime}${a.endTime ? `–${a.endTime}` : ""}`);
          parts.push(`category: ${a.category}`);
          if (a.location) parts.push(`at ${a.location}`);
          if (a.address) parts.push(`(${a.address})`);
          if (a.estimatedCost != null) parts.push(`~${a.estimatedCost} ${currency}`);
          if (a.notes) parts.push(`note: "${a.notes}"`);
          return parts.join(" · ");
        }).join("\n")
      : "No activities recorded.";

    const expensesText = expenses.length > 0
      ? expenses.map((e: any) => {
          const parts: string[] = [`- ${e.title}: ${e.amount} ${currency} (${e.category})`];
          if (e.date) parts.push(`on ${e.date}`);
          if (e.notes) parts.push(`note: "${e.notes}"`);
          return parts.join(" · ");
        }).join("\n")
      : "No expenses recorded.";

    const budgetText = totalBudget != null
      ? `Budget: ${totalBudget} ${currency}. Total spent: ${totalSpent ?? 0} ${currency}.`
      : "No budget set.";

    const tripNotesText = notes
      ? `Traveler's own notes:\n${notes}`
      : "";

    const stayText = accommodationName || accommodationAddress
      ? `Stayed at: ${[accommodationName, accommodationAddress].filter(Boolean).join(" — ")}`
      : "";

    const transportText = transportationType || transportationDetails
      ? `Transport: ${[transportationType, transportationDetails].filter(Boolean).join(" — ")}`
      : "";

    const contextBlock = [tripNotesText, stayText, transportText].filter(Boolean).join("\n\n");

    const prompt =
      `You are a creative travel writer. ${TONE_INSTRUCTIONS[tone]}

Use ONLY the trip data provided below. Do not invent activities, places, people, or details that are not in the inputs. If a section has no relevant data, write something brief and honest rather than filling it with fiction.

Trip: "${tripName}"
Destination: ${destination}
Dates: ${startDate} to ${endDate}
${budgetText}
${contextBlock ? `\n${contextBlock}\n` : ""}
Activities (in chronological order where times are given):
${activitiesText}

Expenses:
${expensesText}

Write a trip journal with the following sections:
1. **overview**: A 3-4 sentence narrative opener. Weave in the destination, the traveler's notes (if provided), and a sense of the trip's arc. No generic travel-brochure phrases.
2. **highlights**: 3-5 memorable highlights, each a single vivid sentence. Reference specific activity titles or locations from the data when it makes the sentence land.
3. **dailyRecap**: One entry per day that has at least one activity. Each entry is { date, summary } where summary is 1-2 sentences referencing the actual activities of that day. Omit days with no activities entirely.
4. **budgetRecap**: { totalBudget, totalSpent, currency, verdict }. The verdict is a single short sentence appropriate to the numbers (e.g. "Came in well under budget." or "A little over, but every peso had a story."). If there is no budget, set totalBudget/totalSpent to null and verdict to a brief phrase about the trip's value.
5. **funFacts**: 2-3 short observations grounded in the actual data (counts, categories, standouts). Examples: "You visited 4 museums in 3 days.", "Food was the biggest expense category." Do not invent statistics.

Return ONLY a JSON object matching this shape exactly, with no markdown fences or commentary:
{
  "overview": "string",
  "highlights": ["string"],
  "dailyRecap": [{ "date": "YYYY-MM-DD", "summary": "string" }],
  "budgetRecap": {
    "totalBudget": number | null,
    "totalSpent": number | null,
    "currency": "string",
    "verdict": "string"
  },
  "funFacts": ["string"]
}`;

    const parsed = await callGemini(prompt);

    return jsonResponse(parsed);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    const status = err instanceof AuthError ? 401 : 500;
    return jsonResponse({ error: message }, status);
  }
});
