import SwiftUI

/// Per-ship leaderboard screen.
///
/// **Plan reference:** Section 17 — local storage of every tracked stat, sorted by win %.
/// Game Center global leaderboards land in Phase 4 once ASC is configured.
struct LeaderboardView: View {
    @StateObject private var store = LeaderboardStore.shared
    @State private var showResetConfirm = false
    @State private var showGameCenter = false

    private let allianceCyan = Color(.sRGB, red: 0, green: 1.0, blue: 0.84)
    private let dominionRed  = Color(.sRGB, red: 1.0, green: 0.2, blue: 0.4)

    var body: some View {
        ZStack {
            StarfieldBackground()

            VStack(spacing: 12) {
                Text("LEADERBOARD")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(.white)
                    .padding(.top, 14)

                Text("Per ship — sorted by win %")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)

                let entries = store.sortedEntries()
                if entries.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "trophy")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary.opacity(0.5))
                        Text("No matches played yet.")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("Win your first match to unlock the leaderboard.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(entries.enumerated()), id: \.element.shipID) { idx, entry in
                                LeaderboardRow(rank: idx + 1,
                                               shipID: entry.shipID,
                                               stats: entry.stats,
                                               allianceCyan: allianceCyan,
                                               dominionRed: dominionRed)
                            }
                        }
                        .padding(.horizontal, 14)
                    }
                }

                #if !os(tvOS)
                Button {
                    showGameCenter = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "rosette")
                        Text("VIEW GAME CENTER")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .tracking(2)
                    }
                    .foregroundStyle(Color(.sRGB, red: 0, green: 1.0, blue: 0.84))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .overlay(Rectangle().stroke(Color(.sRGB, red: 0, green: 1.0, blue: 0.84), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 6)
                #endif

                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Text("RESET ALL STATS")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(2)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                }
                .padding(.bottom, 14)
            }
        }
        #if !os(tvOS)
        .sheet(isPresented: $showGameCenter) {
            GameCenterDashboardView()
                .ignoresSafeArea()
        }
        #endif
        .confirmationDialog("Reset all leaderboard stats?",
                            isPresented: $showResetConfirm,
                            titleVisibility: .visible) {
            Button("Reset", role: .destructive) { store.resetAll() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("All per-ship win/loss records will be cleared. This cannot be undone.")
        }
    }
}

private struct LeaderboardRow: View {
    let rank: Int
    let shipID: String
    let stats: ShipStats
    let allianceCyan: Color
    let dominionRed: Color

    @State private var ships: [ShipDefinition] = []

    private var ship: ShipDefinition? {
        ships.first(where: { $0.id == shipID })
    }

    private var factionColor: Color {
        guard let ship else { return .white }
        return ship.faction.lowercased() == "alliance" ? allianceCyan : dominionRed
    }

    private var winPctColor: Color {
        let p = stats.winPercent
        if p > 60 { return .green }
        if p > 40 { return .yellow }
        return .red
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(rank <= 3 ? Color(.sRGB, red: 1.0, green: 0.67, blue: 0) : .secondary)
                .frame(width: 28, alignment: .center)

            ShipHullShape(shipID: shipID)
                .stroke(factionColor, lineWidth: 1.5)
                .frame(width: 36, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(ship?.name.uppercased() ?? shipID.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                HStack(spacing: 10) {
                    Text("W \(stats.wins)").foregroundStyle(.green.opacity(0.85))
                    Text("L \(stats.losses)").foregroundStyle(.red.opacity(0.85))
                    if stats.bestStreak > 0 {
                        Text("Streak \(stats.bestStreak)").foregroundStyle(.yellow.opacity(0.85))
                    }
                    if stats.fatalityKills > 0 {
                        Text("FATALITY ×\(stats.fatalityKills)")
                            .foregroundStyle(dominionRed)
                    }
                }
                .font(.system(size: 10, design: .monospaced))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f%%", stats.winPercent))
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .foregroundStyle(winPctColor)
                Text("\(stats.matchesPlayed) match\(stats.matchesPlayed == 1 ? "" : "es")")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.55))
        .overlay(Rectangle().stroke(factionColor.opacity(0.5), lineWidth: 1))
        .onAppear {
            if ships.isEmpty { ships = ShipDefinition.loadAll() }
        }
    }
}

#Preview {
    NavigationStack { LeaderboardView() }
}
