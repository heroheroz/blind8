-- 010：用分再改平（要先行過 009_points_v2.sql）：招感殺星 1 分、最強五行 2 分、做功 4 分。Run once in the SQL Editor. Safe to run again.

-- 用分開功能。今日同一個盤開過就唔再扣。回覆 {ok, charged, cost, balance, reason}
create or replace function public.spend_points(p_kind text, p_chart text) returns jsonb
language plpgsql volatile security definer set search_path = public
as $$
declare
  uid uuid := auth.uid();
  c int := case p_kind when 'sha' then 1 when 'sw' then 2 when 'work' then 4 end;
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
