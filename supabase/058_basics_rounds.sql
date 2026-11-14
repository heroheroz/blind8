-- 058：基本功練習獨立一頁（主人 11月14日）：每輪 20 題，每星期最多 5 輪計分，有自己嘅排行榜（唔入狀元榜）
create table if not exists public.bf_rounds (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  ok int not null check (ok between 0 and 20),
  n int not null default 20 check (n = 20),
  at timestamptz not null default now()
);
create index if not exists bf_rounds_at on public.bf_rounds(at);
alter table public.bf_rounds enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename = 'bf_rounds' and policyname = 'bf_rounds own read') then
    create policy "bf_rounds own read" on public.bf_rounds for select to authenticated using (user_id = auth.uid());
  end if;
end $$;

-- 交一輪成績：今個星期（香港時間星期一起）未夠 5 輪先記
create or replace function public.bf_submit(p_ok int) returns json
language plpgsql security definer set search_path = public as $$
declare c int;
begin
  if auth.uid() is null then raise exception 'login required'; end if;
  perform pg_advisory_xact_lock(hashtext('bf' || auth.uid()::text));
  select count(*) into c from bf_rounds where user_id = auth.uid() and at >= quiz_week();
  if c >= 5 then return json_build_object('saved', false, 'rounds', c); end if;
  insert into bf_rounds(user_id, ok) values (auth.uid(), greatest(0, least(20, coalesce(p_ok, 0))));
  return json_build_object('saved', true, 'rounds', c + 1);
end $$;
revoke all on function public.bf_submit(int) from public, anon;
grant execute on function public.bf_submit(int) to authenticated;

create or replace function public.bf_my() returns int
language sql stable security definer set search_path = public as
$$ select count(*)::int from bf_rounds where user_id = auth.uid() and at >= quiz_week() $$;
revoke all on function public.bf_my() from public, anon;
grant execute on function public.bf_my() to authenticated;

-- 基本功排行榜：本週／本月；同測驗榜一樣唔顯示隱藏咗嘅戶口，名唔會用電郵
create or replace function public.bf_board(p_period text) returns table(rk int, name text, title text, score int, n int, rounds int, me boolean)
language sql stable security definer set search_path = public as $$
  with g as (
    select r.user_id, sum(r.ok)::int as score, sum(r.n)::int as n, count(*)::int as rounds, max(r.at) as last_at
    from bf_rounds r
    where r.at >= case p_period when 'month' then quiz_month() else quiz_week() end
      and not exists (select 1 from quiz_hidden h where h.user_id = r.user_id)
    group by r.user_id),
  k as (
    select g.*, row_number() over (order by g.score desc, g.score::float / g.n desc, g.last_at)::int as rk from g where g.score > 0)
  select k.rk,
         (select left(btrim(v), 30) from unnest(array[au.raw_user_meta_data->>'full_name', au.raw_user_meta_data->>'name']) with ordinality t(v, o)
          where v is not null and btrim(v) <> '' and v !~ '@' order by o limit 1),
         coalesce((select t.title from user_titles t where t.user_id = k.user_id), '師兄'),
         k.score, k.n, k.rounds, k.user_id = auth.uid()
  from k left join auth.users au on au.id = k.user_id
  where k.rk <= 20 or k.user_id = auth.uid() order by k.rk
$$;
revoke all on function public.bf_board(text) from public, anon;
grant execute on function public.bf_board(text) to authenticated;

select '058 completed' as status;
