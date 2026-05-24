import Foundation
#if os(iOS)
import CoreHaptics
import UIKit
#endif

/// Phase 3 owner: full Core Haptics patterns per plan Section 13.
/// Phase 1 stub: thin wrapper that no-ops on non-iOS platforms.
final class HapticsSystem {
    static let shared = HapticsSystem()

    enum Event {
        case primaryFire
        case secondaryFire
        case specialFire
        case damageLight
        case damageHeavy
        case shieldUp
        case shieldDown
        case transporterActivate
        case torpedoCountdownTick
        case singularity
        case destruction
        case powerUpCollect
        case victory
        case defeat
    }

    var intensity: String {
        UserDefaults.standard.string(forKey: "settings.hapticIntensity") ?? "medium"
    }

    func play(_ event: Event) {
        #if os(iOS)
        guard intensity != "off" else { return }
        let scale: CGFloat = {
            switch intensity {
            case "low": return 0.4
            case "high": return 1.0
            default: return 0.7  // medium
            }
        }()

        let generator: UIImpactFeedbackGenerator
        switch event {
        case .primaryFire, .powerUpCollect:
            generator = UIImpactFeedbackGenerator(style: .light)
        case .secondaryFire, .shieldUp, .shieldDown, .torpedoCountdownTick:
            generator = UIImpactFeedbackGenerator(style: .medium)
        case .specialFire, .damageHeavy, .destruction, .singularity, .transporterActivate, .victory, .defeat:
            generator = UIImpactFeedbackGenerator(style: .heavy)
        case .damageLight:
            generator = UIImpactFeedbackGenerator(style: .soft)
        }
        generator.impactOccurred(intensity: scale)
        #endif
    }
}
