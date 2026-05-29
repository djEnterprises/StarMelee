import SpriteKit
import CoreGraphics

/// Dispatches the C-button special weapon for any ship.
///
/// **Plan reference:** Section 5 (per-ship special), Section 6 (special-weapon catalog).
///
/// Each ship's `definition.weapons.special` ID is matched here. New ships only need a JSON
/// entry pointing at one of these IDs — no new code required.
///
/// Common rules:
///   - Specials are gated by `allowSpecials` (false during pre-match countdown — Section 23 #8)
///   - Each special charges a battery cost from the weapon definition + locks the ship's
///     `specialCooldownRemaining` to its per-ship cooldown
///   - `unlimitedSpecials` Fun Modifier bypasses the battery cost + cooldown for the player only
enum SpecialWeaponResult {
    case fired
    case spawnHomingMissiles(count: Int)   // CombatScene handles projectile creation
    case armedSelfDestruct
    case rejected
}

@MainActor
enum SpecialWeaponSystem {

    /// Try to fire `ship`'s C-button special at `opponent`. Returns what the caller (CombatScene)
    /// needs to do for follow-up work (e.g., spawn homing-missile projectiles).
    static func execute(special on: Ship,
                        opponent: Ship,
                        allowSpecials: Bool,
                        weaponsCatalog: [WeaponDefinition]) -> SpecialWeaponResult {
        guard allowSpecials else { return .rejected }
        guard !on.isEMDisrupted else { return .rejected }

        let specialID = on.definition.weapons.special

        // Pull battery cost from the weapon definition. Default 30% if entry is missing.
        let weaponDef = weaponsCatalog.first { $0.id == specialID }
        let batteryCost = CGFloat(weaponDef?.batteryCost ?? 30)

        let unlimited = on.side == .player && FunModifiers.shared.unlimitedSpecials
        if !unlimited {
            guard on.specialCooldownRemaining <= 0 else { return .rejected }
            guard on.spendBattery(batteryCost) else { return .rejected }
            on.specialCooldownRemaining = TimeInterval(on.definition.stats.specialCooldownSeconds)
        }

        // Dispatch by the special's ID.
        switch specialID {
        case "inertia_dampeners":
            on.applyBuff(ShipBuff(kind: .inertiaDampeners, remainingSeconds: 6, magnitude: 0))
            return .fired

        case "super_speed_burst":
            on.applyBuff(ShipBuff(kind: .superSpeed, remainingSeconds: 3, magnitude: 3.0))
            return .fired

        case "super_speed_long":
            on.applyBuff(ShipBuff(kind: .superSpeed, remainingSeconds: 5, magnitude: 2.5))
            return .fired

        case "invulnerability_shield":
            on.applyBuff(ShipBuff(kind: .invulnerability, remainingSeconds: 4, magnitude: 0))
            return .fired

        case "em_blast":
            // Applies disruption to the OPPONENT (Section 6).
            opponent.applyBuff(ShipBuff(kind: .emDisrupted, remainingSeconds: 3, magnitude: 0))
            return .fired

        case "homing_missiles":
            // Spawning the actual missiles is the scene's job.
            return .spawnHomingMissiles(count: 4)

        case "cloaking_device":
            on.applyBuff(ShipBuff(kind: .cloaked, remainingSeconds: 8, magnitude: 0))
            return .fired

        case "cloak_phase_shift":
            on.applyBuff(ShipBuff(kind: .cloaked, remainingSeconds: 12, magnitude: 0))
            return .fired

        case "mimic":
            // Simplified: 1.5× outgoing damage + +50% speed (the "copy opponent" idea is replaced
            // by a flat power buff — full mimic is a Phase 4+ stretch goal).
            on.applyBuff(ShipBuff(kind: .damageMultiplier, remainingSeconds: 10, magnitude: 1.5))
            on.applyBuff(ShipBuff(kind: .superSpeed, remainingSeconds: 10, magnitude: 1.4))
            return .fired

        case "mimic_speed":
            on.applyBuff(ShipBuff(kind: .damageMultiplier, remainingSeconds: 8, magnitude: 1.5))
            on.applyBuff(ShipBuff(kind: .superSpeed, remainingSeconds: 8, magnitude: 2.0))
            return .fired

        case "self_destruct":
            on.applyBuff(ShipBuff(kind: .selfDestructArmed, remainingSeconds: 4, magnitude: 0))
            return .armedSelfDestruct

        case "transporter_beam_built_in":
            // The Crimson Tyrant's signature: the special button engages the Transporter Beam
            // (with reduced cooldown vs. the universal A+B). The actual sequence is handled
            // by the Transporter Beam pathway when the scene observes this result.
            return .fired

        default:
            // Refund battery if we don't recognize the special ID.
            on.battery = min(on.maxBattery, on.battery + batteryCost)
            on.specialCooldownRemaining = 0
            return .rejected
        }
    }
}
