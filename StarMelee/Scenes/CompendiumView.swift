import SwiftUI

/// Phase 4 owner: see plan Section 11. Full layout per ship includes rotatable 3D model,
/// faction badge, stat bars, weapon loadout, strengths/weaknesses, play style, win-loss stats.
/// Phase 1 stub: list ships from Ships.json so navigation works.
struct CompendiumView: View {
    @State private var ships: [ShipDefinition] = []

    var body: some View {
        List(ships) { ship in
            HStack {
                Rectangle()
                    .fill(ship.faction.lowercased() == "alliance"
                          ? Color(.sRGB, red: 0, green: 1.0, blue: 0.84)
                          : Color(.sRGB, red: 1.0, green: 0.2, blue: 0.4))
                    .frame(width: 4, height: 32)
                VStack(alignment: .leading) {
                    Text(ship.name)
                        .font(.headline)
                    Text(ship.faction.uppercased())
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("v1.0")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
        .navigationTitle("Ship Compendium")
        .onAppear { ships = ShipDefinition.loadAll() }
    }
}

#Preview {
    NavigationStack { CompendiumView() }
}
