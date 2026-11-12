-- 031：支持者走馬燈。登入咗嘅支持者喺「請飲咖啡」填名／金額／留言（pending），管理員確認收到錢先出街（approved）。
-- 公眾只可以經 supporter_ticker 睇已確認嘅；唔公開金額／匿名嘅資料唔會經呢個 view 出街。
create table if not exists public.supporters (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id uuid default auth.uid(),
  name text check (char_length(name) <= 30),
  anon boolean not null default false,
  amount numeric check (amount is null or (amount > 0 and amount < 1000000)),
  currency text not null default 'HKD' check (currency in ('HKD','CNY','USD','AUD','OTHER')),
  show_amount boolean not null default true,
  method text not null check (method in ('kofi','fps','ahk','acn','wcn')),
  message text check (char_length(message) <= 50),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  approved_at timestamptz
);
alter table public.supporters enable row level security;

drop policy if exists supporters_admin_select on public.supporters;
create policy supporters_admin_select on public.supporters for select using (public.is_admin());
drop policy if exists supporters_insert on public.supporters;
create policy supporters_insert on public.supporters for insert to authenticated
  with check (auth.uid() is not null and (public.is_admin() or (status = 'pending' and approved_at is null)));
drop policy if exists supporters_admin_update on public.supporters;
create policy supporters_admin_update on public.supporters for update using (public.is_admin()) with check (public.is_admin());
drop policy if exists supporters_admin_delete on public.supporters;
create policy supporters_admin_delete on public.supporters for delete using (public.is_admin());

grant select, insert, update, delete on public.supporters to authenticated;

-- 防洗版：一個鐘內最多 20 條未確認；確認時自動寫 approved_at
create or replace function public.supporters_guard() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  if tg_op = 'INSERT' then
    if not public.is_admin() and (select count(*) from public.supporters
        where status = 'pending' and created_at > now() - interval '1 hour') >= 20 then
      raise exception '太多人同時提交，請遲啲再試';
    end if;
    if not public.is_admin() then new.user_id := auth.uid(); end if;
    new.name := nullif(btrim(new.name), '');
    new.message := nullif(btrim(new.message), '');
  end if;
  if new.status = 'approved' and new.approved_at is null then new.approved_at := now(); end if;
  return new;
end $$;
drop trigger if exists supporters_guard on public.supporters;
create trigger supporters_guard before insert or update on public.supporters
  for each row execute function public.supporters_guard();

-- 金額折做港幣（大約），用嚟定等級同貢獻分
create or replace function public.support_hkd(amount numeric, currency text) returns numeric
language sql immutable as $$
  select coalesce(amount, 0) * case currency when 'CNY' then 1.1 when 'USD' then 7.8 when 'AUD' then 5 else 1 end $$;

-- 確認咗、而且支持者登入咗：每港幣 1 元 = 1 貢獻分（入 point_bonus，排行榜自動計）。改金額／取消確認／刪除都會跟住改。
create or replace function public.supporters_points() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare r public.supporters; pts int;
begin
  if tg_op <> 'INSERT' then delete from public.point_bonus where reason = 'support:' || old.id; end if;
  if tg_op = 'DELETE' then return old; end if;
  r := new; pts := round(public.support_hkd(r.amount, r.currency));
  if r.status = 'approved' and r.user_id is not null and pts > 0 then
    insert into public.point_bonus(user_id, amount, reason) values (r.user_id, least(pts, 100000), 'support:' || r.id);
  end if;
  return new;
end $$;
drop trigger if exists supporters_points on public.supporters;
create trigger supporters_points after insert or update or delete on public.supporters
  for each row execute function public.supporters_points();

-- 等級：1 ☕（$50 以下或者冇填）、2 🍰（$50–199）、3 🎁（$200–499）、4 👑（$500 以上）
create or replace view public.supporter_ticker as
  select id, approved_at,
         case when anon then null else name end as name,
         case when show_amount then amount end as amount,
         case when show_amount then currency end as currency,
         case when public.support_hkd(amount, currency) >= 500 then 4 when public.support_hkd(amount, currency) >= 200 then 3
              when public.support_hkd(amount, currency) >= 50 then 2 else 1 end as tier,
         message
  from public.supporters where status = 'approved';
grant select on public.supporter_ticker to anon, authenticated;

select '031 completed' as status;
