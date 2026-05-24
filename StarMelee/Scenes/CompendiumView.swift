import SwiftUI

/// Ship Compendium. Phase 2: list view with hull silhouettes + stat bars per ship.
/// Phase 4 will replace the silhouette with a rotatable 3D SceneKit model per Section 11.
struct CompendiumView: View {
    @State private var ships: [ShipDefinition] = []

    private let allianceCyan = Color(.sRGB, red: 0, green: 1.0, blue: 0.84)
    private let dominionRed  = Color(.sRGB, red: 1.0, green: 0.2, blue: 0.4)

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(ships) { ship in
                    CompendiumRow(ship: ship,
                                  factionColor: factionColor(for: ship))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Ship Compendium")
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
                    miniStat("HP",  CGFloat(ship.stats.maxHealth) / 120.0)
                    miniStat("SHL", CGFloat(ship.stats.maxShield) / 100.0)
                    miniStat("SPD", CGFloat(ship.stats.maxSpeed) / 9.0)
                    miniStat("BAT", CGFloat(ship.stats.maxBattery) / 120.0)
                }
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.45))
        .overlay(Rectangle().stroke(factionColor.opacity(0.5), lineWidth: 1))
    }

    private func miniStat(_ label: String, _ frac: CGFloat) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.black.opacity(0.6))
                    Rectangle()
                        .fill(factionColor)
                        .frame(width: max(0, min(1, frac)) * geo.size.width)
                }
            }
            .frame(width: 50, height: 4)
        }
    }
}

#Preview {
    NavigationStack { CompendiumView() }
}
