import Foundation
#if os(iOS)
import CoreHaptics
import UIKit
#endif

/// Per-event haptic feedback — Section 13 catalog.
///
/// Phase 4 upgrade: uses `CHHapticEngine` to play precise multi-pulse `CHHapticPattern`s built
/// programmatically (the equivalent of the JSON-pattern file mentioned in the plan, just kept
/// in code so the rhythms are version-controlled with the gameplay code).
///
/// Falls back to `UIImpactFeedbackGenerator` on devices without Core Haptics support
/// (iPads, older iPhones) so every event still produces some tactile feedback.
///
/// **Critical rule (Section 13):** haptics fire **only for events that affect the human
/// player's ship**. Callers must self-police; this file enforces nothing at the API level.
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
        case damageLight
        case damageMedium
        case damageHeavy
        case shieldBroken
        case shieldRaise

        // Player environment
        case crashedIntoPlanet
        case bouncedOffWall

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

    // MARK: - Engine

    #if os(iOS)
    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }
    #endif

    private init() {
        prepareEngine()
        refreshIntensityCache()
        // Settings changes (e.g. user toggling Haptic Intensity) update the cache cheaply
        // via the global UserDefaults notification — no per-frame reads.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDefaultsChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Cached intensity scale — refreshed on UserDefaults changes. 0 = haptics disabled.
    private var cachedIntensityScale: Float = 0.7

    /// Refresh the cached intensity (called at init and from UserDefaults observer).
    /// Public so the Settings screen can explicitly nudge it on dismiss if needed.
    func refreshIntensityCache() {
        let setting = UserDefaults.standard.string(forKey: "settings.hapticIntensity") ?? defaultForPlatform
        cachedIntensityScale = {
            switch setting {
            case "off":  return 0
            case "low":  return 0.4
            case "high": return 1.0
            default:     return 0.7
            }
        }()
    }

    @objc private func handleDefaultsChanged() {
        refreshIntensityCache()
    }

    private func prepareEngine() {
        #if os(iOS)
        guard supportsHaptics else { return }
        do {
            let e = try CHHapticEngine()
            // Restart on interruption (incoming call, etc.).
            e.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            e.stoppedHandler = { _ in /* engine stopped — will retry on next play */ }
            try e.start()
            engine = e
        } catch {
            engine = nil
        }
        #endif
    }

    // MARK: - User-facing settings

    var intensitySetting: String {
        UserDefaults.standard.string(forKey: "settings.hapticIntensity") ?? defaultForPlatform
    }

    private var defaultForPlatform: String {
        #if os(macOS)
        return "off"
        #else
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad { return "low" }
        #endif
        return "medium"
        #endif
    }

    /// Read-only accessor kept for any external code that wants the current scale.
    var intensityScale: Float { cachedIntensityScale }

    // MARK: - Public play

    func play(_ event: Event) {
        #if os(iOS)
        let scale = cachedIntensityScale
        guard scale > 0 else { return }

        if let engine = engine, supportsHaptics {
            // Build + play a precise multi-pulse pattern.
            if let pattern = buildPattern(for: event, scale: scale) {
                do {
                    let player = try engine.makePlayer(with: pattern)
                    try player.start(atTime: 0)
                    return
                } catch {
                    // Engine hiccuped — fall through to generator fallback below.
                }
            }
        }

        // Fallback: UIImpactFeedbackGenerator for devices without Core Haptics.
        playFallback(event, scale: CGFloat(scale))
        #endif
    }

    // MARK: - Pattern builder

    #if os(iOS)

    /// Build the Section 13 pattern for an event. Each pulse-duration array becomes a sequence
    /// of continuous haptic events with a small 10ms gap between pulses for distinct rhythm.
    private func buildPattern(for event: Event, scale: Float) -> CHHapticPattern? {
        let intensity = scale
        switch event {

        // Simple transient pulses (single tick).
        case .primaryFire:
            return makePattern([(0.010, intensity, 0.8)])
        case .secondaryFire:
            return makePattern([(0.025, intensity, 0.6)])
        case .specialFire:
            return makePattern([(0.060, intensity, 0.5)])
        case .damageLight:
            return makePattern([(0.012, intensity * 0.7, 0.5)])
        case .damageMedium:
            return makePattern([(0.028, intensity, 0.7)])
        case .shieldRaise:
            return makePattern([(0.020, intensity * 0.6, 0.3)])
        case .bouncedOffWall:
            return makePattern([(0.018, intensity * 0.5, 0.4)])
        case .roundLostByPlayer:
            return makePattern([(0.120, intensity, 0.4)])

        // Multi-pulse rhythms from Section 13.
        case .transporterEngage:
            return makePulses(durationsMs: [40, 30, 40, 30, 60], intensity: intensity, sharpness: 0.7)
        case .torpedoPlantedOnPlayer:
            return makePulses(durationsMs: [60, 40, 80], intensity: intensity, sharpness: 0.7)
        case .speedBoostEngage:
            return makePulses(durationsMs: [25, 15, 25], intensity: intensity, sharpness: 0.7)
        case .cloakEngage:
            return makePulses(durationsMs: [15, 50, 15], intensity: intensity * 0.7, sharpness: 0.3)
        case .selfDestructArmed:
            return makePulses(durationsMs: [80, 40, 80, 40, 80], intensity: intensity, sharpness: 0.9)
        case .damageHeavy:
            return makePulses(durationsMs: [40, 25, 60], intensity: intensity, sharpness: 0.8)
        case .shieldBroken:
            return makePulses(durationsMs: [25, 25, 25], intensity: intensity, sharpness: 0.9)
        case .crashedIntoPlanet:
            return makePulses(durationsMs: [40, 20, 50], intensity: intensity, sharpness: 0.7)
        case .singularityEvent:
            return makePulses(durationsMs: [200, 60, 150, 60, 200], intensity: intensity, sharpness: 0.4)
        case .powerUpCollected:
            return makePulses(durationsMs: [10, 20, 15], intensity: intensity * 0.8, sharpness: 0.7)
        case .matchStart:
            return makePulses(durationsMs: [25, 80, 25], intensity: intensity, sharpness: 0.7)
        case .roundWonByPlayer:
            return makePulses(durationsMs: [60, 40, 100], intensity: intensity, sharpness: 0.6)
        case .playerDestroyed:
            return makePulses(durationsMs: [70, 50, 60, 50, 90, 60, 200], intensity: intensity, sharpness: 0.5)
        case .seriesVictory:
            return makePulses(durationsMs: [80, 50, 80, 50, 200], intensity: intensity, sharpness: 0.7)
        case .seriesDefeat:
            return makePulses(durationsMs: [180, 100, 180], intensity: intensity * 0.8, sharpness: 0.3)
        case .fatality:
            // Six-pulse build + long finale, 100ms gap then sustained 350ms (Section 13).
            return makePulses(durationsMs: [50, 30, 50, 30, 50, 30, 350],
                              intensity: intensity, sharpness: 0.8,
                              gapMs: 10, finaleSustain: true)
        }
    }

    /// Build a pattern from a list of (duration_seconds, intensity, sharpness) tuples — used
    /// for the single-pulse events above. Each event starts immediately after the previous.
    private func makePattern(_ pulses: [(Double, Float, Float)]) -> CHHapticPattern? {
        var events: [CHHapticEvent] = []
        var t: TimeInterval = 0
        for (dur, intensity, sharpness) in pulses {
            let params = [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ]
            events.append(CHHapticEvent(eventType: .hapticContinuous,
                                        parameters: params,
                                        relativeTime: t,
                                        duration: dur))
            t += dur + 0.010   // tiny gap
        }
        return try? CHHapticPattern(events: events, parameters: [])
    }

    /// Build a multi-pulse pattern from a list of pulse durations (in milliseconds), separated
    /// by a fixed gap. All pulses share the same intensity + sharpness. Optional `finaleSustain`
    /// makes the last pulse a louder sustained note (used for FATALITY).
    private func makePulses(durationsMs: [Int],
                            intensity: Float,
                            sharpness: Float,
                            gapMs: Int = 10,
                            finaleSustain: Bool = false) -> CHHapticPattern? {
        var events: [CHHapticEvent] = []
        var t: TimeInterval = 0
        for (i, ms) in durationsMs.enumerated() {
            let dur = TimeInterval(ms) / 1000.0
            let isFinale = finaleSustain && (i == durationsMs.count - 1)
            let pulseIntensity = isFinale ? min(1.0, intensity * 1.2) : intensity
            let pulseSharpness = isFinale ? max(0.1, sharpness * 0.6) : sharpness
            let params = [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: pulseIntensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: pulseSharpness),
            ]
            events.append(CHHapticEvent(eventType: .hapticContinuous,
                                        parameters: params,
                                        relativeTime: t,
                                        duration: dur))
            t += dur + TimeInterval(gapMs) / 1000.0
        }
        return try? CHHapticPattern(events: events, parameters: [])
    }

    // MARK: - Fallback (no Core Haptics)

    private func playFallback(_ event: Event, scale: CGFloat) {
        switch event {
        case .primaryFire, .powerUpCollected, .shieldRaise, .bouncedOffWall:
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: scale)
        case .secondaryFire, .speedBoostEngage, .cloakEngage, .damageMedium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: scale)
        case .specialFire, .transporterEngage, .damageHeavy, .shieldBroken,
             .crashedIntoPlanet, .torpedoPlantedOnPlayer, .selfDestructArmed,
             .playerDestroyed, .singularityEvent:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: scale)
        case .damageLight:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: scale)
        case .matchStart, .roundWonByPlayer, .seriesVictory:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .roundLostByPlayer, .seriesDefeat:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .fatality:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: scale)
            }
        }
    }

    #endif
}
