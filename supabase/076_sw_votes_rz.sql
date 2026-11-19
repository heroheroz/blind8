-- 076：最強五行投票加推論4（rz＝日支藏月令印，Eric 師兄，2026-11-18）
alter table public.sw_votes drop constraint if exists sw_votes_method_check;
alter table public.sw_votes add constraint sw_votes_method_check check (method in ('s1', 'yue', 'sl', 'rz'));
select '076 completed';
