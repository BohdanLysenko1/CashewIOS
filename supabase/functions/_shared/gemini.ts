// Shared Gemini API helper for edge functions.

export const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-3-flash-preview";

interface GeminiOptions {
  /// Optional generationConfig overrides. Defaults to JSON-only output, 4096 tokens, minimal thinking.
  generationConfig?: Record<string, unknown>;
}

/// Calls the Gemini generateContent endpoint and returns the parsed JSON object.
///
/// Throws on:
/// - missing GEMINI_API_KEY
/// - non-200 Gemini response
/// - empty response payload
/// - response not parseable as JSON (includes a snippet of the raw text for diagnostics)
export async function callGemini(
  prompt: string,
  options: GeminiOptions = {},
): Promise<any> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) throw new Error("GEMINI_API_KEY not configured in Vault");

  const generationConfig = options.generationConfig ?? {
    responseMimeType: "application/json",
    maxOutputTokens: 4096,
    thinkingConfig: { thinkingLevel: "minimal" },
  };

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${apiKey}`;

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      generationConfig,
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Gemini API error ${res.status}: ${errText}`);
  }

  const data = await res.json();
  // Gemini 3 includes thought parts — grab the last non-thought text part.
  const parts = data?.candidates?.[0]?.content?.parts ?? [];
  const textPart = parts.filter((p: any) => !p.thought && p.text).pop();
  let rawText = textPart?.text ?? data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
  if (!rawText) throw new Error("Empty response from Gemini");

  // Some responses wrap JSON in markdown fences despite responseMimeType.
  rawText = rawText.replace(/```json\s*/i, "").replace(/```\s*$/i, "").trim();

  try {
    return JSON.parse(rawText);
  } catch (parseErr) {
    const detail = parseErr instanceof Error ? parseErr.message : String(parseErr);
    throw new Error(
      `Gemini returned non-JSON response: ${detail}. Snippet: ${rawText.slice(0, 200)}`,
    );
  }
}
