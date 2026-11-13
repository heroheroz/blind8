-- 050：測驗積分榜加「本月」（每月 1 號 00:00 香港時間起計）
create or replace function public.quiz_month() returns timestamptz language sql stable as
$$ select date_trunc('month', now() at time zone 'Asia/Hong_Kong') at time zone 'Asia/Hong_Kong' $$;

create or replace function public.quiz_board_p(p_period text) returns table(rk int, name text, title text, score int, n int, me boolean)
language sql stable security definer set search_path = public as $$
  select r.rk, r.name, r.title, r.score, r.n, r.uid = auth.uid()
  from quiz_rank(case p_period when 'month' then quiz_month() when 'week' then quiz_week() end) r
  where r.rk <= 20 or r.uid = auth.uid() order by r.rk
$$;
grant execute on function public.quiz_board_p(text) to anon, authenticated;

select '050 completed' as status;
