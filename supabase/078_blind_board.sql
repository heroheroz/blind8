-- 078：八字盲測排行榜（主人 11月19日）：每輪 10 題，每星期頭 50 題計分，本週／本月榜，同基本功一樣
-- 答案、名同事實唔再放喺公開嘅 blind.json；答完先由伺服器話你知（blind_key 冇 select 權限，資料唔入 repo）
create table if not exists public.blind_key (
  qid text primary key,
  ans smallint not null check (ans in (0, 1)),
  x jsonb not null,   -- {id, n, f, l}：命例 id、名、事實、標籤
  y jsonb not null
);
alter table public.blind_key enable row level security;
revoke all on public.blind_key from anon, authenticated;

create table if not exists public.blind_answers (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  qid text not null,
  pick smallint not null,
  ok boolean not null,
  scored boolean not null default false,
  at timestamptz not null default now()
);
create index if not exists blind_answers_user_at on public.blind_answers(user_id, at);
create index if not exists blind_answers_at on public.blind_answers(at);
alter table public.blind_answers enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename = 'blind_answers' and policyname = 'blind_answers own read') then
    create policy "blind_answers own read" on public.blind_answers for select to authenticated using (user_id = auth.uid());
  end if;
end $$;

-- 答一題：記低、話返答案同兩個盤係邊個。p_score＝想計分：今個星期未夠 50 題、30 日內冇見過呢題答案先計
create or replace function public.blind_answer(p_qid text, p_pick int, p_score boolean) returns json
language plpgsql security definer set search_path = public as $$
declare k blind_key; c int; sc boolean := false;
begin
  if auth.uid() is null then raise exception 'login required'; end if;
  select * into k from blind_key where qid = p_qid;
  if not found then raise exception 'no such question'; end if;
  perform pg_advisory_xact_lock(hashtext('bm' || auth.uid()::text));
  select count(*) into c from blind_answers where user_id = auth.uid() and scored and at >= quiz_week();
  if coalesce(p_score, false) and c < 50
     and not exists (select 1 from blind_answers where user_id = auth.uid() and qid = p_qid and at >= now() - interval '30 days') then
    sc := true; c := c + 1;
  end if;
  insert into blind_answers(user_id, qid, pick, ok, scored) values (auth.uid(), p_qid, p_pick, p_pick = k.ans, sc);
  return json_build_object('ans', k.ans, 'x', k.x, 'y', k.y, 'saved', sc, 'n', c);
end $$;
revoke all on function public.blind_answer(text, int, boolean) from public, anon;
grant execute on function public.blind_answer(text, int, boolean) to authenticated;

-- 今個星期計咗幾多題，同 30 日內見過答案嘅題目（出題避開）
create or replace function public.blind_my() returns json
language sql stable security definer set search_path = public as $$
  select json_build_object(
    'n', (select count(*) from blind_answers where user_id = auth.uid() and scored and at >= quiz_week()),
    'seen', coalesce((select json_agg(distinct qid) from blind_answers where user_id = auth.uid() and at >= now() - interval '30 days'), '[]'::json))
$$;
revoke all on function public.blind_my() from public, anon;
grant execute on function public.blind_my() to authenticated;

-- 盲測排行榜：本週／本月；唔顯示隱藏咗嘅戶口（管理員、測試戶口），名唔會用電郵
create or replace function public.blind_board(p_period text) returns table(rk int, name text, title text, score int, n int, me boolean)
language sql stable security definer set search_path = public as $$
  with g as (
    select r.user_id, sum(case when r.ok then 1 else 0 end)::int as score, count(*)::int as n, max(r.at) as last_at
    from blind_answers r
    where r.scored and r.at >= case p_period when 'month' then quiz_month() else quiz_week() end
      and not exists (select 1 from quiz_hidden h where h.user_id = r.user_id)
    group by r.user_id),
  k as (
    select g.*, dense_rank() over (order by g.score desc, g.score::float / g.n desc)::int as rk from g where g.score > 0)
  select k.rk,
         (select left(btrim(v), 30) from unnest(array[au.raw_user_meta_data->>'full_name', au.raw_user_meta_data->>'name']) with ordinality t(v, o)
          where v is not null and btrim(v) <> '' and v !~ '@' order by o limit 1),
         coalesce((select t.title from user_titles t where t.user_id = k.user_id), '師兄'),
         k.score, k.n, k.user_id = auth.uid()
  from k left join auth.users au on au.id = k.user_id
  where k.rk <= 20 or k.user_id = auth.uid() order by k.rk
$$;
revoke all on function public.blind_board(text) from public, anon;
grant execute on function public.blind_board(text) to authenticated;

select '078 completed' as status;
