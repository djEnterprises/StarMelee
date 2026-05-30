import SpriteKit

/// Multi-layer parallax starfield + nebula clouds for arena depth (premium-polish Phase 3).
///
/// The old starfield placed stars directly in `worldNode`, so they rode the world 1:1 — no depth.
/// This system instead attaches layers to the **camera** and scrolls each by a fraction of the
/// camera's world movement: distant layers barely drift, near layers move almost at world speed.
/// Each layer's star pattern is periodic over a `tile` and replicated 3×3, so wrapping the offset
/// `mod tile` produces a seamless, infinite field no matter how far the camera travels.
///
/// Build once (`buildStarfield`), then call `update(cameraPosition:)` each frame with the smoothed
/// camera-follow target (pre-shake, so the background doesn't jitter with screen shake).
final class ParallaxBackground {

    private struct Layer {
        let node: SKNode
        let factor: CGFloat        // 0 = screen-locked, 1 = full world speed
        let tile: CGSize
    }

    private var layers: [Layer] = []

    /// - Parameters:
    ///   - camera: the scene's camera; layers are added as its children (screen space).
    ///   - viewport: the scene size, used to size the wrap tile so it always covers the screen.
    init(camera: SKCameraNode, viewport: CGSize) {
        // Star layers: (parallax factor, stars per tile, alpha range, size range, z).
        let starSpecs: [(factor: CGFloat, count: Int, alpha: ClosedRange<CGFloat>, size: ClosedRange<CGFloat>, z: CGFloat)] = [
            (0.15, 48, 0.18...0.45, 0.4...1.0, -260),   // far, faint, slow
            (0.40, 34, 0.35...0.70, 0.7...1.6, -240),   // mid
            (0.70, 18, 0.55...0.95, 1.0...2.2, -220),   // near, bright, fast
        ]
        // Tile is comfortably larger than the viewport so a 3×3 replication always covers screen.
        let tile = CGSize(width: max(viewport.width, 1) * 1.6,
                          height: max(viewport.height, 1) * 1.6)

        // Deep nebula clouds — big, soft, additive, low-alpha tinted blobs for color + depth.
        let nebula = SKNode()
        nebula.zPosition = -280
        let nebulaColors = [
            SKColor(red: 0.10, green: 0.0,  blue: 0.30, alpha: 1),   // deep violet
            SKColor(red: 0.0,  green: 0.20, blue: 0.30, alpha: 1),   // teal haze
            SKColor(red: 0.22, green: 0.0,  blue: 0.18, alpha: 1),   // magenta dust
        ]
        for i in 0..<5 {
            let cloud = SKSpriteNode(texture: VFX.softDot)
            let dim = CGFloat(900 + i * 220)
            cloud.size = CGSize(width: dim, height: dim)
            cloud.color = nebulaColors[i % nebulaColors.count]
            cloud.colorBlendFactor = 1
            cloud.blendMode = .add
            cloud.alpha = 0.16
            // Deterministic spread across the tile (no Date/random-at-build concerns).
            let fx = CGFloat((i * 37) % 100) / 100 - 0.5
            let fy = CGFloat((i * 61) % 100) / 100 - 0.5
            cloud.position = CGPoint(x: fx * tile.width, y: fy * tile.height)
            nebula.addChild(cloud)
        }
        camera.addChild(nebula)
        layers.append(Layer(node: nebula, factor: 0.08, tile: tile))

        for spec in starSpecs {
            let layer = SKNode()
            layer.zPosition = spec.z
            // Build one tile of stars, then replicate in a 3×3 grid so `mod tile` wrapping is seamless.
            for i in 0..<spec.count {
                // Deterministic pseudo-scatter from the index (avoids needing a seeded RNG here).
                let hx = CGFloat((i &* 1103515245 &+ 12345) & 0xFFFF) / 65535
                let hy = CGFloat((i &* 1664525 &+ 1013904223) & 0xFFFF) / 65535
                let ha = CGFloat((i &* 22695477 &+ 1) & 0xFF) / 255
                let baseX = (hx - 0.5) * tile.width
                let baseY = (hy - 0.5) * tile.height
                let r = (spec.size.lowerBound + ha * (spec.size.upperBound - spec.size.lowerBound)) / 2
                let alpha = spec.alpha.lowerBound + ha * (spec.alpha.upperBound - spec.alpha.lowerBound)
                for gx in -1...1 {
                    for gy in -1...1 {
                        let star = SKShapeNode(circleOfRadius: r)
                        star.fillColor = .white
                        star.strokeColor = .clear
                        star.alpha = alpha
                        star.position = CGPoint(x: baseX + CGFloat(gx) * tile.width,
                                                y: baseY + CGFloat(gy) * tile.height)
                        layer.addChild(star)
                    }
                }
            }
            camera.addChild(layer)
            layers.append(Layer(node: layer, factor: spec.factor, tile: tile))
        }
    }

    /// Offset each layer by a fraction of the camera's world position, wrapped over its tile so the
    /// field scrolls seamlessly and forever. Pass the smoothed follow target (not the shaken camera
    /// position) so the background doesn't inherit screen-shake jitter.
    func update(cameraPosition: CGPoint) {
        for layer in layers {
            let ox = (cameraPosition.x * layer.factor).truncatingRemainder(dividingBy: layer.tile.width)
            let oy = (cameraPosition.y * layer.factor).truncatingRemainder(dividingBy: layer.tile.height)
            layer.node.position = CGPoint(x: -ox, y: -oy)
        }
    }
}
