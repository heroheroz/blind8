-- 021：箭咀力度加「三合拱」一行（預設 1 個箭咀）
-- 三合局缺一個字（例如申辰拱子），招感出嚟嘅字同兩個來源字粘連，每條計呢個數
-- 要先行咗 015、017；喺 Supabase SQL Editor 行一次，行多次都冇問題

alter table public.arrow_weights drop constraint if exists arrow_weights_key_check;
alter table public.arrow_weights add constraint arrow_weights_key_check
  check (key in ('fu','he','lian','banhe','sanhe','zg','zgb','chain','cx','kg','se','yr','sw','sem','gong'));
insert into public.arrow_weights (key, value) values ('gong', 1) on conflict (key) do nothing;

select '021 completed' as status;
