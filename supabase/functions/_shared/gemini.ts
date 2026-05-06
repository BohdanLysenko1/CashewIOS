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
/// - non-200 Gemini response (raw upstream body is logged via console.error;
///   the thrown error message is generic to avoid leaking upstream details to clients)
/// - empty response payload
/// - response not parseable as JSON
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

  // Pass the API key via the x-goog-api-key header rather than the URL query
  // string, so it never appears in URLs that may be captured by network errors,
  // proxy logs, or stack traces.
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": apiKey,
    },
    body: JSON.stringify({
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      generationConfig,
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    console.error(`[gemini] Upstream error ${res.status}: ${errText}`);
    throw new Error(`Gemini request failed (status ${res.status})`);
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
    console.error(`[gemini] Non-JSON response: ${detail}. Raw text: ${rawText}`);
    throw new Error("Gemini returned non-JSON response");
  }
}
