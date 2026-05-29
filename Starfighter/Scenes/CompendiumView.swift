import SwiftUI

/// Ship Compendium list — Section 11.
///
/// Phase 4: tap a row to drill into `CompendiumDetailView`, which presents the rotatable
/// SceneKit 3D ship model alongside full stat / loadout / play-style detail.
struct CompendiumView: View {
    @State private var ships: [ShipDefinition] = []

    private let allianceCyan = Color(.sRGB, red: 0, green: 1.0, blue: 0.84)
    private let dominionRed  = Color(.sRGB, red: 1.0, green: 0.2, blue: 0.4)

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(ships) { ship in
                    NavigationLink(value: ship.id) {
                        CompendiumRow(ship: ship,
                                      factionColor: factionColor(for: ship))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Ship Compendium")
        .navigationDestination(for: String.self) { shipID in
            if let ship = ships.first(where: { $0.id == shipID }) {
                CompendiumDetailView(ship: ship)
            }
        }
        .onAppear { ships = ShipDefinition.loadAll() }
    }

    private func factionColor(for ship: ShipDefinition) -> Color {
        ship.faction.lowercased() == "alliance" ? allianceCyan : dominionRed
    }
}

private struct CompendiumRow: View {
    let ship: ShipDefinition
    let factionColor: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Rectangle()
                    .stroke(factionColor.opacity(0.4), lineWidth: 1)
                    .frame(width: 80, height: 60)
                ShipHullShape(shipID: ship.id)
                    .stroke(factionColor, lineWidth: 1.5)
                    .frame(width: 64, height: 52)
                    .shadow(color: factionColor.opacity(0.7), radius: 6)
                ShipHullShape(shipID: ship.id)
                    .fill(factionColor.opacity(0.15))
                    .frame(width: 64, height: 52)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(ship.name.uppercased())
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(.white)
                    Spacer()
                    Text(ship.tier.replacingOccurrences(of: "_", with: " ").uppercased())
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(factionColor.opacity(0.8))
                }
                Text(ship.faction.uppercased())
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                if let lore = ship.lore {
                    Text(lore)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 10) {
                    miniStat("HP",  CGFloat(ship.stats.maxHealth) / 120.0, color: factionColor)
                    miniStat("SHL", CGFloat(ship.stats.maxShield) / 100.0, color: factionColor)
                    miniStat("SPD", CGFloat(ship.stats.maxSpeed) / 9.0, color: factionColor)
                    miniStat("BAT", CGFloat(ship.stats.maxBattery) / 120.0, color: factionColor)
                }
            }
            Image(systemName: "chevron.right")
                .foregroundStyle(factionColor.opacity(0.7))
        }
        .padding(10)
        .background(Color.black.opacity(0.45))
        .overlay(Rectangle().stroke(factionColor.opacity(0.5), lineWidth: 1))
    }

    private func miniStat(_ label: String, _ frac: CGFloat, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.black.opacity(0.6))
                    Rectangle()
                        .fill(color)
                        .frame(width: max(0, min(1, frac)) * geo.size.width)
                }
            }
            .frame(width: 50, height: 4)
        }
    }
}

// MARK: - Per-ship detail (Section 11)

struct CompendiumDetailView: View {
    let ship: ShipDefinition

    @StateObject private var leaderboard = LeaderboardStore.shared

    private var allianceCyan: Color { Color(.sRGB, red: 0, green: 1.0, blue: 0.84) }
    private var dominionRed: Color { Color(.sRGB, red: 1.0, green: 0.2, blue: 0.4) }
    private var factionColor: Color {
        ship.faction.lowercased() == "alliance" ? allianceCyan : dominionRed
    }
    private var isAlliance: Bool { ship.faction.lowercased() == "alliance" }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 3D viewer with rotatable model (Section 11)
                CompendiumShip3DView(shipID: ship.id, isAlliance: isAlliance)
                    .frame(height: 240)
                    .background(
                        LinearGradient(colors: [factionColor.opacity(0.15), .black],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .overlay(Rectangle().stroke(factionColor.opacity(0.7), lineWidth: 1))

                // Name + faction badge
                VStack(spacing: 4) {
                    Text(ship.name.uppercased())
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(factionColor)
                    Text("\(ship.faction.uppercased()) • \(ship.tier.replacingOccurrences(of: "_", with: " ").uppercased())")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if let lore = ship.lore {
                        Text(lore)
                            .font(.system(size: 12, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 14)
                    }
                }

                // Performance stats
                sectionTitle("PERFORMANCE")
                VStack(spacing: 4) {
                    statBar(label: "Max HP", value: CGFloat(ship.stats.maxHealth), max: 120)
                    statBar(label: "Shield", value: CGFloat(ship.stats.maxShield), max: 100)
                    statBar(label: "Battery", value: CGFloat(ship.stats.maxBattery), max: 120)
                    statBar(label: "Max Speed", value: CGFloat(ship.stats.maxSpeed), max: 9)
                    statBar(label: "Acceleration", value: CGFloat(ship.stats.acceleration), max: 0.20)
                    statBar(label: "Turn Rate", value: CGFloat(ship.stats.turnRate), max: 0.09)
                    statBar(label: "Hitbox", value: CGFloat(ship.stats.hitboxSize), max: 24, inverted: true)
                    statBar(label: "Heal Rate", value: CGFloat(ship.stats.healRate), max: 3)
                }
                .padding(.horizontal, 16)

                // Weapon loadout
                sectionTitle("WEAPON LOADOUT")
                VStack(alignment: .leading, spacing: 4) {
                    loadoutRow(label: "Primary",   id: ship.weapons.primary)
                    loadoutRow(label: "Secondary", id: ship.weapons.secondary)
                    loadoutRow(label: "Special",   id: ship.weapons.special)
                    HStack(spacing: 10) {
                        loadoutBadge("Transporter", enabled: ship.weapons.hasTransporter)
                        loadoutBadge("Cloak",       enabled: ship.weapons.hasCloak)
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 16)

                // Win/loss
                sectionTitle("YOUR RECORD")
                recordPanel
                    .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
        .background(Color.black.ignoresSafeArea())
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .tracking(4)
            .foregroundStyle(factionColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
    }

    private func statBar(label: String, value: CGFloat, max maxValue: CGFloat, inverted: Bool = false) -> some View {
        let fraction = inverted ? (1 - min(1, value / maxValue)) : min(1, value / maxValue)
        return HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.black.opacity(0.6))
                    Rectangle()
                        .fill(factionColor)
                        .frame(width: max(0, fraction) * geo.size.width)
                }
            }
            .frame(height: 6)
            Text(value < 1 ? String(format: "%.2f", value) : "\(Int(value))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private func loadoutRow(label: String, id: String) -> some View {
        HStack {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(id.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(Color.black.opacity(0.45))
        .overlay(Rectangle().stroke(factionColor.opacity(0.35), lineWidth: 1))
    }

    private func loadoutBadge(_ name: String, enabled: Bool) -> some View {
        Text(name.uppercased())
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(2)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(enabled ? Color.black : factionColor.opacity(0.5))
            .background(enabled ? factionColor : Color.black.opacity(0.4))
            .overlay(Rectangle().stroke(factionColor.opacity(enabled ? 0 : 0.5), lineWidth: 1))
    }

    private var recordPanel: some View {
        let s = leaderboard.stats(for: ship.id)
        return HStack(spacing: 16) {
            recordCell("WINS", "\(s.wins)", color: .green)
            recordCell("LOSSES", "\(s.losses)", color: .red)
            recordCell("STREAK", "\(s.bestStreak)", color: .yellow)
            recordCell("WIN %",
                       s.matchesPlayed > 0 ? String(format: "%.0f", s.winPercent) : "—",
                       color: factionColor)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.45))
        .overlay(Rectangle().stroke(factionColor.opacity(0.5), lineWidth: 1))
    }

    private func recordCell(_ label: String, _ value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack { CompendiumView() }
}
