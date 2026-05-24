import SpriteKit
import CoreGraphics

/// Decides when and where to spawn power-ups during a match.
///
/// **Plan reference:** Section 8 (spawn frequency 15–30s, adaptive boost when a ship is below 25%,
/// 12s despawn) and Section 4 (power-ups spawn within ~2 viewports of the midpoint between the
/// two ships so collection feels feasible).
@MainActor
final class PowerUpManager {

    private let defs: [PowerUpDefinition]
    private var weightedDefs: [(def: PowerUpDefinition, cumulativeWeight: CGFloat)] = []
    private var totalWeight: CGFloat = 0
    private var secondsUntilNextSpawn: TimeInterval

    init(definitions: [PowerUpDefinition]) {
        self.defs = definitions
        var acc: CGFloat = 0
        for d in definitions {
            acc += CGFloat(d.weight)
            weightedDefs.append((d, acc))
        }
        totalWeight = acc
        secondsUntilNextSpawn = TimeInterval.random(in: 15...30)   // Section 8
    }

    /// Should the manager spawn a new power-up this frame?
    /// - Parameter dt: seconds since last update
    /// - Parameter playerHealthFraction: 0...1 (for adaptive boost gate)
    /// - Parameter enemyHealthFraction: 0...1
    /// - Returns: a freshly created PowerUp positioned in the world, or nil if nothing to spawn
    func update(dt: TimeInterval,
                playerHealthFraction: CGFloat,
                enemyHealthFraction: CGFloat,
                playerPos: CGPoint,
                enemyPos: CGPoint,
                viewport: CGSize,
                world: CGRect) -> (powerUp: PowerUp, position: CGPoint)? {

        // Adaptive boost: if either ship is below 25% HP, decrement faster (Section 8).
        let adaptive = min(playerHealthFraction, enemyHealthFraction) < 0.25
        let multiplier: TimeInterval = adaptive ? 2.0 : 1.0
        secondsUntilNextSpawn -= dt * multiplier

        guard secondsUntilNextSpawn <= 0, let chosen = weightedPick() else { return nil }
        secondsUntilNextSpawn = TimeInterval.random(in: 15...30)

        // Section 4 + 8: spawn near the midpoint between ships, with an adaptive bias toward the
        // low-health ship so they can plausibly reach it.
        let mid = CGPoint(x: (playerPos.x + enemyPos.x) / 2,
                          y: (playerPos.y + enemyPos.y) / 2)
        var origin = mid
        if adaptive {
            let needyShipPos: CGPoint = playerHealthFraction <= enemyHealthFraction ? playerPos : enemyPos
            origin = CGPoint(x: (mid.x + needyShipPos.x) / 2,
                             y: (mid.y + needyShipPos.y) / 2)
        }

        // Jitter within ~2 viewports of the chosen origin.
        let jitterRangeX = viewport.width * 1.5
        let jitterRangeY = viewport.height * 1.5
        var pos = CGPoint(
            x: origin.x + CGFloat.random(in: -jitterRangeX/2 ... jitterRangeX/2),
            y: origin.y + CGFloat.random(in: -jitterRangeY/2 ... jitterRangeY/2)
        )
        // Keep inside world bounds
        pos.x = max(world.minX + 40, min(world.maxX - 40, pos.x))
        pos.y = max(world.minY + 40, min(world.maxY - 40, pos.y))

        return (PowerUp(definition: chosen), pos)
    }

    private func weightedPick() -> PowerUpDefinition? {
        guard totalWeight > 0 else { return nil }
        let r = CGFloat.random(in: 0...totalWeight)
        for entry in weightedDefs where r <= entry.cumulativeWeight {
            return entry.def
        }
        return defs.last
    }
}
