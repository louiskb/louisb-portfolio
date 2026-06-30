# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Louis Bourne's personal portfolio website — a Rails 7.1 app that is simultaneously a public
portfolio, a project showcase, and a blog. It is a **single-owner CMS**: exactly one user account
may exist (enforced in the `User` model), and that owner logs in to manage projects and blog posts.
Live at `www.louisbourne.me` (deployed on Heroku).

## Stack

- **Ruby 3.3.5 / Rails 7.1.5**, PostgreSQL, Puma
- **Importmap** for JavaScript — no Node/bundler/`bin/dev`. JS is pinned in `config/importmap.rb`.
- **Hotwire** (Turbo + Stimulus)
- **Bootstrap 5.3** compiled through `sassc-rails` (SCSS), plus `font-awesome-sass` and `autoprefixer-rails`
- **Devise** for auth, **simple_form** (installed from the heartcombo GitHub repo) for forms,
  **invisible_captcha** for contact-form spam protection
- Images are referenced by plain URL strings (`img_url` columns), **not** Active Storage attachments,
  even though Active Storage is configured.

## Commands

```bash
bin/setup                      # install gems + db:prepare (first-time setup)
bin/rails server               # run locally (no bin/dev — importmap needs no JS build step)
bin/rails db:prepare           # create + migrate + seed if needed
bin/rails db:migrate
bin/rails db:seed              # seeds the single user + projects from db/seeds.rb (uses ENV vars)
bin/importmap pin <package>    # add a JS dependency

bin/rails test                       # run the whole test suite
bin/rails test test/models/contact_test.rb        # one file
bin/rails test test/models/contact_test.rb:12     # one test by line number

bundle exec rubocop            # lint (config in .rubocop.yml; many cops disabled, line length 120)
```

Note: the test suite is mostly Rails-generated scaffolding (commented-out stubs); there is no
substantial coverage yet. Don't assume green tests prove behavior — verify changes by running the app.

## Deployment

Heroku, via `git push heroku master`. The `Procfile` runs `release: rails db:migrate` on every
deploy. A `Dockerfile` also exists but the live deploy uses the Heroku Rails buildpack. Use the
`deploy-heroku` skill for the full walkthrough.

## Architecture — the parts that span files

**Access control is by `skip_before_action`, not an admin namespace.**
`ApplicationController` applies `before_action :authenticate_user!` globally, so *everything is
private by default*. Each controller then opens up its public actions with
`skip_before_action :authenticate_user!, only: [...]`. Public visitors can reach: `pages#home`,
`pages#terms_of_service`, `pages#privacy_policy`, `projects#index`, `blog_posts#index/show`, and
`contacts#create`. Everything else (creating/editing/deleting projects and blog posts, the profile
dashboard) requires login. **When you add a new publicly-visible route, you must add its action to
the relevant `skip_before_action` list** or it will 302 to the Devise login.

**The home page is composed of section partials.** `pages/home.html.erb` renders
`_landing_hero_banner`, `_featured_projects`, `_demo_day`, `_tech_stack`, `_related_skills`,
`_education`, `_about_me`, `_contact`. Most portfolio content (tech stack, education, about, skills)
is **hard-coded in these partials**, not database-driven. Only the *featured projects* block reads
from the DB.

**Projects/BlogPosts are DB-backed and filtered in Ruby, not via scopes.** Both `belong_to :user`.
`Project` has three booleans — `personal_project`, `private_repo`, `featured` — and the
`PagesController`/`ProjectsController` partition projects with `Array#select` over `Project.all`
(e.g. `filter_personal_projects`, `filter_open_source_projects`). This loads all rows into memory;
it's a deliberately simple pattern, not optimized. "Featured" + `personal_project` decides what shows
on the landing page vs. the open-source section.

**Blog content is raw HTML stored in the DB and revealed by Stimulus.** `BlogPost#html_content` holds
a hand-authored HTML string. `blog_posts/show.html.erb` wraps it in a hidden `<article
data-controller="html-inject">`, passes it through Rails' `sanitize` helper, and the `html-inject`
Stimulus controller un-hides the element on `connect()`. Editing blog rendering means touching both
the view's `sanitize` call and `app/javascript/controllers/html_inject_controller.js`.

**The contact form sends two emails synchronously.** `contacts#create` saves a `Contact`, then calls
`ContactMailer` twice with `deliver_now` — `received_email` (to the owner, `ENV["MAILER_SENDER"]`) and
`confirmation_email` (to the submitter) — and redirects to `root_path(anchor: "contact")`. The action
is guarded by `invisible_captcha`. There is no background job queue; mail is inline.

**Stimulus controllers** (`app/javascript/controllers/`): `clipboard` (copy-to-clipboard share
button), `load_button` (injects a spinner and `requestSubmit()`s the form on click), `html_inject`
(blog reveal, above), `hello` (unused scaffold).

**Active-nav highlighting** lives in `ApplicationHelper#nav_link_class` /
`#nav_link_dropdown_class`, which switch the `active` class via `current_page?`. The navbar
(`shared/_navbar.html.erb`) shows different links for signed-in (owner: Projects/Blog/Create/Profile)
vs. signed-out (Portfolio/Projects/Blog/Contact) visitors.

## Styling

SCSS entrypoint is `app/assets/stylesheets/application.scss`: it imports `config/` (fonts, colors,
`_bootstrap_variables`) **before** `bootstrap` so variable overrides take effect, then the
`components/` and `pages/` partial indexes. Override Bootstrap by editing
`config/_bootstrap_variables.scss`, and add component styles as a new `components/_*.scss` partial
registered in `components/_index.scss`.

## Email / environment

- **Production** (`config/environments/production.rb`): SMTP via `ENV["SMTP_ADDRESS"]`,
  `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`; sender is `ENV["MAILER_SENDER"]`. Host is
  `www.louisbourne.me`, `force_ssl` on.
- **Development** (`config/environments/development.rb`): points at a local SMTP bridge on
  `127.0.0.1:1025` (Proton Mail Bridge — `ENV["PM_USERNAME"]` / `PM_PASSWORD`). `letter_opener` is
  available as a commented-out toggle for inspecting mail without sending.
- **Seeds** use `ENV["USER_1_USERNAME"]` / `USER_1_PASSWORD` to create the single account.
- Local secrets live in `.env` (gitignored, loaded by `dotenv-rails`).

## Conventions

- Double quotes everywhere; `simple_form` with `f.input` / `f.button :submit`; Bootstrap classes for layout.
- `.rubocop.yml` disables many style cops (including `Style/StringLiterals`) and excludes
  `config/`, `db/`, `bin/`, `test/`; line length max is 120.
- **Inline teaching comments are intentional** — the codebase has long explanatory comments on
  models, controllers, and Stimulus actions because the owner is learning Rails. Preserve that style
  rather than stripping comments when editing.
