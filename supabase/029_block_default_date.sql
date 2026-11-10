-- 029：唔畀非管理員加／改做表格預設出生時間 1997-07-01 00:00 嘅命例（好多人忘記改日期）
-- 管理員照樣可以（例如真係香港回歸）；已經存在嘅命例唔受影響
create or replace function public.block_default_case() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  if coalesce((new.input->>'y')::int,0)=1997 and coalesce((new.input->>'m')::int,0)=7 and coalesce((new.input->>'d')::int,0)=1
     and coalesce((new.input->>'h')::int,0)=0 and coalesce((new.input->>'mi')::int,0)=0 and not public.is_admin()
     and (tg_op='INSERT' or old.input is distinct from new.input) then
    raise exception '出生日期時間仲係預設值（1997-07-01 00:00），請輸入正確資料';
  end if;
  return new;
end $$;
drop trigger if exists block_default_case on public.cases;
create trigger block_default_case before insert or update of input on public.cases
  for each row execute function public.block_default_case();

select '029 completed' as status;
