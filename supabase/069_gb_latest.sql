-- 069：走馬燈攞留言版最新一條留言（包括回覆），連埋留言人同被回覆嗰位嘅稱呼（師兄／師姐）
-- user_titles 只係自己睇到，所以用 view（以 owner 權限行）淨係出名同稱呼
create or replace view public.gb_latest as
  select g.author_name as name, t.title, g.body, g.created_at,
         p.author_name as to_name, pt.title as to_title
  from public.guestbook g
  left join public.user_titles t on t.user_id = g.author
  left join public.guestbook p on p.id = g.parent
  left join public.user_titles pt on pt.user_id = p.author
  where coalesce(g.kind, 'msg') = 'msg'
  order by g.created_at desc
  limit 1;
grant select on public.gb_latest to anon, authenticated;
select '069 completed';
