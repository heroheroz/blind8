-- 012：管理員工具（要先行過 008、009、011）。Run once in the SQL Editor. Safe to run again.
--   一、開戶分同加分門檻：開戶送幾多分（預設 200，之前係 100），同命例同筆記要有幾多個其他人撳「準」先加分，由管理員喺網站「扣分設定」度改，預設 1 個（之前係 3 個）。
--       改細咗門檻，已經夠新門檻嘅命例同筆記即刻記低，之後改大門檻都唔會扣返。
--   做功（將來先開）預設改做 5 分。
--   二、手動加分：管理員喺「手動加分」揀用戶、填分數同原因；填負數就係扣分，撳「取消」可以刪走一筆。
--       用戶睇到自己嘅加分紀錄，管理員睇到全部；每筆都寫入審計紀錄。排行榜同 spend_points 嘅餘額會自動計埋。

-- 一、開戶分同加分門檻
create table if not exists public.point_settings (
  key text primary key check (key in ('need', 'start')),
  value int not null check (value between 0 and 100000),
  updated_at timestamptz not null default now()
);
insert into public.point_settings (key, value) values ('need', 1), ('start', 200) on conflict (key) do nothing;
alter table public.point_settings enable row level security;
drop policy if exists "read settings" on public.point_settings;
create policy "read settings" on public.point_settings for select to anon, authenticated using (true);
drop policy if exists "admins set settings" on public.point_settings;
create policy "admins set settings" on public.point_settings for update to authenticated using (public.is_admin()) with check (public.is_admin());
revoke all on public.point_settings from anon, authenticated;
grant select on public.point_settings to anon, authenticated;
grant update (value, updated_at) on public.point_settings to authenticated;
drop trigger if exists audit on public.point_settings;
create trigger audit after insert or update or delete on public.point_settings for each row execute function public.audit_trg();

create or replace function public.need_votes() returns int
language sql stable security definer set search_path = public
as $$ select greatest(1, coalesce((select value from public.point_settings where key = 'need'), 3)) $$;
grant execute on function public.need_votes() to anon, authenticated;

-- 夠門檻嘅命例同筆記記低（行呢個檔同改門檻嗰陣都會行）
create or replace function public.award_backfill() returns void
language sql volatile security definer set search_path = public
as $$
  insert into public.point_awards (kind, ref)
    select 'case', c.id from public.cases c
    where (select count(*) from public.votes v where v.case_id = c.id and v.vote = 1 and v.voter <> c.owner and public.voter_ok(v.voter)) >= public.need_votes()
    on conflict do nothing;
  insert into public.point_awards (kind, ref)
    select 'note', m.id from public.comments m
    where (select count(*) from public.comment_votes x where x.comment_id = m.id and x.vote = 1 and x.voter <> m.author and public.voter_ok(x.voter)) >= public.need_votes()
    on conflict do nothing;
$$;
revoke execute on function public.award_backfill() from public, anon, authenticated;
create or replace function public.award_backfill_trg() returns trigger
language plpgsql security definer set search_path = public
as $$ begin perform public.award_backfill(); return null; end $$;
drop trigger if exists backfill on public.point_settings;
create trigger backfill after update on public.point_settings for each statement execute function public.award_backfill_trg();

create or replace function public.award_case_trg() returns trigger
language plpgsql security definer set search_path = public
as $$ begin
  if new.vote = 1 and (select count(*) from public.votes v join public.cases c on c.id = v.case_id
                       where v.case_id = new.case_id and v.vote = 1 and v.voter <> c.owner and public.voter_ok(v.voter)) >= public.need_votes() then
    insert into public.point_awards (kind, ref) values ('case', new.case_id) on conflict do nothing;
  end if;
  return new;
end $$;

create or replace function public.award_note_trg() returns trigger
language plpgsql security definer set search_path = public
as $$ begin
  if new.vote = 1 and (select count(*) from public.comment_votes x join public.comments m on m.id = x.comment_id
                       where x.comment_id = new.comment_id and x.vote = 1 and x.voter <> m.author and public.voter_ok(x.voter)) >= public.need_votes() then
    insert into public.point_awards (kind, ref) values ('note', new.comment_id) on conflict do nothing;
  end if;
  return new;
end $$;

select public.award_backfill();

-- 做功（將來先開）改做 5 分；如果管理員已經喺網站改過就唔郁
update public.point_costs set cost = 5, updated_at = now() where kind = 'work' and cost = 3;

-- 二、手動加分
create table if not exists public.point_bonus (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  amount int not null check (amount between -100000 and 100000 and amount <> 0),
  reason text not null default '' check (char_length(reason) <= 200),
  by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists point_bonus_user on public.point_bonus (user_id);
alter table public.point_bonus enable row level security;
drop policy if exists "see bonus" on public.point_bonus;
create policy "see bonus" on public.point_bonus for select to authenticated using (user_id = auth.uid() or public.is_admin());
drop policy if exists "admins add bonus" on public.point_bonus;
create policy "admins add bonus" on public.point_bonus for insert to authenticated with check (public.is_admin() and by = auth.uid());
drop policy if exists "admins remove bonus" on public.point_bonus;
create policy "admins remove bonus" on public.point_bonus for delete to authenticated using (public.is_admin());
revoke all on public.point_bonus from anon, authenticated;
grant select, delete on public.point_bonus to authenticated;
grant insert (user_id, amount, reason) on public.point_bonus to authenticated;
drop trigger if exists audit on public.point_bonus;
create trigger audit after insert or update or delete on public.point_bonus for each row execute function public.audit_trg();

-- 排行榜加多一欄 bonus（手動加分總數），分數計埋佢
drop function if exists public.points_board();

create or replace function public.points_board() returns table (
  user_id uuid, name text, points int, cases int, labels int, events int, votes int, notes int, posts int, spent int, bonus int)
language sql stable security definer set search_path = public
as $$
  with ok as (
    select c.owner as u, least(cardinality(c.tags), 5) as nt,
           least(case when jsonb_typeof(c.input->'events') = 'array' then jsonb_array_length(c.input->'events') else 0 end, 5) as ne
    from public.cases c
    where c.owner is not null
      and (exists (select 1 from public.point_awards a where a.kind = 'case' and a.ref = c.id)
           or (select count(*) from public.votes v where v.case_id = c.id and v.vote = 1 and v.voter <> c.owner and public.voter_ok(v.voter)) >= public.need_votes())),
  cs as (select u, count(*) as n, sum(nt) as t, sum(ne) as e from ok group by u),
  cv as (select u, sum(least(n, 5)) as n from (
           select v.voter as u, (v.created_at at time zone 'Asia/Hong_Kong')::date as d, count(*) as n
           from public.votes v join public.cases c on c.id = v.case_id
           where v.voter is distinct from c.owner group by 1, 2) x group by u),
  nv as (select m.author as u, count(*) as n from public.comments m
         where m.author is not null
           and (exists (select 1 from public.point_awards a where a.kind = 'note' and a.ref = m.id)
                or (select count(*) from public.comment_votes x where x.comment_id = m.id and x.vote = 1 and x.voter <> m.author and public.voter_ok(x.voter)) >= public.need_votes())
         group by m.author),
  gb as (select u, sum(least(n, 2)) as n from (
           select g.author as u, (g.created_at at time zone 'Asia/Hong_Kong')::date as d, count(*) as n
           from public.guestbook g group by 1, 2) x group by u),
  sp as (select p.user_id as u, sum(p.cost) as n from public.point_spends p group by p.user_id),
  bn as (select b.user_id as u, sum(b.amount) as n from public.point_bonus b group by b.user_id),
  us as (select id as u from auth.users)
  select us.u,
         coalesce(nullif(au.raw_user_meta_data->>'full_name', ''), nullif(au.raw_user_meta_data->>'name', ''),
                  (select c.owner_name from public.cases c where c.owner = us.u and c.owner_name <> '' order by c.created_at desc limit 1),
                  (select m.author_name from public.comments m where m.author = us.u and m.author_name <> '' order by m.created_at desc limit 1),
                  '用戶'),
         ((select coalesce((select value from public.point_settings where key = 'start'), 100)) + coalesce(cs.n, 0) * 100 + coalesce(cs.e, 0) * 20 + coalesce(cv.n, 0) * 10 + coalesce(nv.n, 0) * 30 + coalesce(gb.n, 0) * 5 - coalesce(sp.n, 0) + coalesce(bn.n, 0))::int,
         coalesce(cs.n, 0)::int, coalesce(cs.t, 0)::int, coalesce(cs.e, 0)::int, coalesce(cv.n, 0)::int, coalesce(nv.n, 0)::int, coalesce(gb.n, 0)::int, coalesce(sp.n, 0)::int, coalesce(bn.n, 0)::int
  from us
  left join cs on cs.u = us.u
  left join cv on cv.u = us.u
  left join nv on nv.u = us.u
  left join gb on gb.u = us.u
  left join sp on sp.u = us.u
  left join bn on bn.u = us.u
  left join auth.users au on au.id = us.u
  where not exists (select 1 from public.admins a where a.user_id = us.u)
  order by 3 desc, 2
$$;
revoke execute on function public.points_board() from public, anon;
grant execute on function public.points_board() to authenticated;
