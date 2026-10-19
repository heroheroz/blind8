-- 留言版: everyone can read; replies point to a top-level message via parent; signed-in users post; authors delete their own, admins delete any.
create table if not exists public.guestbook (
  id uuid primary key default gen_random_uuid(),
  author uuid not null default auth.uid() references auth.users(id) on delete cascade,
  parent uuid references public.guestbook(id) on delete cascade,
  author_name text check (char_length(author_name) <= 60),
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);
alter table public.guestbook enable row level security;
create policy "read guestbook" on public.guestbook for select to anon, authenticated using (true);
create policy "post guestbook" on public.guestbook for insert to authenticated with check (author = auth.uid());
create policy "delete guestbook" on public.guestbook for delete to authenticated using (author = auth.uid() or public.is_admin());
revoke update on public.guestbook from anon, authenticated;
