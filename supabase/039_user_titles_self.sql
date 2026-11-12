-- 039：用戶自己揀稱呼（登入名後面個選擇）。user_titles：自己讀／寫自己嗰行；鳴謝榜經 case_thanks 讀（未揀＝師兄）。
drop policy if exists user_titles_own_select on public.user_titles;
create policy user_titles_own_select on public.user_titles for select to authenticated using (user_id = auth.uid());
drop policy if exists user_titles_own_insert on public.user_titles;
create policy user_titles_own_insert on public.user_titles for insert to authenticated with check (user_id = auth.uid());
drop policy if exists user_titles_own_update on public.user_titles;
create policy user_titles_own_update on public.user_titles for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
grant select, insert, update on public.user_titles to authenticated;

select '039 completed' as status;
