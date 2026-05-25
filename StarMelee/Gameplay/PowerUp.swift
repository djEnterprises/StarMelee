import SpriteKit
import CoreGraphics

/// A collectible power-up in the arena.
///
/// **Plan reference:** Section 8 (Power-Up types + spawn logic), Section 14 (color-coded glow icons).
/// Phase 2 implements the instant pickups (life / battery / shield restore + timer extension).
/// Phase 3+ adds duration buffs (damage multiplier, shield regen boost, repair drone) and the
/// quantum-torpedo ammo path.
final class PowerUp: SKNode {

    let definition: PowerUpDefinition
    private(set) var ageSeconds: TimeInterval = 0
    static let despawnSeconds: TimeInterval = 12   // Section 8: disappears after 12s

    init(definition: PowerUpDefinition) {
        self.definition = definition
        super.init()

        let palette = Self.palette(for: definition.kind)

        // Outer glow ring
        let ring = SKShapeNode(circleOfRadius: 22)
        ring.fillColor = .clear
        ring.strokeColor = palette.withAlphaComponent(0.5)
        ring.lineWidth = 1.5
        ring.glowWidth = 8
        ring.alpha = 0.9
        addChild(ring)

        // Body
        let body = SKShapeNode(circleOfRadius: 14)
        body.fillColor = palette.withAlphaComponent(0.5)
        body.strokeColor = palette
        body.lineWidth = 2
        body.glowWidth = 6
        addChild(body)

        // Letter glyph at the center identifies the type at a glance
        let label = SKLabelNode(text: Self.glyph(for: definition.kind))
        label.fontName = "Menlo-Bold"
        label.fontSize = 12
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        addChild(label)

        // Gentle pulse animation
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.9),
            SKAction.scale(to: 1.00, duration: 0.9),
        ])
        run(SKAction.repeatForever(pulse))

        // Physics — sensor body that only triggers contacts (no collision response).
        let pb = SKPhysicsBody(circleOfRadius: 18)
        pb.affectedByGravity = false
        pb.isDynamic = false
        pb.categoryBitMask = PhysicsCategory.powerUp
        pb.collisionBitMask = 0
        pb.contactTestBitMask = PhysicsCategory.playerShip | PhysicsCategory.enemyShip
        self.physicsBody = pb
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not used") }

    /// Returns false when the power-up has been collected or should despawn.
    /// Fun Modifier: infinitePowerUps disables the despawn timer.
    func tick(dt: TimeInterval) -> Bool {
        ageSeconds += dt
        if FunModifiers.shared.infinitePowerUps { return true }
        return ageSeconds < Self.despawnSeconds
    }

    /// Apply this power-up's effect to a collecting ship. Returns extra timer seconds the match
    /// should gain (only `timerExtension` returns > 0).
    @discardableResult
    func collect(by ship: Ship) -> TimeInterval {
        switch definition.kind {
        case .lifeRestore:
            ship.adjustHealth(by: CGFloat(definition.magnitude) * ship.maxHealth)
            return 0
        case .batteryRestore:
            ship.battery = min(ship.maxBattery,
                               ship.battery + CGFloat(definition.magnitude) * ship.maxBattery)
            return 0
        case .shieldRestore:
            ship.adjustShield(by: CGFloat(definition.magnitude) * ship.maxShield)
            return 0
        case .timerExtension:
            return TimeInterval(definition.magnitude)
        case .quantumTorpedoAmmo, .speedBoostCharge, .specialReset,
             .damageMultiplier, .shieldRegenBoost, .repairDrone:
            // Phase 3+ owners. Phase 2 stub: silently absorb the pickup so the spawn loop
            // still feels alive; effect TODO.
            return 0
        }
    }

    static func glyph(for kind: PowerUpDefinition.Kind) -> String {
        switch kind {
        case .lifeRestore:        return "+"
        case .batteryRestore:     return "B"
        case .shieldRestore:      return "S"
        case .quantumTorpedoAmmo: return "Q"
        case .speedBoostCharge:   return ">"
        case .specialReset:       return "!"
        case .timerExtension:     return "T"
        case .damageMultiplier:   return "×"
        case .shieldRegenBoost:   return "R"
        case .repairDrone:        return "D"
        }
    }

    static func palette(for kind: PowerUpDefinition.Kind) -> SKColor {
        switch kind {
        case .lifeRestore:        return SKColor(red: 0.20, green: 1.00, blue: 0.40, alpha: 1.0)
        case .batteryRestore:     return SKColor(red: 1.00, green: 0.85, blue: 0.15, alpha: 1.0)
        case .shieldRestore:      return SKColor(red: 0.40, green: 0.80, blue: 1.00, alpha: 1.0)
        case .quantumTorpedoAmmo: return SKColor(red: 1.00, green: 0.20, blue: 0.85, alpha: 1.0)
        case .speedBoostCharge:   return SKColor(red: 0.00, green: 1.00, blue: 0.84, alpha: 1.0)
        case .specialReset:       return SKColor(red: 1.00, green: 0.55, blue: 0.00, alpha: 1.0)
        case .timerExtension:     return SKColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1.0)
        case .damageMultiplier:   return SKColor(red: 1.00, green: 0.30, blue: 0.30, alpha: 1.0)
        case .shieldRegenBoost:   return SKColor(red: 0.60, green: 0.40, blue: 1.00, alpha: 1.0)
        case .repairDrone:        return SKColor(red: 0.30, green: 1.00, blue: 0.70, alpha: 1.0)
        }
    }
}

// MARK: - Ship mutator helpers used only by PowerUp collection

extension Ship {
    /// Add positive or negative health, clamped to [0, maxHealth]. Used by power-up collection.
    func adjustHealth(by delta: CGFloat) {
        let newValue = max(0, min(maxHealth, healthInternal + delta))
        setHealth(newValue)
    }
    /// Add positive or negative shield, clamped to [0, maxShield].
    func adjustShield(by delta: CGFloat) {
        let newValue = max(0, min(maxShield, shieldInternal + delta))
        setShield(newValue)
    }
}
