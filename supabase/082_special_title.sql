-- 082 專屬永久稱號（主人 2026-11-27）：老師第100堂話個 app「浩瀚」→ Tom 戴「浩瀚的」，狀元效果
create table if not exists public.special_titles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  title text not null,
  created_at timestamptz not null default now()
);
alter table public.special_titles enable row level security;
revoke all on public.special_titles from anon, authenticated;

insert into public.special_titles (user_id, title) values
  ('75920ec6-44a9-4d3d-bf11-f138d7e65cdf', '浩瀚的'),
  ('ccf63e57-d5b2-4309-be76-4ecfd4bb11e6', '浩瀚的')
on conflict (user_id) do update set title = excluded.title;

-- 用 period 'sp'、rk 0 帶出專屬稱號（唔改 return type）
create or replace function public.quiz_champ_uids()
 returns table(uid uuid, period text, rk integer)
 language sql stable security definer set search_path to 'public'
as $function$
  select c.uid, 'month', c.rk from quiz_champ_ids('month') c
  union all
  select c.uid, 'week', c.rk from quiz_champ_ids('week') c
  union all
  select s.user_id, 'sp:' || s.title, 0 from special_titles s
$function$;

create or replace function public.quiz_my_champ()
 returns table(period text, rk integer)
 language sql stable security definer set search_path to 'public'
as $function$
  select 'month', c.rk from quiz_champ_ids('month') c where c.uid = auth.uid()
  union all
  select 'week', c.rk from quiz_champ_ids('week') c where c.uid = auth.uid()
  union all
  select 'sp:' || s.title, 0 from special_titles s where s.user_id = auth.uid()
$function$;

select '082 completed';
