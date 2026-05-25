# Star Control iOS Game Development Guide for Claude Code

**Version**: 5.0 (Controller Polish, Settings + Fun Modifiers, Full Multi-Platform)  
**Date**: May 24, 2026  
**Purpose**: This consolidated spec (v4.0) merges all design decisions, control schemes (including optional classic virtual pad), technical recommendations, asset sources, monetization strategy (freemium + StoreKit ship packs), Game Center, version update checker, and full multi-platform guidance (iOS + tvOS + Mac Catalyst). It now includes extensive guidance for visual juice, particles, UI polish, onboarding, accessibility, data-driven architecture, performance, macOS-specific refinements, and share features to help Claude Code build the most premium-feeling, polished experience possible. It is the single authoritative source of truth for building a fluid, strategic, premium-feeling 2D space melee game inspired by the original Star Control / Star Control 2 (1990s) Super Melee mode.

Feed this entire document (or relevant sections) to Claude Code when generating, refactoring, or expanding the Xcode/SpriteKit prototype. The goal is a **single universal Xcode project** targeting iOS, tvOS, and Mac Catalyst that feels excellent on iPhone (gesture or classic pad), Apple TV (gamepad), and Mac (mouse/controller).

---

## 1. Game Concept & Scope

**Core Loop**: Pure one-on-one melee space combat. No story, no exploration, no fleet battles. Focus exclusively on the ship-to-ship dogfighting that made Star Control 2 legendary.

**Key Mechanics**:
- Ships accelerate in the direction they are facing (true inertia / momentum — no friction in space).
- Primary weapon, Secondary weapon, Special weapon/ability per ship.
- Random power-ups that spawn in the arena (speed boost, temporary shields, cloaking, weapon overcharge, etc.).
- Self-destruct as a high-risk, high-reward tactical option.
- Full toroidal wrapping (classic Star Control identity).

**Ship Variety & Balance Philosophy** (Critical for Long-Term Success):
- Every ship must feel viable. Balance through **rock-paper-scissors** mechanics rather than raw power.
- Different ships have unique speed, turn rate, weapon profiles, acceleration/braking, shield strength, and special abilities.
- Goal: Strategic depth where skill, ship choice, and tactics matter more than which ship is "stronger."
- Launch with **8–12 core ships** (free). Each ship must have clear strengths and hard counters.
  - Archetypes examples: Fast dodger (beats homing), Tank (beats direct lasers), Stealth/ambush, Area-denial, Glass cannon, etc.
- Document a "counter matrix" during design.

**Ship Roster & Expansion Packs (Monetization & Replayability)**:
- **Base game (free)**: Exactly **8 core ships** with full rock-paper-scissors balance. Every ship must feel viable and have clear counters.
- **Expansion packs**: Themed packs with **4–8 new ships** each, priced at $2.99.
- Suggested themes (heavily stylized — never direct copies to avoid copyright):
  - Cosmic Raiders Pack (agile fighters)
  - Nebula Behemoths Pack (heavy cruisers/tanks)
  - Void Stalkers Pack (stealth/hit-and-run)
  - Galactic Legends Pack (classic silhouette homages with original names)
  - Future ideas: Star Trek-inspired, Star Wars-inspired, Babylon 5-inspired, Alien/Predator-inspired, etc.
- **IAP Implementation Requirement**: Use StoreKit 2. When a ship pack is purchased, the app must immediately unlock those ships (persist via UserDefaults or a secure unlock flag). Ships are defined in a central data-driven registry (JSON or Swift structs). The ship selection screen only shows ships the player has unlocked. New packs must **not** power-creep the core game — every new ship must have meaningful counters.
- Use data-driven ship definitions (struct + JSON/config + unlock status) so expansion content can be added with minimal code changes.

**Match Pacing**: Quick, intense matches — aim for most games lasting 10–30 seconds. This drives high replayability and makes short-form video sharing (TikTok/YouTube Shorts) natural and effective.

**Current State**: Working prototype exists with on-screen D-pad + buttons. The task is to evolve it into a premium touch-first experience.

---

## 2. Playing Field Size, Wrapping & Camera (Toroidal Arena)

**Decision**: Make the playing field **significantly larger** than one iPhone screen **AND retain full toroidal wrapping** (looping edges). This is a core identity feature of Star Control.

### Why Larger Than One Screen?
- Current prototype feels cramped — accelerating immediately sends you to the opposite side.
- Larger field lets ships build real speed and momentum before wrapping, creating satisfying chases, positioning play, and strategic depth.
- Recommended size: **4× to 6×** screen dimensions in each axis (tunable; some tests may prefer up to 8–9× for very fast ships).
  - Example for iPhone 15/16 (~390 × 844 points safe area): world size **2400 × 2400** or **3000 × 3000** points.
- This gives breathing room while still feeling like a "small arena" battle (not an endless void).

### Wrapping Logic (Toroidal)
Retain the classic Star Control wrap-around. It enables endless strategic maneuvering without hard walls punishing momentum.

Implementation in `SKScene.update(_:)` or after physics simulation:

```swift
// Assuming world centered at (0,0) for simplicity
let halfW = worldSize.width / 2
let halfH = worldSize.height / 2

func wrap(_ node: SKNode) {
    if node.position.x > halfW {
        node.position.x -= worldSize.width
    } else if node.position.x < -halfW {
        node.position.x += worldSize.width
    }
    if node.position.y > halfH {
        node.position.y -= worldSize.height
    } else if node.position.y < -halfH {
        node.position.y += worldSize.height
    }
}
```

Apply `wrap()` to: player ship, enemy ship, projectiles, power-ups, and any other moving entities every frame (or after velocity application).

Camera must also handle wrapping gracefully (see Camera section below).

### Camera System
Use `SKCameraNode` added to the scene.

- Camera smoothly follows the **player's ship** with slight lag/inertia so the view feels alive and gives a sense of speed.
- Recommended lerp (tunable):

```swift
let followSpeed: CGFloat = 0.08   // lower = more lag / inertia feel
camera.position.x = camera.position.x * (1 - followSpeed) + player.position.x * followSpeed
camera.position.y = camera.position.y * (1 - followSpeed) + player.position.y * followSpeed
```

- Alternative: Give the camera its own velocity that chases the target for even more "cinematic inertia".
- When the player wraps, the camera position should also wrap (or jump smoothly) so the view never shows an obvious seam.
- On iPhone: Camera follows player (or smart framing to keep both ships visible when possible).
- On Apple TV: Entire arena fits on screen; minimal or static camera.

**Result**: The game feels expansive and strategic on a small phone screen while preserving the original Star Control magic.

---

## 3. iPhone Touch Controls (The Most Critical Part)

**Guiding Principle**: Controls must feel as fluid and precise as a PS5 DualSense controller. The game will succeed or fail based on how good the touch controls feel. **Default experience uses no permanent on-screen buttons**, but the player **must have a Settings toggle** to switch to a Classic Virtual Pad mode (visible joystick + buttons) for accessibility or preference.

### Control Style Toggle (Settings Screen)
- **Modern Gesture Controls** (Default — Premium feel)
- **Classic Virtual Pad** (Visible on-screen joystick on left + fire/special buttons on right, similar to the original prototype)

Claude must implement **both modes** and respect the user preference stored in UserDefaults. The underlying `Ship` movement and weapon methods remain identical; only the input layer changes.

### Modern Gesture Scheme (Default — Split-Screen + Edge Gestures)

Divide the screen roughly in half vertically for primary interactions, with bottom-edge swipes for ship systems.

#### Left Half (~50% width) — Ship Movement / Thrust & Rotation
- **Primary interaction**: One-finger drag / pan.
- **Behavior**:
  - Horizontal drag → rotates the ship toward the drag direction (smooth lerp to target angle).
  - Vertical drag upward → applies forward thrust (intensity can be constant while dragging or scaled by drag distance/length for variable thrust/acceleration feel).
  - Small downward drag = light reverse thrust / brake.
- On finger lift → stop applying thrust (ship continues with existing momentum — true inertia).
- Optional: Draw a very subtle, fading virtual thumbstick indicator only while touching.

**Why this works**: Mimics the left analog stick on a controller. One continuous gesture controls both facing and acceleration.

#### Right Half (~50% width) — Weapons & Special Actions
- **Single tap** (anywhere in right half or safe central area): Primary weapon (fires repeatedly at the ship's fire rate while held — auto-repeat). This must be extremely reliable even during rapid tapping.
- **Long-press** (instead of double-tap): Secondary weapon. Long-press avoids accidental secondary fire when the player is rapidly tapping primary.
- **Two-finger tap** or **quick swipe upward** on right half: Special / Ultimate weapon.
- **Triple-tap** or **swipe down from the top edge of the right zone** (with confirmation flash): Self-destruct.
- All gestures must be fast, forgiving, and provide immediate visual + haptic confirmation.

#### Bottom Edge Gestures (Ship Systems — Global)
- **Swipe up from the bottom edge**: Raise shields (visual pulse + haptic).
- **Swipe down from the bottom edge**: Lower shields / vent heat.
- **Swipe left from the bottom edge**: Brake / reverse thrust.
- **Swipe right from the bottom edge** (or hold + swipe): Speed boost / afterburner.
- These keep the center of the screen clean for combat while giving quick access to defensive and mobility systems.

### Multi-Touch Requirement (Non-Negotiable)
- Player must be able to keep their left thumb on the movement zone **while** using right thumb/index finger for weapons.
- Use raw `UITouch` tracking or a combination of `UIPanGestureRecognizer` (left) + `UITapGestureRecognizer` / `UISwipeGestureRecognizer` / `UILongPressGestureRecognizer` (right). This is usually cleaner and more reliable than SpriteKit's `touchesBegan/Moved/Ended` alone.
- Track touches by `UITouch` object or assign zones based on initial touch location. Ignore touches that start in one zone and drift into another if needed for stability.

### Haptic & Visual Feedback (Juiciness — Non-Negotiable for Premium Feel)
- Light impact haptic on every primary weapon shot.
- Medium impact on secondary / long-press.
- Heavy + notification-style haptic on special and self-destruct.
- Thrust particles / flame trail that scales with thrust input.
- Muzzle flash + screen shake on weapon impact (use `SKAction` or camera shake helper).
- Subtle screen edge glow or vignette when wrapping or at high speed.
- Clear visual + audio feedback on all edge gestures (shields up/down, boost, brake).

### Classic Virtual Pad Mode (Optional — Accessibility / Preference)
- When enabled in Settings: Show a traditional on-screen virtual joystick (left side) + dedicated buttons for Primary Fire, Secondary, Special, Shields, Boost, Brake, Self-Destruct.
- This mode should feel exactly like the current prototype but polished.
- The same underlying `InputManager` protocol feeds both modes into the `Ship` class so game logic never duplicates.

### What NOT to Use for Core Controls
- Accelerometer or back-tap gestures for core gameplay → **explicitly rejected**.
- Do not make gesture mode the *only* option.

**Tell Claude**: "Implement BOTH control styles with a Settings toggle (UserDefaults). Default = Modern Gesture (left drag for steering/thrust, single-tap primary, long-press secondary, two-finger/swipe-up special, bottom-edge swipes for shields/boost/brake). Classic mode = visible virtual joystick + buttons. Both modes must feed the exact same Ship movement/weapon methods. Prioritize single-tap reliability. Add strong haptics and particles. Make controls feel as fluid as a PS5 controller at 60 fps."

---

## 4. Apple TV + Game Controller Support (Universal App — One Codebase)

**Decision**: Do **not** create a separate tvOS app. Make it a **single universal Xcode project** with both iOS and tvOS targets. Share the vast majority of game logic. The game must feel excellent when played with a physical game controller on Apple TV, iPhone, or Mac.

### Supported Controllers (Non-Negotiable)
- **Sony PlayStation 5 DualSense** (primary reference)
- **Xbox Series X/S** controller (and Xbox One)
- Any other MFi or GameController framework compatible controller must also work via sensible defaults.

### Full Button Mapping — Use Every Button Purposefully
Map **every button** on the controller so nothing feels wasted. The goal is a rich, controller-native experience that feels like a premium console game.

**Recommended Baseline Mapping (PS5 DualSense → Xbox equivalent)**:

| PS5 Button       | Xbox Equivalent     | Function                                      | Notes / Rationale |
|------------------|---------------------|-----------------------------------------------|-------------------|
| **Left Stick**   | Left Stick          | Rotate ship (horizontal) + Thrust (vertical) | Core movement. Push up = forward thrust, down = reverse/brake. |
| **D-Pad**        | D-Pad               | Alternative rotate / thrust (or menu nav)    | Useful fallback or for precise small adjustments. |
| **X (Cross)**    | **A**               | **Primary Weapon** (auto-repeat while held)  | Most used action — largest, easiest button. |
| **Square**       | **X**               | **Secondary Weapon**                         | Natural "next" weapon. |
| **Triangle**     | **Y**               | **Special / Ultimate Weapon**                | Big ability button. |
| **Circle**       | **B**               | **Self-Destruct** (with confirmation prompt) | High-risk tactical button. |
| **R1**           | **RB**              | **Raise Shields**                            | Quick defensive toggle (replaces bottom-edge swipe). |
| **R2**           | **RT**              | **Speed Boost / Afterburner** (hold)         | Replaces right-edge swipe. Strong haptic + visual trail. |
| **L1**           | **LB**              | **Lower Shields / Vent Heat**                | Defensive counterpart to R1. |
| **L2**           | **LT**              | **Brake / Reverse Thrust** (hold)            | Precise braking without using left stick down. |
| **Options / Menu** | **Menu / Start**  | Pause / Ship Selection / Match End           | Standard system button. |
| **Create / Share** | **View / Back**   | Quick Stats / Compendium shortcut            | Or toggle mini-radar if desired. |
| **Touch Pad**    | —                   | Pause or open Settings (light press)         | DualSense-specific bonus. |
| **PS / Xbox Home** | Home button      | System dashboard (do not override)           | Leave for system use. |

**Implementation Notes for Claude**:
- Use `GCController` + `GCExtendedGamepad` for standardized input across PS5 and Xbox.
- Create a clean `InputManager` / `ControllerInput` class that translates physical button presses into the same `firePrimary()`, `activateSpecial()`, `setShields(enabled:)`, `applyBoost()`, etc. methods used by touch controls.
- Support **button hold** vs **button press** semantics (e.g., R2 held = continuous boost).
- Provide **strong haptic feedback** on DualSense (adaptive triggers if possible for R2 boost feel, though keep it simple for broad compatibility).
- On Apple TV, the game should **auto-detect** a connected controller and switch to controller input mode seamlessly. Touch should still be supported if someone uses the Siri Remote or taps the screen.

### Premium Feature: In-Game Controller Button Mapping Screen
This is a **high-value polish feature** that makes the game feel premium and console-like.

**Requirement**:
- Add a dedicated screen (accessible from Settings or Pause menu) titled **"Controller Layout"** or **"Button Mapping"**.
- Show a **clear, high-quality illustration** of a PS5 DualSense controller (and optionally an Xbox controller).
- Overlay **text labels and icons** on or next to every button showing exactly what it does in this game.
- Example labels:
  - "X = Primary Fire"
  - "R2 (Hold) = Speed Boost"
  - "R1 = Raise Shields"
  - "Circle / B = Self-Destruct"
- Use simple, clean typography and subtle glow/highlight on the active/pressed button for teaching moments.
- Make the screen beautiful — this single screen significantly increases perceived production value and helps players learn the rich control scheme quickly.
- On first controller connection (or first Apple TV launch), optionally show this screen automatically with a "Got it" button.

**Art Direction**: Use a clean vector-style controller image (you can source a royalty-free line drawing or create a simple one). Keep it minimal and readable on a TV screen.

### SpriteKit Scaling & Viewport
- iPhone: Large arena (4×–6× visible screen) with camera that follows the player ship.
- Apple TV: Entire arena fits on screen at once; ships and projectiles scale appropriately. Minimal or static camera.
- Use responsive design so the same scene works on both without heavy branching.

**Result**: One app binary that delivers a true premium console-like experience on Apple TV while remaining excellent on iPhone (touch or controller) and Mac.

**Tell Claude**: "Add a tvOS target. Integrate the GameController framework with full support for PS5 DualSense and Xbox controllers. Implement the exact button mapping table above using GCExtendedGamepad. Create a beautiful in-game 'Controller Layout' screen that displays a controller illustration with all button functions clearly labeled. Make R1/R2/L1/L2 map to the shield/boost/brake/self-destruct actions that were previously edge swipes on touch. Ensure the same InputManager abstraction works for touch, classic virtual pad, and all supported game controllers. The game must feel native and rich on a big TV screen."

---

## 5. macOS Support (Mac Catalyst — Same Xcode Project)

**Decision**: Do **not** create a separate macOS game. Include **Mac Catalyst** support in the **same universal Xcode project**. This gives maximum code reuse with minimal effort.

### Why Mac Catalyst?
- SpriteKit games work extremely well via Mac Catalyst.
- One codebase, one set of assets, one IAP catalog, one Game Center integration.
- Players can play with mouse (treats as touch) or connect a game controller (same mapping as Apple TV).
- Optional: Add simple keyboard shortcuts for Mac (arrow keys or WASD for thrust/rotate, space for primary, etc.).
- Distribution: Same App Store listing (universal purchase) or Mac App Store if desired later.

### Implementation Steps for Claude
1. In Xcode project settings, enable **Mac Catalyst** for the iOS target (or create a Mac Catalyst target pointing to the same code).
2. Use `#if targetEnvironment(macCatalyst)` or `ProcessInfo.processInfo.isMacCatalystApp` for any Mac-specific tweaks (e.g., larger default window size, menu bar items, or mouse cursor visibility).
3. **Premium macOS Polish**:
   - Support window resizing with reasonable min/max sizes; maintain aspect ratio or letterbox the game view nicely.
   - Add a minimal Mac menu bar (Game → New Match, Pause, Ship Compendium, Settings, Quit) using `NSMenu` or SwiftUI `Commands`.
   - Keyboard support: Map WASD / Arrow keys to thrust/rotate, Space = primary, Shift = secondary, Cmd/Ctrl keys for specials. Make it feel native.
   - Mouse: Left-click in movement zone or direct ship toward mouse cursor (hybrid mode). Right-click or modifier for secondary.
   - Hide mouse cursor during active gameplay (show on pause/menu). Use `NSCursor.hide()` / `unhide()`.
   - On Mac, the larger screen allows showing more of the arena or a less aggressive camera follow — make this tunable per platform.
4. Camera / Viewport: On Mac the arena can be shown at a comfortable zoom level (entire arena visible or slight camera follow). Test on Mac.
5. Test thoroughly on a real Mac (especially M-series) for performance and input feel.

**Result**: One project builds for iPhone, iPad, Apple TV, **and Mac** with a truly premium desktop experience. This significantly increases your addressable audience with almost zero extra maintenance.

**Tell Claude**: "Add Mac Catalyst support to the existing universal project with premium desktop polish: window resizing with aspect handling, minimal native menu bar, full keyboard mapping (WASD/arrows + shortcuts), smart mouse cursor show/hide, and hybrid mouse input. Ensure the game builds and runs cleanly on Mac with excellent performance on M-series. Adapt input so mouse/keyboard works naturally via the InputManager abstraction. Make only minimal platform-specific adjustments. The goal is maximum code sharing across iOS, tvOS, and macOS while feeling native on desktop."

---

## 5.5. Settings Menu, Accessibility & Debug / Fun Modifiers

**Philosophy**: A clean, well-organized Settings screen is essential for a premium feel. It should feel native, respect system conventions (Dynamic Type, Reduce Motion, etc.), and give players meaningful control. For a single-player vs AI game like this, **optional "Fun Modifiers" or "Debug Cheats"** can significantly increase replayability and joy, especially for players who want to experiment with broken or overpowered ships.

### Core Settings (Must-Have for v1)
- **Control Style**: Modern Gesture (default) / Classic Virtual Pad
- **Haptics**: On / Off (respect "Reduce Haptics" system setting)
- **Audio**: Master volume, SFX volume, Music volume, Mute toggle
- **Mini-Radar**: On / Off (default Off for immersion)
- **Screen Shake**: On / Off (default On; respect Reduce Motion)
- **Auto-Update Reminder**: On / Off
- **Game Center**: Sign in status + "View Leaderboards" button
- **Controller Layout**: Button to open the beautiful controller mapping screen (especially useful on Apple TV / Mac)

### Fun Modifiers / Debug Cheats Section (Highly Recommended)
Create a clearly labeled section in Settings called **"Fun Modifiers"** or **"Experimental Options"** (visible to all players — these are single-player only and do not affect online leaderboards or achievements).

**Recommended Modifiers** (all toggleable, persist via UserDefaults, reset on new match or app restart for fairness):

- **Zero Gravity Damage** — Ships take no damage when colliding with the "edge" of the arena or from high-speed wrapping impacts (removes frustration from accidental high-speed crashes).
- **Unlimited Battery / Energy** — Weapons and abilities have no cooldown or energy cost.
- **Invincibility** — Player ship cannot take damage (great for learning new ships or just having fun).
- **Unlimited Special Weapons** — Special / Ultimate ability has zero cooldown.
- **Unlimited Speed Boost** — Boost can be held indefinitely with no energy drain or overheat.
- **Infinite Power-Ups** — Power-ups spawn much more frequently or never despawn.
- **No Ship Inertia** (optional advanced) — Toggle true space inertia off for a more "arcade" feel.
- **Enemy AI Difficulty** — Easy / Normal / Hard / Insane (affects how aggressive/smart the AI is).

**Implementation Guidance for Claude**:
- Store all modifiers in a simple `GameModifiers` struct or `UserDefaults` keys.
- Apply the modifiers inside `Ship`, `Projectile`, and `GameScene` update/collision logic with clean `if GameModifiers.shared.unlimitedEnergy { ... }` guards.
- **Important**: These modifiers must **never** affect Game Center score submission or achievements. When any modifier is active, either disable leaderboard submission for that match or clearly mark the run as "Modified".
- Make the UI beautiful — use `SwiftUI` or a polished `SKScene` overlay with clear toggle switches and a short description under each option.
- Add a big "Reset All Modifiers" button at the bottom of the section.
- On the Results screen, show a small "Modifiers Active" badge if any fun modifiers were used (so players don't accidentally submit modified scores).

**Accessibility Basics (Non-Negotiable for Premium Polish)**
- Full VoiceOver support on all menus and HUD elements.
- Respect **Dynamic Type** for all text.
- Respect **Reduce Motion** (disable screen shake, reduce particle intensity, simplify transitions).
- Colorblind-friendly palettes or optional high-contrast mode.
- Clear, high-contrast text and icons.

**Tell Claude**: "Create a polished Settings screen (preferably using SwiftUI for native feel, presented modally from SpriteKit). Include all core toggles listed above plus a clearly separated 'Fun Modifiers' section with the exact options requested: Zero Gravity Damage, Unlimited Battery, Invincibility, Unlimited Special Weapons, Unlimited Speed Boost, and at least two more logical ones. All modifiers must be easy to toggle, clearly described, and must not corrupt Game Center scores. Add a beautiful Controller Layout screen accessible from Settings."

---

## 6. Weapons, Power-Ups, Self-Destruct & Ship Systems

- **Weapons**: Implement as separate node classes (`Projectile`, `Beam`, `HomingMissile`, etc.) spawned by the `Ship` class. Different ships have different stats (damage, speed, fire rate, spread, homing strength, etc.).
- **Power-Ups**:
  - Spawn on a timer or after certain events at random locations inside the world bounds.
  - Drift slowly or stay mostly stationary.
  - On collision with player ship → auto-collect (no extra tap needed).
  - Apply temporary buff (speed multiplier, temporary extra health layer, cloaking = alpha + dodge chance, weapon overcharge, etc.).
  - Show clear HUD icon + countdown timer while active.
- **Self-Destruct**:
  - Big explosion (SKEmitterNode + screen shake + satisfying sound).
  - Area damage to enemy if within range.
  - Ends the current match (win/loss depending on whether it took the enemy with it).
- **Energy / Cooldowns**: Simple per-weapon timers or a shared energy pool (whichever fits the ship design). Show on HUD.
- **Shields**: Raise/lower via edge swipe. Affects damage absorption and possibly heat/venting mechanics.

---

## 6. Technical Recommendations (SpriteKit)

**Primary Framework**: SpriteKit (`SKScene`, `SKSpriteNode`, `SKPhysicsBody`, `SKCameraNode`, `SKEmitterNode`, `SKAction`).

**Physics Strategy** (True Space Inertia):
- Give ships `SKPhysicsBody` with `friction = 0`, `linearDamping = 0`, `angularDamping = 0.05` (or very low) for true space inertia.
- For **tight player control**, use a **hybrid** movement model: calculate desired velocity/rotation from input every frame, then either set `physicsBody.velocity` directly or apply impulses/forces. Pure `applyForce` can feel too floaty; test both approaches.
- Projectiles and power-ups can use lighter physics or direct position updates.

**Performance**: With only two ships + limited projectiles/power-ups, even a 3000×3000 world is trivial. Use texture atlases, `ignoresSiblingOrder = true`, and recycle nodes where possible.

**Recommended Code Structure**:
- `GameScene.swift` — input routing, update loop, wrapping logic, camera follow, collision handling, power-up spawning.
- `Ship.swift` (or `PlayerShip` / `EnemyShip` subclasses) — stats, health, weapon cooldowns, `applyThrust()`, `firePrimary()`, `activateSpecial()`, `selfDestruct()`, shield state.
- `Projectile.swift`, `PowerUp.swift` — lightweight node classes.
- `InputManager.swift` or protocol extensions — touch vs gamepad abstraction layer.
- HUD as a separate high-zPosition node or SKScene overlay that doesn't move with the camera.
- `ShipData.swift` or JSON config — data-driven ship definitions for easy expansion packs.

**State Management**: Simple enum or `GKStateMachine` for Menu → Ship Selection → Battle → Results.

**3D Compendium / Ship Viewer** (Premium Polish Feature for v1 or v1.1):
- Separate screen or modal.
- Use SceneKit (`SCNScene` + `SCNNode`) or Model I/O to load 3D ship models.
- Allow player to rotate the model with drag/pinch gestures for detail view.
- Keep actual gameplay strictly 2D top-down for performance and classic feel.
- This adds significant "premium" appeal and helps justify expansion pack purchases.

---

## 6.5. Visual Polish, Particles, Juice & Screen Effects (Critical for Premium Feel)

**Philosophy**: In a premium iOS game, **every single player action must deliver satisfying multi-sensory feedback** (visual + audio + haptic). This "juice" is what makes controls feel alive and responsive, and is often what separates good indie games from great ones that players remember and share. Star Control's melee is fast and kinetic — lean into that with generous, context-aware effects.

### Must-Have Juice Elements for v1
- **Thrust / Acceleration**: 
  - Dynamic flame / plasma trail particles that scale in size, intensity, and particle count with thrust input.
  - Subtle screen-edge glow or vignette that intensifies at high speed.
  - Low-frequency camera bob or inertia feel when thrusting hard.

- **Weapon Fire & Impacts**:
  - Muzzle flash (bright sprite scale-up + quick fade, or small emitter) on every shot.
  - Distinct impact effects on ship hit (small spark/debris emitter + brief ship color flash to red/orange).
  - Screen shake intensity scaled to damage dealt (light for primary, heavy for special/self-destruct).
  - Optional: Very brief time-dilation / slow-motion on heavy hits or self-destruct for dramatic weight (0.3–0.6s at 0.3× speed).

- **Explosions & Self-Destruct**:
  - Layered `SKEmitterNode`: Core bright flash → expanding debris → lingering smoke/dust.
  - Strong camera shake + white screen flash that fades (use `SKAction` colorize or overlay node).
  - Heavy haptic + deep explosion sound.
  - Area damage visual ring or shockwave sprite.

- **Power-Up Pickup & Activation**:
  - Satisfying "pop" animation (scale from 0.6 → 1.2 → 1.0 with bounce easing).
  - Sparkle / glitter emitter burst.
  - Clear HUD icon appears with countdown timer + distinct pickup sound + success haptic.

- **Damage / Low Health State**:
  - Persistent light smoke emitter when health < 30%.
  - Subtle screen red vignette or damage overlay that pulses with health.
  - Ship sprite can have multiple visual states (clean → cracked → heavily damaged) if art budget allows, or simple color + particle overlay.

- **Wrapping / High-Speed Moments**:
  - Subtle chromatic or motion-blur style overlay when wrapping at high velocity (can be faked with semi-transparent stretched sprites or shader if using Metal).

### Implementation Recommendations
- **Preload emitters**: Create reusable `.sks` particle files in Xcode and load them once at app start or scene load. Never create emitters on-the-fly in the hot path.
- **ParticleManager singleton or extension**: Helper methods like `spawnExplosion(at:damage:)`, `playThrustEffect(onShip:thrustAmount:)`.
- **Camera shake helper** (add to `GameScene` or camera extension):
  ```swift
  func shakeCamera(duration: TimeInterval = 0.25, intensity: CGFloat = 10.0) {
      guard let camera = camera else { return }
      let originalPos = camera.position
      let shakeAction = SKAction.sequence([
          SKAction.moveBy(x: intensity, y: intensity * 0.5, duration: 0.04),
          SKAction.moveBy(x: -intensity * 1.5, y: -intensity, duration: 0.04),
          SKAction.moveBy(x: intensity * 0.8, y: intensity * 1.2, duration: 0.04),
          SKAction.move(to: originalPos, duration: 0.04)
      ])
      camera.run(shakeAction)
  }
  ```
- **120Hz / ProMotion support**: Set `self.view?.preferredFramesPerSecond = 120` on devices that support it (check `UIScreen.main.maximumFramesPerSecond`). All `SKAction` durations and physics will feel snappier.
- **Performance guardrails**: Limit simultaneous emitters. On older devices, reduce particle birth rates or disable some secondary effects via a simple quality setting.
- **Starfield / Background Polish** (High visual impact, low cost):
  - 2–3 parallax layers of stars (far slow, near faster) that move opposite to camera/ship velocity for depth.
  - Subtle animated nebulae or dust clouds (low alpha, slow drift).
  - This makes the larger toroidal arena feel alive and premium without performance cost.

**Result**: The game will feel responsive, weighty, and cinematic even on a small iPhone screen. Players will naturally want to share clips because every moment looks and feels satisfying.

---

## 7. Asset Resources (All CC0 / Commercial-Safe for Monetized Apps)

### Music & Sound Effects (Premium Retro / Epic Sci-Fi Feel)

**Top Recommended Sources** (All verified safe for commercial/monetized App Store use as of 2026 — always double-check the license file inside each downloaded pack):

**Music (Looping Background Tracks — Epic / Atmospheric / Retro Synth):**
- **alkakrab on itch.io** (Strongly Recommended)
  - Free Sci-Fi Game Music Pack (Vol. 1, 2, and Vol. 3 available)
  - 6–8+ tracks per pack + loops
  - Explicitly "Absolutely Free For Commercial use"
  - Perfect epic/atmospheric sci-fi loops for menu and battle
  - Download: https://alkakrab.itch.io/free-sci-fi-game-music-pack (and search their profile for Vol. 2 / Vol. 3)
- **White Bat Audio – Free Horror/Sci-Fi Music Pack**
  - 27 high-quality retro synth tracks
  - 100% royalty-free for games
  - **Requires credit** in your app: "Music by Karl Casey @ White Bat Audio" (add a small Audio Credits section in Settings or pause menu)
  - Excellent dark, premium, cinematic feel
  - https://whitebataudio.com/product/free-horror-sci-fi-music-pack/
- **OpenGameArt.org** — Search “sci-fi music”, “space ambient”, or “retro synth”. Many CC0 looping tracks available.
- **99Sounds.org** — InterSpace and other free sci-fi atmosphere packs (royalty-free for commercial projects).

**Sound Effects (Lasers, Explosions, Thrust, Impacts, Power-ups, Shields, etc.):**
- **Kenney.nl/assets → Sci-fi Sounds** (Best Overall Starting Point)
  - CC0 / Public Domain (no attribution required)
  - Consistent, high-quality retro sci-fi effects: lasers, explosions, engine hums, impacts, beeps
  - Download the full pack: https://kenney.nl/assets/sci-fi-sounds
- **OpenGameArt.org**
  - “Sci-Fi Sound Effects Library” (large collection)
  - “60 CC0 Sci-Fi SFX”, “50 CC0 Sci-Fi SFX”, “Sci-fi Sounds” by Kenney
  - Many individual weapon/explosion packs under CC0
- **99Sounds.org** — Free Sci-Fi Sounds pack (90 royalty-free sounds including weapons, whooshes, impacts, and atmospheres)

**Implementation Best Practices (Tell Claude to follow these):**
- Convert all audio files to `.caf` or `.m4a` format for best iOS performance and smallest size (use Terminal `afconvert` or free online converters).
- Create a dedicated `AudioManager` class (or singleton) that handles:
  - Preloading all one-shot sounds in `didMove(to:)` or on app launch
  - `playSound(named:)` using `SKAction.playSoundFileNamed`
  - Looping background music via `SKAudioNode` with fade in/out
  - Volume control and mute toggle (respect player settings)
- Use light/medium/heavy haptics to complement audio (not replace it).
- One music track for menu, one (or more) for battle. Cross-fade when transitioning.
- Preload everything — never load sounds during active gameplay.
- Test audio thoroughly on a real iPhone (Simulator audio behavior is unreliable).

**Strict Licensing Rules:**
- Prefer **CC0 / Public Domain** packs whenever possible (no attribution needed).
- For packs that require credit (e.g. White Bat Audio), add a clean “Audio Credits” line in the Settings screen or pause menu.
- **Never** use any music or sound effect that does not explicitly allow commercial use in a monetized app. This includes ripped tracks (e.g. Hans Zimmer’s “No Time for Caution” from Interstellar) — they will cause App Store rejection or takedown.

### 2D Ship Designs
- **Kenney.nl/assets** — Spaceship Pack, Space Kit (polished pixel art, perfect starting point).
- **OpenGameArt.org** — "Spaceship Assets" section (hundreds of sprites, vectors, and animated ships).

**Workflow**: Download packs → import into Assets.xcassets → tint or modify colors slightly per ship for uniqueness → add glows/particles in SpriteKit.

### 3D Ship Models (for Compendium Viewer)
- **Sketchfab.com** — Filter for "sci-fi spaceship", sort by "Free", and check license (many CC0 or Public Domain / CC-BY suitable for commercial use).
- Convert or simplify models as needed for performance in SceneKit.
- Alternative: Use Kenney/OpenGameArt if any 3D assets appear, or create simple extruded 2.5D models.

**Tell Claude**: "Download music and sound effects from the specific sources and packs listed in Section 7 (alkakrab itch.io packs, White Bat Audio free pack, Kenney Sci-fi Sounds, OpenGameArt CC0 packs). Convert files to .caf/.m4a. Implement a clean AudioManager class with preloading, playSound(named:), and looping SKAudioNode music with fade support. For ship art, use Kenney + OpenGameArt 2D sprites (tint per ship) and optional Sketchfab 3D models for the compendium viewer only. Create a data-driven system (JSON or Swift structs) so new ships from expansion packs can be added with minimal code changes. Add an 'Audio Credits' section in Settings if using any packs that require attribution."

---

## 8. Monetization Strategy (Recommended for Indie Success)

**Primary Model**: Freemium on the regular App Store (**NOT** Apple Arcade).

**Why Freemium Wins**:
- Free downloads maximize App Store visibility and organic traffic (critical for an indie with no existing audience or viral marketing budget).
- Ship expansion packs ($2.99 each) target engaged players ("whales") and create ongoing revenue.
- Comparable successful title: Galaxy Attack: Alien Shooter earns hundreds of thousands monthly via similar ship/IAP model.

**Recommended IAP Structure**:
- Core game completely free.
- Themed ship packs at $2.99 (4–6 ships each).
- Optional one-time "Remove Ads + Bonus Starting Credits" pack (~$4.99–$6.99).
- No paid upfront version — it limits discovery in this genre.

**Advertising (Secondary Revenue Stream)**:
- Integrate AdMob or AppLovin MAX.
- **Rewarded video ads only**: After a loss, offer "Watch ad to revive / try again".
- Non-intrusive and player-optional.
- With low early downloads (<100/month), ads will be modest ($5–20/month initially) but help build habits.
- Even 5–10% IAP conversion on 100 downloads beats ad revenue significantly.

**Apple Arcade Consideration**:
- Do **not** launch on Apple Arcade initially.
- Arcade prohibits IAPs and offers lower per-play payouts for most indies.
- Launch on the open App Store for full monetization control and better long-term upside.

**Marketing Reality Check (Indie Context)**:
- As an independent developer with one existing app and no large following, organic discovery via App Store search (ASO) + TikTok/YouTube Shorts is key.
- Create 15-second ship battle clips highlighting unique ship abilities and the "every ship has a chance" balance philosophy.
- Post devlogs on r/indiegaming, r/iosgaming, and relevant retro gaming communities.
- Target keywords: "Star Control", "retro space melee", "sci-fi ship battle", "Star Control clone".

**Tell Claude**: "Implement a clean IAP + rewarded ad system from the start. Make ship data configurable so new packs can be added easily. Prioritize balance so players feel the expansion ships are worth buying."

---

## 9. Game Center Integration (Leaderboards, Achievements & Social Features)

**Why Add Game Center?**
Game Center is free, requires no backend servers, and adds long-term engagement even in a primarily single-player vs AI game. Global leaderboards for wins and win streaks give players a reason to keep playing and improving. It also provides built-in social proof and bragging rights that help with organic sharing.

**Step 1: App Store Connect Setup (Do This Before Coding)**
1. Go to App Store Connect → Your App → **Features** tab → **Game Center** → Enable Game Center.
2. Create **Leaderboards** (these are the IDs you will hard-code):
   - **Total Wins**  
     Leaderboard ID: `com.dje.starcontrol.wins` (or your reverse-domain equivalent)  
     Type: Integer | Sort Order: Descending | Score Format: Integer
   - **Longest Win Streak**  
     Leaderboard ID: `com.dje.starcontrol.win_streak`  
     Type: Integer | Sort Order: Descending | Score Format: Integer
   - (Optional for v1.1) Fastest Victory Time or Wins with Specific Ship archetypes.
3. Create a few **Achievements** (recommended for v1 or v1.1):
   - "First Blood" — Win your first match
   - "On a Roll" — Achieve a 5-win streak
   - "Ship Master" — Win at least once with every core ship
   - "Untouchable" — Win a match without taking damage (stretch)
4. Note the exact Leaderboard IDs and Achievement IDs — they become constants in code.
5. Test with a sandbox Game Center account (different from your production Apple ID).

**Step 2: Recommended Architecture — `GameCenterManager`**
Create a lightweight singleton or observable class `GameCenterManager.swift` that encapsulates all Game Center logic. This keeps `GameScene` and UI code clean.

Key responsibilities:
- Authenticate the local player early (on app launch or first menu load).
- Provide a simple API: `submitWin()`, `submitWinStreak(_ value: Int)`, `showLeaderboards()`.
- Handle authentication state and gracefully degrade if the player declines Game Center or is offline.

**Key Code Patterns (Feed These to Claude)**

Authentication (call once early, e.g. in `AppDelegate` or first `MenuScene`):
```swift
import GameKit

final class GameCenterManager {
    static let shared = GameCenterManager()
    private init() {}

    var isAuthenticated: Bool { GKLocalPlayer.local.isAuthenticated }

    func authenticate(completion: ((Bool) -> Void)? = nil) {
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            if let vc = viewController {
                // Present the Game Center login UI from your root view controller
                // Store a reference or use a delegate pattern
                completion?(false)
            } else if error == nil {
                completion?(true)
            } else {
                // Player declined or error — still allow full gameplay
                completion?(false)
            }
        }
    }
}
```

Submit score after a match ends (call from Results screen or `GameScene` when match concludes):
```swift
func reportWin() {
    guard isAuthenticated else { return }
    // You must maintain the player's total wins count locally (UserDefaults or a simple persistent store)
    let newTotalWins = UserDefaults.standard.integer(forKey: "totalWins") + 1
    UserDefaults.standard.set(newTotalWins, forKey: "totalWins")

    GKLeaderboard.submitScore(newTotalWins,
                              context: 0,
                              player: GKLocalPlayer.local,
                              leaderboardIDs: ["com.dje.starcontrol.wins"]) { error in
        if let error = error {
            print("Game Center submit error: \(error.localizedDescription)")
        }
    }
}

func reportWinStreak(_ currentStreak: Int) {
    guard isAuthenticated else { return }
    // Only submit if this is a new personal best
    let bestStreak = UserDefaults.standard.integer(forKey: "bestWinStreak")
    if currentStreak > bestStreak {
        UserDefaults.standard.set(currentStreak, forKey: "bestWinStreak")
        GKLeaderboard.submitScore(currentStreak,
                                  context: 0,
                                  player: GKLocalPlayer.local,
                                  leaderboardIDs: ["com.dje.starcontrol.win_streak"]) { _ in }
    }
}
```

Display leaderboards (call from a "Game Center" or "Leaderboards" button in the main menu):
```swift
func showLeaderboards(from viewController: UIViewController) {
    guard isAuthenticated else {
        // Optionally show an alert: "Sign in to Game Center in Settings to compete on leaderboards"
        return
    }
    let leaderboardVC = GKGameCenterViewController(leaderboardID: "com.dje.starcontrol.wins",
                                                   playerScope: .global,
                                                   timeScope: .allTime)
    leaderboardVC.gameCenterDelegate = /* your delegate that dismisses the VC */
    viewController.present(leaderboardVC, animated: true)
}
```

**Win Streak Tracking Logic (Simple State Machine)**
- Maintain `currentWinStreak` in memory during a play session.
- On match **win** → `currentWinStreak += 1`; call `reportWinStreak(currentWinStreak)` and `reportWin()`.
- On match **loss** → `currentWinStreak = 0`.
- Persist the best streak across launches via UserDefaults.

**Best Practices & Player Experience**
- **Never block gameplay** if Game Center authentication fails or the player is not signed in. The game must remain fully playable.
- Submit scores **only after** the match results screen is shown (not during gameplay).
- Use `context` parameter if you later want to attach ship ID or other metadata.
- Add a prominent but optional "Game Center" button in the main menu and/or pause menu.
- Respect the player's choice: if they decline Game Center, never nag them again in that session.
- For achievements, use `GKAchievement.report(_:)` similarly — report progress incrementally.

**Optional Mini-Radar**
Toggleable in Settings — small corner SKNode overlay with enemy blips. Implement as a lightweight node that reads enemy positions relative to player. Many players will prefer it off for pure immersion; default = off.

**v1 Must-Have Features**:
- Versus mode vs strong AI with varied tactics per ship.
- Exactly 8 balanced core ships (free).
- BOTH control styles: Modern Gesture (default) + Classic Virtual Pad (Settings toggle).
- Full game controller support (PS5 DualSense + Xbox) with rich button mapping on Apple TV, iPhone, and Mac.
- Beautiful in-game "Controller Layout" screen showing controller illustration with all button functions labeled.
- Game Center leaderboards for Total Wins + Longest Win Streak + simple achievements.
- StoreKit 2 + dynamic ship unlocking ready for expansion packs.
- VersionCheckManager with polite update reminder.
- Polished Settings screen with core toggles + "Fun Modifiers" section (Zero Gravity Damage, Unlimited Battery, Invincibility, Unlimited Specials, Unlimited Boost, etc.).
- Ship compendium (2D + optional 3D rotatable SceneKit viewer).
- Strong juice: particles, screen shake, haptics, impact sounds.
- Quick match pacing (most games 10–30 seconds).
- Universal app: iOS + tvOS + Mac Catalyst.

**v1.1+ Nice-to-Haves**:
- Daily login rewards / challenges.
- Endless survival mode.
- Shareable victory replays (TikTok gold).
- More expansion packs with new themed ships.
- Optional online PvP (only if the core game proves popular — adds server cost & complexity).

---

## 9.5. App Version Update Reminder (Reusable Feature for All Your Apps)

**Requirement**: The game must periodically check whether a newer version is available on the App Store and gently remind the player to update.

### Recommended Lightweight Implementation (No Backend Required)
Use Apple's public iTunes Search API (free, no key needed):

1. On app launch (or in Settings, or once per day via a simple timer/UserDefaults last-checked date):
   - Make a `URLSession` GET request to:
     ```
     https://itunes.apple.com/lookup?id=YOUR_APPLE_ID&country=US
     ```
   - Parse the JSON. The relevant field is `results[0].version` (string, e.g. "1.2.0").

2. Compare it to the currently running version:
   ```swift
   let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
   ```

3. If the App Store version is newer (use semantic version comparison helper), show a non-intrusive UIAlertController or a custom banner:
   - "A new version of [Game Name] is available. Update now for the latest ships and improvements?"
   - Buttons: "Update" (opens App Store page via `SKStoreProductViewController` or `UIApplication.shared.open`) and "Later".

4. **Important Polish**:
   - Only remind once per version (store the last reminded version in UserDefaults).
   - Never block gameplay.
   - Make the check asynchronous and silent on failure.
   - Respect "Do Not Disturb" or low-power mode if possible (simple implementation is fine).

### Reusable Component Recommendation
Create a small `VersionCheckManager` singleton or actor that can be dropped into **all** your future apps with only two lines of configuration (Apple ID + app name). This fulfills the user's request to have this feature everywhere.

**Tell Claude**: "Implement a VersionCheckManager that queries the iTunes lookup API on launch (or daily). If a newer version exists, show a polite non-blocking update prompt that opens the App Store page. Store the last checked version so it only reminds once per new release. Make the manager easy to reuse in other projects."

## 10. Ready-to-Use Prompts for Claude Code

Copy and paste these (plus relevant sections of this spec) when working with Claude:

**Touch Controls Implementation Prompt**:
```
Implement the exact unified gesture mapping from the Star Control iOS Game Development Guide for the iPhone version. 
Left half: one-finger drag/pan controls ship rotation (horizontal) + thrust (vertical up, with intensity). 
Right half: single tap/hold = primary (repeat), swipe up = secondary, double-tap/long-press = special, triple-tap or swipe-down = self-destruct. 
Bottom edge: swipe up = raise shields, swipe down = lower shields, swipe left = brake/reverse, swipe right = boost. 
Use UIGestureRecognizers or precise multi-touch tracking for reliability. 
Add strong haptic feedback on all actions. 
Remove the old on-screen D-pad and buttons from the prototype. 
Make the controls feel as fluid and precise as a PS5 controller. Prioritize 60 fps responsiveness and forgiveness in fast combat.
```

**Playing Field + Camera + Wrapping Prompt**:
```
Expand the arena to 5× screen size (e.g. 2400×2400 or 3000×3000 points) with full toroidal wrapping using modulo position logic on all moving entities. 
Add an SKCameraNode that follows the player ship with smooth lerp lag (followSpeed ~0.08 for inertia feel). 
Ensure wrapping works seamlessly for player, enemy, projectiles, and power-ups. 
Update camera logic so it handles wrapping without visual seams. 
Test that acceleration now feels powerful and strategic instead of cramped.
```

**Apple TV / Gamepad + Full Controller Support Prompt**:
```
Add a tvOS target to the Xcode project. Integrate the GameController framework with full support for PS5 DualSense and Xbox Series controllers.
Implement the exact button mapping from Section 4 of the guide:
- X/A = Primary Weapon
- Square/X = Secondary Weapon  
- Triangle/Y = Special Weapon
- Circle/B = Self-Destruct
- R1/RB = Raise Shields
- R2/RT (hold) = Speed Boost
- L1/LB = Lower Shields
- L2/LT (hold) = Brake
Create a beautiful in-game "Controller Layout" screen that shows a clear illustration of a PS5 controller (and optionally Xbox) with every button clearly labeled with its in-game function. This screen must look premium and be accessible from Settings and the pause menu.
Use GCExtendedGamepad for cross-controller compatibility. Ensure the InputManager abstraction works seamlessly for touch, classic virtual pad, and all game controllers. The game must feel rich and native on Apple TV.
```

**General Refactor / Architecture Prompt**:
```
Refactor the current prototype to follow the full architecture and control scheme in the Star Control iOS Game Development Guide (v3.0). 
Focus first on making touch controls feel premium: implement BOTH Modern Gesture mode (default) and Classic Virtual Pad mode with a Settings toggle. 
Then expand the playing field with wrapping and camera follow. 
Implement hybrid physics movement for tight control + true inertia. 
Keep existing ship physics and weapon systems but integrate them into the new input model. 
Add strong haptic, particle, and screen shake feedback for juiciness. 
Make ship definitions data-driven (JSON/structs + unlock status) so expansion packs can be added cleanly via StoreKit.
```

**StoreKit + Dynamic Ship Pack Unlocking Prompt**:
```
Implement StoreKit 2 for ship expansion packs. Create a central ShipRegistry that loads all ships from config/JSON. Each ship or pack has an unlock status persisted via UserDefaults. When a pack is purchased, immediately unlock its ships and refresh the ship selection UI. The base game starts with exactly 8 ships. Expansion packs add 4–8 ships each. Never power-creep; every ship must have counters. Show locked ships in the compendium with "Purchase Pack" prompt.
```

**Version Update Reminder Prompt**:
```
Add a VersionCheckManager that queries https://itunes.apple.com/lookup?id=YOUR_APPLE_ID on launch (or daily). Compare the returned version string to Bundle.main CFBundleShortVersionString. If newer, show a non-blocking UIAlertController offering to open the App Store page via SKStoreProductViewController. Only remind once per new version. Make this component clean and reusable for other apps.
```

**Game Center Leaderboards & Achievements Prompt**:
```
Implement full Game Center support following the detailed guidance in section 9 of the Star Control iOS Game Development Guide.
1. Create a clean GameCenterManager singleton that handles authentication, score submission, and presenting GKGameCenterViewController.
2. On App Store Connect, create two leaderboards: "Total Wins" (ID: com.dje.starcontrol.wins) and "Longest Win Streak" (ID: com.dje.starcontrol.win_streak). Use these exact IDs in code (or your own reverse-domain IDs).
3. After every match, call reportWin() and reportWinStreak(currentStreak) — only submit streak when it is a new personal best.
4. Track win streak locally (reset on loss, increment on win). Persist best streak in UserDefaults.
5. Add a "Game Center" / "Leaderboards" button in the main menu that presents the native GKGameCenterViewController.
6. Authenticate early but never block gameplay if the player declines or is offline.
7. (Optional) Add 3–5 simple achievements using GKAchievement.report.
Make all Game Center calls non-blocking and fail silently when appropriate. The game must remain 100% playable without Game Center.
```

**Mac Catalyst Prompt**:
```
Add Mac Catalyst support to the Xcode project so the same codebase runs on Mac. Ensure input (mouse or connected controller) works via the existing InputManager abstraction. Test that the game builds and runs well on Mac with reasonable default window size and optional keyboard shortcuts. Keep platform-specific code minimal.
```

**Premium Visual Polish, Particles & Juice Prompt**:
```
Implement the full visual juice and particle system described in section 6.5 of the Star Control iOS Game Development Guide.
- Create reusable particle effects for thrust (scaling with input), muzzle flashes, layered explosions, impact sparks, power-up pickups (pop + sparkle), and low-health smoke.
- Add a robust camera shake helper that scales intensity with damage/event importance.
- Implement parallax starfield background (2–3 layers) that responds to ship/camera velocity for depth.
- Add brief time-dilation / slow-motion on heavy hits or self-destruct for dramatic weight.
- Support 120Hz on ProMotion devices.
- All effects must feel generous and satisfying without hurting performance. Preload .sks emitters. Create a ParticleManager or helpful extensions.
This is one of the highest-leverage areas for making the game feel premium and shareable.
```

**Onboarding & Tutorial Prompt** (for v1 or immediate post-launch update):
```
Design a gentle, non-blocking onboarding experience for first-time players.
- In the first 1–2 matches, use subtle on-screen hints or a translucent overlay that teaches the modern gesture controls (e.g., "Drag left side to steer & thrust", "Tap right to fire").
- Do not force a long tutorial level. Let players learn by doing with forgiving early AI opponents.
- After the first match, optionally show a one-time "Controls" tip in the results screen or pause menu.
- Respect "Reduce Motion" and provide a way to skip hints.
- Goal: Players feel competent and excited within 60–90 seconds of first launch.
```

---

## Summary for Claude Code

This v4.0 document is the complete, authoritative specification. It includes:

- Precise dual control system (modern gesture default + optional classic virtual pad)
- 8 free ships at launch + 4–8 ship expansion packs via StoreKit with dynamic unlocking
- Universal project: iOS + tvOS + Mac Catalyst (with premium desktop polish: windowing, keyboard, mouse, menu bar)
- Full Game Center leaderboards (Total Wins + Longest Win Streak) + achievements support
- Reusable version update reminder
- Extensive visual juice & particles guidance for premium feel
- Gentle onboarding approach
- Data-driven architecture ready for expansion packs
- Accessibility and performance considerations
- All previous technical details (toroidal arena, camera, physics, assets, etc.)

When working on this project, always refer back to this single file. Prioritize making the Modern Gesture controls feel exceptional — that is the make-or-break feature for player retention and word-of-mouth.

**End of v3.1 Star Control iOS Game Development Guide**

---

## 11. What NOT to Do (Explicit Rejections)

- Do **not** use accelerometer or back-tap gestures for core controls.
- Do **not** keep the old on-screen D-pad + button layout as the final control scheme.
- Do **not** make the playing field only one screen size.
- Do **not** remove toroidal wrapping (it is a core identity feature).
- Do **not** create a completely separate Apple TV app — use universal targets + GameController.
- Do **not** use copyrighted music or direct copies of existing sci-fi ship designs.

---

## 12. Success Metrics, Testing Priority & Development Workflow

**Primary Success Metric**: Controls must feel intuitive, precise, and fun within the first 30 seconds of play. Players should forget they are using touch and feel like they are piloting with a controller.

**Iteration Plan**:
1. Build the new gesture system → test extensively in Simulator + real iPhone (different sizes).
2. Tweak dead zones, sensitivity, haptic strength.
3. Then expand arena + camera + wrapping.
4. Once controls are solid, tune individual ship stats so each has clear strengths/weaknesses.
5. Add polish: screen shake, thrust particles, weapon VFX, satisfying explosion on self-destruct, clear power-up pickup feedback.

**Testing Priority**:
- Gesture responsiveness on real iPhones.
- Controller mapping on Apple TV and iOS with connected controllers.
- Balance — play many matches with different ship matchups.
- IAP flow and ad integration in sandbox.
- Performance on older devices.

**Workflow with Claude Code**:
- Start broad, then iterate on specific sections using the prompts above.
- Always refer back to this merged guide as the single source of truth.
- After major changes, have Claude generate a short "what changed and why" summary.

---

## 13. v1 Launch Checklist

- [ ] Exactly 8 balanced core ships (free) with documented rock-paper-scissors counters
- [ ] BOTH control styles implemented: Modern Gesture (default) + Classic Virtual Pad, with Settings toggle
- [ ] Universal Xcode project: iOS + tvOS + Mac Catalyst targets with maximum code sharing + premium macOS polish (window resize, menu bar, keyboard/mouse support)
- [ ] Game Center leaderboards (wins & win streaks) + basic achievements
- [ ] StoreKit 2 + dynamic ship unlocking for expansion packs (base 8 ships, packs add 4–8 ships each)
- [ ] Rewarded video ads (AdMob or AppLovin) — optional but recommended
- [ ] VersionCheckManager with polite App Store update reminder (reusable component)
- [ ] Ship compendium with 2D info (+ optional SceneKit 3D rotatable viewer)
- [ ] Music & SFX implemented from recommended sources (alkakrab itch.io packs, White Bat Audio free pack, Kenney Sci-fi Sounds CC0, OpenGameArt CC0 packs) + AudioManager with preloading and fade support
- [ ] Strong visual juice & particles (thrust scaling, layered explosions, impact effects, power-up pops, damage states, camera shake, parallax starfield)
- [ ] Landscape-only iPhone experience
- [ ] Quick match pacing (most games under 30 seconds)
- [ ] Settings for control style, radar toggle, audio volumes, haptics intensity, reduce motion
- [ ] Data-driven ship system ready for future expansion packs (JSON/config + unlock flags)
- [ ] Gentle onboarding / tutorial flow that teaches modern gesture controls in first 1–2 matches without blocking gameplay
- [ ] Accessibility basics: VoiceOver labels on key UI, Dynamic Type support where applicable, Reduce Motion respect, colorblind-friendly palettes
- [ ] Performance: 60/120 FPS support, smooth on iPhone 12+ / M-series Mac, battery conscious

---

This v5.0 guide now contains every piece of advice and technical detail from both conversations, plus extensive new guidance for full PS5/Xbox controller support with button mapping visualization, rich Settings + Fun Modifiers, visual juice, particles, onboarding, accessibility, macOS desktop polish, and data-driven architecture. It resolves minor inconsistencies into a cohesive, production-ready specification focused on delivering a premium, polished experience that feels native and satisfying on iPhone, Apple TV, and Mac.

Use it as the single source of truth when working with Claude Code. The combination of a larger toroidal arena + fluid unified gesture controls (with classic pad fallback) + universal multi-platform support + strong balance philosophy + generous visual/audio/haptic juice should result in a distinctive, high-quality iOS game that honors the spirit of the original Star Control 2 melee while feeling premium and memorable on modern Apple devices.

**Next Step Recommendation**: Start by having Claude implement the core `GameScene` + unified gesture controls + basic `Ship` struct with 3–4 example ships, toroidal wrapping, and camera follow. Then add the particle/juice system and one polished menu flow. Iterate on balance, assets, and onboarding. This project has strong potential if the controls and moment-to-moment feel are nailed early.

---

**Settings + Fun Modifiers + Controller Layout Prompt**:
```
Create a polished Settings screen (SwiftUI preferred for native iOS feel, presented modally from SpriteKit).
Include all core settings: Control Style toggle (Modern Gesture vs Classic Virtual Pad), Haptics, Audio volumes, Mini-Radar toggle, Screen Shake, Auto-Update Reminder, Game Center status, and a prominent button to open the "Controller Layout" screen.
Add a clearly separated "Fun Modifiers" section with these exact toggles:
- Zero Gravity Damage
- Unlimited Battery / Energy
- Invincibility
- Unlimited Special Weapons
- Unlimited Speed Boost
- Infinite Power-Ups
- No Ship Inertia (optional)
- Enemy AI Difficulty (Easy/Normal/Hard/Insane)
All modifiers must be stored in UserDefaults, applied cleanly in game logic, and must never corrupt Game Center scores (show a "Modified" badge on Results screen when active).
Also implement the beautiful "Controller Layout" screen described in Section 4 that shows a controller illustration with every button labeled. Make the entire Settings experience feel premium and native.
```

**End of Merged Spec (v5.0)**