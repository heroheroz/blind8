-- 加備註嘅用戶可以刪除自己嘅備註（管理員本身已經可以刪除任何備註）
drop policy if exists "authors delete own comments" on public.comments;
create policy "authors delete own comments" on public.comments
  for delete to authenticated using (author = auth.uid());
select '024 completed' as status;
