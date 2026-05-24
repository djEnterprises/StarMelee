import SpriteKit
import CoreGraphics

/// A planet in the arena — provides visual reference, gravity well, and a collidable body
/// that ships and projectiles can hit.
///
/// **Plan reference:** Section 4 (10–14 planets, ≥280 unit spacing, avoid spawn corridor) and
/// Section 14 (gravity wells visible as subtle gradient rings, Saturn-style rings on some).
final class Planet: SKNode {

    /// Physics mass used by the gravity well. Scales roughly with visual radius.
    let gravMass: CGFloat

    /// Visual + collision radius.
    let radius: CGFloat

    init(radius: CGFloat, mass: CGFloat, palette: Palette, hasRings: Bool) {
        self.radius = radius
        self.gravMass = mass

        super.init()

        // Soft outer gravity-well ring (cosmetic — actual gravity force is computed by CombatScene).
        let outerRing = SKShapeNode(circleOfRadius: radius * 3.0)
        outerRing.fillColor = .clear
        outerRing.strokeColor = palette.ring.withAlphaComponent(0.10)
        outerRing.lineWidth = 1
        outerRing.zPosition = -2
        addChild(outerRing)

        let innerRing = SKShapeNode(circleOfRadius: radius * 1.7)
        innerRing.fillColor = .clear
        innerRing.strokeColor = palette.ring.withAlphaComponent(0.18)
        innerRing.lineWidth = 1
        innerRing.zPosition = -1
        addChild(innerRing)

        // Saturn-style ring on selected planets.
        if hasRings {
            let ringNode = SKShapeNode(ellipseOf: CGSize(width: radius * 3.4, height: radius * 0.7))
            ringNode.fillColor = .clear
            ringNode.strokeColor = palette.ring.withAlphaComponent(0.55)
            ringNode.lineWidth = 2
            ringNode.zRotation = CGFloat.random(in: -0.35...0.35)
            addChild(ringNode)
        }

        // The planet body itself.
        let body = SKShapeNode(circleOfRadius: radius)
        body.fillColor = palette.fill
        body.strokeColor = palette.stroke
        body.lineWidth = 2
        body.glowWidth = 8
        addChild(body)

        // Physics body — static, collidable, contact events for projectiles.
        let pb = SKPhysicsBody(circleOfRadius: radius)
        pb.affectedByGravity = false
        pb.isDynamic = false
        pb.categoryBitMask = PhysicsCategory.planet
        pb.collisionBitMask = PhysicsCategory.playerShip | PhysicsCategory.enemyShip
        pb.contactTestBitMask = PhysicsCategory.playerShot | PhysicsCategory.enemyShot
        self.physicsBody = pb
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not used") }

    struct Palette {
        let fill: SKColor
        let stroke: SKColor
        let ring: SKColor

        static let palettes: [Palette] = [
            // Violet
            Palette(fill: SKColor(red: 0.45, green: 0.18, blue: 0.65, alpha: 1.0),
                    stroke: SKColor(red: 0.85, green: 0.45, blue: 1.0, alpha: 0.9),
                    ring: SKColor(red: 1.0, green: 0.4, blue: 0.9, alpha: 1.0)),
            // Cyan ice
            Palette(fill: SKColor(red: 0.18, green: 0.42, blue: 0.62, alpha: 1.0),
                    stroke: SKColor(red: 0.50, green: 0.85, blue: 1.0, alpha: 0.9),
                    ring: SKColor(red: 0.40, green: 0.80, blue: 1.0, alpha: 1.0)),
            // Ember orange
            Palette(fill: SKColor(red: 0.70, green: 0.32, blue: 0.10, alpha: 1.0),
                    stroke: SKColor(red: 1.0, green: 0.60, blue: 0.30, alpha: 0.9),
                    ring: SKColor(red: 1.0, green: 0.50, blue: 0.15, alpha: 1.0)),
            // Toxic green
            Palette(fill: SKColor(red: 0.18, green: 0.55, blue: 0.30, alpha: 1.0),
                    stroke: SKColor(red: 0.45, green: 1.0, blue: 0.55, alpha: 0.9),
                    ring: SKColor(red: 0.35, green: 1.0, blue: 0.45, alpha: 1.0)),
            // Crimson
            Palette(fill: SKColor(red: 0.60, green: 0.15, blue: 0.20, alpha: 1.0),
                    stroke: SKColor(red: 1.0, green: 0.35, blue: 0.40, alpha: 0.9),
                    ring: SKColor(red: 1.0, green: 0.20, blue: 0.30, alpha: 1.0)),
        ]
    }

    // MARK: - Field generator

    /// Generate a planet field for a world rect (Section 4: 10–14 planets, ≥280 unit spacing,
    /// avoiding a horizontal spawn corridor at y ≈ 0).
    /// - Parameters:
    ///   - world: world bounds in points
    ///   - spawnCorridorHalfHeight: vertical exclusion zone around y=0
    /// - Returns: array of Planet nodes positioned in the world.
    static func generateField(world: CGRect, spawnCorridorHalfHeight: CGFloat) -> [Planet] {
        let target = Int.random(in: 10...14)
        let minSpacing: CGFloat = 280
        var planets: [Planet] = []
        var attempts = 0
        let maxAttempts = 4000

        while planets.count < target && attempts < maxAttempts {
            attempts += 1
            let r: CGFloat = CGFloat.random(in: 36...82)
            // Keep a buffer from world edges and skip the spawn corridor.
            let margin: CGFloat = r + 40
            let x = CGFloat.random(in: (world.minX + margin)...(world.maxX - margin))
            let y = CGFloat.random(in: (world.minY + margin)...(world.maxY - margin))
            if abs(y) < spawnCorridorHalfHeight { continue }
            let pos = CGPoint(x: x, y: y)

            // Spacing check
            var ok = true
            for existing in planets {
                let dx = existing.position.x - pos.x
                let dy = existing.position.y - pos.y
                if hypot(dx, dy) < (minSpacing + existing.radius + r) { ok = false; break }
            }
            if !ok { continue }

            let mass = (r / 50)   // ~0.7 to 1.6
            let palette = Palette.palettes.randomElement()!
            let hasRings = Bool.random() && Bool.random() // ~25% chance

            let planet = Planet(radius: r, mass: mass, palette: palette, hasRings: hasRings)
            planet.position = pos
            planets.append(planet)
        }
        return planets
    }
}
