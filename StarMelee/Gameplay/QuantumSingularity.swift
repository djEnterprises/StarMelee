import SpriteKit
import CoreGraphics

/// A piece of hull debris / micro-singularity left over from a Quantum Torpedo detonation.
///
/// **Plan reference:** Section 6 "QUANTUM SINGULARITY EVENT" — debris damages both ships on
/// contact and persists until the end of the current match.
final class SingularityDebris: SKNode {

    init(radius: CGFloat = 18) {
        super.init()

        // Glowing hexagonal silhouette.
        let path = CGMutablePath()
        for i in 0..<6 {
            let a = CGFloat(i) * (.pi / 3)
            let p = CGPoint(x: cos(a) * radius, y: sin(a) * radius)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        let hex = SKShapeNode(path: path)
        hex.fillColor = SKColor(red: 0.7, green: 0.1, blue: 0.9, alpha: 0.5)
        hex.strokeColor = SKColor(red: 1.0, green: 0.4, blue: 1.0, alpha: 1)
        hex.lineWidth = 1.5
        hex.glowWidth = 6
        addChild(hex)

        // Slow rotation
        let spin = SKAction.rotate(byAngle: CGFloat.random(in: -0.4...0.4), duration: 1.6)
        run(SKAction.repeatForever(spin))

        // Physics body — damages anything that touches it.
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.affectedByGravity = false
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.planet   // reuse planet category for ship reflection
        body.collisionBitMask = PhysicsCategory.playerShip | PhysicsCategory.enemyShip
        body.contactTestBitMask = PhysicsCategory.playerShip | PhysicsCategory.enemyShip
            | PhysicsCategory.playerShot | PhysicsCategory.enemyShot
        self.physicsBody = body
        name = "singularity_debris"
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not used") }

    /// Damage dealt to a ship on contact (per collision).
    static let contactDamage: CGFloat = 12
}
