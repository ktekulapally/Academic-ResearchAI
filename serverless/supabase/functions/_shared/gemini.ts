/** Call Gemini generateContent and parse JSON response. */
export async function geminiJson(
  prompt: string,
  apiKey: string,
  model = "gemini-2.5-flash"
): Promise<Record<string, unknown>> {
  const modelsToTry = [model, "gemini-3.5-flash", "gemini-flash-latest", "gemini-2.0-flash"];

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
          },
        }),
      });

      if (!res.ok) {
        continue; // try next model
      }

      const data = await res.json();
      let text = data?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? "{}";

      if (text.startsWith("```json")) text = text.slice(7);
      if (text.startsWith("```")) text = text.slice(3);
      if (text.endsWith("```")) text = text.slice(0, -3);

      return JSON.parse(text.trim());
    } catch {
      continue;
    }
  }

  throw new Error("All Gemini model attempts failed to generate a response.");
}
