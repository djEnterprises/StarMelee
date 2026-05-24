import Foundation

/// Lightweight state carried across an in-progress match and a 2-of-3 series.
/// Phase 2 owner: see plan Section 4 for the match structure.
struct MatchState: Hashable {
    enum Phase: Hashable {
        case preMatchCountdown(remaining: TimeInterval)
        case active(remaining: TimeInterval)
        case ended(winner: Side?, fatality: Bool)
    }

    enum Side: Hashable { case player, opponent }

    var phase: Phase
    var playerWins: Int
    var opponentWins: Int
    var matchNumber: Int  // 1, 2, or 3

    static let preMatchSeconds: TimeInterval = 10
    static let defaultMatchSeconds: TimeInterval = 120

    static var initial: MatchState {
        MatchState(
            phase: .preMatchCountdown(remaining: preMatchSeconds),
            playerWins: 0,
            opponentWins: 0,
            matchNumber: 1
        )
    }

    var seriesWinner: Side? {
        if playerWins >= 2 { return .player }
        if opponentWins >= 2 { return .opponent }
        return nil
    }
}
