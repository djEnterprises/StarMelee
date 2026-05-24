import SpriteKit
import GameplayKit

/// The active 2D arena where ship-to-ship combat happens.
///
/// **Plan reference:** Sections 4 (world model + camera), 5 (ship), 6 (weapons), 7 (HP/shield/battery),
/// 14 (visuals), 23 (mockup fixes — especially the `allowSpecials: Bool` flag pattern).
///
/// Phase 1 mid-build scope:
///   ✓ One playable ship (Aegis Cruiser), full inertia, no auto-drag
///   ✓ Stationary placeholder enemy (Phase 2 replaces with AIController)
///   ✓ Primary + secondary weapons firing, damage, projectile bounds
///   ✓ Lerp-following camera, bounded world (Section 4)
///   ✓ Per-frame writes to GameState so the SwiftUI HUD can show health + off-screen indicator
final class CombatScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Injected dependencies (set by `CombatSceneView` before presentation)
    weak var input: InputState?
    weak var gameState: GameState?
    var playerShipID: String = "aegis_cruiser"

    // MARK: - Scene nodes
    private let worldNode = SKNode()
    private let cameraNode = SKCameraNode()
    private var playerShip: Ship!
    private var enemyShip: Ship!
    private var playerPrimary: Weapon!
    private var playerSecondary: Weapon!
    private var activeProjectiles: [Projectile] = []
    private var starLayers: [SKNode] = []

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

        // World rect — Section 4: WORLD_SCALE × viewport.
        let w = size.width * WorldConstants.worldScaleFactor
        let h = size.height * WorldConstants.worldScaleFactor
        worldRect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)

        addChild(worldNode)
        addChild(cameraNode)
        self.camera = cameraNode

        buildStarfield()
        buildPlaceholderPlanet()
        spawnShips()
        wireWeapons()

        // Initial camera & HUD push.
        cameraNode.position = playerShip.position
        publishGameState()
    }

    private func buildStarfield() {
        // Three parallax layers — each layer is a static SKNode containing many small SKShapeNode stars,
        // tiled across the full world. Slowest layer is largest, farthest, and most opaque-shifted dim.
        // Real parallax in a single-camera setup is faked via depth scale: distant stars are drawn
        // very small and don't pop visually as the camera moves long distances.
        let specs: [(count: Int, alphaRange: ClosedRange<CGFloat>, sizeRange: ClosedRange<CGFloat>)] = [
            (600, 0.20...0.50, 0.4...1.0),  // far
            (300, 0.40...0.75, 0.7...1.6),  // mid
            (120, 0.60...0.95, 1.2...2.4),  // near
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
            starLayers.append(layer)
        }
    }

    private func buildPlaceholderPlanet() {
        // Single planet at world center for early visual reference.
        // Phase 2 will spawn 10–14 planets per Section 4 with 280-unit minimum spacing.
        let planet = SKShapeNode(circleOfRadius: 56)
        planet.position = .zero
        planet.fillColor = SKColor(red: 0.6, green: 0.3, blue: 0.8, alpha: 1.0)
        planet.strokeColor = SKColor(red: 1.0, green: 0.4, blue: 0.9, alpha: 0.8)
        planet.lineWidth = 2
        planet.glowWidth = 12
        planet.name = "placeholder_planet"

        let body = SKPhysicsBody(circleOfRadius: 56)
        body.affectedByGravity = false
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.planet
        body.collisionBitMask = PhysicsCategory.playerShip | PhysicsCategory.enemyShip
        body.contactTestBitMask = PhysicsCategory.playerShot | PhysicsCategory.enemyShot
        planet.physicsBody = body
        worldNode.addChild(planet)

        // Gravity-well visual ring (cosmetic only in Phase 1; Phase 2 wires actual gravity).
        let ring = SKShapeNode(circleOfRadius: 200)
        ring.fillColor = .clear
        ring.strokeColor = SKColor(red: 1.0, green: 0.4, blue: 0.9, alpha: 0.18)
        ring.lineWidth = 1
        ring.zPosition = -1
        worldNode.addChild(ring)
    }

    private func spawnShips() {
        let ships = ShipDefinition.loadAll()
        guard let aegis = ships.first(where: { $0.id == playerShipID }) ?? ships.first else {
            assertionFailure("Ships.json missing or empty — cannot scaffold combat.")
            return
        }

        playerShip = Ship(definition: aegis, side: .player)
        playerShip.position = CGPoint(x: -aegis.stats.hitboxSize * 4, y: 0)
        playerShip.heading = 0   // facing +x (right)
        worldNode.addChild(playerShip)

        // Phase 1 placeholder enemy — uses the same Aegis stats since we're only validating combat.
        // Phase 2 will pick a Dominion ship at random and attach an AIController.
        // Spawn ~0.6 viewport-widths to the right of the player so it's visible on screen
        // for immediate Phase 1 testability. Section 4 spec is 3 viewport-widths; bump in Phase 2.
        let enemyDef = ships.first(where: { $0.id == "void_reaper" }) ?? aegis
        enemyShip = Ship(definition: enemyDef, side: .opponent)
        enemyShip.position = CGPoint(x: size.width * WorldConstants.phase1EnemySpawnViewports, y: 0)
        enemyShip.heading = .pi   // facing -x (left, toward player)
        worldNode.addChild(enemyShip)

        gameState?.playerName = aegis.name.uppercased()
        gameState?.enemyName = enemyDef.name.uppercased()
    }

    private func wireWeapons() {
        let weapons = WeaponDefinition.loadAll()
        let primaryID = playerShip.definition.weapons.primary
        let secondaryID = playerShip.definition.weapons.secondary
        guard let primaryDef = weapons.first(where: { $0.id == primaryID }),
              let secondaryDef = weapons.first(where: { $0.id == secondaryID }) else {
            assertionFailure("Weapons.json missing entries for \(primaryID) / \(secondaryID)")
            return
        }
        playerPrimary = Weapon(definition: primaryDef,
                               fireRateFrames: playerShip.definition.stats.primaryFireRateFrames)
        playerSecondary = Weapon(definition: secondaryDef,
                                 fireRateFrames: playerShip.definition.stats.secondaryFireRateFrames)
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate == 0 ? 1.0 / 60.0 : min(0.05, currentTime - lastUpdate)
        lastUpdate = currentTime

        // Read input — defaults handle the case where the SwiftUI binding hasn't connected yet.
        let thrust = input?.xPressed ?? false
        let brake  = input?.yPressed ?? false
        let turn   = input?.turnDirection ?? 0
        let firing1 = input?.aPressed ?? false
        let firing2 = input?.bPressed ?? false

        // Section 23: `allowSpecials` is false during pre-match countdown. Phase 1 has no countdown
        // yet, so always true. Phase 2 wires this to the MatchState phase.
        let allowSpecials = true

        // Ships
        playerShip.update(dt: dt, thrust: thrust, brake: brake, turn: turn, allowSpecials: allowSpecials)
        enemyShip.update(dt: dt, thrust: false, brake: false, turn: 0, allowSpecials: allowSpecials)

        // Weapons
        playerPrimary.tick(dt: dt)
        playerSecondary.tick(dt: dt)

        if firing1, let shot = playerPrimary.fire(from: playerShip) {
            worldNode.addChild(shot)
            activeProjectiles.append(shot)
        }
        if firing2, let shot = playerSecondary.fire(from: playerShip, target: enemyShip) {
            worldNode.addChild(shot)
            activeProjectiles.append(shot)
        }

        // Projectile lifecycle
        activeProjectiles.removeAll { proj in
            let alive = proj.update(dt: dt, world: worldRect)
            if !alive { proj.removeFromParent() }
            return !alive
        }

        // World boundary handling for ships
        PhysicsEngine.enforceWorldBounds(ship: playerShip, world: worldRect)
        PhysicsEngine.enforceWorldBounds(ship: enemyShip, world: worldRect)

        // Camera — lerp toward player, clamp to world.
        let lerp = WorldConstants.cameraLerp * min(1, CGFloat(dt) * 60)
        cameraNode.position.x += (playerShip.position.x - cameraNode.position.x) * lerp
        cameraNode.position.y += (playerShip.position.y - cameraNode.position.y) * lerp
        clampCameraToWorld()

        publishGameState()
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

        // Off-screen indicator math (Section 4).
        let cameraPos = cameraNode.position
        let halfW = size.width / 2
        let halfH = size.height / 2
        let cameraRect = CGRect(x: cameraPos.x - halfW, y: cameraPos.y - halfH,
                                width: size.width, height: size.height)
        let onScreen = cameraRect.contains(enemyShip.position)
        gs.enemyOnScreen = onScreen
        // SwiftUI uses +y down; SpriteKit +y up. Flip y for the screen-direction vector.
        gs.enemyScreenDirection = CGVector(
            dx: enemyShip.position.x - cameraPos.x,
            dy: -(enemyShip.position.y - cameraPos.y)
        )
        gs.enemyDistanceUnits = hypot(playerShip.position.x - enemyShip.position.x,
                                      playerShip.position.y - enemyShip.position.y)
    }

    // MARK: - Collisions

    func didBegin(_ contact: SKPhysicsContact) {
        let aBody = contact.bodyA
        let bBody = contact.bodyB

        // Identify projectile vs ship pairings (either order).
        if let proj = (aBody.node as? Projectile), let target = (bBody.node as? Ship) {
            handleProjectile(proj, hitting: target)
        } else if let proj = (bBody.node as? Projectile), let target = (aBody.node as? Ship) {
            handleProjectile(proj, hitting: target)
        }
        // Projectile vs planet — just remove projectile.
        else if let proj = (aBody.node as? Projectile), bBody.categoryBitMask == PhysicsCategory.planet {
            removeProjectile(proj)
        } else if let proj = (bBody.node as? Projectile), aBody.categoryBitMask == PhysicsCategory.planet {
            removeProjectile(proj)
        }
    }

    private func handleProjectile(_ proj: Projectile, hitting target: Ship) {
        // Don't friendly-fire.
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
