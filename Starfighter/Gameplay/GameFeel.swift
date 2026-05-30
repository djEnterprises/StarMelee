import CoreGraphics
import Foundation

/// Central, tunable "game feel" constants — the single place to adjust how Starfighter *feels*
/// without hunting through systems.
///
/// **Premium-polish plan reference:** Phase 1 ("Game Feel Foundation"). The plan's standing rule is
/// "one feel file": every magic number governing hit-stop, screen shake, and camera kick lives here
/// so it can be tuned in isolation. Add new feel knobs here rather than inline in systems.
///
/// All values are deliberately conservative — premium feel is about *restraint scaled to magnitude*,
/// not maximum intensity. Readability of gameplay always wins (see CLAUDE.md).
enum GameFeel {

    // MARK: - Hit-stop (frame freeze)
    //
    // On a meaningful impact we briefly freeze gameplay simulation (not the juice/particle layer)
    // so the hit reads as having weight. Tiny on light hits, longer on kills. Implemented by
    // forcing the gameplay time-scale toward zero for the duration; the camera, shake, particles,
    // and SKActions keep animating at real time.

    /// Gameplay time-scale while a hit-stop is active. Near-zero, but not exactly 0 so we never
    /// feed a literally-zero dt into integration.
    static let hitStopTimeScale: CGFloat = 0.04

    /// Hit-stop duration for a ship destruction / kill — the heaviest beat in combat.
    static let hitStopKill: TimeInterval = 0.09

    /// Map an incoming damage amount (raw HP) to a hit-stop duration for a non-fatal hit.
    /// Small chip damage barely registers; a big shell freezes noticeably. Clamped so rapid fire
    /// can't stack into a sludgy slow-motion mess.
    static func hitStopDuration(forDamage hp: CGFloat) -> TimeInterval {
        guard hp > 1 else { return 0 }
        // ~16ms at 5 HP, ~50ms at 25+ HP.
        let seconds = 0.012 + Double(min(hp, 30) / 30) * 0.045
        return min(0.07, seconds)
    }

    // MARK: - Trauma-based screen shake
    //
    // Industry-standard trauma model (GDC "Math for Game Programmers: Juicing Your Cameras"):
    // events add `trauma` (0...1, capped); the actual shake is trauma RAISED TO A POWER, so shake
    // falls off fast and feels organic rather than linear/jittery. Trauma decays linearly per second.

    /// Trauma decays this much per second (so 1.0 trauma fully settles in ~1.1s).
    static let traumaDecayPerSecond: CGFloat = 0.9

    /// Exponent applied to trauma to get shake strength. 2 = classic; higher = punchier onset.
    static let traumaExponent: CGFloat = 2.0

    /// Max positional camera offset (points) at full shake.
    static let shakeMaxOffset: CGFloat = 26.0

    /// Max camera roll (radians) at full shake. Subtle — a little roll reads as "expensive",
    /// too much is nauseating. ~1.4°.
    static let shakeMaxAngle: CGFloat = 0.025

    /// Trauma added per shake-strength tier. Capped to 1.0 after accumulation.
    static let traumaLight: CGFloat   = 0.22
    static let traumaMedium: CGFloat  = 0.38
    static let traumaHeavy: CGFloat   = 0.55
    static let traumaMassive: CGFloat = 0.85

    // MARK: - Camera punch-zoom
    //
    // A brief zoom-in kick on big moments (explosions, boss death). SKCameraNode scale < 1 zooms in.

    /// Fractional zoom-in amount for a kill/explosion punch (0.04 = 4% closer, momentarily).
    static let cameraPunchAmount: CGFloat = 0.045

    /// Time to snap in, and to ease back out, for the punch-zoom.
    static let cameraPunchInDuration: TimeInterval = 0.05
    static let cameraPunchOutDuration: TimeInterval = 0.22
}
