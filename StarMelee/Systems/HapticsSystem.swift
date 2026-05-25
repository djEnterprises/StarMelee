import Foundation
#if os(iOS)
import CoreHaptics
import UIKit
#endif

/// Per-event haptic feedback.
///
/// **Plan reference:** Section 13 — full pattern catalog.
///
/// **Critical rule (Section 13):** haptics fire **only for events that affect the human
/// player's ship**. Gameplay code calls `play(.damageMedium)` only when the player took
/// damage, never when the AI did. This file's API enforces nothing at the framework level —
/// callers must self-police.
///
/// Phase 3 implementation uses `UIImpactFeedbackGenerator` + `UINotificationFeedbackGenerator`
/// to approximate the patterns described in the plan. Phase 4 polish will move to full
/// `CHHapticPattern` JSON files in `Resources/Haptics/` for precise multi-pulse timings.
final class HapticsSystem {
    static let shared = HapticsSystem()

    enum Event {
        // Weapons (player's own ship)
        case primaryFire
        case secondaryFire
        case specialFire
        case transporterEngage
        case torpedoPlantedOnPlayer
        case speedBoostEngage
        case cloakEngage
        case selfDestructArmed

        // Damage taken by player
        case damageLight        // < 5 HP
        case damageMedium       // 5–15 HP
        case damageHeavy        // > 15 HP
        case shieldBroken
        case shieldRaise

        // Player environment
        case crashedIntoPlanet
        case bouncedOffWall     // Section 4 bounded mode only — toroidal has no walls

        // Big events
        case playerDestroyed
        case singularityEvent
        case powerUpCollected

        // Match flow
        case matchStart
        case roundWonByPlayer
        case roundLostByPlayer
        case seriesVictory
        case seriesDefeat
        case fatality
    }

    var intensitySetting: String {
        UserDefaults.standard.string(forKey: "settings.hapticIntensity") ?? defaultForPlatform
    }

    /// Section 13 defaults: Medium on iPhone, Low on iPad (larger device, less wrist contact),
    /// Off on macOS (no haptic engine).
    private var defaultForPlatform: String {
        #if os(macOS)
        return "off"
        #else
        // Treat iPad differently — UIDevice.userInterfaceIdiom == .pad
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad { return "low" }
        #endif
        return "medium"
        #endif
    }

    func play(_ event: Event) {
        #if os(iOS)
        let setting = intensitySetting
        guard setting != "off" else { return }
        let scale: CGFloat = {
            switch setting {
            case "low":    return 0.4
            case "high":   return 1.0
            default:       return 0.7   // medium
            }
        }()

        switch event {
        // Weapons (player) — light → medium → heavy by weapon weight
        case .primaryFire, .powerUpCollected, .shieldRaise:
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: scale)
        case .secondaryFire, .speedBoostEngage, .cloakEngage:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: scale)
        case .specialFire, .transporterEngage:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: scale)

        // Damage taken (player) — graded
        case .damageLight:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: scale)
        case .damageMedium, .bouncedOffWall:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: scale)
        case .damageHeavy, .shieldBroken, .crashedIntoPlanet, .torpedoPlantedOnPlayer:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: scale)

        // Self-destruct armed: heavy 3-pulse warning ([80, 40, 80, 40, 80] ms — approximated)
        case .selfDestructArmed:
            multiPulseHeavy(count: 3, intensity: scale)

        // Player destroyed: sustained intense pattern
        case .playerDestroyed:
            multiPulseHeavy(count: 4, intensity: scale)

        // Singularity event: deep continuous rumble (5-pulse heavy)
        case .singularityEvent:
            multiPulseHeavy(count: 5, intensity: scale)

        // Match flow
        case .matchStart:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .roundWonByPlayer, .seriesVictory:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            multiPulseHeavy(count: 2, intensity: scale * 0.8)
        case .roundLostByPlayer, .seriesDefeat:
            UINotificationFeedbackGenerator().notificationOccurred(.error)

        // FATALITY — intense 6-pulse + delayed long finale
        case .fatality:
            multiPulseHeavy(count: 4, intensity: scale)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: scale)
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
        #endif
    }

    #if os(iOS)
    /// Approximate the multi-pulse patterns from Section 13 with timed heavy impacts.
    private func multiPulseHeavy(count: Int, intensity: CGFloat) {
        for i in 0..<count {
            let delay = Double(i) * 0.08
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: intensity)
            }
        }
    }
    #endif
}
