-- 071：自己上星期／上個月攞咗乜稱號（喺左上角登入名前面顯示；主人 11月16日）
create or replace function public.quiz_my_champ() returns table(period text, rk int)
 language sql stable security definer set search_path to 'public' as $$
  select 'month', c.rk from quiz_champ_ids('month') c where c.uid = auth.uid()
  union all
  select 'week', c.rk from quiz_champ_ids('week') c where c.uid = auth.uid()
$$;
revoke execute on function public.quiz_my_champ() from public, anon;
grant execute on function public.quiz_my_champ() to authenticated;
select '071 completed' as status;
