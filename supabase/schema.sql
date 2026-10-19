-- 盲派八字排盤 shared 命例 backend (Supabase). Run once in the SQL Editor.
-- Anyone may read and add 命例, vote 準/唔準, add notes and change tags; nobody can delete through the website.
-- Remove unwanted entries from the Supabase dashboard (Table Editor).

create table if not exists public.cases (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  name text not null check (char_length(name) between 1 and 60),
  input jsonb not null,          -- the birth form: sex, calendar, date, time, place, 子時 rule…
  notes text check (char_length(notes) <= 2000),
  tags text[] not null default '{}' check (cardinality(tags) <= 30)
);

create table if not exists public.votes (
  case_id uuid not null references public.cases(id) on delete cascade,
  voter text not null check (char_length(voter) between 1 and 64),   -- random id kept in each browser
  vote smallint not null check (vote in (-1, 0, 1)),                -- 1 準, -1 唔準, 0 withdrawn
  created_at timestamptz not null default now(),
  primary key (case_id, voter)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  case_id uuid not null references public.cases(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000)
);

alter table public.cases enable row level security;
alter table public.votes enable row level security;
alter table public.comments enable row level security;

create policy "read cases" on public.cases for select to anon using (true);
create policy "add cases" on public.cases for insert to anon with check (true);
create policy "retag cases" on public.cases for update to anon using (true) with check (true);
-- Only the tags column can be changed from the website.
revoke update on public.cases from anon;
grant update (tags) on public.cases to anon;

create policy "read votes" on public.votes for select to anon using (true);
create policy "add votes" on public.votes for insert to anon with check (true);
create policy "change votes" on public.votes for update to anon using (true) with check (true);

create policy "read comments" on public.comments for select to anon using (true);
create policy "add comments" on public.comments for insert to anon with check (true);
