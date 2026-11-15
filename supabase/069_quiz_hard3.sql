-- 069：放榜之後，上一期（上星期／上個月）最多人錯嘅三題，連正確答案同幾多人錯（主人 11月16日）
CREATE OR REPLACE FUNCTION public.quiz_hard3(p_period text)
 RETURNS TABLE(qid text, ans integer, why text, wrong integer, total integer, f timestamptz, t timestamptz)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
  with w as (
    select case when p_period = 'month'
                then date_trunc('month', (now() at time zone 'Asia/Hong_Kong') - interval '1 month') at time zone 'Asia/Hong_Kong'
                else quiz_week() - interval '7 days' end as f,
           case when p_period = 'month' then quiz_month() else quiz_week() end as t),
  g as (
    select a.qid, count(*) filter (where not a.correct)::int as wrong, count(*)::int as total
    from quiz_answers a, w
    where a.scored and a.at >= w.f and a.at < w.t
      and not exists (select 1 from quiz_hidden h where h.user_id = a.user_id)
    group by a.qid having count(*) filter (where not a.correct) > 0)
  select g.qid, k.ans::int, k.why, g.wrong, g.total, w.f, w.t
  from g join quiz_key k on k.qid = g.qid, w
  order by g.wrong desc, g.wrong::float / g.total desc, g.qid limit 3
$function$;
grant execute on function public.quiz_hard3(text) to anon, authenticated;
select '069 completed' as status;
