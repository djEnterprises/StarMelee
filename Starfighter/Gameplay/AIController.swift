import Foundation
import CoreGraphics
import SpriteKit

/// Per-frame decision the AI feeds back to the scene. The scene applies these by calling
/// `Ship.update(...)` and firing weapons exactly like the player input pipeline does.
struct AIDecision {
    let thrust: Bool
    let brake: Bool
    let turn: CGFloat       // -1 (left), 0 (hold), +1 (right)
    let firePrimary: Bool
    let fireSecondary: Bool
    let fireSpecial: Bool
}

/// Simple behavior-tree-style AI opponent.
///
/// **Plan reference:** Section 15 — four difficulty levels and a 5-step behavior tree
/// (threat assessment, movement, combat, defense, mistake injection).
///
/// Phase 2 implements **Captain** (default) cleanly; the other tiers tune `aimErrorRange`
/// and `secondaryFireProbabilityPerSecond`. Phase 3 will add special-weapon and transporter
/// behaviors per Section 15 step 4.
@MainActor
final class AIController {

    enum Difficulty: String, Codable {
        case cadet, captain, admiral, legendary
    }

    let difficulty: Difficulty
    private var aimError: CGFloat = 0
    private var secondsUntilAimRefresh: TimeInterval = 0
    private var secondsSinceSecondaryShot: TimeInterval = 0

    init(difficulty: Difficulty = .captain) {
        self.difficulty = difficulty
    }

    /// Produce a per-frame decision for the given ship + target.
    /// - Parameter world: used for toroidal wrap-aware shortest-path targeting.
    func decide(dt: TimeInterval,
                ownShip: Ship,
                target: Ship,
                allowSpecials: Bool,
                world: CGRect) -> AIDecision {
        guard !ownShip.isDestroyed, !target.isDestroyed else {
            return AIDecision(thrust: false, brake: false, turn: 0,
                              firePrimary: false, fireSecondary: false, fireSpecial: false)
        }

        // Refresh the aim error every so often so the AI feels human (Section 15 step 5).
        // Cloak heavily degrades the AI's aim — Section 6: "invisible to AI".
        let cloakedTarget = target.hasBuff(.cloaked)
        let activeAimRange = cloakedTarget ? aimErrorRange * 4 : aimErrorRange
        secondsUntilAimRefresh -= dt
        if secondsUntilAimRefresh <= 0 {
            aimError = CGFloat.random(in: -activeAimRange...activeAimRange)
            secondsUntilAimRefresh = TimeInterval.random(in: 0.4...1.2)
        }

        // Threat assessment (Section 15 step 1). Use the shortest wrap-aware vector — in toroidal
        // mode the target might be "closer" through an edge wrap than across the world.
        let v = PhysicsEngine.shortestDelta(from: ownShip.position, to: target.position, world: world)
        let dx = v.dx
        let dy = v.dy
        let dist = hypot(dx, dy)
        let bearingToTarget = atan2(dy, dx)
        let headingError = normalize(bearingToTarget + aimError - ownShip.heading)

        let lowHealth = ownShip.healthFraction < 0.30
        let closeRange: CGFloat = 220
        let optimalRange: CGFloat = 380
        let primaryEffectiveRange: CGFloat = 700

        // Movement (Section 15 step 2).
        var turn: CGFloat = 0
        var thrust = false
        var brake = false

        if lowHealth {
            // Evade — try to keep the player behind us and thrust away.
            // Aim 180° from the player (target heading away from them).
            let evadeHeadingError = normalize(bearingToTarget + .pi - ownShip.heading)
            if abs(evadeHeadingError) > 0.05 {
                turn = evadeHeadingError > 0 ? 1 : -1
            }
            // Thrust once roughly pointed away.
            if abs(evadeHeadingError) < 0.6 { thrust = true }
        } else {
            // Pursue + aim at target.
            if abs(headingError) > 0.05 {
                turn = headingError > 0 ? 1 : -1
            }
            if dist > optimalRange && abs(headingError) < 0.7 {
                thrust = true
            } else if dist < closeRange {
                brake = true   // don't ram unless we already are
            }
        }

        // Combat (Section 15 step 3).
        let aimedWellEnough = abs(headingError) < 0.18
        let firePrimary = !lowHealth && aimedWellEnough && dist < primaryEffectiveRange

        secondsSinceSecondaryShot += dt
        let cooldownGate = secondsSinceSecondaryShot > 1.0   // don't spam missiles back-to-back
        let secondaryRoll = CGFloat.random(in: 0...1) < secondaryFireProbabilityPerSecond * CGFloat(dt)
        let fireSecondary = !lowHealth
            && allowSpecials
            && cooldownGate
            && aimedWellEnough
            && dist < primaryEffectiveRange * 1.2
            && secondaryRoll
        if fireSecondary { secondsSinceSecondaryShot = 0 }

        // Section 15 step 3: AI uses specials "when advantageous". Simple gate: low HP triggers
        // defensive specials, high aim-quality triggers offensive ones. We don't introspect the
        // special — we just fire it on a per-frame probability and let the dispatcher decide
        // whether the special is available (battery, cooldown, target shield, etc.).
        let specialProb: CGFloat = (lowHealth ? 0.6 : 0.3) * specialFireProbabilityPerSecond
        let specialRoll = ownShip.specialCooldownRemaining <= 0
            && allowSpecials
            && CGFloat.random(in: 0...1) < specialProb * CGFloat(dt)
        let fireSpecial = specialRoll

        return AIDecision(thrust: thrust, brake: brake, turn: turn,
                          firePrimary: firePrimary, fireSecondary: fireSecondary,
                          fireSpecial: fireSpecial)
    }

    private var specialFireProbabilityPerSecond: CGFloat {
        switch difficulty {
        case .cadet:     return 0.10
        case .captain:   return 0.30
        case .admiral:   return 0.60
        case .legendary: return 1.20
        }
    }

    // MARK: - Difficulty tuning

    private var aimErrorRange: CGFloat {
        switch difficulty {
        case .cadet:     return 0.40
        case .captain:   return 0.18
        case .admiral:   return 0.08
        case .legendary: return 0.02
        }
    }

    private var secondaryFireProbabilityPerSecond: CGFloat {
        switch difficulty {
        case .cadet:     return 0.10
        case .captain:   return 0.35
        case .admiral:   return 0.70
        case .legendary: return 1.20
        }
    }

    private func normalize(_ a: CGFloat) -> CGFloat {
        var x = a
        while x >  .pi { x -= 2 * .pi }
        while x < -.pi { x += 2 * .pi }
        return x
    }
}
