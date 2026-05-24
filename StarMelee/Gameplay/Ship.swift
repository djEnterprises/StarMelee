import SpriteKit
import CoreGraphics

/// A combat ship — visual + physics + stat profile.
///
/// **Plan reference:** Section 5 (Ship System).
/// Phase 1: stylized polygon hull drawn programmatically (Section 14 DECISION POINT).
/// Phase 2 will refactor the visual layer to per-ship sprite art.
final class Ship: SKNode {

    enum Side { case player, opponent }

    // MARK: - Identity
    let definition: ShipDefinition
    let side: Side

    // MARK: - Stats (derived from definition; mutable so Phase 4 IAP weapon enhancements can scale them)
    let maxHealth: CGFloat
    let healRatePerSecond: CGFloat
    let maxShield: CGFloat
    let maxBattery: CGFloat
    let mass: CGFloat
    let accelerationPerSecond: CGFloat
    let maxSpeed: CGFloat
    let turnRatePerSecond: CGFloat
    let hitboxRadius: CGFloat

    // MARK: - Dynamic state
    private(set) var health: CGFloat
    private(set) var shield: CGFloat
    /// Module-internal setter: `Weapon.spendBattery(_:)` (defined in Weapon.swift) writes through this.
    var battery: CGFloat

    /// Velocity in points per second. Star Control–style inertia: persists forever unless braked.
    /// Module-internal setter so `PhysicsEngine` can write after a wall reflection.
    var velocity: CGVector = .zero

    /// Heading in radians (0 = facing right / +x axis).
    var heading: CGFloat {
        get { -zRotation + .pi / 2 }   // SpriteKit's zRotation has 0 = facing +x via image orientation
        set { zRotation = .pi / 2 - newValue }
    }

    /// Seconds since this ship last took damage. Used to gate self-heal (Section 7: pauses for 2s after damage).
    private var secondsSinceDamage: TimeInterval = .infinity

    // MARK: - Visual nodes
    private let hull: SKShapeNode
    private let thrusterFlare: SKShapeNode

    // MARK: - Init

    init(definition: ShipDefinition, side: Side) {
        self.definition = definition
        self.side = side

        let s = definition.stats
        self.maxHealth = CGFloat(s.maxHealth)
        self.healRatePerSecond = CGFloat(s.healRate) / 100.0 * CGFloat(s.maxHealth) // healRate is %/s
        self.maxShield = CGFloat(s.maxShield)
        self.maxBattery = CGFloat(s.maxBattery)
        self.mass = CGFloat(s.mass)
        self.accelerationPerSecond = CGFloat(s.acceleration) * WorldConstants.accelFrameToSecond
        self.maxSpeed = CGFloat(s.maxSpeed) * WorldConstants.speedFrameToSecond
        self.turnRatePerSecond = CGFloat(s.turnRate) * WorldConstants.turnFrameToSecond
        self.hitboxRadius = CGFloat(s.hitboxSize)

        self.health = self.maxHealth
        self.shield = self.maxShield
        self.battery = self.maxBattery

        // Build hull — faction-tinted polygon silhouette from the ShipHullDesigner.
        let color: SKColor = side == .player
            ? SKColor(red: 0, green: 1.0, blue: 0.84, alpha: 1.0)
            : SKColor(red: 1.0, green: 0.2, blue: 0.4, alpha: 1.0)

        let s2 = hitboxRadius * 1.5
        let hullPath = ShipHullDesigner.cgPath(for: definition.id, size: s2)
        self.hull = SKShapeNode(path: hullPath)
        hull.fillColor = color.withAlphaComponent(0.18)
        hull.strokeColor = color
        hull.lineWidth = 1.8
        hull.glowWidth = 4

        // Thruster flare — visible only while thrusting.
        let flarePath = CGMutablePath()
        flarePath.move(to: CGPoint(x: -s2 * 0.35, y: -s2 * 0.4))
        flarePath.addLine(to: CGPoint(x: 0, y: -s2 * 1.4))
        flarePath.addLine(to: CGPoint(x: s2 * 0.35, y: -s2 * 0.4))
        flarePath.closeSubpath()
        self.thrusterFlare = SKShapeNode(path: flarePath)
        thrusterFlare.fillColor = SKColor(red: 1.0, green: 0.67, blue: 0, alpha: 0.85)
        thrusterFlare.strokeColor = .clear
        thrusterFlare.glowWidth = 6
        thrusterFlare.alpha = 0

        super.init()
        addChild(thrusterFlare)
        addChild(hull)

        // SpriteKit physics — circular hitbox for ship-vs-projectile collision.
        let body = SKPhysicsBody(circleOfRadius: hitboxRadius)
        body.affectedByGravity = false
        body.linearDamping = 0       // Star Control: no auto-drag
        body.angularDamping = 0
        body.allowsRotation = false  // we drive zRotation manually
        body.mass = mass * 0.05      // SK mass is just for collision response; gameplay mass used in our own physics
        body.categoryBitMask = (side == .player) ? PhysicsCategory.playerShip : PhysicsCategory.enemyShip
        body.collisionBitMask = PhysicsCategory.planet | PhysicsCategory.worldBound  // ships bounce off planets & walls
        body.contactTestBitMask = PhysicsCategory.playerShot | PhysicsCategory.enemyShot | PhysicsCategory.planet
        self.physicsBody = body

        heading = .pi / 2   // facing up by default; the scene rotates after spawning
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not used") }

    // MARK: - Per-frame update
    //
    // Section 23 implementation pattern: take a single `allowSpecials: Bool`. Primary / secondary
    // firing ignore this flag; specials, combos, and boost respect it.

    /// Apply controls and integrate physics for one frame.
    /// - Parameters:
    ///   - dt: time since last update, in seconds.
    ///   - thrust: X-button held — apply forward thrust.
    ///   - brake: Y-button held — actively decelerate.
    ///   - turn: -1 (left), 0 (straight), +1 (right). Phase 1 8-way digital; Phase 2 can swap in raw stick magnitude.
    ///   - allowSpecials: false during pre-match countdown, true once the match begins.
    func update(dt: TimeInterval, thrust: Bool, brake: Bool, turn: CGFloat, allowSpecials: Bool) {
        let dtf = CGFloat(dt)

        // Turning
        if abs(turn) > 0.01 {
            heading += turn * turnRatePerSecond * dtf
        }

        // Thrust
        if thrust {
            let dx = cos(heading) * accelerationPerSecond * dtf
            let dy = sin(heading) * accelerationPerSecond * dtf
            velocity.dx += dx
            velocity.dy += dy
            // Clamp to max speed
            let speed = hypot(velocity.dx, velocity.dy)
            if speed > maxSpeed {
                let scale = maxSpeed / speed
                velocity.dx *= scale
                velocity.dy *= scale
            }
            thrusterFlare.alpha = 1.0
        } else {
            // Fade thruster
            thrusterFlare.alpha = max(0, thrusterFlare.alpha - CGFloat(dt) * 4)
        }

        // Brake — fraction of current velocity removed per second.
        if brake {
            let retention = max(0, 1 - WorldConstants.brakeStrengthPerSecond * dtf)
            velocity.dx *= retention
            velocity.dy *= retention
        }

        // Integrate position
        position.x += velocity.dx * dtf
        position.y += velocity.dy * dtf

        // Heal (Section 7: +heal% per second, paused for 2s after damage)
        secondsSinceDamage += dt
        if secondsSinceDamage > 2.0 && health < maxHealth {
            health = min(maxHealth, health + healRatePerSecond * dtf)
        }

        // Shield regen (Section 7: +5%/s after 3s of no damage)
        if secondsSinceDamage > 3.0 && shield < maxShield {
            shield = min(maxShield, shield + maxShield * 0.05 * dtf)
        }

        // Battery regen (Section 7)
        let regenRate = (100.0 / 50.0) * CGFloat(definition.stats.batteryRegenMultiplier) // +1%/0.5s base = +2%/s
        if battery < maxBattery {
            battery = min(maxBattery, battery + maxBattery * (regenRate / 100.0) * dtf)
        }

        // allowSpecials is read by the weapon / specials systems; Ship just integrates physics here.
        _ = allowSpecials
    }

    // MARK: - Damage application

    /// Apply incoming damage. Returns the amount actually subtracted from health.
    /// Section 7: shield absorbs first, then health.
    @discardableResult
    func takeDamage(_ amount: CGFloat) -> CGFloat {
        secondsSinceDamage = 0
        var remaining = amount

        if shield > 0 {
            let blocked = min(shield, remaining * WorldConstants.shieldDamageModifier)
            shield -= blocked
            remaining -= blocked
        }

        let healthLoss = max(0, remaining)
        health = max(0, health - healthLoss)

        // Damage flash
        let flash = SKAction.sequence([
            SKAction.run { [weak self] in self?.hull.fillColor = .white },
            SKAction.wait(forDuration: 0.06),
            SKAction.run { [weak self] in
                guard let self else { return }
                let color: SKColor = self.side == .player
                    ? SKColor(red: 0, green: 1.0, blue: 0.84, alpha: 0.18)
                    : SKColor(red: 1.0, green: 0.2, blue: 0.4, alpha: 0.18)
                self.hull.fillColor = color
            }
        ])
        hull.run(flash, withKey: "damageFlash")

        return healthLoss
    }

    /// Restore health, shield, and battery to 100% — used between matches (Section 4 step 6).
    func fullyRestore() {
        health = maxHealth
        shield = maxShield
        battery = maxBattery
        secondsSinceDamage = .infinity
    }

    var isDestroyed: Bool { health <= 0 }

    // MARK: - Module-internal write accessors
    // Used by PowerUp collection (which lives in a separate file) so we don't have to drop
    // the `private(set)` guard on health/shield for the wider module.

    var healthInternal: CGFloat { health }
    var shieldInternal: CGFloat { shield }
    func setHealth(_ v: CGFloat) { health = v }
    func setShield(_ v: CGFloat) { shield = v }

    var healthFraction: CGFloat { maxHealth > 0 ? health / maxHealth : 0 }
    var shieldFraction: CGFloat { maxShield > 0 ? shield / maxShield : 0 }
    var batteryFraction: CGFloat { maxBattery > 0 ? battery / maxBattery : 0 }
}
