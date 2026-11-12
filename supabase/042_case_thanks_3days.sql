-- 042：加命例嘅感謝由最近 7 日改做最近 3 日（主人 11月12日：每個名淨係出三日，同 ☕ 級支持差唔多）。
-- 名只用網站顯示名（似電郵嘅一律唔出）；命例名淨係登入咗先睇到（命例本身要登入先睇得）。
-- 用戶稱呼（師兄／師姐／'' = 唔加）：未揀嘅當師兄。暫時由管理員入；前端讀唔到（冇 policy），只經 case_thanks 出。

create or replace view public.case_thanks as
  with g as (
    select c.owner, count(*)::int as n, max(c.created_at) as last_at,
           (array_agg(c.name order by c.created_at desc))[1] as last_case,
           (array_agg(c.owner_name order by c.created_at desc))[1] as oname
    from public.cases c
    where c.owner is not null and not coalesce(c.private, false)
      and c.created_at > now() - interval '3 days'
      and not exists (select 1 from public.admins a where a.user_id = c.owner)
      -- 預設日期（1997-07-01 00:00「香港回歸」）嘅舊命例唔計
      and not (c.input->>'y' = '1997' and c.input->>'m' = '7' and c.input->>'d' = '1' and c.input->>'h' = '0' and c.input->>'mi' = '0')
    group by c.owner)
  select (select left(btrim(v), 30)
          from unnest(array[au.raw_user_meta_data->>'full_name', au.raw_user_meta_data->>'name', g.oname]) with ordinality t(v, o)
          where v is not null and btrim(v) <> '' and v !~ '@' order by o limit 1) as name,
         g.n,
         case when auth.uid() is not null then left(g.last_case, 40) end as last_case,
         g.last_at,
         coalesce((select t.title from public.user_titles t where t.user_id = g.owner), '師兄') as title
  from g left join auth.users au on au.id = g.owner
  order by g.last_at desc limit 20;
grant select on public.case_thanks to anon, authenticated;

select '042 completed' as status;
