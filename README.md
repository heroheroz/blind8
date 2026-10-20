# 盲派八字排盤

A single-page 盲派八字 chart: four pillars, 大運/流年/流月/流日, 元運, 三桓 and 命宮, with 招感, 粘連 and 啟動 drawn by the school's rules. Everything runs in the browser.

Live site: https://heroheroz.github.io/blind8/

## 命例 list

The left sidebar keeps 命例 (name, birth data, notes, tags, 準/唔準 votes). With `config.js` empty, each visitor's 命例 stay in their own browser and can be moved with 匯出/匯入.

To share 命例 with every visitor, with sign-in:

1. Create a free project at https://supabase.com.
2. In its SQL Editor, run `supabase/schema.sql`, then `supabase/002_update.sql`, `supabase/003_guestbook.sql` (留言版) and `supabase/004_event_votes.sql` (事件投票).
3. Under Authentication → URL Configuration, set Site URL to `https://heroheroz.github.io/blind8/`.
4. Copy the Project URL and the anon public key (Project Settings → API) into `config.js`.
5. Sign up on the website, confirm the email, then run the last line of `schema.sql` with your email to make yourself admin.

Everyone can read 命例. Signed-in users can add 命例, vote and add notes, and edit the 命例 they added. Only admins can delete 命例, delete tags in use, or edit other people's 命例.

### Google, Facebook and Discord sign-in

Each provider needs an app on its own site; paste its ID and secret into Supabase → Authentication → Sign In / Providers, and turn the provider on. Use this callback (redirect) URL in every provider app:

`https://tuphvsxtqwasotnviwlb.supabase.co/auth/v1/callback`

- Google: https://console.cloud.google.com → APIs & Services → Credentials → Create OAuth client ID (Web application). Fill in the OAuth consent screen first.
- Facebook: https://developers.facebook.com → My Apps → Create app → add Facebook Login → Settings → Valid OAuth Redirect URIs.
- Discord: https://discord.com/developers/applications → New Application → OAuth2 → Redirects.

Also add `https://heroheroz.github.io/blind8/` under Supabase → Authentication → URL Configuration → Redirect URLs. A provider that is not turned on shows an error after its button is clicked.

## Backup

`.github/workflows/backup.yml` runs every Monday (and on demand from the Actions tab). It reads the shared 命例 and 留言版 with the public key and commits them to `backup/`: `cases.csv` uses the website's export format, so it can be brought back with 匯入; `cases.json` and `guestbook.json` keep everything.
