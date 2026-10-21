-- 009：貢獻分調整（要先行過 008_points.sql）。Run once in the SQL Editor. Safe to run again.
--   每個註冊咗嘅用戶一開始有 100 分（登記獎勵）。
--   用分改平：招感殺星 1 分、最強五行 2 分、做功 3 分（每個盤每日扣一次；等級本身有嘅功能照舊免費，管理員全部免費）。
--   其他計分規則同 008 一樣。


create or replace function public.points_board() returns table (
  user_id uuid, name text, points int, cases int, labels int, events int, votes int, notes int, posts int, spent int)
language sql stable security definer set search_path = public
as $$
  with ok as (
    select c.owner as u, least(cardinality(c.tags), 5) as nt,
           least(case when jsonb_typeof(c.input->'events') = 'array' then jsonb_array_length(c.input->'events') else 0 end, 5) as ne
    from public.cases c
    where c.owner is not null
      and (exists (select 1 from public.point_awards a where a.kind = 'case' and a.ref = c.id)
           or (select count(*) from public.votes v where v.case_id = c.id and v.vote = 1 and v.voter <> c.owner and public.voter_ok(v.voter)) >= 3)),
  cs as (select u, count(*) as n, sum(nt) as t, sum(ne) as e from ok group by u),
  cv as (select u, sum(least(n, 5)) as n from (
           select v.voter as u, (v.created_at at time zone 'Asia/Hong_Kong')::date as d, count(*) as n
           from public.votes v join public.cases c on c.id = v.case_id
           where v.voter is distinct from c.owner group by 1, 2) x group by u),
  nv as (select m.author as u, count(*) as n from public.comments m
         where m.author is not null
           and (exists (select 1 from public.point_awards a where a.kind = 'note' and a.ref = m.id)
                or (select count(*) from public.comment_votes x where x.comment_id = m.id and x.vote = 1 and x.voter <> m.author and public.voter_ok(x.voter)) >= 3)
         group by m.author),
  gb as (select u, sum(least(n, 2)) as n from (
           select g.author as u, (g.created_at at time zone 'Asia/Hong_Kong')::date as d, count(*) as n
           from public.guestbook g group by 1, 2) x group by u),
  sp as (select p.user_id as u, sum(p.cost) as n from public.point_spends p group by p.user_id),
  us as (select id as u from auth.users)
  select us.u,
         coalesce(nullif(au.raw_user_meta_data->>'full_name', ''), nullif(au.raw_user_meta_data->>'name', ''),
                  (select c.owner_name from public.cases c where c.owner = us.u and c.owner_name <> '' order by c.created_at desc limit 1),
                  (select m.author_name from public.comments m where m.author = us.u and m.author_name <> '' order by m.created_at desc limit 1),
                  '用戶'),
         (100 + coalesce(cs.n, 0) * 100 + coalesce(cs.e, 0) * 20 + coalesce(cv.n, 0) * 10 + coalesce(nv.n, 0) * 30 + coalesce(gb.n, 0) * 5 - coalesce(sp.n, 0))::int,
         coalesce(cs.n, 0)::int, coalesce(cs.t, 0)::int, coalesce(cs.e, 0)::int, coalesce(cv.n, 0)::int, coalesce(nv.n, 0)::int, coalesce(gb.n, 0)::int, coalesce(sp.n, 0)::int
  from us
  left join cs on cs.u = us.u
  left join cv on cv.u = us.u
  left join nv on nv.u = us.u
  left join gb on gb.u = us.u
  left join sp on sp.u = us.u
  left join auth.users au on au.id = us.u
  where not exists (select 1 from public.admins a where a.user_id = us.u)
  order by 3 desc, 2
$$;
revoke execute on function public.points_board() from public, anon;
grant execute on function public.points_board() to authenticated;

-- 用分開功能。今日同一個盤開過就唔再扣。回覆 {ok, charged, cost, balance, reason}
create or replace function public.spend_points(p_kind text, p_chart text) returns jsonb
language plpgsql volatile security definer set search_path = public
as $$
declare
  uid uuid := auth.uid();
  c int := case p_kind when 'sha' then 1 when 'sw' then 2 when 'work' then 3 end;
  t text;
  bal int;
  today date := (now() at time zone 'Asia/Hong_Kong')::date;
begin
  if uid is null then return jsonb_build_object('ok', false, 'reason', 'login'); end if;
  if c is null or p_chart is null or char_length(p_chart) not between 1 and 200 then raise exception 'bad request'; end if;
  if public.is_admin() then return jsonb_build_object('ok', true, 'charged', false, 'cost', 0); end if;
  select coalesce((select tier from public.user_tiers where user_id = uid), '') into t;
  if (p_kind = 'sha' and t in ('advance', 'premium')) or (p_kind = 'sw' and t = 'premium') then
    return jsonb_build_object('ok', true, 'charged', false, 'cost', 0);
  end if;
  perform pg_advisory_xact_lock(hashtext(uid::text));
  if exists (select 1 from public.point_spends where user_id = uid and kind = p_kind and chart = p_chart and day = today) then
    return jsonb_build_object('ok', true, 'charged', false, 'cost', 0);
  end if;
  select coalesce((select b.points from public.points_board() b where b.user_id = uid), 0) into bal;
  if bal < c then return jsonb_build_object('ok', false, 'reason', 'points', 'cost', c, 'balance', bal); end if;
  insert into public.point_spends (user_id, kind, chart, day, cost) values (uid, p_kind, p_chart, today, c);
  return jsonb_build_object('ok', true, 'charged', true, 'cost', c, 'balance', bal - c);
end $$;
revoke execute on function public.spend_points(text, text) from public, anon;
grant execute on function public.spend_points(text, text) to authenticated;
