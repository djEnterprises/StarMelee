# PREMIUM_POLISH_PLAN.md — Starfighter

The execution plan to take Starfighter from "indie demo" to "a studio shipped this." Phases run in
order. Each phase ends with a game that builds, runs, and is visibly better. Techniques assume
Swift + SpriteKit; adapt to the real engine if Phase 0 says otherwise.

---

## The craft bar (what "premium" actually means)

Premium isn't more content — it's that every moment is *responded to*. The differences a player
feels but can't name:

- **Feedback density:** every action produces visual + audio + (often) haptic response within one frame.
- **No linear motion:** everything eases, springs, anticipates, overshoots, and settles.
- **Weight:** impacts have hit-stop, shake, particles, flash, and low-end thump.
- **Cinematic flow:** title → menu → gameplay → death/victory all feel authored, never abrupt.
- **Decisions over reflexes:** risk/reward, enemy variety, boss phases, and a reason to play again.
- **Performance:** locked frame rate under max load.
- **Respect:** accessibility and system behavior handled like a real product.

---

## Phase 0 — Audit & Plan (no changes yet)

Goal: understand what exists before touching it.

- Identify engine, architecture, scene/entity model, and the update/render loop.
- Profile in Instruments: current FPS under load, frame-time spikes, per-frame allocations, draw calls.
- Inventory existing assets (sprites, audio, fonts) and their quality/consistency.
- List the top 3 reasons it currently feels unfinished.
- Output: a short written audit + a phase plan tailored to the real code. **Wait for go-ahead.**

---

## Phase 1 — Game Feel Foundation ("juice")

This is the single highest-leverage phase. Most of the "premium" perception lives here.

- **Hit-stop / frame freeze:** on meaningful impacts, freeze the action 40–90ms scaled to magnitude.
  Tiny on small hits, longer on kills/boss damage. This alone transforms how combat reads.
- **Screen shake, done right:** trauma-based (a `trauma` value that decays; shake = trauma²), driven
  by Perlin/sine noise, magnitude scaled to the event. Cap it. Never nauseating. Honor Reduce Motion.
- **Camera life:** subtle idle drift, a recoil kick when the player fires heavy weapons, a small
  punch-zoom on big explosions/boss deaths.
- **Easing everywhere:** replace every linear interpolation with eased/spring motion. Pickups
  ease-out toward the player; UI elements spring in; enemies anticipate before they lunge.
- **Damage feedback:** enemies flash white on hit, flash + scale-punch, and desaturate/dissolve on
  death. The player ship reacts visibly to taking damage.
- **Input feel:** input buffering and a few frames of coyote time so the controls feel responsive
  and forgiving rather than twitchy.
- Expose every constant above in `GameFeel.swift`.

Demo target: firing, hitting, and killing an enemy should already feel dramatically better.

---

## Phase 2 — Particles & VFX

- **Layered explosions:** core flash + shockwave ring + debris + secondary sparks + lingering smoke,
  not a single puff. Stagger their timing.
- **Weapon VFX:** muzzle flash, projectile glow/trail, impact sparks, tracer character per weapon type.
- **Engine/thruster trails** that react to throttle and turning.
- **Additive blending** for all energy effects; **bloom** on bright sources (engines, shots, blasts).
- **Subtle full-screen effects on big moments:** brief chromatic aberration + a flash of vignette on
  major hits or boss kills (keep it tasteful — these are seasoning, not the meal).
- Pool all particle emitters. Watch the frame budget; profile after.

---

## Phase 3 — Art Direction & Background

- **Commit to one cohesive visual language** (see `CLAUDE.md`). Re-skin inconsistent assets toward it.
- **Multi-layer parallax starfield:** 3–4 depth layers, drifting at different speeds, plus nebula
  gradient clouds and occasional foreground dust/debris for depth.
- **Color grading:** a LUT or shader-based grade, gentle vignette, optional very-subtle film grain or
  scanlines if the chosen lane is retro. Unify the palette so everything looks shot through the same lens.
- **Lighting:** rim light on ships for silhouette separation; dynamic point-light glow from projectiles
  and explosions on nearby surfaces.
- Keep threats and pickups high-contrast against the background — readability is sacred.

---

## Phase 4 — Audio That Hits

- **Adaptive music:** intensity layers (calm exploration → combat → boss) that crossfade with the
  action instead of one looping track.
- **SFX with variation:** pitch-randomize repeated sounds (lasers, hits) so rapid fire doesn't sound
  robotic. Give impacts real low-end weight.
- **Spatialization:** pan and attenuate by on-screen position.
- **Sidechain ducking:** music ducks briefly under big SFX so explosions punch through.
- **A real mix:** consistent loudness, a master limiter so nothing clips, satisfying UI sounds.
- Handle audio-session interruptions and the silent switch correctly.

---

## Phase 5 — Haptics (Core Haptics)

- Stand up a `HapticsManager` around `CHHapticEngine` with reset/restart handling.
- **Map patterns to events by intensity + sharpness:**
  - Pickup / UI tick → light, short transient.
  - Weapon fire → crisp transient (subtle, or it fatigues on rapid fire).
  - Taking a hit → sharp transient.
  - Explosion / boss impact → low, rumbly continuous burst.
  - Charging a weapon → rising continuous pattern that releases on fire.
- Scale to event magnitude. **Provide a haptics on/off toggle and honor system settings.** Restraint
  matters — over-haptic feels cheap, not premium.

---

## Phase 6 — Strategic Depth

Lift it from a reflex toy to a game with decisions.

- **Risk/reward systems:** e.g. an overcharge/overheat weapon (more damage, risk of overheating), or a
  greed mechanic where staying aggressive builds a score multiplier you lose when hit.
- **Loadout choices with real tradeoffs** — not "+10% damage" but options that change how you play.
- **Enemy variety with distinct behaviors** that demand different responses (a rusher, a sniper, a
  shielded type, a swarm) — soft rock-paper-scissors so positioning and target priority matter.
- **Bosses with telegraphed, learnable phases** — clear wind-ups, readable patterns, escalating stakes.
- **Resource management:** energy / shields / heat / limited special — moment-to-moment decisions.
- **Combo / multiplier** system that rewards skillful aggression.
- **Difficulty curve** + gentle dynamic difficulty so it stays in the flow channel.
- **Meta-progression "one more run" hook:** roguelite structure fits arcade perfectly — runs feed
  persistent unlocks, so failure still advances something.

---

## Phase 7 — Presentation & UX

The layer that makes it read as "a studio made this."

- **Title screen** with motion: animated background, a logo sting, a confident "press to start."
- **Menu system with transitions** — slides, fades, eased motion. No instant scene cuts anywhere.
- **HUD that feels designed:** minimal, animated (numbers tick/pop, bars ease), diegetic where possible.
- **Onboarding by doing** — teach mechanics through a guided opening, not a wall of text.
- **The death/victory moment lands:** slow-mo, a beat of silence, a satisfying score tally that counts up.
- **Pause, settings (audio sliders, haptics toggle, accessibility, difficulty), and a credits screen.**
- **Game Center:** leaderboards + achievements for retention and social proof.
- **Intentional loading/transition states** — never a frozen black frame.

---

## Phase 8 — Performance & Hardening

- Re-profile in Instruments under max on-screen entities. Hit locked 60/120fps.
- Confirm pooling is real (no hot-path allocations), draw calls are batched, memory is flat (no leaks).
- Test background/foreground, interruptions, low-power mode, and a range of devices/aspect ratios.
- Clean up: no debug overlays, no console spam, no placeholder assets shipping.

---

## Phase 9 — Store-Ready Shine

- App icon, launch screen, and App Store screenshots at studio quality (the storefront is the first
  "is this legit?" test most players apply).
- Consistent naming, version, and metadata.
- Final pass against `POLISH_CHECKLIST.md`; report green/yellow/red honestly.

---

## A note on honesty

Code can deliver world-class *feel* — the juice, the timing, the systems, the performance. The part
that most often gives away a solo project is **art and audio**, because that's craft-hours, not
cleverness. Decide early whether to license a cohesive asset pack, generate and refine assets, or
commission them. A consistent, deliberate set of mediocre-fidelity assets reads as more "premium"
than a pile of mismatched high-fidelity ones. Pick a lane and make everything obey it.
