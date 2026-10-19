# 盲派八字排盤

A single-page 盲派八字 chart: four pillars, 大運/流年/流月/流日, 元運, 三桓 and 命宮, with 招感, 粘連 and 啟動 drawn by the school's rules. Everything runs in the browser.

Live site: https://heroheroz.github.io/blind8/

## 命例 list

The left sidebar keeps 命例 (name, birth data, notes, tags, 準/唔準 votes). With `config.js` empty, each visitor's 命例 stay in their own browser and can be moved with 匯出/匯入.

To share 命例 with every visitor, with sign-in:

1. Create a free project at https://supabase.com.
2. In its SQL Editor, run `supabase/schema.sql`.
3. Under Authentication → URL Configuration, set Site URL to `https://heroheroz.github.io/blind8/`.
4. Copy the Project URL and the anon public key (Project Settings → API) into `config.js`.
5. Sign up on the website, confirm the email, then run the last line of `schema.sql` with your email to make yourself admin.

Everyone can read 命例. Signed-in users can add 命例, vote and add notes, and edit the 命例 they added. Only admins can delete 命例, delete tags in use, or edit other people's 命例.
