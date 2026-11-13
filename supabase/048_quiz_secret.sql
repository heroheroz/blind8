-- 048：測驗答案同老師解釋收入資料庫（主人 11月14日）：公開嘅題目檔唔再有答案，答完先由 quiz_answer 話返，避免睇答案衝榜。
alter table public.quiz_key add column if not exists why text;

create or replace function public.quiz_answer(p_qid text, p_pick int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k smallint; w text; n int; td int; cap constant int := 50;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false); end if;
  select ans, why into k, w from quiz_key where qid = p_qid;
  if k is null then return jsonb_build_object('ok', false); end if;
  select count(*) into td from quiz_answers where user_id = auth.uid() and scored
    and at >= date_trunc('week', now() at time zone 'Asia/Hong_Kong') at time zone 'Asia/Hong_Kong';
  insert into quiz_answers(user_id, qid, pick, correct, scored) values (auth.uid(), p_qid, p_pick, p_pick = k, td < cap)
    on conflict (user_id, qid) do nothing;
  get diagnostics n = row_count;
  return jsonb_build_object('ok', true, 'first', n = 1, 'scored', n = 1 and td < cap,
    'today', least(cap, td + case when n = 1 and td < cap then 1 else 0 end), 'cap', cap, 'ans', k, 'why', w);
end $$;
grant execute on function public.quiz_answer(text, int) to authenticated;

-- 答案同解釋嘅資料唔放喺公開 repo（主人自己喺 SQL Editor 入）。
-- insert into public.quiz_key(qid, ans, why) values (…) on conflict (qid) do update set ans = excluded.ans, why = excluded.why;

select '048 completed' as status;
