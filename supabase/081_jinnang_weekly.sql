-- 081 隱師錦囊（主人 11月26日）：小測驗、基本功、八字盲測都有錦囊；每個測驗每星期每種錦囊用一次（三種），星期一香港時間重新計；小測驗、基本功 2026-11-30（星期一）00:00 香港時間先開，盲測即刻開
-- 錦囊由伺服器記數（jn_use），答題時每題記低用咗幾多個（jn），排行榜顯示，同分少用錦囊排先
alter table quiz_answers add column if not exists jn int not null default 0;
alter table bf_rounds add column if not exists jn int not null default 0;

create table if not exists jn_use (id bigserial primary key, user_id uuid not null, game text not null, qid text not null, kind text not null, at timestamptz not null default now());
create index if not exists jn_use_u on jn_use(user_id, game, at);
alter table jn_use enable row level security;

create or replace function public.jn_my()
 returns json language sql stable security definer set search_path to 'public' as $function$
  select json_build_object('open', now() >= timestamptz '2026-11-29 16:00+00', 'bopen', true,
    'quiz', coalesce((select json_agg(distinct kind) from jn_use where user_id = auth.uid() and game = 'quiz' and at >= quiz_week()), '[]'::json),
    'bf', coalesce((select json_agg(distinct kind) from jn_use where user_id = auth.uid() and game = 'bf' and at >= quiz_week()), '[]'::json),
    'blind', coalesce((select json_agg(distinct kind) from jn_use where user_id = auth.uid() and game = 'blind' and at >= quiz_week()), '[]'::json))
$function$;
revoke all on function public.jn_my() from public, anon;
grant execute on function public.jn_my() to authenticated;

-- 用一個錦囊：同一題同一款重複撳唔再扣；呢款今個星期用過（第二題）就 ok=false
create or replace function public.jn_take(p_game text, p_qid text, p_kind text)
 returns json language plpgsql security definer set search_path to 'public' as $function$
declare used boolean; again boolean; k smallint; r json := '{}'::json;
begin
  if auth.uid() is null then raise exception 'login required'; end if;
  if p_game not in ('quiz', 'bf', 'blind') or p_kind not in ('swap', 'fifty', 'poll', 'hint', 'kj') then raise exception 'bad lifeline'; end if;
  if p_game <> 'blind' and now() < timestamptz '2026-11-29 16:00+00' then return json_build_object('ok', false, 'why', 'soon'); end if;
  perform pg_advisory_xact_lock(hashtext('jn' || auth.uid()::text));
  select exists (select 1 from jn_use where user_id = auth.uid() and game = p_game and qid = p_qid and kind = p_kind and at >= quiz_week()) into again;
  select exists (select 1 from jn_use where user_id = auth.uid() and game = p_game and kind = p_kind and at >= quiz_week()) into used;
  if used and not again then return json_build_object('ok', false, 'why', 'used'); end if;
  if p_game = 'quiz' and p_kind = 'fifty' then
    select ans into k from quiz_key where qid = p_qid;
    if k is null then raise exception 'no such question'; end if;
    -- 每人每題固定刪同樣兩個，重複撳都唔會爆多啲
    select json_build_object('rm', (array_agg(i order by md5(auth.uid()::text || p_qid || i::text)))[1:2]) into r from generate_series(0, 3) i where i <> k;
  elsif p_game = 'quiz' and p_kind = 'poll' then
    select json_build_object('c', array_agg((select count(*) from quiz_answers a where a.qid = p_qid and a.pick = i and a.user_id <> auth.uid())::int order by i)) into r from generate_series(0, 3) i;
  elsif p_game = 'blind' and p_kind = 'poll' then
    select json_build_object('a', count(*) filter (where pick = 0), 'b', count(*) filter (where pick = 1)) into r
    from (select distinct on (user_id) user_id, pick from blind_answers where qid = p_qid and user_id <> auth.uid() order by user_id, at) t;
  end if;
  -- 冇人答過就唔扣錦囊
  if p_game = 'quiz' and p_kind = 'poll' and (select sum(x::int) from json_array_elements_text(r->'c') x) = 0 then return json_build_object('ok', true, 'd', r, 'free', true); end if;
  if not again then insert into jn_use(user_id, game, qid, kind) values (auth.uid(), p_game, p_qid, p_kind); end if;
  return json_build_object('ok', true, 'd', r);
end $function$;
revoke all on function public.jn_take(text, text, text) from public, anon;
grant execute on function public.jn_take(text, text, text) to authenticated;

-- 080 嘅 blind_poll 改由 jn_take 計數，唔再直接畀人用
revoke all on function public.blind_poll(text) from public, anon, authenticated;

create or replace function public.blind_answer(p_qid text, p_pick integer, p_score boolean, p_jn integer)
 returns json language plpgsql security definer set search_path to 'public' as $function$
declare k blind_key; c int; sc boolean := false; j int;
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
  select count(*) into j from jn_use where user_id = auth.uid() and game = 'blind' and qid = p_qid and at > now() - interval '1 day';
  insert into blind_answers(user_id, qid, pick, ok, scored, jn) values (auth.uid(), p_qid, p_pick, p_pick = k.ans, sc, greatest(0, least(3, greatest(j, coalesce(p_jn, 0)))));
  return json_build_object('ans', k.ans, 'x', k.x, 'y', k.y, 'saved', sc, 'n', c);
end $function$;

create or replace function public.quiz_answer(p_qid text, p_pick integer, p_jn integer)
 returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare k smallint; w text; n int; td int; cap constant int := 50; j int;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false); end if;
  select ans, why into k, w from quiz_key where qid = p_qid;
  if k is null then return jsonb_build_object('ok', false); end if;
  select count(*) into td from quiz_answers where user_id = auth.uid() and scored
    and at >= date_trunc('week', now() at time zone 'Asia/Hong_Kong') at time zone 'Asia/Hong_Kong';
  select count(*) into j from jn_use where user_id = auth.uid() and game = 'quiz' and qid = p_qid and at > now() - interval '1 day';
  j := greatest(0, least(3, greatest(j, coalesce(p_jn, 0))));
  insert into quiz_answers as a (user_id, qid, pick, correct, scored, jn) values (auth.uid(), p_qid, p_pick, p_pick = k, td < cap, j)
    on conflict (user_id, qid) do update set pick = excluded.pick, correct = excluded.correct, scored = excluded.scored, jn = excluded.jn, at = now()
      where a.at < now() - interval '30 days';
  get diagnostics n = row_count;
  return jsonb_build_object('ok', true, 'first', n = 1, 'scored', n = 1 and td < cap,
    'today', least(cap, td + case when n = 1 and td < cap then 1 else 0 end), 'cap', cap, 'ans', k, 'why', w);
end $function$;
revoke all on function public.quiz_answer(text, integer, integer) from public, anon;
grant execute on function public.quiz_answer(text, integer, integer) to authenticated;

-- 狀元榜：同分用少錦囊嘅排先，再睇答啱率
create or replace function public.quiz_rank(p_from timestamp with time zone)
 returns table(uid uuid, name text, title text, score integer, n integer, rk integer)
 language sql stable security definer set search_path to 'public' as $function$
  with g as (
    select a.user_id, count(*) filter (where a.correct)::int as score, count(*)::int as n, sum(a.jn)::int as jn
    from quiz_answers a
    where a.scored and (p_from is null or a.at >= p_from) and not exists (select 1 from quiz_hidden h where h.user_id = a.user_id)
    group by a.user_id)
  select g.user_id,
         (select left(btrim(v), 30) from unnest(array[au.raw_user_meta_data->>'full_name', au.raw_user_meta_data->>'name']) with ordinality t(v, o)
          where v is not null and btrim(v) <> '' and v !~ '@' order by o limit 1),
         coalesce((select t.title from user_titles t where t.user_id = g.user_id), '師兄'),
         g.score, g.n,
         dense_rank() over (order by g.score desc, g.jn asc, g.score::float / g.n desc)::int
  from g left join auth.users au on au.id = g.user_id where g.score > 0
$function$;

create or replace function public.quiz_board3(p_period text)
 returns table(rk integer, name text, title text, score integer, n integer, me boolean, champ integer, mchamp integer, jn integer)
 language sql stable security definer set search_path to 'public' as $function$
  select r.rk, r.name, r.title, r.score, r.n, r.uid = auth.uid(),
         (select c.rk from quiz_champ_ids('week') c where c.uid = r.uid),
         (select c.rk from quiz_champ_ids('month') c where c.uid = r.uid),
         (select coalesce(sum(a.jn), 0)::int from quiz_answers a where a.user_id = r.uid and a.scored
            and a.at >= case p_period when 'month' then quiz_month() else quiz_week() end)
  from quiz_rank(case p_period when 'month' then quiz_month() when 'week' then quiz_week() end) r
  order by r.rk
$function$;
revoke all on function public.quiz_board3(text) from public, anon;
grant execute on function public.quiz_board3(text) to authenticated;

create or replace function public.bf_answer(p_ok boolean, p_jn integer)
 returns json language plpgsql security definer set search_path to 'public' as $function$
declare c int;
begin
  if auth.uid() is null then raise exception 'login required'; end if;
  perform pg_advisory_xact_lock(hashtext('bf' || auth.uid()::text));
  select coalesce(sum(n), 0) into c from bf_rounds where user_id = auth.uid() and at >= quiz_week();
  if c >= 50 then return json_build_object('saved', false, 'n', c); end if;
  insert into bf_rounds(user_id, ok, n, jn) values (auth.uid(), case when p_ok then 1 else 0 end, 1, greatest(0, least(3, coalesce(p_jn, 0))));
  return json_build_object('saved', true, 'n', c + 1);
end $function$;
revoke all on function public.bf_answer(boolean, integer) from public, anon;
grant execute on function public.bf_answer(boolean, integer) to authenticated;

create or replace function public.bf_board2(p_period text)
 returns table(rk integer, name text, title text, score integer, n integer, rounds integer, jn integer, me boolean)
 language sql stable security definer set search_path to 'public' as $function$
  with g as (
    select r.user_id, sum(r.ok)::int as score, sum(r.n)::int as n, count(*)::int as rounds, sum(r.jn)::int as jn
    from bf_rounds r
    where r.at >= case p_period when 'month' then quiz_month() else quiz_week() end
      and not exists (select 1 from quiz_hidden h where h.user_id = r.user_id)
    group by r.user_id),
  k as (
    select g.*, dense_rank() over (order by g.score desc, g.jn asc, g.score::float / g.n desc)::int as rk from g where g.score > 0)
  select k.rk,
         (select left(btrim(v), 30) from unnest(array[au.raw_user_meta_data->>'full_name', au.raw_user_meta_data->>'name']) with ordinality t(v, o)
          where v is not null and btrim(v) <> '' and v !~ '@' order by o limit 1),
         coalesce((select t.title from user_titles t where t.user_id = k.user_id), '師兄'),
         k.score, k.n, k.rounds, k.jn, k.user_id = auth.uid()
  from k left join auth.users au on au.id = k.user_id
  where k.rk <= 20 or k.user_id = auth.uid() order by k.rk
$function$;
revoke all on function public.bf_board2(text) from public, anon;
grant execute on function public.bf_board2(text) to authenticated;

select '081 completed';
