# STAR MELEE — Complete Development Plan

**Prepared for:** Dan Ehrlich (djEnterprises)
**Date:** May 23, 2026
**Purpose:** Comprehensive build specification for the iOS / iPadOS / macOS game **Star Melee**, optimized for use with Claude Code.
**Inspiration:** *Star Control* and *Star Control II* (Super Melee combat mode), with original IP, original ships, original assets, and significant gameplay extensions.

---

## How to Use This Document with Claude Code

This document is structured so that Claude Code can:
1. Read the whole document first to understand scope.
2. Implement features section-by-section in the order presented.
3. Stop and prompt the user at **`>>> DECISION POINT <<<`** markers.
4. Fall back to reasonable defaults (Star Control II-inspired behavior) whenever the spec is silent.

**Working agreement with Claude Code:**
- Use Git from day one. Commit after every working feature.
- Build minimum-viable versions first, then iterate.
- Run on a physical device early and often.
- Reference `star-melee-mockup.html` for visual/mechanical intent.

---

## 1. Project Vision & Scope

### Game Identity
- **Name:** Star Melee
- **Tagline:** Strategic ship-to-ship arena combat across the stars.
- **Genre:** 2D real-time space combat / arena fighter
- **Inspiration:** *Star Control II* Super Melee combat depth × *Mortal Kombat 1* match structure and presentation.

### Monetization Model
**Freemium**:
- **Free tier:** Core game with a starter roster of ships (recommend 6–8).
- **Paid expansion packs:** Additional ships (3–6 ships per pack).
- **Weapon enhancements:** Upgrade modules (better fire rate, larger shield capacity, enhanced special, etc.) for individual ships.
- **No ads in v1.0.** Re-evaluate after launch.

> **>>> DECISION POINT <<<** Final free vs. paid ship split. Recommendation: 6 free starter ships, 2 paid packs of 3 ships each at launch ($1.99 each or $4.99 bundle).

### Platforms
- **Primary:** iOS (iPhone) and iPadOS — touch controls
- **Secondary:** macOS — keyboard/mouse controls (via Mac Catalyst or native AppKit/SwiftUI)
- **Future:** Apple TV with controller support (Phase 5+)

### Target Performance
- 60 FPS on iPhone 12 and newer, iPad Air (4th gen) and newer, Apple Silicon Macs.
- App size under 250 MB for v1.0.

---

## 2. Technology Stack

### Recommended Stack: Swift + SpriteKit + SwiftUI
- **SpriteKit** for the 2D arena combat (rendering, physics primitives, particle effects).
- **SwiftUI** for menus, HUD overlays, settings, Ship Compendium screens.
- **SceneKit** for the 3D ship rotation views in the Ship Compendium.
- **Core Haptics** for per-weapon and per-event haptic feedback.
- **AVFoundation** for music; **AVAudioEngine** for spatial sound effects.
- **GameKit** for Game Center leaderboards (optional in v1.0, recommended for v1.1).
- **StoreKit 2** for in-app purchases (ship packs, weapon enhancements).
- **Mac Catalyst** to ship the macOS version from the same codebase.

### Why This Stack
- Native, no engine licensing fees, no royalties.
- Excellent Claude Code support (Swift + Apple frameworks are well-documented and well-understood by Claude).
- Maximum performance and battery life on Apple devices.
- The user already has iOS app development experience.

> **>>> DECISION POINT <<<** Confirm Swift + SpriteKit before scaffolding. If Unity is preferred (e.g., for easier 3D ship models and cross-platform expansion), flag now — switching mid-build is expensive.

---

## 3. Legal & IP Guidelines

- **No use of the names** "Star Control," "Ur-Quan," "Spathi," "Mycon," or any other trademarked or copyrighted IP from the Star Control series.
- **No copying of original ship designs**, alien races, dialog, music, or art assets.
- **All Star Melee ships, names, lore, art, music, and sound effects must be 100% original.**
- **Reference repositories (UQM, TW-Light) are for study only** — do not copy substantial code blocks. Reimplement mechanics from scratch in Swift.
- **App Store description:** Use phrasing like "inspired by classic 90s space combat." Avoid naming the original game.

### Reference Repositories (study only)
- **The Ur-Quan Masters MegaMod** — https://github.com/JHGuitarFreak/UQM-MegaMod (study ship physics, weapon systems, AI)
- **TW-Light** — https://github.com/Yurand/tw-light (study melee-focused combat loop)

---

## 4. Core Gameplay Loop

### Arena Dimensions & Camera

The playable arena is **16 × 16 viewport-screens** in area (e.g., on a 6.1" iPhone with ~390×844 logical points, the world is roughly 6,240 × 13,504 points — about 256 screens of total area). This is intentionally vast to allow strategic positioning, hide-and-seek with cloaked ships, planet-orbit slingshot maneuvers, and ambush play.

**Camera behavior:**
- The camera **smoothly follows the player's ship** (lerp factor ~0.08 per frame).
- The arena uses **toroidal wrapping** — a classic *Star Control* identity feature. Position is modulo `worldSize`. There are no walls. Ships, projectiles, and the camera all wrap seamlessly across edges.
- When the player ship wraps, the camera position must wrap by the same delta in the same frame so the view never visibly jumps.
- **Rendering:** to make wrap visually seamless when entities are near an edge, render the world in a **3×3 tile pattern** centered on the player (offsets of −1, 0, +1 × worldSize in each axis). The GPU culls off-screen copies cheaply.
- **AI targeting and the off-screen indicator** must use the shortest wrap-aware vector (the standard wrap-minimization trick: if `abs(dx) > worldW/2`, subtract `worldW * sign(dx)`).

**Required HUD additions for the large world:**
- **Tactical Minimap** — top-right of the HUD, just below the enemy's stat bars, ~120×82 pt. **Not bottom-center**, which would overlap touch controls. Shows the entire world to scale with: planets (translucent colored dots), power-ups (small dots), player marker (cyan), enemy marker (red), and the current camera viewport as a thin white rectangle.
- **Off-screen Enemy Indicator** — when the enemy is outside the camera viewport, render a red triangular arrow at the edge of the screen pointing toward them, with the world-space distance shown above the arrow (in "units"). Arrow is clamped to a safe zone that doesn't overlap the top HUD or the bottom controls.

**Tuning notes:**
- Ships spawn ~3 viewport-widths apart near the center of the world (not at opposite corners).
- 10–14 planets scattered through the world with at least 280 units between each, avoiding the spawn corridor.
- AI must aggressively close distance when the player is more than ~1.2 viewports away (always thrusting toward target until close enough to maneuver).
- Power-ups spawn within ~2 viewports of the midpoint between the two ships (not anywhere in the world) so collection feels feasible.

> **>>> DECISION POINT <<<** Confirm `WORLD_SCALE = 16` after playtesting. If the world feels too sparse or matches feel like chase scenes rather than dogfights, scale to 8 or 12. Implement as a tunable constant so this is a one-line change.

### Match Structure (Mortal Kombat-style)
1. **Main Menu** → Play, Compendium, Settings, Leaderboard
2. **Character Select Screen** → Player picks their ship; opponent is "Random" by default (or player selects)
3. **Pre-Match Countdown** — 10 second practice period.
   - **Player can:** move (D-pad/X/Y), fire **A (primary)** and **B (secondary)** weapons.
   - **AI can:** move and fire at *reduced rate* (~60% primary frequency, ~20% secondary frequency) so practice feels real but is survivable.
   - **Locked during countdown for both ships:** C (special weapon), Z (speed boost), A+B (Transporter Beam), B+C (Cloak), A+C (Self-Destruct).
   - **Locked during countdown:** power-up spawning.
   - **Visual:** the big countdown digit must be rendered at ~35% opacity with an outline so the arena stays visible behind it. A "PRACTICE" banner with hint text appears above the ships.
4. **Match Begins** — 2-minute timer starts. Full combat.
5. **Match Ends** when either ship is destroyed, OR timer expires (ship with higher remaining health wins).
6. **Next Match** begins 3 seconds after the previous one ends. Health, shield, battery all reset to 100%.
7. **Series Winner** — first to 2 wins out of 3 matches.
8. **Victory Screen** — Mortal Kombat-style "WINNER" announcement. If a Quantum Torpedo from a Transporter Beam delivered the killing blow, display **"FATALITY"** below the winner banner.
9. **Post-Match** — Replay, change ship, return to main menu.

### Match Timer Behavior
- Countdown displayed at top center: 2:00 → 0:00.
- At 0:00, ship with higher remaining health % wins.
- If health tied: ship with higher shield % wins; if still tied, ship with higher battery % wins; if still tied, declare a Draw and replay match.
- **Timer Extension Power-Up:** +30 seconds when collected mid-match.

---

## 5. Ship System

### Ship Performance Profile
Every ship has these stats, balanced across ships so each has a viable path to victory:

| Stat | Description | Typical Range |
|------|-------------|---------------|
| **Max Health** | Life bar capacity | 60–120 |
| **Heal Rate** | Health regen per second | +0.5% to +3% |
| **Max Shield** | Shield bar capacity | 0 (no shield) to 100 |
| **Shield Up/Down Time** | Seconds to raise/lower shields | 0.1s to 3.0s |
| **Max Battery** | Energy reserve | 60–120 |
| **Battery Regen** | +1% per 0.5s base, ship-modifier 0.5×–1.5× |
| **Mass** | Affects gravity influence | 0.6–1.8 |
| **Acceleration** | Thrust force | 0.05–0.20 |
| **Max Speed** | Velocity cap | 4–9 units/frame |
| **Turn Rate** | Radians per frame | 0.03–0.09 |
| **Hitbox Size** | Physical profile | Small (10px), Medium (14px), Large (20px) |
| **Primary Weapon Fire Rate** | Frames between shots | 6–24 |
| **Secondary Weapon Fire Rate** | Frames between shots | 18–60 |
| **Special Weapon Cooldown** | Seconds | 8–25 |
| **Speed Boost Cooldown** | Seconds | 6–15 |
| **Transporter Beam Cooldown** | Seconds | 20–40 |

### Ship Roster (Initial v1.0 — 12 ships, 6 free + 6 in expansion packs)

#### ALLIANCE FACTION (defenders) — Free tier in v1.0
1. **AEGIS CRUISER** — Balanced workhorse. Medium speed/health/shield. Primary: rapid laser. Secondary: guided missile. Special: **Inertia Dampeners** (nullify planet gravity for 6 seconds).
2. **SOLAR WING** — Fast scout. High speed, low health, no shield. Primary: pulse cannon. Secondary: flak burst. Special: **Super Speed Burst** (3 seconds of 3× speed).
3. **TITAN BULWARK** — Heavy tank. Huge health, slow, strong shield. Primary: dual cannon. Secondary: cluster bomb. Special: **Invulnerability Shield** (4 seconds of immunity).
4. **PRISM HUNTER** — Mid-weight ranger. Primary: prism spread (3 beams). Secondary: focused beam. Special: **EM Blast** (disrupts opponent's engine + weapons for 3s).
5. **NOVA LANCER** — Glass cannon. Fast, fragile, no shield. Primary: lance beam. Secondary: heavy lance. Special: **Homing Missile** swarm (4 missiles).
6. **HALO SENTINEL** — Defensive support. Medium speed, very strong shield, slow shield up/down. Primary: short pulse. Secondary: omni-burst (8-way). Special: **Mimic** (copy opponent's ship for 10s).

#### DOMINION FACTION (raiders) — Expansion Pack #1 ("Dominion Vanguard") in v1.0
7. **VOID REAPER** — Heavy bruiser. High health, slow, medium shield. Primary: plasma cannon. Secondary: gravity well bomb. Special: **Cloaking Device** (8 seconds invisible to AI, translucent to player).
8. **SCARAB STRIKER** — Fast attacker. Primary: swarm cannon. Secondary: rapid darts. Special: **Super Speed** (5 seconds of 2.5× speed + free turning).
9. **OBSIDIAN MAW** — Massive ship, largest hitbox. Devastating offense, slow. Primary: shard volley. Secondary: scatter mines. Special: **Self-Destruct** (4-second timer, devastating blast in radius).
10. **WRAITH PHANTOM** — Stealth class. Primary: weak beam, fast fire. Secondary: phase shot. Special: **Cloaking Device** + Phase Shift (12s cloak).
11. **BONE SPEAR** — Fast skirmisher. Primary: bone shards. Secondary: piercing spear. Special: **Mimic + Speed** combo.
12. **CRIMSON TYRANT** — Flagship. Premium ship. Strong everywhere. Primary: twin cannon. Secondary: heavy torpedo. Special: **Transporter Beam** (built-in advantage; faster transporter cooldown than other ships).

> **>>> DECISION POINT <<<** Confirm the free / paid ship distribution. Also confirm Crimson Tyrant being a "premium" ship is acceptable (it is the highest-tier ship — may want to balance vs. perception of pay-to-win).

### Universal Ship Capabilities
Every ship has:
- **Primary weapon** (A button) — high fire rate, low per-shot damage
- **Secondary weapon** (B button) — lower fire rate, higher damage per shot
- **Special weapon** (C button) — unique ability, long cooldown
- **Transporter Beam** (A+B combo) — universal capability if ship has Transporter Beam installed
- **Cloaking Device** (B+C combo) — only ships with this ability
- **Self-Destruct** (A+C combo) — universal, but range/damage varies
- **Speed Boost** (Z button) — universal, cooldown varies

> **>>> DECISION POINT <<<** Should the Transporter Beam be universal, or only available to ships that "install" it via the weapon enhancement IAP? Spec is ambiguous. Recommendation: every ship can use Transporter Beam, but cooldowns and battery cost vary widely.

---

## 6. Weapon System

### Weapon Categories

#### Primary Weapons (fast fire, low damage)
- **Laser Cannon** — straight beam, fast
- **Pulse Cannon** — rapid energy bolts
- **Plasma Burst** — slow but powerful
- **Prism Spread** — 3-shot spread
- **Lance Beam** — focused fast beam
- **Twin Cannon** — paired shots
- **Bone Shards** — small fragments
- **Swarm Cannon** — rapid scatter

#### Secondary Weapons (slow fire, high damage)
- **Guided Missile** — homes toward opponent
- **Cluster Bomb** — explodes on impact, area damage
- **Heavy Torpedo** — slow, devastating
- **Focused Beam** — slow charge, high damage
- **Flak Burst** — wide spread
- **Phase Shot** — passes through shields once
- **Piercing Spear** — penetrates and damages multiple times
- **Scatter Mines** — drop in arena, persist until destroyed

#### Special Weapons (long cooldown, unique mechanics)
- **Homing Missiles** — swarm of 4 self-guiding missiles
- **EM Blast** — disrupts opponent's engine + weapons for 3s
- **Cloaking Device** — ship invisible to AI, translucent to player
- **Super Speed Burst** — 3× speed for 3 seconds
- **Inertia Dampeners** — immune to planet gravity for 6 seconds
- **Mimic** — copy opponent's ship and weapons for 10 seconds
- **Self-Destruct** — devastating blast, kills user and damages opponent
- **Invulnerability Shield** — immune to all damage for 4 seconds

#### The Ultimate Weapon: TRANSPORTER BEAM + QUANTUM TORPEDO
**Activation:** A + B button combo.
**Requirements:**
- Ship must have shields lowered.
- Lowering shields takes the ship's specific Shield Down time (0.1s to 3.0s).
- Must have a Quantum Torpedo in inventory (collected as a power-up, or starting ammo varies by ship).
- High battery cost.

**Mechanic:**
1. Player engages Transporter Beam → ship animation + Star Trek-style transporter effect + sound.
2. If opponent ship's shields are DOWN → Quantum Torpedo is transported onto the opponent's bridge.
3. 10-second countdown timer appears above the opponent's ship (visible to both ships).
4. **Defense Option 1:** If opponent has a Transporter Beam installed and battery to use it, they can transport the torpedo into space behind their ship (it detonates harmlessly behind them).
5. **Defense Option 2:** If opponent is within ~25% of arena range of the firing ship, they can transport the torpedo BACK to the firing ship. Strategic: the firing ship must MOVE OUT OF RANGE quickly after firing.
6. **Detonation:** When the 10-second timer hits zero, the Quantum Torpedo explodes:
   - Catastrophic damage to ship it is currently inside.
   - Triggers a **QUANTUM SINGULARITY EVENT** in the arena.

#### QUANTUM SINGULARITY EVENT
- After torpedo detonates, the arena warps. Visual effect: spacetime ripples, color shift, gravitational lensing.
- **Physical obstructions appear** — debris, broken hull fragments, micro-singularities — that damage BOTH ships on contact.
- These obstructions persist until the end of the current match.
- Visual: pulsing dark/light effect, semi-transparent debris with glowing edges.

### Damage Scaling Formula
Weapons damage scales by:
```
final_damage = base_damage × (1 + weapon_weight × ship_offensive_modifier) × (1 - target_shield_modifier × target_shield_strength) × (1 - target_armor_modifier)
```
Where:
- `weapon_weight`: Slow heavy weapons (torpedoes, bombs) weight 1.5–2.5. Fast weapons (lasers, pulses) weight 0.4–0.8.
- `ship_offensive_modifier`: Per-ship balance number.
- `target_shield_strength`: 0 to 1, scales with current shield %.

> **>>> DECISION POINT <<<** Final damage formula and ship balance values. Claude Code should build a JSON config file (`Ships.json` and `Weapons.json`) so balancing can iterate without code changes. Recommend that we tune through playtesting once Phase 2 is complete.

---

## 7. Shield, Battery, Health Systems

### Health (Life Bar)
- Range: 0% (destroyed) to 100% (full).
- Color-coded: green (100–70%), yellow (70–35%), red (35–0%).
- Mortal Kombat 1 visual style: ship name above bar, bar drains from inside toward edge.
- Each ship has a **Self-Heal Rate** (e.g., +0.5% to +3% per second).
- Self-heal pauses for 2 seconds after taking damage.

### Shield
- Range: 0% to 100%.
- Located visually directly under the Life Bar.
- Some ships have no shield (Solar Wing, Nova Lancer, Wraith Phantom in some configs).
- Shield absorbs damage before health.
- **Shield Up/Down time** varies (0.1s to 3.0s) — strategic for transporter beam usage.
- Shield slowly recharges when not under damage: +5% per second after 3 seconds of no damage.
- Shield must be DOWN to use the Transporter Beam.

### Battery
- Range: 0% to 100%.
- Located visually directly under the Shield Bar.
- Drained by:
  - Speed Boost (15% per use)
  - Transporter Beam (40% per use)
  - Cloaking Device (5% per second while cloaked)
  - Special Weapon (varies by ship: 20%–60%)
  - Inertia Dampeners (10% per second while active)
- Regenerates at +1% per 0.5 seconds (ship-specific multiplier 0.5× to 1.5×).
- Resets to 100% at start of every match.
- Restored by power-ups (10%, 50%, 100%).

---

## 8. Power-Ups

### Power-Up Spawn Logic
- **Spawn frequency:** every 15–30 seconds during a match (random).
- **Adaptive boost:** If a ship's health is below 25%, increase power-up spawn rate and prioritize spawning a power-up near that ship.
- **Visual:** Floating glowing icons in the arena. Approach to collect.
- **Despawn:** Power-up disappears after 12 seconds if uncollected.

### Power-Up Types
1. **Life Restore** — three tiers: +10%, +50%, +100% (full).
2. **Battery Restore** — three tiers: +10%, +50%, +100% (full).
3. **Shield Restore** — +50% shield instantly.
4. **Quantum Torpedo Ammo** — adds 1 torpedo to inventory.
5. **Speed Boost Charge** — instantly resets Speed Boost cooldown.
6. **Special Weapon Reset** — instantly resets Special Weapon cooldown.
7. **Timer Extension** — adds 30 seconds to match timer.
8. **Damage Multiplier** — 2× outgoing damage for 8 seconds.
9. **Shield Regen Boost** — 3× shield regen rate for 10 seconds.
10. **Repair Drone** — auto-heals +1% per second for 15 seconds (stacks with ship heal rate).

### Power-Up Indicators (HUD)
- Active power-up effects appear as **colored translucent icons** below the player's Battery bar.
- Each icon shows a countdown ring around it.
- Maximum 4 active power-ups visible at once.

---

## 9. Touch Controls (iOS / iPadOS)

### Layout
Following the **Sega Genesis / 8BitDo M30** controller layout for the right-hand button cluster, with a **PS5-style analog joystick** on the left for movement.

**Bottom-left:** PS5-style analog joystick (NOT a 4-direction cross D-pad)
- Circular base ~140 pt diameter, semi-transparent with cyan border ring and inner dashed ring detail.
- Inner "stick" disc ~64 pt diameter, dark with concave dish shading and drop-shadow so it reads as 3D.
- On touch: player presses anywhere inside the base, then drags. The stick visually translates toward the finger, capped at the base radius. On release, the stick animates back to center with a slight overshoot (spring curve).
- Output: a normalized 2D vector (stickX, stickY) in the range −1..+1. A deadzone of ~0.18 prevents jitter near the center.
- The stick is converted internally to 8-way directional input (up/down/left/right booleans) using the deadzone threshold for the existing input layer, but the raw analog vector should also be exposed so future builds can do proportional turning/thrust.
- **Multitouch correctness is critical:** the stick must track *one specific touch identifier* (the finger that started the drag) and continue tracking even when that finger drifts outside the base bounds. Other fingers using the buttons must not disturb the stick.

**Bottom-right:** Two rows of three buttons each (semi-transparent):
- **Top row:** X / Y / Z
- **Bottom row:** A / B / C

### Button Map
| Button | Function | Hold Behavior |
|--------|----------|---------------|
| A | Fire primary weapon | Hold = auto-fire at ship's primary fire rate |
| B | Fire secondary weapon | Hold = auto-fire at ship's secondary fire rate |
| C | Special weapon | Tap once (cooldown enforced) |
| X | Accelerate (thrust forward) | Hold to maintain thrust |
| Y | Brake (active deceleration) | Hold to brake |
| Z | Speed Boost | Tap (cooldown enforced) |
| A + B | Engage Transporter Beam → Quantum Torpedo | — |
| B + C | Engage Cloaking Device | — |
| A + C | Begin Self-Destruct timer | — |

### Gesture Controls (additional)
- **Tap on screen:** Target weapon (for targeted weapons like homing missile)
- **Tap and swipe on own ship:** Move ship in swipe direction
- **Tap and hold on own ship + drag:** Continuous movement following finger
- **Double-tap anywhere:** Pause game

### Pause Menu
- **Resume** — return to match
- **Restart Match** — restart current match (counts as a loss)
- **Ship Compendium** — view ship details
- **Settings**
- **Quit to Main Menu** (counts as a forfeit)

> **>>> DECISION POINT <<<** Should the analog stick output be used as truly proportional input (turn rate and thrust scale with stick magnitude) or just as 8-way digital? Recommendation: start digital for v1.0 simplicity, expose the raw vector so v1.1 can add proportional control as a Settings option ("Stick Sensitivity: Digital / Analog").

---

## 10. macOS Controls

### Keyboard Map
| Key | Function |
|-----|----------|
| W or ↑ | Thrust (X equivalent) |
| S or ↓ | Brake (Y equivalent) |
| A or ← | Turn left |
| D or → | Turn right |
| Space | Fire primary (A button) |
| F | Fire secondary (B button) |
| G | Special weapon (C button) |
| Shift | Speed boost (Z button) |
| T | Transporter Beam (A+B equivalent) |
| C | Cloaking Device (B+C equivalent) |
| K | Self-Destruct (A+C equivalent) |
| P or Esc | Pause |
| Tab | Target lock (cycle targets) |

### Mouse
- **Click on enemy ship:** Lock target for targeted weapons.
- **Click and drag own ship:** Direct movement (mirrors touch behavior).

---

## 11. Ship Compendium

### Purpose
Detailed view of each ship's full performance profile. Accessible from main menu and pause menu.

### Layout per Ship Page
- **3D Ship Model** — rotatable 360° with pinch-to-zoom (iOS) or click-drag (macOS).
- **Ship Name** — large display font.
- **Faction Badge**
- **Performance Stats** — all stats from Section 5 (Ship System) shown as bars.
- **Weapon Loadout** — primary, secondary, special with descriptions.
- **Strengths** — bullet list of pros.
- **Weaknesses** — bullet list of cons.
- **Recommended Play Style** — short paragraph.
- **Win/Loss Stats** — player's win-loss record with this ship.
- **Unlock Status** — Free / Owned / Locked (with link to IAP screen if locked).

### Expandability
The Compendium must support adding new ships via:
- IAP unlock of ship pack
- Update releases adding new ships
- New ship entries should slot in alphabetically within their faction.

> **>>> DECISION POINT <<<** For v1.0, can 3D ship models be **stylized low-poly geometric models** (built programmatically with SceneKit)? This is the recommended MVP approach. Higher-fidelity models can come in v1.1+.

---

## 12. Audio Design

### Music

**Critical IP guidance:** Do NOT use any copyrighted music as a reference even informally — never embed, sample, or "style after" specific commercial tracks (e.g. movie scores). Even mentioning a copyrighted track by name in build assets, App Store metadata, or commit messages creates legal risk. Use the style description below and the verified-safe sources.

**Style description:** Epic, atmospheric retro-synth with driving percussion, organ swells, low-end strings, and tension-building arpeggios. Think the broad genre of dramatic sci-fi cinematic — not any specific film.

**Use:** Looping during matches. Variants for menu, victory, defeat, and Quantum Singularity Event (tense overlay).

### Verified-Safe Asset Sources (CC0 / Royalty-Free for Commercial Apps)

These were all checked safe for monetized App Store use; double-check each pack's LICENSE file at download time.

**Music (looping background tracks):**
- **alkakrab on itch.io** — Free Sci-Fi Game Music Pack (Vol. 1, 2, 3). Explicitly free for commercial use, no attribution required. Strong epic atmospheric loops. https://alkakrab.itch.io/free-sci-fi-game-music-pack
- **White Bat Audio — Free Horror/Sci-Fi Music Pack** — 27 retro synth tracks, royalty-free. **Requires credit** in app: "Music by Karl Casey @ White Bat Audio" (add an Audio Credits row in Settings → About). Dark cinematic feel. https://whitebataudio.com/product/free-horror-sci-fi-music-pack/
- **OpenGameArt.org** — search "sci-fi music," "space ambient," "retro synth"; many CC0 looping tracks.
- **99Sounds.org** — InterSpace and similar free sci-fi atmosphere packs.

**Sound Effects (lasers, explosions, thrust, impacts, power-ups, shields):**
- **Kenney.nl/assets → Sci-fi Sounds** — CC0 / Public Domain (no attribution). Consistent, high-quality retro sci-fi effects. https://kenney.nl/assets/sci-fi-sounds
- **OpenGameArt.org** — "60 CC0 Sci-Fi SFX," "50 CC0 Sci-Fi SFX," etc.
- **99Sounds.org** — Free Sci-Fi Sounds pack.

**Ship sprite art:**
- **Kenney.nl** — Spaceship Pack, Space Kit (polished pixel art).
- **OpenGameArt.org** — Spaceship Assets section.

**3D models for Compendium viewer:**
- **Sketchfab.com** — filter for "sci-fi spaceship," sort by Free, verify license is CC0 or CC-BY (commercial-OK).

### Implementation
- Convert all audio files to `.caf` or `.m4a` for best iOS performance (`afconvert` CLI).
- Build an `AudioManager` singleton that preloads all one-shot sounds at scene load and exposes `playSound(named:)`, `playMusic(named:fade:)`.
- Loop background music via `SKAudioNode` with cross-fade between menu and match tracks.
- Use **Per-ship unique sound effects** where possible: engine hum (looping while thrusting), primary weapon fire, secondary, special, shield raise/lower, damage taken (varies by incoming weapon), destruction. Mix-and-match from the CC0 packs for distinctness.
- **Audio Credits section** in Settings → About — required whenever any pack mandates attribution. Put it under a clearly visible heading.

### For v1.0 MVP
- Synthesized sounds via `AVAudioEngine` are acceptable for unique per-ship effects if curated packs don't fit.
- Acceptable quality for launch; upgrade to commissioned music in v1.1.

> **>>> DECISION POINT <<<** Use free CC0 packs only (no attribution overhead), or accept the White Bat Audio credit for higher-quality music? Recommendation: ship with alkakrab + Kenney for v1.0 (zero-attribution), then commission custom score for v1.1.

---

## 13. Haptic Feedback (iOS Only)

Use **Core Haptics** for per-weapon and per-event feedback. The implementation should define a `HapticsSystem` enum of pattern identifiers that all gameplay code calls into — never call raw Core Haptics from gameplay logic.

**CRITICAL RULE:** Haptics fire **only for events that affect the human player's ship** (taking damage, firing your own weapons, your own ship's impacts). Never haptic for events that happen to the AI — the player should feel their own ship, not the opponent's.

### Pattern Catalog

| Event | Pattern (Style) | Notes |
|-------|-----------------|-------|
| **Weapons (player's own ship)** | | |
| Primary weapon fire | Sharp short tick | ~10 ms |
| Secondary weapon fire | Heavier thump | ~25 ms |
| Special weapon fire | Long resonant build | ~60 ms |
| Transporter Beam engage | Shimmer pattern (multi-pulse rising) | [40, 30, 40, 30, 60] |
| Torpedo planted on player | Heavy 3-pulse | [60, 40, 80] — *fires when the player's ship has been targeted* |
| Speed Boost engage | Double tick | [25, 15, 25] |
| Cloak engage | Light-pause-light (fade-in feel) | [15, 50, 15] |
| Self-Destruct armed | Heavy 3-pulse warning | [80, 40, 80, 40, 80] |
| **Damage taken by player** | | scaled by incoming damage |
| Light damage (< 5 HP) | Single soft pulse | ~12 ms |
| Medium damage (5–15 HP) | Single sharp pulse | ~28 ms |
| Heavy damage (> 15 HP) | Multi-pulse impact | [40, 25, 60] |
| Shield broken | Triple sharp tick | [25, 25, 25] |
| Shield raise | Building hum | ~20 ms |
| **Player ship environmental impacts** | | |
| Crashed into planet | Heavy 3-pulse | [40, 20, 50] |
| Crossed wrap boundary | (silent — toroidal wrap is not an event) | — |
| **Big events (visceral)** | | |
| Player ship destroyed | Sustained intense pattern | from explosion_big |
| Quantum Singularity Event | Deep continuous rumble (long pattern) | [200, 60, 150, 60, 200] |
| Power-up collected | Pleasant 2-tap chirp | [10, 20, 15] |
| **Match flow** | | |
| Match start (each of 3 matches) | 2-pulse cue | [25, 80, 25] |
| Round won by player | Triumphant 3-pulse cascade | [60, 40, 100] |
| Round lost by player | Single long thud | ~120 ms |
| **Series end** | | |
| Series victory | Triumphant cascade | [80, 50, 80, 50, 200] |
| Series defeat | Three slow thuds | [180, 100, 180] |
| FATALITY | Intense 6-pulse + long finale | [50, 30, 50, 30, 50, 30, 350], fired 700ms *after* the victory haptic so they don't run together |

### Settings
- User can control haptic intensity in Settings: **Off / Low / Medium / High** (multiplies pattern durations and intensities; "Off" disables entirely).
- Default is **Medium** on iPhone, **Low** on iPad (larger device, less wrist contact), **Off** on macOS (no haptic engine).

### Implementation Pattern (for Claude Code)
- Define `enum HapticEvent` with cases for every pattern in the table.
- A single `HapticsSystem.play(_ event: HapticEvent)` function is the only public API.
- All gameplay code calls `HapticsSystem.play(.damageTakenHeavy)` etc., never raw `CHHapticEngine` calls.
- Haptic patterns are JSON files in `Resources/Haptics/` so they can be tuned without code changes.

---

## 14. Visual & Animation Design

### Visual Juice Philosophy
In a premium iOS game, **every player action must deliver satisfying multi-sensory feedback** (visual + audio + haptic). This "juice" is often what separates good indie games from great ones. Lean into Star Melee's fast, kinetic combat with generous, context-aware effects.

### Camera Shake System
A reusable shake helper used across the game:
- **Light shake** (amp ≈ 4, dur ≈ 8 frames): medium damage taken by player
- **Medium shake** (amp ≈ 8, dur ≈ 14): heavy damage taken by player
- **Heavy shake** (amp ≈ 14, dur ≈ 22): ship destruction
- **Massive shake** (amp ≈ 22, dur ≈ 36): Quantum Singularity Event
- Shake amplitude decays each frame (multiplier ≈ 0.88). A stronger shake never gets interrupted by a weaker one.
- Respect Settings → Reduce Motion: disable shake entirely or scale to 25%.

### Time Dilation (Slow Motion on Heavy Events)
Brief slow-mo for dramatic weight. Multiply gameplay `dt` by a scale factor for a short window:
- **Ship destruction:** scale = 0.35, duration ≈ 14 frames (≈ 0.23s real time, feels longer in-game)
- **Quantum Singularity detonation:** scale = 0.25, duration ≈ 22 frames
- Implementation: a global `timeScale` multiplier on `dt` in the update loop, with a frame counter that restores it to 1.0 when expired.

### Shockwave Rings
Expanding circular shockwaves on big explosions. Each shockwave is a ring of color that grows from 0 to a max radius while fading. Used in:
- **Ship destruction:** dual shockwaves — outer white (radius 140), inner ship-color (radius 90)
- **Quantum Singularity Event:** triple shockwaves — white 320, magenta 230, cyan 150

### Per-Ship Animations Required
- **Idle** — gentle bob / engine glow pulse
- **Thrusting** — engine streak / plasma jet trail (particle count and intensity scale with thrust input)
- **Turning** — slight thruster flare on opposite side
- **Primary / Secondary / Special weapon firing** — muzzle flash + projectile, unique per ship
- **Taking damage** — flash white briefly, shake
- **Low health** — when HP < 30%, ship emits continuous smoke particles drifting opposite the thrust direction. Below 15%, smoke turns orange and emits more frequently (visible signal of imminent destruction to both players).
- **Shield active** — translucent hemisphere around ship, pulsing
- **Shield raising / lowering** — sweep / fade animation
- **Cloaked** — translucent ship outline (player view) or invisible (AI view)
- **Destruction** — multi-stage explosion: bright core flash → expanding debris → dual shockwave rings → lingering smoke

### Arena Visual Elements
- **Parallax starfield** — 3 layers minimum (far slow, mid, near fast). Far stars almost stationary; near stars move with camera at high parallax factor. Adds depth and motion feedback.
- **Optional nebula clouds** — large semi-transparent drifting sprites at low alpha for atmosphere.
- **Planets** — 10–14 per arena, with gravity wells visible as subtle gradient rings
- **Planet rings** (Saturn-style on some)
- **Quantum Singularity debris** — fragmented hull pieces with glowing edges, persist for the rest of the match
- **Quantum Singularity warp effect** — brief chromatic aberration + screen flash
- **Power-up icons** — color-coded translucent glow with pulse animation

### HUD Visual Design
- **Mortal Kombat 1 style** life bars at top corners
- Ship name in retro-futuristic font (Orbitron or similar)
- Life / Shield / Battery bars stacked vertically
- Power-up icons below as translucent colored chips
- Match timer at top center
- Match score (e.g., "MATCH 1 OF 3 — WINS: 1–0") below timer
- **"STAR MELEE"** logo small at top center
- **Tactical Minimap** at top-right of the HUD, just below the enemy's stat bars: shows full 16×16 world to scale, with planets, power-ups, player (cyan), enemy (red), and camera viewport rectangle. See Section 4 for sizing details.
- **Off-screen Enemy Indicator** — red arrow at viewport edge pointing toward the enemy when off-camera, with world-distance label. Uses wrap-aware shortest-path direction. See Section 4 for behavior details.

### 120Hz / ProMotion Support
Set `view?.preferredFramesPerSecond = 120` on devices that support it (`UIScreen.main.maximumFramesPerSecond == 120`). Use `dt`-scaled physics and animations so the feel is identical at 60 / 120 Hz. ProMotion makes the analog stick + camera-follow feel dramatically smoother.

> **>>> DECISION POINT <<<** For v1.0, ships will be rendered as **stylized polygon shapes** drawn programmatically (similar to the HTML mockup). This is recommended for MVP. Full sprite art / 3D models in v1.1+.

---

## 15. AI Opponent Design

### AI Difficulty Levels
- **Cadet** (easy) — slow reaction, poor aim, rarely uses special weapons
- **Captain** (medium) — default — reasonable aim, occasional special usage
- **Admiral** (hard) — fast reaction, good aim, smart special usage, uses cover
- **Legendary** (very hard) — frame-perfect aim, predictive movement, optimal weapon usage

### AI Behavior Tree
1. **Threat assessment** — health %, distance to opponent, distance to planets, power-ups available
2. **Movement** — pursuit, evasion, planet-orbit slingshot, power-up grab
3. **Combat** — fire primary in range, fire secondary at slower targets, use special when advantageous
4. **Defense** — raise shields when low health, evade homing missiles, transport away from incoming Quantum Torpedoes
5. **Mistake injection** — AI deliberately misses occasionally on easier difficulties

---

## 16. Settings Menu

### Sections
1. **Audio**
   - Master Volume (slider 0–100%)
   - Music Volume (slider 0–100%)
   - SFX Volume (slider 0–100%)
   - Haptic Intensity (Off / Low / Medium / High) — iOS only
2. **Controls**
   - View Control Scheme diagram (visual reference of button layout)
   - Adjust button opacity (slider)
   - Adjust button size (slider)
   - Left-handed mode (mirror layout)
   - **Modern Gesture Mode** toggle (default Off) — when On, replaces the analog stick + button cluster with the gesture scheme: left-side one-finger drag = steer + thrust; right-side tap = primary, long-press = secondary, two-finger tap = special; bottom-edge swipes = shields up/down, brake, boost. Same `InputManager` protocol; underlying ship code is unchanged.
3. **Gameplay**
   - AI Difficulty (Cadet / Captain / Admiral / Legendary)
   - Match Length (90s / 120s default / 180s / 300s)
4. **Fun Modifiers** (single-player only, see Section 16.5)
5. **How to Play** — interactive tutorial
6. **Ship Compendium** — link to Compendium screen
7. **Language & Localization** — language picker (English at launch; plan Spanish, French, German, Japanese, Korean, Mandarin for v1.1+)
8. **Leaderboard** — local win-loss records per ship + Game Center button
9. **Accessibility**
   - Reduce Motion (scales camera shake, particles, time dilation; respect system setting)
   - Dynamic Type (scale all UI text per system setting)
   - Colorblind palettes (Standard / Protanopia / Deuteranopia / Tritanopia)
   - VoiceOver labels on all menu controls
   - High-contrast HUD toggle
10. **About**
    - App version
    - Credits (including Audio Credits if any pack requires attribution)
    - Link to djEnterprises website
    - Link to Privacy Policy
    - Link to Support / Contact
    - Acknowledgments

### 16.5. Fun Modifiers ("Cheats" Section)

A clearly separated section in Settings, visible to all players. Single-player only.

**Toggles (each persisted in `UserDefaults`):**
- **Invincibility** — player ship cannot take damage
- **Unlimited Battery** — boost / transporter / cloak / specials cost zero battery
- **Unlimited Special Weapons** — special cooldown is zero
- **Unlimited Speed Boost** — boost has no cooldown, no battery cost
- **Infinite Power-Ups** — power-ups spawn at 3× the normal rate and never despawn
- **No Planet Gravity** — planets don't pull ships (collision damage still applies)
- **No Ship Inertia** (optional advanced) — ships brake to a stop instantly when thrust is released
- **Enemy AI Difficulty** — Cadet / Normal / Admiral / Legendary (separate from main Gameplay setting)

**Critical implementation rule:** when ANY fun modifier is active, **Game Center submissions must be disabled** for that match and a small **"Modifiers Active"** badge must appear on the post-match screen. Local stats can still record but should be flagged as modified.

**UI:** native-feeling SwiftUI list with toggle switches, brief description text under each, and a prominent "Reset All Modifiers" button at the bottom.

> **>>> DECISION POINT <<<** Ship Fun Modifiers in v1.0 or save for v1.1? Recommendation: include them in v1.0 — they're cheap to implement, add real replayability for casual players, and make great TikTok / YouTube clip material ("invincible Solar Wing dodges 100 missiles").

---

## 16.6. Game Controller Support (PS5 DualSense + Xbox)

**Status:** Required for v1.0. Apple's `GameController` framework makes this straightforward, and the App Store highlights controller-supported games.

### Button Mapping (PS5 DualSense → Xbox equivalent)

| PS5 | Xbox | Function | Notes |
|-----|------|----------|-------|
| Left Stick | Left Stick | Rotate ship (horizontal) + Thrust (vertical) | Replaces the touch analog stick |
| Cross (X) | A | Primary weapon (auto-repeat while held) | Most used button |
| Square | X | Secondary weapon | |
| Triangle | Y | Special weapon | |
| Circle | B | Self-Destruct (requires confirmation tap) | High-risk |
| R1 | RB | Raise / lower shields (toggle) | |
| R2 | RT | Speed Boost (hold) | DualSense adaptive trigger if available |
| L1 | LB | Engage Transporter Beam | |
| L2 | LT | Brake (hold) | |
| D-Pad | D-Pad | Fine rotation adjustments | Useful for precise aiming |
| Options / Menu | Menu | Pause | |
| Touch Pad (PS5) | View | Open Compendium | |

### Implementation Notes
- Use `GCController` and `GCExtendedGamepad` for cross-controller compatibility.
- Create a clean `InputSource` protocol with implementations for `TouchInput`, `GestureInput`, `KeyboardInput`, and `GamepadInput`. All four feed the same `Ship.firePrimary()`, `applyThrust(amount:)`, etc.
- On controller connect, auto-switch input mode (or honor a Settings override).
- Support DualSense haptics where possible — adaptive trigger pressure for boost (R2), rumble on damage taken.

### Controller Layout Screen
A premium polish feature: a dedicated **"Controller Layout"** screen accessible from Settings and Pause menu. Shows a clean vector illustration of a PS5 (and optionally Xbox) controller with text labels overlaid on every button.

---

## 16.7. VersionCheckManager (Reusable Update Reminder)

A lightweight, reusable component for politely reminding players to update.

### Implementation
1. On app launch (or once per day via `UserDefaults` last-check date), make a `URLSession` GET to:
   ```
   https://itunes.apple.com/lookup?id=YOUR_APPLE_ID&country=US
   ```
2. Parse `results[0].version` from the JSON response.
3. Compare to `Bundle.main.infoDictionary?["CFBundleShortVersionString"]` using semantic version comparison.
4. If App Store version is newer:
   - Show a non-blocking `UIAlertController` or custom banner: "A new version of Star Melee is available. Update for the latest ships and improvements?"
   - Buttons: **Update** (opens App Store via `SKStoreProductViewController`) and **Later**.
5. **Polish requirements:**
   - Remind only once per new version (store last-prompted version in `UserDefaults`).
   - Never block gameplay or pause an active match.
   - Async / silent on network failure.
6. **Reusability:** built as a stand-alone `VersionCheckManager` singleton with two-line config (Apple ID + app name) so it can drop into all future djEnterprises apps.

---

## 16.8. Onboarding

Gentle, non-blocking. No forced tutorial level.

- **First match only:** subtle translucent hints overlay key controls — "Drag the joystick to steer & thrust," "Tap A to fire your primary," "A+B together to engage the Transporter Beam."
- Hints fade after 3 seconds or on first relevant input (player tapped A → hide the A hint).
- After the first match, on the Results screen, show a one-time "Got the hang of it?" line with a link to the full How to Play screen.
- Respect **Reduce Motion** (fade in slowly instead of pop-in animation).
- Goal: player feels competent within 60–90 seconds of first launch.

---

## 17. Leaderboard System

### Local Storage
- Stored in `UserDefaults` (or Core Data for richer data).
- Persists across app launches and updates.

### Tracked Per Ship
- Total matches played
- Wins / Losses
- Win % (color-coded: green > 60%, yellow 40–60%, red < 40%)
- Best win streak
- Total damage dealt
- Total damage taken
- Quantum Torpedo kills (FATALITY count)
- Self-Destruct wins

### Global (Game Center) — Required for v1.0

Game Center is free, server-less, and gives Star Melee long-term engagement hooks. Required for v1.0.

**App Store Connect setup (before coding):**
1. Enable Game Center in App Store Connect → Features.
2. Create two leaderboards (use exact IDs below or your reverse-domain equivalents):
   - `com.dje.starmelee.wins` — Total Wins (Integer, descending)
   - `com.dje.starmelee.win_streak` — Longest Win Streak (Integer, descending)
3. Create 3–5 achievements:
   - **First Blood** — win your first match
   - **On a Roll** — achieve a 5-win streak
   - **Ship Master** — win at least once with every core ship
   - **Untouchable** — win a match without taking damage
   - **FATALITY** — win via Quantum Torpedo

**Architecture:**
- `GameCenterManager` singleton handles authentication and score / achievement submission.
- Authenticate early (on first menu load) but never block gameplay if the player declines or is offline.
- `submitWin()` and `submitWinStreak()` are no-ops when offline / signed out / Fun Modifiers active.
- Track win streak locally — reset on loss, increment on win. Persist best streak in `UserDefaults`.

**UI:** "Game Center" / "Leaderboards" button in the main menu presents the native `GKGameCenterViewController`.

### Player Scoring Formula (proposed)
```
match_score = (base_win_bonus) +
              (damage_dealt × 0.5) -
              (damage_taken × 0.25) +
              (weapon_accuracy_pct × 100) +
              (special_weapon_kills × 50) +
              (time_remaining_bonus) +
              (fatality_bonus × 200)
```

> **>>> DECISION POINT <<<** Confirm scoring formula. Recommended to make this tunable in a config file so it can be balanced post-launch.

---

## 18. In-App Purchases (StoreKit 2)

### Initial v1.0 SKUs
- **Dominion Vanguard Pack** ($2.99) — unlocks Void Reaper, Scarab Striker, Obsidian Maw
- **Shadow Fleet Pack** ($2.99) — unlocks Wraith Phantom, Bone Spear, Crimson Tyrant
- **Bundle: All Ships** ($4.99) — unlocks both packs (save $0.99)
- **Weapon Enhancement: Primary +20%** ($0.99 per ship) — boosts primary weapon damage
- **Weapon Enhancement: Shield +25%** ($0.99 per ship) — boosts max shield
- **Weapon Enhancement: Battery +25%** ($0.99 per ship) — boosts battery capacity
- **Cosmetic: Skin Pack** ($0.99 per ship) — color/texture variations

### StoreKit Implementation
- Use StoreKit 2 (async/await API).
- Server-side receipt validation NOT required for v1.0 (single-device purchases).
- Cloud sync via iCloud (CloudKit) so purchases persist across devices.
- Restore Purchases button in Settings.

---

## 19. Build Phases & Timeline

### Phase 1: Core Combat Prototype (3–5 weeks)
- Xcode project setup, Git repo, SwiftUI menu shell
- SpriteKit scene with arena background
- Single ship with inertia movement
- Planets with gravity (and visual gravity wells)
- Touch controls (D-pad + 6 buttons, semi-transparent)
- Single weapon firing
- Basic damage and death
- **Milestone:** Playable 1v1 with a placeholder enemy that just exists.

### Phase 2: Combat Depth (3–4 weeks)
- All 12 ships' geometric designs and stat profiles
- All primary, secondary, special weapons
- Shield, battery, life systems with HUD
- Mortal Kombat-style HUD
- Match timer + 2-of-3 series structure
- Power-up spawning and collection
- Pre-match 10-second free-movement countdown
- Pause functionality
- Game Over and victory screens with FATALITY logic
- AI opponent (Captain difficulty)
- **Milestone:** Full single-player melee experience.

### Phase 3: Special Mechanics (2–3 weeks)
- Transporter Beam + Quantum Torpedo mechanic (with all defense behaviors)
- Quantum Singularity Event arena modification
- Cloaking Device + AI vs player visibility logic
- Self-Destruct with 4-second countdown
- All ship special weapons implemented
- Haptic feedback for all events
- **Milestone:** Every ship's full unique kit is playable.

### Phase 4: Audio + Compendium + Polish (3–4 weeks)
- Music system (menu + match + special tracks) — use alkakrab + Kenney CC0 packs per Section 12
- Per-ship sound effects (synthesized placeholders for v1.0)
- Ship Compendium with 3D rotatable models (low-poly SceneKit)
- Settings menu (audio sliders, controls, gameplay, accessibility, Fun Modifiers)
- Localization framework (English only at launch)
- Leaderboard local storage + **Game Center integration** (leaderboards + achievements)
- AI difficulty levels (Cadet / Admiral / Legendary)
- **Game Controller support** (PS5 / Xbox via `GCExtendedGamepad`) + Controller Layout screen
- **VersionCheckManager** (reusable App Store update reminder)
- Visual juice: camera shake, time dilation, shockwave rings, low-HP smoke, parallax starfield
- Gentle first-match onboarding overlay
- 120Hz ProMotion support
- Accessibility pass (VoiceOver labels, Reduce Motion respect, Dynamic Type)
- **Milestone:** Feature-complete v1.0 candidate.

### Phase 5: IAP + macOS + Submission (2–3 weeks)
- StoreKit 2 integration (all ship packs and enhancements)
- Mac Catalyst build with keyboard controls
- App Store assets (icons, screenshots, preview video)
- TestFlight beta with 10–20 testers
- Bug fixes and polish
- App Store submission
- **Milestone:** Launched.

### Total estimated build time: 12–18 weeks of focused part-time work.

---

## 20. File Structure (Proposed)

```
StarMelee/
├── README.md
├── STAR_MELEE_PLAN.md           ← this document
├── star-melee-mockup.html       ← browser prototype reference
├── .gitignore
├── StarMelee.xcodeproj/
├── StarMelee/
│   ├── App/
│   │   ├── StarMeleeApp.swift
│   │   ├── AppDelegate.swift
│   │   └── Info.plist
│   ├── Scenes/
│   │   ├── MainMenuView.swift
│   │   ├── ShipSelectView.swift
│   │   ├── CombatScene.swift            ← SKScene
│   │   ├── PauseView.swift
│   │   ├── VictoryView.swift
│   │   ├── CompendiumView.swift
│   │   └── SettingsView.swift
│   ├── Gameplay/
│   │   ├── Ship.swift                   ← entity
│   │   ├── Weapon.swift
│   │   ├── Projectile.swift
│   │   ├── Planet.swift
│   │   ├── PowerUp.swift
│   │   ├── QuantumTorpedo.swift
│   │   ├── QuantumSingularity.swift
│   │   ├── PhysicsEngine.swift
│   │   ├── AIController.swift
│   │   └── MatchManager.swift           ← series logic (2-of-3)
│   ├── Systems/
│   │   ├── InputSystem.swift            ← touch + keyboard
│   │   ├── HapticsSystem.swift
│   │   ├── AudioSystem.swift
│   │   ├── ScoringSystem.swift
│   │   ├── LeaderboardStore.swift
│   │   ├── IAPManager.swift             ← StoreKit 2
│   │   └── LocalizationManager.swift
│   ├── UI/
│   │   ├── HUDView.swift                ← Mortal Kombat-style HUD
│   │   ├── DPadView.swift
│   │   ├── ButtonClusterView.swift      ← A/B/C/X/Y/Z
│   │   ├── LifeBarView.swift
│   │   ├── ShieldBarView.swift
│   │   ├── BatteryBarView.swift
│   │   └── PowerUpIndicatorView.swift
│   ├── Resources/
│   │   ├── Ships.json                   ← ship stats config
│   │   ├── Weapons.json                 ← weapon configs
│   │   ├── PowerUps.json
│   │   ├── Audio/
│   │   ├── Music/
│   │   └── Localization/
│   └── Models/
│       ├── ShipDefinition.swift
│       ├── WeaponDefinition.swift
│       ├── PowerUpDefinition.swift
│       └── MatchState.swift
├── StarMeleeTests/
│   ├── DamageCalculationTests.swift
│   ├── PhysicsTests.swift
│   └── MatchStateTests.swift
└── StarMeleeUITests/
```

---

## 21. Reference Repositories

These are GPL-licensed and **for study only** — do not copy substantial code blocks. Reimplement mechanics from scratch in Swift.

### Primary Study Reference: The Ur-Quan Masters (UQM)
- **Repo:** https://github.com/JHGuitarFreak/UQM-MegaMod
- **What to study:** Ship physics (thrust, inertia, turn), weapon spawn/lifecycle, AI behavior tree, projectile collision, planet gravity computation, special-weapon implementations.
- **License:** GPL v2 — do not import code directly into Star Melee.

### Secondary Reference: TW-Light
- **Repo:** https://github.com/Yurand/tw-light
- **What to study:** Pure melee loop, camera handling, multi-ship combat structure.

---

## 22. Workflow with Claude Code

### Recommended Session Pattern
1. **Read STAR_MELEE_PLAN.md** at the start of every session.
2. **Identify the current Phase and uncompleted milestone.**
3. **Build in vertical slices** — one full feature end-to-end before moving on.
4. **Commit after every working feature** with descriptive Git messages.
5. **Run on a physical device frequently** — touch feel cannot be evaluated in Simulator.
6. **Update this document** when scope changes or decisions are made.

### Sample Claude Code Prompts (for the user to copy/paste)

**Phase 1 kickoff:**
> "Read STAR_MELEE_PLAN.md and star-melee-mockup.html. Then scaffold a new Xcode project for the iOS app Star Melee using Swift + SpriteKit + SwiftUI. Set up the basic SwiftUI main menu (per Section 4 and 16 of the plan), and create an empty CombatScene SKScene with a placeholder arena background. No ships yet. Commit when complete."

**Phase 1 mid-build:**
> "Implement the Ship class per Section 5 of STAR_MELEE_PLAN.md. Add inertia physics matching the behavior of the HTML mockup. Create one playable ship (Aegis Cruiser) with the touch D-pad controls per Section 9. Do NOT implement weapons yet. Commit when ship can move."

**Phase 2 milestone — ship select:**
> "Build the Ship Select screen per Section 4 + Section 19 (Phase 2). Read Ships.json for the ship roster. Display all 12 ships in a grid with their stat profiles. Selecting a ship and tapping CONFIRM should launch the CombatScene with the chosen ship."

---

## 23. Critical Fixes from HTML Mockup Feedback

The user identified that in the previous mockup, the player dies almost immediately, and the countdown number blocked visibility. Address all of these in implementation:

1. **Starting ship positions** must be in safe zones — at least 200px from any planet, one ship per side of arena.
2. **Pre-match 10-second practice countdown** with the exact rules from Section 4:
   - Player and AI can move and fire **primary (A)** and **secondary (B)** weapons.
   - AI fires at reduced frequency during practice (~60% primary rolls, ~20% secondary rolls).
   - **Locked during countdown:** C (special), Z (speed boost), A+B (Transporter), B+C (Cloak), A+C (Self-Destruct), and power-up spawning.
3. **Gravity ramping** — planet gravitational pull starts at 0 and ramps to full strength over the last 5 seconds of the countdown. Players should not get pulled into planets before they understand the controls.
4. **Visible "PRACTICE" banner** during countdown with hint text explaining what works (e.g., "Move and fire A (primary) / B (secondary) to test your ship. Specials, Boost, Transporter, Cloak unlock at MATCH START.").
5. **Semi-transparent countdown digit** — render the large 10/9/8/... number at ~35% opacity with a thin outline ring so the arena and ships remain visible behind it. Do not fully obscure the screen.
6. **Initial ship orientation** facing away from the nearest planet.
7. **Tutorial / How to Play** screen accessible from first launch and from the pause menu.
8. **Implementation pattern (for Claude Code):** in the ship update function, pass a single `allowSpecials: Bool` flag. Primary and secondary firing should never check this flag — they always work in any playing phase. Specials, combos, and boost must check it.

---

## 24. App Store Submission Checklist

Before submitting v1.0:
- [ ] All 12 ships playable and balanced
- [ ] All weapon systems functional
- [ ] All power-ups spawning and collectible
- [ ] Transporter Beam + Quantum Torpedo + Singularity Event working
- [ ] FATALITY trigger working
- [ ] 2-of-3 match series logic verified
- [ ] Touch controls fully functional on iPhone and iPad
- [ ] Keyboard controls fully functional on macOS
- [ ] All Settings options working
- [ ] StoreKit 2 IAP tested on sandbox account
- [ ] Restore Purchases working
- [ ] Privacy Policy URL live
- [ ] Support email + URL live
- [ ] App Store description, keywords, screenshots, preview video done
- [ ] App icon designed (1024×1024)
- [ ] Privacy Manifest filled out
- [ ] No copyrighted content (audit pass)
- [ ] TestFlight beta tested by 10+ external users
- [ ] Performance verified on iPhone 12, iPad Air 4, Apple Silicon Mac
- [ ] Crash-free rate > 99.5% in TestFlight

---

## 25. Open Decision Points Summary

Collected from throughout this document. Resolve before or during the relevant Phase:

1. **Ship distribution: free vs. paid** (Section 1, 5) — Recommend 6 free + 6 paid split. (SuperGrok suggests 8 free + smaller themed packs; viable alternative.)
2. **Swift + SpriteKit confirmation** (Section 2) — Default Yes.
3. **Universal Transporter Beam or IAP-gated** (Section 5, 6) — Recommend universal with battery cost.
4. **Damage formula final values** (Section 6) — Build as JSON config; tune in playtesting.
5. **3D model fidelity in Compendium** (Section 11, 14) — Recommend low-poly SceneKit for MVP.
6. **Crimson Tyrant being a "premium" ship** (Section 5) — Decision needed: pay-to-win perception risk.
7. **Scoring formula final values** (Section 17) — Build as JSON config; tune in playtesting.
8. **Music asset strategy** (Section 12) — Recommend alkakrab + Kenney CC0 packs for v1.0 (zero-attribution); commission custom composer for v1.1.
9. **Localization timing** (Section 16) — English only at launch is fine.
10. **`WORLD_SCALE` value** (Section 4) — Default 16. Tune in playtesting; consider 8 or 12 if combat feels too sparse.
11. **Fun Modifiers in v1.0?** (Section 16.5) — Recommend yes — cheap to implement, great for casuals and clip-sharing.
12. **Analog stick: digital 8-way vs proportional** (Section 9) — Recommend digital for v1.0, expose raw vector for v1.1 proportional option.
13. **Modern Gesture Mode in v1.0?** (Section 9) — Recommend yes as an optional toggle (default Off). The Sega Genesis layout remains the default per the original spec.

---

## 26. Closing Notes

This document is the complete blueprint for Star Melee v1.0. It is designed to be read end-to-end by Claude Code, and to be the source of truth for every decision in the build.

**For Claude Code:** When in doubt about an unspecified behavior, default to the behavior closest to Star Control II's Super Melee mode. If still ambiguous, stop and prompt the user.

**For Dan:** Read the open decision points in Section 25. Resolve the must-decide ones (free vs. paid split, Crimson Tyrant tier) before Phase 2. Everything else can be decided as it comes up.

This game has potential. The combat depth, freemium model, and Mortal Kombat-style presentation are a strong combination. Build it tight, ship the MVP, then iterate based on player data.

---

*Document compiled May 23, 2026. All sections current as of this date.*
*Star Melee © djEnterprises. All ship designs, names, lore, and assets original.*
