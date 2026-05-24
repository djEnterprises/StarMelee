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

1. **Core Combat Prototype** — project skeleton, menu shell, empty arena. *(current)*
2. **Combat Depth** — all 12 ships, weapons, HUD, AI, 2-of-3 match series.
3. **Special Mechanics** — Transporter Beam, Quantum Torpedo, Singularity, Cloak, Self-Destruct.
4. **Audio + Compendium + Polish** — music, SFX, 3D ship rotator, settings, leaderboard.
5. **IAP + macOS + Submission** — StoreKit 2, Mac Catalyst build, TestFlight, App Store.

## Reference repositories (study only)

These are GPL-licensed Star Control reimplementations. They are referenced **only as a study aid** for the original game's physics, weapon lifecycles, and AI behavior trees. **No code is copied** — all mechanics are reimplemented from scratch in Swift, and all ships, names, lore, art, and audio are 100% original.

- **The Ur-Quan Masters MegaMod** — <https://github.com/JHGuitarFreak/UQM-MegaMod> — study target for ship physics (thrust, inertia, turn rate), weapon spawn / lifecycle, AI behavior tree, projectile collision, planet gravity, and special-weapon implementations.
- **TW-Light** — <https://github.com/Yurand/tw-light> — study target for the pure melee loop, camera handling, and multi-ship combat structure.

See Section 3 of `STAR_MELEE_PLAN.md` for the full legal & IP guidelines.

## License

© 2026 djEnterprises. All ship designs, names, lore, art, music, and code are original.
