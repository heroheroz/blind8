-- 027：加命例即刻計分（唔使等 👍），之前未計到分嘅命例自動補返（排行榜係即時計，所以改咗就補咗）
-- 私人命例照舊唔計；刪咗嘅命例冇分；事件分跟命例一齊即刻計；筆記照舊要 👍
create or replace function public.points_board()
 returns table(user_id uuid, name text, points integer, cases integer, labels integer, events integer, votes integer, notes integer, posts integer, spent integer, bonus integer, logins integer)
 language sql stable security definer set search_path to 'public'
as $function$
  with ok as (
    select c.owner as u, least(cardinality(c.tags), 5) as nt,
           least(case when jsonb_typeof(c.input->'events') = 'array' then jsonb_array_length(c.input->'events') else 0 end, 5) as ne
    from public.cases c
    where c.owner is not null and not c.private),
  cs as (select u, count(*) as n, sum(nt) as t, sum(ne) as e from ok group by u),
  cv as (select u, sum(least(n, (select nullif(coalesce((select value from public.point_settings where key = 'vday'), 5), 0)))) as n from (
           select v.voter as u, (v.created_at at time zone 'Asia/Hong_Kong')::date as d, count(*) as n
           from public.votes v join public.cases c on c.id = v.case_id
           where v.voter is distinct from c.owner and not c.private group by 1, 2) x group by u),
  nv as (select m.author as u, count(*) as n from public.comments m
         where m.author is not null
           and exists (select 1 from public.cases c where c.id = m.case_id and not c.private)
           and (exists (select 1 from public.point_awards a where a.kind = 'note' and a.ref = m.id)
                or (select count(*) from public.comment_votes x where x.comment_id = m.id and x.vote = 1 and x.voter <> m.author and public.voter_ok(x.voter)) >= public.need_votes())
         group by m.author),
  gb as (select u, sum(least(n, (select nullif(coalesce((select value from public.point_settings where key = 'gday'), 2), 0)))) as n from (
           select g.author as u, (g.created_at at time zone 'Asia/Hong_Kong')::date as d, count(*) as n
           from public.guestbook g group by 1, 2) x group by u),
  sp as (select p.user_id as u, sum(p.cost) as n from public.point_spends p group by p.user_id),
  bn as (select b.user_id as u, sum(b.amount) as n from public.point_bonus b group by b.user_id),
  ck as (select c.user_id as u, count(*) as n from public.point_checkins c group by c.user_id),
  us as (select id as u from auth.users)
  select us.u,
         coalesce(nullif(au.raw_user_meta_data->>'full_name', ''), nullif(au.raw_user_meta_data->>'name', ''),
                  (select c.owner_name from public.cases c where c.owner = us.u and c.owner_name <> '' order by c.created_at desc limit 1),
                  (select m.author_name from public.comments m where m.author = us.u and m.author_name <> '' order by m.created_at desc limit 1),
                  '用戶'),
         ((select coalesce((select value from public.point_settings where key = 'start'), 100)) + coalesce(cs.n, 0) * 100 + coalesce(cs.e, 0) * 20 + coalesce(cv.n, 0) * 10 + coalesce(nv.n, 0) * 30 + coalesce(gb.n, 0) * 5 - coalesce(sp.n, 0) + coalesce(bn.n, 0) + coalesce(ck.n, 0) * (select coalesce((select value from public.point_settings where key = 'daily'), 10)))::int,
         coalesce(cs.n, 0)::int, coalesce(cs.t, 0)::int, coalesce(cs.e, 0)::int, coalesce(cv.n, 0)::int, coalesce(nv.n, 0)::int, coalesce(gb.n, 0)::int, coalesce(sp.n, 0)::int, coalesce(bn.n, 0)::int, coalesce(ck.n, 0)::int
  from us
  left join cs on cs.u = us.u
  left join cv on cv.u = us.u
  left join nv on nv.u = us.u
  left join gb on gb.u = us.u
  left join sp on sp.u = us.u
  left join bn on bn.u = us.u
  left join ck on ck.u = us.u
  left join auth.users au on au.id = us.u
  where not exists (select 1 from public.admins a where a.user_id = us.u)
  order by 3 desc, 2
$function$;

select '027 completed' as status;
