-- 060：使用統計加「基本功答題」（主人 11月15日）
alter table public.usage drop constraint if exists usage_kind_check,
  add constraint usage_kind_check check (kind = any (array['visit','chart','case','quiz','basics','lesson','analysis']));

create or replace function public.usage_stats()
 returns jsonb language plpgsql stable security definer set search_path to 'public'
as $function$
declare d0 timestamptz := date_trunc('day', now() at time zone 'Asia/Hong_Kong') at time zone 'Asia/Hong_Kong';
        r jsonb;
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  select jsonb_build_object(
    'periods', (select jsonb_agg(x order by x.ord) from (
        select p.ord, p.label, count(distinct u.anon) as visitors, count(distinct u.user_id) as users,
               (select count(*) from (select g.anon from public.usage g where g.at >= p.since group by g.anon having bool_and(g.user_id is null)) z) as guests,
               count(u.id) filter (where u.kind = 'visit') as visits,
               count(u.id) filter (where u.kind = 'chart') as charts,
               count(u.id) filter (where u.kind = 'case') as cases,
               count(u.id) filter (where u.kind = 'quiz') as quiz,
               count(u.id) filter (where u.kind = 'basics') as basics,
               count(u.id) filter (where u.kind = 'lesson') as lessons,
               count(u.id) filter (where u.kind = 'analysis') as analysis
        from (values (1, '今日', d0), (2, '7 日', now() - interval '7 days'), (3, '30 日', now() - interval '30 days'),
                     (4, '全部', '-infinity'::timestamptz)) p(ord, label, since)
        left join public.usage u on u.at >= p.since
        group by p.ord, p.label, p.since) x),
    'daily', (select coalesce(jsonb_agg(y order by y.day desc), '[]'::jsonb) from (
        select a.day, count(distinct a.anon) as visitors, count(distinct a.user_id) as users,
               (select count(*) from (select (g.at at time zone 'Asia/Hong_Kong')::date d, g.anon from public.usage g where (g.at at time zone 'Asia/Hong_Kong')::date = a.day group by 1, 2 having bool_and(g.user_id is null)) z) as guests,
               count(*) filter (where a.kind = 'visit') as visits,
               count(*) filter (where a.kind = 'chart') as charts,
               count(*) filter (where a.kind = 'case') as cases,
               count(*) filter (where a.kind = 'quiz') as quiz,
               count(*) filter (where a.kind = 'basics') as basics,
               count(*) filter (where a.kind = 'lesson') as lessons,
               count(*) filter (where a.kind = 'analysis') as analysis
        from (select (u.at at time zone 'Asia/Hong_Kong')::date as day, u.* from public.usage u where u.at >= d0 - interval '13 days') a group by a.day) y))
  into r;
  return r;
end $function$;

select '060 completed' as status;
