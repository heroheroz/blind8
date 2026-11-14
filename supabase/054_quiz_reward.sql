-- 054：測驗每週獎勵分（主人 11月14日）。每星期一放榜，上一個星期頭五名加貢獻分：500／300／200／100／100。
-- 條件同稱號一樣（quiz_champ_ids：最少做 10 題計分題、隱藏名單唔計）。冇排程器，所以放榜後第一個人開網站（走馬燈讀 quiz_champs）嗰陣順手派，每週每名次只派一次。
create or replace function public.quiz_award() returns void
language plpgsql security definer set search_path = public as $$
declare wk text := to_char((quiz_week() - interval '7 days') at time zone 'Asia/Hong_Kong', 'YYYY-MM-DD');
        amt int[] := array[500, 300, 200, 100, 100]; r record;
begin
  if wk < '2026-11-09' then return; end if;
  if exists (select 1 from point_bonus where reason like 'quiz:w:' || wk || ':%') then return; end if;
  perform pg_advisory_xact_lock(hashtext('quiz_award'));
  if exists (select 1 from point_bonus where reason like 'quiz:w:' || wk || ':%') then return; end if;
  for r in select uid, rk from quiz_champ_ids('week') where rk <= 5 loop
    insert into point_bonus(user_id, amount, reason, by) values (r.uid, amt[r.rk], 'quiz:w:' || wk || ':' || r.rk, null);
  end loop;
end $$;
revoke execute on function public.quiz_award() from public, anon, authenticated;

create or replace function public.quiz_champs() returns table(period text, rk int, name text, title text)
language plpgsql volatile security definer set search_path = public as $$
begin
  begin perform quiz_award(); exception when others then null; end;
  return query
  select c.period, c.rk,
         (select left(btrim(v), 30) from unnest(array[au.raw_user_meta_data->>'full_name', au.raw_user_meta_data->>'name']) with ordinality t(v, o)
          where v is not null and btrim(v) <> '' and v !~ '@' order by o limit 1),
         coalesce((select t.title from user_titles t where t.user_id = c.uid), '師兄')
  from (select 'month' as period, m.uid, m.rk from quiz_champ_ids('month') m
        union all select 'week', k.uid, k.rk from quiz_champ_ids('week') k) c
  left join auth.users au on au.id = c.uid order by c.period, c.rk;
end $$;
grant execute on function public.quiz_champs() to anon, authenticated;
select '054 completed' as status;
