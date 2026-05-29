import SwiftUI
import Combine

/// Gentle first-match-only hint overlay (SuperGrok addition, Section 16.8).
///
/// Shows translucent labels near each control on the very first match the player runs.
/// Each hint fades as soon as the player uses the matching input. A safety timeout fades
/// any remaining hints after 8 seconds so the overlay never overstays its welcome.
/// Persists "seen" via UserDefaults so it never appears again on subsequent matches.
///
/// Audit fix: the previous version kept a `Timer.publish.autoconnect()` running for the
/// view's lifetime even after dismissal. The cancellable is now stored in @State and
/// `.cancel()`-ed on dismiss, and the timer is only created when hints are actually visible.
struct OnboardingHintsOverlay: View {
    @ObservedObject var input: InputState

    private let key = "onboarding.firstMatchSeen"

    @State private var stickHinted = false
    @State private var aHinted = false
    @State private var bHinted = false
    @State private var zHinted = false
    @State private var elapsed: TimeInterval = 0
    @State private var allDismissed = false
    @State private var timerCancellable: AnyCancellable?
    /// Captured once on appear so the body doesn't reread UserDefaults on every redraw.
    @State private var alreadySeen: Bool = true

    private let maxSeconds: TimeInterval = 8

    var body: some View {
        ZStack {
            if !alreadySeen && !allDismissed {
                // Stick turns the ship; the X button thrusts. (The stick does NOT thrust —
                // calling that out explicitly here because it's the most common confusion.)
                hintCard("Drag stick → TURN\nX button → THRUST",
                         visible: !stickHinted,
                         alignment: .bottomLeading,
                         offsetX: 180, offsetY: -110)

                hintCard("A = primary fire\nB = secondary fire",
                         visible: !aHinted || !bHinted,
                         alignment: .bottomTrailing,
                         offsetX: -160, offsetY: -130,
                         color: Color(.sRGB, red: 1.0, green: 0.85, blue: 0.10))

                hintCard("Z = Speed Boost\n(15% battery)",
                         visible: !zHinted,
                         alignment: .bottomTrailing,
                         offsetX: -100, offsetY: -200,
                         color: Color(.sRGB, red: 1.0, green: 0.0, blue: 0.67))
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            alreadySeen = UserDefaults.standard.bool(forKey: key)
            if !alreadySeen {
                // Start the polling timer only when we have hints to show.
                timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
                    .autoconnect()
                    .sink { _ in
                        elapsed += 0.1
                        if elapsed > maxSeconds || (stickHinted && aHinted && bHinted && zHinted) {
                            dismissAll()
                        }
                    }
            }
        }
        .onDisappear { timerCancellable?.cancel() }
        .onChange(of: input.stickX) { _, _ in if input.stickMagnitude > 0.18 { stickHinted = true } }
        .onChange(of: input.stickY) { _, _ in if input.stickMagnitude > 0.18 { stickHinted = true } }
        .onChange(of: input.aPressed) { _, p in if p { aHinted = true } }
        .onChange(of: input.bPressed) { _, p in if p { bHinted = true } }
        .onChange(of: input.zPressed) { _, p in if p { zHinted = true } }
    }

    private func dismissAll() {
        allDismissed = true
        timerCancellable?.cancel()
        timerCancellable = nil
        UserDefaults.standard.set(true, forKey: key)
    }

    @ViewBuilder
    private func hintCard(_ text: String,
                          visible: Bool,
                          alignment: Alignment,
                          offsetX: CGFloat,
                          offsetY: CGFloat,
                          color: Color = Color(.sRGB, red: 0, green: 1.0, blue: 0.84)) -> some View {
        if visible {
            GeometryReader { geo in
                Text(text)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(color)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.7))
                    .overlay(Rectangle().stroke(color, lineWidth: 1.5))
                    .shadow(color: color.opacity(0.5), radius: 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                    .padding(.leading, alignment == .bottomLeading ? offsetX : 0)
                    .padding(.trailing, alignment == .bottomTrailing ? abs(offsetX) : 0)
                    .padding(.bottom, abs(offsetY))
                    .transition(.opacity)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .animation(.easeOut(duration: 0.3), value: visible)
        }
    }
}
