-- 061：基本功每輪改做 10 題，每星期 5 輪計分，滿分 50（主人 11月15日）
alter table public.bf_rounds drop constraint if exists bf_rounds_ok_check, drop constraint if exists bf_rounds_n_check;
alter table public.bf_rounds alter column n set default 10,
  add constraint bf_rounds_ok_check check (ok between 0 and 20),
  add constraint bf_rounds_n_check check (n in (10, 20));

create or replace function public.bf_submit(p_ok int) returns json
language plpgsql security definer set search_path = public as $$
declare c int;
begin
  if auth.uid() is null then raise exception 'login required'; end if;
  perform pg_advisory_xact_lock(hashtext('bf' || auth.uid()::text));
  select count(*) into c from bf_rounds where user_id = auth.uid() and at >= quiz_week();
  if c >= 5 then return json_build_object('saved', false, 'rounds', c); end if;
  insert into bf_rounds(user_id, ok, n) values (auth.uid(), greatest(0, least(10, coalesce(p_ok, 0))), 10);
  return json_build_object('saved', true, 'rounds', c + 1);
end $$;

select '061 completed' as status;
