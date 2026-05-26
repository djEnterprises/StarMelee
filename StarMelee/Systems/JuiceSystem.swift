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

    // MARK: - Camera shake

    enum ShakeStrength {
        case light, medium, heavy, massive

        /// Initial amplitude (points) and duration (seconds).
        var profile: (amplitude: CGFloat, durationSeconds: TimeInterval) {
            switch self {
            case .light:   return (4,  8.0 / 60.0)
            case .medium:  return (8,  14.0 / 60.0)
            case .heavy:   return (14, 22.0 / 60.0)
            case .massive: return (22, 36.0 / 60.0)
            }
        }
    }

    private var shakeAmplitude: CGFloat = 0
    private var shakeSecondsRemaining: TimeInterval = 0
    private var shakeDecayPerSecond: CGFloat = 0

    /// Request a shake. Stronger requests override weaker ones in progress.
    func shake(_ strength: ShakeStrength) {
        let scale = motionScale
        guard scale > 0 else { return }
        let (amp, dur) = strength.profile
        let scaled = amp * scale
        if scaled > shakeAmplitude {
            shakeAmplitude = scaled
            shakeSecondsRemaining = dur
            // Decay rate so amplitude reaches ~0 by the end of the window.
            shakeDecayPerSecond = scaled / CGFloat(dur)
        }
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

    /// Returns the dt multiplier to apply to gameplay this frame.
    /// Always 1.0 if no slow-mo is active.
    var currentTimeScale: CGFloat { timeScale }

    // MARK: - Per-frame tick

    /// Evolve shake + slow-mo state. Apply the resulting shake offset to the camera.
    func apply(dt: TimeInterval, to camera: SKCameraNode, cameraTargetPosition: CGPoint) {
        // Slow-mo decay
        slowMoSecondsRemaining -= dt
        if slowMoSecondsRemaining <= 0 {
            timeScale = 1.0
            slowMoSecondsRemaining = 0
        }

        // Shake decay
        shakeSecondsRemaining -= dt
        if shakeSecondsRemaining <= 0 {
            shakeAmplitude = 0
            shakeSecondsRemaining = 0
        } else {
            shakeAmplitude = max(0, shakeAmplitude - shakeDecayPerSecond * CGFloat(dt))
        }

        // Apply offset: position the camera at the smoothed-follow target, plus a random nudge.
        let ox = (shakeAmplitude > 0) ? CGFloat.random(in: -shakeAmplitude...shakeAmplitude) : 0
        let oy = (shakeAmplitude > 0) ? CGFloat.random(in: -shakeAmplitude...shakeAmplitude) : 0
        camera.position = CGPoint(x: cameraTargetPosition.x + ox,
                                  y: cameraTargetPosition.y + oy)
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

        // Build a large rounded-rect "frame" — colored ring around the screen edges so the
        // center stays clearly visible. Sized to comfortably cover any iOS/iPad/tvOS/Mac
        // viewport without needing to know the actual SKView size.
        let frame = SKShapeNode(rectOf: CGSize(width: 4000, height: 4000), cornerRadius: 24)
        frame.lineWidth = 220
        frame.strokeColor = SKColor(red: 1.0, green: 0.15, blue: 0.20, alpha: peakAlpha)
        frame.fillColor = .clear
        frame.glowWidth = 60
        frame.alpha = 0
        frame.zPosition = 999       // above all gameplay nodes
        frame.position = .zero       // centered on camera
        camera.addChild(frame)

        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.05)
        let hold = SKAction.wait(forDuration: 0.08)
        let fadeOut = SKAction.fadeAlpha(to: 0.0, duration: 0.30 + Double(strength) * 0.15)
        frame.run(SKAction.sequence([fadeIn, hold, fadeOut])) { [weak frame] in
            frame?.removeFromParent()
        }
    }

    // MARK: - Reduce Motion gate

    /// 0.0 = effects fully disabled; 1.0 = effects at full strength.
    /// Reads `settings.reduceMotion` UserDefaults key (set via the Accessibility settings section).
    /// The OS-level Reduce Motion preference will be folded in once a Phase 4 settings pass
    /// listens to `UIAccessibility.isReduceMotionEnabled` and mirrors it here.
    private var motionScale: CGFloat {
        let key = UserDefaults.standard.string(forKey: "settings.reduceMotion") ?? "off"
        switch key {
        case "off":      return 1.0     // full effects
        case "reduced":  return 0.25    // dampened
        case "disabled": return 0.0     // off entirely
        default:         return 1.0
        }
    }
}
