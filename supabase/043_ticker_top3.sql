-- 043：鳴謝榜加 fx：而家喺榜上面嘅支持入面，金額（換港幣）最多嘅頭三位 = 1、2、3（同額就先支持嗰個排先），其他 null。
-- 前端用嚟畀個名特別效果：1 彩虹字、2 金色流光、3 銀色流光，全部加閃星。過咗期（唔喺榜）就唔計。
create or replace view public.supporter_ticker as
  select id, approved_at, name, amount, currency, tier, message, title, recurring, created_at,
         case when rf <= 3 then rf::int end as fx
  from (
  select id, approved_at,
         case when anon then null else name end as name,
         case when show_amount then amount end as amount,
         case when show_amount then currency end as currency,
         case when hk >= 500 then 4 when hk >= 200 then 3 when hk >= 50 then 2 else 1 end as tier,
         message, title, rec as recurring, created_at,
         row_number() over (order by hk desc, created_at asc) as rf
  from (select s.*, coalesce(s.recurring, false) as rec, public.support_hkd(s.amount, s.currency) as hk,
               row_number() over (order by s.approved_at desc) as rn,
               row_number() over (partition by case when coalesce(s.recurring, false)
                                    then coalesce(s.user_id::text, lower(s.name), s.id::text) else s.id::text end
                                  order by s.approved_at desc) as rk
        from public.supporters s where s.status = 'approved') s
  where rk = 1 and (rn <= 5
     or approved_at > now() - make_interval(days => greatest(case when rec then 35 else 0 end,
          case when hk >= 500 then 21 when hk >= 200 then 10 when hk >= 50 then 7 else 3 end)))) z;
grant select on public.supporter_ticker to anon, authenticated;

select '043 completed' as status;
