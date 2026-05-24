import Foundation
import SpriteKit

/// Tracks per-weapon fire-rate cadence for a single ship.
///
/// **Plan reference:** Section 5 (fire-rate stats in frames @ 60 FPS) and Section 6 (categories).
/// Phase 1 supports primary + secondary. Special weapons gated by `allowSpecials` arrive in Phase 3.
final class Weapon {
    let definition: WeaponDefinition
    let intervalSeconds: TimeInterval
    private var secondsUntilReady: TimeInterval = 0

    init(definition: WeaponDefinition, fireRateFrames: Int) {
        self.definition = definition
        self.intervalSeconds = TimeInterval(fireRateFrames) / 60.0
    }

    /// Tick the cooldown forward.
    func tick(dt: TimeInterval) {
        secondsUntilReady = max(0, secondsUntilReady - dt)
    }

    /// Whether the weapon is ready to fire right now.
    var isReady: Bool { secondsUntilReady <= 0 }

    /// Returns a freshly spawned projectile if the weapon was ready, otherwise nil.
    /// Resets the cooldown when it fires.
    func fire(from ship: Ship, target: Ship? = nil) -> Projectile? {
        guard isReady else { return nil }
        // Battery cost
        guard ship.spendBattery(CGFloat(definition.batteryCost)) else { return nil }

        secondsUntilReady = intervalSeconds

        // Spawn just ahead of the ship so we don't immediately self-collide.
        let spawnOffset: CGFloat = ship.hitboxRadius + 4
        let start = CGPoint(x: ship.position.x + cos(ship.heading) * spawnOffset,
                            y: ship.position.y + sin(ship.heading) * spawnOffset)
        return Projectile(
            definition: definition,
            firedBy: ship.side,
            startPosition: start,
            startHeading: ship.heading,
            homingTarget: target
        )
    }
}

extension Ship {
    /// Attempt to spend battery. Returns false if not enough.
    func spendBattery(_ amount: CGFloat) -> Bool {
        guard amount <= battery else { return false }
        battery -= amount
        return true
    }
}
