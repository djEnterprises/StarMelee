import Foundation

/// "Fun Modifiers" / cheats — SuperGrok addition, Section 16.5.
///
/// Single-player only. UserDefaults-backed. Gameplay code reads `FunModifiers.shared.xxx`
/// at the right points. **Critical rule:** when any modifier is active, Game Center submission
/// must be disabled for that match — `GameCenterManager` respects `anyActive`.
@MainActor
final class FunModifiers {
    static let shared = FunModifiers()

    private let defaults = UserDefaults.standard
    private struct K {
        static let invincibility       = "modifiers.invincibility"
        static let unlimitedBattery    = "modifiers.unlimitedBattery"
        static let unlimitedSpecials   = "modifiers.unlimitedSpecials"
        static let unlimitedBoost      = "modifiers.unlimitedBoost"
        static let infinitePowerUps    = "modifiers.infinitePowerUps"
        static let noPlanetGravity     = "modifiers.noPlanetGravity"
        static let noShipInertia       = "modifiers.noShipInertia"
    }

    var invincibility:     Bool { get { defaults.bool(forKey: K.invincibility) }     set { defaults.set(newValue, forKey: K.invincibility) } }
    var unlimitedBattery:  Bool { get { defaults.bool(forKey: K.unlimitedBattery) }  set { defaults.set(newValue, forKey: K.unlimitedBattery) } }
    var unlimitedSpecials: Bool { get { defaults.bool(forKey: K.unlimitedSpecials) } set { defaults.set(newValue, forKey: K.unlimitedSpecials) } }
    var unlimitedBoost:    Bool { get { defaults.bool(forKey: K.unlimitedBoost) }    set { defaults.set(newValue, forKey: K.unlimitedBoost) } }
    var infinitePowerUps:  Bool { get { defaults.bool(forKey: K.infinitePowerUps) }  set { defaults.set(newValue, forKey: K.infinitePowerUps) } }
    var noPlanetGravity:   Bool { get { defaults.bool(forKey: K.noPlanetGravity) }   set { defaults.set(newValue, forKey: K.noPlanetGravity) } }
    var noShipInertia:     Bool { get { defaults.bool(forKey: K.noShipInertia) }     set { defaults.set(newValue, forKey: K.noShipInertia) } }

    /// True if any modifier is currently on. Match results are flagged + Game Center submission
    /// is suppressed when this is true.
    var anyActive: Bool {
        invincibility || unlimitedBattery || unlimitedSpecials || unlimitedBoost
            || infinitePowerUps || noPlanetGravity || noShipInertia
    }

    func resetAll() {
        invincibility = false
        unlimitedBattery = false
        unlimitedSpecials = false
        unlimitedBoost = false
        infinitePowerUps = false
        noPlanetGravity = false
        noShipInertia = false
    }
}
