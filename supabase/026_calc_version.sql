-- 026：計法版本（管理員揀全站用邊個版本）同半會箭咀力度
alter table point_settings drop constraint if exists point_settings_key_check;
alter table point_settings add constraint point_settings_key_check
  check (key = any (array['need','start','vday','gday','daily','calc_ver']));
insert into point_settings(key,value) values ('calc_ver',2) on conflict (key) do nothing;

alter table arrow_weights drop constraint if exists arrow_weights_key_check;
alter table arrow_weights add constraint arrow_weights_key_check
  check (key = any (array['fu','he','lian','banhe','sanhe','zg','zgb','chain','cx','kg','se','yr','sw','sem','gong','anhe','anhe2','sanhui','hai','xing','he2','cg','cgy','kw','tian','jgz','gw','zc','banhui']));
insert into arrow_weights(key,value) values ('banhui',0.5) on conflict (key) do nothing;

select '026 completed' as status;
