-- 033／034：支持加分比率。試過每港幣 $1 = 10 分，Tom（2026-11-12）定返每港幣 $1 = 1 分。要改比率就改下面 round(...) 嗰行。
create or replace function public.supporters_points() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare r public.supporters; pts int;
begin
  if tg_op <> 'INSERT' then delete from public.point_bonus where reason = 'support:' || old.id; end if;
  if tg_op = 'DELETE' then return old; end if;
  r := new;
  pts := round(public.support_hkd(r.amount, r.currency));
  if r.status = 'approved' and r.user_id is not null and pts > 0 then
    insert into public.point_bonus(user_id, amount, reason) values (r.user_id, least(pts, 100000), 'support:' || r.id);
  end if;
  return new;
end $$;
select '033 completed' as status;
