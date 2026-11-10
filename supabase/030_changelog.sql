-- 030：留言版分開「留言」同「更新日誌」：guestbook 加 kind（msg＝用戶留言，log＝更新日誌）
-- 將站長幾個戶口（Thomas Chau、heroheroz@hotmail.com、heroheroz#0）喺留言版頂層出嘅帖標做 log；回覆照留喺留言版。唔刪任何嘢。
alter table public.guestbook add column if not exists kind text not null default 'msg';
alter table public.guestbook drop constraint if exists guestbook_kind_check;
alter table public.guestbook add constraint guestbook_kind_check check (kind in ('msg','log'));
update public.guestbook set kind='log'
  where parent is null and author in ('75920ec6-44a9-4d3d-bf11-f138d7e65cdf','ccf63e57-d5b2-4309-be76-4ecfd4bb11e6','c8f873d6-c382-42ae-92d4-71860509317c');
-- 只有管理員可以出更新日誌
create or replace function public.guestbook_log_admin() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  if new.kind='log' and (tg_op='INSERT' or old.kind is distinct from 'log') and not public.is_admin() then
    raise exception '只有管理員可以出更新日誌';
  end if;
  return new;
end $$;
drop trigger if exists guestbook_log_admin on public.guestbook;
create trigger guestbook_log_admin before insert or update of kind on public.guestbook
  for each row execute function public.guestbook_log_admin();

select '030 completed' as status;
