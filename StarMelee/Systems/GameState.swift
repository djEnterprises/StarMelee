import Foundation
import Combine
import CoreGraphics

/// Bridge between the SpriteKit `CombatScene` and the SwiftUI HUD overlay.
///
/// The scene writes here each frame; the SwiftUI HUD observes these published properties.
/// Keeps the gameplay logic in SpriteKit (60 FPS, deterministic) and the cosmetic UI in SwiftUI.
@MainActor
final class GameState: ObservableObject {

    // Player stat fractions (0...1)
    @Published var playerHealth: CGFloat = 1.0
    @Published var playerShield: CGFloat = 1.0
    @Published var playerBattery: CGFloat = 1.0
    @Published var playerName: String = "—"

    // Enemy stat fractions
    @Published var enemyHealth: CGFloat = 1.0
    @Published var enemyName: String = "—"

    // Off-screen enemy indicator (Section 4)
    /// True when the enemy is currently in the camera viewport.
    @Published var enemyOnScreen: Bool = true
    /// Direction vector from camera center to enemy, in screen-space coordinates.
    /// SwiftUI uses +y down; we publish in that space so the HUD can use it directly.
    @Published var enemyScreenDirection: CGVector = .zero
    /// Distance between player and enemy in world units.
    @Published var enemyDistanceUnits: CGFloat = 0

    // Match flow (Phase 2 will populate)
    @Published var matchPhaseLabel: String = "PRACTICE"
}
