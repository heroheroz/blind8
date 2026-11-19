-- 072：本月稱號擴到第 10 級（本月傳臚、本月進士），同週榜一樣；quiz_champ_uids 畀留言版喺作者名前面出稱號牌（主人 11月16日）
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
  select r.user_id, r.rk from r where r.rk <= 10
$function$;
create or replace function public.quiz_champ_uids() returns table(uid uuid, period text, rk int)
 language sql stable security definer set search_path to 'public' as $$
  select c.uid, 'month', c.rk from quiz_champ_ids('month') c
  union all
  select c.uid, 'week', c.rk from quiz_champ_ids('week') c
$$;
grant execute on function public.quiz_champ_uids() to anon, authenticated;
select '072 completed' as status;
