import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { geminiJson } from "../_shared/gemini.ts";

/**
 * POST { query: string }
 * Parses free-form student queries (e.g. "CBSE 12th physics 5 marks derivations for last 7 years")
 * Maps intent to matched board, standard, stream, and subject IDs.
 */
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "POST only" }, 405);
  }

  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  if (!geminiKey) {
    return jsonResponse({ error: "GEMINI_API_KEY not configured" }, 500);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!
  );

  let body: { query?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON" }, 400);
  }

  const query = body.query?.trim();
  if (!query) {
    return jsonResponse({ error: "query string is required" }, 400);
  }

  try {
    // 1. Fetch available standards and subjects from DB
    const { data: standards } = await supabase.from("academic_standards").select("id, name");
    const { data: subjects } = await supabase.from("subjects").select("id, name, stream_id");

    const standardsList = (standards ?? []).map((s) => `${s.id}: ${s.name}`).join(", ");
    const subjectsList = (subjects ?? []).map((s) => `${s.id}: ${s.name}`).join(", ");

    const prompt = `
You are an Academic Query Parser for Indian Secondary and Intermediate Board Exams.
User Query: "${query}"

Available Standards: [${standardsList}]
Available Subjects: [${subjectsList}]

Task: Extract structured academic intent from the user query.
Return JSON ONLY with this structure:
{
  "detected_standard_id": number or null,
  "detected_standard_name": string,
  "detected_subject_id": number or null,
  "detected_subject_name": string,
  "years": 5 or 7 or 10,
  "marks_filter": number or null,
  "question_type": "Derivation" or "Theory" or "Numerical" or "All",
  "specific_topics": string[],
  "search_summary": "Short readable summary of what user is searching for"
}

Rules:
- Default years to 10 if not explicitly mentioned as 5 or 7.
- Match standard_id and subject_id to the provided IDs if relevant.
`;

    const parsed = await geminiJson(prompt, geminiKey);
    return jsonResponse(parsed);
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});
