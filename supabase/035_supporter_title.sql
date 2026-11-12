-- 035：鳴謝榜稱呼（師兄／師姐／有心人），支持者自己揀
alter table public.supporters add column if not exists title text not null default '有心人' check (title in ('師兄','師姐','有心人'));
create or replace view public.supporter_ticker as
  select id, approved_at,
         case when anon then null else name end as name,
         case when show_amount then amount end as amount,
         case when show_amount then currency end as currency,
         case when public.support_hkd(amount, currency) >= 500 then 4 when public.support_hkd(amount, currency) >= 200 then 3
              when public.support_hkd(amount, currency) >= 50 then 2 else 1 end as tier,
         message, title
  from public.supporters where status = 'approved';
select '035 completed' as status;
