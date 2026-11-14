-- 059：錯題重溫可以自己清除，同埋逢星期一 00:00（香港時間）自動清（主人 11月15日）。
-- 只係唔再顯示，quiz_answers 原本記錄（計分、30 日唔重出）完全唔變。
create table if not exists public.quiz_wrong_clear(user_id uuid primary key, at timestamptz not null default now());
alter table public.quiz_wrong_clear enable row level security;
create or replace function public.quiz_wrong_reset() returns timestamptz
language sql volatile security definer set search_path = public as $$
  insert into quiz_wrong_clear(user_id, at) select auth.uid(), now() where auth.uid() is not null
  on conflict (user_id) do update set at = excluded.at
  returning at
$$;
revoke execute on function public.quiz_wrong_reset() from public, anon;
grant execute on function public.quiz_wrong_reset() to authenticated;
create or replace function public.quiz_my_wrong() returns table(qid text, pick int, ans int, why text, at timestamptz)
language sql stable security definer set search_path = public as $$
  select a.qid, a.pick::int, k.ans::int, k.why, a.at
  from quiz_answers a join quiz_key k on k.qid = a.qid
  where a.user_id = auth.uid() and auth.uid() is not null and not a.correct
    and a.at >= (date_trunc('week', now() at time zone 'Asia/Hong_Kong') at time zone 'Asia/Hong_Kong')
    and a.at > coalesce((select c.at from quiz_wrong_clear c where c.user_id = auth.uid()), '-infinity'::timestamptz)
  order by a.at desc limit 300
$$;
select '059 completed' as status;
