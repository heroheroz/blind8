-- 073：本月榜都派貢獻分，係本週三倍：1500／900／600／300／300（同級各自照級數攞），每月 1 號（香港時間）放榜後派；由 2026-11 月榜起（主人 11月16日）
CREATE OR REPLACE FUNCTION public.quiz_award()
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare wk text := to_char((quiz_week() - interval '7 days') at time zone 'Asia/Hong_Kong', 'YYYY-MM-DD');
        mo text := to_char((now() at time zone 'Asia/Hong_Kong') - interval '1 month', 'YYYY-MM');
        amt int[] := array[500, 300, 200, 100, 100]; r record;
begin
  perform pg_advisory_xact_lock(hashtext('quiz_award'));
  if wk >= '2026-11-09' and not exists (select 1 from point_bonus where reason like 'quiz:w:' || wk || ':%') then
    for r in select uid, rk from quiz_champ_ids('week') where rk <= 5 loop
      insert into point_bonus(user_id, amount, reason, by) values (r.uid, amt[r.rk], 'quiz:w:' || wk || ':' || r.rk, null);
    end loop;
  end if;
  if mo >= '2026-11' and not exists (select 1 from point_bonus where reason like 'quiz:m:' || mo || ':%') then
    for r in select uid, rk from quiz_champ_ids('month') where rk <= 5 loop
      insert into point_bonus(user_id, amount, reason, by) values (r.uid, amt[r.rk] * 3, 'quiz:m:' || mo || ':' || r.rk, null);
    end loop;
  end if;
end $function$;
select '073 completed' as status;
