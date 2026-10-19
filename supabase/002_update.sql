-- Run this once in the SQL Editor (you already ran the first schema.sql).
-- Adds: the shared tag list, who added each 命例 and note, and 準/唔準 on each note.

-- Shared tag list. Signed-in users add, admins delete.
create table if not exists public.tags (
  name text primary key check (char_length(name) between 1 and 30),
  created_at timestamptz not null default now()
);
alter table public.tags enable row level security;
create policy "read tags" on public.tags for select to anon, authenticated using (true);
create policy "add tags" on public.tags for insert to authenticated with check (true);
create policy "admins delete tags" on public.tags for delete to authenticated using (public.is_admin());
insert into public.tags (name) values ('雙胞胎'),('結婚'),('離婚'),('生死'),('生仔'),('兄弟數目'),('父母'),('事業'),('財運'),('疾病')
  on conflict (name) do nothing;

-- Display name of whoever added a 命例 or a note.
alter table public.cases add column if not exists owner_name text check (char_length(owner_name) <= 60);
alter table public.comments add column if not exists author_name text check (char_length(author_name) <= 60);

-- 準/唔準 on each note.
create table if not exists public.comment_votes (
  comment_id uuid not null references public.comments(id) on delete cascade,
  voter uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vote smallint not null check (vote in (-1, 0, 1)),
  created_at timestamptz not null default now(),
  primary key (comment_id, voter)
);
alter table public.comment_votes enable row level security;
create policy "read note votes" on public.comment_votes for select to anon, authenticated using (true);
create policy "add note votes" on public.comment_votes for insert to authenticated with check (voter = auth.uid());
create policy "change own note votes" on public.comment_votes for update to authenticated using (voter = auth.uid()) with check (voter = auth.uid());
