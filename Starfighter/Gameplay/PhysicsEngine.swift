import SpriteKit
import CoreGraphics

/// Shared physics helpers — damage scaling, world boundaries, and toroidal wrap math.
///
/// **Plan reference:** Section 6 (damage formula), Section 4 (bounded vs. toroidal world).
enum PhysicsEngine {

    // MARK: - Damage

    /// Section 6 damage formula:
    /// `final = base × (1 + weapon_weight × ship_offensive_modifier) × (1 - target_shield_modifier × target_shield_strength) × (1 - target_armor_modifier)`
    static func damage(weapon: WeaponDefinition,
                       attackerOffensiveModifier: CGFloat = WorldConstants.baselineOffensiveModifier,
                       targetShieldFraction: CGFloat,
                       targetArmor: CGFloat = 0) -> CGFloat {
        let base = CGFloat(weapon.baseDamage)
        let weight = CGFloat(weapon.weaponWeight)
        let shieldMul = 1 - (WorldConstants.shieldDamageModifier * targetShieldFraction)
        let armorMul = 1 - targetArmor
        return base * (1 + weight * attackerOffensiveModifier) * shieldMul * armorMul
    }

    // MARK: - World boundaries

    /// Apply the current world's boundary rule to a ship.
    /// Toroidal: wrap modulo world size. Bounded: clamp + reflect with 45% velocity loss.
    /// - Returns: the wrap delta applied (zero in bounded mode, non-zero only on a toroidal wrap).
    /// Callers (e.g., CombatScene) use the delta to wrap the camera by the same amount so the
    /// view never visibly jumps when the player crosses an edge.
    @discardableResult
    static func enforceWorldBoundaries(ship: Ship, world: CGRect) -> CGVector {
        switch WorldConstants.worldMode {
        case .toroidal:
            return wrap(node: ship, world: world)
        case .bounded:
            return reflectBounded(ship: ship, world: world)
        }
    }

    /// Apply toroidal wrap to any moving node. Same math used for ships and projectiles.
    /// Returns the (x, y) delta added to position so callers can mirror it onto a camera.
    @discardableResult
    static func wrap(node: SKNode, world: CGRect) -> CGVector {
        var delta = CGVector.zero
        let halfW = world.width / 2
        let halfH = world.height / 2
        if node.position.x >  halfW + world.midX { node.position.x -= world.width; delta.dx = -world.width }
        if node.position.x < -halfW + world.midX { node.position.x += world.width; delta.dx =  world.width }
        if node.position.y >  halfH + world.midY { node.position.y -= world.height; delta.dy = -world.height }
        if node.position.y < -halfH + world.midY { node.position.y += world.height; delta.dy =  world.height }
        return delta
    }

    /// Bounded-world bounce. Section 4: ~45% velocity loss.
    private static func reflectBounded(ship: Ship, world: CGRect) -> CGVector {
        let r = ship.hitboxRadius
        let minX = world.minX + r, maxX = world.maxX - r
        let minY = world.minY + r, maxY = world.maxY - r
        let retention = WorldConstants.wallBounceRetention
        var pos = ship.position
        var v = ship.velocity

        if pos.x < minX { pos.x = minX; if v.dx < 0 { v.dx = -v.dx * retention } }
        if pos.x > maxX { pos.x = maxX; if v.dx > 0 { v.dx = -v.dx * retention } }
        if pos.y < minY { pos.y = minY; if v.dy < 0 { v.dy = -v.dy * retention } }
        if pos.y > maxY { pos.y = maxY; if v.dy > 0 { v.dy = -v.dy * retention } }

        ship.position = pos
        ship.velocity = v
        return .zero
    }

    // MARK: - Wrap-aware vector math

    /// Shortest wrap-aware delta from `from` → `to`. In toroidal mode, picks the path
    /// that doesn't cross the world's midline; in bounded mode, returns the literal delta.
    /// Used by AI targeting + the HUD's off-screen enemy indicator (Section 4).
    static func shortestDelta(from: CGPoint, to: CGPoint, world: CGRect) -> CGVector {
        var dx = to.x - from.x
        var dy = to.y - from.y
        if WorldConstants.worldMode == .toroidal {
            if dx >  world.width / 2  { dx -= world.width }
            if dx < -world.width / 2  { dx += world.width }
            if dy >  world.height / 2 { dy -= world.height }
            if dy < -world.height / 2 { dy += world.height }
        }
        return CGVector(dx: dx, dy: dy)
    }
}
