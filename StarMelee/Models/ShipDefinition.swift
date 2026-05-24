import Foundation

/// Decoded from `Resources/Ships.json`. Matches the stat profile in plan Section 5.
struct ShipDefinition: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let faction: String
    let tier: String
    let stats: Stats
    let weapons: Loadout
    let lore: String?

    struct Stats: Codable, Hashable {
        let maxHealth: Double
        let healRate: Double
        let maxShield: Double
        let shieldUpTime: Double
        let shieldDownTime: Double
        let maxBattery: Double
        let batteryRegenMultiplier: Double
        let mass: Double
        let acceleration: Double
        let maxSpeed: Double
        let turnRate: Double
        let hitboxSize: Double
        let primaryFireRateFrames: Int
        let secondaryFireRateFrames: Int
        let specialCooldownSeconds: Double
        let speedBoostCooldownSeconds: Double
        let transporterCooldownSeconds: Double
    }

    struct Loadout: Codable, Hashable {
        let primary: String
        let secondary: String
        let special: String
        let hasCloak: Bool
        let hasTransporter: Bool
    }

    /// Loads the ship roster from the app bundle. Returns an empty array if the JSON is missing
    /// or malformed so SwiftUI previews and Phase 1 navigation don't crash on misconfigured bundles.
    static func loadAll(bundle: Bundle = .main) -> [ShipDefinition] {
        guard let url = bundle.url(forResource: "Ships", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return (try? decoder.decode([ShipDefinition].self, from: data)) ?? []
    }
}
