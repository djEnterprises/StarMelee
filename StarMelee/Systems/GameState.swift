import Foundation
import Combine
import CoreGraphics

/// Bridge between the SpriteKit `CombatScene` and the SwiftUI HUD overlay.
@MainActor
final class GameState: ObservableObject {

    // Player + enemy stats (0...1 fractions)
    @Published var playerHealth: CGFloat = 1.0
    @Published var playerShield: CGFloat = 1.0
    @Published var playerBattery: CGFloat = 1.0
    @Published var playerName: String = "—"

    @Published var enemyHealth: CGFloat = 1.0
    @Published var enemyShield: CGFloat = 1.0
    @Published var enemyName: String = "—"

    // Off-screen indicator
    @Published var enemyOnScreen: Bool = true
    @Published var enemyScreenDirection: CGVector = .zero
    @Published var enemyDistanceUnits: CGFloat = 0

    // Match flow
    @Published var matchPhaseLabel: String = "PRACTICE"
    @Published var preMatchSecondsRemaining: TimeInterval = 10
    @Published var matchSecondsRemaining: TimeInterval = 120
    @Published var inPreMatch: Bool = true
    @Published var inActiveMatch: Bool = false
    @Published var matchNumber: Int = 1
    @Published var playerWins: Int = 0
    @Published var opponentWins: Int = 0

    // Series end overlay
    @Published var seriesEnded: Bool = false
    @Published var seriesWinnerIsPlayer: Bool = true
    @Published var isFatality: Bool = false

    // Tactical minimap data (Section 4 + 14)
    /// World bounds in points — set once at scene start.
    @Published var worldRect: CGRect = .zero
    /// Current camera viewport in world coordinates — used for the minimap's viewport rectangle.
    @Published var cameraViewport: CGRect = .zero
    @Published var playerWorldPos: CGPoint = .zero
    @Published var enemyWorldPos: CGPoint = .zero
    /// Planet position + radius pairs, captured at world build time.
    @Published var planetMarkers: [(CGPoint, CGFloat)] = []
    /// Power-up positions — replaced each frame.
    @Published var powerUpMarkers: [CGPoint] = []
}
