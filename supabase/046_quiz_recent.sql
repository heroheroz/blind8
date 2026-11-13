-- 046：走馬燈「成功挑戰小測驗」（主人 11月14日）：過去 24 小時內答夠 10 題（即做完一輪）嘅師兄師姐，每人一個名，新排先。
create or replace function public.quiz_recent() returns table(name text, title text, n int, last_at timestamptz)
language sql stable security definer set search_path = public as $$
  with g as (
    select a.user_id, count(*)::int as n, max(a.at) as last_at
    from quiz_answers a
    where a.at > now() - interval '24 hours' and not exists (select 1 from quiz_hidden h where h.user_id = a.user_id)
    group by a.user_id having count(*) >= 10)
  select (select left(btrim(v), 30) from unnest(array[au.raw_user_meta_data->>'full_name', au.raw_user_meta_data->>'name']) with ordinality t(v, o)
          where v is not null and btrim(v) <> '' and v !~ '@' order by o limit 1),
         coalesce((select t.title from user_titles t where t.user_id = g.user_id), '師兄'), g.n, g.last_at
  from g left join auth.users au on au.id = g.user_id order by g.last_at desc limit 30
$$;
grant execute on function public.quiz_recent() to anon, authenticated;

select '046 completed' as status;
