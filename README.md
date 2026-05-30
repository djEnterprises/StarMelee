# Starfighter

**Strategic ship-to-ship arena combat across the stars.**

A 2D real-time space combat / arena fighter for iOS, iPadOS, macOS, and tvOS.
Inspired by the *Star Control II* Super Melee mode, with original IP, original ships,
original art, and a *Mortal Kombat*-style match structure.

> Bundle ID `com.djEnterprises.Starfighter`. The Xcode project, targets, schemes, source
> folder, GitHub repo, and Swift module are all named **Starfighter**. (The original design
> spec was authored under the working title "Star Melee" — that historical doc is preserved
> in `SuperGrok/` unchanged.)

> **Spec:** see [`STARFIGHTER_PLAN.md`](./STARFIGHTER_PLAN.md) — the complete 26-section design and build plan. Claude Code should read this at the start of every session.
>
> **Visual reference:** see [`starfighter-mockup.html`](./starfighter-mockup.html) — interactive browser prototype showing the intended look and feel.

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

| Platform | Status | Scheme | Controls |
|---|---|---|---|
| **iOS / iPadOS** | ✅ shipping | `Starfighter` | Touch (PS5-style analog stick + 6-button cluster) + hardware keyboard + PS5/Xbox controllers |
| **macOS** (via Mac Catalyst) | ✅ shipping | `Starfighter` | Keyboard (WASD + Space/F/G/R/Esc) + mouse + PS5/Xbox controllers |
| **tvOS** (Apple TV) | ✅ shipping | `StarfighterTV` | PS5/Xbox controllers + Siri Remote (gamepad-only — touch controls hidden) |

Minimum deployment targets: **iOS 17 / iPadOS 17 / macOS 14 / tvOS 17**.

All four platforms share the same `Starfighter/` source folder via Xcode's `PBXFileSystemSynchronizedRootGroup` — no duplicated source tree. Platform-specific behavior (touch UI, haptics, etc.) is gated with `#if !os(tvOS)` / `#if os(iOS)` source guards.

## Project layout

See Section 20 of `STARFIGHTER_PLAN.md` for the full layout. Top level:

```
Starfighter/
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
open Starfighter.xcodeproj
```

In Xcode: select the **Starfighter** scheme and an iPhone or iPad simulator (landscape).
Press ⌘R to run. Phase 1 boots to the SwiftUI main menu; tapping **Play** opens a
placeholder SpriteKit arena with a parallax starfield. No ships yet — those land in Phase 2.

## Build phases

The plan splits work into five phases:

1. **Core Combat Prototype** — project skeleton, menu shell, empty arena. ✅ *done*
2. **Combat Depth** — all 12 ships, weapons, HUD, AI, 2-of-3 match series. ✅ *done*
3. **Special Mechanics** — Transporter Beam, Quantum Torpedo, Singularity, Cloak, Self-Destruct. ✅ *done*
4. **Audio + Compendium + Polish** — procedural SFX, SceneKit 3D Compendium rotator, leaderboard, Game Center wiring, full Core Haptics patterns, shield up/down UX. ✅ *done (curated audio packs pending)*
5. **IAP + macOS + Submission** — StoreKit 2, TestFlight, App Store. *(current)*

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

### Phase 4 additions in place

- **Procedural audio system** — `AVAudioEngine` pipeline with 18 synthesized one-shots (laser sweeps, explosions, shimmers, victory stings). No file assets required for v1.0 per Section 12; replace with CC0 packs from the source list below in v1.1.
- **SceneKit 3D Compendium rotator** — `SCNShape`-extruded ship silhouettes with idle auto-rotation, drag-to-orbit, pinch-to-zoom. Faction-tinted emissive materials.
- **Compendium detail view** — per-ship stats / weapon loadout / strengths / your record (from `LeaderboardStore`).
- **Leaderboard local store** — per-ship `matchesPlayed / wins / losses / currentStreak / bestStreak / totalDamageDealt / totalDamageTaken / fatalityKills / selfDestructWins / forfeits`. Sorted by win %. Game Center submission paired (offline-safe).
- **Game Center achievement triggers** — First Blood (first win), On a Roll (5-streak), FATALITY (torpedo kill). Manager no-ops cleanly until you enable Game Center in App Store Connect.
- **Full CHHapticPattern engine** — multi-pulse rhythms from Section 13's spec ([40,30,40,30,60] etc.) via `CHHapticEngine`, with `UIImpactFeedbackGenerator` fallback for devices without Core Haptics.
- **Shield up/down UX** — explicit toggle via `SHIELD` HUD button or `R` key. Translucent hemisphere visual; per-ship `shieldUpTime` / `shieldDownTime` honoured. Transporter Beam now requires `shieldsFullyDown` (replacing the 5% proxy).
- **Quit-to-Menu forfeit recording** — Pause → Quit writes a forfeit row to LeaderboardStore.

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

Five safety checkpoints tagged in git:

```bash
git tag -l                              # phase2-stable, phase2-supergrok, phase3-complete, phase4-complete, phase4-audit
git reset --hard phase2-stable          # back to "Aegis playable, AI Captain"
git reset --hard phase2-supergrok       # back to "+ visual juice, toroidal, Fun Modifiers"
git reset --hard phase3-complete        # back to "+ specials, Transporter Beam + Singularity, Cloak, Self-Destruct"
git reset --hard phase4-complete        # back to Phase 4 done (3 targets)
git reset --hard phase4-audit           # current — audit pass + tvOS target
```

Per-tag scope:
- **`phase2-stable`** — Phase 2 only, no SuperGrok additions, bounded-walls world
- **`phase2-supergrok`** — Phase 2 + visual juice + toroidal wrap + onboarding + Fun Modifiers + VersionCheckManager + GameCenter/Controller scaffolds
- **`phase3-complete`** — Phase 3 done. All special weapons, Transporter Beam + Quantum Torpedo + Singularity, Cloak, Self-Destruct, full haptic catalog, Pause polish
- **`phase4-complete`** — Procedural audio, SceneKit 3D Compendium, leaderboard local store + Game Center submission, full CHHapticPattern engine, shield up/down UX
- **`phase4-audit`** — current. Full hot-path audit: cached UserDefaults reads (~700 reads/sec eliminated), equality-guarded GameState (no more SwiftUI invalidation storms), force-unwrap fixes, timer leak fix, tvOS target added with platform guards, verified iOS / iPad / tvOS / Mac Catalyst all build clean

`git log phase3-complete..phase4-complete --oneline` shows the Phase 4 commit chain.

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

### Phase 5 hand-off notes — needs your direct input

Phases 1–4 are complete. The remaining items all require **decisions or external setup** you have to make personally:

1. **Audio asset selection** — `AudioSystem` ships with procedurally synthesized one-shots (Section 12 explicitly accepts this for v1.0). Whenever you want a step up, pick CC0 tracks/SFX from the source list above (alkakrab itch.io, Kenney.nl, etc.) and the existing API stays the same — only the buffer source changes from generated to file-loaded.
2. **App Store Connect setup** — Game Center: enable in ASC → Features → create two leaderboards (`com.djEnterprises.starfighter.wins`, `com.djEnterprises.starfighter.win_streak`) and five achievements (`first_blood`, `on_a_roll`, `ship_master`, `untouchable`, `fatality`). IDs are already declared in `GameCenterManager`; submissions wake up the moment ASC is configured.
3. **Apple App ID for VersionCheck** — After your first App Store publish, set `VersionCheckManager.shared.appleAppID` to the numeric ID from ASC. Until then it's a silent no-op.
4. **Free vs. paid ship split** — Plan Section 5 recommends 6 free + 6 paid; SuperGrok suggested 8 free + smaller themed packs. Your business call. The Ships.json `tier` field is the toggle.
5. **AI difficulty tuning** — Captain has been playtested. Cadet, Admiral, and Legendary will feel right after a pass on `aimErrorRange` / `secondaryFireProbabilityPerSecond` / `specialFireProbabilityPerSecond` in `AIController.swift`.
6. **StoreKit 2 IAP wiring** — Phase 5 spec: ship-pack purchases, weapon-enhancement IAPs. `IAPManager.swift` placeholder file referenced in plan Section 20 hasn't been created yet because the SKUs depend on your final ship-split decision.
7. **TestFlight beta** — When you're ready, archive + upload via Xcode → ASC.
8. **App icon (1024×1024) + screenshots + preview video** — All Phase 5 marketing assets.

## Reference repositories (study only)

These are GPL-licensed Star Control reimplementations. They are referenced **only as a study aid** for the original game's physics, weapon lifecycles, and AI behavior trees. **No code is copied** — all mechanics are reimplemented from scratch in Swift, and all ships, names, lore, art, and audio are 100% original.

- **The Ur-Quan Masters MegaMod** — <https://github.com/JHGuitarFreak/UQM-MegaMod> — study target for ship physics (thrust, inertia, turn rate), weapon spawn / lifecycle, AI behavior tree, projectile collision, planet gravity, and special-weapon implementations.
- **TW-Light** — <https://github.com/Yurand/tw-light> — study target for the pure melee loop, camera handling, and multi-ship combat structure.

See Section 3 of `STARFIGHTER_PLAN.md` for the full legal & IP guidelines.

## License

© 2026 djEnterprises. All ship designs, names, lore, art, music, and code are original.
