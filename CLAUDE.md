# CLAUDE.md — Starfighter

Persistent engineering context for Claude Code. Read this at the start of every session.

## What this project is

**Starfighter** is an iOS space-arcade game (original IP — no licensed/trademarked references).
Working lineage: Star Control Reborn → Void Wanderers → Starfighter. Built by a solo developer
(djEnterprises) with Claude as the engineering partner. The goal of the current effort is a
**premium polish pass** that lifts the existing game to studio-quality feel and presentation.

**Quality benchmark:** Alto's Odyssey, Space Marshals. The test we hold ourselves to: a stranger
playing it should not be able to tell it was made by two people.

## Assumed stack (verify in Phase 0, correct here if wrong)

- **Language:** Swift
- **Engine:** SpriteKit (`SKScene` / `SKNode` graph)
- **Haptics:** Core Haptics (`CHHapticEngine` + custom patterns)
- **Audio:** AVFoundation / AVAudioEngine
- **Post-processing:** `SKShader` / `SKEffectNode` with Metal shaders
- **Target devices:** iPhone; support ProMotion (120Hz) where available
- **Min iOS:** confirm from the project file and record here

> If the real engine is SceneKit, RealityKit, Metal-direct, or Unity, update this section and
> adapt the techniques in `PREMIUM_POLISH_PLAN.md` to that engine's equivalents.

## Non-negotiable engineering standards

- **Frame budget:** lock 60fps (120 on ProMotion). Measure with Instruments, not vibes. A polish
  feature that drops frames gets optimized or cut.
- **No per-frame allocation in the hot path.** Pool bullets, enemies, particles, and audio players.
  Spawning should reuse, never `alloc`.
- **Delta-time movement.** All motion is frame-rate independent. Never assume a fixed tick.
- **Texture atlases + batched draws.** Keep draw calls low; group by texture/blend mode.
- **One feel file.** All tunable constants (shake, hit-stop, easing, haptic intensity/sharpness,
  audio gain, spawn timing) live in `GameFeel.swift`. No magic numbers buried in systems.
- **Readability first.** Juice never beats gameplay clarity. If an effect obscures a threat, it loses.
- **Accessibility is a feature, not a setting we forgot.** Honor Reduce Motion. Provide a haptics
  toggle, audio sliders, a colorblind-safe palette, and difficulty options.
- **Respect the system.** Handle audio-session interruptions (calls, Control Center), background/
  foreground transitions, the silent switch, and the Core Haptics engine reset/`stoppedHandler`.

## Working agreement

- Audit before editing (Phase 0). Show findings; wait for go-ahead.
- One phase at a time; the game builds and runs after every phase.
- Commit per phase with a descriptive message.
- Refactor inside a system freely; ask before changing how systems interconnect.
- Prefer small, reversible changes over big rewrites.
- When you add an effect, expose its parameters in `GameFeel.swift` so it can be tuned.

## Art & audio direction

- **Pick one cohesive lane and commit to it** (e.g. neon synthwave / clean hard sci-fi / gritty
  used-future). Consistency reads as "expensive" far more than raw fidelity does.
- Limited, deliberate palette. Brand accents (gold / teal) are welcome in menus and HUD; the
  in-space palette should serve readability — threats and pickups must pop against the background.
- Additive blending for energy, engines, and explosions. Rim/edge light on ships for separation.
- Audio gets variation (pitch-randomize repeated SFX), low-end weight on impacts, and a real mix
  with a master limiter so nothing clips and loudness is consistent.

## Where assets can come from (solo-dev reality)

The true ceiling for a solo game is usually art and audio, not code. Acceptable sources: licensed
asset packs (Kenney, itch.io, properly licensed marketplaces), AI-assisted generation for concepting
and textures, and original work. Track licenses in `CREDITS`/`ATTRIBUTION`. Do not ship anything
without clear rights.

## Definition of done

The game passes `POLISH_CHECKLIST.md`, holds frame rate under max load (proven in Instruments),
and clears the craft bar in `PREMIUM_POLISH_PLAN.md`.
