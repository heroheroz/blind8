-- 075：記錄用戶開命例／排盤時嘅顯示選項同「計」剔格（主人 11月17日），審計頁管理員先睇到
-- usage.vw = {o:{同預設唔同嘅顯示選項}, x:{閂咗嘅柱 colOff}, c:{盤上有「計」剔格嘅柱:1/0}, h:{填實分開計 柱:"干支" 1/0}, k:{手動改過嘅干支剔格}, cv:計法版本}
-- 新 kind 'vopt'：用戶喺盤上改選項／剔格（5 秒內合併做一次）
alter table public.usage add column if not exists vw jsonb;
alter table public.usage drop constraint if exists usage_kind_check,
  add constraint usage_kind_check check (kind = any (array['visit','chart','case','quiz','basics','lesson','analysis','vopt']));

create or replace function public.view_opt_stats(p_days int default 30, p_all boolean default false)
 returns jsonb language plpgsql stable security definer set search_path to 'public'
as $function$
declare r jsonb;
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  with ex as (  -- 管理員同測試戶口（同埋佢哋用過嘅部機）唔計
      select user_id from public.admins union select id from auth.users where email ilike 'testuser@%'),
    exa as (select distinct anon from public.usage where user_id in (select user_id from ex) and anon is not null),
    base as (
      select u.at, u.kind, u.vw, coalesce(u.user_id::text, 'a:' || u.anon) pk, u.user_id, u.user_name, u.user_email, u.anon, u.mobile
      from public.usage u
      where u.vw is not null and (p_days <= 0 or u.at >= now() - make_interval(days => p_days))
        and (p_all or ((u.user_id is null or u.user_id not in (select user_id from ex)) and (u.anon is null or u.anon not in (select anon from exa))))),
    lat as (select distinct on (pk) * from base order by pk, at desc),
    cnt as (select pk, count(*) filter (where kind <> 'vopt') opens, count(*) filter (where kind = 'vopt') changes from base group by pk)
  select jsonb_build_object(
    'opens', (select count(*) from base where kind <> 'vopt'),
    'changes', (select count(*) from base where kind = 'vopt'),
    'people', (select count(*) from lat),
    'opt', (select coalesce(jsonb_agg(jsonb_build_object('k', k, 'v', v, 'n', n, 'p', p)), '[]') from (
        select e.k, e.v, count(*) filter (where b.kind <> 'vopt') n, count(distinct b.pk) filter (where b.at = l.at) p
        from base b join lat l using (pk), jsonb_each(b.vw->'o') e(k, v) group by 1, 2) z),
    'col', (select coalesce(jsonb_agg(jsonb_build_object('k', k, 'n', n, 'on', o, 'p', p, 'pon', po)), '[]') from (
        select e.k, count(*) filter (where b.kind <> 'vopt') n, count(*) filter (where b.kind <> 'vopt' and e.v = '1') o,
               count(distinct b.pk) filter (where b.at = l.at) p, count(distinct b.pk) filter (where b.at = l.at and e.v = '1') po
        from base b join lat l using (pk), jsonb_each_text(b.vw->'c') e(k, v) group by 1) z),
    'half', (select coalesce(jsonb_agg(jsonb_build_object('k', k, 'n', n, 'g', g, 'z', zz)), '[]') from (
        select e.k, count(*) n, count(*) filter (where left(e.v, 1) = '1') g, count(*) filter (where right(e.v, 1) = '1') zz
        from base b, jsonb_each_text(b.vw->'h') e(k, v) where b.kind <> 'vopt' group by 1) z),
    'users', (select coalesce(jsonb_agg(jsonb_build_object('at', l.at, 'uid', l.user_id, 'name', l.user_name, 'email', l.user_email, 'anon', left(l.anon, 6),
        'mobile', l.mobile, 'opens', c.opens, 'changes', c.changes, 'vw', l.vw) order by l.at desc), '[]')
        from (select * from lat order by at desc limit 300) l join cnt c using (pk)))
  into r;
  return r;
end $function$;
grant execute on function public.view_opt_stats(int, boolean) to authenticated;
select '075 completed';
