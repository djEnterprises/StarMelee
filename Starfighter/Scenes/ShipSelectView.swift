import SwiftUI

/// Ship select screen — Section 4 / Section 19 Phase 2 milestone.
///
/// Lists all 12 ships in a grid grouped by faction with hull silhouettes and condensed stat bars.
/// Selecting a ship and tapping LAUNCH starts combat with the chosen player ship.
struct ShipSelectView: View {
    @Binding var path: NavigationPath
    @State private var ships: [ShipDefinition] = []
    @State private var selectedID: String?
    @State private var activeFaction: Faction = .alliance

    enum Faction: String { case alliance, dominion }

    private let allianceCyan = Color(.sRGB, red: 0, green: 1.0, blue: 0.84)
    private let dominionRed  = Color(.sRGB, red: 1.0, green: 0.2, blue: 0.4)

    var body: some View {
        ZStack {
            StarfieldBackground()

            VStack(spacing: 16) {
                Text("CHOOSE YOUR SHIP")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(.white)
                    .padding(.top, 16)

                factionTabs

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                        ForEach(filteredShips) { ship in
                            ShipCard(ship: ship,
                                     isSelected: selectedID == ship.id,
                                     allianceCyan: allianceCyan,
                                     dominionRed: dominionRed)
                                .onTapGesture { selectedID = ship.id }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }

                launchButton
                    .padding(.bottom, 18)
            }
        }
        .onAppear { ships = ShipDefinition.loadAll() }
    }

    private var factionTabs: some View {
        HStack(spacing: 10) {
            tabButton(label: "ALLIANCE", color: allianceCyan, value: .alliance)
            tabButton(label: "DOMINION", color: dominionRed, value: .dominion)
        }
    }

    private func tabButton(label: String, color: Color, value: Faction) -> some View {
        let active = activeFaction == value
        return Button { activeFaction = value } label: {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(4)
                .padding(.vertical, 10)
                .padding(.horizontal, 22)
                .foregroundStyle(active ? Color.black : color)
                .background(active ? color : color.opacity(0.10))
                .overlay(Rectangle().stroke(color, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private var filteredShips: [ShipDefinition] {
        ships.filter { $0.faction.lowercased() == activeFaction.rawValue }
    }

    private var launchButton: some View {
        Button {
            if let id = selectedID {
                path.append(MenuRoute.combat(shipID: id))
            }
        } label: {
            Text("LAUNCH")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .tracking(4)
                .frame(minWidth: 220)
                .padding(.vertical, 12)
                .background(selectedID == nil
                            ? Color.gray.opacity(0.35)
                            : Color(.sRGB, red: 1.0, green: 0.67, blue: 0))
                .foregroundStyle(.black)
        }
        .disabled(selectedID == nil)
        .buttonStyle(.plain)
    }
}

private struct ShipCard: View {
    let ship: ShipDefinition
    let isSelected: Bool
    let allianceCyan: Color
    let dominionRed: Color

    private var factionColor: Color {
        ship.faction.lowercased() == "alliance" ? allianceCyan : dominionRed
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 110, height: 90)
                ShipHullShape(shipID: ship.id)
                    .stroke(factionColor, lineWidth: 1.5)
                    .frame(width: 90, height: 70)
                    .shadow(color: factionColor.opacity(0.6), radius: 6)
                ShipHullShape(shipID: ship.id)
                    .fill(factionColor.opacity(0.15))
                    .frame(width: 90, height: 70)
            }

            Text(ship.name.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1)
                .lineLimit(1)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            statRow("HP",  fraction: CGFloat(ship.stats.maxHealth) / 120.0, color: factionColor)
            statRow("SHL", fraction: CGFloat(ship.stats.maxShield) / 100.0, color: factionColor)
            statRow("SPD", fraction: CGFloat(ship.stats.maxSpeed) / 9.0, color: factionColor)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.55))
        .overlay(
            Rectangle()
                .stroke(isSelected ? Color(.sRGB, red: 1.0, green: 0.67, blue: 0) : factionColor.opacity(0.4),
                        lineWidth: isSelected ? 2.5 : 1)
        )
    }

    private func statRow(_ label: String, fraction: CGFloat, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.black.opacity(0.5))
                    Rectangle()
                        .fill(color)
                        .frame(width: max(0, min(1, fraction)) * geo.size.width)
                }
            }
            .frame(height: 4)
        }
    }
}
