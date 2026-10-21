-- 016：箭咀力度加「多個同五行」倍數（預設 ×1）；最強五行三個推論逐個盤投「準／唔準」
-- 要先行咗 015_arrow_weights.sql；喺 Supabase SQL Editor 行一次

alter table public.arrow_weights drop constraint if exists arrow_weights_key_check;
alter table public.arrow_weights add constraint arrow_weights_key_check
  check (key in ('fu','he','lian','banhe','sanhe','zg','zgb','chain','cx','se','yr','sw','sem'));
insert into public.arrow_weights (key, value) values ('sem', 1) on conflict (key) do nothing;

-- 最強五行投票：chart 係出生資料（同網頁 chartKey 一樣），method 係 s1（推論1）、yue（推論2）、sl（推論3）
create table if not exists public.sw_votes (
  chart text not null check (char_length(chart) between 1 and 200),
  method text not null check (method in ('s1', 'yue', 'sl')),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vote smallint not null check (vote in (-1, 1)),
  at timestamptz not null default now(),
  primary key (chart, method, user_id)
);
alter table public.sw_votes enable row level security;
drop policy if exists "read own sw votes" on public.sw_votes;
create policy "read own sw votes" on public.sw_votes for select to authenticated using (user_id = auth.uid());
drop policy if exists "insert own sw votes" on public.sw_votes;
create policy "insert own sw votes" on public.sw_votes for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "update own sw votes" on public.sw_votes;
create policy "update own sw votes" on public.sw_votes for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "delete own sw votes" on public.sw_votes;
create policy "delete own sw votes" on public.sw_votes for delete to authenticated using (user_id = auth.uid());
grant select, insert, delete on public.sw_votes to authenticated;
grant update (vote, at) on public.sw_votes to authenticated;

-- 票數：呢個盤每個推論幾多「準／唔準」，同全站總數
create or replace function public.sw_vote_counts(p_chart text) returns jsonb
language sql stable security definer set search_path = public
as $$
  select jsonb_build_object(
    'chart', coalesce((select jsonb_object_agg(method, jsonb_build_object('up', up, 'down', down)) from (
        select method, count(*) filter (where vote = 1) as up, count(*) filter (where vote = -1) as down
        from public.sw_votes where chart = p_chart group by method) a), '{}'::jsonb),
    'all', coalesce((select jsonb_object_agg(method, jsonb_build_object('up', up, 'down', down)) from (
        select method, count(*) filter (where vote = 1) as up, count(*) filter (where vote = -1) as down
        from public.sw_votes group by method) b), '{}'::jsonb))
$$;
revoke execute on function public.sw_vote_counts(text) from public;
grant execute on function public.sw_vote_counts(text) to anon, authenticated;
