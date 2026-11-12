-- 044：鳴謝榜頭三名（fx）改做逐個人計：同一個人喺榜上面有幾筆就加埋（主人 11月12日）。
-- 人 = 有戶口用 user_id，冇就用個名。總額一樣就並列（1,2,2,4），過咗期落榜嗰筆唔計。
create or replace view public.supporter_ticker as
  select id, approved_at, name, amount, currency, tier, message, title, recurring, created_at,
         case when rf <= 3 then rf::int end as fx
  from (
    select y.*, 1 + sum(isfirst) over (order by tot desc range between unbounded preceding and current row)
                  - sum(isfirst) over (partition by tot) as rf
    from (
      select z.*, sum(hk) over (partition by pkey) as tot,
             case when row_number() over (partition by pkey order by created_at) = 1 then 1 else 0 end as isfirst
      from (
        select s.id, s.approved_at,
               case when s.anon then null else s.name end as name,
               case when s.show_amount then s.amount end as amount,
               case when s.show_amount then s.currency end as currency,
               case when hk >= 500 then 4 when hk >= 200 then 3 when hk >= 50 then 2 else 1 end as tier,
               s.message, s.title, s.rec as recurring, s.created_at, s.hk,
               coalesce(s.user_id::text, lower(btrim(s.name)), s.id::text) as pkey
        from (select s.*, coalesce(s.recurring, false) as rec, public.support_hkd(s.amount, s.currency) as hk,
                     row_number() over (order by s.approved_at desc) as rn,
                     row_number() over (partition by case when coalesce(s.recurring, false)
                                          then coalesce(s.user_id::text, lower(s.name), s.id::text) else s.id::text end
                                        order by s.approved_at desc) as rk
              from public.supporters s where s.status = 'approved') s
        where rk = 1 and (rn <= 5
           or approved_at > now() - make_interval(days => greatest(case when rec then 35 else 0 end,
                case when hk >= 500 then 21 when hk >= 200 then 10 when hk >= 50 then 7 else 3 end)))) z) y) x;
grant select on public.supporter_ticker to anon, authenticated;

select '044 completed' as status;
