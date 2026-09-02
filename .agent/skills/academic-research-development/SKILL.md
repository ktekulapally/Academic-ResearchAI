---
name: academic-research-development
description: >-
  Comprehensive guide and architectural blueprint for the Academic Research AI (Exam Focus AI)
  system. Activate this skill whenever the user mentions "Academic Research Development",
  "Exam Focus AI", or needs guidance on serverless deep research, question paper extraction,
  dynamic taxonomy, incremental research resuming, LaTeX rendering, and multi-board education pipelines.
---

# Academic Research Development (Exam Focus AI)

This skill encapsulates the full architectural blueprint, operational runbooks, and implementation patterns of the **Exam Focus AI / Academic Research AI** system.

---

## 1. System Architecture & Constraints

- **Architecture Mode**: 100% Serverless Progressive Web App (PWA). No local Python/Node.js desktop backend processes (due to enterprise AppLocker policies).
- **Frontend**: Flutter Web (Material 3 Dark Theme) hosted via GitHub Pages at:
  `https://ktekulapally.github.io/Academic-ResearchAI/`
- **Backend**: Supabase Edge Runtime (Deno / TypeScript) deployed to project `rzgwoubtuyrpmwsezhqw`.
  - Base URL: `https://rzgwoubtuyrpmwsezhqw.supabase.co/functions/v1`
- **Dual-Repository Mirroring**:
  Every file created or modified in `D:\Develop\Academic-ResearchAI` must be mirrored to `D:\Develop\Edu_Research`.

---

## 2. Supabase Edge Functions Reference

### `start-research`
- **Purpose**: Live multi-source web scraping via Serper API + AI frequency analysis and model solution synthesis via Google Generative AI (Gemini).
- **Gemini Models**:
  - Valid, active models: `gemini-3.6-flash`, `gemini-flash-lite-latest`, `gemini-flash-latest`.
  - Deprecated/Invalid: `gemini-1.5-pro` (404), `gemini-2.0-flash` (deprecated by Google with error prompting to use `gemini-3.6-flash`).
  - Implements dynamic model discovery via `v1beta/models?key=...`.
  - Implements automatic 2-second backoff retry on HTTP 503 (temporary demand spikes).
- **Payload Safety & JSON Recovery**:
  - Math solutions contain numerous LaTeX curly braces (e.g. `\int_0^{\pi/2}`, `\frac{a}{b}`).
  - Never use `lastIndexOf("}")` alone because it matches braces inside LaTeX strings.
  - Line-based boundary parser (`tryRepairTruncatedJson`) scans backwards for lines that strictly end with `},` or `}`.
  - Ultimate safety net: `extractQuestionsRegex` parses complete question objects via regex if `JSON.parse` fails, guaranteeing **zero question loss**.
- **Non-Destructive Question Preservation**:
  - If a network error or cut-off happens, any questions harvested before the error are saved immediately to the database with `status: "done"` and `partial: true`.
  - The student immediately sees the harvested questions without receiving a blank error screen.
- **Incremental Resuming**:
  - When `resume: true` is passed, existing question titles are passed to Gemini with explicit instructions:
    `"INCREMENTAL RESUME: We already have X questions. DO NOT duplicate these topics. Harvest remaining chapters/derivations."`
  - Newly harvested questions are appended to `question_clusters` rather than wiping previous rows.

### `taxonomy`
- **Hierarchical Structure**: `academic_standards` → `streams` → `subjects`.
- **Supported Standards**: CBSE Class 10/11/12, TS Inter 1st Year (Junior), TS Inter 2nd Year (Senior).
- **Supported Streams**: MPC, BiPC, CEC, MEC, Science, Commerce, Humanities.
- **Language Subjects**: Both 1st and 2nd language options (e.g. `Sanskrit 1`, `Sanskrit 2`, `English 1`, `English 2`, `Telugu`, `Hindi`) must be seeded across all intermediate streams.
- **Dynamic Creation**: Supports `POST /taxonomy` with actions:
  - `create_standard`
  - `create_stream`
  - `create_subject`

---

## 3. Frontend Implementation Reference (`flutter_app/lib/main.dart`)

### Natural Language Search & Query Router (`_handleNLPQuery`)
- **Search Intent Detection**:
  - If query contains action words (`"find"`, `"search"`, `"paper"`, `"exam papers"`, `"get"`, `"fetch"`, `"research"`):
    - Routes directly to **Deep Research Cloud** rather than in-memory filtering.
  - If query mentions a different subject (e.g. searching for `"Sanskrit 2"` while on `"Mathematics 2B"`):
    - Automatically switches the target subject chip.
    - Launches Deep Research for the new subject.
  - In-memory filtering is only applied for intra-subject filters (e.g. `"10 marks"`, `"derivations"`, `"2023"`).

### Live Research Terminal
- Status indicators: `✅ Research Complete`, `🔬 AI Agent Deep Researching…`, `❌ Research Failed`.
- Action buttons:
  - **`[➕ Continue Research]`**: Triggers `_startDeepResearch(resume: true)` to harvest the next batch without losing existing questions.
  - **`[Re-Run Fresh]`**: Triggers `_startDeepResearch(resume: false)` to start fresh.

### Study Booklet & LaTeX Rendering
- Markdown-to-HTML heading hierarchy: `####` evaluated before `###` evaluated before `##`.
- Math blocks wrapped in `<div class="math-block">$$...$$</div>` and rendered via MathJax CDN.
- Fully scrollable vertical list layout avoiding zero-height nested clipping.

---

## 4. Deployment Commands Quick Reference

### Deploy Backend Functions
```powershell
cd d:\Develop\Academic-ResearchAI\serverless
npx supabase functions deploy start-research --project-ref rzgwoubtuyrpmwsezhqw
npx supabase functions deploy taxonomy --project-ref rzgwoubtuyrpmwsezhqw
```

### Build & Deploy Frontend PWA
```powershell
cd d:\Develop\Academic-ResearchAI\flutter_app
flutter build web --release
Copy-Item -Force "d:\Develop\Academic-ResearchAI\flutter_app\lib\main.dart" "d:\Develop\Edu_Research\flutter_app\lib\main.dart"
git add .
git commit -m "<Description>"
git push origin main
```
