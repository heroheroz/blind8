-- 019：私人命例。加命例時可以剔「私人」，淨係加入嗰個人同管理員睇到；本人隨時可以轉返公開。
-- 私人命例連埋佢嘅事件投票、筆記、筆記投票都收埋；私人命例唔計分（轉返公開之後照計）。
-- 要先行過 018_no_daily_caps.sql。Run once in the SQL Editor. Safe to run again.

alter table public.cases add column if not exists private boolean not null default false;
grant update (private) on public.cases to authenticated;

-- 呢個人睇唔睇到呢個命例（security definer：唔受 cases 嘅權限影響）
create or replace function public.can_see_case(cid uuid) returns boolean
language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.cases c where c.id = cid and (not c.private or c.owner = auth.uid() or public.is_admin())) $$;
grant execute on function public.can_see_case(uuid) to anon, authenticated;

create or replace function public.can_see_comment(mid uuid) returns boolean
language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.comments m where m.id = mid and public.can_see_case(m.case_id)) $$;
grant execute on function public.can_see_comment(uuid) to anon, authenticated;

-- 命例
drop policy if exists "read cases" on public.cases;
create policy "read cases" on public.cases for select to anon, authenticated
  using (not private or owner = auth.uid() or public.is_admin());

-- 命例投票
drop policy if exists "read votes" on public.votes;
create policy "read votes" on public.votes for select to anon, authenticated using (public.can_see_case(case_id));
drop policy if exists "add votes" on public.votes;
create policy "add votes" on public.votes for insert to authenticated with check (voter = auth.uid() and public.can_see_case(case_id));

-- 筆記
drop policy if exists "read comments" on public.comments;
create policy "read comments" on public.comments for select to anon, authenticated using (public.can_see_case(case_id));
drop policy if exists "add comments" on public.comments;
create policy "add comments" on public.comments for insert to authenticated with check (author = auth.uid() and public.can_see_case(case_id));

-- 筆記投票
drop policy if exists "read note votes" on public.comment_votes;
create policy "read note votes" on public.comment_votes for select to anon, authenticated using (public.can_see_comment(comment_id));
drop policy if exists "add note votes" on public.comment_votes;
create policy "add note votes" on public.comment_votes for insert to authenticated with check (voter = auth.uid() and public.can_see_comment(comment_id));

-- 事件投票
drop policy if exists "read event votes" on public.event_votes;
create policy "read event votes" on public.event_votes for select to anon, authenticated using (public.can_see_case(case_id));
drop policy if exists "add event votes" on public.event_votes;
create policy "add event votes" on public.event_votes for insert to authenticated with check (voter = auth.uid() and public.can_see_case(case_id));

-- 排行榜：私人命例、私人命例上面嘅投票同筆記都唔計分
create or replace function public.points_board() returns table (
  user_id uuid, name text, points int, cases int, labels int, events int, votes int, notes int, posts int, spent int, bonus int, logins int)
language sql stable security definer set search_path = public
as $$
  with ok as (
    select c.owner as u, least(cardinality(c.tags), 5) as nt,
           least(case when jsonb_typeof(c.input->'events') = 'array' then jsonb_array_length(c.input->'events') else 0 end, 5) as ne
    from public.cases c
    where c.owner is not null and not c.private
      and (exists (select 1 from public.point_awards a where a.kind = 'case' and a.ref = c.id)
           or (select count(*) from public.votes v where v.case_id = c.id and v.vote = 1 and v.voter <> c.owner and public.voter_ok(v.voter)) >= public.need_votes())),
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
$$;
revoke execute on function public.points_board() from public, anon;
grant execute on function public.points_board() to authenticated;
