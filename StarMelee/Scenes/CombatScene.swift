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
    private var planets: [Planet] = []

    // MARK: - Match management
    private let matchManager = MatchManager()

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

        // Player
        playerPrimary = makeWeapon(weaponID: playerShip.definition.weapons.primary,
                                   fireRateFrames: playerShip.definition.stats.primaryFireRateFrames,
                                   in: weapons)!
        playerSecondary = makeWeapon(weaponID: playerShip.definition.weapons.secondary,
                                     fireRateFrames: playerShip.definition.stats.secondaryFireRateFrames,
                                     in: weapons)!

        // Enemy
        enemyPrimary = makeWeapon(weaponID: enemyShip.definition.weapons.primary,
                                  fireRateFrames: enemyShip.definition.stats.primaryFireRateFrames,
                                  in: weapons)!
        enemySecondary = makeWeapon(weaponID: enemyShip.definition.weapons.secondary,
                                    fireRateFrames: enemyShip.definition.stats.secondaryFireRateFrames,
                                    in: weapons)!

        // AI difficulty from settings, defaulting to Captain (Section 15 default).
        let savedDifficulty = UserDefaults.standard.string(forKey: "settings.aiDifficulty") ?? "captain"
        let diff = AIController.Difficulty(rawValue: savedDifficulty) ?? .captain
        aiController = AIController(difficulty: diff)
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
        let dt = lastUpdate == 0 ? 1.0 / 60.0 : min(0.05, currentTime - lastUpdate)
        lastUpdate = currentTime

        let allowSpecials = matchManager.allowSpecials

        // Read input
        let thrust = input?.xPressed ?? false
        let brake  = input?.yPressed ?? false
        let turn   = input?.turnDirection ?? 0
        let firing1 = input?.aPressed ?? false
        let firing2 = input?.bPressed ?? false

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
                                             allowSpecials: allowSpecials)
        let aiCadenceCutPrimary: CGFloat = matchManager.allowSpecials ? 1.0 : 0.6
        let aiCadenceCutSecondary: CGFloat = matchManager.allowSpecials ? 1.0 : 0.2
        let aiFirePrimary = aiDecision.firePrimary && CGFloat.random(in: 0...1) < aiCadenceCutPrimary
        let aiFireSecondary = aiDecision.fireSecondary && CGFloat.random(in: 0...1) < aiCadenceCutSecondary

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
        }
        if canControlPlayer && firing2, let shot = playerSecondary.fire(from: playerShip, target: enemyShip) {
            worldNode.addChild(shot)
            activeProjectiles.append(shot)
        }
        if aiFirePrimary, let shot = enemyPrimary.fire(from: enemyShip) {
            worldNode.addChild(shot)
            activeProjectiles.append(shot)
        }
        if aiFireSecondary, let shot = enemySecondary.fire(from: enemyShip, target: playerShip) {
            worldNode.addChild(shot)
            activeProjectiles.append(shot)
        }

        // Projectile lifecycle
        activeProjectiles.removeAll { proj in
            let alive = proj.update(dt: dt, world: worldRect)
            if !alive { proj.removeFromParent() }
            return !alive
        }

        // World boundary
        PhysicsEngine.enforceWorldBounds(ship: playerShip, world: worldRect)
        PhysicsEngine.enforceWorldBounds(ship: enemyShip, world: worldRect)

        // Camera
        let lerp = WorldConstants.cameraLerp * min(1, CGFloat(dt) * 60)
        cameraNode.position.x += (playerShip.position.x - cameraNode.position.x) * lerp
        cameraNode.position.y += (playerShip.position.y - cameraNode.position.y) * lerp
        clampCameraToWorld()

        // Match state advance
        if let change = matchManager.update(
            dt: dt,
            playerDestroyed: playerShip.isDestroyed,
            enemyDestroyed: enemyShip.isDestroyed,
            playerHealthFraction: playerShip.healthFraction,
            enemyHealthFraction: enemyShip.healthFraction,
            playerShieldFraction: playerShip.shieldFraction,
            enemyShieldFraction: enemyShip.shieldFraction
        ) {
            handlePhaseChange(change)
        }

        publishGameState()
    }

    private func applyPlanetGravity(to ship: Ship, dt: TimeInterval) {
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

    private func clampCameraToWorld() {
        let halfW = size.width / 2
        let halfH = size.height / 2
        cameraNode.position.x = min(max(cameraNode.position.x, worldRect.minX + halfW), worldRect.maxX - halfW)
        cameraNode.position.y = min(max(cameraNode.position.y, worldRect.minY + halfH), worldRect.maxY - halfH)
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
            gs.matchSecondsRemaining = MatchManager.activeMatchSeconds
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
        gs.enemyScreenDirection = CGVector(
            dx: enemyShip.position.x - cameraPos.x,
            dy: -(enemyShip.position.y - cameraPos.y)
        )
        gs.enemyDistanceUnits = hypot(playerShip.position.x - enemyShip.position.x,
                                      playerShip.position.y - enemyShip.position.y)
    }

    private func handlePhaseChange(_ change: MatchManager.PhaseChange) {
        switch change {
        case .countdownEnded:
            // No-op visually for now; haptics + sound will land in Phase 3/4.
            break
        case .matchEnded:
            // Active projectiles cleared so next match starts clean.
            for p in activeProjectiles { p.removeFromParent() }
            activeProjectiles.removeAll()
        case .nextMatchStarted:
            // Section 4 step 6: ships reset to 100% and respawn.
            resetShipsForNextMatch()
        case .seriesEnded:
            // CombatSceneView observes GameState.seriesEnded and presents the overlay.
            break
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
        }
    }

    private func handleProjectile(_ proj: Projectile, hitting target: Ship) {
        if proj.firedBy == target.side { return }
        let damage = proj.computeDamage(against: target)
        target.takeDamage(damage)
        removeProjectile(proj)
    }

    private func removeProjectile(_ proj: Projectile) {
        proj.removeFromParent()
        activeProjectiles.removeAll { $0 === proj }
    }
}
