-- 038：鳴謝榜都多謝加命例嘅人。public.case_thanks：最近 7 日有加公開命例嘅用戶（管理員唔計、私人命例唔計），每人一行。
-- 名只用網站顯示名（似電郵嘅一律唔出）；命例名淨係登入咗先睇到（命例本身要登入先睇得）。
create or replace view public.case_thanks as
  with g as (
    select c.owner, count(*)::int as n, max(c.created_at) as last_at,
           (array_agg(c.name order by c.created_at desc))[1] as last_case,
           (array_agg(c.owner_name order by c.created_at desc))[1] as oname
    from public.cases c
    where c.owner is not null and not coalesce(c.private, false)
      and c.created_at > now() - interval '7 days'
      and not exists (select 1 from public.admins a where a.user_id = c.owner)
      -- 預設日期（1997-07-01 00:00「香港回歸」）嘅舊命例唔計
      and not (c.input->>'y' = '1997' and c.input->>'m' = '7' and c.input->>'d' = '1' and c.input->>'h' = '0' and c.input->>'mi' = '0')
    group by c.owner)
  select (select left(btrim(v), 30)
          from unnest(array[au.raw_user_meta_data->>'full_name', au.raw_user_meta_data->>'name', g.oname]) with ordinality t(v, o)
          where v is not null and btrim(v) <> '' and v !~ '@' order by o limit 1) as name,
         g.n,
         case when auth.uid() is not null then left(g.last_case, 40) end as last_case,
         g.last_at
  from g left join auth.users au on au.id = g.owner
  order by g.last_at desc limit 20;
grant select on public.case_thanks to anon, authenticated;

select '038 completed' as status;
