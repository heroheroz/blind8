-- 024：箭咀力度加 13 行（計法改善第9、12、19–22、24、11、1 條，對照隱姓先生課堂）
-- 暗合、三會方、害刑啟動倍數、以一合二、天干相同地支沖、空亡、夾拱填實、天干地支同時夾拱、天干權重、直沖扣分
-- 要先行咗 015、017、021；喺 Supabase SQL Editor 行一次，行多次都冇問題

alter table public.arrow_weights drop constraint if exists arrow_weights_key_check;
alter table public.arrow_weights add constraint arrow_weights_key_check
  check (key in ('fu','he','lian','banhe','sanhe','zg','zgb','chain','cx','kg','se','yr','sw','sem','gong',
                 'anhe','anhe2','sanhui','hai','xing','he2','cg','cgy','kw','tian','jgz','gw','zc'));
insert into public.arrow_weights (key, value) values
  ('anhe',1),('anhe2',0.5),('sanhui',1),('hai',0.5),('xing',0.5),('he2',1),('cg',1),('cgy',0.5),
  ('kw',0.35),('tian',1),('jgz',1),('gw',1.5),('zc',2.5)
on conflict (key) do nothing;

select '025 completed' as status;
