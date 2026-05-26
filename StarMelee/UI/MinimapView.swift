import SwiftUI

/// Tactical Minimap — Section 4 (sizing + behavior) and Section 14 (placement).
///
/// Shows the entire 16×16 world to scale:
///   - planets (translucent colored dots)
///   - power-ups (small dots)
///   - player marker (cyan)
///   - enemy marker (red)
///   - current camera viewport as a thin white rectangle
///
/// Sized 120×82 pt by default, positioned top-right of the HUD below the enemy stat panel.
struct MinimapView: View {
    @ObservedObject var gameState: GameState
    var width: CGFloat = 120
    var height: CGFloat = 82

    private let allianceCyan = Color(.sRGB, red: 0, green: 1.0, blue: 0.84)
    private let dominionRed  = Color(.sRGB, red: 1.0, green: 0.2, blue: 0.4)

    var body: some View {
        Canvas { ctx, size in
            let world = gameState.worldRect
            guard world.width > 0, world.height > 0 else { return }

            // Background
            let bg = Path(CGRect(origin: .zero, size: size))
            ctx.fill(bg, with: .color(.black.opacity(0.55)))

            // Planets
            for marker in gameState.planetMarkers {
                let mp = mapToMinimap(marker.position, world: world, mapSize: size)
                let r = mapScale(marker.radius, world: world, mapSize: size).clamped(min: 1.5, max: 6)
                let rect = CGRect(x: mp.x - r, y: mp.y - r, width: r*2, height: r*2)
                ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.35)))
            }

            // Power-ups
            for pos in gameState.powerUpMarkers {
                let mp = mapToMinimap(pos, world: world, mapSize: size)
                let rect = CGRect(x: mp.x - 1.5, y: mp.y - 1.5, width: 3, height: 3)
                ctx.fill(Path(ellipseIn: rect), with: .color(.yellow))
            }

            // Camera viewport rectangle
            let cv = gameState.cameraViewport
            if cv.width > 0 {
                let tl = mapToMinimap(CGPoint(x: cv.minX, y: cv.maxY), world: world, mapSize: size)
                let br = mapToMinimap(CGPoint(x: cv.maxX, y: cv.minY), world: world, mapSize: size)
                let rect = CGRect(x: tl.x, y: tl.y, width: br.x - tl.x, height: br.y - tl.y)
                ctx.stroke(Path(rect), with: .color(.white.opacity(0.7)), lineWidth: 0.5)
            }

            // Player marker
            let pp = mapToMinimap(gameState.playerWorldPos, world: world, mapSize: size)
            ctx.fill(Path(ellipseIn: CGRect(x: pp.x - 3, y: pp.y - 3, width: 6, height: 6)),
                     with: .color(allianceCyan))

            // Enemy marker
            let ep = mapToMinimap(gameState.enemyWorldPos, world: world, mapSize: size)
            ctx.fill(Path(ellipseIn: CGRect(x: ep.x - 3, y: ep.y - 3, width: 6, height: 6)),
                     with: .color(dominionRed))
        }
        .frame(width: width, height: height)
        .overlay(Rectangle().stroke(.white.opacity(0.5), lineWidth: 1))
    }

    /// Convert world point (SpriteKit +y up, origin at world center) → minimap point
    /// (SwiftUI +y down, origin at top-left).
    private func mapToMinimap(_ p: CGPoint, world: CGRect, mapSize: CGSize) -> CGPoint {
        let normX = (p.x - world.minX) / world.width            // 0...1
        let normY = (p.y - world.minY) / world.height           // 0...1 (world up)
        return CGPoint(x: normX * mapSize.width,
                       y: (1 - normY) * mapSize.height)        // flip y for SwiftUI
    }

    private func mapScale(_ r: CGFloat, world: CGRect, mapSize: CGSize) -> CGFloat {
        r / world.width * mapSize.width
    }
}

private extension CGFloat {
    func clamped(min lo: CGFloat, max hi: CGFloat) -> CGFloat { Swift.max(lo, Swift.min(hi, self)) }
}

#Preview {
    let gs = GameState()
    gs.worldRect = CGRect(x: -3000, y: -3000, width: 6000, height: 6000)
    gs.cameraViewport = CGRect(x: -200, y: -100, width: 400, height: 300)
    gs.playerWorldPos = CGPoint(x: 0, y: 0)
    gs.enemyWorldPos = CGPoint(x: 800, y: 500)
    gs.planetMarkers = [
        PlanetMarker(position: CGPoint(x: -1000, y: 700), radius: 50),
        PlanetMarker(position: CGPoint(x: 1500, y: -1200), radius: 80),
        PlanetMarker(position: CGPoint(x: 200, y: -2000), radius: 40),
    ]
    return MinimapView(gameState: gs)
        .padding()
        .background(Color.black)
}
