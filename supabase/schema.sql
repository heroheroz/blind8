-- 盲派八字排盤 shared 命例 backend (Supabase). Run once in the SQL Editor.
-- Everyone can read. Signed-in users can add 命例, vote 準/唔準 and add notes, and edit the 命例 they added.
-- Only admins (listed in public.admins) can delete 命例 or edit other people's 命例.

create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.admins where user_id = auth.uid()) $$;

create table if not exists public.cases (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  owner uuid not null default auth.uid() references auth.users(id) on delete set null,
  owner_name text check (char_length(owner_name) <= 60),
  name text not null check (char_length(name) between 1 and 60),
  input jsonb not null,          -- the birth form: sex, calendar, date, time, place, 子時 rule…
  notes text check (char_length(notes) <= 2000),
  tags text[] not null default '{}' check (cardinality(tags) <= 30)
);

create table if not exists public.votes (
  case_id uuid not null references public.cases(id) on delete cascade,
  voter uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vote smallint not null check (vote in (-1, 0, 1)),                -- 1 準, -1 唔準, 0 withdrawn
  created_at timestamptz not null default now(),
  primary key (case_id, voter)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  case_id uuid not null references public.cases(id) on delete cascade,
  author uuid not null default auth.uid() references auth.users(id) on delete set null,
  author_name text check (char_length(author_name) <= 60),
  body text not null check (char_length(body) between 1 and 2000)
);

alter table public.admins enable row level security;
alter table public.cases enable row level security;
alter table public.votes enable row level security;
alter table public.comments enable row level security;

-- A signed-in user can see whether they themselves are an admin.
create policy "see own admin row" on public.admins for select to authenticated using (user_id = auth.uid());

create policy "read cases" on public.cases for select to anon, authenticated using (true);
create policy "add cases" on public.cases for insert to authenticated with check (owner = auth.uid());
create policy "edit own cases" on public.cases for update to authenticated
  using (owner = auth.uid() or public.is_admin()) with check (owner = auth.uid() or public.is_admin());
create policy "admins delete cases" on public.cases for delete to authenticated using (public.is_admin());
-- Only these columns can be changed from the website.
revoke update on public.cases from anon, authenticated;
grant update (name, input, notes, tags) on public.cases to authenticated;

create policy "read votes" on public.votes for select to anon, authenticated using (true);
create policy "add votes" on public.votes for insert to authenticated with check (voter = auth.uid());
create policy "change own votes" on public.votes for update to authenticated using (voter = auth.uid()) with check (voter = auth.uid());

create policy "read comments" on public.comments for select to anon, authenticated using (true);
create policy "add comments" on public.comments for insert to authenticated with check (author = auth.uid());
create policy "admins delete comments" on public.comments for delete to authenticated using (public.is_admin());

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

-- After you sign up on the website, make yourself admin (put your own sign-up email):
-- insert into public.admins (user_id) select id from auth.users where email = 'you@example.com';

-- Shared tag list (suggestions shown when saving a 命例). Signed-in users add, admins delete.
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
