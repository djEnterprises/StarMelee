import Foundation
import AVFoundation

/// Phase 4 owner: full music + per-ship SFX pipeline per plan Section 12.
/// Phase 1 stub: holds the AVAudioEngine handle and reads volume settings.
final class AudioSystem {
    static let shared = AudioSystem()

    private let engine = AVAudioEngine()
    private var prepared = false

    var masterVolume: Float {
        Float(UserDefaults.standard.double(forKey: "settings.masterVolume").nonZeroOrDefault(0.8))
    }
    var musicVolume: Float {
        Float(UserDefaults.standard.double(forKey: "settings.musicVolume").nonZeroOrDefault(0.7))
    }
    var sfxVolume: Float {
        Float(UserDefaults.standard.double(forKey: "settings.sfxVolume").nonZeroOrDefault(0.9))
    }

    func prepare() {
        guard !prepared else { return }
        prepared = true
        // Phase 4 will wire up music players + SFX nodes here.
    }
}

private extension Double {
    func nonZeroOrDefault(_ fallback: Double) -> Double {
        self == 0 ? fallback : self
    }
}
