import Foundation

/// Decoded from `Resources/PowerUps.json`. See plan Section 8.
struct PowerUpDefinition: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let kind: Kind
    let magnitude: Double
    let durationSeconds: Double
    let weight: Double

    enum Kind: String, Codable {
        case lifeRestore
        case batteryRestore
        case shieldRestore
        case quantumTorpedoAmmo
        case speedBoostCharge
        case specialReset
        case timerExtension
        case damageMultiplier
        case shieldRegenBoost
        case repairDrone
    }

    static func loadAll(bundle: Bundle = .main) -> [PowerUpDefinition] {
        guard let url = bundle.url(forResource: "PowerUps", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return (try? decoder.decode([PowerUpDefinition].self, from: data)) ?? []
    }
}
