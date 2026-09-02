/** Call Gemini generateContent with dynamic model discovery, JSON repair & diagnostics. */
export async function geminiJson(
  prompt: string,
  apiKey: string,
  preferredModel = "gemini-1.5-flash"
): Promise<Record<string, unknown>> {
  // 1. Discover available text-capable models for this specific API key
  let availableModels: string[] = [];
  try {
    const listRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`
    );
    if (listRes.ok) {
      const listData = await listRes.json();
      if (Array.isArray(listData.models)) {
        availableModels = listData.models
          .filter((m: any) => {
            const name = String(m.name).toLowerCase();
            const methods = Array.isArray(m.supportedGenerationMethods) ? m.supportedGenerationMethods : [];
            return (
              methods.includes("generateContent") &&
              !name.includes("tts") &&
              !name.includes("audio") &&
              !name.includes("imagen") &&
              !name.includes("embedding") &&
              !name.includes("2.5")
            );
          })
          .map((m: any) => String(m.name).replace(/^models\//, ""));
      }
    } else {
      const listErr = await listRes.text();
      console.warn(`Models list endpoint returned HTTP ${listRes.status}: ${listErr}`);
    }
  } catch (e) {
    console.warn(`Failed to query models list: ${e}`);
  }

  // Stable production models prioritized first
  const fallbackModels = [
    "gemini-1.5-flash",
    "gemini-1.5-flash-latest",
    "gemini-flash-latest",
    "gemini-2.0-flash",
    "gemini-2.0-flash-exp",
    "gemini-1.5-pro",
  ];

  // Candidates: available standard flash models first, then fallbacks
  const candidates = Array.from(
    new Set([
      ...availableModels.filter((m) => m === "gemini-1.5-flash" || m === "gemini-1.5-flash-latest" || m === "gemini-2.0-flash"),
      ...fallbackModels,
      ...availableModels,
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
        // Attempt line-based JSON recovery (handles truncated output & LaTeX braces)
        console.warn(`Model ${m} payload cut off, attempting line-based question recovery…`);
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

/** Recovers valid questions from a truncated JSON payload by scanning for object boundaries on line endings */
function tryRepairTruncatedJson(raw: string): Record<string, unknown> | null {
  try {
    const lines = raw.split("\n");
    // Scan backwards from the end of the payload for a line containing only "}," or "}"
    for (let i = lines.length - 1; i >= 0; i--) {
      const line = lines[i].trim();
      if (line === "}," || line === "}") {
        const trimmed = lines.slice(0, i + 1).join("\n").replace(/,\s*$/, "");
        const candidate = `${trimmed}\n  ]\n}`;
        try {
          const parsed = JSON.parse(candidate);
          if (Array.isArray(parsed.questions) && parsed.questions.length > 0) {
            console.log(`Successfully recovered ${parsed.questions.length} complete questions from truncated payload.`);
            return parsed;
          }
        } catch (_) {
          continue; // Try previous question block
        }
      }
    }
  } catch (_) {}
  return null;
}



