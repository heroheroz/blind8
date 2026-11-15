-- 074：gb_latest 加 author／to_author，走馬燈留言個名前面出稱號牌（主人 11月16日）
create or replace view public.gb_latest as
  select g.author_name as name, t.title, g.body, g.created_at,
         p.author_name as to_name, pt.title as to_title, g.author, p.author as to_author
  from public.guestbook g
  left join public.user_titles t on t.user_id = g.author
  left join public.guestbook p on p.id = g.parent
  left join public.user_titles pt on pt.user_id = p.author
  where coalesce(g.kind, 'msg') = 'msg'
  order by g.created_at desc
  limit 1;
grant select on public.gb_latest to anon, authenticated;
select '074 completed' as status;
