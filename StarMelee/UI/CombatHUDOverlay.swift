import SwiftUI

/// Phase 1 HUD overlay — minimal: player + enemy health bars, off-screen enemy indicator,
/// and a small "PRACTICE / MATCH" label placeholder.
///
/// **Plan reference:** Section 14 (HUD design — Mortal Kombat 1 style life bars).
/// Phase 2 will add full life/shield/battery stacks, match timer, score, minimap, power-up chips.
struct CombatHUDOverlay: View {
    @ObservedObject var gameState: GameState

    private let allianceCyan = Color(.sRGB, red: 0, green: 1.0, blue: 0.84)
    private let dominionRed  = Color(.sRGB, red: 1.0, green: 0.2, blue: 0.4)

    var body: some View {
        ZStack {
            // Top stat bars + match label
            VStack {
                HStack(alignment: .top, spacing: 16) {
                    playerPanel
                    Spacer()
                    matchCenterLabel
                    Spacer()
                    enemyPanel
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                Spacer()
            }

            // Off-screen enemy indicator
            GeometryReader { geo in
                if !gameState.enemyOnScreen {
                    OffscreenIndicator(
                        direction: gameState.enemyScreenDirection,
                        distance: gameState.enemyDistanceUnits,
                        viewportSize: geo.size,
                        color: dominionRed
                    )
                }
            }
            .allowsHitTesting(false)
        }
        .allowsHitTesting(false)   // overlay never blocks input; the stick/buttons sit above
    }

    private var playerPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(gameState.playerName)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(allianceCyan)
            statBar(fraction: gameState.playerHealth, color: healthColor(gameState.playerHealth))
            statBar(fraction: gameState.playerShield, color: allianceCyan.opacity(0.7))
                .frame(height: 4)
            statBar(fraction: gameState.playerBattery, color: .yellow.opacity(0.8))
                .frame(height: 4)
        }
        .frame(width: 180, alignment: .leading)
        .padding(8)
        .background(Color.black.opacity(0.55))
        .overlay(Rectangle().stroke(allianceCyan, lineWidth: 1))
    }

    private var enemyPanel: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(gameState.enemyName)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(dominionRed)
            statBar(fraction: gameState.enemyHealth, color: healthColor(gameState.enemyHealth), reversed: true)
        }
        .frame(width: 180, alignment: .trailing)
        .padding(8)
        .background(Color.black.opacity(0.55))
        .overlay(Rectangle().stroke(dominionRed, lineWidth: 1))
    }

    private var matchCenterLabel: some View {
        VStack(spacing: 2) {
            Text("STAR MELEE")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.7))
            Text(gameState.matchPhaseLabel)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.yellow)
        }
    }

    private func statBar(fraction: CGFloat, color: Color, reversed: Bool = false) -> some View {
        GeometryReader { geo in
            ZStack(alignment: reversed ? .trailing : .leading) {
                Rectangle().fill(Color.black.opacity(0.6))
                Rectangle()
                    .fill(color)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
                    .shadow(color: color.opacity(0.6), radius: 4)
            }
        }
        .frame(height: 10)
    }

    private func healthColor(_ f: CGFloat) -> Color {
        if f > 0.70 { return Color(.sRGB, red: 0.1, green: 1.0, blue: 0.3) }
        if f > 0.35 { return Color(.sRGB, red: 1.0, green: 0.85, blue: 0.1) }
        return Color(.sRGB, red: 1.0, green: 0.3, blue: 0.2)
    }
}

private struct OffscreenIndicator: View {
    let direction: CGVector
    let distance: CGFloat
    let viewportSize: CGSize
    let color: Color

    var body: some View {
        // Clamp the direction to the viewport edge, leaving safe padding for HUD + controls.
        let safePadding: CGFloat = 70
        let halfW = max(1, viewportSize.width / 2 - safePadding)
        let halfH = max(1, viewportSize.height / 2 - safePadding)
        let dx = direction.dx
        let dy = direction.dy
        let mag = max(0.001, hypot(dx, dy))

        // Scale so the arrow sits on the edge of the safe rect.
        let scaleX = halfW / max(0.001, abs(dx))
        let scaleY = halfH / max(0.001, abs(dy))
        let scale = min(scaleX, scaleY)
        let offsetX = dx * scale
        let offsetY = dy * scale
        let angle = atan2(dy, dx)

        return VStack(spacing: 4) {
            Text("\(Int(distance)) u")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .shadow(color: .black, radius: 2)
            Triangle()
                .fill(color)
                .frame(width: 22, height: 22)
                .rotationEffect(.radians(Double(angle) + .pi / 2))
                .shadow(color: color.opacity(0.7), radius: 6)
        }
        .position(x: viewportSize.width / 2 + offsetX,
                  y: viewportSize.height / 2 + offsetY)
        // Magnitude unused now but referenced so the compiler stays quiet on future tweaks.
        .onAppear { _ = mag }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
