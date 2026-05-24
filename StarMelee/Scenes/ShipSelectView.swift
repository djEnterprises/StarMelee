import SwiftUI

/// Phase 2 owner: full 12-ship grid driven by Ships.json (see plan Section 5).
/// Phase 1 stub: lists the ships from the bundled JSON so the navigation works.
struct ShipSelectView: View {
    @Binding var path: NavigationPath
    @State private var ships: [ShipDefinition] = []
    @State private var selectedID: String?

    var body: some View {
        ZStack {
            StarfieldBackground()

            VStack(spacing: 20) {
                Text("CHOOSE YOUR SHIP")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(Color(.sRGB, red: 0, green: 1.0, blue: 0.84))
                    .padding(.top, 16)

                Text("Phase 1 stub — full ship grid lands in Phase 2.")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                        ForEach(ships) { ship in
                            ShipCard(ship: ship, isSelected: selectedID == ship.id)
                                .onTapGesture { selectedID = ship.id }
                        }
                    }
                    .padding()
                }

                Button {
                    if let id = selectedID {
                        path.append(MenuRoute.combat(shipID: id))
                    }
                } label: {
                    Text("LAUNCH")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .tracking(4)
                        .frame(minWidth: 200)
                        .padding(.vertical, 12)
                        .background(
                            selectedID == nil
                                ? Color.gray.opacity(0.3)
                                : Color(.sRGB, red: 1.0, green: 0.67, blue: 0)
                        )
                        .foregroundStyle(.black)
                }
                .disabled(selectedID == nil)
                .padding(.bottom, 24)
            }
        }
        .onAppear { ships = ShipDefinition.loadAll() }
    }
}

private struct ShipCard: View {
    let ship: ShipDefinition
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Rectangle()
                    .stroke(factionColor, lineWidth: 1)
                    .frame(width: 60, height: 60)
                Text(ship.name.prefix(2))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(factionColor)
            }

            Text(ship.name)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            Text(ship.faction.uppercased())
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.6))
        .overlay(
            Rectangle()
                .stroke(isSelected ? Color(.sRGB, red: 1.0, green: 0.67, blue: 0) : factionColor.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1)
        )
    }

    private var factionColor: Color {
        ship.faction.lowercased() == "alliance"
            ? Color(.sRGB, red: 0, green: 1.0, blue: 0.84)
            : Color(.sRGB, red: 1.0, green: 0.2, blue: 0.4)
    }
}
