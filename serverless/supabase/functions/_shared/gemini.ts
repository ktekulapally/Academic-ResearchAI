/** Call Gemini generateContent and parse JSON response with auto-repair for truncated JSON. */
export async function geminiJson(
  prompt: string,
  apiKey: string,
  model = "gemini-2.0-flash"
): Promise<Record<string, unknown>> {
  const modelsToTry = [
    model,
    "gemini-1.5-flash",
    "gemini-2.0-flash-exp",
    "gemini-1.5-pro",
  ];

  let lastError = "";

  for (const m of modelsToTry) {
    try {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${m}:generateContent?key=${apiKey}`;
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ role: "user", parts: [{ text: prompt }] }],
          generationConfig: {
            responseMimeType: "application/json",
            temperature: 0.2,
            maxOutputTokens: 8192,
          },
        }),
      });

      if (!res.ok) {
        const errText = await res.text();
        lastError = `Model ${m} HTTP ${res.status}: ${errText}`;
        console.error(lastError);
        continue; // try next model
      }

      const data = await res.json();
      let text = data?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? "{}";

      if (text.startsWith("```json")) text = text.slice(7);
      if (text.startsWith("```")) text = text.slice(3);
      if (text.endsWith("```")) text = text.slice(0, -3);
      text = text.trim();

      // Attempt 1: Direct parse
      try {
        return JSON.parse(text);
      } catch (parseErr) {
        // Attempt 2: Auto-repair truncated JSON array (if cut off by maxOutputTokens)
        console.warn(`Model ${m} output truncated, attempting JSON repair…`);
        const repaired = tryRepairTruncatedJson(text);
        if (repaired) return repaired;
        throw parseErr;
      }
    } catch (err) {
      lastError = `Model ${m} execution error: ${err instanceof Error ? err.message : String(err)}`;
      console.error(lastError);
      continue;
    }
  }

  throw new Error(`All Gemini model attempts failed. Diagnostic: ${lastError}`);
}

/** Recovers valid questions from a truncated JSON payload */
function tryRepairTruncatedJson(raw: string): Record<string, unknown> | null {
  try {
    // Find the last complete question object "}" inside "questions": [ ... ]
    const qIndex = raw.lastIndexOf("}");
    if (qIndex !== -1) {
      const trimmed = raw.substring(0, qIndex + 1);
      // Close the array and object
      const candidate = `${trimmed}\n  ]\n}`;
      return JSON.parse(candidate);
    }
  } catch (_) {}
  return null;
}

