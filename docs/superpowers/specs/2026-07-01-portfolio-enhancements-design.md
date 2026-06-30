# Portfolio Enhancements — Design Spec

**Date:** 2026-07-01
**Author:** Louis Bourne (with Claude)
**Status:** Approved (self-approved via `/full-send`)
**Reference codebase:** `/Users/devilfish/code/chifury/isarak-portfolio` (Louis's own Rails 8.1 client build — the proven source of these patterns)

## 1. Goal

Take `louisb-portfolio` (a Rails 7.1 personal portfolio + blog + project showcase) and raise it to the
feature level of the isarak reference: a rich-text + AI-assisted blog, slug URLs, pagination, file uploads,
scheduled publishing, cookieless analytics, and a livelier homepage. This session delivers the **backend
foundation plus enough frontend to see it working**; a separate Claude Design handoff will later layer the
final visual design on top.

The guiding principle is **port-faithfully**: copy isarak's battle-tested patterns, adapting only for
(a) the target app's existing column names, (b) Claude instead of OpenAI, and (c) `Project`/`BlogPost`
instead of `research/teaching/grant`. We are not re-architecting; we are transplanting proven code.

## 2. Locked Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Rails version | Upgrade **7.1.5 → 8.1** first | isarak code drops in nearly unchanged; unlocks Solid Queue; small app = low-risk |
| Ruby | Stay on **3.3.5** | Rails 8.1 needs only ≥ 3.2; avoids a Ruby install |
| AI provider | **Anthropic Claude** (Sonnet 5 default, swappable via env) | Louis's ecosystem; top writing quality; `ruby_llm` makes it a one-line change |
| Images | **Hybrid** — keep `img_url` string + add Cloudinary `featured_image` attachment | Preserves all existing seeded images; matches isarak's dual approach |
| Projects | **Full parity** — slugs, uploads, drag-reorder, draft/scheduled/published | Uniform content model; AI stays blog-only |
| Analytics | **Full PostHog** — cookieless, visitor-only, server + client events, MCP enabled | Privacy-friendly (no consent banner); queryable from Claude Code |
| Homepage | **Backend data + motion scaffolding now**; lavish visuals after design handoff | Matches Louis's stated plan; avoids rework |
| Scroll motion | Custom **IntersectionObserver Stimulus** (`scroll_reveal`), reduced-motion gated | Dependency-free; Louis already owns the pattern |
| Background jobs | **Solid Queue only**, single primary DB, **run in-Puma** (`SOLID_QUEUE_IN_PUMA`) | No extra Heroku worker dyno; no multi-DB complexity. Skip Solid Cache/Cable (unused) |
| Code adaptation rule | **Adapt ported code to Louis's existing column names** (`img_url`, `html_content`) rather than rename Louis's columns | Lower migration risk; existing views keep working |

## 3. Architecture — Phased Roadmap

Seven phases, each an independently-testable PR landing in dependency order. Each phase keeps the suite
green and the site bootable.

- **Phase 0 — Foundation:** Rails 8.1 + Devise 5 + gem stack + Solid Queue (in-Puma).
- **Phase 1 — Data layer:** `Publishable` concern (status + scheduling), FriendlyId slugs, drag-reorder,
  Cloudinary/Active Storage uploads — on both `BlogPost` and `Project`.
- **Phase 2 — Blog overhaul:** Action Text rich text, `Tag`/`BlogPostTag`, Pagy pagination, reading time,
  related posts, excerpts, search + tag filter.
- **Phase 3 — AI:** `ruby_llm` (Claude), `BlogPostSchema`, `BlogPostAiService` (generate + revise), Unsplash.
- **Phase 4 — Scheduled publishing:** `PublishScheduledPostsJob`, `recurring.yml`, split publish-button UI.
- **Phase 5 — Analytics + legal:** PostHog (server + client, guarded), PostHog MCP, updated TOS + Privacy.
- **Phase 6 — Homepage:** live stat data + `scroll_reveal` + `count_up` Stimulus controllers (plain PoC).

## 4. Data Model Changes

All new status-bearing models share a `Publishable` concern:

```ruby
# app/models/concerns/publishable.rb
module Publishable
  extend ActiveSupport::Concern
  included do
    enum :status, { draft: 0, scheduled: 1, published: 2 }   # Rails 8 enum syntax
    scope :visible_to_visitors, -> { published }
  end
  def publish!         = update!(status: :published, scheduled_at: nil)
  def schedule!(time)  = update!(status: :scheduled, scheduled_at: time)
  def cancel_schedule! = update!(status: :draft, scheduled_at: nil)
end
```

### 4.1 `Project` (additive only — no destructive changes)
Existing columns unchanged (`title, description, img_url, tech_stack, project_url, github_url, user_id,
personal_project, private_repo, featured`).
**Add:** `slug:string` (FriendlyId, indexed unique), `status:integer default:2(published)`,
`scheduled_at:datetime`, `position:integer`.
**Attachment:** `has_one_attached :featured_image`.
**Backfill migration:** existing rows → `status: published`, `position` assigned by `created_at`.
`featured_image` is optional; `img_url` remains the primary image source until a file is uploaded.
**Validations (relaxed for drafts):** replace the current `presence` validators on `img_url`/`project_url`
with `validates :title, presence: true` only (status comes from the concern). A draft project may be
created before every field is filled; existing rows already have these fields.

### 4.2 `BlogPost`
Existing columns kept (`title, description, img_url, tags(string→removed), html_content, user_id`).
**Add:** `slug:string` (unique), `status:integer default:2`, `scheduled_at:datetime`, `featured:boolean
default:false`, `blog_excerpt:text`, `featured_image_caption:text`, `ai_generated:boolean default:false`,
`human_generated:boolean default:false null:false`, `author:string`.
**Rich text:** `has_rich_text :body` (Action Text / Trix) for new manual posts.
**Attachments:** `has_one_attached :featured_image`, `has_many_attached :photos`.
**Dual content model (ported gotcha):** a post renders **either** Action Text `body` (manual) **or**
`html_content` (AI/legacy raw HTML) — never both. A `one_content_field_only` validation enforces it.
Louis's existing `html_content` column is the "erb content" field (no rename needed).
**Validations (REPLACE, don't add):** the current `BlogPost` block validates
`img_url`/`description`/`tags`/`html_content` presence. These are **incompatible** with the new design
(rich-text-only posts, dropped `tags` column, AI posts with rescued/nil `img_url`). Replace the entire
block with isarak-style: `validates :title, presence: true`, `validates :status, presence: true`, and
`one_content_field_only`. `author` is stamped by a `before_validation :set_author` → `"Louis Bourne"`.
**Tags:** new `Tag` (`name` unique, capitalized before save) + `BlogPostTag` join (unique composite index).
A backfill migration splits each existing `tags` string on the **`" . "` (dot-space) separator** Louis's
data actually uses (e.g. `"Rails 7 . ActionMailer . Heroku"` — verify against live rows first; do NOT
split on comma/space or multiword tags shatter), creating `Tag` rows + join rows, then **drops** the
legacy `tags` string column. The same migration strips `tags:` from `db/seeds.rb` and any fixtures and
re-expresses them via the join (else seed/fixture loading raises `UnknownAttributeError`).
**Helpers:** `#reading_time` (200 wpm, min 1), `#related_posts` (shared tags, recent, limit 3),
`#ai_label` ("Revised with AI" / "Created with AI" / nil).

### 4.3 `User`
No changes (single-user enforcement already present). Devise modules unchanged across the 4→5 upgrade.

## 5. Per-Phase Detailed Design

### Phase 0 — Rails 8.1 Foundation
- Gemfile: `rails ~> 8.1`, `devise ~> 5.0`, add `solid_queue`, `pagy`, `friendly_id ~> 5.6`,
  `cloudinary`, `ruby_llm`, `posthog-ruby`, `posthog-rails`; `faker` (test).
- Reconcile config against isarak (adapting the `LouisbPortfolio` module name, db names, host
  `www.louisbourne.me`): `config.load_defaults 8.1`, `config/initializers/new_framework_defaults_8_1.rb`,
  Devise 5 initializer deltas (`responder.error_status = :unprocessable_content`,
  `redirect_status = :see_other`).
- Solid Queue: install schema into the **primary** database (no separate queue DB), set
  `config.active_job.queue_adapter = :solid_queue`, run the supervisor **inside Puma** via the puma
  plugin + `SOLID_QUEUE_IN_PUMA=true` (no extra Heroku dyno).
- **Gate:** app boots, `bin/rails test` green (pre-existing broken scaffolds rewritten), home renders.

### Phase 1 — Data Layer (slugs, status, reorder, uploads)
- FriendlyId `friendly_id :title, use: :slugged` on `BlogPost` + `Project`; controllers resolve with
  `.friendly.find`. No `:history` module (title changes change the URL — acceptable for a personal site).
  Slug backfill uses `update_columns`/`save(validate: false)` (never `find_each(&:save)`, which would run
  full validations and silently skip invalid legacy rows).
- `Publishable` concern included by both. **Visitor scoping (correctness-critical — wire it explicitly):**
  `blog_posts#index`, `projects#index`, and `pages#home` must scope to `visible_to_visitors` for signed-out
  visitors and show all for the signed-in owner — otherwise drafts/scheduled posts leak publicly and the
  whole scheduled-publishing feature is defeated.
- **`projects#show` becomes public** (add `:show` to its `skip_before_action :authenticate_user!` list,
  matching `blog_posts#show`). This is an intended behaviour change so project detail pages — and the
  Phase 5 `project_viewed` visitor event — work for the public.
- Active Storage installed; `config/storage.yml` adds a `cloudinary` service. **Service per environment:**
  test → `:test`, development → `:local` (works with no Cloudinary key), production → `:cloudinary`
  (reads `CLOUDINARY_URL`). This keeps tests/local dev key-free while production uses Cloudinary.
- Drag-reorder: SortableJS ESM build vendored at `vendor/javascript/sortablejs.js`;
  `sortable_controller.js` PATCHes `{ ids: [...] }` to a `reorder` collection action that does
  `Model.where(id:).update_all(position:)`. Drag handles + `data-controller="sortable"` render only when
  `user_signed_in?`.
- **Gate:** model specs for status/slug/reorder green; uploading a file attaches a blob (local disk in test).

### Phase 2 — Blog Overhaul
- Action Text installed (Trix via importmap pins `trix` + `@rails/actiontext`); Trix toolbar extended with
  H2/H3 buttons (ported `trix-before-initialize` listener).
- `show.html.erb`: render `body` if present, else `sanitize(html_content)` inside the existing
  `html-inject` controller. Widen the sanitize allowlist via `config/initializers/sanitize.rb`: add tags
  `figure, figcaption` (`allowed_tags`) and the `style` **attribute** (`allowed_attributes`) — note `style`
  is an attribute, not a tag (needed for AI/Unsplash figures in Phase 3).
- **Action Text image embeds:** because `variant_processor` stays disabled, override
  `app/views/active_storage/blobs/_blob.html.erb` to render the original blob (no `representation`/
  `variant` call), or any image dropped into a Trix `body` raises an Active Storage error.
- `Tag` + `BlogPostTag`; `TagsController` (JSON create/destroy) + inline tag manager.
- Pagy 43: `Pagy::OPTIONS[:limit] = 9`, `include Pagy::Method` in ApplicationController,
  `@pagy, @blog_posts = pagy(scope)`, `raw @pagy.series_nav(:bootstrap)` guarded by `@pagy.pages > 1`.
- Index: `?q` title ILIKE search + `?tag_ids[]` filter; card grid; reading-time + excerpt on cards.
- **Gate:** index paginates, search/filter work, dual-content show renders both kinds, tag backfill verified.

### Phase 3 — AI Generation (Claude + Unsplash)
- **⚠ Provider-port risk (verify FIRST, before building the service):** isarak uses OpenAI's native
  `json_schema` structured output, where `chat.with_schema(...).ask` returns a parsed Hash in
  `response.content`. Anthropic's structured output goes through a different (tool-forcing) path. Before
  implementing, confirm via Context7/`ruby_llm` docs whether `with_schema` works on the Anthropic provider
  in the chosen `ruby_llm` version; if not, route through forced tool-use and parse the tool input. Pin
  `ruby_llm` to a version that supports Anthropic structured output (isarak's 1.13.0 is OpenAI-proven only).
  Keep `config.use_new_acts_as = true` from isarak's initializer.
- `config/initializers/ruby_llm.rb`: `config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", nil)`;
  model id from `ENV.fetch("AI_MODEL", "claude-sonnet-5")`. Build the chat with
  `provider: :anthropic, assume_model_exists: true` so a newer model id (valid but absent from the gem's
  registry) doesn't raise `ModelNotFoundError`.
- **Stubbed-green is NOT proof here.** Because all tests stub `RubyLLM`, a green suite says nothing about
  the live Claude path. Phase 3 ships with an explicit **manual live-key verification step** (run one real
  generation with `ANTHROPIC_API_KEY` set, confirm `response.content` parses and a post is built) listed
  in the final report as a "needs your eyes" item.
- `app/schemas/blog_post_schema.rb`: PORO with `#to_json_schema` (fields `title, excerpt, content,
  image_query, tag_ids[]`, all required, `additionalProperties: false`).
- `app/services/blog_post_ai_service.rb` (adapted to Louis's columns): `create_from_prompt(...)` and
  `revise_blog_post(...)`. Writes AI HTML into `html_content` (not `blog_post_erb_content`), `img_url`
  (not `image_url`), sets `ai_generated`/`human_generated`. Filters AI-chosen `tag_ids` against real IDs.
- Unsplash via `Net::HTTP` (`UNSPLASH_ACCESS_KEY`); `fetch_unsplash_data`, `inject_inline_images`
  (replaces `<!-- IMAGE: query -->` placeholders with `<figure>`). **All Unsplash failures rescue to nil
  and never block a save.** Uses `featured_image.purge_later` to avoid the Cloudinary-in-transaction trap.
- Routes: `collection { get :ai_new; post :create_with_ai }`,
  `member { get :ai_revise; patch :revise_with_ai }`. Both wrap the service in `rescue StandardError`.
- **Graceful degradation:** with no `ANTHROPIC_API_KEY`, the AI menu items render a friendly "AI not
  configured" notice instead of erroring. Tests **stub** `RubyLLM` and `Net::HTTP` — no real API calls.
- **Gate:** service builds a post from a stubbed LLM response; revise nils `body` and flips flags;
  missing-key path shows the notice; no live network in tests.

### Phase 4 — Scheduled Publishing
- `app/jobs/publish_scheduled_posts_job.rb`: publishes due `BlogPost.scheduled` + `Project.scheduled`
  (`scheduled_at <= Time.current`).
- `config/recurring.yml`: `publish_scheduled_posts` every minute (dev + production), so scheduling works
  locally too. Solid Queue supervisor (in-Puma) runs recurring.
- `schedule` / `publish` / `cancel_schedule` member actions + `resolve_publish_intent` on both controllers
  (parses the split-button `status` + `datetime-local`; **falls back to draft** if a scheduled time is
  blank/past — silently drafting is safer than silently publishing).
- `publish_form_controller.js` + schedule modal (Bootstrap UMD → `window.bootstrap?.Modal`);
  `load_button_controller.js` spinner already exists.
- **Gate:** job publishes only due records; past/blank schedule → draft; controller intent parsing tested.

### Phase 5 — Analytics + Legal
- `config/initializers/posthog.rb`: **DO NOT port isarak's verbatim** — it calls `PostHog.init`
  unconditionally (api_key → nil, host → nil) and enables `auto_capture_exceptions` +
  `auto_instrument_active_job`, which still fire/flush against a nil host when unconfigured. Wrap the entire
  block in `if ENV["POSTHOG_PROJECT_TOKEN"].present?` so it **no-ops entirely** when absent. **Delete** the
  `capture_user_context` / `current_user_method` / `user_id_method` lines (the `posthog_distinct_id` method
  doesn't exist — the latent isarak bug); visitor-only tracking needs no user context.
- `resume_downloaded` needs a real endpoint: the resume is currently a static asset `link_to` in
  `pages/_education.html.erb`. Add a `GET /resume` route + `pages#resume` action that streams/redirects the
  PDF and fires the event, and repoint the link.
- Client: official `posthog-js` snippet in the layout, wrapped `<% if posthog_enabled? && !user_signed_in? %>`,
  cookieless (`persistence: 'memory', disable_cookie: true`). No consent banner needed.
- `analytics_controller.js`: declarative `data-action="click->analytics#trackClick"` tracking, guarded on
  `window.posthog`.
- Server events (visitor-only, `distinct_id: "anonymous"`): `blog_post_viewed`, `project_viewed`,
  `contact_submitted`, `resume_downloaded`.
- PostHog MCP: add a project-scoped entry so Louis can query analytics from Claude Code; token referenced
  via env (per Louis's API-key-hygiene rule — value in `~/.zshrc`, not committed).
- Legal: update `privacy_policy` (disclose cookieless PostHog analytics, no third-party ad tracking) and
  `terms_of_service` (AI-assisted content disclosure). Content-only ERB edits.
- **Gate:** with no token, zero PostHog calls and no errors; with a stubbed client, a visitor view fires one
  event and a signed-in view fires none.

### Phase 6 — Homepage Data + Motion (scaffolding)
- `PagesController#home` exposes a `@stats` hash: `projects_count`, `blog_posts_count`,
  `technologies_count` (distinct tech across projects' `tech_stack`), `years_coding`, `years_trading`.
  Computed in a small `HomeStats` query object (`app/queries/home_stats.rb`) for testability.
- `scroll_reveal_controller.js`: IntersectionObserver (threshold 0.1) adds `.reveal-visible`, staggered,
  disconnects after first reveal; all CSS gated behind `@media (prefers-reduced-motion: no-preference)`.
- `count_up_controller.js`: animates a number from 0 to a `data-count-up-target-value` on reveal.
- A plain (intentionally unstyled) "by the numbers" section on the home page wires live `@stats` through
  `count_up` + `scroll_reveal` so motion + real data are visible. **The Claude Design handoff restyles this.**
- **Gate:** `HomeStats` returns correct counts from fixtures; section renders the live numbers.

## 6. Cross-Cutting Concerns

### 6.1 Environment variables (runtime secrets Louis must set to go live)
| Var | Used by | Without it |
|---|---|---|
| `ANTHROPIC_API_KEY` | AI generation (Phase 3) | AI menu shows "not configured"; rest of app fine |
| `AI_MODEL` (optional) | AI model id | Defaults to `claude-sonnet-5` |
| `CLOUDINARY_URL` | Prod image uploads (Phase 1) | Dev/test use local disk; **prod uploads need it** |
| `UNSPLASH_ACCESS_KEY` | AI inline/featured imagery (Phase 3) | AI posts save with no auto-image (rescued) |
| `POSTHOG_PROJECT_TOKEN` + `POSTHOG_HOST` | Analytics (Phase 5) | Analytics no-op silently |
| `SOLID_QUEUE_IN_PUMA` | Scheduled publishing (Phase 4) | **No supervisor → scheduled posts never publish** (silent). Set `=true` in dev `.env` and on Heroku |

All are read with `ENV.fetch("VAR", nil)` and **degrade gracefully** — the app boots and all non-dependent
features work with none of them set. Per Louis's hygiene rule, values live in `~/.zshrc` / Heroku config,
never committed. **Exception:** `SOLID_QUEUE_IN_PUMA` is not optional for scheduling to work — its absence
fails silently (no error, just nothing publishes), so it's a hard deploy-note + dev-`.env` item.

### 6.2 Deployment (Heroku)
- Solid Queue runs **inside Puma** (`SOLID_QUEUE_IN_PUMA=true` + puma plugin) — **no new worker dyno, no
  added cost.** `Procfile` keeps `release: rails db:migrate`; add `web: bundle exec puma -C config/puma.rb`.
- Multi-DB avoided: Solid Queue tables live in the primary Postgres DB (authored as a normal timestamped
  migration from the Solid Queue schema — **not** the separate `db/queue_schema.rb` + `queue` database that
  `solid_queue:install` generates by default).
- **Heroku memory:** the in-Puma supervisor forks a dispatcher + worker, each loading Rails, alongside Puma.
  On a 512 MB Eco/Basic dyno this risks R14. Keep `JOB_CONCURRENCY=1` (the `queue.yml` default) and monitor
  memory after the first deploy; acceptable for low portfolio traffic.
- **Deploy itself is deferred to Louis** (not performed by this build). A post-build note lists the
  `heroku config:set` commands for every env var above, including the mandatory `SOLID_QUEUE_IN_PUMA=true`.

### 6.3 Testing strategy
- Minitest (existing). Rewrite the broken scaffold controller tests into real ones (auth via
  `sign_in`, correct route helpers).
- External services are **always stubbed** in tests: `RubyLLM`, `Net::HTTP` (Unsplash), PostHog client.
  No test makes a live network call or needs a real key.
- Each phase ships its own model/controller/job tests; the gate is the **full suite green**.

### 6.4 Out of scope (this session)
- Final visual design / styling (the Claude Design handoff).
- Solid Cache / Solid Cable adoption.
- FriendlyId `:history` redirects.
- AI-drafted *project* blurbs (AI stays blog-only).
- The actual Heroku deploy.

## 7. Risks & Mitigations
- **Rails 8.1 upgrade breakage** → mitigated by copying isarak's known-good config (same gem stack) and a
  green-test gate before any feature work.
- **Devise 4→5 config drift** → copy isarak's Devise 5 initializer deltas.
- **Pagy 43 API churn** (`series_nav(:bootstrap)`, `Pagy::Method`) → follow isarak's exact usage.
- **Cloudinary-in-transaction purge errors** → use `purge_later`/`detach`, per the ported gotcha.
- **Tag backfill data loss** → migration backfills into `tags`/`blog_post_tags` *before* dropping the legacy
  string column. Note this is only *schema*-reversible: `remove_column` must pass the type (`:string`) to
  roll back, and rollback restores an **empty** column — the original strings live on in the `tags` table,
  not the dropped column.
- **AI provider port (OpenAI→Anthropic)** → biggest runtime risk; verify `ruby_llm` Anthropic structured
  output before building the service, use `assume_model_exists: true`, and treat the live path as a manual
  key-gated verification (stubbed-green proves nothing about Claude).
- **Bootstrap UMD via importmap** → always `window.bootstrap?.Modal`, never `import { Modal }`.
- **Build delivers backend + plain scaffolding only** → all final styling is intentionally deferred to the
  separate Claude Design handoff (per Louis's stated plan); this session does not deliver "lavish" visuals.
- **Large scope in one session** → built on a single `feat/portfolio-overhaul` branch with clean per-phase
  commits (one cohesive PR reviewed by `/self-review`), keeping the suite green at every phase boundary, so
  partial completion still lands as clean, green, reviewable history.
```
