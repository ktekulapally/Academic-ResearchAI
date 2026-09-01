-- Exam Focus AI — Complete Serverless Supabase Schema
-- Run in Supabase SQL Editor (or via supabase db push)

-- Extensions
create extension if not exists "pgcrypto";

-- ========== 1. TAXONOMY TABLES ==========
create table if not exists academic_standards (
  id bigserial primary key,
  name text not null unique,
  level_order int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists streams (
  id bigserial primary key,
  standard_id bigint not null references academic_standards(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  unique (standard_id, name)
);

create table if not exists subjects (
  id bigserial primary key,
  stream_id bigint not null references streams(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  unique (stream_id, name)
);

-- ========== 2. PROFILES & GUEST AUTH ==========
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  is_guest boolean default false,
  created_at timestamptz not null default now()
);

-- ========== 3. RESEARCH JOBS ==========
create table if not exists research_jobs (
  id uuid primary key default gen_random_uuid(),
  subject_id bigint not null references subjects(id) on delete cascade,
  years int not null default 10 check (years in (5, 7, 10)),
  query_prompt text,
  status text not null default 'queued'
    check (status in ('queued', 'running', 'done', 'failed')),
  progress_log text[] not null default '{}',
  error text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create index if not exists research_jobs_subject_idx on research_jobs(subject_id);
create index if not exists research_jobs_status_idx on research_jobs(status);

-- ========== 4. QUESTION CLUSTERS ==========
create table if not exists question_clusters (
  id bigserial primary key,
  subject_id bigint not null references subjects(id) on delete cascade,
  canonical_text text not null,
  frequency_count int not null default 1,
  years_appeared int[] not null default '{}',
  marks_hint text,
  question_type text default 'Theory',
  solution_markdown text,
  concept_tags text[] default '{}',
  job_id uuid references research_jobs(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists question_clusters_subject_freq_idx
  on question_clusters(subject_id, frequency_count desc);

-- ========== 5. SOURCE PAPERS & DOWNLOADS ==========
create table if not exists source_papers (
  id bigserial primary key,
  subject_id bigint not null references subjects(id) on delete cascade,
  title text not null,
  year int not null,
  exam_type text default 'Annual Board Exam',
  paper_url text not null,
  file_size text default '1.8 MB',
  created_at timestamptz not null default now()
);

create index if not exists source_papers_subject_year_idx 
  on source_papers(subject_id, year desc);

-- ========== 6. COMPREHENSIVE SEED DATA ==========

-- Standards
insert into academic_standards (name, level_order) values
  ('CBSE Class 10', 10),
  ('CBSE Class 11', 11),
  ('CBSE Class 12', 12),
  ('TS Inter 1st Year (Junior)', 21),
  ('TS Inter 2nd Year (Senior)', 22)
on conflict (name) do nothing;

-- Populate Streams & Subjects
do $$
declare
  s10 bigint; s11 bigint; s12 bigint; ts1 bigint; ts2 bigint;
  sid bigint;
begin
  select id into s10 from academic_standards where name = 'CBSE Class 10';
  select id into s11 from academic_standards where name = 'CBSE Class 11';
  select id into s12 from academic_standards where name = 'CBSE Class 12';
  select id into ts1 from academic_standards where name = 'TS Inter 1st Year (Junior)';
  select id into ts2 from academic_standards where name = 'TS Inter 2nd Year (Senior)';

  -- 1. CBSE 10
  insert into streams (standard_id, name) values (s10, 'General') on conflict (standard_id, name) do nothing;
  select id into sid from streams where standard_id = s10 and name = 'General';
  insert into subjects (stream_id, name) values
    (sid, 'Mathematics (Standard)'), (sid, 'Mathematics (Basic)'), (sid, 'Science'), 
    (sid, 'Social Science'), (sid, 'English Language & Lit'), (sid, 'Hindi Course A')
  on conflict (stream_id, name) do nothing;

  -- 2. CBSE 11
  insert into streams (standard_id, name) values
    (s11, 'Science (PCM/PCB)'), (s11, 'Commerce'), (s11, 'Humanities / Arts')
  on conflict (standard_id, name) do nothing;

  select id into sid from streams where standard_id = s11 and name = 'Science (PCM/PCB)';
  insert into subjects (stream_id, name) values
    (sid, 'Physics'), (sid, 'Chemistry'), (sid, 'Mathematics'), (sid, 'Biology'), (sid, 'Computer Science (Python)'), (sid, 'English Core')
  on conflict (stream_id, name) do nothing;

  select id into sid from streams where standard_id = s11 and name = 'Commerce';
  insert into subjects (stream_id, name) values
    (sid, 'Accountancy'), (sid, 'Business Studies'), (sid, 'Economics'), (sid, 'Applied Mathematics'), (sid, 'English Core')
  on conflict (stream_id, name) do nothing;

  select id into sid from streams where standard_id = s11 and name = 'Humanities / Arts';
  insert into subjects (stream_id, name) values
    (sid, 'History'), (sid, 'Political Science'), (sid, 'Geography'), (sid, 'Psychology'), (sid, 'Economics')
  on conflict (stream_id, name) do nothing;

  -- 3. CBSE 12
  insert into streams (standard_id, name) values
    (s12, 'Science (PCM/PCB)'), (s12, 'Commerce'), (s12, 'Humanities / Arts')
  on conflict (standard_id, name) do nothing;

  select id into sid from streams where standard_id = s12 and name = 'Science (PCM/PCB)';
  insert into subjects (stream_id, name) values
    (sid, 'Physics'), (sid, 'Chemistry'), (sid, 'Mathematics'), (sid, 'Biology'), (sid, 'Computer Science (Python)'), (sid, 'English Core')
  on conflict (stream_id, name) do nothing;

  select id into sid from streams where standard_id = s12 and name = 'Commerce';
  insert into subjects (stream_id, name) values
    (sid, 'Accountancy'), (sid, 'Business Studies'), (sid, 'Economics'), (sid, 'Applied Mathematics'), (sid, 'English Core')
  on conflict (stream_id, name) do nothing;

  select id into sid from streams where standard_id = s12 and name = 'Humanities / Arts';
  insert into subjects (stream_id, name) values
    (sid, 'History'), (sid, 'Political Science'), (sid, 'Geography'), (sid, 'Psychology'), (sid, 'Economics')
  on conflict (stream_id, name) do nothing;

  -- 4. TS Inter 1st Year
  insert into streams (standard_id, name) values
    (ts1, 'MPC'), (ts1, 'BiPC'), (ts1, 'CEC'), (ts1, 'MEC')
  on conflict (standard_id, name) do nothing;

  select id into sid from streams where standard_id = ts1 and name = 'MPC';
  insert into subjects (stream_id, name) values
    (sid, 'Mathematics 1A'), (sid, 'Mathematics 1B'), (sid, 'Physics 1'), (sid, 'Chemistry 1'), (sid, 'English 1')
  on conflict (stream_id, name) do nothing;

  select id into sid from streams where standard_id = ts1 and name = 'BiPC';
  insert into subjects (stream_id, name) values
    (sid, 'Botany 1'), (sid, 'Zoology 1'), (sid, 'Physics 1'), (sid, 'Chemistry 1'), (sid, 'English 1')
  on conflict (stream_id, name) do nothing;

  select id into sid from streams where standard_id = ts1 and name = 'CEC';
  insert into subjects (stream_id, name) values
    (sid, 'Commerce 1'), (sid, 'Economics 1'), (sid, 'Civics 1'), (sid, 'English 1')
  on conflict (stream_id, name) do nothing;

  -- 5. TS Inter 2nd Year
  insert into streams (standard_id, name) values
    (ts2, 'MPC'), (ts2, 'BiPC'), (ts2, 'CEC'), (ts2, 'MEC')
  on conflict (standard_id, name) do nothing;

  select id into sid from streams where standard_id = ts2 and name = 'MPC';
  insert into subjects (stream_id, name) values
    (sid, 'Mathematics 2A'), (sid, 'Mathematics 2B'), (sid, 'Physics 2'), (sid, 'Chemistry 2'), (sid, 'English 2')
  on conflict (stream_id, name) do nothing;

  select id into sid from streams where standard_id = ts2 and name = 'BiPC';
  insert into subjects (stream_id, name) values
    (sid, 'Botany 2'), (sid, 'Zoology 2'), (sid, 'Physics 2'), (sid, 'Chemistry 2'), (sid, 'English 2')
  on conflict (stream_id, name) do nothing;

  select id into sid from streams where standard_id = ts2 and name = 'CEC';
  insert into subjects (stream_id, name) values
    (sid, 'Commerce 2'), (sid, 'Economics 2'), (sid, 'Civics 2'), (sid, 'English 2')
  on conflict (stream_id, name) do nothing;

end $$;

-- Enable Row Level Security (RLS) & Public read policies
alter table academic_standards enable row level security;
alter table streams enable row level security;
alter table subjects enable row level security;
alter table question_clusters enable row level security;
alter table source_papers enable row level security;
alter table research_jobs enable row level security;

create policy "Public read standards" on academic_standards for select using (true);
create policy "Public read streams" on streams for select using (true);
create policy "Public read subjects" on subjects for select using (true);
create policy "Public read clusters" on question_clusters for select using (true);
create policy "Public read source papers" on source_papers for select using (true);
create policy "Public read research jobs" on research_jobs for select using (true);
create policy "Public insert research jobs" on research_jobs for insert with check (true);
create policy "Public update research jobs" on research_jobs for update using (true);
