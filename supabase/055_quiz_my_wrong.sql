-- 055：錯題重溫（用戶建議，主人 11月14日）。只回自己答錯過嘅題（已經答過，所以畀返答案同老師解釋冇問題）。
create or replace function public.quiz_my_wrong() returns table(qid text, pick int, ans int, why text, at timestamptz)
language sql stable security definer set search_path = public as $$
  select a.qid, a.pick::int, k.ans::int, k.why, a.at
  from quiz_answers a join quiz_key k on k.qid = a.qid
  where a.user_id = auth.uid() and auth.uid() is not null and not a.correct
  order by a.at desc limit 300
$$;
revoke execute on function public.quiz_my_wrong() from public, anon;
grant execute on function public.quiz_my_wrong() to authenticated;
select '055 completed' as status;
