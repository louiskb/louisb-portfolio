# Deploy Notes — Portfolio Overhaul (Rails 8.1)

This overhaul upgraded the app to Rails 8.1 and added rich-text + AI blogging, slug URLs,
pagination, Cloudinary uploads, scheduled publishing, cookieless analytics, and a homepage
stats section. Everything **degrades gracefully** when a secret is absent — the app boots and
all non-dependent features work with none of these set. Set them to turn each feature on.

## 1. Environment variables

| Var | Feature | Without it | Required? |
|---|---|---|---|
| `SOLID_QUEUE_IN_PUMA=true` | Scheduled publishing (worker runs in Puma) | **Scheduled posts/projects never publish — silently** | **YES, for scheduling** |
| `ANTHROPIC_API_KEY` | AI blog generation/revision | AI menu shows a "configure" notice; rest of app fine | Only for AI |
| `AI_MODEL` (optional) | AI model id | Defaults to `claude-sonnet-5` | No |
| `CLOUDINARY_URL` | Production image uploads | Dev/test use local disk; **prod uploads fail** without it | For prod uploads |
| `UNSPLASH_ACCESS_KEY` | Auto-imagery for AI posts | AI posts save with no auto-image (rescued, never blocks) | Only for AI imagery |
| `POSTHOG_PROJECT_TOKEN` + `POSTHOG_HOST` | Cookieless visitor analytics | Analytics no-op silently | Only for analytics |
| `POSTHOG_PERSONAL_API_KEY` | PostHog **MCP** (Claude Code only, not the app) | MCP server inactive | Local only |

Already configured (unchanged by this work): `MAILER_SENDER`, `SMTP_ADDRESS`, `SMTP_PORT`,
`SMTP_USERNAME`, `SMTP_PASSWORD`, `RAILS_MASTER_KEY`, `LOUISB_PORTFOLIO_DATABASE_PASSWORD`.

Per your hygiene rule, keep real values in `~/.zshrc` (local) / Heroku config (prod), never committed.

## 2. Heroku config (run before/with the deploy)

```bash
heroku config:set SOLID_QUEUE_IN_PUMA=true
heroku config:set JOB_CONCURRENCY=1          # keep at 1 on a small dyno (memory)
heroku config:set ANTHROPIC_API_KEY=sk-ant-...        # optional (AI)
heroku config:set AI_MODEL=claude-sonnet-5            # optional
heroku config:set CLOUDINARY_URL=cloudinary://...     # prod uploads (reuse your isarak account, new folder)
heroku config:set UNSPLASH_ACCESS_KEY=...             # optional (AI imagery)
heroku config:set POSTHOG_PROJECT_TOKEN=phc_...       # optional (analytics)
heroku config:set POSTHOG_HOST=https://us.i.posthog.com
```

The `release: rails db:migrate` Procfile step runs the new migrations (slug/status/scheduling
columns, Active Storage, Action Text, tags, Solid Queue tables) automatically on deploy.

## 3. Background worker (no extra dyno)

Solid Queue runs **inside the web dyno's Puma** via the puma plugin, gated by
`SOLID_QUEUE_IN_PUMA=true`. There is **no separate worker dyno** (no added cost). The recurring
`publish_scheduled_posts` job runs every minute and publishes any post/project whose
`scheduled_at` has passed. If `SOLID_QUEUE_IN_PUMA` is unset, the supervisor never starts and
scheduling silently does nothing — so this var is mandatory for that feature.

**Memory:** the in-Puma supervisor forks a dispatcher + worker alongside Puma. On a 512 MB
Eco/Basic dyno keep `JOB_CONCURRENCY=1` and watch for R14 after the first deploy.

## 4. Manual verification only you can do

1. **AI live-key smoke (important — stubbed tests do NOT prove the live Claude path):** set a real
   `ANTHROPIC_API_KEY`, open `/blog_posts/ai_new`, generate one post, and confirm it builds with
   content (and imagery if `UNSPLASH_ACCESS_KEY` is set). The `ruby_llm` 1.16 Anthropic structured-
   output path was verified at the gem-source level, but only a real call proves the round trip.
2. **Confirm the homepage year constants** in `app/queries/home_stats.rb`:
   `CODING_SINCE_YEAR = 2024` (→ "2 years coding") and `TRADING_SINCE_YEAR = 2018`
   (→ "8 years in markets"). Your profile mentions ~6 years trading — adjust if 2018 is off.
3. **Reset your dev user password.** A subagent's browser smoke set the dev login for
   `nemo.m1cxw@8shield.net` to `SmokeTest123!` (the original hash couldn't be restored). Reset it
   in the app, or re-run `rails db:seed` (which reads `USER_1_USERNAME`/`USER_1_PASSWORD`). Dev DB only.

## 5. Not done here (by design)

- The actual Heroku deploy (your call).
- Final visual design / styling — that is the separate Claude Design handoff; this work delivers
  the backend + a plain, working homepage stats section for it to restyle.
- Solid Cache / Solid Cable (unused), FriendlyId history redirects, AI-drafted project blurbs.
