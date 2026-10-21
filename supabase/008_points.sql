-- 008：貢獻分（新用戶一開始有 100 分）。分數每次即時計。命例或者筆記一旦夠 3 個準，就記低（point_awards），之後有人撤回準都唔扣分；命例或者筆記刪咗先冇分。
--   命例：有 3 個或以上其他人撳「準」，命例主人 +100；每個事件 +20（每個命例最多計 5 個）；標籤唔加分，免得有人亂加標籤
--   投票：喺唔屬於自己嘅命例撳準或者唔準，每個命例 +10，每日（香港時間）最多計 5 個（改票都係計一次，撤回都唔扣）
--   防假帳號（暫時閂咗）：將 voter_ok 入面嘅 0 days 改做 7 days，註冊未夠 7 日嘅帳號撳嘅準就唔計入 3 個準
--   筆記：一條筆記有 3 個或以上其他人撳「準」，寫筆記嘅人 +30
--   留言版：每條留言（包括回覆）+5，每日（香港時間）最多計 2 條；刪咗嘅留言唔計
-- 事件只有命例主人（同管理員）改得，所以計俾命例主人。
-- 用分：等級本身有嘅功能唔扣分（進階用戶：招感殺星；高級用戶：招感殺星、最強五行；管理員：全部）。
--   冇嗰個等級就用分換，每個盤（同一組出生資料）每日每個功能扣一次：招感殺星 1、最強五行 2、做功 3（做功除咗管理員人人都扣）。
--   只可以經 spend_points() 扣，佢會檢查等級同分數夠唔夠，網頁冇得自己改。
-- 登入咗嘅用戶先睇到排行榜；管理員唔上榜；唔會顯示電郵。要先行過 007_tiers.sql。Run once in the SQL Editor. Safe to run again.

create table if not exists public.point_spends (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  kind text not null check (kind in ('sha', 'sw', 'work')),
  chart text not null check (char_length(chart) between 1 and 200),
  day date not null default (now() at time zone 'Asia/Hong_Kong')::date,
  cost int not null check (cost >= 0),
  created_at timestamptz not null default now(),
  unique (user_id, kind, chart, day)
);
alter table public.point_spends enable row level security;
drop policy if exists "see own spends" on public.point_spends;
create policy "see own spends" on public.point_spends for select to authenticated using (user_id = auth.uid() or public.is_admin());
revoke all on public.point_spends from anon, authenticated;
grant select on public.point_spends to authenticated;

-- 帳號註冊夠幾多日先計佢撳嘅準；而家係 0（即係全部都計），用戶多咗之後可以改做 7
create or replace function public.voter_ok(u uuid) returns boolean
language sql stable security definer set search_path = public
as $$ select exists (select 1 from auth.users where id = u and created_at <= now() - interval '0 days') $$;
revoke execute on function public.voter_ok(uuid) from public, anon, authenticated;

-- 夠 3 個準嘅命例同筆記記低喺度，撤回準都唔會刪
create table if not exists public.point_awards (
  kind text not null check (kind in ('case', 'note')),
  ref uuid not null,
  created_at timestamptz not null default now(),
  primary key (kind, ref)
);
alter table public.point_awards enable row level security;
revoke all on public.point_awards from anon, authenticated;
-- 命例或者筆記刪咗就連記錄一齊刪
create or replace function public.award_gc() returns trigger
language plpgsql security definer set search_path = public
as $$ begin
  delete from public.point_awards where kind = tg_argv[0] and ref = old.id; return old;
end $$;
drop trigger if exists award_gc on public.cases;
create trigger award_gc after delete on public.cases for each row execute function public.award_gc('case');
drop trigger if exists award_gc on public.comments;
create trigger award_gc after delete on public.comments for each row execute function public.award_gc('note');

create or replace function public.award_case_trg() returns trigger
language plpgsql security definer set search_path = public
as $$ begin
  if new.vote = 1 and (select count(*) from public.votes v join public.cases c on c.id = v.case_id
                       where v.case_id = new.case_id and v.vote = 1 and v.voter <> c.owner and public.voter_ok(v.voter)) >= 3 then
    insert into public.point_awards (kind, ref) values ('case', new.case_id) on conflict do nothing;
  end if;
  return new;
end $$;
drop trigger if exists award on public.votes;
create trigger award after insert or update on public.votes for each row execute function public.award_case_trg();

create or replace function public.award_note_trg() returns trigger
language plpgsql security definer set search_path = public
as $$ begin
  if new.vote = 1 and (select count(*) from public.comment_votes x join public.comments m on m.id = x.comment_id
                       where x.comment_id = new.comment_id and x.vote = 1 and x.voter <> m.author and public.voter_ok(x.voter)) >= 3 then
    insert into public.point_awards (kind, ref) values ('note', new.comment_id) on conflict do nothing;
  end if;
  return new;
end $$;
drop trigger if exists award on public.comment_votes;
create trigger award after insert or update on public.comment_votes for each row execute function public.award_note_trg();

-- 行呢個檔之前已經夠 3 個準嘅都補記
insert into public.point_awards (kind, ref)
  select 'case', c.id from public.cases c
  where (select count(*) from public.votes v where v.case_id = c.id and v.vote = 1 and v.voter <> c.owner and public.voter_ok(v.voter)) >= 3
  on conflict do nothing;
insert into public.point_awards (kind, ref)
  select 'note', m.id from public.comments m
  where (select count(*) from public.comment_votes x where x.comment_id = m.id and x.vote = 1 and x.voter <> m.author and public.voter_ok(x.voter)) >= 3
  on conflict do nothing;

drop function if exists public.points_board();

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
