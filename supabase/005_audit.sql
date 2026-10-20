-- 審計紀錄: every add, change and delete on the shared data is written to public.audit_log,
-- with who did it and the row before and after. Only admins can read it; nobody can edit or delete it from the website.
-- Run once in the SQL Editor. Safe to run again.

create table if not exists public.audit_log (
  id bigserial primary key,
  at timestamptz not null default now(),
  actor uuid,                 -- auth.uid() of whoever made the change (null = SQL Editor / system)
  actor_name text,
  actor_email text,
  tbl text not null,
  op text not null check (op in ('INSERT', 'UPDATE', 'DELETE')),
  row_old jsonb,
  row_new jsonb
);
create index if not exists audit_log_at on public.audit_log (at desc);
create index if not exists audit_log_actor on public.audit_log (actor);

alter table public.audit_log enable row level security;
drop policy if exists "admins read audit" on public.audit_log;
create policy "admins read audit" on public.audit_log for select to authenticated using (public.is_admin());
revoke insert, update, delete on public.audit_log from anon, authenticated;

create or replace function public.audit_trg() returns trigger
language plpgsql security definer set search_path = public
as $$
declare uid uuid := auth.uid(); nm text; em text;
begin
  if uid is not null then
    select coalesce(raw_user_meta_data->>'full_name', raw_user_meta_data->>'name'), email
      into nm, em from auth.users where id = uid;
  end if;
  insert into public.audit_log (actor, actor_name, actor_email, tbl, op, row_old, row_new)
  values (uid, nm, em, tg_table_name, tg_op,
          case when tg_op <> 'INSERT' then to_jsonb(old) end,
          case when tg_op <> 'DELETE' then to_jsonb(new) end);
  return coalesce(new, old);
end $$;

do $$
declare t text;
begin
  foreach t in array array['cases', 'comments', 'guestbook', 'tags', 'votes', 'comment_votes', 'event_votes', 'admins'] loop
    if to_regclass('public.' || t) is not null then
      execute format('drop trigger if exists audit on public.%I', t);
      execute format('create trigger audit after insert or update or delete on public.%I for each row execute function public.audit_trg()', t);
    end if;
  end loop;
end $$;
-- If you run 004_event_votes.sql after this file, run this file again so 事件 votes are logged too.
