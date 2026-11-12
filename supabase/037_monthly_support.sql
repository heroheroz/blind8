-- 037：Ko-fi 月供（每月支持）。每次扣數 Ko-fi 都會通知一次 → 每月一行（照樣每港幣 $1 = 1 分）。
-- 月供嘅行喺鳴謝榜留 35 日（或者照級數，邊個長用邊個），所以只要繼續月供就一直喺榜；取消 plan 之後 35 日自動落榜。
-- 同一位月供支持者只出最新嗰行，唔會重複。
alter table public.supporters add column if not exists recurring boolean default false;

create or replace function public.kofi_support(k text, p jsonb) returns text
language plpgsql security definer set search_path to 'public' as $$
declare tid text := coalesce(nullif(p->>'kofi_transaction_id', ''), nullif(p->>'message_id', ''));
        pub boolean := coalesce((p->>'is_public')::boolean, true);
        nm text := left(nullif(btrim(p->>'from_name'), ''), 30);
        cur text := upper(coalesce(p->>'currency', 'USD'));
        rec boolean := lower(coalesce(p->>'is_subscription_payment', '')) = 'true' or lower(coalesce(p->>'type', '')) = 'subscription';
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
  insert into public.supporters(user_id, name, anon, amount, currency, show_amount, method, message, status, kofi_id, recurring)
  values (uid, nm, (not pub) or nm is null, amt, cur, pub, 'kofi',
          case when pub then left(nullif(btrim(p->>'message'), ''), 50) end, 'approved', tid, rec);
  return 'ok';
end $$;

create or replace view public.supporter_ticker as
  select id, approved_at,
         case when anon then null else name end as name,
         case when show_amount then amount end as amount,
         case when show_amount then currency end as currency,
         case when hk >= 500 then 4 when hk >= 200 then 3 when hk >= 50 then 2 else 1 end as tier,
         message, title, rec as recurring
  from (select s.*, coalesce(s.recurring, false) as rec, public.support_hkd(s.amount, s.currency) as hk,
               row_number() over (order by s.approved_at desc) as rn,
               row_number() over (partition by case when coalesce(s.recurring, false)
                                    then coalesce(s.user_id::text, lower(s.name), s.id::text) else s.id::text end
                                  order by s.approved_at desc) as rk
        from public.supporters s where s.status = 'approved') s
  where rk = 1 and (rn <= 5
     or approved_at > now() - make_interval(days => greatest(case when rec then 35 else 0 end,
          case when hk >= 500 then 42 when hk >= 200 then 21 when hk >= 50 then 14 else 7 end)));
grant select on public.supporter_ticker to anon, authenticated;

select '037 completed' as status;
