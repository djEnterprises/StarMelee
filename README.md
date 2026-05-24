# Star Melee

**Strategic ship-to-ship arena combat across the stars.**

A 2D real-time space combat / arena fighter for iOS, iPadOS, macOS, and (later) tvOS.
Inspired by the *Star Control II* Super Melee mode, with original IP, original ships,
original art, and a *Mortal Kombat*-style match structure.

> **Spec:** see [`STAR_MELEE_PLAN.md`](./STAR_MELEE_PLAN.md) — the complete 26-section design and build plan. Claude Code should read this at the start of every session.
>
> **Visual reference:** see [`star-melee-mockup.html`](./star-melee-mockup.html) — interactive browser prototype showing the intended look and feel.

---

## Tech stack

| Layer | Choice |
|-------|--------|
| UI / menus | SwiftUI |
| Combat rendering & physics | SpriteKit |
| Ship Compendium 3D views | SceneKit |
| Haptics | Core Haptics |
| Audio | AVFoundation / AVAudioEngine |
| IAP | StoreKit 2 |
| Leaderboards (v1.1+) | GameKit |
| Language | Swift 6 |
| Build | Xcode 26+ |

## Platforms

- **iOS / iPadOS** — primary, touch controls (D-pad + 6 buttons, semi-transparent).
- **macOS** — via Mac Catalyst, keyboard & mouse (Phase 5).
- **tvOS** — separate target with controller support (post v1.0).

Minimum deployment target: **iOS 17 / iPadOS 17 / macOS 14**.

## Project layout

See Section 20 of `STAR_MELEE_PLAN.md` for the full layout. Top level:

```
StarMelee/
├── App/        SwiftUI app entry, Info plist values, asset catalog
├── Scenes/     SwiftUI screens + SpriteKit combat scene
├── Gameplay/   Ship / Weapon / Planet / Projectile / AI / MatchManager
├── Systems/    Input, Haptics, Audio, Scoring, Leaderboard, IAP
├── UI/         HUD components (life / shield / battery bars, controls)
├── Models/     Codable definitions matched to Resources/*.json
└── Resources/  Ships.json, Weapons.json, PowerUps.json, audio, localization
```

## Getting started

```bash
open StarMelee.xcodeproj
```

In Xcode: select the **StarMelee** scheme and an iPhone or iPad simulator (landscape).
Press ⌘R to run. Phase 1 boots to the SwiftUI main menu; tapping **Play** opens a
placeholder SpriteKit arena with a parallax starfield. No ships yet — those land in Phase 2.

## Build phases

The plan splits work into five phases:

1. **Core Combat Prototype** — project skeleton, menu shell, empty arena. ✅ *done*
2. **Combat Depth** — all 12 ships, weapons, HUD, AI, 2-of-3 match series. ✅ *done (Phase 3 polish items below)*
3. **Special Mechanics** — Transporter Beam, Quantum Torpedo, Singularity, Cloak, Self-Destruct. *(current)*
4. **Audio + Compendium + Polish** — music, SFX, 3D ship rotator, settings, leaderboard.
5. **IAP + macOS + Submission** — StoreKit 2, Mac Catalyst build, TestFlight, App Store.

### What's playable right now

- Main menu → Ship Select grid showing all 12 ship silhouettes filtered by faction
- Pick a ship, hit **LAUNCH**, drop into the 16×16-viewport arena
- 10-second pre-match practice phase with semi-transparent countdown and PRACTICE banner; primary + secondary firing allowed, specials locked
- Full 2-of-3 series: each match runs a 2-minute timer (or ends on destruction), 3-second gap between matches, ships reset to 100%
- Captain-difficulty AI opponent that pursues, aims with random error, fires primary + secondary, evades at low health
- 10–14 planets per arena with gravity wells (gravity ramps up over last 5s of countdown)
- 4 instant power-up types (life / battery / shield / timer-extension); 6 more types reserved for Phase 3
- Tactical Minimap (top-right) shows the whole world, planets, power-ups, both ships, and the camera viewport
- Off-screen enemy indicator with world-space distance
- PS5-style analog joystick + 6-button cluster (A/B/C/X/Y/Z) on iOS
- W A S D + Space/F/G + Esc/P keyboard map on Mac Catalyst (Section 10)
- Pause overlay (HUD button or Esc/P) — freezes ship, weapons, AI, gravity, match timer
- Speed Boost via Z (3× max speed for 3 s, 15% battery, ship-specific cooldown)
- Victory overlay with FATALITY tag plumbed in (fires for Quantum-Torpedo kills once Phase 3 lands)

### Phase 3 hand-off notes

1. **Transporter Beam + Quantum Torpedo** (Section 6) — full A+B combo, shield-down requirement, 10-second torpedo timer above target, both defense behaviors (transport-behind, transport-back), `MatchManager.lastKillByQuantumTorpedo` plumbing for FATALITY.
2. **Quantum Singularity Event** (Section 6) — arena-wide debris that damages both ships, chromatic-aberration / lens-distortion visual.
3. **Cloaking Device** (B+C) — only for ships with `weapons.has_cloak == true`; translucent to player, invisible to AI.
4. **Self-Destruct** (A+C) — 4-second countdown, devastating blast, kills user + damages opponent.
5. **All 12 special weapons** — most are duration buffs on the ship; the buff tracker hook already exists on `Ship`. Wire them up driven by the C-button + ship `definition.weapons.special`.
6. **Section 13 haptic catalog** — fold the full event table into `HapticsSystem` and call from gameplay; remember the critical rule (haptics fire **only for events affecting the human player's ship**).
7. **Section 12 audio pipeline** — per-ship engine hum, weapon-fire SFX, transporter shimmer, FATALITY sting.
8. **Pause menu polish** — "Restart Match" and "Quit to Menu" should match Section 9 semantics (restart counts as a loss, quit is a forfeit). Phase 2 currently dismisses to menu for both.

## Reference repositories (study only)

These are GPL-licensed Star Control reimplementations. They are referenced **only as a study aid** for the original game's physics, weapon lifecycles, and AI behavior trees. **No code is copied** — all mechanics are reimplemented from scratch in Swift, and all ships, names, lore, art, and audio are 100% original.

- **The Ur-Quan Masters MegaMod** — <https://github.com/JHGuitarFreak/UQM-MegaMod> — study target for ship physics (thrust, inertia, turn rate), weapon spawn / lifecycle, AI behavior tree, projectile collision, planet gravity, and special-weapon implementations.
- **TW-Light** — <https://github.com/Yurand/tw-light> — study target for the pure melee loop, camera handling, and multi-ship combat structure.

See Section 3 of `STAR_MELEE_PLAN.md` for the full legal & IP guidelines.

## License

© 2026 djEnterprises. All ship designs, names, lore, art, music, and code are original.
