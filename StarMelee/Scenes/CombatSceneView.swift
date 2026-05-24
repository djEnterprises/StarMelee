import SwiftUI
import SpriteKit

/// SwiftUI wrapper that presents `CombatScene` via `SpriteView`.
/// Phase 1 just hosts the scene; Phase 2 will overlay the HUD and touch controls.
struct CombatSceneView: View {
    let playerShipID: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            SpriteView(
                scene: makeScene(),
                options: [.ignoresSiblingOrder],
                debugOptions: []
            )
            .ignoresSafeArea()

            // Phase 1 exit affordance — placeholder until Phase 2 pause overlay lands.
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
                    .padding(20)
                }
                Spacer()
            }
        }
        .navigationBarBackButtonHiddenIfAvailable()
    }

    private func makeScene() -> CombatScene {
        let scene = CombatScene(size: CGSize(width: 1024, height: 768))
        scene.playerShipID = playerShipID
        scene.scaleMode = .resizeFill
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
