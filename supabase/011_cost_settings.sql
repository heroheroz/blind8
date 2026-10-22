-- 011：扣分數改由管理員喺網站「扣分設定」度改，唔使再行 SQL（要先行過 008、009）。
-- 所有人睇到（網頁顯示要扣幾多分），淨係管理員改到；改動會寫入審計紀錄。Run once in the SQL Editor. Safe to run again.

create table if not exists public.point_costs (
  kind text primary key check (kind in ('sha', 'sw', 'work')),
  cost int not null check (cost between 0 and 1000),
  updated_at timestamptz not null default now()
);
insert into public.point_costs (kind, cost) values ('sha', 1), ('sw', 2), ('work', 3) on conflict (kind) do nothing;
alter table public.point_costs enable row level security;
drop policy if exists "read costs" on public.point_costs;
create policy "read costs" on public.point_costs for select to anon, authenticated using (true);
drop policy if exists "admins set costs" on public.point_costs;
create policy "admins set costs" on public.point_costs for update to authenticated using (public.is_admin()) with check (public.is_admin());
grant select on public.point_costs to anon, authenticated;
grant update (cost, updated_at) on public.point_costs to authenticated;
drop trigger if exists audit on public.point_costs;
create trigger audit after insert or update or delete on public.point_costs for each row execute function public.audit_trg();

-- 用分開功能：扣幾多分睇 point_costs；設做 0 就免費。今日同一個盤開過就唔再扣。回覆 {ok, charged, cost, balance, reason}
create or replace function public.spend_points(p_kind text, p_chart text) returns jsonb
language plpgsql volatile security definer set search_path = public
as $$
declare
  uid uuid := auth.uid();
  c int := (select cost from public.point_costs where kind = p_kind);
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
  if c = 0 then return jsonb_build_object('ok', true, 'charged', false, 'cost', 0); end if;
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

select '011 completed' as status;
