import SwiftUI
import SpriteKit

/// SwiftUI host for `CombatScene`. Composes the SpriteKit view, the HUD overlay, the touch
/// controls, the series-end overlay, and (on Mac Catalyst / hardware keyboards) keyboard input.
struct CombatSceneView: View {
    let playerShipID: String

    @StateObject private var input = InputState()
    @StateObject private var gameState = GameState()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var sceneFocused: Bool

    var body: some View {
        ZStack {
            SpriteView(
                scene: makeScene(),
                options: [.ignoresSiblingOrder],
                debugOptions: []
            )
            .ignoresSafeArea()

            CombatHUDOverlay(gameState: gameState)

            if gameState.seriesEnded {
                VictoryView(
                    winnerName: gameState.seriesWinnerIsPlayer ? gameState.playerName : gameState.enemyName,
                    isFatality: gameState.isFatality,
                    onReplay: { dismiss() },
                    onChangeShip: { dismiss() },
                    onMainMenu: { dismiss() }
                )
                .transition(.opacity)
            }

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
                            .overlay(Rectangle().stroke(Color(.sRGB, red: 1.0, green: 0.2, blue: 0.4), lineWidth: 1))
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
        .focusable()
        .focused($sceneFocused)
        .onAppear { sceneFocused = true }
        .onKeyPress(phases: [.down, .up]) { press in handleKey(press) }
    }

    private func makeScene() -> CombatScene {
        let scene = CombatScene(size: CGSize(width: 1024, height: 768))
        scene.playerShipID = playerShipID
        scene.scaleMode = .resizeFill
        scene.input = input
        scene.gameState = gameState
        return scene
    }

    // MARK: - Keyboard (Section 10)
    //
    // Modern SwiftUI .onKeyPress works on Mac Catalyst and on iPad with hardware keyboards.
    // We map each key onto the same InputState fields the touch controls write to, so the
    // gameplay code stays input-agnostic.
    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        let pressed = press.phase == .down || press.phase == .repeat
        switch press.key {
        case .space:           input.aPressed = pressed
        case KeyEquivalent("f"): input.bPressed = pressed
        case KeyEquivalent("g"): input.cPressed = pressed
        case .upArrow:         input.xPressed = pressed
        case KeyEquivalent("w"): input.xPressed = pressed
        case .downArrow:       input.yPressed = pressed
        case KeyEquivalent("s"): input.yPressed = pressed
        case .leftArrow:       setStickX(pressed ? -1 : 0, ifMatching: -1)
        case KeyEquivalent("a"): setStickX(pressed ? -1 : 0, ifMatching: -1)
        case .rightArrow:      setStickX(pressed ? 1 : 0, ifMatching: 1)
        case KeyEquivalent("d"): setStickX(pressed ? 1 : 0, ifMatching: 1)
        case KeyEquivalent("p"): if pressed { /* Phase 2 stub — pause hookup pending */ }
        case .escape:          if pressed { dismiss() }
        default:               return .ignored
        }
        return .handled
    }

    /// Set stickX, but on release only clear if the current value matches our key direction.
    /// This avoids "release of right arrow" wiping a still-held left arrow.
    private func setStickX(_ newValue: CGFloat, ifMatching match: CGFloat) {
        if newValue != 0 {
            input.stickX = newValue
        } else if input.stickX == match {
            input.stickX = 0
        }
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
