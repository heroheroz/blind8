-- 017：箭咀力度加「魁罡」一行（預設 1 個箭咀；魁罡用呢個數代替坐辰戌，唔會疊加）
-- 要先行咗 015、016；喺 Supabase SQL Editor 行一次，行多次都冇問題

alter table public.arrow_weights drop constraint if exists arrow_weights_key_check;
alter table public.arrow_weights add constraint arrow_weights_key_check
  check (key in ('fu','he','lian','banhe','sanhe','zg','zgb','chain','cx','kg','se','yr','sw','sem'));
insert into public.arrow_weights (key, value) values ('kg', 1) on conflict (key) do nothing;

select '017 completed' as status;
