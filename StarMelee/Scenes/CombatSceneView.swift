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
    @State private var sceneRef: CombatScene?
    @State private var gamepadSource: GamepadInputSource?

    var body: some View {
        ZStack {
            SpriteView(
                scene: makeScene(),
                options: [.ignoresSiblingOrder],
                debugOptions: []
            )
            .ignoresSafeArea()

            CombatHUDOverlay(gameState: gameState)

            // First-match onboarding hints — no-op after the player completes their first match.
            OnboardingHintsOverlay(input: input)

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

            // Pause overlay (Section 9 pause menu)
            if gameState.isPaused {
                PauseView(
                    onResume:  { setPaused(false) },
                    onRestart: {
                        // Section 9: Restart counts as a loss for the current match.
                        sceneRef?.restartCurrentMatchAsLoss()
                        setPaused(false)
                    },
                    onQuit:    {
                        // Section 9: Quit is a forfeit. Record before dismissing.
                        sceneRef?.recordForfeitIfInProgress()
                        dismiss()
                    }
                )
                .transition(.opacity)
            }

            VStack {
                HStack(spacing: 8) {
                    Button {
                        setPaused(true)
                    } label: {
                        Text("‖ PAUSE")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.5))
                            .overlay(Rectangle().stroke(Color(.sRGB, red: 0, green: 1.0, blue: 0.84), lineWidth: 1))
                    }
                    .padding(.top, 8)
                    .padding(.leading, 16)

                    // Shield up/down toggle (Section 7). Tap to flip the player's shield state.
                    // Edge-detected by the scene so a long press doesn't keep flipping.
                    Button {
                        input.shieldTogglePressed = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            input.shieldTogglePressed = false
                        }
                    } label: {
                        Text("◯ SHIELD")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.5))
                            .overlay(Rectangle().stroke(Color(.sRGB, red: 0.4, green: 0.8, blue: 1.0), lineWidth: 1))
                    }
                    .padding(.top, 8)

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
        .onAppear {
            sceneFocused = true
            if gamepadSource == nil {
                gamepadSource = GamepadInputSource(inputState: input)
            }
        }
        .onKeyPress(phases: [.down, .up]) { press in handleKey(press) }
    }

    private func makeScene() -> CombatScene {
        let scene = CombatScene(size: CGSize(width: 1024, height: 768))
        scene.playerShipID = playerShipID
        scene.scaleMode = .resizeFill
        scene.input = input
        scene.gameState = gameState
        // SpriteKit owns the scene; we keep a reference so the pause toggle can reach it.
        DispatchQueue.main.async { self.sceneRef = scene }
        return scene
    }

    private func setPaused(_ paused: Bool) {
        gameState.isPaused = paused
        sceneRef?.customPaused = paused
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
        case KeyEquivalent("p"): if pressed { setPaused(!gameState.isPaused) }
        case .escape:          if pressed { setPaused(!gameState.isPaused) }
        case KeyEquivalent("r"):
            // Shield toggle — edge-detected by the scene, so just pulse the flag.
            if pressed {
                input.shieldTogglePressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    input.shieldTogglePressed = false
                }
            }
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
