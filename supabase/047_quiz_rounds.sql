-- 047：「成功挑戰小測驗」改做：做完一輪 10 題（啱錯都計）先算（主人 11月14日）。走馬燈出過去 24 小時內做完過一輪嘅師兄師姐。
create table if not exists public.quiz_rounds (
  user_id uuid not null references auth.users(id) on delete cascade,
  at timestamptz not null default now(), ok smallint not null default 0, primary key (user_id, at));
alter table public.quiz_rounds enable row level security;

-- 前端做完一輪（第 10 題答完）叫一次；兩分鐘內重複叫唔再記
create or replace function public.quiz_round_done(p_ok int) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return false; end if;
  if exists (select 1 from quiz_rounds where user_id = auth.uid() and at > now() - interval '2 minutes') then return false; end if;
  insert into quiz_rounds(user_id, ok) values (auth.uid(), greatest(0, least(10, coalesce(p_ok, 0))));
  return true;
end $$;
grant execute on function public.quiz_round_done(int) to authenticated;

create or replace function public.quiz_recent() returns table(name text, title text, n int, last_at timestamptz)
language sql stable security definer set search_path = public as $$
  with g as (
    select r.user_id, count(*)::int as n, max(r.at) as last_at
    from quiz_rounds r
    where r.at > now() - interval '24 hours' and not exists (select 1 from quiz_hidden h where h.user_id = r.user_id)
    group by r.user_id)
  select (select left(btrim(v), 30) from unnest(array[au.raw_user_meta_data->>'full_name', au.raw_user_meta_data->>'name']) with ordinality t(v, o)
          where v is not null and btrim(v) <> '' and v !~ '@' order by o limit 1),
         coalesce((select t.title from user_titles t where t.user_id = g.user_id), '師兄'), g.n, g.last_at
  from g left join auth.users au on au.id = g.user_id order by g.last_at desc limit 30
$$;
grant execute on function public.quiz_recent() to anon, authenticated;

select '047 completed' as status;
