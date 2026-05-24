import SpriteKit
import CoreGraphics

/// Shared physics helpers — damage scaling and world-boundary handling.
///
/// **Plan reference:** Section 6 (damage formula) and Section 4 (bounded world / wall bounce).
enum PhysicsEngine {

    /// Section 6 damage formula:
    /// `final = base × (1 + weapon_weight × ship_offensive_modifier) × (1 - target_shield_modifier × target_shield_strength) × (1 - target_armor_modifier)`
    ///
    /// Phase 1 keeps `targetArmor = 0`. Phase 2 adds per-ship armor on definition.
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

    /// Clamp a ship inside the world rect; on contact, reflect the velocity component with
    /// `WorldConstants.wallBounceRetention` (Section 4: "~45% velocity loss" → retain 55%).
    static func enforceWorldBounds(ship: Ship, world: CGRect) {
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
    }
}
