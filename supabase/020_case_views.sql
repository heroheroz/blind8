-- 020：審計紀錄記低「邊個打開咗邊個命例」。每次喺網站撳開一個命例，就寫一行 op = 'VIEW' 入 audit_log。
-- 記：邊個（未登入就冇名，只有機號）、幾時、命例 id、名、係咪私人。睇唔到嘅私人命例唔會記。
-- 要先行過 006_stats.sql 同 019_private_cases.sql。Run once in the SQL Editor. Safe to run again.

alter table public.audit_log drop constraint if exists audit_log_op_check;
alter table public.audit_log add constraint audit_log_op_check check (op in ('INSERT', 'UPDATE', 'DELETE', 'LOGIN', 'VIEW'));

-- 使用統計「開命例」記埋係邊個命例
alter table public.usage add column if not exists case_id uuid;

create or replace function public.audit_view_trg() returns trigger
language plpgsql security definer set search_path = public
as $$
declare c record;
begin
  if new.kind = 'case' and new.case_id is not null and public.can_see_case(new.case_id) then
    begin
      select id, name, private, owner_name into c from public.cases where id = new.case_id;
      if found then
        insert into public.audit_log (actor, actor_name, actor_email, tbl, op, row_new)
        values (new.user_id, new.user_name, new.user_email, 'cases', 'VIEW',
                jsonb_build_object('id', c.id, 'name', c.name, 'private', c.private, 'owner_name', c.owner_name, 'anon', new.anon, 'mobile', new.mobile));
      end if;
    exception when others then
      null;  -- 寫唔到紀錄都唔可以阻住人開命例
    end;
  end if;
  return null;
end $$;
drop trigger if exists audit_view on public.usage;
create trigger audit_view after insert on public.usage for each row execute function public.audit_view_trg();

select '020 completed' as status;
