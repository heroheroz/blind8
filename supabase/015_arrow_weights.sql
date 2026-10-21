-- 015：箭咀力度（粘連、啟動、力度嘅箭咀數）
-- 所有人都睇到數值；只有管理員可以改；登入用戶可以投「應該加／應該減」（每人每項一票，可以改或者取消）
-- 喺 Supabase SQL Editor 行一次

create table if not exists public.arrow_weights (
  key text primary key check (key in ('fu','he','lian','banhe','sanhe','zg','zgb','chain','cx','se','yr','sw')),
  value numeric(5,2) not null check (value between 0 and 10),
  updated_at timestamptz not null default now()
);
insert into public.arrow_weights (key, value) values
  ('fu', 1), ('he', 1), ('lian', 0.5), ('banhe', 0.5), ('sanhe', 1), ('zg', 0.5), ('zgb', 0.5),
  ('chain', 1), ('cx', 1), ('se', 0.5), ('yr', 1), ('sw', 1.5)
on conflict (key) do nothing;
alter table public.arrow_weights enable row level security;
drop policy if exists "read arrow weights" on public.arrow_weights;
create policy "read arrow weights" on public.arrow_weights for select to anon, authenticated using (true);
drop policy if exists "admins set arrow weights" on public.arrow_weights;
create policy "admins set arrow weights" on public.arrow_weights for update to authenticated using (public.is_admin()) with check (public.is_admin());
grant select on public.arrow_weights to anon, authenticated;
grant update (value, updated_at) on public.arrow_weights to authenticated;
drop trigger if exists audit on public.arrow_weights;
create trigger audit after insert or update or delete on public.arrow_weights for each row execute function public.audit_trg();

-- 投票：每人每項一票（+1 應該加，-1 應該減）；自己只睇到自己嗰票，總數用 arrow_vote_counts()
create table if not exists public.arrow_votes (
  key text not null references public.arrow_weights(key) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  dir smallint not null check (dir in (-1, 1)),
  at timestamptz not null default now(),
  primary key (key, user_id)
);
alter table public.arrow_votes enable row level security;
drop policy if exists "read own arrow votes" on public.arrow_votes;
create policy "read own arrow votes" on public.arrow_votes for select to authenticated using (user_id = auth.uid());
drop policy if exists "insert own arrow votes" on public.arrow_votes;
create policy "insert own arrow votes" on public.arrow_votes for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "update own arrow votes" on public.arrow_votes;
create policy "update own arrow votes" on public.arrow_votes for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "delete own arrow votes" on public.arrow_votes;
create policy "delete own arrow votes" on public.arrow_votes for delete to authenticated using (user_id = auth.uid());
grant select, insert, delete on public.arrow_votes to authenticated;
grant update (dir, at) on public.arrow_votes to authenticated;

create or replace function public.arrow_vote_counts() returns table (key text, up int, down int)
language sql stable security definer set search_path = public
as $$
  select w.key,
         count(v.*) filter (where v.dir = 1)::int,
         count(v.*) filter (where v.dir = -1)::int
  from public.arrow_weights w left join public.arrow_votes v on v.key = w.key
  group by w.key
$$;
revoke execute on function public.arrow_vote_counts() from public;
grant execute on function public.arrow_vote_counts() to anon, authenticated;
