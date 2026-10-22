-- 022：資料庫執執手（唔改任何資料、唔改權限規則）
-- 1) 觸發器函數本身唔使俾網站直接 call：收返 anon／authenticated 嘅 EXECUTE（觸發器照常行）
-- 2) 幫 11 條外鍵加索引：刪用戶、睇投票、睇留言快啲
revoke execute on function public.audit_auth_trg(), public.audit_trg(), public.audit_view_trg(),
  public.award_backfill_trg(), public.award_case_trg(), public.award_gc(), public.award_note_trg(), public.usage_fill()
  from public, anon, authenticated;

create index if not exists arrow_votes_user_id_idx on public.arrow_votes(user_id);
create index if not exists cases_owner_idx on public.cases(owner);
create index if not exists comment_votes_voter_idx on public.comment_votes(voter);
create index if not exists comments_author_idx on public.comments(author);
create index if not exists comments_case_id_idx on public.comments(case_id);
create index if not exists event_votes_voter_idx on public.event_votes(voter);
create index if not exists guestbook_author_idx on public.guestbook(author);
create index if not exists guestbook_parent_idx on public.guestbook(parent);
create index if not exists point_bonus_by_idx on public.point_bonus(by);
create index if not exists sw_votes_user_id_idx on public.sw_votes(user_id);
create index if not exists votes_voter_idx on public.votes(voter);

select '022 completed' as status;
