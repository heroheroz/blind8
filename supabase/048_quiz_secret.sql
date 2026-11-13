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

-- 做完一輪要伺服器核實：過去 60 分鐘內真係答咗最少 10 條新題目先記（唔信前端）
create or replace function public.quiz_round_done(p_ok int) returns boolean
language plpgsql security definer set search_path = public as $$
declare c int; k int;
begin
  if auth.uid() is null then return false; end if;
  if exists (select 1 from quiz_rounds where user_id = auth.uid() and at > now() - interval '2 minutes') then return false; end if;
  select count(*), count(*) filter (where correct) into c, k from (
    select correct from quiz_answers where user_id = auth.uid() and at > now() - interval '60 minutes' order by at desc limit 10) t;
  if c < 10 then return false; end if;
  insert into quiz_rounds(user_id, ok) values (auth.uid(), k);
  return true;
end $$;
grant execute on function public.quiz_round_done(int) to authenticated;

select '048 completed' as status;
