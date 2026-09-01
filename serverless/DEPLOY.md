# 🚀 Exam Focus AI — Serverless Cloud Deployment Guide

Complete step-by-step guide to deploying the serverless backend (Supabase Edge Functions + PostgreSQL) and frontend (GitHub Pages PWA). **No local server required.**

---

## 1. Create Free Supabase Project

1. Go to **https://supabase.com** → **New project**.
2. Note your:
   - **Project URL** (e.g. `https://xxxx.supabase.co`)
   - **Anon Public Key** (under **Settings → API**)
   - **Service Role Key** (under **Settings → API**)

---

## 2. Apply Database Schema & Taxonomy Seed

1. In Supabase Dashboard → **SQL Editor** → **New query**.
2. Copy and paste the entire contents of **[`serverless/supabase/migrations/001_init.sql`](./supabase/migrations/001_init.sql)**.
3. Click **Run**.
4. This seeds:
   - CBSE Class 10th (Science, Math, Social Science, English, Hindi)
   - CBSE Class 11th (Science, Commerce, Humanities)
   - CBSE Class 12th (Science, Commerce, Humanities)
   - TS Inter 1st Year (Junior: MPC, BiPC, CEC, MEC)
   - TS Inter 2nd Year (Senior: MPC, BiPC, CEC, MEC)

---

## 3. Configure AI API Keys (Secrets)

In Supabase Dashboard → **Edge Functions → Secrets** (or via CLI):

```bash
supabase secrets set GEMINI_API_KEY="your_gemini_api_key"
supabase secrets set SERPER_API_KEY="your_serper_api_key"
```

- **Gemini API Key**: https://aistudio.google.com/apikey (Generates top recurring questions, LaTeX solutions, and powers AI Tutor).
- **Serper API Key** (optional, recommended): https://serper.dev (Fetches live Google search signals for official previous year question papers).

---

## 4. Enable Anonymous & Email Auth

In Supabase Dashboard → **Authentication → Providers**:
1. **Email**: Enable (uncheck "Confirm email" for instant login).
2. **Anonymous**: Enable **Anonymous sign-ins** (powers instant 1-click **Continue as Guest**).

---

## 5. Deploy Edge Functions

Install Supabase CLI if you haven't:
```bash
# In terminal inside serverless/
cd serverless
supabase login
supabase link --project-ref YOUR_PROJECT_REF

supabase functions deploy taxonomy
supabase functions deploy parse-query
supabase functions deploy start-research
supabase functions deploy job-progress
supabase functions deploy top-questions
supabase functions deploy ask-tutor
```

Your live endpoints will be:
- `https://YOUR_PROJECT_REF.supabase.co/functions/v1/taxonomy`
- `https://YOUR_PROJECT_REF.supabase.co/functions/v1/parse-query`
- `https://YOUR_PROJECT_REF.supabase.co/functions/v1/start-research`
- `https://YOUR_PROJECT_REF.supabase.co/functions/v1/job-progress`
- `https://YOUR_PROJECT_REF.supabase.co/functions/v1/top-questions`
- `https://YOUR_PROJECT_REF.supabase.co/functions/v1/ask-tutor`

---

## 6. Access the Live Web App & PWA

The frontend is automated with **GitHub Actions** (`.github/workflows/deploy_pwa.yml`).

Once pushed to GitHub:
1. Go to your GitHub Repository: `https://github.com/ktekulapally/Academic-ResearchAI`
2. Go to **Settings → Pages** → Under **Build and deployment**, set Source to **GitHub Actions**.
3. Your live PWA URL will be:
   👉 **`https://ktekulapally.github.io/Academic-ResearchAI/`**

You and your students can open this link on **any phone (Android/iOS), tablet, or desktop** and click **"Add to Home Screen"** to install it as a native mobile app!
