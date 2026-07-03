# Black Hole — Charge / Energy System (handoff)

> Imported from the Claude Design project "Louisb Portfolio Enhancement"
> (`claude.ai/design/p/a5c4a6dc-7b37-460c-ab89-a130e73111e1`), file
> `Energy Levels - Handoff.md`, on 2026-07-03. Describes the ORIGINAL
> charge engine in `Louis Bourne - Scroll Site.dc.html`; the official
> Depth Charge build uses an `excite`-based variant of the same model
> (see `claude-design-project-memory.md`), but this remains the best
> mental model of the system.

This explains how the "charge" and "energy" system works in the black-hole
animation in **`Louis Bourne - Scroll Site.dc.html`**. All logic lives in one
place: the `initBH(cv)` method of the `Component` class (the `<script data-dc-script>`
block). Everything below refers to variables in that closure.

The system has **three separate time-varying quantities** — `level`, `chargeE`,
and `boom` — plus one **derived** value, `energy`, that most visuals read from.
Keep these distinct; they are easy to confuse.

---

## 1. The state variables

| Variable | Range | What it is | How it changes |
|---|---|---|---|
| `level` | `0 → 8` (float) | The **persistent charge state**. This is "how charged the hole is right now." | Rises in integer steps via `explode()`. **Continuously decays** every frame: `level -= dt * decayRate` (default `decayRate = 0.22`/sec, a tweakable prop). |
| `chargeE` | `0 → 1` (float) | The **cursor charge meter** — a short-term accumulator that fills while the pointer is near the hole. | `+= dt/2.2` while charging, `-= dt/1.1` otherwise. When it reaches `1` it triggers `explode()` and resets to `0`. |
| `boom` | `1 → 0` (float) | The **explosion envelope** — a decaying "just exploded" pulse used to animate the flash + shove particles outward. | Set to `1` inside `explode()`, then `boom -= dt/1.15` each frame down to `0`. |
| `peak` | `0 → 8` | The **highest `level` ever reached** this session. | `peak = Math.max(peak, level)`. Only ever goes up. Used for the idle inner-core glow. |
| `energy` | `0 → ~1.5` | **Derived master intensity** most visuals read. | Recomputed every frame (see below). Not stored between frames. |
| `vel` | `0 → 1` | Smoothed **scroll speed**. | Feeds particle spin only; not part of charge. |

### The derived `energy`

Recomputed once per frame:

```js
energy = Math.min(1.5, level/4 + chargeE*0.5 + boom*0.6);
```

So `energy` blends the persistent charge (`level/4`), the live cursor meter
(`chargeE`), and the explosion pulse (`boom`). Think of `level` as the *stored*
charge and `energy` as the *instantaneous brightness* the render code should use.

---

## 2. How charge goes UP — two independent sources

Both call the same `explode()`:

```js
function explode(){
  level = Math.min(8, Math.floor(level + 1e-6) + 1); // bump to next integer, cap 8
  peak  = Math.max(peak, level);
  boom  = 1;         // fire the explosion pulse
  chargeE = 0;       // reset the cursor meter
  spawnBurst(...);   // emit the nova of particles
}
```

**Source A — the cursor (manual charging).**
Each frame, if the pointer is hovering *and* within `Re * 1.9` of the hole
center (`Re` = current on-screen radius), `chargeE` fills. When `chargeE >= 1`,
`explode()` fires and `level` steps up by one. Moving the cursor away lets
`chargeE` drain back toward 0 (no explosion).

**Source B — scroll breaks (automatic charging).**
Controlled by the `autoCharge` prop (default on). In `readCam()`, the code finds
which `[data-sec]` section is centered in the viewport (`ci`). When you scroll
**down into a new section** (`ci > lastCi`) and a `0.7s` cooldown (`cool`) has
elapsed, it calls `explode()` — so passing a section boundary bumps the charge
state. The cooldown stops fast scrolling from spiking it instantly.

Because both sources feed the *same* `level`, the user can charge at the hero,
then keep charging (or top it up) at any section via either the cursor or by
scrolling — exactly the "follows you down the page and can be re-charged" behaviour.

---

## 3. How charge goes DOWN — decay

`level` is reduced every single frame:

```js
level = Math.max(0, level - dt * decayRate);
```

With `decayRate = 0.22`, a full `level 8` bleeds to `0` in ~36 seconds if the
user does nothing. This is what makes the charge feel alive: stop feeding it and
it settles back down. `chargeE` also self-drains when the cursor leaves. `peak`
does **not** decay (it's a high-water mark).

Net effect: `level` is a running balance of **explosions pushing it up** vs
**decay pulling it down**.

---

## 4. What each quantity DRIVES (the visuals)

All in `render()`. Roughly ordered from subtle to loud:

- **Outer aura (subtle, grows with stored charge).**
  `aur = min(1, level/6)*0.5 + energy*0.3`, drawn as a faint radial glow at
  `alpha ≈ 0.07 * aur`. Higher `level` → a slightly bigger, subtler blue halo.

- **Accretion ring glow.** Ring `shadowBlur = 16 + energy*26` and stroke
  `alpha = 0.5 + energy*0.32`. While actively charging/exploding the ring also
  gets a jittered, wobbling outline.

- **Inner core flicker (the "charged past level 3" look).**
  `idleCore = peak >= 3 ? min(0.6, (peak-2)*0.11) : 0`. Combined as
  `coreG = max(idleCore, chargeE*0.5, boom*0.7)` and multiplied by a
  `sin`-based flicker. Meaning: once the hole has *ever* reached level 3, it
  keeps a soft, growing, flickering glow **inside** the event horizon even when
  idle/uncharged — and it grows with each further level.

- **Particle spin.**
  `spin = 1 + energy*1.3 + chargeE*4 + boom*3 + vel*2`. Charging and exploding
  visibly accelerate the disk; scrolling adds a little too.

- **Particle radius / suck-in.** While charging, particles are pulled toward the
  core: `r → R*1.1 + (a - R*1.1)*(1 - chargeE*0.86)`. On explosion (`boom>0`)
  they're shoved outward by `boom * rMax * 0.6`.

- **Charge glow burst.** When `chargeE` or `boom` is active, a white→orange
  radial flash scales with both.

- **The nova (`spawnBurst`).** Fired once per `explode()`. Particle count scales
  with `level`. Each particle flies in a **random** direction at a random speed;
  its colour is taken from the palette by *normalised speed* (slow=inner palette
  colours, fast=outer), so the spray is colour-ordered radially like the disk
  rather than a hard ring. (There is intentionally **no** stroked shockwave ring.)

- **Hero headline text.** `renderText(level + chargeE*0.9)` maps the 0→8 charge
  onto a text morph: the `web / developer` headline and the subtitle scramble
  toward `Louis / Bourne` / an alternate tagline as charge rises, and back down
  as it decays. So the copy itself is a charge readout.

---

## 5. What is NOT part of the energy system

The **camera** (`cx`, `cy`, `scaleC`) is driven purely by **scroll position**,
not charge. Each `[data-sec]` carries `data-ax` (horizontal anchor 0–1) and
`data-scmax` (max zoom). `readCam()` lerps the hole toward the centered
section's anchor and scales it up as that section centers ("approach") and down
between sections ("recede"). On screens `< 820px` the anchor is forced to `0.5`
and zoom is damped. The only crossover: `scaleC` sets `Re` (on-screen radius),
which the cursor-proximity charge test uses.

---

## 6. Tweakable props (host Tweaks panel / `data-props`)

- `intensity` (20–140%, default 80) — global multiplier `inten` on all alphas/glow.
- `decay` (0.05–0.6, default 0.22) — how fast `level` bleeds off.
- `autoCharge` (bool, default true) — enable/disable scroll-break explosions.
- `starfield` (bool, default true) — background stars.

---

## TL;DR mental model

- `level` = **stored charge** (0–8), goes up in steps on explosions, always slowly decays.
- `chargeE` = **cursor meter** (0–1), fills on hover, explodes at full.
- `boom` = **explosion flash** (1→0), the visual kick.
- `energy` = `level/4 + chargeE*0.5 + boom*0.6` = **what the renderer reads** for brightness/spin.
- `peak` = highest level reached → unlocks the permanent flickering inner core at ≥3.
- Camera position/zoom is a **separate**, scroll-driven system.
