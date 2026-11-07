-- 023: 命例淨係登入咗嘅用戶先睇到（未登入：命例、備註、投票都讀唔到）
alter policy "read cases"       on public.cases         to authenticated;
alter policy "read comments"    on public.comments      to authenticated;
alter policy "read votes"       on public.votes         to authenticated;
alter policy "read event votes" on public.event_votes   to authenticated;
alter policy "read note votes"  on public.comment_votes to authenticated;
select '023 completed' as status;
