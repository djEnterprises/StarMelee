import SwiftUI

/// HUD overlay — life/shield/battery bars, match timer, score, off-screen indicator,
/// pre-match countdown digit + PRACTICE banner.
///
/// **Plan reference:** Section 14 (HUD design), Section 4 (match flow), Section 23 #4/#5
/// (PRACTICE banner + semi-transparent countdown).
struct CombatHUDOverlay: View {
    @ObservedObject var gameState: GameState

    private let allianceCyan = Color(.sRGB, red: 0, green: 1.0, blue: 0.84)
    private let dominionRed  = Color(.sRGB, red: 1.0, green: 0.2, blue: 0.4)

    var body: some View {
        ZStack {
            // Top stat bars + center match info, with the tactical minimap docked under the
            // enemy panel on the right (Section 4 placement rule).
            VStack {
                HStack(alignment: .top, spacing: 16) {
                    playerPanel
                    Spacer()
                    matchCenterPanel
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        enemyPanel
                        MinimapView(gameState: gameState)
                    }
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

            // Pre-match countdown digit (Section 23 #5: ~35% opacity so arena stays visible)
            if gameState.inPreMatch {
                CountdownOverlay(secondsRemaining: gameState.preMatchSecondsRemaining)
            }
        }
        .allowsHitTesting(false)
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
            statBar(fraction: gameState.enemyShield, color: dominionRed.opacity(0.7), reversed: true)
                .frame(height: 4)
        }
        .frame(width: 180, alignment: .trailing)
        .padding(8)
        .background(Color.black.opacity(0.55))
        .overlay(Rectangle().stroke(dominionRed, lineWidth: 1))
    }

    private var matchCenterPanel: some View {
        VStack(spacing: 2) {
            Text("STAR MELEE")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.7))
            Text(formattedTimer)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(timerColor)
                .monospacedDigit()
            Text("\(gameState.matchPhaseLabel) — WINS \(gameState.playerWins)–\(gameState.opponentWins)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.yellow)
        }
    }

    private var formattedTimer: String {
        let s = gameState.inActiveMatch ? gameState.matchSecondsRemaining : MatchManager.activeMatchSeconds
        let secs = max(0, Int(ceil(s)))
        return String(format: "%d:%02d", secs / 60, secs % 60)
    }

    private var timerColor: Color {
        guard gameState.inActiveMatch else { return .white.opacity(0.5) }
        let s = gameState.matchSecondsRemaining
        if s <= 10 { return .red }
        if s <= 30 { return .yellow }
        return .white
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

// MARK: - Pre-match countdown overlay

private struct CountdownOverlay: View {
    let secondsRemaining: TimeInterval

    var body: some View {
        let digit = max(1, Int(ceil(secondsRemaining)))
        ZStack {
            // "PRACTICE" banner with hint text (Section 23 #4)
            VStack {
                Spacer().frame(height: 90)
                VStack(spacing: 6) {
                    Text("PRACTICE")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .tracking(6)
                        .foregroundStyle(Color(.sRGB, red: 1.0, green: 0.67, blue: 0))
                    Text("Move + fire A (primary) / B (secondary) to test your ship.\nSpecials, Boost, Transporter, Cloak unlock at MATCH START.")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
            }

            // Semi-transparent digit — 35% opacity per Section 23 #5
            Text("\(digit)")
                .font(.system(size: 280, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
                .shadow(color: Color(.sRGB, red: 0, green: 1.0, blue: 0.84, opacity: 0.4), radius: 30)
                .transition(.scale.combined(with: .opacity))
                .id(digit)   // re-trigger animation when digit changes
                .animation(.easeOut(duration: 0.4), value: digit)
        }
    }
}

// MARK: - Off-screen enemy indicator

private struct OffscreenIndicator: View {
    let direction: CGVector
    let distance: CGFloat
    let viewportSize: CGSize
    let color: Color

    var body: some View {
        let safePadding: CGFloat = 70
        let halfW = max(1, viewportSize.width / 2 - safePadding)
        let halfH = max(1, viewportSize.height / 2 - safePadding)
        let dx = direction.dx
        let dy = direction.dy
        let mag = max(0.001, hypot(dx, dy))
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
