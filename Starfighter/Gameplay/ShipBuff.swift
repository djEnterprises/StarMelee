import Foundation
import CoreGraphics

/// A time-limited effect attached to a ship — driven by special weapons or duration power-ups.
///
/// **Plan reference:** Section 6 (special weapons), Section 8 (duration power-ups).
struct ShipBuff: Equatable {
    enum Kind: String, Equatable {
        case inertiaDampeners      // immune to planet gravity (Section 6)
        case invulnerability       // immune to damage (Titan Bulwark)
        case superSpeed            // max-speed multiplier (Solar Wing, Scarab Striker, Bone Spear)
        case emDisrupted           // applied to opponent — engines + weapons disabled (Prism Hunter)
        case cloaked               // translucent visual, AI can't reliably target (Void Reaper, Wraith Phantom)
        case damageMultiplier      // outgoing damage × magnitude (Mimic, power-up)
        case shieldRegenBoost      // shield regen × magnitude (power-up)
        case repairDrone           // adds magnitude HP per second (power-up)
        case selfDestructArmed     // ship has armed self-destruct — visual warning, blast on expire
    }

    let kind: Kind
    var remainingSeconds: TimeInterval
    let magnitude: CGFloat
}
