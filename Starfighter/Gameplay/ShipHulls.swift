import SwiftUI
import CoreGraphics
import SpriteKit

/// Per-ship hull silhouettes — stylized polygon shapes (Section 14 DECISION POINT for v1.0).
///
/// Each ship's hull is defined as a list of normalized 2D points in a [-1, +1]² box, with
/// +y up (gameplay/SpriteKit convention). Two helpers convert to:
/// - `cgPath(for:size:)` — CGPath for SKShapeNode use in the arena
/// - `swiftUIPath(for:in:)` — SwiftUI Path for previews in the Ship Select grid and Compendium
///
/// Adding a new ship: append its `id` case below with a distinct silhouette.
enum ShipHullDesigner {

    /// Normalized polygon points (+y up, -1...+1 box). Drawn in order, automatically closed.
    static func normalizedPoints(for shipID: String) -> [CGPoint] {
        switch shipID {

        // ---------- ALLIANCE (cyan) ----------

        case "aegis_cruiser":
            // Classic balanced arrow with notched tail.
            return [
                CGPoint(x: 0,    y: 1.00),
                CGPoint(x: 0.70, y: -0.55),
                CGPoint(x: 0.30, y: -0.40),
                CGPoint(x: 0,    y: -0.25),
                CGPoint(x: -0.30, y: -0.40),
                CGPoint(x: -0.70, y: -0.55),
            ]

        case "solar_wing":
            // Sleek dart with deeply swept wings — speed read.
            return [
                CGPoint(x: 0,    y: 1.00),
                CGPoint(x: 0.20, y: 0.40),
                CGPoint(x: 0.85, y: -0.75),
                CGPoint(x: 0.30, y: -0.55),
                CGPoint(x: 0.10, y: -0.30),
                CGPoint(x: -0.10, y: -0.30),
                CGPoint(x: -0.30, y: -0.55),
                CGPoint(x: -0.85, y: -0.75),
                CGPoint(x: -0.20, y: 0.40),
            ]

        case "titan_bulwark":
            // Wide diamond brick — tank silhouette.
            return [
                CGPoint(x: 0,    y: 0.90),
                CGPoint(x: 0.50, y: 0.55),
                CGPoint(x: 0.85, y: 0.10),
                CGPoint(x: 0.85, y: -0.40),
                CGPoint(x: 0.40, y: -0.75),
                CGPoint(x: -0.40, y: -0.75),
                CGPoint(x: -0.85, y: -0.40),
                CGPoint(x: -0.85, y: 0.10),
                CGPoint(x: -0.50, y: 0.55),
            ]

        case "prism_hunter":
            // Three-pronged trident — the "prism spread" weapon shape.
            return [
                CGPoint(x: 0,    y: 1.00),
                CGPoint(x: 0.20, y: 0.20),
                CGPoint(x: 0.80, y: 0.60),
                CGPoint(x: 0.55, y: -0.40),
                CGPoint(x: 0.25, y: -0.20),
                CGPoint(x: 0,    y: -0.70),
                CGPoint(x: -0.25, y: -0.20),
                CGPoint(x: -0.55, y: -0.40),
                CGPoint(x: -0.80, y: 0.60),
                CGPoint(x: -0.20, y: 0.20),
            ]

        case "nova_lancer":
            // Long thin needle — glass cannon.
            return [
                CGPoint(x: 0,    y: 1.00),
                CGPoint(x: 0.15, y: 0.20),
                CGPoint(x: 0.35, y: -0.60),
                CGPoint(x: 0.10, y: -0.80),
                CGPoint(x: -0.10, y: -0.80),
                CGPoint(x: -0.35, y: -0.60),
                CGPoint(x: -0.15, y: 0.20),
            ]

        case "halo_sentinel":
            // Octagonal shield with a small forward jut — defensive support.
            return [
                CGPoint(x: 0,    y: 0.90),
                CGPoint(x: 0.55, y: 0.65),
                CGPoint(x: 0.80, y: 0.20),
                CGPoint(x: 0.80, y: -0.30),
                CGPoint(x: 0.45, y: -0.75),
                CGPoint(x: -0.45, y: -0.75),
                CGPoint(x: -0.80, y: -0.30),
                CGPoint(x: -0.80, y: 0.20),
                CGPoint(x: -0.55, y: 0.65),
            ]

        // ---------- DOMINION (red) ----------

        case "void_reaper":
            // Crescent / scythe — dominant inner curve.
            return [
                CGPoint(x: 0,    y: 1.00),
                CGPoint(x: 0.55, y: 0.30),
                CGPoint(x: 0.90, y: -0.50),
                CGPoint(x: 0.30, y: -0.25),
                CGPoint(x: 0,    y: -0.55),
                CGPoint(x: -0.30, y: -0.25),
                CGPoint(x: -0.90, y: -0.50),
                CGPoint(x: -0.55, y: 0.30),
            ]

        case "scarab_striker":
            // Pointy beetle with spiked sides.
            return [
                CGPoint(x: 0,    y: 1.00),
                CGPoint(x: 0.35, y: 0.55),
                CGPoint(x: 0.75, y: 0.30),
                CGPoint(x: 0.55, y: 0),
                CGPoint(x: 0.85, y: -0.40),
                CGPoint(x: 0.30, y: -0.30),
                CGPoint(x: 0.20, y: -0.75),
                CGPoint(x: -0.20, y: -0.75),
                CGPoint(x: -0.30, y: -0.30),
                CGPoint(x: -0.85, y: -0.40),
                CGPoint(x: -0.55, y: 0),
                CGPoint(x: -0.75, y: 0.30),
                CGPoint(x: -0.35, y: 0.55),
            ]

        case "obsidian_maw":
            // Angular dreadnought — massive blocky brick with serrated jaw.
            return [
                CGPoint(x: 0.30, y: 0.95),
                CGPoint(x: 0.85, y: 0.65),
                CGPoint(x: 0.95, y: 0.10),
                CGPoint(x: 0.80, y: -0.35),
                CGPoint(x: 0.55, y: -0.45),
                CGPoint(x: 0.65, y: -0.75),
                CGPoint(x: 0.25, y: -0.55),
                CGPoint(x: 0,    y: -0.85),
                CGPoint(x: -0.25, y: -0.55),
                CGPoint(x: -0.65, y: -0.75),
                CGPoint(x: -0.55, y: -0.45),
                CGPoint(x: -0.80, y: -0.35),
                CGPoint(x: -0.95, y: 0.10),
                CGPoint(x: -0.85, y: 0.65),
                CGPoint(x: -0.30, y: 0.95),
            ]

        case "wraith_phantom":
            // Curvy ghost — narrow forward, wider rear with tendril-tail.
            return [
                CGPoint(x: 0,    y: 1.00),
                CGPoint(x: 0.30, y: 0.50),
                CGPoint(x: 0.65, y: 0.10),
                CGPoint(x: 0.75, y: -0.40),
                CGPoint(x: 0.40, y: -0.55),
                CGPoint(x: 0.20, y: -0.85),
                CGPoint(x: 0,    y: -0.60),
                CGPoint(x: -0.20, y: -0.85),
                CGPoint(x: -0.40, y: -0.55),
                CGPoint(x: -0.75, y: -0.40),
                CGPoint(x: -0.65, y: 0.10),
                CGPoint(x: -0.30, y: 0.50),
            ]

        case "bone_spear":
            // Long harpoon with barbed shaft and rear vanes.
            return [
                CGPoint(x: 0,    y: 1.00),
                CGPoint(x: 0.25, y: 0.55),
                CGPoint(x: 0.10, y: 0.30),
                CGPoint(x: 0.30, y: 0),
                CGPoint(x: 0.10, y: -0.20),
                CGPoint(x: 0.20, y: -0.40),
                CGPoint(x: 0.55, y: -0.65),
                CGPoint(x: 0.10, y: -0.55),
                CGPoint(x: 0.05, y: -0.85),
                CGPoint(x: -0.05, y: -0.85),
                CGPoint(x: -0.10, y: -0.55),
                CGPoint(x: -0.55, y: -0.65),
                CGPoint(x: -0.20, y: -0.40),
                CGPoint(x: -0.10, y: -0.20),
                CGPoint(x: -0.30, y: 0),
                CGPoint(x: -0.10, y: 0.30),
                CGPoint(x: -0.25, y: 0.55),
            ]

        case "crimson_tyrant":
            // Three-peak crown — the flagship.
            return [
                CGPoint(x: 0,     y: 1.00),
                CGPoint(x: 0.20,  y: 0.55),
                CGPoint(x: 0.55,  y: 0.85),
                CGPoint(x: 0.50,  y: 0.30),
                CGPoint(x: 0.85,  y: 0.10),
                CGPoint(x: 0.65,  y: -0.30),
                CGPoint(x: 0.85,  y: -0.65),
                CGPoint(x: 0.30,  y: -0.55),
                CGPoint(x: 0.10,  y: -0.85),
                CGPoint(x: -0.10, y: -0.85),
                CGPoint(x: -0.30, y: -0.55),
                CGPoint(x: -0.85, y: -0.65),
                CGPoint(x: -0.65, y: -0.30),
                CGPoint(x: -0.85, y: 0.10),
                CGPoint(x: -0.50, y: 0.30),
                CGPoint(x: -0.55, y: 0.85),
                CGPoint(x: -0.20, y: 0.55),
            ]

        default:
            // Fallback: simple triangle.
            return [
                CGPoint(x: 0,    y: 1.00),
                CGPoint(x: 0.70, y: -0.60),
                CGPoint(x: -0.70, y: -0.60),
            ]
        }
    }

    /// CGPath for SpriteKit. `size` is the half-extent (radius-equivalent).
    static func cgPath(for shipID: String, size: CGFloat) -> CGPath {
        let pts = normalizedPoints(for: shipID)
        let path = CGMutablePath()
        for (i, p) in pts.enumerated() {
            let cp = CGPoint(x: p.x * size, y: p.y * size)
            if i == 0 { path.move(to: cp) } else { path.addLine(to: cp) }
        }
        path.closeSubpath()
        return path
    }

    /// SwiftUI Path scaled to fit a rect. Note: SwiftUI uses +y down so we flip the y axis.
    static func swiftUIPath(for shipID: String, in rect: CGRect) -> Path {
        let pts = normalizedPoints(for: shipID)
        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) / 2
        var path = Path()
        for (i, p) in pts.enumerated() {
            let pt = CGPoint(x: cx + p.x * r, y: cy - p.y * r)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - SwiftUI shape wrapper for use in previews / Ship Select / Compendium

/// SwiftUI `Shape` rendering a ship's silhouette from its ID. Use with `.fill()` and `.stroke()`.
struct ShipHullShape: Shape {
    let shipID: String
    func path(in rect: CGRect) -> Path {
        // Inset slightly so the stroke doesn't clip at the edge.
        ShipHullDesigner.swiftUIPath(for: shipID, in: rect.insetBy(dx: 2, dy: 2))
    }
}
