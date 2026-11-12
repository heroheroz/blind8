-- 040：鳴謝榜加 created_at（支持嗰刻嘅時間），等走馬燈可以由最新支持排到最舊（補登嘅記錄 approved_at 一樣，分唔到先後）。
create or replace view public.supporter_ticker as
  select id, approved_at,
         case when anon then null else name end as name,
         case when show_amount then amount end as amount,
         case when show_amount then currency end as currency,
         case when hk >= 500 then 4 when hk >= 200 then 3 when hk >= 50 then 2 else 1 end as tier,
         message, title, rec as recurring, created_at
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


select '040 completed' as status;
