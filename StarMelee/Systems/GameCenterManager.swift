import Foundation
#if canImport(GameKit)
import GameKit
#endif

/// Game Center scaffold — SuperGrok addition, Section 17 promoted to v1.0 requirement.
///
/// Phase 4 owner. This file is intentionally offline-safe today:
///   - `authenticate()` works on the main thread, never blocks gameplay
///   - `submitWin()` / `submitWinStreak()` no-op when offline / signed out
///   - Most importantly: **all submissions no-op when `FunModifiers.anyActive` is true**
///     (Section 16.5 critical rule)
///
/// Daniel: enable Game Center in App Store Connect → Features, create the two leaderboards
/// + five achievements listed in plan Section 17, then this manager just starts working.
@MainActor
final class GameCenterManager {
    static let shared = GameCenterManager()

    // Leaderboard / achievement IDs (use exact strings or your reverse-domain equivalents)
    enum LeaderboardID {
        static let totalWins  = "com.djEnterprises.starmelee.wins"
        static let winStreak  = "com.djEnterprises.starmelee.win_streak"
    }
    enum AchievementID {
        static let firstBlood   = "com.djEnterprises.starmelee.first_blood"
        static let onARoll      = "com.djEnterprises.starmelee.on_a_roll"
        static let shipMaster   = "com.djEnterprises.starmelee.ship_master"
        static let untouchable  = "com.djEnterprises.starmelee.untouchable"
        static let fatality     = "com.djEnterprises.starmelee.fatality"
    }

    private(set) var isAuthenticated: Bool = false

    /// Authenticate the local player. Call once from app launch.
    func authenticate() {
        #if canImport(GameKit)
        GKLocalPlayer.local.authenticateHandler = { [weak self] _, error in
            guard let self else { return }
            self.isAuthenticated = GKLocalPlayer.local.isAuthenticated && error == nil
        }
        #endif
    }

    /// Submit a single-match win score (used for total-wins leaderboard counter).
    /// No-ops if offline, signed out, or any Fun Modifier is active.
    func submitWin(totalWinsCount: Int) {
        guard !FunModifiers.shared.anyActive else { return }
        guard isAuthenticated else { return }
        #if canImport(GameKit)
        Task {
            try? await GKLeaderboard.submitScore(totalWinsCount,
                                                 context: 0,
                                                 player: GKLocalPlayer.local,
                                                 leaderboardIDs: [LeaderboardID.totalWins])
        }
        #endif
    }

    /// Submit the player's longest win streak.
    func submitWinStreak(_ streak: Int) {
        guard !FunModifiers.shared.anyActive else { return }
        guard isAuthenticated else { return }
        #if canImport(GameKit)
        Task {
            try? await GKLeaderboard.submitScore(streak,
                                                 context: 0,
                                                 player: GKLocalPlayer.local,
                                                 leaderboardIDs: [LeaderboardID.winStreak])
        }
        #endif
    }

    /// Award (or progress) an achievement by ID. Percent is 0...100.
    func reportAchievement(id: String, percent: Double = 100) {
        guard !FunModifiers.shared.anyActive else { return }
        guard isAuthenticated else { return }
        #if canImport(GameKit)
        let achievement = GKAchievement(identifier: id)
        achievement.percentComplete = percent
        achievement.showsCompletionBanner = true
        GKAchievement.report([achievement]) { _ in }
        #endif
    }
}
