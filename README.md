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
2. **Combat Depth** — all 12 ships, weapons, HUD, AI, 2-of-3 match series. ✅ *done*
3. **Special Mechanics** — Transporter Beam, Quantum Torpedo, Singularity, Cloak, Self-Destruct. ✅ *done*
4. **Audio + Compendium + Polish** — music, SFX, 3D ship rotator, settings, leaderboard. *(current)*
5. **IAP + macOS + Submission** — StoreKit 2, Mac Catalyst build, TestFlight, App Store.

### SuperGrok additions in place

The SuperGrok 2026-05-25 addendum (`SuperGrok/STAR_MELEE_PLAN.md`) layered in a number of polish features that have been integrated:

- **Visual juice** — camera shake (4 amplitudes), time-dilation slow-mo on heavy events, layered shockwave rings on destruction, low-HP smoke trail that turns orange below 15%, 120Hz ProMotion support on capable devices.
- **Toroidal world wrap** — classic Star Control identity. `WorldConstants.worldMode` defaults to `.toroidal`; flip to `.bounded` to restore the wall-bounce Phase 2 behavior in one line.
- **Accessibility — Reduce Motion** setting (off / reduced / disabled) scales all juice effects.
- **First-match onboarding hints** — translucent labels fade per-input.
- **Fun Modifiers** screen — Invincibility, Unlimited Battery, Unlimited Boost, Infinite Power-Ups, No Planet Gravity, plus Unlimited Specials + No Ship Inertia stubs wired for Phase 3 / 4. Any active modifier disables Game Center submission and flags the victory screen.
- **`VersionCheckManager`** — reusable App Store update reminder. Drops into every future djEnterprises app.
- **`GameCenterManager`** scaffold — offline-safe stub; ready when ASC is configured.
- **`InputSource` / `GamepadInputSource`** — PS5 DualSense + Xbox controllers auto-connect and feed the same `InputState` that touch and keyboard use.

### Phase 3 additions in place

- **All 12 ship special weapons** (C button) — Inertia Dampeners, Super Speed Burst/Long, Invulnerability Shield, EM Blast, Homing Missile swarm (4), Cloaking Device, Cloak+Phase Shift, Mimic, Mimic+Speed, Self-Destruct, Transporter Beam (built-in)
- **Transporter Beam + Quantum Torpedo** (A+B combo) — full Section 6 mechanic. 10-second timer above target, defense option 2 (transport torpedo back if within 25% arena range), FATALITY trigger on torpedo kill
- **Quantum Singularity Event** — 4–6 hexagonal debris fragments spawn after detonation, persist until match end, deal 12 HP contact damage to either ship
- **Cloak** (B+C combo) — only for ships with `has_cloak` (Void Reaper, Wraith Phantom). 8-second duration, 40% battery + 5%/s drain, AI accuracy heavily degraded against cloaked targets
- **Self-Destruct** (A+C combo, universal) — 4-second armed countdown, 80 HP linear-falloff blast over 220-unit radius, kills source
- **Full Section 13 haptic catalog** — every weapon fire, damage tier, match-flow event, and FATALITY with delayed finale impulse. Strictly player-only per the critical rule
- **Pause polish** — Restart Match counts as a loss; Quit dismisses to menu (forfeit record lands in Phase 4)
- **Buff system foundation** — Ship.activeBuffs supports duration effects for all specials + future duration power-ups

## Revert / safety

Three safety checkpoints tagged in git:

```bash
git tag -l                              # phase2-stable, phase2-supergrok, phase3-complete
git reset --hard phase2-stable          # back to "Aegis playable, AI Captain"
git reset --hard phase2-supergrok       # back to "+ visual juice, toroidal, Fun Modifiers"
git reset --hard phase3-complete        # back to current head (Phase 3 done)
```

Per-tag scope:
- **`phase2-stable`** — Phase 2 only, no SuperGrok additions, bounded-walls world
- **`phase2-supergrok`** — Phase 2 + visual juice + toroidal wrap + onboarding + Fun Modifiers + VersionCheckManager + GameCenter/Controller scaffolds
- **`phase3-complete`** — current. All special weapons, Transporter Beam + Quantum Torpedo + Singularity, Cloak, Self-Destruct, full haptic catalog, Pause polish

`git log phase2-supergrok..phase3-complete --oneline` shows the Phase 3 commit chain.

### Audio sources (Phase 4 — verified CC0 / commercial-safe)

When the Phase 4 audio pipeline lands, source from these packs only. Never sample or
"style after" a copyrighted commercial track — see Section 12 of the plan.

**Music** (looping background tracks):
- alkakrab on itch.io — Free Sci-Fi Game Music Pack Vol. 1 / 2 / 3 (free commercial, no attribution)
- White Bat Audio Free Horror/Sci-Fi pack — 27 retro synth tracks (requires credit: "Music by Karl Casey @ White Bat Audio")
- OpenGameArt.org — search "sci-fi music," "space ambient" (filter to CC0)
- 99Sounds.org — InterSpace + similar sci-fi atmosphere packs

**Sound effects** (lasers, explosions, thrust, impacts, power-ups, shields):
- Kenney.nl/assets → Sci-fi Sounds (CC0, no attribution)
- OpenGameArt.org — "60 CC0 Sci-Fi SFX," "50 CC0 Sci-Fi SFX," etc.

**Ship sprites** (Phase 4+ when promoting from polygon silhouettes):
- Kenney.nl Spaceship Pack / Space Kit
- OpenGameArt.org Spaceship Assets

When any pack requires attribution, add the credit line under Settings → About → Credits.

### Phase 4 hand-off notes

Phase 3 is done. Phase 4 items remaining per plan Section 19:

1. **Audio pipeline** — `AudioSystem` is still a thin stub. Phase 4 brings per-ship engine hum, primary/secondary/special weapon SFX, transporter shimmer, FATALITY sting, looping music. Use the CC0 source list above — never sample copyrighted commercial tracks.
2. **Compendium 3D ship rotator** — Section 11 calls for rotatable low-poly SceneKit models. Today's Compendium shows the polygon silhouette.
3. **Game Center wiring** — `GameCenterManager` is offline-safe stubbed. Daniel needs to enable Game Center in App Store Connect → Features and create the two leaderboards + five achievements (IDs already declared in code).
4. **Leaderboard local store** — Section 17 wants per-ship win/loss records persisted via UserDefaults or Core Data. Nothing recorded today.
5. **AI difficulty tuning** — Cadet / Captain / Admiral / Legendary are all selectable, but only Captain has been playtested.
6. **Full Core Haptics patterns** — `HapticsSystem` approximates Section 13 timings with dispatched impacts. Phase 4 moves to `CHHapticPattern` JSON files for precise multi-pulse rhythms.
7. **Forfeit record on Quit** — currently dismisses; Phase 4 leaderboard layer should write a forfeit row.
8. **Shield up/down UX** — Transporter Beam currently uses a 5%-shield proxy. Phase 4 polish: explicit shield-up/down toggle or animation per Section 7.

## Reference repositories (study only)

These are GPL-licensed Star Control reimplementations. They are referenced **only as a study aid** for the original game's physics, weapon lifecycles, and AI behavior trees. **No code is copied** — all mechanics are reimplemented from scratch in Swift, and all ships, names, lore, art, and audio are 100% original.

- **The Ur-Quan Masters MegaMod** — <https://github.com/JHGuitarFreak/UQM-MegaMod> — study target for ship physics (thrust, inertia, turn rate), weapon spawn / lifecycle, AI behavior tree, projectile collision, planet gravity, and special-weapon implementations.
- **TW-Light** — <https://github.com/Yurand/tw-light> — study target for the pure melee loop, camera handling, and multi-ship combat structure.

See Section 3 of `STAR_MELEE_PLAN.md` for the full legal & IP guidelines.

## License

© 2026 djEnterprises. All ship designs, names, lore, art, music, and code are original.
