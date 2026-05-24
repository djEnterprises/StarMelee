import SwiftUI
import SpriteKit

/// SwiftUI host for `CombatScene`. Composes the SpriteKit view, the HUD overlay,
/// and the touch controls (analog joystick + 6-button cluster).
struct CombatSceneView: View {
    let playerShipID: String

    @StateObject private var input = InputState()
    @StateObject private var gameState = GameState()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // SpriteKit scene fills the entire viewport.
            SpriteView(
                scene: makeScene(),
                options: [.ignoresSiblingOrder],
                debugOptions: []
            )
            .ignoresSafeArea()

            // HUD — read-only overlay, never blocks input.
            CombatHUDOverlay(gameState: gameState)

            // Series-end overlay (Section 4 step 8 — WINNER + FATALITY if applicable).
            if gameState.seriesEnded {
                VictoryView(
                    winnerName: gameState.seriesWinnerIsPlayer ? gameState.playerName : gameState.enemyName,
                    isFatality: gameState.isFatality,
                    onReplay: { dismiss() },        // Phase 2 stub: bounce to menu, Phase 3 will rematch in place
                    onChangeShip: { dismiss() },
                    onMainMenu: { dismiss() }
                )
                .transition(.opacity)
            }

            // Touch controls — analog stick bottom-left, buttons bottom-right.
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Text("EXIT")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.5))
                            .overlay(
                                Rectangle().stroke(Color(.sRGB, red: 1.0, green: 0.2, blue: 0.4), lineWidth: 1)
                            )
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 16)
                }
                Spacer()
                HStack(alignment: .bottom) {
                    AnalogStickView(input: input)
                        .padding(.leading, 24)
                        .padding(.bottom, 24)
                    Spacer()
                    ButtonClusterView(input: input)
                        .padding(.trailing, 24)
                        .padding(.bottom, 24)
                }
            }
        }
        .navigationBarBackButtonHiddenIfAvailable()
    }

    private func makeScene() -> CombatScene {
        let scene = CombatScene(size: CGSize(width: 1024, height: 768))
        scene.playerShipID = playerShipID
        scene.scaleMode = .resizeFill
        scene.input = input
        scene.gameState = gameState
        return scene
    }
}

private extension View {
    @ViewBuilder
    func navigationBarBackButtonHiddenIfAvailable() -> some View {
        #if os(iOS)
        self.navigationBarBackButtonHidden(true)
        #else
        self
        #endif
    }
}

#Preview {
    CombatSceneView(playerShipID: "aegis_cruiser")
}
