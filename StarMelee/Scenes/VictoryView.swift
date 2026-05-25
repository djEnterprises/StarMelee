import SwiftUI

/// Phase 2 owner: end-of-match screen. Shows WINNER banner, "FATALITY" tag if a Quantum Torpedo
/// delivered the killing blow (see plan Section 4 step 8), and Replay / Change Ship / Main Menu actions.
struct VictoryView: View {
    let winnerName: String
    let isFatality: Bool
    let onReplay: () -> Void
    let onChangeShip: () -> Void
    let onMainMenu: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("WINNER")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .tracking(8)
                    .foregroundStyle(Color(.sRGB, red: 1.0, green: 0.67, blue: 0))

                Text(winnerName)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(.white)

                if isFatality {
                    Text("FATALITY")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .tracking(12)
                        .foregroundStyle(Color(.sRGB, red: 1.0, green: 0.2, blue: 0.4))
                        .padding(.top, 12)
                }

                // SuperGrok Section 16.5: when any Fun Modifier is active, flag the result
                // so the player knows this run isn't eligible for Game Center submission.
                if FunModifiers.shared.anyActive {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("MODIFIERS ACTIVE — score not submitted")
                    }
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.6))
                    .overlay(Rectangle().stroke(.orange, lineWidth: 1))
                    .padding(.top, 4)
                }

                HStack(spacing: 12) {
                    Button("REPLAY", action: onReplay)
                    Button("CHANGE SHIP", action: onChangeShip)
                    Button("MAIN MENU", role: .destructive, action: onMainMenu)
                }
                .padding(.top, 24)
                .buttonStyle(.bordered)
            }
        }
    }
}

#Preview {
    VictoryView(winnerName: "AEGIS CRUISER", isFatality: true, onReplay: {}, onChangeShip: {}, onMainMenu: {})
}
