import SwiftUI

/// Phase 2 owner: overlay shown when match is paused. See plan Section 9 "Pause Menu".
struct PauseView: View {
    let onResume: () -> Void
    let onRestart: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("PAUSED")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .tracking(8)
                    .foregroundStyle(Color(.sRGB, red: 0, green: 1.0, blue: 0.84))

                Button("RESUME", action: onResume)
                Button("RESTART MATCH", action: onRestart)
                Button("QUIT TO MENU", role: .destructive, action: onQuit)
            }
            .buttonStyle(.bordered)
        }
    }
}

#Preview {
    PauseView(onResume: {}, onRestart: {}, onQuit: {})
}
