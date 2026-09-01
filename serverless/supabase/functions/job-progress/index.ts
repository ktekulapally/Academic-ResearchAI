import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const jobId = url.searchParams.get("id");

  if (!jobId) {
    return jsonResponse({ error: "job_id (id) required" }, 400);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!
  );

  try {
    const { data: job, error } = await supabase
      .from("research_jobs")
      .select("id, subject_id, years, status, progress_log, error, completed_at")
      .eq("id", jobId)
      .single();

    if (error || !job) {
      return jsonResponse({ error: "Job not found" }, 404);
    }

    return jsonResponse({
      id: job.id,
      status: job.status,
      progress: job.progress_log ?? [],
      error: job.error,
      completed_at: job.completed_at,
    });
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});
