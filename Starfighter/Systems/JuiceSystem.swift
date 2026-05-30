import SpriteKit
import CoreGraphics

/// Visual feedback layer — camera shake, time dilation, shockwaves, low-HP smoke.
///
/// **Plan reference:** SuperGrok addition to Section 14 ("Visual Juice Philosophy").
///
/// Design principles:
///   - **Player-only**: every juice effect that produces sensory feedback (shake especially)
///     fires only for events affecting the human player's ship — Section 13 critical rule.
///   - **Accessibility-aware**: respects the `accessibility.reduceMotion` UserDefaults key
///     (and falls back to the OS Reduce Motion setting on iOS) to scale or disable effects.
///   - **Non-blocking**: every API returns immediately; the next `apply(dt:to:)` call evolves
///     the effect. Stronger shakes never get overridden by weaker ones.
@MainActor
final class JuiceSystem {

    /// Cached once at init. Settings (Reduce Motion) are only reachable from the main menu,
    /// never mid-match, and a fresh `JuiceSystem` is created with each `CombatScene`, so the
    /// value can't go stale during play. Caching avoids a `UserDefaults` read + `String`
    /// allocation on every shake / slow-mo / vignette / shockwave in the per-frame damage path.
    private let motionScale: CGFloat = {
        switch UserDefaults.standard.string(forKey: "settings.reduceMotion") ?? "off" {
        case "reduced":  return 0.25    // dampened
        case "disabled": return 0.0     // off entirely
        default:         return 1.0     // full effects
        }
    }()

    // MARK: - Camera shake

    enum ShakeStrength {
        case light, medium, heavy, massive

        /// Trauma contributed by this tier (see `GameFeel`). Trauma accumulates (capped at 1)
        /// and decays; actual shake is trauma^exponent for an organic, non-linear falloff.
        var trauma: CGFloat {
            switch self {
            case .light:   return GameFeel.traumaLight
            case .medium:  return GameFeel.traumaMedium
            case .heavy:   return GameFeel.traumaHeavy
            case .massive: return GameFeel.traumaMassive
            }
        }
    }

    /// Accumulated trauma (0...1). Decays every frame in `apply(dt:)`.
    private var trauma: CGFloat = 0
    /// Monotonic seed advanced each frame so the per-axis noise varies smoothly over time
    /// instead of being pure white noise (smoother = more "camera-operator", less "jackhammer").
    private var shakeSeed: CGFloat = 0

    /// Request a shake. Trauma accumulates (stronger events stack toward the cap) rather than
    /// simply overriding, so a flurry of hits builds intensity naturally.
    func shake(_ strength: ShakeStrength) {
        addTrauma(strength.trauma)
    }

    /// Add raw trauma (0...1 contribution), scaled by the Reduce-Motion setting and capped at 1.
    func addTrauma(_ amount: CGFloat) {
        guard motionScale > 0 else { return }
        trauma = min(1, trauma + amount * motionScale)
    }

    // MARK: - Hit-stop (frame freeze)

    private var hitStopRemaining: TimeInterval = 0

    /// Briefly freeze gameplay simulation for `seconds` to give an impact weight. The juice and
    /// particle layers keep animating (they tick on real time / SKActions). Longest request wins.
    func hitStop(_ seconds: TimeInterval) {
        guard motionScale > 0, seconds > 0 else { return }
        hitStopRemaining = max(hitStopRemaining, seconds * Double(motionScale))
    }

    // MARK: - Time dilation

    enum SlowMo {
        case shipDestruction       // 0.35× for ~14 frames
        case quantumSingularity    // 0.25× for ~22 frames

        var profile: (scale: CGFloat, durationSeconds: TimeInterval) {
            switch self {
            case .shipDestruction:    return (0.35, 14.0 / 60.0)
            case .quantumSingularity: return (0.25, 22.0 / 60.0)
            }
        }
    }

    private var timeScale: CGFloat = 1.0
    private var slowMoSecondsRemaining: TimeInterval = 0

    /// Request a time-dilation event. Stronger requests (slower scale) override.
    func slowMo(_ kind: SlowMo) {
        let scale = motionScale
        guard scale > 0 else { return }
        let (s, dur) = kind.profile
        // Blend with current motion scale so Reduce Motion at half-strength = less dramatic.
        let effective = 1 - ((1 - s) * scale)
        if effective < timeScale {
            timeScale = effective
            slowMoSecondsRemaining = dur
        }
    }

    /// Returns the dt multiplier to apply to gameplay this frame. 1.0 normally; a small slow-mo
    /// value during time dilation; near-zero during a hit-stop freeze (whichever is slower wins).
    var currentTimeScale: CGFloat {
        hitStopRemaining > 0 ? min(timeScale, GameFeel.hitStopTimeScale) : timeScale
    }

    // MARK: - Per-frame tick

    /// Evolve slow-mo, hit-stop, and trauma-based shake state, then position the camera at the
    /// smoothed-follow target plus a shake offset + roll. Driven by REAL dt so juice keeps its
    /// pace even while gameplay is frozen by hit-stop or slowed by time dilation.
    func apply(dt: TimeInterval, to camera: SKCameraNode, cameraTargetPosition: CGPoint) {
        // Slow-mo decay
        slowMoSecondsRemaining -= dt
        if slowMoSecondsRemaining <= 0 {
            timeScale = 1.0
            slowMoSecondsRemaining = 0
        }

        // Hit-stop decay (real time, so the freeze lasts a fixed wall-clock duration)
        if hitStopRemaining > 0 {
            hitStopRemaining = max(0, hitStopRemaining - dt)
        }

        // Trauma decay → shake = trauma^exponent (organic, fast falloff)
        trauma = max(0, trauma - GameFeel.traumaDecayPerSecond * CGFloat(dt))
        let shake = pow(trauma, GameFeel.traumaExponent)

        var ox: CGFloat = 0, oy: CGFloat = 0, roll: CGFloat = 0
        if shake > 0 {
            shakeSeed += CGFloat(dt) * 40        // advance the noise phase
            // Decorrelated sine "noise" per channel — smoother than white noise, no extra deps.
            ox   = GameFeel.shakeMaxOffset * shake * sin(shakeSeed * 1.0 + 0.0)
            oy   = GameFeel.shakeMaxOffset * shake * sin(shakeSeed * 1.3 + 2.1)
            roll = GameFeel.shakeMaxAngle  * shake * sin(shakeSeed * 1.7 + 4.2)
        }
        camera.position = CGPoint(x: cameraTargetPosition.x + ox,
                                  y: cameraTargetPosition.y + oy)
        camera.zRotation = roll
    }

    // MARK: - Camera punch-zoom

    /// A brief zoom-in kick on big moments (explosions, boss death). Independent of the per-frame
    /// position/shake handling — runs as an SKAction on the camera's scale and eases back out.
    func cameraPunch(in camera: SKCameraNode) {
        guard motionScale > 0 else { return }
        let target = 1 - GameFeel.cameraPunchAmount * motionScale   // <1 zooms in
        let punchIn = SKAction.scale(to: target, duration: GameFeel.cameraPunchInDuration)
        punchIn.timingMode = .easeOut
        let punchOut = SKAction.scale(to: 1.0, duration: GameFeel.cameraPunchOutDuration)
        punchOut.timingMode = .easeInEaseOut
        camera.run(SKAction.sequence([punchIn, punchOut]), withKey: "cameraPunch")
    }

    // MARK: - Shockwaves

    /// Spawn an expanding ring on the world layer. Lives ~0.5s, fades to 0 alpha while
    /// expanding to `maxRadius`. The ring is added to `world` and removes itself on completion.
    func spawnShockwave(at position: CGPoint,
                        color: SKColor,
                        maxRadius: CGFloat,
                        durationSeconds: TimeInterval = 0.5,
                        in world: SKNode) {
        let scale = motionScale
        guard scale > 0 else { return }

        let ring = SKShapeNode(circleOfRadius: 1)
        ring.position = position
        ring.strokeColor = color
        ring.fillColor = .clear
        ring.lineWidth = 3
        ring.glowWidth = 4
        ring.zPosition = 50
        world.addChild(ring)

        let scaledMax = maxRadius * scale
        let grow = SKAction.scale(to: scaledMax, duration: durationSeconds)
        grow.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: durationSeconds)
        ring.run(SKAction.group([grow, fade])) { [weak ring] in
            ring?.removeFromParent()
        }
    }

    /// Spawn the layered shockwave + flash for a ship destruction.
    func spawnDestructionExplosion(at position: CGPoint, shipColor: SKColor, in world: SKNode) {
        spawnShockwave(at: position, color: .white,
                       maxRadius: 140, durationSeconds: 0.45, in: world)
        spawnShockwave(at: position, color: shipColor,
                       maxRadius: 90, durationSeconds: 0.55, in: world)
        spawnFlashCore(at: position, color: shipColor, in: world)
    }

    /// Spawn the triple shockwave for a Quantum Singularity event.
    func spawnSingularityExplosion(at position: CGPoint, in world: SKNode) {
        spawnShockwave(at: position, color: .white,
                       maxRadius: 320, durationSeconds: 0.8, in: world)
        spawnShockwave(at: position, color: SKColor(red: 1.0, green: 0.0, blue: 0.67, alpha: 1),
                       maxRadius: 230, durationSeconds: 0.7, in: world)
        spawnShockwave(at: position, color: SKColor(red: 0.0, green: 1.0, blue: 0.84, alpha: 1),
                       maxRadius: 150, durationSeconds: 0.6, in: world)
    }

    private func spawnFlashCore(at position: CGPoint, color: SKColor, in world: SKNode) {
        let core = SKShapeNode(circleOfRadius: 30)
        core.position = position
        core.fillColor = color
        core.strokeColor = .white
        core.glowWidth = 16
        core.zPosition = 60
        world.addChild(core)
        let scaleUp = SKAction.scale(to: 1.6, duration: 0.1)
        let fade = SKAction.fadeOut(withDuration: 0.25)
        core.run(SKAction.group([scaleUp, fade])) { [weak core] in
            core?.removeFromParent()
        }
    }

    // MARK: - Red-vignette flash on player damage

    /// Spawn a brief red screen-edge vignette on the camera. The vignette is a static-
    /// position SKShapeNode child of the camera (so it always covers the screen regardless
    /// of camera position), faded in and out. Strength scales the peak alpha + duration.
    ///
    /// Used for: player taking damage. Gives an instantly recognizable "you got hit" signal
    /// even when the actual damage flash on the ship hull is occluded by HUD overlays.
    func flashRedVignette(strength: CGFloat, in camera: SKCameraNode) {
        let scale = motionScale
        guard scale > 0 else { return }
        let peakAlpha: CGFloat = min(0.55, 0.20 + strength * 0.4) * scale

        // A single reusable rounded-rect "frame" — colored ring around the screen edges so the
        // center stays clearly visible. Sized to comfortably cover any iOS/iPad/tvOS/Mac
        // viewport without needing to know the actual SKView size. The node is created once per
        // camera and reused on every subsequent hit (rebuilding a 4000×4000 glow-stroked
        // SKShapeNode several times a second under sustained fire was a real frame-time cost).
        let vignette: SKShapeNode
        if let existing = camera.childNode(withName: "juiceVignette") as? SKShapeNode {
            vignette = existing
            vignette.removeAllActions()
        } else {
            let frame = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000), cornerRadius: 24)
            frame.name = "juiceVignette"
            frame.lineWidth = 220
            frame.fillColor = .clear
            frame.glowWidth = 60
            frame.zPosition = 999       // above all gameplay nodes
            frame.position = .zero       // centered on camera
            camera.addChild(frame)
            vignette = frame
        }
        vignette.strokeColor = SKColor(red: 1.0, green: 0.15, blue: 0.20, alpha: peakAlpha)
        vignette.alpha = 0

        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.05)
        let hold = SKAction.wait(forDuration: 0.08)
        let fadeOut = SKAction.fadeAlpha(to: 0.0, duration: 0.30 + Double(strength) * 0.15)
        vignette.run(SKAction.sequence([fadeIn, hold, fadeOut]))
    }

}
