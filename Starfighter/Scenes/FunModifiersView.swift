import SwiftUI

/// Fun Modifiers / Cheats settings screen (SuperGrok addition, Section 16.5).
///
/// Each toggle persists via UserDefaults via the FunModifiers singleton.
/// A prominent warning at the top reminds the player that any active modifier disables
/// Game Center submission and flags match results as "Modifiers Active."
struct FunModifiersView: View {
    @AppStorage("modifiers.invincibility")     private var invincibility = false
    @AppStorage("modifiers.unlimitedBattery")  private var unlimitedBattery = false
    @AppStorage("modifiers.unlimitedSpecials") private var unlimitedSpecials = false
    @AppStorage("modifiers.unlimitedBoost")    private var unlimitedBoost = false
    @AppStorage("modifiers.infinitePowerUps")  private var infinitePowerUps = false
    @AppStorage("modifiers.noPlanetGravity")   private var noPlanetGravity = false
    @AppStorage("modifiers.noShipInertia")     private var noShipInertia = false

    var body: some View {
        Form {
            Section {
                Label("Single-player only. Any active modifier disables Game Center submission for that match.",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.footnote)
            }

            Section("Survival") {
                modifierRow("Invincibility",
                            description: "Player ship cannot take damage.",
                            value: $invincibility)
                modifierRow("Unlimited Battery",
                            description: "Weapon battery cost is zero for the player.",
                            value: $unlimitedBattery)
            }

            Section("Combat") {
                modifierRow("Unlimited Specials",
                            description: "Special-weapon cooldown and battery cost are zero.",
                            value: $unlimitedSpecials)
                modifierRow("Unlimited Speed Boost",
                            description: "Boost has no battery cost and no cooldown.",
                            value: $unlimitedBoost)
            }

            Section("Arena") {
                modifierRow("Infinite Power-Ups",
                            description: "Power-ups spawn 3× as often and never despawn.",
                            value: $infinitePowerUps)
                modifierRow("No Planet Gravity",
                            description: "Planets stop pulling on ships. Crash damage still applies.",
                            value: $noPlanetGravity)
                modifierRow("No Ship Inertia",
                            description: "Your ship stops instantly when you release thrust (arcade feel — no drifting).",
                            value: $noShipInertia)
            }

            Section {
                Button(role: .destructive) {
                    FunModifiers.shared.resetAll()
                } label: {
                    Text("Reset All Modifiers")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle("Fun Modifiers")
    }

    private func modifierRow(_ name: String, description: String, value: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(name, isOn: value)
            Text(description)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack { FunModifiersView() }
}
