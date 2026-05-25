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

    /// Active speed boost — non-zero `remaining` while the ship is boosted.
    private(set) var speedBoostRemaining: TimeInterval = 0
    private(set) var speedBoostCooldownRemaining: TimeInterval = 0

    /// Time until the C-button special weapon is available again.
    var specialCooldownRemaining: TimeInterval = 0

    /// Time until the Transporter Beam (A+B combo) can be engaged again.
    var transporterCooldownRemaining: TimeInterval = 0

    /// Quantum torpedoes in inventory (collected as power-up, used by Transporter Beam).
    var quantumTorpedoCount: Int = 1

    /// Active effects on this ship.
    private(set) var activeBuffs: [ShipBuff] = []

    /// Quantum Torpedo currently planted on this ship (Section 6). Detonates when its 10s timer
    /// expires. The host can press A+B again to defend by transporting it back to the attacker
    /// (if in range and ship has_transporter).
    var plantedTorpedo: QuantumTorpedo? = nil

    /// Speed-boost configuration (Section 5 universal capability — Section 7 battery cost).
    private static let boostDurationSeconds: TimeInterval = 3.0
    private static let boostMultiplier: CGFloat = 3.0
    private static let boostBatteryCost: CGFloat = 15.0   // % of max battery

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

        // EM-disrupted ships can't thrust, brake, or turn (Section 6 EM Blast)
        let disrupted = isEMDisrupted
        let effectiveThrust = thrust && !disrupted
        let effectiveBrake = brake && !disrupted
        let effectiveTurn: CGFloat = disrupted ? 0 : turn

        // Turning
        if abs(effectiveTurn) > 0.01 {
            heading += effectiveTurn * turnRatePerSecond * dtf
        }

        // Thrust
        if effectiveThrust {
            let dx = cos(heading) * accelerationPerSecond * dtf
            let dy = sin(heading) * accelerationPerSecond * dtf
            velocity.dx += dx
            velocity.dy += dy
            // Clamp to max speed (boost-aware)
            let cap = effectiveMaxSpeed
            let speed = hypot(velocity.dx, velocity.dy)
            if speed > cap {
                let scale = cap / speed
                velocity.dx *= scale
                velocity.dy *= scale
            }
            thrusterFlare.alpha = hasBuff(.cloaked) ? 0.4 : 1.0
        } else {
            // Fade thruster
            thrusterFlare.alpha = max(0, thrusterFlare.alpha - CGFloat(dt) * 4)
        }

        // Brake — fraction of current velocity removed per second.
        if effectiveBrake {
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

        // Speed boost cooldown + active duration tick
        speedBoostCooldownRemaining = max(0, speedBoostCooldownRemaining - dt)
        speedBoostRemaining = max(0, speedBoostRemaining - dt)
        specialCooldownRemaining = max(0, specialCooldownRemaining - dt)
        transporterCooldownRemaining = max(0, transporterCooldownRemaining - dt)

        // Tick + apply buffs
        tickBuffs(dt: dt)

        // Cloaked visual
        let cloaked = hasBuff(.cloaked)
        // While cloaked the player still sees a translucent silhouette; the AI's separate
        // targeting penalty is enforced inside AIController.
        hull.alpha = cloaked ? 0.35 : 1.0

        // Self-destruct timer expired → trigger blast event (handled by CombatScene observing
        // `selfDestructTimerExpiredFlag`).
        if hadSelfDestructLastFrame && !hasBuff(.selfDestructArmed) {
            selfDestructJustExpired = true
        }
        hadSelfDestructLastFrame = hasBuff(.selfDestructArmed)

        // allowSpecials is read by the weapon / specials systems; Ship just integrates physics here.
        _ = allowSpecials
    }

    // MARK: - Buff helpers

    /// Add (or refresh) a buff. If a buff of the same kind exists, its duration is extended
    /// to the longer of the two and its magnitude is updated to the new value.
    func applyBuff(_ buff: ShipBuff) {
        if let i = activeBuffs.firstIndex(where: { $0.kind == buff.kind }) {
            activeBuffs[i].remainingSeconds = max(activeBuffs[i].remainingSeconds, buff.remainingSeconds)
        } else {
            activeBuffs.append(buff)
        }
    }

    /// Returns true if a buff of the given kind is currently active.
    func hasBuff(_ kind: ShipBuff.Kind) -> Bool {
        activeBuffs.contains { $0.kind == kind && $0.remainingSeconds > 0 }
    }

    /// Active buff magnitude for the given kind (0 if none).
    func buffMagnitude(_ kind: ShipBuff.Kind) -> CGFloat {
        activeBuffs.first { $0.kind == kind && $0.remainingSeconds > 0 }?.magnitude ?? 0
    }

    /// Remove all buffs (used between matches).
    func clearBuffs() {
        activeBuffs.removeAll()
        hull.alpha = 1.0
    }

    private var hadSelfDestructLastFrame: Bool = false
    /// Read-and-cleared by CombatScene to know when to spawn the self-destruct blast.
    var selfDestructJustExpired: Bool = false

    private func tickBuffs(dt: TimeInterval) {
        for i in activeBuffs.indices {
            activeBuffs[i].remainingSeconds -= dt
        }
        // Apply repair-drone HP-over-time per second (magnitude is fraction of max HP/s).
        if hasBuff(.repairDrone) {
            let mag = buffMagnitude(.repairDrone)
            adjustHealth(by: mag * maxHealth * CGFloat(dt))
        }
        // Drop expired buffs
        activeBuffs.removeAll { $0.remainingSeconds <= 0 }
    }

    /// Attempt to engage Speed Boost (universal capability, Section 5 / Section 7).
    /// Returns true on success, false if locked by cooldown / battery / specials lock.
    /// Fun Modifiers: unlimitedBoost zeroes cooldown + cost for the player ship only.
    @discardableResult
    func tryEngageSpeedBoost(allowSpecials: Bool) -> Bool {
        guard allowSpecials else { return false }
        let unlimited = side == .player && FunModifiers.shared.unlimitedBoost
        if !unlimited {
            guard speedBoostCooldownRemaining <= 0 else { return false }
            let cost = (Self.boostBatteryCost / 100.0) * maxBattery
            guard battery >= cost else { return false }
            battery -= cost
        }
        speedBoostRemaining = Self.boostDurationSeconds
        speedBoostCooldownRemaining = unlimited ? 0 : TimeInterval(definition.stats.speedBoostCooldownSeconds)
        return true
    }

    /// Effective maximum speed including boost + superSpeed-buff scaling.
    var effectiveMaxSpeed: CGFloat {
        var s = maxSpeed
        if speedBoostRemaining > 0 { s *= Self.boostMultiplier }
        let superMag = buffMagnitude(.superSpeed)
        if superMag > 1 { s *= superMag }
        return s
    }

    /// True while the ship's engines / weapons are EM-disrupted (Prism Hunter's special).
    var isEMDisrupted: Bool { hasBuff(.emDisrupted) }

    /// Outgoing damage multiplier — from Mimic special / damageMultiplier power-up.
    var outgoingDamageMultiplier: CGFloat {
        let m = buffMagnitude(.damageMultiplier)
        return m > 0 ? m : 1.0
    }

    // MARK: - Damage application

    /// Apply incoming damage. Returns the amount actually subtracted from health.
    /// Section 7: shield absorbs first, then health.
    /// Fun Modifiers: when invincibility is on AND this is the player ship, no damage applies.
    /// Buffs: `invulnerability` short-circuits damage for any ship (used by Titan Bulwark's special).
    @discardableResult
    func takeDamage(_ amount: CGFloat) -> CGFloat {
        if side == .player && FunModifiers.shared.invincibility { return 0 }
        if hasBuff(.invulnerability) { return 0 }
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
        speedBoostRemaining = 0
        speedBoostCooldownRemaining = 0
        specialCooldownRemaining = 0
        transporterCooldownRemaining = 0
        quantumTorpedoCount = 1
        clearBuffs()
        hadSelfDestructLastFrame = false
        selfDestructJustExpired = false
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
