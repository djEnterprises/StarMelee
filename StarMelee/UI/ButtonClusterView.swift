import SwiftUI

/// Bottom-right 6-button cluster: top row X / Y / Z, bottom row A / B / C.
///
/// **Plan reference:** Section 9 (Sega Genesis / 8BitDo M30 layout).
/// Each button owns its own `DragGesture(minimumDistance: 0)` so SwiftUI assigns each finger
/// to whichever button it landed on — fingers on different buttons don't interfere.
struct ButtonClusterView: View {
    @ObservedObject var input: InputState

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ControlButton(label: "X", tint: .cyan, isPressed: Binding(
                    get: { input.xPressed }, set: { input.xPressed = $0 }))
                ControlButton(label: "Y", tint: .cyan, isPressed: Binding(
                    get: { input.yPressed }, set: { input.yPressed = $0 }))
                ControlButton(label: "Z", tint: Color(.sRGB, red: 1.0, green: 0, blue: 0.67, opacity: 1), isPressed: Binding(
                    get: { input.zPressed }, set: { input.zPressed = $0 }))
            }
            HStack(spacing: 10) {
                ControlButton(label: "A", tint: .yellow, isPressed: Binding(
                    get: { input.aPressed }, set: { input.aPressed = $0 }))
                ControlButton(label: "B", tint: .yellow, isPressed: Binding(
                    get: { input.bPressed }, set: { input.bPressed = $0 }))
                ControlButton(label: "C", tint: Color(.sRGB, red: 1.0, green: 0, blue: 0.67, opacity: 1), isPressed: Binding(
                    get: { input.cPressed }, set: { input.cPressed = $0 }))
            }
        }
    }
}

private struct ControlButton: View {
    let label: String
    let tint: Color
    @Binding var isPressed: Bool

    private let size: CGFloat = 60

    var body: some View {
        ZStack {
            Circle()
                .fill(isPressed ? tint : tint.opacity(0.15))
                .overlay(Circle().stroke(tint, lineWidth: 2))
                .shadow(color: tint.opacity(isPressed ? 0.9 : 0.4), radius: isPressed ? 14 : 6)
            Text(label)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(isPressed ? .black : tint)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { _ in
                    if !isPressed { isPressed = true }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

#Preview {
    ButtonClusterView(input: InputState())
        .padding()
        .background(Color.black)
}
