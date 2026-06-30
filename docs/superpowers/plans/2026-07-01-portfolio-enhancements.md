# Portfolio Enhancements Implementation Plan (v2 — post adversarial review)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **This is a PORT.** Reference app `/Users/devilfish/code/chifury/isarak-portfolio` (Rails 8.1) has this exact stack. For most tasks the "implementation" is: read the named isarak source file(s), reproduce them here, apply the listed **Adaptations**. Always read the isarak source directly.
>
> **v2 incorporates the 3-lens adversarial review** (coverage / executability / correctness). Fixes are marked `[FIX]`.

**Goal:** Raise `louisb-portfolio` from Rails 7.1 simple portfolio to a Rails 8.1 rich-text + AI blog, slug URLs, pagination, uploads, scheduled publishing, cookieless analytics, livelier homepage — by porting proven isarak patterns.

**Architecture:** Port-faithfully. Adapt ported code to Louis's columns (`img_url`, `html_content`) and to Claude. `BlogPost` + `Project` share a `Publishable` concern. **One feature branch `feat/portfolio-overhaul`, clean per-phase commits, one PR reviewed by `/self-review`** (a strictly-sequential overhaul on shared mutable schema is safer linear than 7 stacked PRs).

**Tech Stack:** Rails 8.1, Ruby 3.3.5, Postgres (single DB), Devise 5, Solid Queue (in-Puma), FriendlyId 5.6, Pagy 43, Action Text, Cloudinary + Active Storage, ruby_llm (Anthropic Claude), Unsplash (Net::HTTP), posthog-ruby/-rails + posthog-js, Bootstrap 5.3 + importmap, SortableJS.

## Global Constraints

- Target Rails `~> 8.1`; Ruby stays `3.3.5` (do NOT let `bundle update` force a Ruby bump). Devise `~> 5.0`.
- **Strong params: use `params.require(...).permit(...)`** (match existing louisb code) — NOT Rails-8 `params.expect` (which isarak uses). Rewrite ported actions accordingly. `[FIX M4]`
- **Pin ported-pattern gems to isarak's `Gemfile.lock` versions** to avoid API drift: `pagy 43.3.1`, `friendly_id 5.6.0`, `cloudinary 2.4.4`, `posthog-ruby 3.6.1`, `posthog-rails 3.6.1`, `solid_queue 1.3.2`, `devise ~> 5.0`. **Exception:** `ruby_llm` — choose a version that supports **Anthropic structured output** (verify in Task 3.1; isarak's 1.13.0 is OpenAI-proven only). `[FIX C11/M5]`
- Double quotes; `simple_form_for` + `f.input`; RuboCop `.rubocop.yml` (line length 120). App module `LouisbPortfolio` — never copy isarak's `IsarakPortfolio`/db/host names. Prod host `www.louisbourne.me`.
- GitHub remote SSH `git@github.com:louiskb/louisb-portfolio.git`. Conventional Commits, **no `Co-Authored-By`**.
- Secrets read via `ENV.fetch("VAR", nil)`, **degrade gracefully** when absent. Tests **never** hit the network — stub `RubyLLM`, `Net::HTTP`, PostHog. Storage service: test→`:test`, dev→`:local`, prod→`:cloudinary`.
- Adapt ported code to Louis's columns: AI HTML → `html_content`; image URL → `img_url`; author → `"Louis Bourne"`.
- Keep single-user enforcement + the `skip_before_action :authenticate_user!` public-access pattern.
- Suite green at every PHASE GATE. Commit after each task.

---

## PHASE 0 — Rails 8.1 Foundation

### Task 0.1: Green baseline on Rails 7.1 first
**Files:** Modify `test/test_helper.rb` (`include Devise::Test::IntegrationHelpers`), `test/controllers/{blog_posts,projects,contacts}_controller_test.rb`, `test/mailers/contact_mailer_test.rb`. Add `test/fixtures/{users,projects,blog_posts}.yml`.
**`[FIX C-fixtures]`** Fixtures must satisfy the **current** presence validators (these still exist in Phase 0): `blog_posts` need `title, description, img_url, tags, html_content, user`; `projects` need `title, description, img_url, tech_stack, project_url, user`. The `tags` string column still exists until Task 2.3.
- [ ] Add fixtures (one `users.yml: louis`); fix route helpers (`new_blog_post_url`, not `blog_posts_new_url`); `sign_in users(:louis)` for authed actions; assert public actions work signed-out.
- [ ] Run `bin/rails test` → all green on Rails 7.1.
- [ ] Commit: `test: repair scaffold tests and add fixtures for upgrade baseline`.

### Task 0.2: Bump Rails + Devise + gem stack (pinned)
**Files:** Modify `Gemfile`. Reference isarak `Gemfile`/`Gemfile.lock` for exact pins.
- [ ] Set `rails "~> 8.1"`, `devise "~> 5.0"`; add (pinned per Global Constraints): `solid_queue`, `friendly_id "~> 5.6"`, `pagy "~> 43.3"`, `cloudinary "~> 2.4"`, `ruby_llm` (version chosen in 3.1 — add latest for now), `posthog-ruby "~> 3.6"`, `posthog-rails "~> 3.6"`; `faker` in `:development, :test`. Keep `invisible_captcha, bootstrap ~>5.3, simple_form (github), sassc-rails, font-awesome-sass, importmap-rails, turbo-rails, stimulus-rails`.
- [ ] `bundle install`; confirm Ruby stays 3.3.5; `bin/rails --version` → `8.1.x`.
- [ ] Commit: `chore(deps): upgrade to Rails 8.1 and add feature gem stack`.

### Task 0.3: Reconcile framework config (enumerated deltas) `[FIX M2]`
**Files:** `config/application.rb`, add `config/initializers/new_framework_defaults_8_1.rb`, `config/environments/{development,production,test}.rb`, `config/puma.rb`, `config/boot.rb`.
**Enumerated deltas** (diff each against isarak, keep `LouisbPortfolio`/host/db names):
1. `config/application.rb`: `config.load_defaults 8.1`; keep existing eager-load/i18n; do NOT add Solid Cache/Cable; do NOT set `variant_processor` (leave default — but see Task 2.x `_blob` override).
2. Add `config/initializers/new_framework_defaults_8_1.rb` (Rails 8.1 generator content; leave new defaults commented/opt-in to avoid surprise behaviour changes).
3. `production.rb`: confirm `force_ssl`, `assets.compile=false`, STDOUT logger, existing SMTP block all intact post-upgrade.
4. `development.rb`/`test.rb`: reconcile any removed/renamed options flagged by boot warnings.
5. `puma.rb`/`boot.rb`: align with Rails 8.1 defaults.
- [ ] Apply; `bin/rails runner "puts Rails.version"` boots clean (no deprecations that break).
- [ ] Run `bin/rails test` → green. Commit: `chore: reconcile config for Rails 8.1 defaults`.

### Task 0.4: Devise 5 initializer
**Files:** `config/initializers/devise.rb`. Reference isarak's.
**Adaptations:** `mailer_sender = ENV.fetch("MAILER_SENDER", nil)`; `responder.error_status = :unprocessable_content`; `responder.redirect_status = :see_other`; keep current modules.
- [ ] Update; `bin/rails test` green; smoke `bin/rails s` → home + `/users/sign_in` render.
- [ ] Commit: `chore(auth): update Devise initializer for Devise 5`.

### Task 0.5: Solid Queue (primary DB, in-Puma) — correct install path `[FIX H2/C6]`
**Files:** Add a normal timestamped migration `db/migrate/*_create_solid_queue_tables.rb`, `config/queue.yml`, `config/recurring.yml` (empty/minimal for now), modify `config/environments/{development,production}.rb` (`config.active_job.queue_adapter = :solid_queue`), `config/puma.rb` (`plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]`), `Procfile`, `.env` (`SOLID_QUEUE_IN_PUMA=true` for dev). Reference isarak `config/queue.yml`, `config/puma.rb`.
**Correct path (NOT `solid_queue:install` verbatim):**
1. Run `bin/rails solid_queue:install` to generate `db/queue_schema.rb`, then **convert its contents into a normal `db/migrate` migration** (so tables land in the **primary** DB and into `schema.rb`).
2. Delete the `queue` database block from `config/database.yml` and any `config.solid_queue.connects_to` line — single primary DB.
3. `bin/rails db:migrate`; assert `schema.rb` now contains `solid_queue_*` tables.
- [ ] **Test** `test/jobs/solid_queue_smoke_test.rb`: use `ActiveJob::TestHelper` `assert_enqueued_with` for a trivial job (the test env adapter is `:test`, so assert via ActiveJob helpers, NOT the `solid_queue_*` tables). `[FIX L17]`
- [ ] Run `bin/rails test test/jobs/` → PASS. Commit: `feat(jobs): Solid Queue in-Puma on the primary database`.

**PHASE 0 GATE:** `bin/rails test` fully green on Rails 8.1; `bin/rails s` boots; home + login render. Commit boundary.

---

## PHASE 1 — Data Layer: Publishable, slugs, reorder, uploads, scoping

### Task 1.1: `Publishable` concern
**Files:** Create `app/models/concerns/publishable.rb`, `test/models/concerns/publishable_test.rb`.
**Produces:** `enum :status {draft:0, scheduled:1, published:2}`, scope `visible_to_visitors` (= `published`), `publish!`, `schedule!(time)`, `cancel_schedule!`.
- [ ] Test (dummy model including concern) state transitions + `visible_to_visitors` returns only published.
- [ ] Implement (spec §4); run `bin/rails test test/models/concerns/publishable_test.rb` → PASS.
- [ ] Commit: `feat(models): Publishable concern for status + scheduling`.

### Task 1.2: Migrations — columns + backfill
**Files:** Migrations in `db/migrate/`. `projects`: add `slug:string, status:integer default:2, scheduled_at:datetime, position:integer`. `blog_posts`: add `slug:string, status:integer default:2, scheduled_at:datetime, featured:boolean default:false, blog_excerpt:text, featured_image_caption:text, ai_generated:boolean default:false, human_generated:boolean default:false null:false, author:string`. Unique indexes on both `slug` columns. Backfill `position` by `created_at` (status default 2 already applies to existing rows — `[FIX L-status]` redundant explicit backfill harmless, skip it).
- [ ] Write migrations; `bin/rails db:migrate`; verify `schema.rb`.
- [ ] Tests: `project_test.rb` + `blog_post_test.rb` assert default status `published`, columns present.
- [ ] Commit: `feat(db): status/slug/scheduling columns on projects and blog_posts`.

### Task 1.3: FriendlyId slugs
**Files:** Modify `app/models/{blog_post,project}.rb` (`extend FriendlyId; friendly_id :title, use: :slugged`), `app/controllers/{blog_posts,projects}_controller.rb` (`.friendly.find`). Slug backfill migration.
**`[FIX L15]`** Backfill via `update_columns(slug: ...)` or `save(validate: false)` — never `find_each(&:save)` (runs validations, silently skips invalid legacy rows).
- [ ] Add FriendlyId; backfill existing slugs; switch finders to `.friendly.find`.
- [ ] Tests: `GET /blog_posts/:slug` + `GET /projects/:slug` resolve; model test asserts slug from title.
- [ ] `bin/rails test` → PASS. Commit: `feat(content): friendly slug URLs for blog posts and projects`.

### Task 1.4: Active Storage + Cloudinary + attachments + blob override
**Files:** `active_storage:install` migration; `config/storage.yml` (+`cloudinary` service); `config/environments/{test,development,production}.rb` (service `:test`/`:local`/`:cloudinary`); `app/models/blog_post.rb` (`has_one_attached :featured_image`, `has_many_attached :photos`), `app/models/project.rb` (`has_one_attached :featured_image`). **`[FIX C7]`** Override `app/views/active_storage/blobs/_blob.html.erb` to render the original blob (no `representation`/`variant`) so Trix-embedded images don't raise (variant processing stays off).
- [ ] Install + migrate; configure per-env services; add attachments; add blob override.
- [ ] Test: `blog_post_test.rb` attaches a fixture file (`:test` service) → `featured_image.attached?` true.
- [ ] `bin/rails test` → PASS. Commit: `feat(media): Active Storage + Cloudinary featured-image uploads`.

### Task 1.5: Drag-to-reorder (SortableJS)
**Files:** Vendor `vendor/javascript/sortablejs.js` (from isarak); `app/javascript/controllers/sortable_controller.js` (from isarak); register in `controllers/index.js` + pin in `config/importmap.rb`. Add `reorder` collection route + action to both controllers (`require/permit` the `ids`). Drag handles in index views gated on `user_signed_in?`.
- [ ] Port; add routes/actions/handles.
- [ ] Test: authed `PATCH reorder` persists new `position` order; unauthenticated is redirected.
- [ ] `bin/rails test` → PASS. Commit: `feat(content): drag-to-reorder for projects and blog posts`.

### Task 1.6: Controller scoping + public project show + form refactor `[FIX C1/C3/#8]`
**Files:** `app/controllers/projects_controller.rb` (`skip_before_action ... only: [:index, :show]`; `index`/`pages#home` visitor-scoped), `app/controllers/pages_controller.rb#home`, `app/controllers/blog_posts_controller.rb#index`. Create `app/views/projects/_form.html.erb` + `app/views/blog_posts/_form.html.erb` (refactor inline new/edit forms into partials). Add `featured_image` file input, `featured` checkbox to both forms; permit `:featured_image, :featured, :status, :scheduled_at, :position` in `project_params`/`blog_post_params`.
**Scoping rule:** signed-in sees all; visitor sees `visible_to_visitors`. Apply to `projects#index`, `blog_posts#index`, and both `pages#home` project filters.
- [ ] Implement; make `projects#show` public.
- [ ] Tests: visitor index/home excludes a `draft` record; signed-in includes it; `GET /projects/:slug` works signed-out; uploading a `featured_image` via the form persists the attachment.
- [ ] `bin/rails test` → PASS. Commit: `feat(content): visitor scoping, public project pages, shared form partials`.

**PHASE 1 GATE:** suite green; slugs resolve; drafts hidden from visitors; project show public; file attaches via form; reorder persists. Commit boundary.

---

## PHASE 2 — Blog Overhaul

### Task 2.1: Action Text (Trix)
**Files:** `action_text:install` (migrations + importmap pins `trix`, `@rails/actiontext`); `app/models/blog_post.rb` (`has_rich_text :body`); port Trix H2/H3 toolbar extension into `app/javascript/application.js`; add `app/assets/stylesheets/components/_actiontext.scss` (from isarak), register in `_index.scss`.
- [ ] Install; add rich text; port toolbar + scss.
- [ ] Test: model sets `body` and asserts `body.to_plain_text`.
- [ ] Commit: `feat(blog): Action Text rich-text body`.

### Task 2.2: REPLACE validations + dual-content + helpers + sanitize `[FIX H1/#1/#16]`
**Files:** `app/models/blog_post.rb`, `app/models/project.rb`, `config/initializers/sanitize.rb`, `app/views/blog_posts/show.html.erb`.
**Validation REPLACEMENT (delete the old presence block):**
- `BlogPost`: remove `validates :img_url/:description/:tags/:html_content, presence`. Add `validates :title, presence: true`, `validates :status, presence: true`, `one_content_field_only` (rejects `body` + `html_content` both present), `before_validation :set_author` → `"Louis Bourne"`.
- `Project`: remove `validates :img_url/:project_url, presence`; keep `validates :title, presence: true`.
**Helpers (adapt to `html_content`/`body`):** `#reading_time` (strip HTML, 200 wpm, min 1), `#related_posts` (shared tags, recent, limit 3), `#ai_label`.
**Sanitize:** `config/initializers/sanitize.rb` → `allowed_tags += %w[figure figcaption]`, `allowed_attributes += %w[style]` (`style` is an attribute). `[FIX L13]`
**Show:** render `body` if `body.present?` (`body?`) else `sanitize(html_content)` inside the `html-inject` controller.
- [ ] Tests: `reading_time`, `related_posts`, `one_content_field_only` rejects both; existing fixture posts (html_content only) still valid; `set_author` stamps "Louis Bourne".
- [ ] `bin/rails test` → PASS. Commit: `feat(blog): dual-content model, reading time, related posts, sanitize`.

### Task 2.3: Tags + correct backfill + seeds/fixtures update + drop column `[FIX #2/#4/L14]`
**Files:** Create `app/models/tag.rb`, `app/models/blog_post_tag.rb`; migrations (create tables + unique composite index `[blog_post_id, tag_id]`; backfill; `remove_column :blog_posts, :tags, :string`). Modify `app/models/blog_post.rb` (`has_many :tags, through: :blog_post_tags`). Add `app/controllers/tags_controller.rb` (JSON create/destroy) + routes. Port `tag_manager_controller.js`. Update `db/seeds.rb` + `test/fixtures/blog_posts.yml` to drop `tags:` and express tags via `Tag`/join (add `test/fixtures/{tags,blog_post_tags}.yml`).
**`[FIX #2]`** Backfill splits the legacy string on the **`" . "` (dot-space)** separator (verify against live rows with `bin/rails runner` first; do NOT split on comma/space). `Tag` capitalizes words preserving hyphens, `uniqueness case_sensitive:false`.
**Ordering:** run AFTER slug backfill (1.3); backfill into tables BEFORE `remove_column`.
- [ ] Write migration + `tag_test.rb` (capitalization, uniqueness) + association test; update seeds/fixtures.
- [ ] `bin/rails db:migrate`; `bin/rails test` → PASS; verify a `bin/rails runner` shows migrated tags intact.
- [ ] Commit: `feat(blog): Tag model with dot-space backfill; drop legacy tags string`.

### Task 2.4: Pagy pagination
**Files:** `config/initializers/pagy.rb` (`Pagy::OPTIONS[:limit] = 9`); `app/controllers/application_controller.rb` (`include Pagy::Method`); `blog_posts_controller.rb#index` (`@pagy, @blog_posts = pagy(scope.order(created_at: :desc))` where `scope` is the visitor-scoped relation from 1.6); `app/views/blog_posts/index.html.erb` (`raw @pagy.series_nav(:bootstrap)` guarded by `@pagy.pages > 1`).
- [ ] Implement; test: >9 published posts → page 2 returns the next set.
- [ ] Commit: `feat(blog): Pagy pagination on the blog index`.

### Task 2.5: Search + tag filter + card grid + blog form fields
**Files:** `blog_posts_controller.rb#index` (`?q` title ILIKE, `?tag_ids[]` join); `app/views/blog_posts/index.html.erb` (search bar, tag pills, card grid w/ reading-time + excerpt); `app/views/blog_posts/_form.html.erb` (add `rich_text_area :body`, `blog_excerpt`, `featured_image_caption`, tag manager; permit `:body, :blog_excerpt, :featured_image_caption, tag_ids: [], photos: []`). Port `blog_filter_controller.js` (PostHog calls deferred to Phase 5).
- [ ] Implement; tests: `?q=` filters by title; `?tag_ids[]=` filters by tag; creating a manual post with `body` saves.
- [ ] `bin/rails test` → PASS. Commit: `feat(blog): search, tag filtering, and full editor form`.

**PHASE 2 GATE:** suite green; index paginates/searches/filters; show renders both content kinds; tags migrated intact; manual rich-text post saves. Commit boundary.

---

## PHASE 3 — AI Generation (Claude + Unsplash)

### Task 3.1: ruby_llm config (Claude) + Anthropic verification `[FIX H3/M5]`
**Files:** `config/initializers/ruby_llm.rb`, `app/controllers/application_controller.rb` or `application_helper.rb` (`ai_configured?` = `ENV["ANTHROPIC_API_KEY"].present?`).
**VERIFY FIRST (Context7 `ruby_llm` docs):** does `chat.with_schema(Schema)` work on the **Anthropic** provider in the chosen version, returning a parsed Hash in `response.content`? If not, use forced tool-use and parse tool input. Lock the `ruby_llm` version accordingly.
**Config:** `config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", nil)`; `config.use_new_acts_as = true`. Chats built with `provider: :anthropic, assume_model_exists: true`, model `ENV.fetch("AI_MODEL", "claude-sonnet-5")`.
- [ ] Implement; test: `ai_configured?` false without key, true with (ENV stub); initializer doesn't raise on nil key.
- [ ] Commit: `feat(ai): ruby_llm configured for Anthropic Claude`.

### Task 3.2: `BlogPostSchema` PORO
**Files:** `app/schemas/blog_post_schema.rb`, `test/schemas/blog_post_schema_test.rb`. Reference isarak.
- [ ] Port (fields `title, excerpt, content, image_query, tag_ids[]`, required, `additionalProperties:false`); test `to_json_schema` shape.
- [ ] Commit: `feat(ai): blog post structured-output schema`.

### Task 3.3: `BlogPostAiService` — FULL service incl. Unsplash `[FIX M3]`
**Files:** `app/services/blog_post_ai_service.rb`, `test/services/blog_post_ai_service_test.rb`. Reference isarak `app/services/blog_post_ai_service.rb` (read in full).
**Adaptations:** AI HTML → `html_content`; image URL → `img_url`; set `ai_generated`/`human_generated`, `blog_excerpt` (from `excerpt`), `featured_image_caption`; `filter_valid_tag_ids`; `revise_blog_post` nils `body`, sets both flags. Claude chat per 3.1. **Include the Unsplash privates in THIS task** (`create_from_prompt` calls them — they can't be split out): `fetch_unsplash_data`, `inject_inline_images`, `fetch_image_html`, `figcaption_html`, all reading `ENV.fetch("UNSPLASH_ACCESS_KEY", nil)`, **all rescuing failures to nil/""**, replacing `<!-- IMAGE: query -->`. Use `featured_image.purge_later` in revise.
- [ ] Tests with **stubbed** `RubyLLM.chat` (canned schema Hash) + **stubbed** `Net::HTTP`: `create_from_prompt` builds a saved post (AI flags, filtered tags, html_content set, img_url from stubbed Unsplash); `revise_blog_post` nils body + both flags; HTTP raising → content unchanged + save still succeeds; no key → no HTTP attempted.
- [ ] `bin/rails test test/services/` → PASS (no network). Commit: `feat(ai): blog generation + revision service with Unsplash (Claude)`.

### Task 3.4: AI controller actions + views + graceful no-key UX `[FIX C2-resume-not-here]`
**Files:** `app/controllers/blog_posts_controller.rb` (`ai_new, create_with_ai, ai_revise, revise_with_ai`, `ai_params` via `require/permit`, `handle_ai_error`); routes (collection `ai_new`/`create_with_ai`, member `ai_revise`/`revise_with_ai`); `app/views/blog_posts/{ai_new,ai_revise}.html.erb` (port, minimal styling). Gate AI menu entries on `ai_configured?` else a "configure ANTHROPIC_API_KEY" notice.
- [ ] Implement; tests: authed `GET ai_new` renders; `POST create_with_ai` (stubbed service) redirects to new post; no-key path shows notice; visitor blocked.
- [ ] `bin/rails test` → PASS. Commit: `feat(ai): AI generate/revise endpoints with graceful no-key UX`.

**PHASE 3 GATE:** suite green; AI flow works vs stubs; missing key degrades; no live network in tests. **Manual live-key check deferred to final report (stubbed-green ≠ proof).** Commit boundary.

---

## PHASE 4 — Scheduled Publishing

### Task 4.1: `PublishScheduledPostsJob`
**Files:** `app/jobs/publish_scheduled_posts_job.rb`, `test/jobs/publish_scheduled_posts_job_test.rb`. Reference isarak.
**Adaptations:** publish due `BlogPost.scheduled` + `Project.scheduled` (`scheduled_at <= Time.current`) via `publish!` (the concern method — nils `scheduled_at`; cleaner than isarak's `published!`). `[FIX L2]`
- [ ] Test: past `scheduled_at` → published on perform; future stays scheduled.
- [ ] Implement; PASS. Commit: `feat(jobs): publish-scheduled-posts job for blog and projects`.

### Task 4.2: Recurring config
**Files:** `config/recurring.yml` (`publish_scheduled_posts` every minute, dev + production; keep isarak's hourly Solid Queue cleanup task too).
- [ ] Add; verify Solid Queue loads recurring (boot log / `bin/rails runner`).
- [ ] Commit: `feat(jobs): publish job every minute via Solid Queue recurring`.

### Task 4.3: Publish-intent actions
**Files:** `blog_posts_controller.rb` + `projects_controller.rb`: `publish, schedule, cancel_schedule` member actions + private `resolve_publish_intent` + `publish_notice`; member routes. Reference isarak (rewrite `params.expect` → `require/permit`).
**Adaptations:** `resolve_publish_intent` parses `status` + `datetime-local` `scheduled_at`; **blank/past → draft**.
- [ ] Tests: `PATCH publish` publishes; `PATCH schedule` future → scheduled; past/blank → draft; authed-only.
- [ ] `bin/rails test` → PASS. Commit: `feat(content): publish/schedule/cancel with safe intent parsing`.

### Task 4.4: Split publish-button UI
**Files:** Port `app/javascript/controllers/publish_form_controller.js` (`window.bootstrap?.Modal`). Add dropup split-button + schedule modal to `blog_posts/_form` + `projects/_form`. Reference isarak forms.
- [ ] Implement; manual smoke (`bin/rails s`): create a scheduled post via the modal.
- [ ] `bin/rails test` → PASS. Commit: `feat(content): split publish/schedule button UI`.

**PHASE 4 GATE:** suite green; job publishes only due records; intent parsing safe. Commit boundary.

---

## PHASE 5 — Analytics + Legal

### Task 5.1: PostHog server init (GUARDED) `[FIX #5/L1]`
**Files:** `config/initializers/posthog.rb`, `app/helpers/application_helper.rb` (`posthog_enabled?` = `ENV["POSTHOG_PROJECT_TOKEN"].present?`).
**DO NOT port verbatim:** wrap the whole `PostHog.init`/`PostHog::Rails.configure` block in `if ENV["POSTHOG_PROJECT_TOKEN"].present?`. **Delete** `capture_user_context`/`current_user_method`/`user_id_method` lines (no `posthog_distinct_id` exists). Keep `auto_capture_exceptions`/`auto_instrument_active_job` INSIDE the guard.
- [ ] Test: `posthog_enabled?` false without token; init does not raise / does not call PostHog when token absent.
- [ ] Commit: `feat(analytics): guarded PostHog server initialization`.

### Task 5.2: Client snippet + analytics Stimulus controller
**Files:** `app/views/layouts/application.html.erb` (posthog-js snippet wrapped `<% if posthog_enabled? && !user_signed_in? %>`, cookieless `persistence:'memory', disable_cookie:true`). Port `app/javascript/controllers/analytics_controller.js`; register/pin.
- [ ] Test (request test): snippet renders only when token present AND signed-out; absent for admin and when disabled.
- [ ] Commit: `feat(analytics): cookieless posthog-js snippet + declarative tracking`.

### Task 5.3: Server-side events + resume endpoint `[FIX C2/M1/#9]`
**Files:** Add `GET /resume` route + `pages#resume` action (`send_file`/redirect the PDF, fire `resume_downloaded`), repoint the link in `app/views/pages/_education.html.erb`. Add events to `blog_posts_controller#show` (`blog_post_viewed`), `projects_controller#show` (`project_viewed` — show is public as of 1.6), `contacts_controller#create` (`contact_submitted`). All `unless user_signed_in?`, `distinct_id: "anonymous"`, guarded by `posthog_enabled?`.
- [ ] Tests (PostHog client **stubbed**): visitor `show`/`create`/`resume` fires exactly one event each; signed-in fires none; disabled fires none.
- [ ] `bin/rails test` → PASS. Commit: `feat(analytics): server-side visitor events + instrumented resume download`.

### Task 5.4: PostHog MCP + legal pages
**Files:** `.mcp.json` (PostHog MCP server, token via env reference — never a raw value; add `.mcp.json` to `.gitignore` only if it must hold a secret, else commit the env-referenced form). Update `app/views/pages/privacy_policy.html.erb` (cookieless analytics disclosure, no third-party ad tracking) + `terms_of_service.html.erb` (AI-assisted content disclosure).
- [ ] Add MCP entry (env-referenced); update legal copy.
- [ ] `bin/rails test` → PASS. Commit: `feat(analytics): PostHog MCP config + updated TOS/Privacy`.

**PHASE 5 GATE:** suite green; zero PostHog calls without token; events visitor-only; resume instrumented. Commit boundary.

---

## PHASE 6 — Homepage Data + Motion (scaffolding)

### Task 6.1: `HomeStats` query object
**Files:** `app/queries/home_stats.rb`, `test/queries/home_stats_test.rb`; `pages_controller.rb#home` (`@stats = HomeStats.new.to_h`).
**Fields:** `projects_count` (published), `blog_posts_count` (published), `technologies_count` (distinct across published projects' `tech_stack`), `years_coding`, `years_trading` (from constants vs `Time.current.year`).
- [ ] Test (fixtures): counts correct; technologies de-duplicated across projects.
- [ ] Commit: `feat(home): HomeStats query object`.

### Task 6.2: `scroll_reveal` + `count_up` Stimulus controllers
**Files:** `app/javascript/controllers/scroll_reveal_controller.js` (port isarak), `count_up_controller.js` (new: animate 0→`data-count-up-target-value` on reveal); register/pin; reduced-motion-gated CSS in `app/assets/stylesheets/pages/_home.scss`.
- [ ] Port/implement; browser smoke.
- [ ] Commit: `feat(home): scroll-reveal and count-up animation controllers`.

### Task 6.3: "By the numbers" PoC section
**Files:** `app/views/pages/_by_the_numbers.html.erb` (plain; wires `@stats` through `count_up` + `scroll_reveal`), rendered in `app/views/pages/home.html.erb`.
**Adaptations:** intentionally minimal styling (Claude Design handoff restyles); reduced-motion safe.
- [ ] Implement; **verify in browser** (chrome-devtools/Playwright) desktop + mobile: numbers count up on scroll, live data shows. Screenshot both.
- [ ] `bin/rails test` → PASS. Commit: `feat(home): by-the-numbers section with live stats and motion`.

**PHASE 6 GATE:** suite green; `HomeStats` correct; section animates live numbers on scroll (verified in browser). Commit boundary.

---

## FINAL — Deploy notes + close-out

### Task F.1: Deploy notes doc
**Files:** Create `docs/DEPLOY_NOTES.md`: every env var (`ANTHROPIC_API_KEY`, `AI_MODEL`, `CLOUDINARY_URL`, `UNSPLASH_ACCESS_KEY`, `POSTHOG_PROJECT_TOKEN`, `POSTHOG_HOST`, **`SOLID_QUEUE_IN_PUMA=true`**) with `heroku config:set` commands; the in-Puma worker note; the `JOB_CONCURRENCY=1` memory caution; the manual AI live-key verification step. `[FIX C5/#10/#12]`
- [ ] Write; commit: `docs: Heroku deploy notes for new env vars and worker`.

### Task F.2: `/self-review`
Run `/self-review` (adversarial review of the PR diff → address real findings → merge to master → pull → prune). **Do NOT deploy to Heroku or force-push** (out of scope per `/full-send`).

## Self-Review (coverage map) — v2
- Spec §2 decisions, §3 phases 0–6 → Phases 0–6 (1:1). §4 model → 1.1/1.2/2.1/2.2/2.3. §5 per-phase → matching tasks.
- §6.1 graceful degradation → 1.4 (storage), 3.1/3.3/3.4 (AI), 5.1 (PostHog), 0.5+F.1 (`SOLID_QUEUE_IN_PUMA`).
- §6.2 in-Puma/no-dyno/memory → 0.5 + F.1. §6.3 stubs → 3.3/3.4/5.1/5.2/5.3. §6 TOS/Privacy → 5.4.
- Review fixes applied: H1→2.2; H2→0.5; H3/M5→3.1; #2/#4→2.3; C1/#8→1.6; C2/M1/#9→5.3; C3→1.6/2.5; #5→5.1; #7→1.4; C11→Global pins; M2→0.3; M3→3.3; M4→Global; L13→2.2; L15→1.3; L17→0.5; #16→2.2; C5/#10/#12→F.1.
- Out-of-scope (design, Solid Cache/Cable, deploy, `:history`, AI project blurbs) intentionally absent.
