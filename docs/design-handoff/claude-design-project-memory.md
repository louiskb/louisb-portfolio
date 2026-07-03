# Louis Bourne — Portfolio (Claude Design project memory)

> Imported from the Claude Design project "Louisb Portfolio Enhancement"
> (`claude.ai/design/p/a5c4a6dc-7b37-460c-ab89-a130e73111e1`), file
> `CLAUDE.md`, on 2026-07-03. This is the design project's own memory —
> the authoritative record of which design shipped and how its engine
> works. Note: it says the repo default branch is `master`; it is `main`.

## What this is
An enhanced redesign of **louisbourne.me**, Louis Bourne's personal portfolio.
The live site is a Ruby-on-Rails app: GitHub repo `louiskb/louisb-portfolio` (default branch `master`).

## OFFICIAL DECISION (current)
- **OFFICIAL portfolio design → `Louis Bourne - Scroll Site (Depth Charge).dc.html`.** This is the shipping design. All future portfolio work happens here unless told otherwise.
- **DEFENSIVE FALLBACK → `Louis Bourne - Website.dc.html`.** Static-section (non-scroll-driven) build with the same content and the `chargex` black-hole hero; kept as a safe backup. (Its old "Responsive" phone-mockup section has been removed.)

## Files in this project (what each is for)
- **`Louis Bourne - Scroll Site (Depth Charge).dc.html`** — ⭐ THE OFFICIAL SITE. Full single-page scroll site. One fixed full-viewport `<canvas data-bh>` behind all sections; the black hole **depth-dollies** (scales up toward mid-scroll, recedes after) as you scroll, staying horizontally centered (NO diagonal drift — that was tried and reverted). Merges the depth camera with the full **charge / energy / cursor / hero-text-morph** engine lifted from `Louis Bourne - Website` (see engine notes below). Sections: hero, work (Featured Projects + open-source line), numbers, demo, stack, background, education, about, contact, footer.
- **`Louis Bourne - Website.dc.html`** — the defensive fallback (see above).
- **`Louis Bourne - Scroll Site.dc.html`** / **`Louis Bourne - Scroll Site (Depth).dc.html`** — earlier scroll experiments (charge-burst and plain-depth). Superseded by Depth Charge; keep for reference.
- **`Louis Bourne - Scroll Site (Accretion + Depth).dc.html`** — full-page site with a top-right Accretion / Depth mode toggle. Exploration; not the deliverable.
- **`Scroll Concepts.dc.html`** (1A–1D) and **`Scroll Concepts (Round 2).dc.html`** (2A accretion, 2B orbital nav, 2C signal-decode, 2D depth, 2E depth+accretion) — mini-panel galleries used to pitch scroll-interaction behaviors. Not deliverables.
- **`Louis Bourne - Portfolio.dc.html`** / **`Mission Console - Lab.dc.html`** — older Mission Console production build + its sandbox clone. Legacy direction, not the current official site.
- **`Earth From Here - Concept.dc.html`** — separate concept canvas (view Earth centered on visitor location via geolocation or IP). Own session; still open-ended.
- **`Louis Bourne - Design Directions.dc.html`** — exploration gallery (NOT a deliverable). Do NOT add `design_doc_mode=canvas` here — it caused an infinite-scroll grey void; uses normal bounded scroll.
- **`Energy Levels - Handoff.md`** — written explainer of the original charge/energy system (level / chargeE / boom / energy). Still a good mental model, though Depth Charge uses the `excite`-based variant (below).

## Black-hole engine — Depth Charge (current official) state
All logic is in the `initBH(cv)` closure of the DC's `Component` class. Key behaviors as tuned with Louis:
- **Depth camera**: `camCx = w*0.5` (always centered horizontally); `sc` (scale) eases toward `.5 + depthv*1.75` where `depthv = 1-|prog-.5|*2` → approaches at mid-scroll, recedes at the ends. Vertical drift `cyOff` from `(prog-.5)*.1`.
- **End position**: over the final 10% of scroll (`endPush = (prog-0.9)/0.1`) the hole eases to sit centered *between the contact form's bottom and the footer's top* (measured live via `#contact form` + `footer` rects) so it has equal top/bottom margin at the very bottom. Original scroll animation is untouched until that last sliver.
- **Charge system (`excite`-based)**: hover within `Re*1.7` of center fills `chargeE` over ~2.5s; at full it explodes → steps `excite` up (0–8, with `vFloor` high-water + power/bmult), fires a nova `spawnBurst`, ring wobble + pulse. If the cursor leaves mid-charge, the bright core **HOLDS for 2s then decays linearly over 3s** to black (phases: idle→charging→hold→decay→explode). No auto-escalate past 0.6.
- **Hero text morph**: `renderText(excite)` scrambles the hero `[data-morph="1"/"2"/"sub"]` (web/developer ↔ Louis/Bourne + tagline). Fires on every explosion **immediately** and works even when charging mid/bottom of the page (targets the hero spans by selector).
- **Look**: particle disk stretched **1.5× horizontally** (drawParts + drawOrbits x-scaled; hole stays round). Global brightness `briMul = 1.45` so it's not faint. Particle count doubled (`w*h/1300`, cap 3000). NO cursor-follow glow (tried several variants, all removed). NO shooting star (tried, removed).
- Respects `prefers-reduced-motion`; tweak props: `intensity` (default 70), `animate`, `starfield`.

Active work = the OFFICIAL Depth Charge site. Legacy Mission Console + Earth concept live in their own sessions.

## Workflow note
Streamed `dc_*` edits sometimes lag the live preview by a beat (hot-reload reconciliation gap) — the FILE is correct; a fresh load (ready_for_verification) renders it. Don't chase phantom "missing element" reads from the stale runtime; grep the file to confirm.

## About Louis (use for copy/tone)
- Full-stack developer; production **Ruby on Rails** apps (PostgreSQL, StimulusJS, RSpec).
- Mixed **British-Thai**, based in **Thailand**. Speaks EN / TH.
- Also an independent **trader / financial analyst**; background in **marine biology**.
- Completed New Zealand's **Te Araroa** 3,000 km thru-hike (2024/25). Into lifting, kitesurfing, running, hiking.
- Open to full-time roles & freelance contracts (Rails MVPs, custom web apps).
- Links: GitHub `github.com/louiskb` · LinkedIn `linkedin.com/in/louis-bourne/` · Discord user `brothercap` · email `dev@louisbourne.me`.
- Featured projects: **Market Sensei** (marketsensei.app), **Sipfolio** (sipfolio.rocks), **Dokodemo Fit** (dokodemofit.app).

## Design direction (agreed)
- **Deep-space "mission console" / retro-terminal HUD** aesthetic — inspired by the *vibe* of marathonthegame.com, NOT a copy. Do **not** reproduce Bungie/Marathon's logo, layout, or acid-green brand identity. Keep it original, in Louis's palette.
- Mouse-reactive **aurora / space** background (WebGL shader): ribbons bend to cursor, spotlight follows pointer, parallax, ripple warp, drifting stars that repel.
- Animation intensity target ~70%. **Must respect `prefers-reduced-motion` and stay smooth on mobile.**
- Fonts: **Chakra Petch** (display/headings), **Space Mono** (mono/labels), **Space Grotesk** (body). These replaced the old Le Wagon bootcamp fonts — don't go back to Inter/Roboto/Arial.

## Themes
Five live-switchable presets in the hero "Theme Engine" panel; switching recolors aurora + all HUD accents + headline gradient:
1. **Aurora** (teal→green→violet, default) · 2. **Deep Field** (electric blue, closest to old site) · 3. **Nebula** (violet/magenta, #6f2bdd DNA) · 4. **Corona** (cosmic dawn coral/gold) · 5. **Signal** (cyber cyan + hot pink).
Original brand accents to preserve: blue `#1062FE`, purple `#6f2bdd`, green `#22C75F`, cyan `#0dcaf0`, orange `#E67E22`.

## Conventions
- Each design lives in its own single `.dc.html`; split into child DCs only if something genuinely reusable emerges.
- Inline styles only (per DC rules); the only `<style>` block is for `@keyframes`/`@font-face`/resets.
- Project & portrait images are currently labeled placeholder frames — swap in real screenshots when provided.
- Tweak props on the OFFICIAL Depth Charge site: `intensity`, `animate`, `starfield`. (Legacy Mission Console files also expose `defaultTheme`, `scanlines`.)
- Fonts on the current portfolio builds: **Bricolage Grotesque** (display/headings), **Instrument Serif** (italic accent, e.g. "developer"), **Space Grotesk** (body), **Space Mono** (labels/mono). Don't go back to Inter/Roboto/Arial. (The Chakra Petch note below is legacy Mission Console.)
- Animations only run in a visible browser tab (headless screenshot tools freeze them mid-frame — that's expected, not a bug).
