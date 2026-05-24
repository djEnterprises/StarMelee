import SpriteKit
import GameplayKit

/// The active 2D arena where ship-to-ship combat happens.
///
/// Phase 1 scope: render a parallax starfield + a placeholder planet.
/// Phase 2 will add ships, weapons, HUD overlay, and gravity.
/// See `STAR_MELEE_PLAN.md` Sections 4–8 and 14.
final class CombatScene: SKScene {

    var playerShipID: String = "aegis_cruiser"

    private var lastUpdate: TimeInterval = 0
    private var starfields: [SKNode] = []

    override func didMove(to view: SKView) {
        backgroundColor = .black
        scaleMode = .resizeFill
        physicsWorld.gravity = .zero

        buildStarfield()
        buildPlaceholderPlanet()
        buildPracticeBanner()
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate == 0 ? 0 : currentTime - lastUpdate
        lastUpdate = currentTime
        scrollStarfield(dt: dt)
    }

    // MARK: - Starfield

    private func buildStarfield() {
        // Three parallax layers — slowest in back, fastest in front.
        let layerSpecs: [(starCount: Int, alpha: CGFloat, sizeRange: ClosedRange<CGFloat>, name: String)] = [
            (120, 0.35, 0.6...1.2, "starfield_far"),
            (80,  0.6,  1.0...1.8, "starfield_mid"),
            (40,  0.9,  1.4...2.6, "starfield_near"),
        ]

        for spec in layerSpecs {
            let layer = SKNode()
            layer.name = spec.name
            layer.zPosition = -100

            for _ in 0..<spec.starCount {
                let size = CGFloat.random(in: spec.sizeRange)
                let star = SKShapeNode(circleOfRadius: size / 2)
                star.fillColor = .white
                star.strokeColor = .clear
                star.alpha = spec.alpha * CGFloat.random(in: 0.5...1.0)
                star.position = CGPoint(
                    x: CGFloat.random(in: 0...max(1, self.size.width)),
                    y: CGFloat.random(in: 0...max(1, self.size.height))
                )
                layer.addChild(star)
            }

            addChild(layer)
            starfields.append(layer)
        }
    }

    private func scrollStarfield(dt: TimeInterval) {
        guard dt > 0 else { return }
        let speeds: [CGFloat] = [4, 9, 16] // points per second, per layer
        for (i, layer) in starfields.enumerated() where i < speeds.count {
            let dx = -speeds[i] * CGFloat(dt)
            for case let star as SKShapeNode in layer.children {
                star.position.x += dx
                if star.position.x < 0 {
                    star.position.x += size.width
                    star.position.y = CGFloat.random(in: 0...size.height)
                }
            }
        }
    }

    // MARK: - Arena content (Phase 1 placeholder)

    private func buildPlaceholderPlanet() {
        let planet = SKShapeNode(circleOfRadius: 56)
        planet.position = CGPoint(x: size.width / 2, y: size.height / 2)
        planet.fillColor = SKColor(red: 0.6, green: 0.3, blue: 0.8, alpha: 1.0)
        planet.strokeColor = SKColor(red: 1.0, green: 0.4, blue: 0.9, alpha: 0.8)
        planet.lineWidth = 2
        planet.glowWidth = 12
        planet.name = "placeholder_planet"
        addChild(planet)

        // Subtle gravity-well ring — visual only in Phase 1.
        let ring = SKShapeNode(circleOfRadius: 140)
        ring.position = planet.position
        ring.fillColor = .clear
        ring.strokeColor = SKColor(red: 1.0, green: 0.4, blue: 0.9, alpha: 0.15)
        ring.lineWidth = 1
        ring.zPosition = -1
        addChild(ring)
    }

    private func buildPracticeBanner() {
        let label = SKLabelNode(text: "PHASE 1 — ARENA SHELL")
        label.fontName = "Menlo-Bold"
        label.fontSize = 14
        label.fontColor = SKColor(red: 0, green: 1.0, blue: 0.84, alpha: 0.9)
        label.position = CGPoint(x: size.width / 2, y: size.height - 32)
        label.zPosition = 10
        addChild(label)

        let hint = SKLabelNode(text: "Ships, weapons, HUD land in Phase 2")
        hint.fontName = "Menlo"
        hint.fontSize = 11
        hint.fontColor = SKColor(white: 0.7, alpha: 0.8)
        hint.position = CGPoint(x: size.width / 2, y: size.height - 52)
        hint.zPosition = 10
        addChild(hint)
    }
}

private extension CGFloat {
    func smaller(size: CGSize) -> CGSize { size }
}
