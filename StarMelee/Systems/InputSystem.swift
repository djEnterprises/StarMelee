import Foundation
import Combine
import CoreGraphics

/// Shared input state — the SwiftUI controls write here, the SpriteKit scene reads every frame.
///
/// **Plan reference:** Section 9 (PS5-style analog joystick + A/B/C/X/Y/Z cluster).
/// The raw stick vector is exposed alongside the 8-way digital conversion so a Phase 2 Settings
/// toggle can switch to proportional turning/thrust later (Section 9 DECISION POINT).
@MainActor
final class InputState: ObservableObject {

    // Analog stick — components in -1...+1 with a deadzone applied.
    @Published var stickX: CGFloat = 0
    @Published var stickY: CGFloat = 0

    // Six-button cluster.
    @Published var aPressed: Bool = false   // primary fire
    @Published var bPressed: Bool = false   // secondary fire
    @Published var cPressed: Bool = false   // special weapon
    @Published var xPressed: Bool = false   // thrust
    @Published var yPressed: Bool = false   // brake
    @Published var zPressed: Bool = false   // speed boost

    // MARK: - Derived helpers

    /// Stick magnitude (0...1) after the deadzone is enforced by the source.
    var stickMagnitude: CGFloat { hypot(stickX, stickY) }

    /// Stick angle in radians (0 = right, π/2 = up).
    var stickAngle: CGFloat { atan2(stickY, stickX) }

    /// 8-way digital turn input. Section 9: "convert the stick to 8-way digital using the deadzone threshold."
    /// Returns -1 to turn left, +1 to turn right, 0 to hold heading.
    /// Phase 1 maps the stick's X axis to turning so the ship rotates in place — true Star Control
    /// feel where heading is decoupled from thrust direction.
    var turnDirection: CGFloat {
        let dz = WorldConstants.stickDeadzone
        if stickX < -dz { return -1 }
        if stickX >  dz { return  1 }
        return 0
    }
}
