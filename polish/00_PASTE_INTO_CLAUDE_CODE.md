# PASTE THIS INTO CLAUDE CODE

> Copy everything below the line into Claude Code from the root of your Starfighter project.
> First drop the three companion files (`CLAUDE.md`, `PREMIUM_POLISH_PLAN.md`, `POLISH_CHECKLIST.md`)
> into the repo so Claude Code can read them. The prompt is self-sufficient on its own, but those
> files make it bulletproof.

---

You are taking over **Starfighter**, my iOS space-arcade game, with one mission: make it feel like a premium title a funded studio shipped — the kind of polish people associate with a real game, not a solo project. The benchmark bar is **Alto's Odyssey** and **Space Marshals** for feel and presentation. We are not adding scope for its own sake; we are raising the *craft* of what's already here until it crosses the line from "indie demo" to "how did two people make this."

Read `CLAUDE.md`, `PREMIUM_POLISH_PLAN.md`, and `POLISH_CHECKLIST.md` in this repo before doing anything. They are the source of truth for standards, the phase order, and the acceptance bar. Follow them.

## How I want you to work

- **Phase 0 first — audit, don't assume.** Open the codebase and tell me, in plain language: the engine/framework actually in use (I believe Swift + SpriteKit + Core Haptics + AVFoundation — correct me if it's SceneKit, Metal, or Unity), the architecture, the current frame rate under load, where time is spent, what's allocated per frame, and the three things most responsible for it feeling "unfinished." Do not start changing things until you've shown me this audit and your proposed order of attack.
- **Work in the phases defined in `PREMIUM_POLISH_PLAN.md`, one at a time.** After every phase the game must build, run, and be visibly better than before. Commit at the end of each phase with a clear message. Never leave the game in a broken state between phases.
- **Centralize the "feel."** Create one tunable constants file (`GameFeel.swift` or equivalent) so every magic number — shake intensity, hit-stop duration, easing curves, haptic sharpness, audio levels — lives in one place I can tweak without hunting through code.
- **Capture before/after.** For each polish pass, describe (and where you can, screen-record or log) what changed so I can feel the delta.
- **Ask before any architectural rewrite.** Refactor freely inside a system; check with me before restructuring how systems talk to each other.
- **Protect readability.** Every piece of juice you add must make the game feel better *without* making it harder to read. If a shake or a bloom hurts clarity, dial it back. Gameplay legibility wins every tie.

## The craft bar (this is the whole point)

By the time we're done, these must be true — they're spelled out in detail in the plan:

1. **Every player action gets feedback within one frame** — visual + audio + (where it fits) haptic. Nothing happens silently.
2. **Nothing moves in a straight line.** No linear tweens anywhere. Everything eases, springs, anticipates, and follows through.
3. **Impact has weight.** Hits land with hit-stop, screen shake scaled to magnitude, particles, flash, and low-end punch in the audio + haptics.
4. **The presentation is cinematic end to end** — animated title with a logo sting, menu transitions (no instant cuts), a HUD that feels designed, a death/victory moment that lands.
5. **There's real decision-making, not just reflexes** — risk/reward systems, distinct enemy behaviors that demand different responses, telegraphed boss phases, and a meta-progression "one more run" hook.
6. **It holds frame rate** — locked 60fps (120 on ProMotion) even at max on-screen entities, via object pooling and batched draws. Prove it with Instruments.
7. **It respects the player** — pause, audio sliders, haptics toggle, Reduce Motion support, a colorblind-safe palette, and difficulty options.

## Start now

Begin with the Phase 0 audit. Show me what you find, confirm the stack, and propose the phase plan tailored to what's actually in the code. Then wait for my go before Phase 1.

When you finish all phases, run the game against `POLISH_CHECKLIST.md` and tell me honestly which boxes are green, which are yellow, and what the single highest-leverage next improvement would be.

Let's make something that doesn't look like it should exist from a team of two.
