-- 062：基本功同狀元挑戰一樣，每答一題即刻計分（主人 11月15日）；每星期頭 50 題計分
alter table public.bf_rounds drop constraint if exists bf_rounds_n_check;
alter table public.bf_rounds alter column n set default 1, add constraint bf_rounds_n_check check (n in (1, 10, 20));

create or replace function public.bf_answer(p_ok boolean) returns json
language plpgsql security definer set search_path = public as $$
declare c int;
begin
  if auth.uid() is null then raise exception 'login required'; end if;
  perform pg_advisory_xact_lock(hashtext('bf' || auth.uid()::text));
  select coalesce(sum(n), 0) into c from bf_rounds where user_id = auth.uid() and at >= quiz_week();
  if c >= 50 then return json_build_object('saved', false, 'n', c); end if;
  insert into bf_rounds(user_id, ok, n) values (auth.uid(), case when p_ok then 1 else 0 end, 1);
  return json_build_object('saved', true, 'n', c + 1);
end $$;
revoke all on function public.bf_answer(boolean) from public, anon;
grant execute on function public.bf_answer(boolean) to authenticated;

-- bf_my：今個星期計咗幾多題（0–50）
create or replace function public.bf_my() returns int
language sql stable security definer set search_path = public as
$$ select coalesce(sum(n), 0)::int from bf_rounds where user_id = auth.uid() and at >= quiz_week() $$;

select '062 completed' as status;
