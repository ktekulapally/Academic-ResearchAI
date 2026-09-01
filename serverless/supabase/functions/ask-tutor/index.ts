import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { geminiJson } from "../_shared/gemini.ts";

/**
 * POST { cluster_id: number, prompt: string }
 * Context-aware AI Academic Tutor helping the student understand or clarify a specific question.
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

  let body: { cluster_id?: number; prompt?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON" }, 400);
  }

  const clusterId = Number(body.cluster_id);
  const studentPrompt = body.prompt?.trim();

  if (!clusterId || !studentPrompt) {
    return jsonResponse({ error: "cluster_id and prompt are required" }, 400);
  }

  try {
    // 1. Fetch Question Cluster Context
    const { data: cluster, error } = await supabase
      .from("question_clusters")
      .select("canonical_text, solution_markdown, concept_tags")
      .eq("id", clusterId)
      .single();

    if (error || !cluster) {
      return jsonResponse({ error: "Question cluster not found" }, 404);
    }

    const tutorPrompt = `
You are a friendly, expert Academic Tutor helping a high school student prepare for their board exams.

ORIGINAL EXAM QUESTION:
${cluster.canonical_text}

REFERENCE MODEL SOLUTION:
${cluster.solution_markdown ?? "Standard textbook solution"}

STUDENT DOUBT / QUESTION:
"${studentPrompt}"

Task: Provide a clear, encouraging, and pedagogically sound explanation that directly answers the student's doubt.
- Use LaTeX formatting for all mathematical equations (e.g. $x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}$).
- Break complex steps down into simple intuitive analogies if helpful.
- Keep the response concise, formatted in clean markdown.

Return JSON ONLY:
{
  "response": "Your markdown answer to the student"
}
`;

    const result = await geminiJson(tutorPrompt, geminiKey);
    return jsonResponse({
      response: result.response ?? "I understand your question. Let's break it down step by step.",
    });
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});
