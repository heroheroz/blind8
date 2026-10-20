// Weekly backup of the shared 命例 and 留言版 from Supabase into backup/.
// Uses the public read access (same publishable key as the website), so no secret is needed.
// cases.csv uses the website's export format, so it can be imported back with 匯入.
import fs from 'node:fs';

const cfg = fs.readFileSync(new URL('../config.js', import.meta.url), 'utf8');
const url = (cfg.match(/url:\s*'([^']+)'/) || [])[1];
const key = (cfg.match(/key:\s*'([^']+)'/) || [])[1];
if (!url || !key) { console.log('config.js has no Supabase project; nothing to back up.'); process.exit(0); }

async function get(path) {
  const r = await fetch(`${url.replace(/\/$/, '')}/rest/v1/${path}`, { headers: { apikey: key } });
  if (!r.ok) throw new Error(`${path}: ${r.status} ${await r.text()}`);
  return r.json();
}

const rows = await get('cases?select=id,created_at,owner_name,name,input,notes,tags,votes(vote),comments(created_at,body,author_name)&order=created_at.asc');
let guestbook = [];
try { guestbook = await get('guestbook?select=id,parent,author_name,body,created_at&order=created_at.asc'); } catch (e) { console.log('guestbook skipped:', e.message); }

const cases = rows.map(r => ({
  name: r.name, input: r.input || {}, notes: r.notes || '', tags: r.tags || [], by: r.owner_name || '',
  likes: (r.votes || []).filter(v => v.vote === 1).length, unlikes: (r.votes || []).filter(v => v.vote === -1).length,
  comments: (r.comments || []).sort((a, b) => (a.created_at < b.created_at ? -1 : 1)).map(m => ({ by: m.author_name || '', body: m.body })),
}));

const COLS = [['名稱', c => c.name], ['性別', c => c.input.sex === 1 ? '男' : '女'], ['曆法', c => c.input.lunar ? '農曆' : '公曆'], ['閏月', c => c.input.leap ? '是' : ''],
  ['年', c => c.input.y], ['月', c => c.input.m], ['日', c => c.input.d], ['時', c => c.input.h], ['分', c => c.input.mi], ['子時換日', c => c.input.zi],
  ['城市', c => c.input.city], ['經度', c => c.input.lon], ['時區', c => c.input.tz], ['夏令時間', c => c.input.dst ? '是' : ''], ['真太陽時', c => c.input.tst === false ? '否' : '是'],
  ['姓名', c => c.input.name || ''], ['備註', c => c.notes], ['標籤', c => c.tags.join(' ')], ['新增者', c => c.by], ['準', c => c.likes], ['唔準', c => c.unlikes],
  ['事件', c => (c.input.events || []).map(v => `${v.t}:${v.y}-${v.m}-${v.d}`).join('; ')], ['補充備註', c => c.comments.map(m => `${m.by ? m.by + '：' : ''}${m.body}`).join('\n---\n')]];
const cell = v => { v = String(v ?? ''); return /[",\n\r]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v; };
const csv = '﻿' + [COLS.map(x => x[0]).join(','), ...cases.map(c => COLS.map(x => cell(x[1](c))).join(','))].join('\r\n') + '\r\n';

fs.mkdirSync(new URL('../backup/', import.meta.url), { recursive: true });
fs.writeFileSync(new URL('../backup/cases.csv', import.meta.url), csv);
fs.writeFileSync(new URL('../backup/cases.json', import.meta.url), JSON.stringify(rows, null, 1) + '\n');
fs.writeFileSync(new URL('../backup/guestbook.json', import.meta.url), JSON.stringify(guestbook, null, 1) + '\n');
console.log(`backed up ${cases.length} 命例 and ${guestbook.length} 留言`);
