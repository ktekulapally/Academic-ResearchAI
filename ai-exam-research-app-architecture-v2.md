# AI Exam Research Web App — Architecture Plan (v2, using your Default Stack)

Rebuilt to match your team's standard stack (Flutter, FastAPI, n8n, Flowise, Ollama, LangGraph, Qdrant, SQLite/Postgres, FastMCP, Docker, OpenTelemetry+Grafana).

---

## 1. What we're building (unchanged)

Student logs in → selects Academic Standard (Intermediate, CBSE, Polytechnic, Graduation) → selects Stream (MPC, BiPC, CEC, HEC, etc.) → sees Subjects (Maths, Physics, Chemistry, Biology, Civics, Economics) → clicks "Deep Research" on a subject → app searches the web live, pulls last 10 years' question papers, extracts questions, clusters repeats, ranks by frequency → student gets a "prepare these first" list.

---

## 2. Stack mapping

| Layer | Your Default Stack | Role in this app |
|---|---|---|
| Client | **Flutter (web target)** | One codebase, deployable as a responsive web app (and later Android/iOS with zero rework) |
| Backend API | **FastAPI** | Auth, standard/stream/subject CRUD, job triggering, results endpoints |
| Workflow automation | **n8n** | Scheduling ("re-research this subject every 30 days"), external integrations (notifications, email on job completion), and the outer orchestration loop that kicks off the research pipeline |
| AI agent orchestration | **LangGraph** | The actual multi-step "deep research" agent graph: query-gen → search → scrape → extract → cluster → rank (see Section 5) |
| AI agent builder | **Flowise** | Visual, editable sub-agents your team can tune without redeploying code — e.g. the "question extractor" or "topic classifier" agent, swappable/testable independently of the core LangGraph pipeline |
| Local LLM | **Ollama** | Runs extraction/classification/query-generation models locally for the POC (e.g. Llama 3.1 / Qwen2.5) |
| Vector DB | **Qdrant** | Stores question embeddings; used for semantic dedup/clustering — "same question, different year/wording" |
| Dev DB | **SQLite** | Local development |
| Prod DB | **PostgreSQL** | Structured data: users, standards, streams, subjects, papers, jobs, clusters |
| MCP layer | **FastMCP** | Exposes reusable tools (web_search, fetch_pdf, parse_pdf, extract_questions) as MCP tools — callable from LangGraph, Flowise, or n8n uniformly |
| Deployment | **Docker (Compose)** | All services containerized: FastAPI, n8n, Flowise, Ollama, Qdrant, Postgres |
| Monitoring | **OpenTelemetry + Grafana** | Track job durations, pipeline failures, LLM latency/cost, scrape success rates |
| IDE | **VS Code** | — |

Note on Flutter for web: Flutter Web is solid for dashboards/forms like this (login, dropdowns, result lists). If any part of the UI later needs heavy SEO or ultra-fast first paint (e.g. a public marketing page), that one page can be a plain static page outside the Flutter app — everything logged-in stays Flutter.

---

## 3. Data model (same entities, now Postgres/SQLite via FastAPI + SQLModel/SQLAlchemy)

```
users                 (id, email, password_hash, name, created_at)
academic_standards    (id, name, level_order)              -- Intermediate, CBSE, Polytechnic, Graduation
streams               (id, standard_id FK, name)            -- MPC, BiPC, CEC, HEC
subjects              (id, stream_id FK, name)               -- Maths, Physics, Chemistry, Biology, Civics, Economics
user_profiles          (user_id FK, standard_id FK, stream_id FK)

research_jobs          (id, user_id FK, subject_id FK, status, created_at, completed_at)
source_papers          (id, subject_id FK, source_url, year, board_name, file_type, fetched_at)
extracted_questions    (id, source_paper_id FK, raw_text, question_type, topic_tag, qdrant_point_id)
question_clusters      (id, subject_id FK, canonical_text, frequency_count, years_appeared[], difficulty_estimate)
cluster_membership     (cluster_id FK, question_id FK, similarity_score)
```

Embeddings themselves live in **Qdrant** (collection per subject or one collection with subject as a payload filter); Postgres/SQLite stores the relational metadata and references the Qdrant point ID.

---

## 4. User flow (unchanged)

```
Login/Signup (FastAPI + JWT)
   │
   ▼
Select Academic Standard → Intermediate | CBSE | Polytechnic | Graduation
   │
   ▼
Select Stream (conditional dropdown, seeded config table — not hardcoded)
   │
   ▼
Dashboard: subject tiles for the chosen stream
   │
   ▼
Click "Deep Research" → FastAPI enqueues a job → n8n workflow triggers the LangGraph agent
   │
   ▼
Results page polls job status → ranked "most common questions" list with year tags + sources
```

---

## 5. Deep Research pipeline (LangGraph graph, tools via FastMCP)

n8n receives the "research subject X" trigger (from FastAPI, or on a schedule) and calls a LangGraph agent run. LangGraph owns the multi-step reasoning; each step calls a **FastMCP tool** so the same tools are reusable from Flowise for ad-hoc testing:

1. **Query generation** (Ollama via LangGraph node) — generate 10 years' worth of targeted search queries per subject/board, e.g. `"CBSE Class 12 Physics question paper 2023 pdf"`.
2. **Web search** (FastMCP tool `web_search`, backed by a self-hosted SearxNG instance) — collect candidate URLs.
3. **Source filtering** (LangGraph node, rule-based + LLM check) — prefer official board domains and known trusted sites, drop low-quality aggregators.
4. **Fetch & parse** (FastMCP tools `fetch_pdf`, `parse_pdf`, using Playwright + pdf-parse/OCR) — extract raw text per paper.
5. **Question extraction** (Flowise-built agent, called as a FastMCP tool `extract_questions`, running on Ollama) — turns raw paper text into structured question records. Building this one in Flowise (rather than hardcoded LangGraph) lets your team tune the extraction prompt visually without a redeploy.
6. **Embed + store** — embed each question (Ollama embedding model or a small sentence-transformer), upsert into Qdrant.
7. **Cluster** (LangGraph node, Qdrant similarity search) — group near-duplicate questions across years/sources into `question_clusters`.
8. **Rank** — frequency = distinct years/papers per cluster; write results to Postgres.
9. **n8n** picks up job completion → notifies the user (email/push) and marks `research_jobs.status = done`.

OpenTelemetry traces wrap each LangGraph node and FastMCP tool call, visualized in Grafana — so you can see exactly where a research job is slow or failing (e.g. a specific board's site blocking scrapes).

---

## 6. Swap point for a stronger AI model later

Every LLM call in LangGraph/Flowise talks to Ollama through a single model-provider config. When you're ready to use a frontier "deep research" model instead of a local model, you change that one provider config (Ollama → hosted API) — the graph structure, FastMCP tools, and data model don't change.

---

## 7. Suggested build order (POC → MVP)

1. FastAPI + SQLite: auth, standard/stream/subject tables + seed data, Flutter web login + selection screens (no AI yet)
2. Stand up Docker Compose: FastAPI, Postgres, Qdrant, Ollama, n8n, Flowise
3. Build FastMCP tools (`web_search`, `fetch_pdf`, `parse_pdf`) and test them standalone
4. Build the Flowise "question extractor" agent against a few manually-picked sample papers
5. Wire the LangGraph pipeline end-to-end for one subject, one board, one year
6. Expand to 10 years / all subjects for one stream; add n8n scheduling + notifications
7. Add OpenTelemetry/Grafana dashboards for pipeline health
8. Swap Ollama → stronger hosted model once POC quality is validated

---

## 8. Open questions for you

- Priority boards/standards for the POC — just CBSE + Intermediate first, or all at once?
- Should students see original source-paper links (for trust), or just the distilled question list?
- Do you want Flutter web deployed standalone, or embedded/linked from an existing site?

Ready to start scaffolding (FastAPI project + Docker Compose + Flutter web skeleton) whenever you confirm scope for the POC.
