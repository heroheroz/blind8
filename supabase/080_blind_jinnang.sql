-- 080 八字盲測錦囊：每題記低用咗幾多個錦囊；排行榜顯示錦囊數，同分冇用錦囊排先（主人 11月26日）
alter table blind_answers add column if not exists jn int not null default 0;

create or replace function public.blind_answer(p_qid text, p_pick integer, p_score boolean, p_jn integer)
 returns json language plpgsql security definer set search_path to 'public' as $function$
declare k blind_key; c int; sc boolean := false;
begin
  if auth.uid() is null then raise exception 'login required'; end if;
  select * into k from blind_key where qid = p_qid;
  if not found then raise exception 'no such question'; end if;
  perform pg_advisory_xact_lock(hashtext('bm' || auth.uid()::text));
  select count(*) into c from blind_answers where user_id = auth.uid() and scored and at >= quiz_week();
  if coalesce(p_score, false) and c < 50
     and not exists (select 1 from blind_answers where user_id = auth.uid() and qid = p_qid and at >= now() - interval '30 days') then
    sc := true; c := c + 1;
  end if;
  insert into blind_answers(user_id, qid, pick, ok, scored, jn) values (auth.uid(), p_qid, p_pick, p_pick = k.ans, sc, greatest(0, least(3, coalesce(p_jn, 0))));
  return json_build_object('ans', k.ans, 'x', k.x, 'y', k.y, 'saved', sc, 'n', c);
end $function$;
grant execute on function public.blind_answer(text, integer, boolean, integer) to authenticated;

create or replace function public.blind_board2(p_period text)
 returns table(rk integer, name text, title text, score integer, n integer, jn integer, me boolean)
 language sql stable security definer set search_path to 'public' as $function$
  with g as (
    select r.user_id, sum(case when r.ok then 1 else 0 end)::int as score, count(*)::int as n, sum(r.jn)::int as jn
    from blind_answers r
    where r.scored and r.at >= case p_period when 'month' then quiz_month() else quiz_week() end
      and not exists (select 1 from quiz_hidden h where h.user_id = r.user_id)
    group by r.user_id),
  k as (
    select g.*, dense_rank() over (order by g.score desc, g.jn asc, g.score::float / g.n desc)::int as rk from g where g.score > 0)
  select k.rk,
         (select left(btrim(v), 30) from unnest(array[au.raw_user_meta_data->>'full_name', au.raw_user_meta_data->>'name']) with ordinality t(v, o)
          where v is not null and btrim(v) <> '' and v !~ '@' order by o limit 1),
         coalesce((select t.title from user_titles t where t.user_id = k.user_id), '師兄'),
         k.score, k.n, k.jn, k.user_id = auth.uid()
  from k left join auth.users au on au.id = k.user_id
  where k.rk <= 20 or k.user_id = auth.uid() order by k.rk
$function$;
revoke all on function public.blind_board2(text) from public, anon;
grant execute on function public.blind_board2(text) to authenticated;

-- 睇大家點揀：其他人（唔計自己）揀甲揀乙幾多個
create or replace function public.blind_poll(p_qid text)
 returns json language sql stable security definer set search_path to 'public' as $function$
  select json_build_object('a', count(*) filter (where pick = 0), 'b', count(*) filter (where pick = 1))
  from (select distinct on (user_id) user_id, pick from blind_answers
        where qid = p_qid and user_id <> auth.uid() order by user_id, at) t
$function$;
revoke all on function public.blind_poll(text) from public, anon;
grant execute on function public.blind_poll(text) to authenticated;

select '080 completed';
