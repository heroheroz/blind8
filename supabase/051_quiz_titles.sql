-- 051：測驗科舉稱號（主人 11月14日）。唔加貢獻分，淨係稱號。即時由答題記錄計，唔使另外儲存，新一週／新一月自動換人。
-- 本週稱號：上一個星期（星期一 00:00 香港時間起計）頭十名：狀元、榜眼、探花、傳臚、第五至十名進士，戴一個星期。
-- 本月稱號：上一個月（1 號 00:00 香港時間起計）頭三名：本月狀元、榜眼、探花，戴成個月。
-- 要求：嗰段時間最少做咗 10 題計分題、最少答啱 1 題；隱藏名單（quiz_hidden）唔計。
create or replace function public.quiz_champ_ids(p_period text) returns table(uid uuid, rk int)
language sql stable security definer set search_path = public as $$
  with w as (
    select case when p_period = 'month'
                then date_trunc('month', (now() at time zone 'Asia/Hong_Kong') - interval '1 month') at time zone 'Asia/Hong_Kong'
                else quiz_week() - interval '7 days' end as f,
           case when p_period = 'month' then quiz_month() else quiz_week() end as t),
  g as (
    select a.user_id, count(*) filter (where a.correct)::int as score, count(*)::int as n, max(a.at) as last_at
    from quiz_answers a, w
    where a.scored and a.at >= w.f and a.at < w.t
      and not exists (select 1 from quiz_hidden h where h.user_id = a.user_id)
    group by a.user_id
    having count(*) >= 10 and count(*) filter (where a.correct) > 0),
  r as (select g.user_id, row_number() over (order by g.score desc, g.score::float / g.n desc, g.last_at)::int as rk from g)
  select r.user_id, r.rk from r where r.rk <= case when p_period = 'month' then 3 else 10 end
$$;
revoke execute on function public.quiz_champ_ids(text) from public, anon, authenticated;

-- 走馬燈用：上週頭十名（period='week'）同上月頭三名（period='month'）嘅名
create or replace function public.quiz_champs() returns table(period text, rk int, name text, title text)
language sql stable security definer set search_path = public as $$
  select c.period, c.rk,
         (select left(btrim(v), 30) from unnest(array[au.raw_user_meta_data->>'full_name', au.raw_user_meta_data->>'name']) with ordinality t(v, o)
          where v is not null and btrim(v) <> '' and v !~ '@' order by o limit 1),
         coalesce((select t.title from user_titles t where t.user_id = c.uid), '師兄')
  from (select 'month' as period, m.uid, m.rk from quiz_champ_ids('month') m
        union all select 'week', k.uid, k.rk from quiz_champ_ids('week') k) c
  left join auth.users au on au.id = c.uid order by c.period, c.rk
$$;
grant execute on function public.quiz_champs() to anon, authenticated;

-- 積分榜：同 quiz_board_p 一樣，多兩欄：champ（本週稱號名次 1–10）、mchamp（本月稱號名次 1–3）；冇就 null
create or replace function public.quiz_board2(p_period text) returns table(rk int, name text, title text, score int, n int, me boolean, champ int, mchamp int)
language sql stable security definer set search_path = public as $$
  select r.rk, r.name, r.title, r.score, r.n, r.uid = auth.uid(),
         (select c.rk from quiz_champ_ids('week') c where c.uid = r.uid),
         (select c.rk from quiz_champ_ids('month') c where c.uid = r.uid)
  from quiz_rank(case p_period when 'month' then quiz_month() when 'week' then quiz_week() end) r
  where r.rk <= 20 or r.uid = auth.uid() order by r.rk
$$;
grant execute on function public.quiz_board2(text) to anon, authenticated;

select '051 completed' as status;
