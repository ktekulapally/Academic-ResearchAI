-- Exam Focus AI — Complete Serverless Supabase Schema (Pure Standard SQL)
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

-- ========== 6. SEED DATA (PURE STANDARD SQL) ==========

-- Standards
insert into academic_standards (name, level_order) values
  ('CBSE Class 10', 10),
  ('CBSE Class 11', 11),
  ('CBSE Class 12', 12),
  ('TS Inter 1st Year (Junior)', 21),
  ('TS Inter 2nd Year (Senior)', 22)
on conflict (name) do nothing;

-- Streams for CBSE 10
insert into streams (standard_id, name)
select id, 'General' from academic_standards where name = 'CBSE Class 10'
on conflict (standard_id, name) do nothing;

-- Streams for CBSE 11 & 12
insert into streams (standard_id, name)
select a.id, t.stream_name 
from academic_standards a,
(values ('Science (PCM/PCB)'), ('Commerce'), ('Humanities / Arts')) as t(stream_name)
where a.name in ('CBSE Class 11', 'CBSE Class 12')
on conflict (standard_id, name) do nothing;

-- Streams for TS Inter 1st & 2nd Year
insert into streams (standard_id, name)
select a.id, t.stream_name 
from academic_standards a,
(values ('MPC'), ('BiPC'), ('CEC'), ('MEC')) as t(stream_name)
where a.name in ('TS Inter 1st Year (Junior)', 'TS Inter 2nd Year (Senior)')
on conflict (standard_id, name) do nothing;

-- Subjects: CBSE 10
insert into subjects (stream_id, name)
select s.id, t.sub_name 
from streams s 
join academic_standards a on s.standard_id = a.id,
(values 
  ('Mathematics (Standard)'), 
  ('Mathematics (Basic)'), 
  ('Science'), 
  ('Social Science'), 
  ('English Language & Lit'), 
  ('Hindi Course A')
) as t(sub_name)
where a.name = 'CBSE Class 10' and s.name = 'General'
on conflict (stream_id, name) do nothing;

-- Subjects: CBSE 11 Science
insert into subjects (stream_id, name)
select s.id, t.sub_name 
from streams s 
join academic_standards a on s.standard_id = a.id,
(values 
  ('Physics'), 
  ('Chemistry'), 
  ('Mathematics'), 
  ('Biology'), 
  ('Computer Science (Python)'), 
  ('English Core')
) as t(sub_name)
where a.name = 'CBSE Class 11' and s.name = 'Science (PCM/PCB)'
on conflict (stream_id, name) do nothing;

-- Subjects: CBSE 11 Commerce
insert into subjects (stream_id, name)
select s.id, t.sub_name 
from streams s 
join academic_standards a on s.standard_id = a.id,
(values 
  ('Accountancy'), 
  ('Business Studies'), 
  ('Economics'), 
  ('Applied Mathematics'), 
  ('English Core')
) as t(sub_name)
where a.name = 'CBSE Class 11' and s.name = 'Commerce'
on conflict (stream_id, name) do nothing;

-- Subjects: CBSE 11 Humanities
insert into subjects (stream_id, name)
select s.id, t.sub_name 
from streams s 
join academic_standards a on s.standard_id = a.id,
(values 
  ('History'), 
  ('Political Science'), 
  ('Geography'), 
  ('Psychology'), 
  ('Economics')
) as t(sub_name)
where a.name = 'CBSE Class 11' and s.name = 'Humanities / Arts'
on conflict (stream_id, name) do nothing;

-- Subjects: CBSE 12 Science
insert into subjects (stream_id, name)
select s.id, t.sub_name 
from streams s 
join academic_standards a on s.standard_id = a.id,
(values 
  ('Physics'), 
  ('Chemistry'), 
  ('Mathematics'), 
  ('Biology'), 
  ('Computer Science (Python)'), 
  ('English Core')
) as t(sub_name)
where a.name = 'CBSE Class 12' and s.name = 'Science (PCM/PCB)'
on conflict (stream_id, name) do nothing;

-- Subjects: CBSE 12 Commerce
insert into subjects (stream_id, name)
select s.id, t.sub_name 
from streams s 
join academic_standards a on s.standard_id = a.id,
(values 
  ('Accountancy'), 
  ('Business Studies'), 
  ('Economics'), 
  ('Applied Mathematics'), 
  ('English Core')
) as t(sub_name)
where a.name = 'CBSE Class 12' and s.name = 'Commerce'
on conflict (stream_id, name) do nothing;

-- Subjects: CBSE 12 Humanities
insert into subjects (stream_id, name)
select s.id, t.sub_name 
from streams s 
join academic_standards a on s.standard_id = a.id,
(values 
  ('History'), 
  ('Political Science'), 
  ('Geography'), 
  ('Psychology'), 
  ('Economics')
) as t(sub_name)
where a.name = 'CBSE Class 12' and s.name = 'Humanities / Arts'
on conflict (stream_id, name) do nothing;

-- Subjects: TS Inter 1st Year (MPC, BiPC, CEC)
insert into subjects (stream_id, name)
select s.id, t.sub_name 
from streams s 
join academic_standards a on s.standard_id = a.id,
(values ('Mathematics 1A'), ('Mathematics 1B'), ('Physics 1'), ('Chemistry 1'), ('English 1')) as t(sub_name)
where a.name = 'TS Inter 1st Year (Junior)' and s.name = 'MPC'
on conflict (stream_id, name) do nothing;

insert into subjects (stream_id, name)
select s.id, t.sub_name 
from streams s 
join academic_standards a on s.standard_id = a.id,
(values ('Botany 1'), ('Zoology 1'), ('Physics 1'), ('Chemistry 1'), ('English 1')) as t(sub_name)
where a.name = 'TS Inter 1st Year (Junior)' and s.name = 'BiPC'
on conflict (stream_id, name) do nothing;

insert into subjects (stream_id, name)
select s.id, t.sub_name 
from streams s 
join academic_standards a on s.standard_id = a.id,
(values ('Commerce 1'), ('Economics 1'), ('Civics 1'), ('English 1')) as t(sub_name)
where a.name = 'TS Inter 1st Year (Junior)' and s.name = 'CEC'
on conflict (stream_id, name) do nothing;

-- Subjects: TS Inter 2nd Year (MPC, BiPC, CEC)
insert into subjects (stream_id, name)
select s.id, t.sub_name 
from streams s 
join academic_standards a on s.standard_id = a.id,
(values ('Mathematics 2A'), ('Mathematics 2B'), ('Physics 2'), ('Chemistry 2'), ('English 2')) as t(sub_name)
where a.name = 'TS Inter 2nd Year (Senior)' and s.name = 'MPC'
on conflict (stream_id, name) do nothing;

insert into subjects (stream_id, name)
select s.id, t.sub_name 
from streams s 
join academic_standards a on s.standard_id = a.id,
(values ('Botany 2'), ('Zoology 2'), ('Physics 2'), ('Chemistry 2'), ('English 2')) as t(sub_name)
where a.name = 'TS Inter 2nd Year (Senior)' and s.name = 'BiPC'
on conflict (stream_id, name) do nothing;

insert into subjects (stream_id, name)
select s.id, t.sub_name 
from streams s 
join academic_standards a on s.standard_id = a.id,
(values ('Commerce 2'), ('Economics 2'), ('Civics 2'), ('English 2')) as t(sub_name)
where a.name = 'TS Inter 2nd Year (Senior)' and s.name = 'CEC'
on conflict (stream_id, name) do nothing;

-- ========== 7. RLS POLICIES ==========
alter table academic_standards enable row level security;
alter table streams enable row level security;
alter table subjects enable row level security;
alter table question_clusters enable row level security;
alter table source_papers enable row level security;
alter table research_jobs enable row level security;

-- Drop existing policies if they already exist to avoid errors on rerun
drop policy if exists "Public read standards" on academic_standards;
drop policy if exists "Public read streams" on streams;
drop policy if exists "Public read subjects" on subjects;
drop policy if exists "Public read clusters" on question_clusters;
drop policy if exists "Public read source papers" on source_papers;
drop policy if exists "Public read research jobs" on research_jobs;
drop policy if exists "Public insert research jobs" on research_jobs;
drop policy if exists "Public update research jobs" on research_jobs;

create policy "Public read standards" on academic_standards for select using (true);
create policy "Public read streams" on streams for select using (true);
create policy "Public read subjects" on subjects for select using (true);
create policy "Public read clusters" on question_clusters for select using (true);
create policy "Public read source papers" on source_papers for select using (true);
create policy "Public read research jobs" on research_jobs for select using (true);
create policy "Public insert research jobs" on research_jobs for insert with check (true);
create policy "Public update research jobs" on research_jobs for update using (true);
