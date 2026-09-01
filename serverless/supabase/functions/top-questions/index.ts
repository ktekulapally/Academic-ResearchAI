import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const subjectId = url.searchParams.get("subject_id");
  const limit = Math.min(100, Math.max(1, Number(url.searchParams.get("limit") ?? 50)));

  if (!subjectId) {
    return jsonResponse({ error: "subject_id required" }, 400);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!
  );

  try {
    // 1. Fetch Question Clusters
    const { data: clusters, error: clusterErr } = await supabase
      .from("question_clusters")
      .select(
        "id, canonical_text, frequency_count, years_appeared, marks_hint, question_type, solution_markdown, concept_tags"
      )
      .eq("subject_id", subjectId)
      .order("frequency_count", { ascending: false })
      .limit(limit);

    if (clusterErr) throw clusterErr;

    // 2. Fetch Downloadable Source Papers
    const { data: papers, error: paperErr } = await supabase
      .from("source_papers")
      .select("id, title, year, exam_type, paper_url, file_size")
      .eq("subject_id", subjectId)
      .order("year", { ascending: false });

    if (paperErr) throw paperErr;

    return jsonResponse({
      clusters: clusters ?? [],
      papers: papers ?? [],
    });
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});
