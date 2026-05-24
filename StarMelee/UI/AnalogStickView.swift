import SwiftUI

/// PS5-style analog joystick.
///
/// **Plan reference:** Section 9 — circular base ~140 pt, inner stick ~64 pt, deadzone 0.18.
/// - DragGesture(minimumDistance: 0) tracks the single touch that started the drag, so the
///   stick keeps tracking even when the finger drifts outside the base bounds.
/// - SwiftUI assigns each finger to whichever gesture's hit-area it landed on, so other
///   fingers pressing the A/B/C/X/Y/Z buttons do not disturb the stick. This is the
///   "multitouch correctness" Section 9 calls out.
struct AnalogStickView: View {
    @ObservedObject var input: InputState

    var baseDiameter: CGFloat = 140
    var stickDiameter: CGFloat = 64

    @State private var stickOffset: CGSize = .zero
    @State private var isDragging: Bool = false

    private var maxOffset: CGFloat { (baseDiameter - stickDiameter) / 2 }

    var body: some View {
        ZStack {
            // Outer base with cyan border + inner dashed detail ring.
            Circle()
                .fill(Color.black.opacity(0.45))
                .overlay(
                    Circle().stroke(Color(.sRGB, red: 0, green: 1.0, blue: 0.84, opacity: 0.7), lineWidth: 2)
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            Color(.sRGB, red: 0, green: 1.0, blue: 0.84, opacity: 0.25),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 6])
                        )
                        .padding(10)
                )
                .frame(width: baseDiameter, height: baseDiameter)

            // Inner stick with concave shading + drop shadow.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(.sRGB, red: 0.05, green: 0.10, blue: 0.13),
                            Color(.sRGB, red: 0.15, green: 0.22, blue: 0.26)
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: stickDiameter / 2
                    )
                )
                .overlay(
                    Circle().stroke(
                        Color(.sRGB, red: 0, green: 1.0, blue: 0.84, opacity: 0.5),
                        lineWidth: 1.5
                    )
                )
                .shadow(color: .black.opacity(0.7), radius: 4, x: 0, y: 2)
                .frame(width: stickDiameter, height: stickDiameter)
                .offset(stickOffset)
                .animation(isDragging ? nil : .interpolatingSpring(stiffness: 220, damping: 14), value: stickOffset)
        }
        .frame(width: baseDiameter, height: baseDiameter)
        .contentShape(Circle())
        .gesture(stickGesture)
    }

    private var stickGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                isDragging = true
                // Distance from the center of the base. SwiftUI gives us .location relative to the view.
                let centerX = baseDiameter / 2
                let centerY = baseDiameter / 2
                var dx = value.location.x - centerX
                var dy = value.location.y - centerY
                let mag = sqrt(dx*dx + dy*dy)
                if mag > maxOffset {
                    dx *= maxOffset / mag
                    dy *= maxOffset / mag
                }
                stickOffset = CGSize(width: dx, height: dy)

                // Publish normalized vector with deadzone.
                // Note: SwiftUI's +y is downward, so flip Y for gameplay (which uses standard math axes).
                let normX = dx / maxOffset
                let normYGame = -(dy / maxOffset)
                let normalizedMag = sqrt(normX*normX + normYGame*normYGame)
                if normalizedMag < WorldConstants.stickDeadzone {
                    input.stickX = 0
                    input.stickY = 0
                } else {
                    input.stickX = normX
                    input.stickY = normYGame
                }
            }
            .onEnded { _ in
                isDragging = false
                stickOffset = .zero
                input.stickX = 0
                input.stickY = 0
            }
    }
}

#Preview {
    AnalogStickView(input: InputState())
        .padding()
        .background(Color.black)
}
