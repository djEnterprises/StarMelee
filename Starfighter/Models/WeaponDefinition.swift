import Foundation

/// Decoded from `Resources/Weapons.json`. See plan Section 6 for weapon categories and damage scaling.
struct WeaponDefinition: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: Category
    let baseDamage: Double
    let weaponWeight: Double
    let projectileSpeed: Double
    let lifetimeSeconds: Double
    let homing: Bool
    let piercing: Bool
    let areaOfEffect: Double
    let batteryCost: Double

    enum Category: String, Codable {
        case primary
        case secondary
        case special
    }

    static func loadAll(bundle: Bundle = .main) -> [WeaponDefinition] {
        guard let url = bundle.url(forResource: "Weapons", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return (try? decoder.decode([WeaponDefinition].self, from: data)) ?? []
    }
}
