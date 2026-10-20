-- 007：用戶等級。普通用戶（冇紀錄）、進階用戶（advance）、高級用戶（premium）；管理員照舊記喺 public.admins。
-- 「招感殺星」選項只開畀進階用戶、高級用戶同管理員。等級由管理員喺網站「用戶等級」度改，改動會寫入審計紀錄。
-- 要先行過 005_audit.sql。Run once in the SQL Editor. Safe to run again.

create table if not exists public.user_tiers (
  user_id uuid primary key references auth.users(id) on delete cascade,
  tier text not null check (tier in ('advance', 'premium')),
  updated_at timestamptz not null default now()
);
alter table public.user_tiers enable row level security;

-- 用戶睇到自己嘅等級；管理員睇到同改到全部
drop policy if exists "see own tier" on public.user_tiers;
create policy "see own tier" on public.user_tiers for select to authenticated using (user_id = auth.uid() or public.is_admin());
drop policy if exists "admins set tiers" on public.user_tiers;
create policy "admins set tiers" on public.user_tiers for all to authenticated using (public.is_admin()) with check (public.is_admin());
grant select, insert, update, delete on public.user_tiers to authenticated;
revoke all on public.user_tiers from anon;

drop trigger if exists audit on public.user_tiers;
create trigger audit after insert or update or delete on public.user_tiers for each row execute function public.audit_trg();

-- 管理員用：列出所有用戶（名、電郵、註冊同最後登入時間、等級、係咪管理員）
create or replace function public.admin_users() returns table (
  id uuid, email text, name text, created_at timestamptz, last_sign_in_at timestamptz, tier text, admin boolean)
language plpgsql stable security definer set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  return query
    select u.id, u.email::text, coalesce(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name'),
           u.created_at, u.last_sign_in_at, t.tier, exists (select 1 from public.admins a where a.user_id = u.id)
    from auth.users u left join public.user_tiers t on t.user_id = u.id
    order by u.created_at desc;
end $$;
revoke execute on function public.admin_users() from public, anon;
grant execute on function public.admin_users() to authenticated;
