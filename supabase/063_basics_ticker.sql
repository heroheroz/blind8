-- 063：走馬燈加基本功：本週頭 5 名同過去 24 小時練過嘅人（主人 11月15日），未登入都睇到
create or replace function public.bf_top5() returns table(rk int, name text, title text, score int, n int)
language sql stable security definer set search_path = public as $$
  with g as (
    select r.user_id, sum(r.ok)::int as score, sum(r.n)::int as n, max(r.at) as last_at
    from bf_rounds r
    where r.at >= quiz_week() and not exists (select 1 from quiz_hidden h where h.user_id = r.user_id)
    group by r.user_id),
  k as (select g.*, row_number() over (order by g.score desc, g.score::float / g.n desc, g.last_at)::int as rk from g where g.score > 0)
  select k.rk,
         (select left(btrim(v), 30) from unnest(array[au.raw_user_meta_data->>'full_name', au.raw_user_meta_data->>'name']) with ordinality t(v, o)
          where v is not null and btrim(v) <> '' and v !~ '@' order by o limit 1),
         coalesce((select t.title from user_titles t where t.user_id = k.user_id), '師兄'), k.score, k.n
  from k left join auth.users au on au.id = k.user_id where k.rk <= 5 order by k.rk
$$;
grant execute on function public.bf_top5() to anon, authenticated;

create or replace function public.bf_recent() returns table(name text, title text, n int, last_at timestamptz)
language sql stable security definer set search_path = public as $$
  with g as (
    select r.user_id, sum(r.n)::int as n, max(r.at) as last_at
    from bf_rounds r
    where r.at > now() - interval '24 hours' and not exists (select 1 from quiz_hidden h where h.user_id = r.user_id)
    group by r.user_id)
  select (select left(btrim(v), 30) from unnest(array[au.raw_user_meta_data->>'full_name', au.raw_user_meta_data->>'name']) with ordinality t(v, o)
          where v is not null and btrim(v) <> '' and v !~ '@' order by o limit 1),
         coalesce((select t.title from user_titles t where t.user_id = g.user_id), '師兄'), g.n, g.last_at
  from g left join auth.users au on au.id = g.user_id order by g.last_at desc limit 30
$$;
grant execute on function public.bf_recent() to anon, authenticated;

select '063 completed' as status;
