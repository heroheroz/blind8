-- 066：同分同級唔跳號（dense_rank），可以雙狀元、雙榜眼、三人同級都得（主人 11月16日）
CREATE OR REPLACE FUNCTION public.quiz_rank(p_from timestamp with time zone)
 RETURNS TABLE(uid uuid, name text, title text, score integer, n integer, rk integer)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
  with g as (
    select a.user_id, count(*) filter (where a.correct)::int as score, count(*)::int as n
    from quiz_answers a
    where a.scored and (p_from is null or a.at >= p_from) and not exists (select 1 from quiz_hidden h where h.user_id = a.user_id)
    group by a.user_id)
  select g.user_id,
         (select left(btrim(v), 30) from unnest(array[au.raw_user_meta_data->>'full_name', au.raw_user_meta_data->>'name']) with ordinality t(v, o)
          where v is not null and btrim(v) <> '' and v !~ '@' order by o limit 1),
         coalesce((select t.title from user_titles t where t.user_id = g.user_id), '師兄'),
         g.score, g.n,
         dense_rank() over (order by g.score desc, g.score::float / g.n desc)::int
  from g left join auth.users au on au.id = g.user_id where g.score > 0
$function$;

CREATE OR REPLACE FUNCTION public.quiz_champ_ids(p_period text)
 RETURNS TABLE(uid uuid, rk integer)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
  with w as (
    select case when p_period = 'month'
                then date_trunc('month', (now() at time zone 'Asia/Hong_Kong') - interval '1 month') at time zone 'Asia/Hong_Kong'
                else quiz_week() - interval '7 days' end as f,
           case when p_period = 'month' then quiz_month() else quiz_week() end as t),
  g as (
    select a.user_id, count(*) filter (where a.correct)::int as score, count(*)::int as n
    from quiz_answers a, w
    where a.scored and a.at >= w.f and a.at < w.t
      and not exists (select 1 from quiz_hidden h where h.user_id = a.user_id)
    group by a.user_id
    having count(*) >= 10 and count(*) filter (where a.correct) > 0),
  r as (select g.user_id, dense_rank() over (order by g.score desc, g.score::float / g.n desc)::int as rk from g)
  select r.user_id, r.rk from r where r.rk <= case when p_period = 'month' then 3 else 10 end
$function$;

CREATE OR REPLACE FUNCTION public.bf_board(p_period text)
 RETURNS TABLE(rk integer, name text, title text, score integer, n integer, rounds integer, me boolean)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
  with g as (
    select r.user_id, sum(r.ok)::int as score, sum(r.n)::int as n, count(*)::int as rounds
    from bf_rounds r
    where r.at >= case p_period when 'month' then quiz_month() else quiz_week() end
      and not exists (select 1 from quiz_hidden h where h.user_id = r.user_id)
    group by r.user_id),
  k as (
    select g.*, dense_rank() over (order by g.score desc, g.score::float / g.n desc)::int as rk from g where g.score > 0)
  select k.rk,
         (select left(btrim(v), 30) from unnest(array[au.raw_user_meta_data->>'full_name', au.raw_user_meta_data->>'name']) with ordinality t(v, o)
          where v is not null and btrim(v) <> '' and v !~ '@' order by o limit 1),
         coalesce((select t.title from user_titles t where t.user_id = k.user_id), '師兄'),
         k.score, k.n, k.rounds, k.user_id = auth.uid()
  from k left join auth.users au on au.id = k.user_id
  where k.rk <= 20 or k.user_id = auth.uid() order by k.rk
$function$;

CREATE OR REPLACE FUNCTION public.bf_top5()
 RETURNS TABLE(rk integer, name text, title text, score integer, n integer)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
  with g as (
    select r.user_id, sum(r.ok)::int as score, sum(r.n)::int as n
    from bf_rounds r
    where r.at >= quiz_week() and not exists (select 1 from quiz_hidden h where h.user_id = r.user_id)
    group by r.user_id),
  k as (select g.*, dense_rank() over (order by g.score desc, g.score::float / g.n desc)::int as rk from g where g.score > 0)
  select k.rk,
         (select left(btrim(v), 30) from unnest(array[au.raw_user_meta_data->>'full_name', au.raw_user_meta_data->>'name']) with ordinality t(v, o)
          where v is not null and btrim(v) <> '' and v !~ '@' order by o limit 1),
         coalesce((select t.title from user_titles t where t.user_id = k.user_id), '師兄'), k.score, k.n
  from k left join auth.users au on au.id = k.user_id where k.rk <= 5 order by k.rk
$function$;

select '066 completed' as status;
