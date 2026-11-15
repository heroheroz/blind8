-- 068：「重溫」——自己今個星期做過嘅所有題目（啱錯都有），逢星期一重新計；hid = 撳過「清除錯題」之前嘅（主人 11月15日）
CREATE OR REPLACE FUNCTION public.quiz_my_review()
 RETURNS TABLE(qid text, pick integer, ans integer, why text, correct boolean, scored boolean, at timestamptz, hid boolean)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
  select a.qid, a.pick::int, k.ans::int, k.why, a.correct, a.scored, a.at,
         a.at <= coalesce((select c.at from quiz_wrong_clear c where c.user_id = auth.uid()), '-infinity'::timestamptz)
  from quiz_answers a join quiz_key k on k.qid = a.qid
  where a.user_id = auth.uid() and auth.uid() is not null and a.at >= quiz_week()
  order by a.at desc limit 2000
$function$;
revoke execute on function public.quiz_my_review() from public, anon;
grant execute on function public.quiz_my_review() to authenticated;
select '068 completed' as status;
