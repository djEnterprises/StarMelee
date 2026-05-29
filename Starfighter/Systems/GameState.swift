import Foundation
import Combine
import CoreGraphics

/// Equatable struct for minimap planet markers. Replaces the prior
/// `[(CGPoint, CGFloat)]` tuple — tuples aren't Equatable so SwiftUI couldn't
/// diff them and rebuilt the minimap on every `objectWillChange`.
struct PlanetMarker: Equatable, Hashable {
    let position: CGPoint
    let radius: CGFloat
}

/// Bridge between the SpriteKit `CombatScene` and the SwiftUI HUD overlay.
///
/// **Performance audit:** every `@Published` property has an equality-checked manual setter
/// (via `didSet { if oldValue != newValue { ... } }`) so that re-publishing identical values
/// from the per-frame `publishGameState()` doesn't trigger redundant SwiftUI invalidations.
/// CombatScene calls `publishGameState()` at 60–120 fps; without these guards, every observer
/// (HUD, minimap, off-screen indicator, victory overlay) would rebuild on every frame.
@MainActor
final class GameState: ObservableObject {

    // Helper that publishes only on real change.
    private func publish<T: Equatable>(_ oldValue: T, _ newValue: T) {
        if oldValue != newValue { objectWillChange.send() }
    }

    // MARK: - Player + enemy stats (0...1 fractions)

    var playerHealth: CGFloat = 1.0 { didSet { publish(oldValue, playerHealth) } }
    var playerShield: CGFloat = 1.0 { didSet { publish(oldValue, playerShield) } }
    var playerBattery: CGFloat = 1.0 { didSet { publish(oldValue, playerBattery) } }
    var playerName: String = "—" { didSet { publish(oldValue, playerName) } }

    var enemyHealth: CGFloat = 1.0 { didSet { publish(oldValue, enemyHealth) } }
    var enemyShield: CGFloat = 1.0 { didSet { publish(oldValue, enemyShield) } }
    var enemyName: String = "—" { didSet { publish(oldValue, enemyName) } }

    // MARK: - Off-screen indicator

    var enemyOnScreen: Bool = true { didSet { publish(oldValue, enemyOnScreen) } }
    var enemyScreenDirection: CGVector = .zero {
        didSet {
            if oldValue.dx != enemyScreenDirection.dx || oldValue.dy != enemyScreenDirection.dy {
                objectWillChange.send()
            }
        }
    }
    var enemyDistanceUnits: CGFloat = 0 { didSet { publish(oldValue, enemyDistanceUnits) } }

    // MARK: - Match flow

    var matchPhaseLabel: String = "PRACTICE" { didSet { publish(oldValue, matchPhaseLabel) } }
    var preMatchSecondsRemaining: TimeInterval = 10 { didSet { publish(oldValue, preMatchSecondsRemaining) } }
    var matchSecondsRemaining: TimeInterval = 120 { didSet { publish(oldValue, matchSecondsRemaining) } }
    var inPreMatch: Bool = true { didSet { publish(oldValue, inPreMatch) } }
    var inActiveMatch: Bool = false { didSet { publish(oldValue, inActiveMatch) } }
    var matchNumber: Int = 1 { didSet { publish(oldValue, matchNumber) } }
    var playerWins: Int = 0 { didSet { publish(oldValue, playerWins) } }
    var opponentWins: Int = 0 { didSet { publish(oldValue, opponentWins) } }

    // MARK: - Pause (Section 9)

    var isPaused: Bool = false { didSet { publish(oldValue, isPaused) } }

    // MARK: - Series end overlay

    var seriesEnded: Bool = false { didSet { publish(oldValue, seriesEnded) } }
    var seriesWinnerIsPlayer: Bool = true { didSet { publish(oldValue, seriesWinnerIsPlayer) } }
    var isFatality: Bool = false { didSet { publish(oldValue, isFatality) } }

    // MARK: - Tactical minimap (Section 4 + 14)

    var worldRect: CGRect = .zero {
        didSet {
            if oldValue != worldRect { objectWillChange.send() }
        }
    }
    var cameraViewport: CGRect = .zero {
        didSet {
            if oldValue != cameraViewport { objectWillChange.send() }
        }
    }
    var playerWorldPos: CGPoint = .zero {
        didSet {
            if oldValue != playerWorldPos { objectWillChange.send() }
        }
    }
    var enemyWorldPos: CGPoint = .zero {
        didSet {
            if oldValue != enemyWorldPos { objectWillChange.send() }
        }
    }
    /// Captured once at world build time — never changes mid-match.
    var planetMarkers: [PlanetMarker] = [] { didSet { publish(oldValue, planetMarkers) } }
    /// Power-up positions — replaced each frame. Equality check skips publish when the set
    /// is unchanged (most frames between spawns/collections).
    var powerUpMarkers: [CGPoint] = [] {
        didSet {
            if oldValue != powerUpMarkers { objectWillChange.send() }
        }
    }
}
