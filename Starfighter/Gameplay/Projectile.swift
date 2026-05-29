import SpriteKit
import CoreGraphics

/// A flying weapon shot. Owns its own lifetime, optional homing, and damage payload.
///
/// **Plan reference:** Section 6 (Weapon System).
/// Phase 1 supports straight projectiles + simple homing for guided missiles.
final class Projectile: SKNode {

    let definition: WeaponDefinition
    let firedBy: Ship.Side
    /// Multiplier captured at firing time — reflects the shooter's active outgoing-damage buffs.
    let outgoingMultiplier: CGFloat
    private var ageSeconds: TimeInterval = 0
    private var velocity: CGVector
    private weak var homingTarget: Ship?

    init(definition: WeaponDefinition,
         firedBy: Ship.Side,
         startPosition: CGPoint,
         startHeading: CGFloat,
         homingTarget: Ship? = nil,
         outgoingMultiplier: CGFloat = 1.0) {
        self.definition = definition
        self.firedBy = firedBy
        self.homingTarget = definition.homing ? homingTarget : nil
        self.outgoingMultiplier = outgoingMultiplier

        let speed = CGFloat(definition.projectileSpeed) * WorldConstants.speedFrameToSecond
        self.velocity = CGVector(dx: cos(startHeading) * speed, dy: sin(startHeading) * speed)

        super.init()
        position = startPosition
        zRotation = startHeading - .pi / 2

        // Visual — colored by attacker, shape by category.
        let color: SKColor = firedBy == .player
            ? SKColor(red: 0, green: 1.0, blue: 0.84, alpha: 1.0)
            : SKColor(red: 1.0, green: 0.2, blue: 0.4, alpha: 1.0)
        let visual: SKShapeNode
        switch definition.category {
        case .primary:
            visual = SKShapeNode(rectOf: CGSize(width: 3, height: 14), cornerRadius: 1)
        case .secondary:
            visual = SKShapeNode(rectOf: CGSize(width: 6, height: 18), cornerRadius: 2)
        case .special:
            visual = SKShapeNode(circleOfRadius: 8)
        }
        visual.fillColor = color
        visual.strokeColor = .white
        visual.glowWidth = 4
        visual.lineWidth = 0.5
        addChild(visual)

        // Physics — slim circular body, no gravity, no rotation, contact-only.
        let body = SKPhysicsBody(circleOfRadius: max(2, CGFloat(definition.areaOfEffect == 0 ? 3 : 5)))
        body.affectedByGravity = false
        body.allowsRotation = false
        body.linearDamping = 0
        body.categoryBitMask = firedBy == .player ? PhysicsCategory.playerShot : PhysicsCategory.enemyShot
        body.collisionBitMask = 0   // pass through walls; we handle bounds manually
        body.contactTestBitMask = firedBy == .player
            ? PhysicsCategory.enemyShip | PhysicsCategory.planet
            : PhysicsCategory.playerShip | PhysicsCategory.planet
        self.physicsBody = body
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not used") }

    /// Returns false when the projectile should be removed from the scene
    /// (expired, left world bounds, or hit something).
    func update(dt: TimeInterval, world: CGRect) -> Bool {
        ageSeconds += dt
        if ageSeconds > definition.lifetimeSeconds { return false }

        let dtf = CGFloat(dt)

        // Homing — rotate velocity toward target at a fixed turn rate.
        if let target = homingTarget {
            let targetVec = CGVector(dx: target.position.x - position.x,
                                     dy: target.position.y - position.y)
            let desiredAngle = atan2(targetVec.dy, targetVec.dx)
            let currentAngle = atan2(velocity.dy, velocity.dx)
            var delta = desiredAngle - currentAngle
            while delta >  .pi { delta -= 2 * .pi }
            while delta < -.pi { delta += 2 * .pi }
            let maxTurn: CGFloat = 3.5 * dtf   // rad/s; tuned for "noticeable but dodgeable"
            let applied = max(-maxTurn, min(maxTurn, delta))
            let newAngle = currentAngle + applied
            let speed = hypot(velocity.dx, velocity.dy)
            velocity = CGVector(dx: cos(newAngle) * speed, dy: sin(newAngle) * speed)
            zRotation = newAngle - .pi / 2
        }

        position.x += velocity.dx * dtf
        position.y += velocity.dy * dtf

        switch WorldConstants.worldMode {
        case .toroidal:
            // Projectiles wrap with the world. Lifetime still kills them eventually.
            PhysicsEngine.wrap(node: self, world: world)
        case .bounded:
            // Section 4: projectiles leaving the bounded world are destroyed.
            if !world.contains(position) { return false }
        }
        return true
    }

    /// Compute scaled damage against a target ship's current shield state.
    func computeDamage(against target: Ship) -> CGFloat {
        PhysicsEngine.damage(weapon: definition, targetShieldFraction: target.shieldFraction) * outgoingMultiplier
    }
}
