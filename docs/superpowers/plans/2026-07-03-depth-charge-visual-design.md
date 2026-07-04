# Depth Charge Visual Design Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the Depth Charge design handoff (dark space theme +
black-hole scroll engine) across the whole portfolio app — homepage scroll
experience, public pages, and CMS — per
`docs/superpowers/specs/2026-07-03-depth-charge-visual-design-design.md`.

**Architecture:** Retheme Bootstrap 5 dark via the existing token files
(`config/_fonts|_colors|_bootstrap_variables.scss`, which load before
Bootstrap), add a small design-system layer of component SCSS, port the
handoff's canvas engine to a Stimulus controller used only on `pages#home`,
and rewrite view partials section-by-section in the new language while
preserving all existing controller logic, Stimulus wiring, and tests.

**Tech Stack:** Rails 8.1 / sprockets + sassc (Bootstrap 5.3 SCSS),
importmap + Stimulus, simple_form, minitest. No new dependencies.

## Global Constraints

- **Double quotes** in Ruby/ERB/JS wherever the language allows.
- **`simple_form_for` + `f.input`** for any form (never `form_with`).
- **Conventional Commits**, NO `Co-Authored-By` lines.
- **Inline teaching comments are intentional** — preserve and extend them.
- **Never deploy.** No `git push heroku`. Land branches/PRs only.
- **Tests must stay green**: run `bin/rails test` at every task's gate
  (baseline: 185 runs, 0 failures). Ignore Bootstrap `WARNING: Found no
  color…` noise in test output; only failures/errors matter.
- **Test-critical selectors that MUST survive:** `section#by-the-numbers`
  with `data-controller="scroll-reveal"`; five elements with
  `data-controller="count-up"` and `data-count-up-target-value`;
  `#featured-projects`; the contact form posting to `contacts_path` with
  `invisible_captcha`.
- **Dark-theme sweep rule:** Bootstrap's `data-bs-theme="dark"` does NOT
  invert `.text-dark`, `.text-black`, or `.btn-outline-dark`. In every view
  file you touch, grep for those classes and convert to light equivalents
  (`.text-light`/none, `.btn-outline-light`) — dark-on-dark text is the #1
  regression risk of this retheme.
- The design source of truth is
  `docs/design-handoff/louis-bourne-scroll-site-depth-charge.dc.html`
  (referred to below as **the mock**) and
  `docs/design-handoff/claude-design-project-memory.md`.
- Design tokens (use everywhere, never hardcode hex in components):
  `$space-black #040507`, `$panel-bg rgba(11,13,18,.62)`, `$panel-border
  rgba(255,255,255,.08)`, `$text-bright #e9ecf1`, `$text-body #aeb7c1`,
  `$text-muted #7f8a95`, `$sky-blue #5fb0ff`, `$blue #1062FE` (primary),
  `$purple #6f2bdd`.
- Branch stack (PR per phase, in order): `design/p1-foundation` (off
  `main`) ← `design/p2-homepage` ← `design/p3-public` ← `design/p4-cms`.
  **Each phase's FIRST task creates its branch as its FIRST step.**
- After each phase: browser-verify with chrome-devtools MCP (desktop
  ~1440px AND 375px mobile screenshots; check the flows that phase touched;
  console clean). Headless screenshots freeze canvas animation mid-frame —
  expected, not a bug.

---

## Phase 1 — Foundation (branch `design/p1-foundation`)

### Task 1: Branch + design tokens (fonts, colors, Bootstrap variables)

**Files:**
- Modify: `app/assets/stylesheets/config/_fonts.scss` (whole file)
- Modify: `app/assets/stylesheets/config/_colors.scss` (append palette)
- Modify: `app/assets/stylesheets/config/_bootstrap_variables.scss`
- Modify: `app/views/layouts/application.html.erb` (font links in `<head>`)

**Interfaces:**
- Produces SCSS vars consumed by every later task: `$headers-font`,
  `$body-font`, `$mono-font`, `$accent-font`, `$space-black`, `$panel-bg`,
  `$panel-border`, `$text-bright`, `$text-body`, `$text-muted`, `$sky-blue`,
  `$purple`, `$input-dark`.

- [ ] **Step 1: Create the branch**

```bash
git checkout main && git pull && git checkout -b design/p1-foundation
```

- [ ] **Step 2: Load fonts from the layout `<head>`** (NOT a SCSS
  `@import` — a `<link>` starts the font fetch in parallel with the main
  CSS; the SCSS route serializes it and makes the 132px hero headline FOUT
  visibly). In `app/views/layouts/application.html.erb`, directly above the
  `stylesheet_link_tag` line, add:

```erb
<%# Design fonts (Depth Charge handoff): Bricolage Grotesque (headings),
    Instrument Serif (italic accent), Space Grotesk (body), Space Mono
    (labels). Loaded as <link> so the fetch starts alongside the CSS. %>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,600;12..96,700;12..96,800&family=Instrument+Serif:ital@0;1&family=Space+Grotesk:wght@400;500;600;700&family=Space+Mono:wght@400;700&display=swap" rel="stylesheet">
```

- [ ] **Step 3: Replace `_fonts.scss` contents** (vars only — the `@import
  url(...)` for Nunito/Work Sans is deleted; loading moved to the layout):

```scss
// Font variables for the Depth Charge design. The actual Google Fonts
// <link> lives in the layout <head> so it loads in parallel with the CSS.
// Every stack ends in a generic family so a failed font load degrades to a
// readable system font.
$body-font: "Space Grotesk", "Helvetica Neue", sans-serif;
$headers-font: "Bricolage Grotesque", "Helvetica Neue", sans-serif;
$mono-font: "Space Mono", "SFMono-Regular", monospace;
$accent-font: "Instrument Serif", Georgia, serif;
```

- [ ] **Step 4: Append the space palette to `_colors.scss`** (keep every
  existing variable — other files still reference them):

```scss

// Depth Charge design palette (docs/design-handoff/README.md).
// Near-black space background, glass panels, soft text scale, sky accent.
$space-black: #040507;                    // body background
$panel-bg: rgba(11, 13, 18, 0.62);        // glass card background
$panel-border: rgba(255, 255, 255, 0.08); // glass card border
$text-bright: #e9ecf1;                    // headings / primary text
$text-body: #aeb7c1;                      // paragraphs
$text-muted: #7f8a95;                     // labels / de-emphasised text
$sky-blue: #5fb0ff;                       // eyebrows, stat numbers, links
$input-dark: #05060a;                     // form control background
$purple: #6f2bdd;                         // brand purple, promoted from a
                                          // hardcoded hex in _text.scss
```

- [ ] **Step 5: Retheme `_bootstrap_variables.scss`** — replace the
  "General style", "Colors" and radius sections with:

```scss
// General style
$font-family-sans-serif: $body-font;
$headings-font-family: $headers-font;
$font-size-base: 1rem;

// Depth Charge dark theme: near-black body, light text.
$body-bg: $space-black;
$body-color: $text-bright;

// Colors
$primary: $blue;
$secondary: $gray;
$success: $green;
$info: $cyan;
$danger: $red;
$warning: $orange;
$tertiary: $lightest_gray;

// Links use the design's sky accent.
$link-color: $sky-blue;
$link-decoration: none;
$link-hover-color: lighten($sky-blue, 12%);

// Dark form controls (design: #05060a fields with faint white borders).
$input-bg: $input-dark;
$input-color: $text-bright;
$input-border-color: rgba(255, 255, 255, 0.12);
$input-placeholder-color: $text-muted;
$input-focus-border-color: $sky-blue;
$input-focus-box-shadow: 0 0 0 0.2rem rgba(95, 176, 255, 0.15);

// Buttons & inputs' radius — the design uses a 10–18px radius range.
$border-radius-sm: 0.5rem;
$border-radius: 0.625rem;   // ~10px, buttons/inputs
$border-radius-lg: 0.75rem; // ~12px, CTAs
$border-radius-xl: 1rem;    // ~16px, cards
$border-radius-xxl: 1.125rem; // ~18px, large panels
```

- [ ] **Step 6: Compile check + full suite**

Run: `bin/rails assets:precompile && bin/rails assets:clobber && bin/rails test`
Expected: precompile succeeds (SCSS compiles); 185 runs, 0 failures.

- [ ] **Step 7: Commit**

```bash
git add app/assets/stylesheets/config app/views/layouts/application.html.erb
git commit -m "feat(design): swap tokens to Depth Charge fonts and dark palette"
```

### Task 2: Dark-mode base — layout, hardcoded-light sweep, component classes

**Files:**
- Modify: `app/views/layouts/application.html.erb:2` (`<html>` tag)
- Modify: `app/assets/stylesheets/components/_body.scss` (**critical** —
  its `body { background-color: $white; }` loads AFTER Bootstrap and would
  silently defeat the dark theme)
- Modify: `app/assets/stylesheets/components/_text.scss` (flip to light-on-dark)
- Modify: `app/assets/stylesheets/components/_cards.scss` (drop fixed heights)
- Audit: `app/assets/stylesheets/components/_buttons.scss`, `_social.scss`
  (retoken any light-theme colors found)
- Create: `app/assets/stylesheets/components/_design_system.scss`
- Modify: `app/assets/stylesheets/components/_index.scss` (import it)

**Interfaces:**
- Produces CSS classes consumed by all view tasks: `.glass-card`,
  `.glass-card--hover`, `.section-eyebrow`, `.section-heading`, `.chip`,
  `.chip--learning`, `.timeline-row`, `.sec`, `.section-inner`,
  `.framed-media`, `.text-body-soft`, `.text-soft-muted`.

- [ ] **Step 1: Turn on Bootstrap dark variants** — in
  `app/views/layouts/application.html.erb` change `<html>` to
  `<html data-bs-theme="dark">`. (Bootstrap 5.3 then darkens dropdowns,
  modals, close buttons etc. on CMS screens for free.)

- [ ] **Step 2: Fix `_body.scss`** — change `background-color: $white;` to
  `background-color: $space-black;` (this file wins the cascade over
  Bootstrap's `$body-bg`, so without this the site stays white). Keep the
  `scroll-behavior: smooth` rule.

- [ ] **Step 3: Flip the text scale** — `_text.scss` currently colors
  headings/body for a light background. Read the file; change base heading
  and paragraph colors to the dark-theme tokens (`h1–h5 { color:
  $text-bright; }`, body text helpers to `$text-body`), keep the `.h1-d` /
  `.p-d` "dark background" variants working (they can simply alias the new
  base colors), replace the hardcoded `#6f2bdd` with `$purple`, and keep
  `.gray-link` / `.gray-non-link` but recolor to `$text-muted` with
  `$text-bright` hover. Add two utilities:

```scss
// Soft text tones from the design (body copy + muted meta text).
.text-body-soft { color: $text-body; }
.text-soft-muted { color: $text-muted; }
```

- [ ] **Step 4: Remove ALL fixed card heights in `_cards.scss`** — delete
  the fixed `height:` rules from `.card-project` (530px), `.card-blog-post`
  (690px), `.card-education` (160px), `.card-skills` (160px). Cards size to
  content in the new design; keep the class names so old views still render
  until their phase rewrites them.

- [ ] **Step 5: Audit `_buttons.scss` and `_social.scss`** for light-theme
  assumptions (`$white`/`$black`/`$gray` used as text-on-light) and retoken
  what would be unreadable on dark. Small files — read fully, adjust only
  what's wrong.

- [ ] **Step 6: Create `_design_system.scss`** with the design language
  translated from the mock's inline styles (import it last in
  `components/_index.scss`):

```scss
// Depth Charge design system — reusable classes translated from the mock
// (docs/design-handoff/louis-bourne-scroll-site-depth-charge.dc.html).
// Inline styles in the mock become these classes so every page reuses them.

// Full-viewport scroll section. On phones the design centers content.
.sec {
  min-height: 100vh;
  display: flex;
  align-items: center;
  padding: 80px 6vw;
  position: relative;
  z-index: 2;

  @media (max-width: 820px) {
    justify-content: center !important;
    padding: 96px 22px !important;
  }
}

// Content column inside a .sec (sits above the canvas).
.section-inner { position: relative; z-index: 1; width: 100%; }

// Anchor jumps must clear the fixed navbar.
section[id] { scroll-margin-top: 90px; }

// Glass panel card — blur + faint border; solid fallback color first so
// browsers without backdrop-filter still get a readable panel.
.glass-card {
  background: rgb(11, 13, 18); // fallback
  background: $panel-bg;
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
  border: 1px solid $panel-border;
  border-radius: $border-radius-xl;
  transition: transform 0.35s, border-color 0.35s, box-shadow 0.35s;

  &.glass-card--hover:hover {
    transform: translateY(-6px);
    border-color: $blue;
    box-shadow: 0 22px 50px rgba(16, 98, 254, 0.18);
  }
}

// Mono eyebrow label above each section heading: "◆ Selected Work".
.section-eyebrow {
  font-family: $mono-font;
  font-size: 12px;
  letter-spacing: 0.34em;
  text-transform: uppercase;
  color: $sky-blue;
  margin-bottom: 14px;
}

// Big Bricolage section heading with fluid size.
.section-heading {
  font-family: $headers-font;
  font-weight: 700;
  font-size: clamp(1.9rem, 3.6vw, 2.8rem);
  letter-spacing: -0.025em;
  color: $text-bright;
}

// Tech chips: solid = known, dashed = learning.
.chip {
  display: inline-block;
  font-family: $mono-font;
  font-size: 13px;
  color: #dbe1e8;
  background: rgba(11, 13, 18, 0.55);
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 999px;
  padding: 9px 16px;
}

.chip--learning {
  color: $text-muted;
  background: transparent;
  border-style: dashed;
  border-color: rgba(255, 255, 255, 0.2);
}

// Education timeline row: mono year column | detail column.
.timeline-row {
  display: grid;
  grid-template-columns: 120px 1fr;
  gap: 20px;
  padding: 18px 0;
  border-top: 1px solid rgba(255, 255, 255, 0.1);

  .timeline-year {
    font-family: $mono-font;
    font-size: 12.5px;
    color: $sky-blue;
  }
}

// Framed media panel (YouTube embeds): border + deep shadow, design demo style.
.framed-media {
  border-radius: $border-radius-xl;
  overflow: hidden;
  border: 1px solid rgba(255, 255, 255, 0.12);
  box-shadow: 0 30px 70px rgba(0, 0, 0, 0.5);

  iframe { display: block; border: 0; width: 100%; }
}

// Homepage project/blog card internals (shared by home + index pages).
.project-thumb {
  width: 150px;
  aspect-ratio: 16 / 11;
  object-fit: cover;
  border-radius: $border-radius-sm;
  flex: 0 0 auto;
}

.project-card-title {
  font-family: $headers-font;
  font-weight: 700;
  font-size: 19px;
  color: $text-bright;
}

.project-tech-line {
  font-family: $mono-font;
  font-size: 11px;
  color: #6d7c9c;
}

// Stat tiles (by the numbers).
.stat-tile { padding: 24px 14px; }

.stat-number {
  font-family: $headers-font;
  font-weight: 800;
  font-size: 44px;
  line-height: 1;
  color: $sky-blue;
}

.stat-label {
  font-family: $mono-font;
  font-size: 10px;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: #8b95a1;
  margin-top: 8px;
}
```

- [ ] **Step 7: Gate**

Run: `bin/rails assets:precompile && bin/rails assets:clobber && bin/rails test`
Expected: compile OK; 185 runs, 0 failures.

- [ ] **Step 8: Commit**

```bash
git add app/views/layouts/application.html.erb app/assets/stylesheets
git commit -m "feat(design): dark base theme, light-rule sweep, design-system components"
```

### Task 3: Navbar restyle

**Files:**
- Modify: `app/views/shared/_navbar.html.erb`
- Modify: `app/assets/stylesheets/components/_navbar.scss`

**Interfaces:**
- Consumes: `nav_link_class` / `nav_link_dropdown_class` helpers (unchanged).
- Keep ALL existing links/routes and the signed-in dropdown structure —
  this is a restyle, not a nav redesign.

- [ ] **Step 1: Restyle the nav wrapper** — in `_navbar.html.erb` remove the
  inline `style="background-color: rgba(0, 0, 0, 0.90);"` and keep classes
  `navbar navbar-expand-sm navbar-dark navbar-lb`. Next to the logo add the
  wordmark (design: logo + name):

```erb
<%= link_to "/", class: "navbar-brand ms-2 d-flex align-items-center gap-2" do %>
  <%= image_tag "lb-circle-logo-light-tp.png", alt: "Logo" %>
  <span class="navbar-wordmark">Louis Bourne</span>
<% end %>
```

- [ ] **Step 2: Dark-sweep the dropdown** — the "Log out" link is
  `class: "dropdown-item text-dark fs-5"` (`_navbar.html.erb:32`); inside
  the now-dark dropdown that's unreadable. Change to
  `class: "dropdown-item fs-5"` (dropdown items inherit the dark-theme
  color). Grep the file for any other `text-dark`/`text-black`.

- [ ] **Step 3: Update `_navbar.scss`** — keep the fixed positioning rule,
  replace the background with the design's gradient glass bar:

```scss
.navbar-lb {
  background: linear-gradient(rgba(4, 5, 7, 0.8), rgba(4, 5, 7, 0));
  backdrop-filter: blur(6px);
  -webkit-backdrop-filter: blur(6px);
}

.navbar-wordmark {
  font-family: $headers-font;
  font-weight: 700;
  font-size: 15.5px;
  color: $text-bright;
}
```

  Keep `.avatar` sizing. The "Contact Me" button keeps `btn btn-primary`
  (now dark-radius themed by tokens).

- [ ] **Step 4: Gate + commit**

Run: `bin/rails test` → 185 runs, 0 failures.

```bash
git add app/views/shared/_navbar.html.erb app/assets/stylesheets/components/_navbar.scss
git commit -m "feat(design): glass gradient navbar with wordmark"
```

### Task 4: Footer rewrite (semantic `<footer>`)

**Files:**
- Test: `test/controllers/pages_controller_test.rb` (add assertion)
- Modify: `app/views/shared/_footer.html.erb` (rewrite)
- Modify: `app/assets/stylesheets/components/_design_system.scss` (append)

**Interfaces:**
- Produces: a top-level `<footer>` element — the black-hole engine's
  end-of-scroll anchor queries `document.querySelector("footer")` (Task 6+).
- Keeps all four social links (GitHub/LinkedIn/Discord/Email), the legal
  links, and the conditional Login link.

- [ ] **Step 1: Write the regression-guard test** — in
  `test/controllers/pages_controller_test.rb` add:

```ruby
test "home renders a semantic footer element (black-hole end anchor)" do
  get root_path
  # The canvas engine parks the hole between the contact form and the
  # footer at the end of scroll — it needs a real <footer> element.
  assert_select "footer", 1
end
```

- [ ] **Step 2: Run it** — the current markup nests `<footer>` inside a
  styled div, so this may already pass; keep it as a regression guard
  either way and continue.

Run: `bin/rails test test/controllers/pages_controller_test.rb`

- [ ] **Step 3: Rewrite `_footer.html.erb`** as a semantic top-level footer
  in the design language, KEEPING: Login link condition, Terms/Privacy
  links, all four social links, and making the year dynamic:

```erb
<%# Site footer — Depth Charge design. Semantic <footer> is load-bearing:
    the black-hole engine measures it to park the hole at end of scroll. %>
<footer class="site-footer mt-5">
  <div class="container-fluid py-4 px-4">
    <div class="row g-4 align-items-center">
      <div class="col-12 col-md-4">
        <div class="d-flex flex-column flex-md-row justify-content-center justify-content-md-start align-items-center gap-3 gap-md-4">
          <% if !user_signed_in? && current_page?("/projects") %>
            <%= link_to "Login", new_user_session_path, class: "gray-link text-decoration-none" %>
          <% end %>
          <%= link_to "Terms of Use", terms_of_service_path, class: "gray-link text-decoration-none" %>
          <%= link_to "Privacy Policy", privacy_policy_path, class: "gray-link text-decoration-none" %>
        </div>
      </div>
      <div class="col-12 col-md-4 text-center">
        <div class="gray-non-link footer-copyright">
          © <%= Date.current.year %> Louis Bourne · Thailand
        </div>
      </div>
      <div class="col-12 col-md-4">
        <div class="social-horizontal d-flex justify-content-center justify-content-md-end align-items-center gap-4">
          <%= link_to "https://github.com/louiskb", target: "_blank", rel: "noopener", "aria-label": "GitHub" do %>
            <i class="fa-brands fa-github fs-5"></i>
          <% end %>
          <%= link_to "https://www.linkedin.com/in/louis-bourne/", target: "_blank", rel: "noopener", "aria-label": "LinkedIn" do %>
            <i class="fa-brands fa-linkedin fs-5"></i>
          <% end %>
          <%= link_to "https://discord.com/users/brothercap", target: "_blank", rel: "noopener", "aria-label": "Discord" do %>
            <i class="fa-brands fa-discord fs-5"></i>
          <% end %>
          <%= link_to "mailto:dev@louisbourne.me", "aria-label": "Email" do %>
            <i class="fa-solid fa-envelope fs-5"></i>
          <% end %>
        </div>
      </div>
    </div>
  </div>
</footer>
```

  Append to `_design_system.scss`:

```scss
// Footer: translucent divider strip above near-black background.
.site-footer {
  position: relative;
  z-index: 2;
  background: rgba(4, 5, 7, 0.7);
  backdrop-filter: blur(8px);
  border-top: 1px solid $panel-border;

  .footer-copyright {
    font-family: $mono-font;
    font-size: 11px;
  }
}
```

- [ ] **Step 4: Gate**

Run: `bin/rails test`
Expected: 186 runs (new test), 0 failures.

- [ ] **Step 5: Commit + phase browser sweep**

```bash
git add app/views/shared/_footer.html.erb app/assets/stylesheets/components/_design_system.scss test/controllers/pages_controller_test.rb
git commit -m "feat(design): semantic dark footer with dynamic year"
```

  Then run the app (`bin/rails server`) and browser-verify Phase 1: home,
  projects, blog, a blog post, sign-in page — all dark, readable, navbar +
  footer coherent, at 1440px and 375px. Fix regressions found (e.g. old
  hero/waves sections may look rough on home — acceptable; they are
  rewritten in Phase 2 — but nothing may be *unreadable*). Push and open
  PR 1 (`gh pr create`), base `main`.

---

## Phase 2 — Engine + homepage (branch `design/p2-homepage` off p1)

### Task 5: Port the black-hole engine to a Stimulus controller

**Files:**
- Create: `app/javascript/controllers/black_hole_controller.js`
- Create: `app/assets/stylesheets/components/_black_hole.scss`
- Modify: `app/assets/stylesheets/components/_index.scss` (import it)

**Interfaces:**
- Produces: Stimulus controller `black-hole` with values `intensity`
  (Number, default 70), `animate` (Boolean, default true), `starfield`
  (Boolean, default true); canvas target `canvas`. Reads page DOM:
  `[data-sec]` sections, `[data-morph="1"|"2"|"sub"]` hero spans,
  `#contact form`, `footer`.

- [ ] **Step 1: Create the phase branch FIRST**

```bash
git checkout -b design/p2-homepage
```

- [ ] **Step 2: Port the engine.** Source: ONLY the body of `initBH(cv) {
  ... }` inside the mock's `<script data-dc-script>` block in
  `docs/design-handoff/louis-bourne-scroll-site-depth-charge.dc.html`,
  plus the `PAL` class field. Everything else in that script —
  `class Component extends DCLogic`, `componentDidMount`,
  `componentWillUnmount`, `boot()`, `renderVals()` — is Claude-Design
  framework glue: DISCARD it; the Stimulus wrapper below replaces it.
  Create the controller with this exact wrapper and copy the engine
  functions verbatim into `initBH(cv)`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Black-hole canvas engine — ported from the Depth Charge design handoff
// (docs/design-handoff/louis-bourne-scroll-site-depth-charge.dc.html).
// Homepage only. Depth camera follows scroll; hovering the hole charges it
// (idle → charging → hold → decay → explode); explosions morph the hero
// text between "web developer" and "Louis Bourne".
export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    intensity: { type: Number, default: 70 },
    animate: { type: Boolean, default: true },
    starfield: { type: Boolean, default: true }
  }

  // Accretion-disk palette, inner → outer (from the mock).
  PAL = [[240, 248, 255], [85, 205, 245], [42, 120, 250], [85, 95, 232], [150, 82, 220], [210, 84, 162]]

  connect() {
    // A canvas failure must never break the page — content sits above the
    // canvas and works without it.
    try {
      this.ctrl = this.initBH(this.canvasTarget)
    } catch (e) {
      console.error("black-hole engine failed to start", e)
    }
    // Turbo snapshots the DOM before caching a page. Reset the morphing
    // hero text and clear the canvas first, so back-navigation never
    // flashes a half-morphed headline or a frozen frame.
    this.beforeCache = () => {
      if (this.ctrl && this.ctrl.resetForCache) this.ctrl.resetForCache()
    }
    document.addEventListener("turbo:before-cache", this.beforeCache)
  }

  disconnect() {
    // Turbo-safe teardown: stop the rAF loop and remove window listeners.
    document.removeEventListener("turbo:before-cache", this.beforeCache)
    if (this.ctrl && this.ctrl.stop) this.ctrl.stop()
    this.ctrl = null
  }

  initBH(cv) {
    // === Engine body: copied VERBATIM from the mock's initBH(cv), with
    // === exactly these substitutions (the spec's four divergences):
    // 1. const inten=(self.props.intensity!=null?self.props.intensity:70)/70;
    //      → const inten = this.intensityValue / 70;
    //    const animate=self.props.animate!==false;
    //      → const animate = this.animateValue;
    //    const starsOn=self.props.starfield!==false;
    //      → const starsOn = this.starfieldValue;
    //    const PAL=self.PAL → const PAL = this.PAL; delete `const self=this;`
    // 2. DELETE the countUp() function, and in render() DELETE the line
    //    `if(role==='numbers'&&!counted){ counted=true; countUp(); }`
    //    (the app's tested count_up Stimulus controller owns that animation;
    //    also delete the now-unused `counted` variable, and `role` if unused).
    // 3. The returned object gains a resetForCache() method alongside stop():
    //      return {
    //        stop(){ ...verbatim from the mock... },
    //        resetForCache(){ renderText(0); ctx.clearRect(0, 0, w, h); }
    //      }
    // 4. Everything else — build/resize/readScroll/blendStr/morphSub/
    //    renderText/spawnBurst/stepCharge/drawParts/drawOrbits/drawBurst/
    //    render/loop and the listener setup — UNCHANGED, including the
    //    reduced-motion branch and single-quoted strings inside the copied
    //    engine code (verbatim copy beats style points; keep the copied
    //    block as-is).
  }
}
```

- [ ] **Step 3: Create `_black_hole.scss`** (import in `_index.scss`):

```scss
// Fixed full-viewport canvas behind the homepage sections.
.black-hole-canvas {
  position: fixed;
  inset: 0;
  width: 100vw;
  height: 100vh;
  z-index: 0;
  display: block;
}

// The homepage scroll scene: content layers above the fixed canvas.
.bh-scene {
  position: relative;
  overflow-x: hidden;
}
```

- [ ] **Step 4: Syntax gate** — controllers are eager-loaded via importmap;
  a parse error breaks all Stimulus. Check:

Run: `node --check app/javascript/controllers/black_hole_controller.js`
Expected: no output (parses).

- [ ] **Step 5: Run suite + commit**

Run: `bin/rails test` → green.

```bash
git add app/javascript/controllers/black_hole_controller.js app/assets/stylesheets/components
git commit -m "feat(design): port Depth Charge black-hole engine to Stimulus"
```

### Task 6: Home shell — wrapper, canvas, main id, section attributes

**Files:**
- Test: `test/controllers/pages_controller_test.rb`
- Modify: `app/views/pages/home.html.erb`
- Create: `app/views/pages/_latest_posts.html.erb` (placeholder only)

**Interfaces:**
- Consumes: `black-hole` controller (Task 5).
- Produces: the `data-sec` scene every remaining Phase-2 task's partial
  lives in. Section attribute map (10 sections, camera anchors from the
  mock, alternating sides):
  hero-banner→hero/0.66, featured-projects→work/0.34,
  by-the-numbers→numbers/0.5, demo-day→demo/0.66, tech-stack→stack/0.34,
  related-skills→background/0.66, education→education/0.34,
  about-me→about/0.66, latest-posts→blog/0.34, contact→contact/0.5.
  (Partials themselves carry the attributes on their `<section>` tags;
  this task only builds the shell; `_latest_posts` content arrives in
  Task 9.)

- [ ] **Step 1: Write failing tests**

```ruby
test "home renders the black-hole scene wiring" do
  get root_path
  assert_select "[data-controller='black-hole']", 1
  assert_select "canvas[data-black-hole-target='canvas']", 1
  # Skip-link target from the layout must exist on the page.
  assert_select "main#main-content", 1
end
```

- [ ] **Step 2: Run — expect FAIL** (no black-hole wiring yet).

Run: `bin/rails test test/controllers/pages_controller_test.rb`

- [ ] **Step 3: Rewrite `home.html.erb`**

```erb
<%# Portfolio home — the Depth Charge single-page scroll scene. One fixed
    canvas renders the black hole behind every section; each section carries
    data-sec attributes the engine's depth camera reads. %>
<div class="bh-scene"
     data-controller="black-hole"
     data-black-hole-intensity-value="70"
     data-black-hole-animate-value="true"
     data-black-hole-starfield-value="true">
  <canvas class="black-hole-canvas" data-black-hole-target="canvas"></canvas>

  <header>
    <%= render "landing_hero_banner" %>
  </header>
  <main id="main-content">
    <%= render "featured_projects" %>
    <%= render "by_the_numbers" %>
    <%= render "demo_day" %>
    <%= render "tech_stack" %>
    <%= render "related_skills" %>
    <%= render "education" %>
    <%= render "about_me" %>
    <%= render "latest_posts" %>
    <%= render "contact" %>
  </main>
</div>
```

  Create `app/views/pages/_latest_posts.html.erb` as a placeholder so this
  task stays independently green — its full content lands in Task 9 via
  TDD:

```erb
<%# Latest blog posts — implemented with @latest_posts in a later task. %>
```

- [ ] **Step 4: Run tests — expect PASS**, then commit

Run: `bin/rails test` → green.

```bash
git add app/views/pages test/controllers/pages_controller_test.rb
git commit -m "feat(design): home black-hole scene shell with canvas and main id"
```

### Task 7: Hero section (morph headline)

**Files:**
- Modify: `app/views/pages/_landing_hero_banner.html.erb` (rewrite)
- Modify: `app/assets/stylesheets/components/_landing_hero_banner.scss` (replace)

**Interfaces:**
- Produces `[data-morph="1"/"2"/"sub"]` spans the engine's `renderText`
  targets. Default text MUST read correctly without JS: "web developer".

- [ ] **Step 1: Rewrite the hero partial** (translation of the mock's hero,
  real links, existing social URLs):

```erb
<%# Hero — Depth Charge. The headline spans are morph targets: the engine
    scrambles "web developer" toward "Louis Bourne" as the hole charges. %>
<section id="hero-banner" class="sec justify-content-start"
         data-sec data-role="hero" data-ax="0.66" data-label="Hero">
  <div class="hero-scrim"></div>
  <div class="hero-content">
    <p class="hero-kicker">Full-Stack Developer · Thailand</p>
    <h1 class="hero-headline">
      <span data-morph="1" class="hero-word-display">web</span>
      <span data-morph="2" class="hero-word-accent">developer</span>
    </h1>
    <p data-morph="sub" class="hero-sub text-body-soft">Louis Bourne, full-stack developer building production Ruby-on-Rails products from Thailand.</p>
    <div class="d-flex gap-3 mt-4 flex-wrap">
      <%= link_to "Contact Me", "#contact", class: "btn btn-primary btn-lg" %>
      <%= link_to "Key Projects", "#featured-projects", class: "btn btn-outline-light btn-lg" %>
    </div>
    <div class="d-flex align-items-center gap-4 mt-4 hero-social">
      <%= link_to "https://github.com/louiskb", target: "_blank", rel: "noopener", "aria-label": "GitHub" do %>
        <i class="fa-brands fa-github"></i>
      <% end %>
      <%= link_to "https://www.linkedin.com/in/louis-bourne/", target: "_blank", rel: "noopener", "aria-label": "LinkedIn" do %>
        <i class="fa-brands fa-linkedin"></i>
      <% end %>
      <%= link_to "https://discord.com/users/brothercap", target: "_blank", rel: "noopener", "aria-label": "Discord" do %>
        <i class="fa-brands fa-discord"></i>
      <% end %>
      <%= link_to "mailto:dev@louisbourne.me", "aria-label": "Email" do %>
        <i class="fa-solid fa-envelope"></i>
      <% end %>
    </div>
    <p class="hero-hint">↪ Hover the black hole to charge it · scroll to descend</p>
  </div>
</section>
```

- [ ] **Step 2: Replace `_landing_hero_banner.scss`** (drop the old bg-image
  styles for the hero itself; keep the `.bg-waves-1/2` rules for now —
  demo/about still use them until Task 8 rewrites those partials and
  deletes the rules):

```scss
// Hero — Depth Charge. A radial scrim keeps the headline readable over the
// black-hole canvas without hiding it.
#hero-banner {
  .hero-scrim {
    position: absolute;
    inset: 0;
    pointer-events: none;
    z-index: 0;
    background: radial-gradient(90% 120% at 22% 50%, rgba(4, 5, 7, 0.8) 4%, rgba(4, 5, 7, 0) 62%);
  }

  .hero-content { max-width: 620px; position: relative; z-index: 1; }

  .hero-kicker {
    font-family: $mono-font;
    font-size: 12.5px;
    letter-spacing: 0.4em;
    text-transform: uppercase;
    color: $text-muted;
  }

  .hero-headline { margin: 20px 0 0; color: $text-bright; }

  // Morph targets get fixed metrics so text scrambling never reflows.
  .hero-word-display {
    display: block;
    font-family: $headers-font;
    font-weight: 800;
    font-size: clamp(3rem, 9vw, 132px);
    line-height: 0.86;
    letter-spacing: -0.045em;
  }

  .hero-word-accent {
    display: block;
    font-family: $accent-font;
    font-style: italic;
    font-weight: 400;
    font-size: clamp(3.2rem, 9.5vw, 138px);
    line-height: 0.82;
    letter-spacing: -0.01em;
    color: #e9f0ff;
    margin-top: 2px;
  }

  .hero-sub { margin-top: 26px; font-size: 18px; max-width: 470px; min-height: 56px; }

  .hero-social a { color: $text-muted; font-size: 18px; transition: color 0.2s; &:hover { color: $text-bright; } }

  .hero-hint {
    margin-top: 24px;
    font-family: $mono-font;
    font-size: 11px;
    letter-spacing: 0.18em;
    text-transform: uppercase;
    color: #5a6572;
  }
}
```

  Check whether the hero was the only consumer of the vertical social bar:
  `grep -rn "social_vertical_bar" app/` — if so, delete
  `app/views/pages/_social_vertical_bar.html.erb`.

- [ ] **Step 3: Gate + commit**

Run: `bin/rails test` → green. Load the page in a browser: hero reads "web
developer", canvas behind, hover near center charges + explodes + morphs.

```bash
git add app/views/pages app/assets/stylesheets/components
git commit -m "feat(design): Depth Charge hero with morph headline"
```

### Task 8: Restyle the seven content sections

**Files:**
- Modify: `app/views/pages/_featured_projects.html.erb`
- Modify: `app/views/pages/_by_the_numbers.html.erb`
- Modify: `app/views/pages/_demo_day.html.erb`
- Modify: `app/views/pages/_tech_stack.html.erb`
- Modify: `app/views/pages/_related_skills.html.erb`
- Modify: `app/views/pages/_education.html.erb`
- Modify: `app/views/pages/_about_me.html.erb`
- Modify: `app/assets/stylesheets/pages/_home.scss` (keep scroll-reveal CSS;
  delete rules for removed markup), `_landing_hero_banner.scss` (delete
  `.bg-waves-*` now that nothing uses them)

**Interfaces:**
- Consumes `.sec`, `.section-inner`, `.glass-card`, `.glass-card--hover`,
  `.section-eyebrow`, `.section-heading`, `.chip`, `.chip--learning`,
  `.timeline-row`, `.framed-media`, `.project-thumb`, `.project-card-title`,
  `.project-tech-line`, `.stat-tile`, `.stat-number`, `.stat-label`
  (Task 2) and the section attribute map (Task 6).
- MUST preserve: `#by-the-numbers` + `scroll-reveal`/`count-up` wiring;
  each section's existing `id`; `project.title.capitalize` (the visibility
  test relies on canonical capitalization).

Read each current partial FIRST — carry over its real copy, data, links,
and analytics attributes; only the presentation changes. The wrapper
pattern for every section:

```erb
<section id="<current-id>" class="sec <justify class>"
         data-sec data-role="<role>" data-ax="<ax>" data-label="<Label>">
  <div class="section-inner" style="max-width: <620–760>px;">
    <p class="section-eyebrow">◆ <Eyebrow></p>
    <h2 class="section-heading mb-4"><Heading.></h2>
    …content…
  </div>
</section>
```

with `justify-content-start` for ax 0.66 (content left, hole right),
`justify-content-end` for ax 0.34, `justify-content-center` for ax 0.5.

- [ ] **Step 1: `_featured_projects`** — eyebrow "◆ Selected Work", heading
  "Featured projects."; keep the two groups (`@personal_projects` with a
  mono group label "Personal", then `@open_source_projects` under
  "Open source"); each project renders as a horizontal glass card:

```erb
<div class="glass-card glass-card--hover p-3 d-flex gap-3 mb-3">
  <% if project.featured_image.attached? %>
    <%= image_tag project.featured_image, alt: project.title, class: "project-thumb" %>
  <% elsif project.img_url.present? %>
    <%= image_tag project.img_url, alt: project.title, class: "project-thumb" %>
  <% end %>
  <div class="d-flex flex-column">
    <h3 class="project-card-title"><%= project.title.capitalize %></h3>
    <p class="text-body-soft mb-2"><%= project.description %></p>
    <div class="mt-auto project-tech-line"><%= project.tech_stack %></div>
    <%# keep the existing GitHub / live-site links + private-repo badge
        markup from the current partial here (restyled with .gray-link) %>
  </div>
</div>
```

  NOTE the `.capitalize` — the current partial renders
  `project.title.capitalize` and the draft-visibility test comment depends
  on canonical capitalization; do not drop it.

- [ ] **Step 2: `_by_the_numbers`** — keep the section tag's id +
  `data-controller="scroll-reveal"`, ADD the data-sec attributes
  (`data-role="numbers" data-ax="0.5"`); keep the 5-stat hash loop, tiles
  become glass cards, numbers keep count-up wiring EXACTLY:

```erb
<section id="by-the-numbers" class="sec justify-content-center"
         data-sec data-role="numbers" data-ax="0.5" data-label="By the Numbers"
         data-controller="scroll-reveal">
  <div class="section-inner text-center" style="max-width: 760px;">
    <p class="section-eyebrow">◆ By the Numbers</p>
    <h2 class="section-heading mb-4">By the numbers.</h2>
    <div class="row g-3">
      <% {
        projects_count: "Projects shipped",
        blog_posts_count: "Blog posts",
        technologies_count: "Technologies",
        years_coding: "Years coding",
        years_trading: "Years in markets"
      }.each do |key, label| %>
        <div class="col-6 col-md" data-scroll-reveal-target="fromBottom">
          <div class="glass-card stat-tile h-100">
            <p class="stat-number"
               data-controller="count-up"
               data-count-up-target-value="<%= @stats[key] %>">
              <%= @stats[key] %>
            </p>
            <p class="stat-label mb-0"><%= label %></p>
          </div>
        </div>
      <% end %>
    </div>
  </div>
</section>
```

  Keep the partial's existing teaching comment block at the top, updated to
  note the Depth Charge restyle happened.

- [ ] **Step 3: `_demo_day`** — eyebrow "◆ Demo Day", heading "Le Wagon
  Tokyo demo day.", existing copy + Market Sensei link, current iframe
  wrapped in `<div class="framed-media">…</div>`. Remove `.bg-waves-1` use.

- [ ] **Step 4: `_tech_stack`** — eyebrow "◆ Technology & Skills", heading
  "The tools I reach for."; mono sub-label "What I know" then chips derived
  from the CURRENT partial's icon list — read the partial and use each
  icon's name/alt text (the real list includes Figma and Storybook.js,
  which the mock omits; the real content wins per the translation rule).
  Then sub-label "Learning" with `.chip.chip--learning` spans for React and
  Vue.js. Plain spans, not links (spec decision).

- [ ] **Step 5: `_related_skills`** — eyebrow "◆ Related Skills", heading
  "Skills & background.", intro line, then the current three cards as
  stacked `.glass-card` blocks (`p-3`, title in `.project-card-title`
  style, body in `.text-body-soft`), current copy.

- [ ] **Step 6: `_education`** — eyebrow "◆ Education", heading "Education &
  certifications."; current entries as `.timeline-row`s (year in
  `.timeline-year`, right cell: institution bold Bricolage + program in
  `.text-body-soft`); KEEP the "Download Full Resume" button
  (`btn btn-outline-light`, same `resume_path` link + any analytics data
  attributes it carries today — read the current partial first).

- [ ] **Step 7: `_about_me`** — eyebrow "◆ About Me", heading "About me.",
  current paragraphs in `.text-body-soft` (16.5px), existing YouTube embed
  in `.framed-media`. Remove `.bg-waves-2` use; delete the `.bg-waves-*`
  rules from `_landing_hero_banner.scss` now.

- [ ] **Step 8: Gate**

Run: `bin/rails test`
Expected: all green — including the untouched by-the-numbers assertions.

- [ ] **Step 9: Commit**

```bash
git add app/views/pages app/assets/stylesheets
git commit -m "feat(design): restyle home content sections in Depth Charge language"
```

### Task 9: Latest posts section (TDD)

**Files:**
- Test: `test/controllers/pages_controller_test.rb`
- Modify: `app/controllers/pages_controller.rb:6-13` (add `@latest_posts`)
- Modify: `app/views/pages/_latest_posts.html.erb` (replace placeholder)

**Interfaces:**
- Consumes: `BlogPost.visible_to_visitors` (Publishable scope),
  `blog_post.reading_time` (returns the FULL string, e.g. `"4 min read"` —
  do NOT append "min read" again), `blog_post.ai_label`,
  `blog_post.blog_excerpt`, `blog_post.tags`, FriendlyId slugs
  (`blog_post_path(post)`).
- Fixtures: `test/fixtures/users.yml` defines `louis` (the owner) and
  `intruder` — use `users(:louis)`. `test/fixtures/blog_posts.yml` has two
  published posts (`welcome`, `deploying` — status defaults to published);
  check for a draft fixture and add one only if missing.

- [ ] **Step 1: Write failing tests**

```ruby
test "home shows up to three latest published posts and never drafts" do
  get root_path
  assert_select "section#latest-posts" do
    # Only published posts may appear, newest first, max 3.
    assert_select ".latest-post-card", { maximum: 3 }
  end
  draft_titles = BlogPost.where.not(status: :published).pluck(:title)
  draft_titles.each { |title| assert_no_match title, response.body }
end

test "home hides drafts in latest posts even for the signed-in owner" do
  sign_in users(:louis)
  get root_path
  draft_titles = BlogPost.where.not(status: :published).pluck(:title)
  draft_titles.each { |title| assert_no_match title, response.body }
end
```

  (Match the sign-in helper style already used in this test file; ensure at
  least one draft blog post fixture exists so the assertions bite.)

- [ ] **Step 2: Run — expect FAIL** (`section#latest-posts` absent).

Run: `bin/rails test test/controllers/pages_controller_test.rb`

- [ ] **Step 3: Controller** — in `PagesController#home` add:

```ruby
# Latest published posts for the homepage blog section. Published-only for
# everyone (even the owner) — drafts belong in the blog index, not here.
@latest_posts = BlogPost.visible_to_visitors.order(created_at: :desc).limit(3)
```

- [ ] **Step 4: Partial**

```erb
<%# From the Blog — surfaces the newest published posts on the homepage.
    Renders nothing at all when no posts are published yet. %>
<% if @latest_posts.any? %>
  <section id="latest-posts" class="sec justify-content-end"
           data-sec data-role="blog" data-ax="0.34" data-label="From the Blog">
    <div class="section-inner" style="max-width: 640px;">
      <p class="section-eyebrow">◆ From the Blog</p>
      <h2 class="section-heading mb-4">Latest writing.</h2>
      <div class="d-flex flex-column gap-3">
        <% @latest_posts.each do |post| %>
          <div class="glass-card glass-card--hover latest-post-card p-3">
            <h3 class="project-card-title mb-1">
              <%= link_to post.title, blog_post_path(post), class: "text-decoration-none" %>
            </h3>
            <% if post.blog_excerpt.present? %>
              <p class="text-body-soft mb-2"><%= truncate(post.blog_excerpt, length: 140) %></p>
            <% end %>
            <div class="project-tech-line">
              <%= post.created_at.strftime("%b %-d, %Y") %>
              · <%= post.reading_time %>
              <% if post.ai_label.present? %> · <%= post.ai_label %><% end %>
            </div>
            <% if post.tags.any? %>
              <div class="mt-2 d-flex flex-wrap gap-2">
                <% post.tags.each do |tag| %>
                  <span class="chip"><%= tag.name %></span>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
      <%= link_to "All posts →", blog_posts_path, class: "d-inline-block mt-3" %>
    </div>
  </section>
<% end %>
```

  (`reading_time` already returns `"N min read"`; verify `ai_label`'s
  return shape in `app/models/blog_post.rb` before relying on `.present?`.)

- [ ] **Step 5: Run tests — expect PASS**, full suite, commit

Run: `bin/rails test` → green.

```bash
git add app/controllers/pages_controller.rb app/views/pages/_latest_posts.html.erb test/controllers/pages_controller_test.rb
git commit -m "feat(design): latest published posts section on the homepage"
```

### Task 10: Contact section restyle + Phase-2 wiring test + browser sweep

**Files:**
- Test: `test/controllers/pages_controller_test.rb`
- Modify: `app/views/pages/_contact.html.erb`

**Interfaces:**
- MUST keep: `simple_form_for @contact, url: contacts_path` with
  first_name/last_name/email/message inputs, `invisible_captcha`, the
  load-button controller wiring, and flash-based error display — read the
  current partial and change ONLY presentation.

- [ ] **Step 1: Write the failing scene test**

```ruby
test "home sections carry the depth-camera data attributes" do
  get root_path
  # 10 sections: hero, work, numbers, demo, stack, background, education,
  # about, blog (2 published fixture posts exist), contact.
  assert_select "[data-sec]", 10
  assert_select "[data-sec][data-role][data-ax]", 10
  assert_select "#contact form", 1 # engine end-anchor contract
end
```

- [ ] **Step 2: Run — expect FAIL** (contact not yet a `[data-sec]`; count
  off).

- [ ] **Step 3: Restyle `_contact.html.erb`** — wrapper per the section
  pattern (`id="contact"`, role contact, ax 0.5, centered, max-width
  560px): eyebrow "◆ Contact", heading "Let's build something.",
  availability line ("Open to full-time roles and freelance contracts —
  Rails MVPs and custom web apps."), mono `mailto:dev@louisbourne.me` row,
  then the EXISTING simple_form inside `<div class="glass-card p-4
  text-start">`. Keep every field, hint, captcha, and data attribute from
  the current file.

- [ ] **Step 4: Run tests — expect PASS**; full suite green; commit.

```bash
git add app/views/pages/_contact.html.erb test/controllers/pages_controller_test.rb
git commit -m "feat(design): contact section in Depth Charge language"
```

- [ ] **Step 5: Phase-2 browser verification (the big one)** — run
  `bin/rails server` and with chrome-devtools MCP:
  1. Home at 1440px: scroll top→bottom — hole dollies in/out, parks between
     form and footer at the very bottom; sections alternate sides.
  2. Hover the hole ≥3s: charge glow → explosion → hero morphs toward
     "Louis Bourne"; leave cursor: hold → decay.
  3. Stats animate once on scroll-into-view (no double animation — proves
     divergence 2 worked).
  4. Submit the contact form empty/invalid: flash alert renders dark +
     dismissible; then check the invisible_captcha honeypot field is still
     visually hidden inside the glass panel (inspect element).
  5. 375px: sections centered, hole centered, no horizontal scroll, text
     readable, tap targets OK.
  6. Reduced-motion emulation: static hole, instant stats, page usable.
  7. Turbo check: navigate home → blog → back; no frozen canvas or morphed
     headline flash (divergence 4).
  8. Console: no errors.
  Fix-and-iterate until right, screenshot evidence saved. Push, open PR 2
  (base: `design/p1-foundation`).

---

## Phase 3 — Public pages (branch `design/p3-public` off p2)

### Task 11: Blog index + blog show

**Files:**
- Modify: `app/views/blog_posts/index.html.erb` + any partials it renders
  (read `app/views/blog_posts/` first)
- Modify: `app/views/blog_posts/show.html.erb`
- Modify: `app/assets/stylesheets/components/_actiontext.scss` (retoken the
  EXISTING dark `.trix-content` overrides — see Step 3)

**Interfaces:**
- Do NOT touch: `blog_filter_controller.js`, `html_inject` wiring, Pagy
  calls, tag logic, owner-only buttons' conditions.

- [ ] **Step 0: Create the phase branch FIRST**

```bash
git checkout -b design/p3-public
```

- [ ] **Step 1: Read every file in `app/views/blog_posts/` and the current
  `_actiontext.scss`** to inventory what renders where (index cards, search
  + tag pills, pagination, show meta, related posts). Note: `_actiontext.scss`
  ALREADY contains a hand-tuned dark-theme block (~lines 442–581) with teal
  `#89d6cc` accents — the work below RETOKENS it; never add a second
  competing ruleset.
- [ ] **Step 2: Index** — post cards → `.glass-card.glass-card--hover`,
  title Bricolage (strip the `text-dark` class from the title link —
  unreadable on dark), meta line `.project-tech-line`, tag pills `.chip`;
  search input inherits dark input tokens; active tag pill = `.chip` with
  `border-color: $sky-blue; color: $sky-blue`. Keep all data attributes and
  ids the filter controller queries (grep the controller for selectors
  first). Wrap content in `<main id="main-content">` if the template has a
  `<main>`; otherwise add it. Grep the file for `.text-dark`/`.text-black`/
  `.btn-outline-dark` and convert all.
- [ ] **Step 3: Show** — content column `max-width: 720px; margin-inline:
  auto;`; retoken the EXISTING `.trix-content` dark overrides in place:
  `#89d6cc` → `$sky-blue`, hardcoded grays → design tokens, body text
  `$text-body`, headings `$text-bright` (Bricolage), `pre/code` on
  `#0b0d12` with `$mono-font`, blockquotes with `$panel-border` left rule,
  images `max-width: 100%; border-radius: 12px`. Meta chips row (date,
  reading time, AI badge, tags). Related posts as small glass cards. Add
  `main#main-content`. Same `.text-dark` sweep.
- [ ] **Step 4: Gate** — `bin/rails test` green (blog controller tests
  assert content, not styling); browser-check one AI post (html_content)
  AND one Trix post (body) render readably dark.
- [ ] **Step 5: Commit**

```bash
git add app/views/blog_posts app/assets/stylesheets
git commit -m "feat(design): dark blog index and readable long-form post pages"
```

### Task 12: Projects index + show

**Files:**
- Modify: `app/views/projects/index.html.erb`, `app/views/projects/show.html.erb`,
  `app/views/projects/_projects_hero_banner.html.erb` (read directory first)

**Interfaces:**
- Do NOT touch: sortable wrapper (`data-controller="sortable"` +
  `reorder_projects_path`), owner badges' conditionals, image fallback
  logic (`featured_image` → `img_url`).

- [ ] **Step 1: Index** — project cards → `.glass-card.glass-card--hover`
  with full-width top images (16/9), title/description/tech-line/link
  styling as the homepage cards; owner drag handles + Featured/Edit badges
  restyled (`.chip` with accent border). Hero banner: eyebrow + heading
  pattern. Add `main#main-content`. Sweep `.text-dark`/`.text-black`.
- [ ] **Step 2: Show** — public-appropriate detail: title (Bricolage,
  clamp), image in `.framed-media`, description `.text-body-soft`, tech
  chips, GitHub/live buttons (`btn btn-primary` / `btn-outline-light`);
  owner Edit/Delete as small outline buttons. This page is littered with
  `.text-dark`/`.text-black` spans — convert every one. Add
  `main#main-content`.
- [ ] **Step 3: Gate + commit** — suite green; browser-check index (visitor
  + owner drag-reorder still works) and one show page.

```bash
git add app/views/projects
git commit -m "feat(design): projects index and show in Depth Charge language"
```

### Task 13: Terms, privacy + static hero banners

**Files:**
- Modify: `app/views/pages/terms_of_service.html.erb`,
  `app/views/pages/privacy_policy.html.erb`, their hero banner partials
  (`_terms_of_service_hero_banner`, `_privacy_policy_hero_banner`),
  `app/assets/stylesheets/components/_pages_hero_banner.scss`

- [ ] **Step 1:** Hero banners → eyebrow + `.section-heading` on dark
  (delete old banner bg styles) — BUT preserve enough top padding to clear
  the fixed navbar: the current `padding: 200px 0` in
  `_pages_hero_banner.scss` is what stops content hiding under it; keep a
  `padding-top` of at least 140px in the replacement. Body copy in a 720px
  prose column, `.text-body-soft`, headings `$text-bright`. Add
  `main#main-content` to both pages.
- [ ] **Step 2: Gate** — suite green (tests assert "PostHog" /
  "AI-assisted" text — content unchanged); browser-check both pages;
  commit.

```bash
git add app/views/pages app/assets/stylesheets
git commit -m "feat(design): dark static pages (terms, privacy)"
```

- [ ] **Step 3:** Phase-3 browser sweep (blog index/show, projects
  index/show, terms/privacy at both viewports) + push + PR 3 (base:
  `design/p2-homepage`).

---

## Phase 4 — CMS + auth polish (branch `design/p4-cms` off p3)

### Task 14: Devise views + shared form styling

**Files:**
- Modify: `app/views/devise/sessions/new.html.erb`,
  `app/views/devise/passwords/*.html.erb`,
  `app/views/devise/registrations/edit.html.erb`,
  `app/views/devise/shared/_links.html.erb` (read
  `app/views/devise/` first — style what exists, skip what doesn't)

- [ ] **Step 0: Create the phase branch FIRST**

```bash
git checkout -b design/p4-cms
```

- [ ] **Step 1:** Each Devise screen: centered `.glass-card` panel
  (max-width 460px) with eyebrow ("◆ Owner Access"), heading, the existing
  simple_form fields (inputs already dark from tokens), primary submit.
  KEEP `invisible_captcha` where present and all Devise links. In
  `devise/shared/_links.html.erb` the buttons are `btn-outline-dark` —
  convert to `btn-outline-light` (dark outline is invisible on dark).
- [ ] **Step 2: Gate + commit** — suite green; browser: sign-out → sign-in
  flow works and looks right.

```bash
git add app/views/devise
git commit -m "feat(design): dark Devise auth screens"
```

### Task 15: CMS forms, Trix dark retoken, profile

**Files:**
- Modify: `app/views/blog_posts/_form*.html.erb`,
  `app/views/projects/_form*.html.erb` (read directories first),
  `app/views/pages/profile.html.erb`
- Modify: `app/assets/stylesheets/components/_actiontext.scss` (Trix
  toolbar + dialog)

**Interfaces:**
- Do NOT touch: `publish_form` / `tag_manager` / `load_button` Stimulus
  wiring, `resolve_publish_intent` button names/values, AI revise buttons.
- NOTE: there is no tags index page — the tag manager lives inline in the
  blog post form (`tag-manager` controller) and is covered by the form work
  here.

- [ ] **Step 1: Retoken the existing Trix dark block** —
  `_actiontext.scss` already ships a complete hand-tuned dark-theme section
  (~lines 442–581: toolbar tinted `#2d2d2d`/`#3d3d3d`, icons recolored to
  `#e2e2e2`, teal `#89d6cc` active accents). Edit it IN PLACE: teal accents
  → `$sky-blue`, hardcoded grays → design tokens where a token matches.
  Do NOT add invert filters on top of the recolored icons. ALSO darken the
  Trix link dialog, which hardcodes white and is otherwise unreadable:

```scss
// Trix link dialog hardcodes a white background upstream — retheme it.
trix-toolbar .trix-dialog,
trix-toolbar .trix-dialogs .trix-dialog {
  background: #0b0d12;
  border: 1px solid $panel-border;
  box-shadow: 0 12px 30px rgba(0, 0, 0, 0.5);
}

trix-toolbar .trix-input--dialog {
  background: $input-dark;
  color: $text-bright;
  border-color: rgba(255, 255, 255, 0.12);
}
```

  (Selector specificity may need adjusting against the real upstream CSS —
  verify in the browser, that's Step 4.)
- [ ] **Step 2: Forms** — wrap each form in `.glass-card p-4`; labels
  `$text-body`; the publish/schedule split button group keeps its exact
  button `name`/`value` attributes; datetime field inherits dark input.
  Sweep `.text-dark`/`.text-black`/`.btn-outline-dark` in every form
  partial touched (projects `_form.html.erb` has `text-black` counter
  spans).
- [ ] **Step 3: Profile** — `app/views/pages/profile.html.erb` is littered
  with `.text-dark`/`.text-black` (10+ occurrences) — convert all; stat
  cards → `.glass-card`.
- [ ] **Step 4: Gate + commit**

Run: `bin/rails test` → green.

```bash
git add app/views app/assets/stylesheets
git commit -m "feat(design): dark CMS forms, Trix retoken, profile"
```

- [ ] **Step 5: Full CMS browser smoke** — sign in; create/edit a blog post
  in Trix (toolbar legible, link dialog legible, text visible); open the
  AI-generation form; project form: publish split-button renders;
  drag-reorder projects; tag manager add/remove inside the blog form.
  Fix-and-iterate. Push, PR 4 (base: `design/p3-public`).

---

## Final gate (before /review-sync)

- [ ] `bin/rails test` — full suite green, count > 185 (new tests added).
- [ ] All four PRs open, stacked bases correct, each description lists its
  browser-verification evidence.
- [ ] Whole-site browser pass at 1440px + 375px: home scroll + charge +
  morph; blog; projects; static; auth; CMS. Console clean everywhere.
- [ ] NO deploy anywhere in the run.
