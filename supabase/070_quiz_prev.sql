-- 070：放榜之後喺榜度顯示上一期（上星期／上個月）最終名單，同分同級（主人 11月16日）
CREATE OR REPLACE FUNCTION public.quiz_prev(p_period text)
 RETURNS TABLE(rk integer, name text, title text, score integer, n integer, me boolean, f timestamptz, t timestamptz)
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
    group by a.user_id having count(*) filter (where a.correct) > 0),
  r as (select g.*, dense_rank() over (order by g.score desc, g.score::float / g.n desc)::int as rk from g)
  select r.rk,
         (select left(btrim(v), 30) from unnest(array[au.raw_user_meta_data->>'full_name', au.raw_user_meta_data->>'name']) with ordinality t(v, o)
          where v is not null and btrim(v) <> '' and v !~ '@' order by o limit 1),
         coalesce((select t.title from user_titles t where t.user_id = r.user_id), '師兄'),
         r.score, r.n, r.user_id = auth.uid(), w.f, w.t
  from r left join auth.users au on au.id = r.user_id, w
  where r.rk <= 10 order by r.rk
$function$;
grant execute on function public.quiz_prev(text) to anon, authenticated;
select '070 completed' as status;
