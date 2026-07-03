# Claude Design Handoff — v2 Visual Design

Imported on 2026-07-03 from the Claude Design project **"Louisb Portfolio Enhancement"**
(`https://claude.ai/design/p/a5c4a6dc-7b37-460c-ab89-a130e73111e1`). This is the design
handoff referenced in the root `CLAUDE.md` — the visual design to be layered over the
current plain v2 scaffolding.

## The decision (from the design project's own memory)

- ⭐ **OFFICIAL design: `louis-bourne-scroll-site-depth-charge.dc.html`** — a full
  single-page scroll site with one fixed full-viewport black-hole `<canvas>` behind all
  sections. This is what we implement.
- 🛟 **Fallback: `louis-bourne-website-fallback.dc.html`** — a simpler static-section
  build with the same content and a black-hole hero. Only used if the official design
  fails or doesn't look good in the real app.

## Files

| File | What it is |
|---|---|
| `louis-bourne-scroll-site-depth-charge.dc.html` | ⭐ The official design. Sections: hero, work, numbers, demo, stack, background, education, about, contact, footer. Contains the full black-hole engine (depth camera + `excite`-based charge system + hero text morph) in its `<script data-dc-script>` block. |
| `louis-bourne-website-fallback.dc.html` | The defensive fallback (static sections, `chargex` black-hole hero). |
| `support.js` | The Claude Design runtime (`dc-runtime`) the `.dc.html` files load. Only needed to preview the files as-is in a browser; NOT part of what we port to Rails. |
| `claude-design-project-memory.md` | The design project's `CLAUDE.md` — the authoritative record of the official decision, engine tuning notes, design direction, fonts, palette, and conventions. Read this first. |
| `energy-levels-handoff.md` | Deep-dive explainer of the original charge/energy system (`level` / `chargeE` / `boom` / `energy`). The official build uses an `excite`-based variant, but this is still the best mental model. |

## Key implementation facts

- **Fonts:** Bricolage Grotesque (display/headings), Instrument Serif (italic accent,
  e.g. "developer"), Space Grotesk (body), Space Mono (labels/mono).
- **Background** `#040507`; brand accents to preserve: blue `#1062FE`, purple `#6f2bdd`,
  green `#22C75F`, cyan `#0dcaf0`, orange `#E67E22`. Section accent `#5fb0ff`.
- **The black-hole engine** lives in `initBH(cv)` inside the DC script block — plain
  Canvas 2D, no libraries. It must respect `prefers-reduced-motion` and stay smooth on
  mobile. Tweakable props: `intensity` (default 70), `animate`, `starfield`.
- **Sections carry `data-sec` / `data-role` / `data-ax` / `data-label`** attributes the
  engine reads for the scroll-driven depth camera and the numbers count-up trigger.
- The `.dc.html` files use inline styles + a Claude-Design component wrapper (`<x-dc>`,
  `DCLogic`); porting to Rails means translating structure/styles into ERB partials +
  SCSS and the DC script into a Stimulus controller — not copying the wrapper.

## Not imported

The design project also holds earlier explorations (`Scroll Concepts`, `Mission
Console`, `Earth From Here`, etc.), process screenshots, and Louis's uploaded source
screenshots. They are superseded or non-deliverable; fetch from the design project URL
above if ever needed.
