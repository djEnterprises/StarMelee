import Foundation
import Combine

/// Per-ship match statistics, persisted via UserDefaults.
///
/// **Plan reference:** Section 17 — Local Storage + Tracked Per Ship list.
/// Tracks only the player's ship history; AI stats are never recorded.
struct ShipStats: Codable, Equatable {
    var matchesPlayed: Int = 0
    var wins: Int = 0
    var losses: Int = 0
    var currentStreak: Int = 0          // resets on loss / forfeit
    var bestStreak: Int = 0
    var totalDamageDealt: Double = 0
    var totalDamageTaken: Double = 0
    var fatalityKills: Int = 0          // wins via Quantum Torpedo (Section 17)
    var selfDestructWins: Int = 0       // wins where own SD took the opponent
    var forfeits: Int = 0               // matches Quit during

    var winPercent: Double {
        matchesPlayed > 0 ? Double(wins) / Double(matchesPlayed) * 100 : 0
    }
}

@MainActor
final class LeaderboardStore: ObservableObject {
    static let shared = LeaderboardStore()

    @Published private(set) var stats: [String: ShipStats] = [:]
    private let storageKey = "leaderboard.stats.v1"
    private var pendingChanges = false

    init() { load() }

    // MARK: - Lookup

    func stats(for shipID: String) -> ShipStats {
        stats[shipID] ?? ShipStats()
    }

    /// All entries sorted by win % descending. Ships with no plays are excluded.
    func sortedEntries() -> [(shipID: String, stats: ShipStats)] {
        stats
            .filter { $0.value.matchesPlayed > 0 }
            .sorted { lhs, rhs in
                if lhs.value.winPercent != rhs.value.winPercent {
                    return lhs.value.winPercent > rhs.value.winPercent
                }
                return lhs.value.wins > rhs.value.wins
            }
            .map { ($0.key, $0.value) }
    }

    // MARK: - Mutations

    func recordWin(shipID: String, byFatality: Bool, bySelfDestruct: Bool) {
        var s = stats(for: shipID)
        s.matchesPlayed += 1
        s.wins += 1
        s.currentStreak += 1
        s.bestStreak = max(s.bestStreak, s.currentStreak)
        if byFatality { s.fatalityKills += 1 }
        if bySelfDestruct { s.selfDestructWins += 1 }
        stats[shipID] = s
        save()

        // Section 17: push global totals to Game Center too. Manager no-ops when offline /
        // signed out / any Fun Modifier is active.
        GameCenterManager.shared.submitWin(totalWinsCount: totalWinsAcrossAllShips)
        GameCenterManager.shared.submitWinStreak(bestStreakAcrossAllShips)

        // First Blood achievement on the very first win.
        if totalWinsAcrossAllShips == 1 {
            GameCenterManager.shared.reportAchievement(id: GameCenterManager.AchievementID.firstBlood)
        }
        // On a Roll: 5+ current streak.
        if s.currentStreak >= 5 {
            GameCenterManager.shared.reportAchievement(id: GameCenterManager.AchievementID.onARoll)
        }
        if byFatality {
            GameCenterManager.shared.reportAchievement(id: GameCenterManager.AchievementID.fatality)
        }
    }

    /// Sum of wins across every ship the player has used.
    var totalWinsAcrossAllShips: Int {
        stats.values.reduce(0) { $0 + $1.wins }
    }

    /// The single best-ever win streak across all ships.
    var bestStreakAcrossAllShips: Int {
        stats.values.map { $0.bestStreak }.max() ?? 0
    }

    func recordLoss(shipID: String) {
        var s = stats(for: shipID)
        s.matchesPlayed += 1
        s.losses += 1
        s.currentStreak = 0
        stats[shipID] = s
        save()
    }

    func recordForfeit(shipID: String) {
        var s = stats(for: shipID)
        s.matchesPlayed += 1
        s.losses += 1            // forfeit counts as a loss (Section 9)
        s.forfeits += 1
        s.currentStreak = 0
        stats[shipID] = s
        save()
    }

    /// Damage accumulators — kept in memory, flushed to disk at match end via `flushDamage()`.
    /// Saving on every projectile hit would thrash UserDefaults; flushing once per match is
    /// cheap and sufficient.
    func addDamageDealt(shipID: String, amount: Double) {
        var s = stats(for: shipID)
        s.totalDamageDealt += amount
        stats[shipID] = s
        pendingChanges = true
    }

    func addDamageTaken(shipID: String, amount: Double) {
        var s = stats(for: shipID)
        s.totalDamageTaken += amount
        stats[shipID] = s
        pendingChanges = true
    }

    func flushDamage() {
        if pendingChanges { save() }
    }

    func resetAll() {
        stats = [:]
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: ShipStats].self, from: data) else { return }
        stats = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        pendingChanges = false
    }
}
