-- 033：支持加分改做每港幣 $1 = 10 分（Tom 2026-11-12）；可以喺 point_settings 加 key='support' 改比率。
create or replace function public.supporters_points() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare r public.supporters; pts int;
begin
  if tg_op <> 'INSERT' then delete from public.point_bonus where reason = 'support:' || old.id; end if;
  if tg_op = 'DELETE' then return old; end if;
  r := new;
  pts := round(public.support_hkd(r.amount, r.currency) * coalesce((select value from public.point_settings where key = 'support'), 10));
  if r.status = 'approved' and r.user_id is not null and pts > 0 then
    insert into public.point_bonus(user_id, amount, reason) values (r.user_id, least(pts, 1000000), 'support:' || r.id);
  end if;
  return new;
end $$;
select '033 completed' as status;
