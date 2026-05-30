import SpriteKit
import GameplayKit

/// The active 2D arena where ship-to-ship combat happens.
///
/// **Plan reference:** Sections 4 (world model + camera + planet field), 5 (ship), 6 (weapons),
/// 7 (HP/shield/battery), 14 (visuals), 23 (mockup fixes — `allowSpecials: Bool` flag pattern,
/// gravity ramp, semi-transparent countdown digit).
final class CombatScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Injected dependencies
    weak var input: InputState?
    weak var gameState: GameState?
    var playerShipID: String = "aegis_cruiser"
    var enemyShipID: String = "void_reaper"

    // MARK: - Scene nodes
    private let worldNode = SKNode()
    private let cameraNode = SKCameraNode()
    private var playerShip: Ship!
    private var enemyShip: Ship!
    private var playerPrimary: Weapon!
    private var playerSecondary: Weapon!
    private var enemyPrimary: Weapon!
    private var enemySecondary: Weapon!
    private var aiController: AIController!
    private var activeProjectiles: [Projectile] = []
    private var activePowerUps: [PowerUp] = []
    private var planets: [Planet] = []
    private var powerUpManager: PowerUpManager!
    private var weaponsCatalog: [WeaponDefinition] = []

    /// Active Quantum Torpedoes (one per ship at most — Section 6).
    private var activeTorpedoes: [QuantumTorpedo] = []
    private var singularityDebris: [SingularityDebris] = []

    /// Set true on the frame a Quantum Torpedo kills a ship — drives the FATALITY banner.
    private var lastKillByTorpedo: Bool = false

    /// Set true when the player's self-destruct blast triggers a chain that destroys the enemy
    /// during the same match — Section 17 selfDestructWins stat.
    private var playerWonViaSelfDestruct: Bool = false

    // Edge-trigger button state — fires specials on rising-edge only, not while held.
    private var lastCHandled: Bool = false
    private var lastABHandled: Bool = false   // Transporter Beam combo
    private var lastBCHandled: Bool = false   // Cloak combo
    private var lastACHandled: Bool = false   // Self-Destruct combo
    private var lastShieldToggleHandled: Bool = false

    // MARK: - Match management
    private let matchManager = MatchManager()

    // MARK: - Juice (camera shake, time dilation, shockwaves)
    private let juice = JuiceSystem()

    // MARK: - Low-HP smoke trails (one per ship)
    private var playerSmoke: SKEmitterNode?
    private var enemySmoke: SKEmitterNode?

    // MARK: - Destruction tracking — fires destruction juice exactly once per ship lifecycle
    private var playerWasDestroyed: Bool = false
    private var enemyWasDestroyed: Bool = false

    // MARK: - Damage tracking — fires shake/feedback only on rising-edge damage events
    private var lastPlayerHealth: CGFloat = 1.0
    private var lastEnemyHealth: CGFloat = 1.0

    // MARK: - Pause
    /// When true, the update loop skips ship integration, AI, weapons, gravity, and match-state.
    /// Named `customPaused` because `SKScene.isPaused` already exists and it pauses *actions*
    /// rather than our own update logic — we want both, so we own the flag explicitly.
    var customPaused: Bool = false {
        didSet { self.isPaused = customPaused }   // also pause SK's action engine for cleanliness
    }
    private var lastZHandled: Bool = false   // edge-trigger Z button for speed boost

    // MARK: - World geometry
    private var worldRect: CGRect = .zero

    // MARK: - Frame timing
    private var lastUpdate: TimeInterval = 0

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = .black
        scaleMode = .resizeFill
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        // ProMotion / 120Hz support — drives smooth analog stick + camera-follow on capable devices.
        #if os(iOS)
        let maxFPS = view.window?.windowScene?.screen.maximumFramesPerSecond ?? 60
        view.preferredFramesPerSecond = maxFPS
        #endif

        let w = size.width * WorldConstants.worldScaleFactor
        let h = size.height * WorldConstants.worldScaleFactor
        worldRect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)

        addChild(worldNode)
        addChild(cameraNode)
        self.camera = cameraNode

        buildStarfield()
        buildPlanetField()
        spawnShips()
        wireWeapons()

        powerUpManager = PowerUpManager(definitions: PowerUpDefinition.loadAll())

        // One-time minimap data — captured once at scene build, never changes during a match.
        gameState?.worldRect = worldRect
        gameState?.planetMarkers = planets.map { PlanetMarker(position: $0.position, radius: $0.radius) }

        cameraNode.position = playerShip.position
        publishGameState()
    }

    private func buildStarfield() {
        let specs: [(count: Int, alphaRange: ClosedRange<CGFloat>, sizeRange: ClosedRange<CGFloat>)] = [
            (600, 0.20...0.50, 0.4...1.0),
            (300, 0.40...0.75, 0.7...1.6),
            (120, 0.60...0.95, 1.2...2.4),
        ]
        for spec in specs {
            let layer = SKNode()
            layer.zPosition = -100
            for _ in 0..<spec.count {
                let r = CGFloat.random(in: spec.sizeRange) / 2
                let star = SKShapeNode(circleOfRadius: r)
                star.fillColor = .white
                star.strokeColor = .clear
                star.alpha = CGFloat.random(in: spec.alphaRange)
                star.position = CGPoint(
                    x: CGFloat.random(in: worldRect.minX...worldRect.maxX),
                    y: CGFloat.random(in: worldRect.minY...worldRect.maxY)
                )
                layer.addChild(star)
            }
            worldNode.addChild(layer)
        }
    }

    private func buildPlanetField() {
        // Section 4: 10–14 planets, ≥280 units apart, avoiding the spawn corridor.
        planets = Planet.generateField(world: worldRect, spawnCorridorHalfHeight: size.height * 0.75)
        for planet in planets {
            worldNode.addChild(planet)
        }
    }

    private func spawnShips() {
        let ships = ShipDefinition.loadAll()
        guard let playerDef = ships.first(where: { $0.id == playerShipID }) ?? ships.first else {
            assertionFailure("Ships.json missing or empty — cannot scaffold combat.")
            return
        }
        let enemyDef = ships.first(where: { $0.id == enemyShipID }) ?? playerDef

        playerShip = Ship(definition: playerDef, side: .player)
        playerShip.position = CGPoint(x: -size.width * WorldConstants.enemySpawnViewports / 2, y: 0)
        playerShip.heading = 0
        worldNode.addChild(playerShip)

        enemyShip = Ship(definition: enemyDef, side: .opponent)
        enemyShip.position = CGPoint(x:  size.width * WorldConstants.enemySpawnViewports / 2, y: 0)
        enemyShip.heading = .pi
        worldNode.addChild(enemyShip)

        gameState?.playerName = playerDef.name.uppercased()
        gameState?.enemyName = enemyDef.name.uppercased()
    }

    private func wireWeapons() {
        let weapons = WeaponDefinition.loadAll()
        weaponsCatalog = weapons

        // Audit fix: replaced force-unwraps with a safe-fallback weapon so a missing JSON entry
        // can't crash the app in production. Falls back to "laser_cannon" if the lookup fails.
        playerPrimary = makeWeapon(weaponID: playerShip.definition.weapons.primary,
                                   fireRateFrames: playerShip.definition.stats.primaryFireRateFrames,
                                   in: weapons)
            ?? safeWeaponFallback(in: weapons, fireRateFrames: playerShip.definition.stats.primaryFireRateFrames)
        playerSecondary = makeWeapon(weaponID: playerShip.definition.weapons.secondary,
                                     fireRateFrames: playerShip.definition.stats.secondaryFireRateFrames,
                                     in: weapons)
            ?? safeWeaponFallback(in: weapons, fireRateFrames: playerShip.definition.stats.secondaryFireRateFrames)
        enemyPrimary = makeWeapon(weaponID: enemyShip.definition.weapons.primary,
                                  fireRateFrames: enemyShip.definition.stats.primaryFireRateFrames,
                                  in: weapons)
            ?? safeWeaponFallback(in: weapons, fireRateFrames: enemyShip.definition.stats.primaryFireRateFrames)
        enemySecondary = makeWeapon(weaponID: enemyShip.definition.weapons.secondary,
                                    fireRateFrames: enemyShip.definition.stats.secondaryFireRateFrames,
                                    in: weapons)
            ?? safeWeaponFallback(in: weapons, fireRateFrames: enemyShip.definition.stats.secondaryFireRateFrames)

        let savedDifficulty = UserDefaults.standard.string(forKey: "settings.aiDifficulty") ?? "captain"
        let diff = AIController.Difficulty(rawValue: savedDifficulty) ?? .captain
        aiController = AIController(difficulty: diff)
    }

    /// Last-resort fallback weapon — used if a ship's `weapons.json` ID lookup fails so the
    /// game still launches instead of crashing on a force-unwrap. Picks "laser_cannon" if it
    /// exists in the catalog (it does in stock Weapons.json), otherwise the first entry.
    private func safeWeaponFallback(in weapons: [WeaponDefinition], fireRateFrames: Int) -> Weapon {
        let def = weapons.first { $0.id == "laser_cannon" } ?? weapons[0]
        return Weapon(definition: def, fireRateFrames: fireRateFrames)
    }

    private func makeWeapon(weaponID: String, fireRateFrames: Int, in weapons: [WeaponDefinition]) -> Weapon? {
        guard let def = weapons.first(where: { $0.id == weaponID }) else {
            assertionFailure("Weapons.json missing entry: \(weaponID)")
            return nil
        }
        return Weapon(definition: def, fireRateFrames: fireRateFrames)
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        let rawDt = lastUpdate == 0 ? 1.0 / 60.0 : min(0.05, currentTime - lastUpdate)
        lastUpdate = currentTime

        if customPaused {
            // Freeze gameplay; still tick the HUD so the pause overlay reads current values.
            publishGameState()
            return
        }

        // Apply time dilation to gameplay dt; juice + HUD still tick at real time.
        let dt = rawDt * TimeInterval(juice.currentTimeScale)

        let allowSpecials = matchManager.allowSpecials

        // Read input
        let thrust = input?.xPressed ?? false
        let brake  = input?.yPressed ?? false
        let turn   = input?.turnDirection ?? 0
        let firing1 = input?.aPressed ?? false
        let firing2 = input?.bPressed ?? false
        let zPressed = input?.zPressed ?? false
        let cPressed = input?.cPressed ?? false

        // Edge-trigger speed boost: only engage on the rising edge of Z so a held button
        // doesn't spam boost attempts every frame.
        if zPressed && !lastZHandled {
            if playerShip.tryEngageSpeedBoost(allowSpecials: allowSpecials) {
                HapticsSystem.shared.play(.speedBoostEngage)
                AudioSystem.shared.play(.speedBoostEngage)
            }
        }
        lastZHandled = zPressed

        // Edge-trigger C-button: fire player's special. Combos (A+B, B+C, A+C) take precedence
        // when more than one of those buttons is pressed — they're checked in Iteration K.
        let abCombo = firing1 && firing2
        let bcCombo = firing2 && cPressed
        let acCombo = firing1 && cPressed
        let plainC = cPressed && !bcCombo && !acCombo
        if plainC && !lastCHandled {
            handleSpecialButton(for: playerShip, opponent: enemyShip)
        }
        lastCHandled = plainC

        // A+B combo: Transporter Beam → Quantum Torpedo (Section 6).
        if abCombo && !lastABHandled {
            handleTransporterBeam(from: playerShip, opponent: enemyShip)
        }
        lastABHandled = abCombo

        // B+C combo: Cloaking Device (Section 5 universal capability for has_cloak ships).
        if bcCombo && !lastBCHandled {
            engageCloak(on: playerShip)
        }
        lastBCHandled = bcCombo

        // A+C combo: Self-Destruct (universal, Section 5).
        if acCombo && !lastACHandled {
            armSelfDestruct(on: playerShip)
        }
        lastACHandled = acCombo

        // Shield up/down toggle (Section 7 / dedicated HUD button or `R` key).
        let shieldTogglePressed = input?.shieldTogglePressed ?? false
        if shieldTogglePressed && !lastShieldToggleHandled {
            let nowRaised = playerShip.toggleShield()
            HapticsSystem.shared.play(nowRaised ? .shieldRaise : .shieldBroken)
            AudioSystem.shared.play(nowRaised ? .shieldRaise : .shieldLower)
        }
        lastShieldToggleHandled = shieldTogglePressed

        // Phase 1: ships only move/fire when not in series-end. During pre-match we DO allow
        // primary + secondary firing (Section 23 #2) and movement; specials are locked.
        let canControlPlayer = !matchManager.isSeriesOver

        // Player integration
        playerShip.update(dt: dt,
                          thrust: canControlPlayer && thrust,
                          brake: canControlPlayer && brake,
                          turn: canControlPlayer ? turn : 0,
                          allowSpecials: allowSpecials)

        // AI integration — Section 23 #2 also gives the AI primary/secondary during practice
        // but at reduced cadence. We model the cadence reduction by gating fire decisions to a
        // 60% / 20% rate during pre-match.
        let aiDecision = aiController.decide(dt: dt,
                                             ownShip: enemyShip,
                                             target: playerShip,
                                             allowSpecials: allowSpecials,
                                             world: worldRect)
        // Audit fix: when cadence cut is 1.0 (full match) we don't need a random roll at all.
        // This skips ~120 random-number generations per second during active match.
        let allowFullCadence = matchManager.allowSpecials
        let aiFirePrimary: Bool = {
            guard aiDecision.firePrimary else { return false }
            if allowFullCadence { return true }
            return CGFloat.random(in: 0...1) < 0.6
        }()
        let aiFireSecondary: Bool = {
            guard aiDecision.fireSecondary else { return false }
            if allowFullCadence { return true }
            return CGFloat.random(in: 0...1) < 0.2
        }()

        enemyShip.update(dt: dt,
                         thrust: aiDecision.thrust,
                         brake: aiDecision.brake,
                         turn: aiDecision.turn,
                         allowSpecials: allowSpecials)

        // Gravity (ramps during last 5s of countdown, full during active match)
        applyPlanetGravity(to: playerShip, dt: dt)
        applyPlanetGravity(to: enemyShip, dt: dt)

        // Weapons (primary + secondary always allowed during pre-match per Section 23 #2)
        playerPrimary.tick(dt: dt)
        playerSecondary.tick(dt: dt)
        enemyPrimary.tick(dt: dt)
        enemySecondary.tick(dt: dt)
        if canControlPlayer && firing1, let shot = playerPrimary.fire(from: playerShip) {
            worldNode.addChild(shot)
            activeProjectiles.append(shot)
            HapticsSystem.shared.play(.primaryFire)
            AudioSystem.shared.play(.primaryFire)
        }
        if canControlPlayer && firing2, let shot = playerSecondary.fire(from: playerShip, target: enemyShip) {
            worldNode.addChild(shot)
            activeProjectiles.append(shot)
            HapticsSystem.shared.play(.secondaryFire)
            AudioSystem.shared.play(.secondaryFire)
        }
        // AI weapon fires produce audio (audible in the arena) but never haptics — Section 13.
        if aiFirePrimary, let shot = enemyPrimary.fire(from: enemyShip) {
            worldNode.addChild(shot)
            activeProjectiles.append(shot)
            AudioSystem.shared.play(.primaryFire)
        }
        if aiFireSecondary, let shot = enemySecondary.fire(from: enemyShip, target: playerShip) {
            worldNode.addChild(shot)
            activeProjectiles.append(shot)
            AudioSystem.shared.play(.secondaryFire)
        }
        if aiDecision.fireSpecial {
            handleSpecialButton(for: enemyShip, opponent: playerShip)
        }

        // Projectile lifecycle
        activeProjectiles.removeAll { proj in
            let alive = proj.update(dt: dt, world: worldRect)
            if !alive { proj.removeFromParent() }
            return !alive
        }

        // Quantum Torpedo lifecycle — Section 6, ticks even when allowSpecials=false so the
        // 10s timer doesn't pause if a torpedo somehow lingered across phase boundaries.
        tickTorpedoes(dt: dt)

        // Self-Destruct: when the armed buff has just expired, detonate.
        if playerShip.selfDestructJustExpired {
            playerShip.selfDestructJustExpired = false
            detonateSelfDestruct(on: playerShip, opponent: enemyShip)
        }
        if enemyShip.selfDestructJustExpired {
            enemyShip.selfDestructJustExpired = false
            detonateSelfDestruct(on: enemyShip, opponent: playerShip)
        }

        // Power-up lifecycle (Section 8: spawn during active match only; despawn after 12s)
        activePowerUps.removeAll { p in
            let alive = p.tick(dt: dt)
            if !alive { p.removeFromParent() }
            return !alive
        }
        if matchManager.allowSpecials {
            if let spawn = powerUpManager.update(
                dt: dt,
                playerHealthFraction: playerShip.healthFraction,
                enemyHealthFraction: enemyShip.healthFraction,
                playerPos: playerShip.position,
                enemyPos: enemyShip.position,
                viewport: size,
                world: worldRect
            ) {
                spawn.powerUp.position = spawn.position
                worldNode.addChild(spawn.powerUp)
                activePowerUps.append(spawn.powerUp)
            }
        }

        // World boundary — wrap in toroidal mode, bounce in bounded mode.
        // When the player wraps, mirror the same delta onto the camera so the view never jumps.
        let playerWrapDelta = PhysicsEngine.enforceWorldBoundaries(ship: playerShip, world: worldRect)
        PhysicsEngine.enforceWorldBoundaries(ship: enemyShip, world: worldRect)
        // Power-ups wrap too in toroidal mode (so they don't fall off the world).
        if WorldConstants.worldMode == .toroidal {
            for pu in activePowerUps {
                PhysicsEngine.wrap(node: pu, world: worldRect)
            }
        }
        if playerWrapDelta.dx != 0 || playerWrapDelta.dy != 0 {
            cameraNode.position.x += playerWrapDelta.dx
            cameraNode.position.y += playerWrapDelta.dy
        }

        // Camera follow (lerp toward player), then layer juice-system shake on top.
        let lerp = WorldConstants.cameraLerp * min(1, CGFloat(rawDt) * 60)
        var followTarget = cameraNode.position
        followTarget.x += (playerShip.position.x - cameraNode.position.x) * lerp
        followTarget.y += (playerShip.position.y - cameraNode.position.y) * lerp
        // Clamp follow target to world before passing to juice (juice adds shake offset on top).
        followTarget = clampToCameraBounds(followTarget)
        juice.apply(dt: rawDt, to: cameraNode, cameraTargetPosition: followTarget)

        // Damage detection — shake + haptics + screen vignette on rising-edge health drops
        // for the PLAYER only. Section 13 critical rule: never haptic for AI-side events.
        // Audit fix: shake tiers bumped one notch — even small primary-fire hits now produce
        // visibly perceptible feedback (was light → medium → heavy, now medium → heavy → massive).
        let pf = playerShip.healthFraction
        if pf < lastPlayerHealth {
            let drop = lastPlayerHealth - pf
            let dropHP = drop * playerShip.maxHealth
            if dropHP > 15 {
                juice.shake(.massive)
                HapticsSystem.shared.play(.damageHeavy)
                AudioSystem.shared.play(.damageHeavy)
            } else if dropHP > 5 {
                juice.shake(.heavy)
                HapticsSystem.shared.play(.damageMedium)
                AudioSystem.shared.play(.damageHeavy)
            } else {
                juice.shake(.medium)
                HapticsSystem.shared.play(.damageLight)
                AudioSystem.shared.play(.damageLight)
            }
            // Universal red-vignette pulse on player damage — easy peripheral signal that you
            // were hit. Strength scales with damage so big hits look big.
            let vignetteStrength = min(1.0, dropHP / 20.0)
            juice.flashRedVignette(strength: vignetteStrength, in: cameraNode)
        }
        lastPlayerHealth = pf
        lastEnemyHealth = enemyShip.healthFraction

        // Destruction — fire shockwave + slow-mo exactly once per lifecycle.
        if !playerWasDestroyed && playerShip.isDestroyed {
            playerWasDestroyed = true
            juice.spawnDestructionExplosion(at: playerShip.position,
                                            shipColor: SKColor(red: 0, green: 1.0, blue: 0.84, alpha: 1),
                                            in: worldNode)
            juice.slowMo(.shipDestruction)
            juice.shake(.heavy)
            juice.hitStop(GameFeel.hitStopKill)
            juice.cameraPunch(in: cameraNode)
            HapticsSystem.shared.play(.playerDestroyed)
            AudioSystem.shared.play(.destruction)
        }
        if !enemyWasDestroyed && enemyShip.isDestroyed {
            enemyWasDestroyed = true
            juice.spawnDestructionExplosion(at: enemyShip.position,
                                            shipColor: SKColor(red: 1.0, green: 0.2, blue: 0.4, alpha: 1),
                                            in: worldNode)
            juice.slowMo(.shipDestruction)
            juice.shake(.medium)
            juice.hitStop(GameFeel.hitStopKill)
            juice.cameraPunch(in: cameraNode)
            AudioSystem.shared.play(.destruction)   // audible to player but no haptic on AI death
        }

        // Low-HP smoke trails (Section 14 SuperGrok addition)
        updateLowHPSmoke()

        // Match state advance — pipe FATALITY flag through (Section 4 step 8).
        if let change = matchManager.update(
            dt: dt,
            playerDestroyed: playerShip.isDestroyed,
            enemyDestroyed: enemyShip.isDestroyed,
            playerHealthFraction: playerShip.healthFraction,
            enemyHealthFraction: enemyShip.healthFraction,
            playerShieldFraction: playerShip.shieldFraction,
            enemyShieldFraction: enemyShip.shieldFraction,
            lastKillByQuantumTorpedo: lastKillByTorpedo
        ) {
            handlePhaseChange(change)
        }
        // Reset the flag once consumed.
        lastKillByTorpedo = false

        publishGameState()
    }

    private func applyPlanetGravity(to ship: Ship, dt: TimeInterval) {
        // Fun Modifier: noPlanetGravity disables the gravity force entirely (collision damage
        // still applies because that's a separate SpriteKit physics contact).
        if FunModifiers.shared.noPlanetGravity { return }
        let ramp = matchManager.gravityRampFactor
        guard ramp > 0 else { return }
        let G: CGFloat = 18000   // tuned for ~Star Control style influence at ~150 unit range
        let dtf = CGFloat(dt)
        for planet in planets {
            let dx = planet.position.x - ship.position.x
            let dy = planet.position.y - ship.position.y
            let distSq = dx*dx + dy*dy
            // Skip if very far away (perf + avoid summing tiny contributions across all planets).
            if distSq > 800 * 800 { continue }
            let minDistSq: CGFloat = (planet.radius * 1.5) * (planet.radius * 1.5)
            let safeSq = max(minDistSq, distSq)
            let dist = sqrt(safeSq)
            let force = G * planet.gravMass * ramp / safeSq
            ship.velocity.dx += (dx / dist) * force * dtf
            ship.velocity.dy += (dy / dist) * force * dtf
        }
    }

    private func clampToCameraBounds(_ p: CGPoint) -> CGPoint {
        // In toroidal mode there are no walls — the camera can sit anywhere because the
        // wrap math keeps everything visible. Clamp only in bounded mode.
        guard WorldConstants.worldMode == .bounded else { return p }
        let halfW = size.width / 2
        let halfH = size.height / 2
        return CGPoint(
            x: min(max(p.x, worldRect.minX + halfW), worldRect.maxX - halfW),
            y: min(max(p.y, worldRect.minY + halfH), worldRect.maxY - halfH)
        )
    }

    /// Attach (or detach) a low-HP smoke emitter to each ship based on current health %.
    /// Section 14 SuperGrok addition: visible <30%, intensifies <15% with orange smoke.
    private func updateLowHPSmoke() {
        playerSmoke = updateSmoke(existing: playerSmoke, on: playerShip,
                                  cleanColor: SKColor(white: 0.7, alpha: 1))
        enemySmoke  = updateSmoke(existing: enemySmoke, on: enemyShip,
                                  cleanColor: SKColor(white: 0.7, alpha: 1))
    }

    private func updateSmoke(existing: SKEmitterNode?, on ship: Ship, cleanColor: SKColor) -> SKEmitterNode? {
        let hp = ship.healthFraction
        let needsSmoke = hp < 0.30 && !ship.isDestroyed
        guard needsSmoke else {
            existing?.removeFromParent()
            return nil
        }
        let emitter = existing ?? makeSmokeEmitter()
        if existing == nil {
            ship.addChild(emitter)
        }
        // Critical state: turn smoke orange below 15% and spit more particles.
        if hp < 0.15 {
            emitter.particleColor = SKColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 1.0)
            emitter.particleBirthRate = 25
        } else {
            emitter.particleColor = cleanColor
            emitter.particleBirthRate = 10
        }
        return emitter
    }

    private func makeSmokeEmitter() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = nil
        e.particleBirthRate = 10
        e.particleLifetime = 1.0
        e.particleLifetimeRange = 0.4
        e.particleSize = CGSize(width: 8, height: 8)
        e.particleScale = 0.6
        e.particleScaleRange = 0.4
        e.particleScaleSpeed = 0.5
        e.particleAlpha = 0.7
        e.particleAlphaRange = 0.2
        e.particleAlphaSpeed = -0.7
        e.particleSpeed = 30
        e.particleSpeedRange = 20
        e.particleColor = SKColor(white: 0.7, alpha: 1)
        e.particleColorBlendFactor = 1
        e.emissionAngle = -.pi / 2     // backward relative to ship's local +y forward
        e.emissionAngleRange = 0.6
        e.zPosition = -1
        e.position = CGPoint(x: 0, y: -8)   // attach behind the hull
        return e
    }

    private func publishGameState() {
        guard let gs = gameState else { return }
        gs.playerHealth = playerShip.healthFraction
        gs.playerShield = playerShip.shieldFraction
        gs.playerBattery = playerShip.batteryFraction
        gs.enemyHealth = enemyShip.healthFraction
        gs.enemyShield = enemyShip.shieldFraction

        // Match phase mirror
        switch matchManager.phase {
        case .preMatch(let remaining):
            gs.inPreMatch = true
            gs.inActiveMatch = false
            gs.preMatchSecondsRemaining = remaining
            gs.matchSecondsRemaining = matchManager.matchDuration
        case .active(let remaining):
            gs.inPreMatch = false
            gs.inActiveMatch = true
            gs.matchSecondsRemaining = remaining
        case .interMatch:
            gs.inPreMatch = false
            gs.inActiveMatch = false
        case .seriesEnded(let winner, let fatality):
            gs.inPreMatch = false
            gs.inActiveMatch = false
            gs.seriesEnded = true
            gs.seriesWinnerIsPlayer = (winner == .player)
            gs.isFatality = fatality
        }
        gs.matchPhaseLabel = matchManager.phaseLabel
        gs.matchNumber = matchManager.matchNumber
        gs.playerWins = matchManager.playerWins
        gs.opponentWins = matchManager.opponentWins

        // Off-screen indicator
        let cameraPos = cameraNode.position
        let halfW = size.width / 2
        let halfH = size.height / 2
        let cameraRect = CGRect(x: cameraPos.x - halfW, y: cameraPos.y - halfH,
                                width: size.width, height: size.height)
        gs.enemyOnScreen = cameraRect.contains(enemyShip.position)
        // Use wrap-aware delta so the off-screen indicator always points to the closest path
        // through the world (which in toroidal mode may be the short way around an edge).
        let camToEnemy = PhysicsEngine.shortestDelta(from: cameraPos, to: enemyShip.position, world: worldRect)
        gs.enemyScreenDirection = CGVector(dx: camToEnemy.dx, dy: -camToEnemy.dy)
        let playerToEnemy = PhysicsEngine.shortestDelta(from: playerShip.position, to: enemyShip.position, world: worldRect)
        gs.enemyDistanceUnits = hypot(playerToEnemy.dx, playerToEnemy.dy)

        // Minimap (Section 4)
        gs.cameraViewport = cameraRect
        gs.playerWorldPos = playerShip.position
        gs.enemyWorldPos = enemyShip.position
        // Avoid allocating a fresh array every frame when no power-ups are active (the common
        // case between spawns). The `powerUpMarkers` didSet equality guard then skips the publish.
        if activePowerUps.isEmpty {
            if !gs.powerUpMarkers.isEmpty { gs.powerUpMarkers = [] }
        } else {
            gs.powerUpMarkers = activePowerUps.map { $0.position }
        }
    }

    private func handlePhaseChange(_ change: MatchManager.PhaseChange) {
        switch change {
        case .countdownEnded:
            HapticsSystem.shared.play(.matchStart)
            AudioSystem.shared.play(.matchStart)
        case .matchEnded(let winner, let fatality):
            for p in activeProjectiles { p.removeFromParent() }
            activeProjectiles.removeAll()

            // Section 17: persist this match's result against the player's ship.
            // Fun Modifiers disable stat recording (per the Section 16.5 "MODIFIERS ACTIVE" rule).
            if !FunModifiers.shared.anyActive {
                let playerID = playerShip.definition.id
                if winner == .player {
                    LeaderboardStore.shared.recordWin(
                        shipID: playerID,
                        byFatality: fatality,
                        bySelfDestruct: playerWonViaSelfDestruct
                    )
                } else {
                    LeaderboardStore.shared.recordLoss(shipID: playerID)
                }
                LeaderboardStore.shared.flushDamage()
            }
            playerWonViaSelfDestruct = false   // reset for next match

            if winner == .player {
                HapticsSystem.shared.play(.roundWonByPlayer)
            } else {
                HapticsSystem.shared.play(.roundLostByPlayer)
            }
            AudioSystem.shared.play(.matchEnd)
            if fatality {
                HapticsSystem.shared.play(.fatality)
                AudioSystem.shared.play(.fatality)
            }
        case .nextMatchStarted:
            resetShipsForNextMatch()
            HapticsSystem.shared.play(.matchStart)
            AudioSystem.shared.play(.matchStart)
        case .seriesEnded(let winner, _):
            if winner == .player {
                HapticsSystem.shared.play(.seriesVictory)
                AudioSystem.shared.play(.victorySting)
            } else {
                HapticsSystem.shared.play(.seriesDefeat)
                AudioSystem.shared.play(.defeatSting)
            }
        }
    }

    private func resetShipsForNextMatch() {
        playerShip.fullyRestore()
        enemyShip.fullyRestore()
        // Re-position to the configured spawn
        let halfSpread = size.width * WorldConstants.enemySpawnViewports / 2
        playerShip.position = CGPoint(x: -halfSpread, y: 0)
        enemyShip.position = CGPoint(x:  halfSpread, y: 0)
        playerShip.heading = 0
        enemyShip.heading = .pi
        playerShip.velocity = .zero
        enemyShip.velocity = .zero

        // Clear juice-system bookkeeping so destruction can fire again next match.
        playerWasDestroyed = false
        enemyWasDestroyed = false
        lastPlayerHealth = 1.0
        lastEnemyHealth = 1.0
        playerSmoke?.removeFromParent(); playerSmoke = nil
        enemySmoke?.removeFromParent(); enemySmoke = nil

        // Clear lingering torpedoes (defensive) and singularity debris between matches.
        for t in activeTorpedoes { t.removeFromParent() }
        activeTorpedoes.removeAll()
        clearSingularityDebris()
    }

    // MARK: - Collisions

    func didBegin(_ contact: SKPhysicsContact) {
        let aBody = contact.bodyA
        let bBody = contact.bodyB

        if let proj = (aBody.node as? Projectile), let target = (bBody.node as? Ship) {
            handleProjectile(proj, hitting: target)
        } else if let proj = (bBody.node as? Projectile), let target = (aBody.node as? Ship) {
            handleProjectile(proj, hitting: target)
        } else if let proj = (aBody.node as? Projectile), bBody.categoryBitMask == PhysicsCategory.planet {
            removeProjectile(proj)
        } else if let proj = (bBody.node as? Projectile), aBody.categoryBitMask == PhysicsCategory.planet {
            removeProjectile(proj)
        } else if let pu = (aBody.node as? PowerUp), let ship = (bBody.node as? Ship) {
            handlePowerUp(pu, collectedBy: ship)
        } else if let pu = (bBody.node as? PowerUp), let ship = (aBody.node as? Ship) {
            handlePowerUp(pu, collectedBy: ship)
        } else if let debris = (aBody.node as? SingularityDebris), let ship = (bBody.node as? Ship) {
            handleSingularityHit(debris, ship: ship)
        } else if let debris = (bBody.node as? SingularityDebris), let ship = (aBody.node as? Ship) {
            handleSingularityHit(debris, ship: ship)
        }
    }

    // MARK: - Public hooks (called by CombatSceneView)

    /// Section 9: Pause → Restart Match counts as a loss for the current match. Forfeit the
    /// current match in MatchManager; the next-match flow kicks in automatically.
    func restartCurrentMatchAsLoss() {
        if let change = matchManager.forfeitCurrentMatch() {
            handlePhaseChange(change)
        }
    }

    /// Section 9: Pause → Quit to Menu counts as a forfeit. Records once against the player's
    /// current ship if a match is in progress and no Fun Modifier is active.
    func recordForfeitIfInProgress() {
        guard !FunModifiers.shared.anyActive else { return }
        // Only count as a forfeit if a real match is underway.
        if case .active = matchManager.phase {
            LeaderboardStore.shared.recordForfeit(shipID: playerShip.definition.id)
            LeaderboardStore.shared.flushDamage()
        }
    }

    private func handleSingularityHit(_ debris: SingularityDebris, ship: Ship) {
        ship.takeDamage(SingularityDebris.contactDamage)
        // Brief shake when the player ship makes contact.
        if ship.side == .player { juice.shake(.medium) }
    }

    private func handlePowerUp(_ pu: PowerUp, collectedBy ship: Ship) {
        let extraTime = pu.collect(by: ship)
        if extraTime > 0 {
            matchManager.extendActiveTimer(by: extraTime)
        }
        if ship.side == .player { HapticsSystem.shared.play(.powerUpCollected) }
        AudioSystem.shared.play(.powerUpCollect)
        pu.removeFromParent()
        activePowerUps.removeAll { $0 === pu }
    }

    private func handleProjectile(_ proj: Projectile, hitting target: Ship) {
        if proj.firedBy == target.side { return }
        let damage = proj.computeDamage(against: target)
        target.takeDamage(damage)
        // Phase 1 game feel: a brief hit-stop scaled to damage gives the impact weight. Fires for
        // both sides (unlike haptics, which are player-only) — freezing the sim reads globally.
        juice.hitStop(GameFeel.hitStopDuration(forDamage: damage))
        // Section 17: track damage on the PLAYER's ship only (their leaderboard entry).
        if proj.firedBy == .player && target.side == .opponent {
            LeaderboardStore.shared.addDamageDealt(shipID: playerShip.definition.id, amount: Double(damage))
        } else if proj.firedBy == .opponent && target.side == .player {
            LeaderboardStore.shared.addDamageTaken(shipID: playerShip.definition.id, amount: Double(damage))
        }
        removeProjectile(proj)
    }

    private func removeProjectile(_ proj: Projectile) {
        proj.removeFromParent()
        activeProjectiles.removeAll { $0 === proj }
    }

    // MARK: - Special weapon dispatch

    private func handleSpecialButton(for ship: Ship, opponent: Ship) {
        let result = SpecialWeaponSystem.execute(special: ship,
                                                 opponent: opponent,
                                                 allowSpecials: matchManager.allowSpecials,
                                                 weaponsCatalog: weaponsCatalog)
        applySpecialResult(result, for: ship, opponent: opponent)
    }

    private func applySpecialResult(_ result: SpecialWeaponResult, for ship: Ship, opponent: Ship) {
        switch result {
        case .fired:
            if ship.side == .player { HapticsSystem.shared.play(.specialFire) }
            AudioSystem.shared.play(.specialFire)
        case .rejected:
            return
        case .spawnHomingMissiles(let count):
            spawnHomingMissileSwarm(from: ship, count: count, target: opponent)
            if ship.side == .player { HapticsSystem.shared.play(.specialFire) }
            AudioSystem.shared.play(.specialFire)
        case .armedSelfDestruct:
            if ship.side == .player { HapticsSystem.shared.play(.selfDestructArmed) }
            AudioSystem.shared.play(.specialFire)
        }
    }

    // MARK: - Cloak (B+C combo, Section 5)

    /// Engage cloaking device. Only ships with `has_cloak == true` can use this combo.
    /// 8-second duration, 40% battery cost, drains 5% per second while cloaked.
    private func engageCloak(on ship: Ship) {
        guard matchManager.allowSpecials else { return }
        guard ship.definition.weapons.hasCloak else { return }
        guard !ship.hasBuff(.cloaked) else { return }   // already cloaked, no-op

        let cost = (40.0 / 100) * ship.maxBattery
        let unlimited = ship.side == .player && FunModifiers.shared.unlimitedBattery
        if !unlimited {
            guard ship.spendBattery(cost) else { return }
        }
        ship.applyBuff(ShipBuff(kind: .cloaked, remainingSeconds: 8, magnitude: 0))
        if ship.side == .player { HapticsSystem.shared.play(.cloakEngage) }
        AudioSystem.shared.play(.cloakEngage)
    }

    // MARK: - Self-Destruct (A+C combo, Section 5)

    private static let selfDestructBlastRadius: CGFloat = 220
    private static let selfDestructDamage: CGFloat = 80

    /// Arm the self-destruct sequence on `ship`. 4-second countdown — Section 6.
    private func armSelfDestruct(on ship: Ship) {
        guard matchManager.allowSpecials else { return }
        guard !ship.hasBuff(.selfDestructArmed) else { return }   // already armed
        ship.applyBuff(ShipBuff(kind: .selfDestructArmed, remainingSeconds: 4, magnitude: 0))
        if ship.side == .player { HapticsSystem.shared.play(.selfDestructArmed) }
    }

    /// Big radial blast — kills the source, damages anything in range.
    private func detonateSelfDestruct(on source: Ship, opponent: Ship) {
        // Visual + audio + slow-mo (player only)
        juice.spawnSingularityExplosion(at: source.position, in: worldNode)
        juice.slowMo(.shipDestruction)
        AudioSystem.shared.play(.destruction)
        if source.side == .player { juice.shake(.massive) }

        // Radial damage to opponent (and any other ships in future — supports >2 ships)
        let dx = PhysicsEngine.shortestDelta(from: source.position, to: opponent.position, world: worldRect).dx
        let dy = PhysicsEngine.shortestDelta(from: source.position, to: opponent.position, world: worldRect).dy
        let dist = hypot(dx, dy)
        if dist < Self.selfDestructBlastRadius {
            // Linear falloff
            let falloff = 1 - (dist / Self.selfDestructBlastRadius)
            opponent.takeDamage(Self.selfDestructDamage * falloff)
        }

        // Source is always destroyed by their own bomb
        source.takeDamage(source.maxHealth * 2)

        // Section 17 selfDestructWins tracking: if the player blew themselves up AND it killed
        // the enemy in the same beat, credit the player. (If both die, the match resolves via
        // MatchManager — the player still gets the SD win flag because they took the AI with them.)
        if source.side == .player && opponent.isDestroyed {
            playerWonViaSelfDestruct = true
        }
    }

    // MARK: - Transporter Beam + Quantum Torpedo (Section 6)

    private static let transporterBatteryCostPct: CGFloat = 40
    private static let transportBackRangeFraction: CGFloat = 0.25  // Section 6 defense option 2

    /// Try to engage the Transporter Beam from `from` aimed at `opponent`.
    ///
    /// Three possible flows:
    /// 1. If a torpedo is already planted on the firing ship's hull, this is a defense-attempt
    ///    to transport it back to the original attacker (requires being within 25% arena range
    ///    of the attacker).
    /// 2. Otherwise plant a torpedo on the opponent if conditions met.
    /// 3. Otherwise no-op (UI feedback for failure is a Phase 4 polish item).
    private func handleTransporterBeam(from: Ship, opponent: Ship) {
        // Defense option 2 — defender is firing back.
        if let plantedOnSelf = from.plantedTorpedo {
            attemptTransportBack(torpedo: plantedOnSelf, defender: from, attacker: opponent)
            return
        }

        // Otherwise: try to plant a torpedo on the opponent.
        attemptPlantTorpedo(from: from, target: opponent)
    }

    private func attemptPlantTorpedo(from: Ship, target: Ship) {
        guard matchManager.allowSpecials else { return }
        guard from.definition.weapons.hasTransporter else { return }
        guard from.transporterCooldownRemaining <= 0 else { return }
        guard from.quantumTorpedoCount > 0 else { return }

        // Section 6: BOTH ships must have shields fully lowered (transition complete).
        // Ships with no shield (maxShield == 0) auto-pass this check via shieldsFullyDown.
        guard from.shieldsFullyDown || from.maxShield == 0 else { return }
        guard target.shieldsFullyDown || target.maxShield == 0 else { return }
        guard target.plantedTorpedo == nil else { return }   // can't double-stack

        // Battery + ammo
        let cost = (Self.transporterBatteryCostPct / 100) * from.maxBattery
        let unlimited = from.side == .player && FunModifiers.shared.unlimitedBattery
        if !unlimited {
            guard from.spendBattery(cost) else { return }
        }
        from.quantumTorpedoCount -= 1
        from.transporterCooldownRemaining = TimeInterval(from.definition.stats.transporterCooldownSeconds)

        // Plant!
        let torpedo = QuantumTorpedo(originalFirer: from.side)
        torpedo.host = target
        target.plantedTorpedo = torpedo
        target.addChild(torpedo)
        activeTorpedoes.append(torpedo)

        // Haptic: player feels their own transporter engage, OR if a torpedo just landed on
        // them as the target (Section 13).
        if from.side == .player { HapticsSystem.shared.play(.transporterEngage) }
        if target.side == .player { HapticsSystem.shared.play(.torpedoPlantedOnPlayer) }
        AudioSystem.shared.play(.transporterEngage)
    }

    private func attemptTransportBack(torpedo: QuantumTorpedo, defender: Ship, attacker: Ship) {
        guard defender.definition.weapons.hasTransporter else { return }
        // Section 6: only works within 25% of arena range. (Audit fix: previously called
        // shortestDelta twice; now compute the delta once.)
        let delta = PhysicsEngine.shortestDelta(from: defender.position, to: attacker.position, world: worldRect)
        let dist = hypot(delta.dx, delta.dy)
        let maxRange = min(worldRect.width, worldRect.height) * Self.transportBackRangeFraction
        guard dist <= maxRange else { return }

        // Defender pays the same battery cost.
        let cost = (Self.transporterBatteryCostPct / 100) * defender.maxBattery
        let unlimited = defender.side == .player && FunModifiers.shared.unlimitedBattery
        if !unlimited {
            guard defender.spendBattery(cost) else { return }
        }

        // Move torpedo to attacker.
        defender.plantedTorpedo = nil
        attacker.plantedTorpedo = torpedo
        torpedo.transport(to: attacker)
    }

    private func tickTorpedoes(dt: TimeInterval) {
        for torpedo in activeTorpedoes {
            guard let host = torpedo.host else { continue }
            let stillTicking = torpedo.tick(dt: dt)
            if !stillTicking {
                detonate(torpedo: torpedo, on: host)
            }
        }
        activeTorpedoes.removeAll { $0.host?.plantedTorpedo !== $0 }
    }

    private func detonate(torpedo: QuantumTorpedo, on host: Ship) {
        // Section 6: catastrophic damage.
        let damageBeforeKill = host.health > 0
        host.takeDamage(host.maxHealth * 2.0)   // overkill — guaranteed destruction if not invulnerable

        // FATALITY flag if the kill was the host's.
        if damageBeforeKill && host.isDestroyed {
            lastKillByTorpedo = true
        }

        // Detach torpedo.
        host.plantedTorpedo = nil
        torpedo.removeFromParent()

        // Quantum Singularity Event — spawn 4-6 debris fragments + visual blast.
        spawnQuantumSingularity(at: host.position)
        juice.spawnSingularityExplosion(at: host.position, in: worldNode)
        juice.slowMo(.quantumSingularity)
        AudioSystem.shared.play(.quantumSingularity)
        if host.side == .player {
            juice.shake(.massive)
        }
    }

    private func spawnQuantumSingularity(at center: CGPoint) {
        let count = Int.random(in: 4...6)
        for _ in 0..<count {
            let debris = SingularityDebris(radius: CGFloat.random(in: 14...22))
            // Scatter around the detonation point.
            let r = CGFloat.random(in: 40...160)
            let a = CGFloat.random(in: 0...(2 * .pi))
            debris.position = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
            worldNode.addChild(debris)
            singularityDebris.append(debris)
        }
    }

    private func clearSingularityDebris() {
        for d in singularityDebris { d.removeFromParent() }
        singularityDebris.removeAll()
    }

    private func spawnHomingMissileSwarm(from ship: Ship, count: Int, target: Ship) {
        guard let missileDef = weaponsCatalog.first(where: { $0.id == "homing_missiles" }) else { return }
        // Spread the missiles in a small forward arc so they emerge as a swarm.
        let spread: CGFloat = 0.6   // radians total
        for i in 0..<count {
            let t = CGFloat(i) / CGFloat(max(1, count - 1))
            let angleOffset = -spread / 2 + spread * t
            let heading = ship.heading + angleOffset
            let spawnOffset: CGFloat = ship.hitboxRadius + 6
            let start = CGPoint(
                x: ship.position.x + cos(heading) * spawnOffset,
                y: ship.position.y + sin(heading) * spawnOffset
            )
            let p = Projectile(
                definition: missileDef,
                firedBy: ship.side,
                startPosition: start,
                startHeading: heading,
                homingTarget: target,
                outgoingMultiplier: ship.outgoingDamageMultiplier
            )
            worldNode.addChild(p)
            activeProjectiles.append(p)
        }
    }
}
