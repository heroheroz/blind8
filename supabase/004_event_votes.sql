-- 事件 votes: each event on a 命例 (stored in cases.input.events) can be voted 準／唔準.
-- An event is identified by its text and date, e.g. '生死|1052-6-10'.
create table if not exists public.event_votes (
  case_id uuid not null references public.cases(id) on delete cascade,
  ev text not null check (char_length(ev) between 1 and 60),
  voter uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vote smallint not null check (vote in (-1, 0, 1)),
  created_at timestamptz not null default now(),
  primary key (case_id, ev, voter)
);
alter table public.event_votes enable row level security;
create policy "read event votes" on public.event_votes for select to anon, authenticated using (true);
create policy "add event votes" on public.event_votes for insert to authenticated with check (voter = auth.uid());
create policy "change own event votes" on public.event_votes for update to authenticated using (voter = auth.uid()) with check (voter = auth.uid());

select '004 completed' as status;
