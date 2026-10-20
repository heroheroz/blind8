-- 006：審計紀錄加埋「新用戶註冊」同「用戶登入」、「使用統計」（幾多人用、開咗幾多次網、排咗幾多次盤），同埋用戶可以刪自己加嘅命例。
-- 註冊／登入：auth.users 有新戶口或者 last_sign_in_at 變咗就寫入 audit_log；只記 id、名、電郵同登入方法，唔記密碼或 token。自動續期唔會記。
-- 要先行過 005_audit.sql。Run once in the SQL Editor. Safe to run again.

alter table public.audit_log drop constraint if exists audit_log_op_check;
alter table public.audit_log add constraint audit_log_op_check check (op in ('INSERT', 'UPDATE', 'DELETE', 'LOGIN'));

create or replace function public.audit_auth_trg() returns trigger
language plpgsql security definer set search_path = public
as $$
declare nm text := coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name');
        info jsonb := jsonb_build_object('email', new.email, 'name', nm,
                        'provider', new.raw_app_meta_data->>'provider', 'providers', new.raw_app_meta_data->'providers');
begin
  begin
    if tg_op = 'INSERT' then
      insert into public.audit_log (actor, actor_name, actor_email, tbl, op, row_new)
      values (new.id, nm, new.email, 'users', 'INSERT', info);
    elsif new.last_sign_in_at is distinct from old.last_sign_in_at and new.last_sign_in_at is not null then
      insert into public.audit_log (actor, actor_name, actor_email, at, tbl, op, row_new)
      values (new.id, nm, new.email, new.last_sign_in_at, 'logins', 'LOGIN', info);
    end if;
  exception when others then
    null;  -- 寫唔到紀錄都唔可以阻住人註冊或者登入
  end;
  return new;
end $$;

drop trigger if exists audit_auth on auth.users;
create trigger audit_auth after insert or update of last_sign_in_at on auth.users
  for each row execute function public.audit_auth_trg();

-- 使用統計：每次開網（visit）、撳排盤（chart）、開命例（case）寫一行。
-- 記時間、類別、每部機一個隨機編號（anon）、有登入就記用戶、係咪手機；排盤同開命例仲會記埋出生資料（input）。
-- 任何人都可以寫，只有管理員讀得到（總數經 usage_stats()，逐筆排盤直接讀 usage）。
create table if not exists public.usage (
  id bigserial primary key,
  at timestamptz not null default now(),
  kind text not null check (kind in ('visit', 'chart', 'case')),
  anon text not null check (char_length(anon) between 8 and 40),
  user_id uuid default auth.uid(),
  mobile boolean,
  input jsonb check (input is null or pg_column_size(input) < 4000),
  user_name text,
  user_email text
);
alter table public.usage add column if not exists input jsonb check (input is null or pg_column_size(input) < 4000);
alter table public.usage add column if not exists user_name text;
alter table public.usage add column if not exists user_email text;
create index if not exists usage_kind_at on public.usage (kind, at desc);
create index if not exists usage_at on public.usage (at desc);

alter table public.usage enable row level security;
drop policy if exists "anyone logs usage" on public.usage;
create policy "anyone logs usage" on public.usage for insert to anon, authenticated
  with check (user_id is not distinct from auth.uid());
grant insert on public.usage to anon, authenticated;
grant usage on sequence public.usage_id_seq to anon, authenticated;
drop policy if exists "admins read usage" on public.usage;
create policy "admins read usage" on public.usage for select to authenticated using (public.is_admin());
grant select on public.usage to authenticated;

-- 名同電郵由資料庫自己由 auth.users 填，用戶冒認唔到
create or replace function public.usage_fill() returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  new.user_name := null; new.user_email := null; new.at := now();
  if new.user_id is not null then
    select coalesce(raw_user_meta_data->>'full_name', raw_user_meta_data->>'name'), email
      into new.user_name, new.user_email from auth.users where id = new.user_id;
  end if;
  return new;
end $$;
drop trigger if exists usage_fill on public.usage;
create trigger usage_fill before insert on public.usage for each row execute function public.usage_fill();

create or replace function public.usage_stats() returns jsonb
language plpgsql stable security definer set search_path = public
as $$
declare d0 timestamptz := date_trunc('day', now() at time zone 'Asia/Hong_Kong') at time zone 'Asia/Hong_Kong';
        r jsonb;
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  select jsonb_build_object(
    'periods', (select jsonb_agg(x order by x.ord) from (
        select p.ord, p.label, count(distinct u.anon) as visitors, count(distinct u.user_id) as users,
               count(u.id) filter (where u.kind = 'visit') as visits,
               count(u.id) filter (where u.kind = 'chart') as charts,
               count(u.id) filter (where u.kind = 'case') as cases
        from (values (1, '今日', d0), (2, '7 日', now() - interval '7 days'), (3, '30 日', now() - interval '30 days'),
                     (4, '全部', '-infinity'::timestamptz)) p(ord, label, since)
        left join public.usage u on u.at >= p.since
        group by p.ord, p.label) x),
    'daily', (select coalesce(jsonb_agg(y order by y.day desc), '[]'::jsonb) from (
        select (u.at at time zone 'Asia/Hong_Kong')::date as day, count(distinct u.anon) as visitors, count(distinct u.user_id) as users,
               count(*) filter (where u.kind = 'visit') as visits,
               count(*) filter (where u.kind = 'chart') as charts,
               count(*) filter (where u.kind = 'case') as cases
        from public.usage u where u.at >= d0 - interval '13 days' group by 1) y))
  into r;
  return r;
end $$;
revoke execute on function public.usage_stats() from public, anon;
grant execute on function public.usage_stats() to authenticated;

-- 命例：自己加嘅自己刪得，管理員刪得任何命例
drop policy if exists "admins delete cases" on public.cases;
drop policy if exists "owners or admins delete cases" on public.cases;
create policy "owners or admins delete cases" on public.cases for delete to authenticated
  using (owner = auth.uid() or public.is_admin());
