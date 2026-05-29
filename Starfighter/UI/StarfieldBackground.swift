import SwiftUI

/// Decorative starfield used behind menu screens. The in-arena starfield lives in `CombatScene`.
struct StarfieldBackground: View {
    private struct Star: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let opacity: Double
    }

    private static let stars: [Star] = (0..<140).map { _ in
        Star(
            x: CGFloat.random(in: 0...1),
            y: CGFloat.random(in: 0...1),
            size: CGFloat.random(in: 0.5...2.4),
            opacity: Double.random(in: 0.25...0.95)
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(.sRGB, red: 0.08, green: 0.0, blue: 0.16, opacity: 1),
                        .black
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                ForEach(Self.stars) { star in
                    Circle()
                        .fill(.white)
                        .frame(width: star.size, height: star.size)
                        .opacity(star.opacity)
                        .position(x: star.x * geo.size.width, y: star.y * geo.size.height)
                }
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    StarfieldBackground()
}
