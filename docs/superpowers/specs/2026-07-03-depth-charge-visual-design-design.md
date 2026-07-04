# Depth Charge Visual Design Implementation — Design

**Date:** 2026-07-03
**Status:** Approved. Foundation + engine sections approved by Louis directly;
remainder self-approved under `/full-send` after adversarial review.
**Source design:** `docs/design-handoff/louis-bourne-scroll-site-depth-charge.dc.html`
(the official design; see `docs/design-handoff/README.md`). Fallback design is
NOT built unless the official one fails in practice.

## Context

v2 of the portfolio (Rails 8.1) shipped backend + intentionally-unstyled
frontend scaffolding; the Claude Design handoff supplies the final visual
design. This spec covers implementing that design across the whole app.

Louis's locked decisions (2026-07-03):

1. **Scope: everything** — public pages AND owner CMS screens.
2. **Translate, don't copy** — the mock's content/layout is the design
   language; real app data (DB projects, 5 stats, blog) must be presented in
   that language, visually pleasing and easy to digest. Pixel fidelity to the
   mock is not required.
3. **Black-hole canvas: homepage only.** Other pages get the dark space theme
   without the canvas.
4. **CSS strategy: retheme Bootstrap 5 dark** via existing token files; add
   custom component SCSS on top. Do not remove Bootstrap.
5. **Homepage gains a "latest blog posts" section** (not in the mock).
6. **No deploy** — land code + push branches/PRs only. The first v2 deploy
   happens only when Louis greenlights it (standing project rule).

## Goals / success criteria

- Whole site presents the Depth Charge design language: near-black space
  theme, Bricolage Grotesque / Instrument Serif / Space Grotesk / Space Mono
  type, glass panels, mono eyebrow labels, `#1062FE` primary / `#5fb0ff`
  accent.
- Homepage is the full scroll experience: fixed black-hole canvas with depth
  camera, hover-charge system, and hero text morph, per the handoff engine.
- The full test suite stays green (185 runs at start; more at end — new
  behavior gets tests). Test-critical selectors preserved (see Testing).
- Behavior verified in a real browser: desktop + 375 px mobile + reduced
  motion, every user-facing flow driven (Louis's verification rule).
- CMS remains fully usable (forms, Trix, drag-reorder, publish buttons) in
  the dark theme.

## Non-goals

- Building the fallback design (`louis-bourne-website-fallback.dc.html`).
- The legacy Mission Console "Theme Engine" (5 switchable themes) AND the
  mouse-reactive aurora/WebGL-shader background from the design project's
  earlier "Design direction" notes — both superseded by the official
  black-hole Canvas 2D design; the official design has a single fixed theme.
- Model/schema/route changes beyond one controller ivar (`@latest_posts`).
- Copy rewrites beyond what translation into the new layout requires.
- Deploying, or anything requiring production credentials.

## 1. Foundation — tokens, fonts, Bootstrap retheme

All in `app/assets/stylesheets/config/`, which loads before Bootstrap:

- **Fonts** — the four families (Bricolage Grotesque 600/700/800,
  Instrument Serif regular+italic, Space Grotesk 400–700, Space Mono
  400/700) load via `<link rel="preconnect">` ×2 + a stylesheet `<link>`
  (`display=swap`) in the layout `<head>`, the mock's own approach — the
  browser starts the font fetch in parallel with the main CSS instead of
  serializing behind a SCSS `@import` (the hero's 132 px Bricolage headline
  makes FOUT visible otherwise). `_fonts.scss` keeps only the vars:
  `$headers-font: "Bricolage Grotesque"`, `$body-font: "Space Grotesk"`,
  `$mono-font: "Space Mono"`, `$accent-font: "Instrument Serif"`. Every
  stack ends in a generic family so failed font loads degrade to system
  fonts.
- **`_colors.scss`** — add the space palette, keep brand accents:
  `$space-black: #040507` (body bg), `$panel-bg: rgba(11, 13, 18, 0.62)`,
  `$panel-border: rgba(255, 255, 255, 0.08)`, text scale `$text-bright:
  #e9ecf1` / `$text-body: #aeb7c1` / `$text-muted: #7f8a95`, `$sky-blue:
  #5fb0ff` (eyebrows, stat numbers, meta accents). Unchanged: `$blue:
  #1062FE` (primary), `$green`, `$cyan`, `$orange`, `$red`, `$yellow`.
  New `$purple: #6f2bdd` token — the brand purple is currently hardcoded
  in `_text.scss`; promote it to a variable like its siblings.
- **`_bootstrap_variables.scss`** — `$body-bg: $space-black`, `$body-color:
  $text-bright`, `$font-family-*` from the new font vars, dark inputs
  (`$input-bg: #05060a`, `$input-border-color: rgba(255,255,255,.12)`,
  `$input-color: $text-bright`), link colors (`$link-color: $sky-blue`),
  radius scale aligned to the design's 10–18 px range.
- **`data-bs-theme="dark"` on `<html>`** (layout) so Bootstrap 5.3's built-in
  dark variants (dropdowns, close buttons, modals) apply on CMS screens.
- **Component SCSS** (new files under `components/`, imported via
  `_index.scss`): `.glass-card` (panel bg + border + blur + hover lift),
  `.section-eyebrow` (Space Mono, letter-spaced uppercase, `◆` prefix),
  `.section-heading` (Bricolage, clamp sizing), `.chip` + `.chip--learning`
  (solid / dashed mono pills), `.timeline-row` (year | detail grid),
  `.sec` (full-viewport flex section + `<820px` centering). The fixed
  pixel-height card styles in `_cards.scss` (`.card-project`,
  `.card-blog-post`, `.card-education`, `.card-skills`) are removed/
  replaced. `backdrop-filter` always has a solid `background-color`
  fallback.
- **Hardcoded light-theme rules are swept, not just retokened:**
  `_body.scss` sets `body { background-color: $white; }` and loads AFTER
  Bootstrap in the cascade — left alone it silently defeats the dark theme;
  flip it to `$space-black`. Views using `.text-dark` / `.text-black` /
  `.btn-outline-dark` (Bootstrap does NOT invert these under
  `data-bs-theme="dark"`) are converted to light equivalents as each phase
  touches their pages.
- Sections get `scroll-margin-top` so anchor jumps clear the fixed navbar.
- Inline teaching comments preserved/extended (Louis is learning Rails).

## 2. Black-hole engine → Stimulus controller

New `app/javascript/controllers/black_hole_controller.js`, porting the
mock's `initBH(cv)` closure nearly verbatim (dependency-free Canvas 2D):

- `static targets = ["canvas"]`; `static values = { intensity: { default:
  70 }, animate: { default: true }, starfield: { default: true } }` — the
  mock's tweakable props.
- `connect()` starts the engine in `try/catch` (a canvas failure must never
  break the page); `disconnect()` does the mock's `ctrl.stop()` — cancel
  rAF, remove resize/pointer listeners. This makes it Turbo-navigation-safe.
- Engine internals (palette, particle disk stretched 1.5×, depth camera
  centered at `w*0.5`, `excite`-based charge phases idle→charging→hold→
  decay→explode, nova `spawnBurst`, end-of-scroll anchor between `#contact
  form` bottom and `footer` top, `briMul = 1.45`, DPR cap 2, particle count
  `w*h/1300` cap 3000) are kept as designed.
- **Deliberate divergences from the mock script (the only four):**
  1. Drop the engine's internal `countUp()` + its `role === "numbers"`
     trigger — the app's tested `count_up` controller already does this;
     both running would double-animate.
  2. Hero morph strings stay as designed (`web`/`developer` ↔
     `Louis`/`Bourne`; subtitle ↔ the easter-egg line), reading `[data-morph]`
     spans; all lookups null-guarded (already true in the mock).
  3. `self.props.X` → Stimulus `this.xValue`.
  4. A `turbo:before-cache` listener resets the morph spans to their
     default text and clears the canvas, so Turbo's page snapshot never
     caches a half-morphed headline or a frozen frame (brief stale-flash
     on back-navigation otherwise). The reduced-motion scroll listener is also named and removed in `stop()` — the mock leaked it, which a static page tolerates but Turbo navigation does not. Canvas positioning lives in
     `_black_hole.scss` (created with the controller in phase 2).
- `prefers-reduced-motion` (or `animate: false`): single static render,
  re-rendered on passive scroll — mock behavior, kept.

Wiring (homepage only): the home view wraps content in
`data-controller="black-hole"` with `<canvas data-black-hole-target="canvas">`
fixed inset-0 z-0; content sections sit at `z-index: 2`.

## 3. Homepage translation map

`pages#home` keeps its composition of section partials. Every section keeps
its current `id` and gains `data-sec data-role="…" data-ax="…"` for the
depth camera (alternating left/right anchors as in the mock). Order:

| # | Partial | id | role / ax | Translation |
|---|---------|----|-----------|-------------|
| 0 | `_landing_hero_banner` | `#hero-banner` | hero / 0.66 | Eyebrow "Full-Stack Developer · Thailand"; morph headline `web` (Bricolage 800) / `developer` (Instrument Serif italic) with `data-morph="1"/"2"`; morph subtitle `data-morph="sub"`; CTAs "Contact Me" (`#contact`, primary) + "Key Projects" (`#featured-projects`, outline); social icon row (GitHub/LinkedIn/Discord/email — existing links, Font Awesome); mono hint "↪ Hover the black hole to charge it · scroll to descend". Default rendered text is `web developer` so no-JS reads correctly. |
| 1 | `_featured_projects` | `#featured-projects` | work / 0.34 | Eyebrow "◆ Selected Work"; two labeled groups (Personal, Open source) from `@personal_projects` / `@open_source_projects` as horizontal glass cards: thumbnail (**`featured_image` if attached, else `img_url`, else none — fixes the current inconsistency**), title, one-line description, mono tech-stack line, GitHub/live links + private-repo badge as now. |
| 2 | `_by_the_numbers` | `#by-the-numbers` | numbers / 0.5 | 5 stat tiles (auto-fit grid): Bricolage 800 number in `$sky-blue` + mono uppercase label. **Wiring preserved exactly:** section keeps `data-controller="scroll-reveal"`, tiles keep `data-scroll-reveal-target`, numbers keep `data-controller="count-up"` + `data-count-up-target-value` (tests depend on these). |
| 3 | `_demo_day` | `#demo-day` | demo / 0.66 | Eyebrow "◆ Demo Day"; heading + copy; existing YouTube iframe in a framed, shadowed panel. Replaces `.bg-waves-1`. |
| 4 | `_tech_stack` | `#tech-stack` | stack / 0.34 | "What I know" solid `.chip`s (current tech names) + "Learning" dashed chips (React, Vue.js). Plain spans, not links (design language; outbound icon links dropped intentionally). |
| 5 | `_related_skills` | `#related-skills` | background / 0.66 | Eyebrow "◆ Related Skills"; 3 stacked glass cards (Financial analysis / Marine biology / Digital marketing & e-commerce) with current copy. |
| 6 | `_education` | `#education` | education / 0.34 | Timeline rows (mono year | Bricolage institution + program) from current content; **"Download Full Resume" button kept** (`resume_path` + its analytics event). |
| 7 | `_about_me` | `#about-me` | about / 0.66 | Two-paragraph about copy (current text, design tone); existing documentary YouTube embed kept, framed like Demo Day. Replaces `.bg-waves-2`. |
| 8 | **NEW** `_latest_posts` | `#latest-posts` | blog / 0.34 | Eyebrow "◆ From the Blog"; up to 3 glass cards from `@latest_posts`: title (links to post), `blog_excerpt` when present, meta row (date · `reading_time` min read · AI badge when `ai_label`), tag pills; "All posts →" link to blog index. Section renders nothing when there are no published posts. |
| 9 | `_contact` | `#contact` | contact / 0.5 | Centered heading "Let's build something." + availability line + `mailto:` row; the **existing** simple_form (first/last name, email, message, `invisible_captcha`, load-button submit) inside a glass panel, dark inputs. |

Plus: `<main id="main-content">` on home (fixes the layout skip-link target),
`overflow-x: hidden` on the home wrapper.

**Data flow change (the only one):** `pages#home` adds
`@latest_posts = BlogPost.visible_to_visitors.order(created_at: :desc).limit(3)`
(there is no `published_at` column; `created_at` is the recency signal) —
published-only **for everyone including the signed-in owner** (drafts on
the homepage would be confusing; the owner sees drafts in the blog index).
`HomeStats` unchanged.

## 4. Site-wide (public pages, shared chrome, CMS)

- **Navbar** (`shared/_navbar`): fixed glass bar (gradient + blur), brand
  logo + "Louis Bourne" in Bricolage; links Portfolio / Projects / Blog +
  "Contact" primary button; signed-in avatar dropdown via Bootstrap dark.
  `nav_link_class` helpers untouched.
- **Footer** (`shared/_footer`): becomes a semantic `<footer>` (the engine's
  end-anchor queries `footer`): "© <year> Louis Bourne · Thailand" (dynamic
  year), legal links (Terms, Privacy, conditional Login),
  GitHub/LinkedIn/Discord/Email links (all four kept from the current
  footer — the mock's footer omits Discord but dropping a live link would
  be a regression).
- **Flashes**: Bootstrap alerts inherit the dark theme; still dismissible.
- **Blog index**: dark glass post cards; search field + tag-pill filter
  restyled (controller logic untouched); Pagy nav dark.
- **Typography-art index heroes (Louis, 2026-07-04):** the blog index and
  projects index drop their image hero banners entirely. Each gets an
  editorial, typography-first hero — oversized Bricolage display headline
  with an Instrument Serif italic accent word and mono eyebrow, no images —
  plus a **featured card** above the regular list: blog = latest published
  `featured` post (fallback: newest published), projects = first visible
  `featured` project. Featured picks are visitor-scoped like everything
  else.
- **Blog show**: readable long-form column (~720 px max-width) — dark prose
  styles for both Action Text `body` and sanitized `html_content` (update
  `_actiontext.scss`: headings, code blocks, figures/figcaptions, links);
  meta chips (date, reading time, AI label, tags); related-posts cards.
- **Projects index**: glass cards (image fallback logic as-is); owner-only
  drag-reorder handles + Featured/Edit badges restyled, SortableJS wiring
  untouched.
- **Projects show**: proper public detail page — title, image, description,
  tech chips, GitHub/live buttons; owner Edit/Delete styled.
- **Terms / Privacy**: prose pages with restyled hero banners.
- **CMS/auth polish**: Devise views (sign-in, password, registration-edit —
  including `devise/shared/_links` buttons → light variants), blog/project
  forms (simple_form inherits dark inputs; `publish_form` split-button
  restyled; the tag manager lives inline in the blog form — there is no
  tags index page), owner profile page (sweep its many `.text-dark`/
  `.text-black` spans). Trix/Action Text: `_actiontext.scss` ALREADY has a
  hand-tuned dark-theme block (teal `#89d6cc` accents, `#2d2d2d` toolbar) —
  retoken that existing block to the design palette (`$sky-blue` accent,
  panel tokens) in place; do NOT stack new invert filters on it. Also
  darken the Trix link dialog (`trix-dialog`, `.trix-input--dialog`
  hardcode white backgrounds). Functional-polish level, not a redesign.
- PostHog snippet, analytics events, and all controller/auth logic untouched.

## 5. Error handling & degradation

- Canvas engine: `try/catch` on start; page fully functional without it.
- No JS: static dark page, real hero copy, all content readable (server-
  rendered ERB throughout).
- Reduced motion: static canvas render; `count_up` and `scroll_reveal`
  already handle it (instant values / CSS-gated animations).
- `backdrop-filter` unsupported: solid panel fallback color.
- Google Fonts unreachable: generic font-stack fallbacks.
- Empty states: no published posts → no `#latest-posts` section; no projects
  → section renders its heading with nothing listed (as now).

## 6. Testing

**Must stay green:** entire existing suite; specifically
`pages_controller_test` by-the-numbers assertions (`section#by-the-numbers`
with `scroll-reveal`, 5 `count-up` nodes, `data-count-up-target-value`),
contacts, projects, blog tests.

**New tests:**
- Home shows up to 3 latest *published* posts; never drafts/scheduled — for
  visitors AND signed-in owner.
- Home renders the black-hole wiring: `[data-controller="black-hole"]`,
  canvas target, and 10 `[data-sec]` sections with `data-role`/`data-ax`.
- Home `<main id="main-content">` exists (skip-link target).
- Footer is a `<footer>` element (engine end-anchor contract).

**Browser verification (per phase, chrome-devtools MCP):** desktop ~1440 px
and 375 px mobile screenshots; drive home scroll (depth dolly), hover-charge
the hole (explosion + hero morph), contact submit (invalid + valid — the
invalid path also proves flash alerts read correctly on dark and stay
dismissible), inspect that the `invisible_captcha` honeypot field stays
visually hidden inside the glass panel, blog index filter + a post page,
projects pages; CMS: sign in, edit a post (Trix toolbar AND link dialog
legible), project form publish split-button, drag-reorder; reduced-motion
emulation; console free of errors. Iterate until it looks right — screenshots are the
proof, not green builds. (Headless screenshots freeze canvas animation
mid-frame; that is expected, not a bug.)

## 7. Rollout

Four stacked PRs, merged in order by `/review-sync` (NO deploy):

1. **Foundation** — tokens, fonts, dark retheme, `data-bs-theme`, component
   SCSS, navbar/footer/flashes, `main-content` fix. Spec + plan committed at
   the head of this branch. Whole site goes dark-coherent; CMS usable.
2. **Engine + homepage** — `black_hole_controller.js`, all home partials
   restyled + `data-sec` wiring, `_latest_posts` + `@latest_posts`, contact
   restyle, new tests.
3. **Public pages** — blog index/show (incl. Action Text dark), projects
   index/show, terms/privacy.
4. **CMS polish** — Devise, forms, Trix toolbar, tags, profile.

## 8. Risks & mitigations

- **Trix on dark** is the retheme's roughest edge → dedicated overrides +
  real-browser Trix editing check in phase 4.
- **Engine perf on mobile** → mock's own scaling (particle density, DPR cap)
  + 375 px verification; `intensity`/`starfield` values give a tuning knob
  without code changes.
- **Fixed navbar vs anchors** → `scroll-margin-top` on sections.
- **Charge system needs the canvas centered under the cursor** — engine math
  is viewport-based and ported unchanged; verified by driving hover in the
  browser.
- **Bootstrap variable retheme misses a corner** (e.g. a hardcoded light
  style in an old partial) → phase-by-phase browser sweeps catch these; fix
  as found.
- **Charging near the contact form**: at the end of scroll the hole parks
  behind/below the contact panel, and mousing within its radius while
  filling the form can trigger charge glow — this is the mock's tuned,
  intended behavior (accepted as delight, not a bug). Verify in the browser
  that it doesn't impair form use; dampen only if it actually does.
- **Skip-link targets**: `main#main-content` lands on home in phase 2; blog,
  projects, and static pages add the id to their `<main>` as phases 3–4
  touch them, so the layout's skip link works site-wide by the end.
