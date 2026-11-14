-- 064：測驗積分榜唔再限頭 20 名，第 11 名之後全部放喺「睇埋」（主人 11月15日）
CREATE OR REPLACE FUNCTION public.quiz_board2(p_period text)
 RETURNS TABLE(rk integer, name text, title text, score integer, n integer, me boolean, champ integer, mchamp integer)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
  select r.rk, r.name, r.title, r.score, r.n, r.uid = auth.uid(),
         (select c.rk from quiz_champ_ids('week') c where c.uid = r.uid),
         (select c.rk from quiz_champ_ids('month') c where c.uid = r.uid)
  from quiz_rank(case p_period when 'month' then quiz_month() when 'week' then quiz_week() end) r
  order by r.rk
$function$;
select '064 completed' as status;
