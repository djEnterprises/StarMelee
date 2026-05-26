import SwiftUI

struct MainMenuView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                StarfieldBackground()

                VStack(spacing: 40) {
                    Spacer()

                    VStack(spacing: 8) {
                        Text("STAR MELEE")
                            .font(.system(size: 64, weight: .black, design: .rounded))
                            .tracking(8)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(.sRGB, red: 0, green: 1.0, blue: 0.84), Color(.sRGB, red: 1.0, green: 0, blue: 0.67)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color(.sRGB, red: 0, green: 1.0, blue: 0.84, opacity: 0.5), radius: 24)

                        Text("STELLAR COMBAT")
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .tracking(12)
                            .foregroundStyle(Color(.sRGB, red: 1.0, green: 0.67, blue: 0))
                    }

                    VStack(spacing: 14) {
                        MenuButton(label: "PLAY") { path.append(MenuRoute.shipSelect) }
                        MenuButton(label: "SHIP COMPENDIUM") { path.append(MenuRoute.compendium) }
                        MenuButton(label: "LEADERBOARD") { path.append(MenuRoute.leaderboard) }
                        MenuButton(label: "SETTINGS") { path.append(MenuRoute.settings) }
                        MenuButton(label: "FUN MODIFIERS") { path.append(MenuRoute.funModifiers) }
                    }

                    Spacer()

                    Text("v\(appVersion) — © 2026 djEnterprises")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationDestination(for: MenuRoute.self) { route in
                switch route {
                case .shipSelect: ShipSelectView(path: $path)
                case .compendium: CompendiumView()
                case .leaderboard: LeaderboardView()
                case .settings: SettingsView()
                case .funModifiers: FunModifiersView()
                case .combat(let shipID): CombatSceneView(playerShipID: shipID)
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

enum MenuRoute: Hashable {
    case shipSelect
    case compendium
    case leaderboard
    case settings
    case funModifiers
    case combat(shipID: String)
}

private struct MenuButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .tracking(4)
                .foregroundStyle(Color(.sRGB, red: 0, green: 1.0, blue: 0.84))
                .frame(minWidth: 280)
                .padding(.vertical, 14)
                .padding(.horizontal, 32)
                .background(
                    Rectangle()
                        .stroke(Color(.sRGB, red: 0, green: 1.0, blue: 0.84), lineWidth: 2)
                        .background(Color(.sRGB, red: 0, green: 1.0, blue: 0.84, opacity: 0.08))
                )
                .shadow(color: Color(.sRGB, red: 0, green: 1.0, blue: 0.84, opacity: 0.4), radius: 16)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainMenuView()
}
