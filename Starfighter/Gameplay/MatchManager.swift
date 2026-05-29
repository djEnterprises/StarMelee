import Foundation
import CoreGraphics

/// Drives the match phase state machine for a 2-of-3 series.
///
/// **Plan reference:** Section 4 (Match Structure), Section 23 (countdown rules).
@MainActor
final class MatchManager {

    enum Phase: Equatable {
        /// 10-second practice phase. Primary + secondary firing allowed (Section 23 #2);
        /// specials, combos, boost, transporter, cloak locked; gravity ramps in last 5s.
        case preMatch(remaining: TimeInterval)

        /// Full combat — 2-minute timer running.
        case active(remaining: TimeInterval)

        /// Brief gap between matches in a series (Section 4 step 6 — 3 seconds, ships reset).
        case interMatch(remaining: TimeInterval)

        /// First to 2 wins — series complete.
        case seriesEnded(winner: Ship.Side, fatality: Bool)
    }

    /// Emitted on phase transitions so the scene can react (haptics, reset positions, present overlays).
    enum PhaseChange {
        case countdownEnded
        case matchEnded(winner: Ship.Side, fatality: Bool)
        case nextMatchStarted(matchNumber: Int)
        case seriesEnded(winner: Ship.Side, fatality: Bool)
    }

    // MARK: - Constants
    static let preMatchSeconds: TimeInterval = 10
    static let defaultMatchSeconds: TimeInterval = 120   // Section 4: 2-minute timer (default)
    static let interMatchSeconds: TimeInterval = 3
    static let gravityRampSeconds: TimeInterval = 5     // Section 23 #3

    /// Per-match active duration. Read from the `settings.matchLengthSeconds` picker
    /// (90 / 120 / 180 / 300) at construction; falls back to the 120s default. This makes the
    /// Settings → Match Length control actually take effect (previously it was ignored).
    let matchDuration: TimeInterval

    // MARK: - State
    private(set) var phase: Phase = .preMatch(remaining: MatchManager.preMatchSeconds)
    private(set) var matchNumber: Int = 1
    private(set) var playerWins: Int = 0
    private(set) var opponentWins: Int = 0
    /// Persists across the inter-match phase so the series-end victory screen knows whether
    /// to show FATALITY (Section 4 step 8). Reset when a new match starts.
    private var lastMatchFatality: Bool = false

    /// - Parameter matchDuration: per-match seconds. Pass `nil` to read the player's
    ///   `settings.matchLengthSeconds` preference (default 120).
    init(matchDuration: TimeInterval? = nil) {
        if let matchDuration {
            self.matchDuration = matchDuration
        } else {
            let saved = UserDefaults.standard.object(forKey: "settings.matchLengthSeconds") as? Int
            self.matchDuration = TimeInterval(saved ?? Int(Self.defaultMatchSeconds))
        }
    }

    /// Section 23 #8: gameplay code reads this single flag. Primary + secondary fire ignore it
    /// (they always work in active phases); specials, combos, and boost respect it.
    var allowSpecials: Bool {
        if case .active = phase { return true }
        return false
    }

    /// Section 23 #3: planet gravity ramps from 0 → 1 over the last 5 seconds of the countdown.
    /// Returns 1 during active play, 0 between matches and at series end.
    var gravityRampFactor: CGFloat {
        switch phase {
        case .preMatch(let remaining):
            if remaining >= Self.gravityRampSeconds { return 0 }
            return CGFloat((Self.gravityRampSeconds - remaining) / Self.gravityRampSeconds)
        case .active:
            return 1
        case .interMatch, .seriesEnded:
            return 0
        }
    }

    var isSeriesOver: Bool {
        if case .seriesEnded = phase { return true }
        return false
    }

    /// Human-readable label for the HUD.
    var phaseLabel: String {
        switch phase {
        case .preMatch:           return "PRACTICE"
        case .active:             return "MATCH \(matchNumber) OF 3"
        case .interMatch:         return "NEXT MATCH"
        case .seriesEnded(let w, _): return w == .player ? "VICTORY" : "DEFEAT"
        }
    }

    // MARK: - Tick

    /// Advance time. Returns a `PhaseChange` event if a transition fired this frame.
    /// - Parameters:
    ///   - dt: seconds since last update
    ///   - playerDestroyed: true if player ship just hit 0 HP this frame (or earlier)
    ///   - enemyDestroyed: same for the opponent
    ///   - lastKillByQuantumTorpedo: set true when a Quantum Torpedo dealt the finishing blow (Section 4 step 8)
    func update(dt: TimeInterval,
                playerDestroyed: Bool,
                enemyDestroyed: Bool,
                playerHealthFraction: CGFloat,
                enemyHealthFraction: CGFloat,
                playerShieldFraction: CGFloat,
                enemyShieldFraction: CGFloat,
                lastKillByQuantumTorpedo: Bool = false) -> PhaseChange? {

        switch phase {

        case .preMatch(let remaining):
            let next = remaining - dt
            if next <= 0 {
                phase = .active(remaining: matchDuration)
                return .countdownEnded
            }
            phase = .preMatch(remaining: next)
            return nil

        case .active(let remaining):
            // Section 4 step 5: match ends on destruction OR timer expiry.
            if enemyDestroyed {
                playerWins += 1
                return endMatch(winner: .player, fatality: lastKillByQuantumTorpedo)
            }
            if playerDestroyed {
                opponentWins += 1
                return endMatch(winner: .opponent, fatality: lastKillByQuantumTorpedo)
            }
            let next = remaining - dt
            if next <= 0 {
                let winner = resolveTimerWinner(
                    playerHealth: playerHealthFraction,
                    enemyHealth: enemyHealthFraction,
                    playerShield: playerShieldFraction,
                    enemyShield: enemyShieldFraction
                )
                if winner == .player { playerWins += 1 } else { opponentWins += 1 }
                return endMatch(winner: winner, fatality: false)
            }
            phase = .active(remaining: next)
            return nil

        case .interMatch(let remaining):
            let next = remaining - dt
            if next <= 0 {
                if playerWins >= 2 {
                    phase = .seriesEnded(winner: .player, fatality: lastMatchFatality)
                    return .seriesEnded(winner: .player, fatality: lastMatchFatality)
                }
                if opponentWins >= 2 {
                    phase = .seriesEnded(winner: .opponent, fatality: lastMatchFatality)
                    return .seriesEnded(winner: .opponent, fatality: lastMatchFatality)
                }
                matchNumber += 1
                lastMatchFatality = false   // fresh match — reset until something kills again
                phase = .preMatch(remaining: Self.preMatchSeconds)
                return .nextMatchStarted(matchNumber: matchNumber)
            }
            phase = .interMatch(remaining: next)
            return nil

        case .seriesEnded:
            return nil
        }
    }

    /// Add seconds to the currently active match timer (used by the timer-extension power-up).
    /// No-op in any other phase.
    func extendActiveTimer(by seconds: TimeInterval) {
        if case .active(let remaining) = phase {
            phase = .active(remaining: remaining + seconds)
        }
    }

    /// Forfeit the current match: counts as a loss for the player, advances to inter-match
    /// or series-end as appropriate. Used by Pause → Restart Match (Section 9).
    /// - Returns: the resulting PhaseChange so the scene can react (clean projectiles, etc).
    @discardableResult
    func forfeitCurrentMatch() -> PhaseChange? {
        guard case .active = phase else { return nil }
        opponentWins += 1
        return endMatch(winner: .opponent, fatality: false)
    }

    private func endMatch(winner: Ship.Side, fatality: Bool) -> PhaseChange {
        lastMatchFatality = fatality   // remember across the inter-match pause
        phase = .interMatch(remaining: Self.interMatchSeconds)
        return .matchEnded(winner: winner, fatality: fatality)
    }

    /// Section 4: at timer 0, higher health %; tiebreak shield %; then battery; else draw.
    /// Phase 2 simplification: ties go to player (we don't yet replay draws — Phase 3 polish item).
    private func resolveTimerWinner(playerHealth: CGFloat,
                                    enemyHealth: CGFloat,
                                    playerShield: CGFloat,
                                    enemyShield: CGFloat) -> Ship.Side {
        if abs(playerHealth - enemyHealth) > 0.001 {
            return playerHealth > enemyHealth ? .player : .opponent
        }
        if abs(playerShield - enemyShield) > 0.001 {
            return playerShield > enemyShield ? .player : .opponent
        }
        return .player
    }
}
