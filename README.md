# Louis Bourne — Developer Portfolio

Louis Bourne's personal portfolio, project showcase, and AI-assisted blog. Built with Ruby on Rails 8.1.

> **v2 in progress.** The live site is v1; this is the v2 overhaul, being stabilised before launch
> (bug-fixing + an incoming design handoff). See `docs/DEPLOY_NOTES.md`.

## What it does

**For visitors**
- Browse the portfolio, projects (personal + open-source), and blog
- Read posts (hand-written rich text or AI-generated), filter by tag, search by title
- Download the résumé; get in touch via a spam-protected contact form

**For Louis (signed in — single owner)**
- Manage projects and blog posts; upload images (Cloudinary)
- Write rich-text posts (Trix) or **generate/revise drafts with AI** (Anthropic Claude + Unsplash imagery)
- **Schedule** posts and projects to publish at a future time
- Drag-to-reorder the showcase

## Tech stack

| Layer | Technology |
|---|---|
| Framework | Ruby on Rails 8.1 (Ruby 3.3.5) |
| Database | PostgreSQL |
| Styling | Bootstrap 5.3 + SCSS |
| Auth | Devise (single-user) |
| Rich text | Action Text (Trix) |
| Uploads | Cloudinary + Active Storage |
| Slugs / Pagination | FriendlyId / Pagy |
| AI | ruby_llm → Anthropic Claude |
| Background jobs | Solid Queue (in-Puma) |
| Frontend | Hotwire (Turbo + Stimulus), Importmap |
| Spam protection | invisible_captcha |
| Analytics | PostHog (cookieless, visitor-only) |

## Development

```bash
bin/setup          # install gems + prepare the database
bin/rails server   # run locally
bin/rails test     # run the test suite
```

See `CLAUDE.md` for architecture and conventions, and `docs/DEPLOY_NOTES.md` for the environment
variables needed to enable AI, uploads, analytics, and scheduling.
