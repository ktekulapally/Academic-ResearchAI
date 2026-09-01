import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_ANON_KEY")!
  );

  const url = new URL(req.url);

  // POST: Add custom Board / Stream / Subject dynamically
  if (req.method === "POST") {
    try {
      const body = await req.json();
      const action = body.action;

      if (action === "create_standard") {
        const { name, level_order = 99 } = body;
        const { data, error } = await supabase
          .from("academic_standards")
          .insert({ name, level_order })
          .select()
          .single();
        if (error) throw error;
        return jsonResponse(data, 201);
      }

      if (action === "create_stream") {
        const { standard_id, name } = body;
        const { data, error } = await supabase
          .from("streams")
          .insert({ standard_id, name })
          .select()
          .single();
        if (error) throw error;
        return jsonResponse(data, 201);
      }

      if (action === "create_subject") {
        const { stream_id, name } = body;
        const { data, error } = await supabase
          .from("subjects")
          .insert({ stream_id, name })
          .select()
          .single();
        if (error) throw error;
        return jsonResponse(data, 201);
      }

      return jsonResponse({ error: "Invalid action" }, 400);
    } catch (e) {
      return jsonResponse({ error: String(e) }, 500);
    }
  }

  // GET /taxonomy?type=standards | streams | subjects
  const type = url.searchParams.get("type") ?? "standards";

  try {
    if (type === "standards") {
      const { data, error } = await supabase
        .from("academic_standards")
        .select("id, name, level_order")
        .order("level_order");
      if (error) throw error;
      return jsonResponse(data);
    }

    if (type === "streams") {
      const standardId = url.searchParams.get("standard_id");
      if (!standardId) return jsonResponse({ error: "standard_id required" }, 400);
      const { data, error } = await supabase
        .from("streams")
        .select("id, name, standard_id")
        .eq("standard_id", standardId)
        .order("name");
      if (error) throw error;
      return jsonResponse(data);
    }

    if (type === "subjects") {
      const streamId = url.searchParams.get("stream_id");
      if (!streamId) return jsonResponse({ error: "stream_id required" }, 400);
      const { data, error } = await supabase
        .from("subjects")
        .select("id, name, stream_id")
        .eq("stream_id", streamId)
        .order("name");
      if (error) throw error;
      return jsonResponse(data);
    }

    return jsonResponse({ error: "Unknown type" }, 400);
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});
