# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Louis Bourne's personal portfolio — a **Rails 8.1** app that is a public portfolio, a project
showcase, and an AI-assisted blog. It is a **single-owner CMS**: exactly one user account may exist
(enforced in the `User` model), and that owner logs in to manage projects and posts. Live at
`www.louisbourne.me`.

**This is v2.** The live site is still v1 (the pre-overhaul Rails 7.1 app). v2 (this codebase) added
the feature set below by porting proven patterns from Louis's `isarak-portfolio` client build, and is
being stabilised before launch — bug-fixing plus an incoming Claude Design handoff that will layer the
final visual design over the current plain scaffolding. See
`docs/superpowers/specs/2026-07-01-portfolio-enhancements-design.md` and the matching plan +
`docs/DEPLOY_NOTES.md`.

## ⚠️ Deployment policy (do not deploy without a greenlight)

**Do NOT deploy this project** during `/review-sync`, `/docs-sync`, `/self-review`, or otherwise, until
Louis explicitly initiates the **first v2 deploy**. Land code and push, but stop before any
`git push heroku …`. Once he greenlights that first deploy, those skills deploy normally thereafter.
The live v1 must not be overwritten by an unstabilised v2.

## Stack

- **Ruby 3.3.5 / Rails 8.1.3**, PostgreSQL, Puma. Default branch: **`main`**.
- **Importmap** for JS (no Node/bundler/`bin/dev`); Hotwire (Turbo + Stimulus).
- **Bootstrap 5.3** via `sassc-rails`; `font-awesome-sass`; `autoprefixer-rails`.
- **Devise 5** (single-user), **simple_form** (heartcombo GitHub), **invisible_captcha**.
- **Action Text (Trix)** rich text; **FriendlyId** slugs; **Pagy** pagination.
- **Cloudinary + Active Storage** uploads (variant processing disabled — originals rendered).
- **ruby_llm → Anthropic Claude** for AI blog generation; **Unsplash** (raw `Net::HTTP`) for imagery.
- **Solid Queue** background jobs, run **in-Puma on the primary DB** (no Solid Cache/Cable).
- **posthog-ruby/-rails + posthog-js** — cookieless, visitor-only analytics; PostHog MCP in `.mcp.json`.

## Commands

```bash
bin/setup                      # install gems + db:prepare
bin/rails server               # run locally (no bin/dev). .env sets SOLID_QUEUE_IN_PUMA=true
                               #   so the scheduled-publish worker runs in-Puma
bin/rails db:prepare           # create + migrate
bin/rails db:seed              # seeds the single user + projects/posts (reads USER_1_* env vars)
bin/importmap pin <package>    # add a JS dependency

bin/rails test                       # full suite (currently 185 runs, 0 failures)
bin/rails test test/models/blog_post_test.rb        # one file
bin/rails test test/models/blog_post_test.rb:42     # one test by line
```

Test output is noisy with Bootstrap `WARNING: Found no color…` scss lines — ignore them; only
failures/errors matter. No RuboCop in the bundle; follow the conventions below by hand.

## Architecture — the parts that span files

**Single-owner CMS, gated by `skip_before_action`.** `ApplicationController` applies
`before_action :authenticate_user!` globally; public actions opt out per-action. Public visitors reach:
`pages#home/terms_of_service/privacy_policy/resume`, `projects#index/show`, `blog_posts#index/show`,
`contacts#create`, `tags` is owner-only. **When adding a public route, add it to the relevant
`skip_before_action` list.** The `User` model enforces a single account (`one_account_allowed`), so
"authenticated" == "owner".

**`Publishable` concern** (`app/models/concerns/publishable.rb`) is included by `BlogPost` and `Project`:
`enum :status { draft, scheduled, published }`, a `visible_to_visitors` scope (= published), and
`publish!`/`schedule!(time)`/`cancel_schedule!`. **Visitor scoping is correctness-critical and applied in
both `index` AND `show`** (`user_signed_in? ? Model.all : Model.visible_to_visitors`) plus `pages#home`
— drafts/scheduled records must never reach a signed-out visitor. `pages#profile` is owner-only.

**Dual-content blog.** A `BlogPost` renders **either** Action Text `body` (manual, Trix) **or**
`html_content` (AI / legacy raw HTML), never both (`one_content_field_only`). The AI path writes
`html_content`; `show` renders `body` if present else `sanitize(html_content)` via the `html-inject`
Stimulus controller (sanitize allowlist widened for `figure`/`figcaption` + the `style` attribute).
Tags are a `Tag`/`BlogPostTag` many-to-many; `reading_time`/`related_posts`/`ai_label` are model helpers.

**AI generation** (`app/services/blog_post_ai_service.rb`): `create_from_prompt` + `revise_blog_post`
build a Claude chat via `RubyLLM.chat(model: ENV["AI_MODEL"]||"claude-sonnet-5", provider: :anthropic,
assume_model_exists: true).with_instructions(...).with_schema(BlogPostSchema)`; `response.content` is an
auto-parsed Hash (ruby_llm 1.16 Anthropic structured output). Unsplash fetch + inline `<!-- IMAGE: q -->`
replacement; **every external call rescues to nil/"" and never blocks a save**, and gates on a present
`ANTHROPIC_API_KEY` (`ai_configured?`). Interpolated Unsplash fields are HTML-escaped + scheme-checked.

**Scheduled publishing.** `PublishScheduledPostsJob` publishes due `BlogPost`/`Project` (`scheduled_at <=
now`) via `publish!`; `config/recurring.yml` runs it every minute through the in-Puma Solid Queue
supervisor (needs `SOLID_QUEUE_IN_PUMA=true`). `resolve_publish_intent` on both controllers parses the
split publish/schedule button; a blank/past time falls back to **draft** (never an accidental publish).

**Analytics.** `config/initializers/posthog.rb` is fully **guarded** — a complete no-op without
`POSTHOG_PROJECT_TOKEN`. `ApplicationController#track_event` fires server events only for signed-out
visitors (`distinct_id: "anonymous"`); the posthog-js snippet renders only when enabled AND signed-out;
cookieless (no consent banner). Owner is never tracked.

**Homepage** `pages#home` exposes `@stats` from `app/queries/home_stats.rb` (published counts; technologies
split on the canonical `" . "` separator; editable year constants). `scroll_reveal` + `count_up` Stimulus
controllers animate the plain "by the numbers" section (reduced-motion gated). **Intentionally unstyled —
the Claude Design handoff restyles it.**

**Other:** FriendlyId slugs on both models (`.friendly.find`); drag-reorder via SortableJS
(`position` column, owner-scoped `reorder` action); Cloudinary `featured_image` attachments alongside the
legacy `img_url` string (views prefer the attachment, fall back to `img_url`, else no image).

## Conventions

- **Strong params: `params.require(...).permit(...)`** (not Rails-8 `params.expect`). Double quotes.
  `simple_form_for` + `f.input`. App module `LouisbPortfolio`.
- **All mutating actions are IDOR-scoped to `current_user`** (reorder, publish/schedule/cancel, AI revise).
- **Tests never hit the network** — `RubyLLM`, `Net::HTTP` (Unsplash), and PostHog are always stubbed.
  Secrets are read with `ENV.fetch("VAR", nil)` and every feature degrades gracefully when absent.
- Storage service per env: test→`:test`, development→`:local`, production→`:cloudinary` (`CLOUDINARY_URL`).
- **Inline teaching comments are intentional** (Louis is learning Rails) — preserve that style.
- Commit style: Conventional Commits, **no `Co-Authored-By`** lines.
