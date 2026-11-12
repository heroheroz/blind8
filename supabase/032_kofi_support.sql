-- 032：Ko-fi 支持自動上鳴謝榜。Ko-fi webhook → edge function kofi-webhook → public.kofi_support(k, p)。
-- 網址入面嘅暗號（app_secrets.kofi_hook）啱先收；同一筆交易只記一次；Ko-fi 電郵同網站登入電郵一樣就自動加貢獻分。
create table if not exists public.app_secrets (key text primary key, value text not null);
alter table public.app_secrets enable row level security;  -- 冇任何 policy：前端讀唔到
insert into public.app_secrets(key, value)
  values ('kofi_hook', replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''))
  on conflict (key) do nothing;

alter table public.supporters add column if not exists kofi_id text;
create unique index if not exists supporters_kofi_id_key on public.supporters(kofi_id);

create or replace function public.supporters_guard() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  if tg_op = 'INSERT' then
    if new.status = 'pending' and not public.is_admin() and (select count(*) from public.supporters
        where status = 'pending' and created_at > now() - interval '1 hour') >= 20 then
      raise exception '太多人同時提交，請遲啲再試';
    end if;
    if auth.uid() is not null and not public.is_admin() then new.user_id := auth.uid(); end if;
    new.name := nullif(btrim(new.name), '');
    new.message := nullif(btrim(new.message), '');
  end if;
  if new.status = 'approved' and new.approved_at is null then new.approved_at := now(); end if;
  return new;
end $$;

create or replace function public.kofi_support(k text, p jsonb) returns text
language plpgsql security definer set search_path to 'public' as $$
declare tid text := coalesce(nullif(p->>'kofi_transaction_id', ''), nullif(p->>'message_id', ''));
        pub boolean := coalesce((p->>'is_public')::boolean, true);
        nm text := left(nullif(btrim(p->>'from_name'), ''), 30);
        cur text := upper(coalesce(p->>'currency', 'USD'));
        amt numeric; uid uuid;
begin
  if k is null or k is distinct from (select value from public.app_secrets where key = 'kofi_hook') then
    raise exception 'forbidden';
  end if;
  if tid is null then return 'no id'; end if;
  if exists (select 1 from public.supporters where kofi_id = tid) then return 'duplicate'; end if;
  begin amt := nullif((p->>'amount')::numeric, 0); exception when others then amt := null; end;
  if cur not in ('HKD','CNY','USD','AUD') then cur := 'OTHER'; end if;
  select id into uid from auth.users where lower(email) = lower(p->>'email') limit 1;
  insert into public.supporters(user_id, name, anon, amount, currency, show_amount, method, message, status, kofi_id)
  values (uid, nm, (not pub) or nm is null, amt, cur, pub, 'kofi',
          case when pub then left(nullif(btrim(p->>'message'), ''), 50) end, 'approved', tid);
  return 'ok';
end $$;

select '032 completed' as status;
