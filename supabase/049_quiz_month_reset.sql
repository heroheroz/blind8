-- 049：答過嘅題目 30 日後可以再出（主人 11月14日）。30 日內答過＝唔出、唔計；過咗 30 日再答，用新答案換走舊記錄，照計分。
create or replace function public.quiz_answer(p_qid text, p_pick int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k smallint; w text; n int; td int; cap constant int := 50;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false); end if;
  select ans, why into k, w from quiz_key where qid = p_qid;
  if k is null then return jsonb_build_object('ok', false); end if;
  select count(*) into td from quiz_answers where user_id = auth.uid() and scored
    and at >= date_trunc('week', now() at time zone 'Asia/Hong_Kong') at time zone 'Asia/Hong_Kong';
  insert into quiz_answers as a (user_id, qid, pick, correct, scored) values (auth.uid(), p_qid, p_pick, p_pick = k, td < cap)
    on conflict (user_id, qid) do update set pick = excluded.pick, correct = excluded.correct, scored = excluded.scored, at = now()
      where a.at < now() - interval '30 days';
  get diagnostics n = row_count;
  return jsonb_build_object('ok', true, 'first', n = 1, 'scored', n = 1 and td < cap,
    'today', least(cap, td + case when n = 1 and td < cap then 1 else 0 end), 'cap', cap, 'ans', k, 'why', w);
end $$;
grant execute on function public.quiz_answer(text, int) to authenticated;

select '049 completed' as status;
