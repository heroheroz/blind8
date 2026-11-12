-- 036：鳴謝榜（走馬燈）唔永久出：按級數留唔同日數（☕ 1 星期、🍰 2 星期、🎁 3 星期、👑 6 星期，由確認嗰日計），
-- 最新 5 筆無論幾耐都留，條榜唔會變空。只係唔再喺走馬燈出；supporters 記錄、貢獻值、排行榜唔受影響。
create or replace view public.supporter_ticker as
  select id, approved_at,
         case when anon then null else name end as name,
         case when show_amount then amount end as amount,
         case when show_amount then currency end as currency,
         case when hk >= 500 then 4 when hk >= 200 then 3 when hk >= 50 then 2 else 1 end as tier,
         message, title
  from (select s.*, public.support_hkd(s.amount, s.currency) as hk,
               row_number() over (order by s.approved_at desc) as rn
        from public.supporters s where s.status = 'approved') s
  where rn <= 5
     or approved_at > now() - make_interval(days => case when hk >= 500 then 42 when hk >= 200 then 21 when hk >= 50 then 14 else 7 end);
grant select on public.supporter_ticker to anon, authenticated;

select '036 completed' as status;
