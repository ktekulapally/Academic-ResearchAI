/** Call Gemini generateContent with dynamic model discovery, JSON repair & diagnostics. */
export async function geminiJson(
  prompt: string,
  apiKey: string,
  preferredModel = "gemini-2.0-flash"
): Promise<Record<string, unknown>> {
  // 1. Discover available models for this specific API key
  let availableModels: string[] = [];
  try {
    const listRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`
    );
    if (listRes.ok) {
      const listData = await listRes.json();
      if (Array.isArray(listData.models)) {
        availableModels = listData.models
          .filter((m: any) =>
            Array.isArray(m.supportedGenerationMethods) &&
            m.supportedGenerationMethods.includes("generateContent")
          )
          .map((m: any) => String(m.name).replace(/^models\//, ""));
      }
    } else {
      const listErr = await listRes.text();
      console.warn(`Models list endpoint returned HTTP ${listRes.status}: ${listErr}`);
    }
  } catch (e) {
    console.warn(`Failed to query models list: ${e}`);
  }

  // Fallback candidates if discovery was empty
  const fallbackModels = [
    preferredModel,
    "gemini-2.0-flash",
    "gemini-1.5-flash",
    "gemini-1.5-flash-latest",
    "gemini-1.5-flash-001",
    "gemini-1.5-flash-002",
    "gemini-2.0-flash-exp",
    "gemini-pro",
  ];

  // Prioritize flash models from discovered list, then fallback models
  const candidates = Array.from(
    new Set([
      ...availableModels.filter((m) => m.includes("flash")),
      ...availableModels,
      ...fallbackModels,
    ])
  );

  let allDiagnostics: string[] = [];

  for (const m of candidates.slice(0, 6)) {
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
        allDiagnostics.push(`[${m} -> HTTP ${res.status}: ${errText.slice(0, 160)}]`);
        continue;
      }

      const data = await res.json();
      let text = data?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? "{}";

      if (text.startsWith("```json")) text = text.slice(7);
      if (text.startsWith("```")) text = text.slice(3);
      if (text.endsWith("```")) text = text.slice(0, -3);
      text = text.trim();

      // Attempt direct JSON parse
      try {
        return JSON.parse(text);
      } catch (parseErr) {
        // Attempt JSON recovery for truncated payload
        console.warn(`Model ${m} payload truncated, attempting recovery…`);
        const repaired = tryRepairTruncatedJson(text);
        if (repaired) return repaired;
        throw parseErr;
      }
    } catch (err) {
      allDiagnostics.push(`[${m} -> ${err instanceof Error ? err.message : String(err)}]`);
      continue;
    }
  }

  throw new Error(`All Gemini model attempts failed. Diagnostic log:\n${allDiagnostics.join("\n")}`);
}

/** Recovers valid questions from a truncated JSON payload */
function tryRepairTruncatedJson(raw: string): Record<string, unknown> | null {
  try {
    const qIndex = raw.lastIndexOf("}");
    if (qIndex !== -1) {
      const trimmed = raw.substring(0, qIndex + 1);
      const candidate = `${trimmed}\n  ]\n}`;
      return JSON.parse(candidate);
    }
  } catch (_) {}
  return null;
}


