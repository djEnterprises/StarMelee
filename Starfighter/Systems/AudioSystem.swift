import Foundation
import AVFoundation
import CoreGraphics

/// Procedurally synthesized audio system (Section 12).
///
/// Builds a small library of one-shot sound effects at engine start, then plays them via
/// dedicated `AVAudioPlayerNode`s. Each effect is a sine / sweep / noise burst with an
/// exponential decay envelope — Section 12 explicitly accepts "Web Audio API-style synthesized
/// sounds via AVAudioEngine" for v1.0, with curated assets in v1.1.
///
/// Phase 4 audit: volume settings are **cached** rather than read from `UserDefaults` on every
/// `play()` call. Cache refreshes when the Settings screen posts `UserDefaults.didChangeNotification`
/// or when `refreshVolumeCache()` is called explicitly. This eliminates ~600 UserDefaults
/// reads/second during active combat.
final class AudioSystem {
    static let shared = AudioSystem()

    enum Sound: CaseIterable {
        // Combat
        case primaryFire, secondaryFire, specialFire
        case damageLight, damageHeavy, destruction
        // Power-ups + buffs
        case powerUpCollect
        case shieldRaise, shieldLower
        case speedBoostEngage, cloakEngage
        // Big events
        case transporterEngage, quantumSingularity, fatality
        // Match flow
        case matchStart, matchEnd, victorySting, defeatSting
    }

    // MARK: - Engine

    private let engine = AVAudioEngine()
    private var players: [Sound: AVAudioPlayerNode] = [:]
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    private var prepared = false

    // MARK: - Cached volume

    /// Cached effective SFX volume (master × sfx). Recomputed on UserDefaults changes.
    private var cachedSfxVolume: Float = 0.72   // 0.8 × 0.9 defaults

    /// Call once on app launch. Sets up the audio session, generates all sound buffers, and
    /// starts the engine. Safe to call multiple times — no-op after first success.
    func prepare() {
        guard !prepared else { return }
        prepared = true

        configureAudioSession()
        refreshVolumeCache()

        // Observe Settings → volume changes. UserDefaults posts a notification whenever any
        // value changes, so we recompute the cache cheaply on those (rare) events instead of
        // re-reading on every play.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDefaultsChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )

        let format = engine.mainMixerNode.outputFormat(forBus: 0)

        for sound in Sound.allCases {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players[sound] = player
            buffers[sound] = makeBuffer(for: sound, format: format)
        }

        do {
            try engine.start()
            for (_, player) in players { player.play() }
        } catch {
            prepared = false
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureAudioSession() {
        #if os(iOS) || os(tvOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Non-fatal; engine still attempts to play with whatever default session is active.
        }
        #endif
    }

    /// Re-read the master and SFX volumes from `UserDefaults` and recompute the cached product.
    /// Called once at `prepare()` time and again whenever `UserDefaults.didChangeNotification` fires.
    func refreshVolumeCache() {
        let master = (UserDefaults.standard.object(forKey: "settings.masterVolume") as? Double) ?? 0.8
        let sfx    = (UserDefaults.standard.object(forKey: "settings.sfxVolume") as? Double) ?? 0.9
        cachedSfxVolume = Float(master * sfx)
    }

    @objc private func handleDefaultsChanged() {
        refreshVolumeCache()
    }

    // MARK: - Public play API

    /// Trigger a one-shot effect. No-op when prepare() hasn't been called, volume is zero, or
    /// the engine failed to start.
    func play(_ sound: Sound) {
        guard prepared else { return }
        let vol = cachedSfxVolume
        guard vol > 0.001 else { return }
        guard let player = players[sound], let buffer = buffers[sound] else { return }
        player.volume = vol
        player.scheduleBuffer(buffer, at: nil, options: [.interrupts], completionHandler: nil)
    }

    // MARK: - Buffer generation

    private func makeBuffer(for sound: Sound, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        switch sound {
        case .primaryFire:
            return generate(format: format, durationSec: 0.10) { t, _, _ in
                self.sineSweep(t: t, startHz: 1400, endHz: 500, duration: 0.10, decay: 22)
            }
        case .secondaryFire:
            return generate(format: format, durationSec: 0.22) { t, _, _ in
                self.sineSweep(t: t, startHz: 220, endHz: 90, duration: 0.22, decay: 9)
            }
        case .specialFire:
            return generate(format: format, durationSec: 0.40) { t, _, _ in
                let f1 = self.sine(t: t, hz: 660) * exp(-6 * t)
                let f2 = self.sine(t: t, hz: 990) * exp(-6 * (t - 0.05).asNonNegative)
                let f3 = self.sine(t: t, hz: 1320) * exp(-6 * (t - 0.10).asNonNegative)
                return Float(0.25 * (f1 + f2 + f3))
            }
        case .damageLight:
            return generate(format: format, durationSec: 0.08) { t, _, _ in
                let n = (Float.random(in: -1...1)) * Float(exp(-20 * t)) * 0.35
                return n
            }
        case .damageHeavy:
            return generate(format: format, durationSec: 0.25) { t, _, _ in
                let lowSine = self.sine(t: t, hz: 110) * exp(-7 * t) * 0.4
                let noise = Double(Float.random(in: -1...1)) * exp(-9 * t) * 0.4
                return Float(lowSine + noise)
            }
        case .destruction:
            return generate(format: format, durationSec: 0.85) { t, _, _ in
                let rumble = self.sineSweep(t: t, startHz: 90, endHz: 35, duration: 0.85, decay: 2.2)
                let noise = Float(Double.random(in: -1...1) * exp(-3 * t)) * 0.4
                return rumble + noise
            }
        case .powerUpCollect:
            return generate(format: format, durationSec: 0.25) { t, _, _ in
                let f1 = self.sine(t: t, hz: 600) * exp(-15 * t)
                let f2 = self.sine(t: t, hz: 900) * exp(-15 * (t - 0.05).asNonNegative)
                let f3 = self.sine(t: t, hz: 1200) * exp(-15 * (t - 0.10).asNonNegative)
                return Float(0.30 * (f1 + f2 + f3))
            }
        case .shieldRaise:
            return generate(format: format, durationSec: 0.30) { t, _, _ in
                return self.sineSweep(t: t, startHz: 250, endHz: 550, duration: 0.30, decay: 4.5)
            }
        case .shieldLower:
            return generate(format: format, durationSec: 0.30) { t, _, _ in
                return self.sineSweep(t: t, startHz: 550, endHz: 200, duration: 0.30, decay: 4.5)
            }
        case .speedBoostEngage:
            return generate(format: format, durationSec: 0.30) { t, _, _ in
                let f1 = self.sine(t: t, hz: 800) * exp(-30 * t)
                let f2 = self.sine(t: t, hz: 1200) * exp(-30 * (t - 0.06).asNonNegative)
                return Float(0.4 * (f1 + f2))
            }
        case .cloakEngage:
            return generate(format: format, durationSec: 0.45) { t, _, _ in
                let env = exp(-3.5 * t)
                let s = self.sine(t: t, hz: 2200 + 600 * sin(2 * .pi * 14 * t))
                return Float(s * env * 0.25)
            }
        case .transporterEngage:
            return generate(format: format, durationSec: 0.7) { t, _, _ in
                let wob = sin(2 * .pi * 18 * t)
                let s = self.sine(t: t, hz: 3000 + 1200 * wob) * exp(-2.5 * t)
                return Float(s * 0.22)
            }
        case .quantumSingularity:
            return generate(format: format, durationSec: 1.2) { t, _, _ in
                let sweep = self.sineSweep(t: t, startHz: 180, endHz: 35, duration: 1.2, decay: 1.6)
                let warble = self.sine(t: t, hz: 60 + 35 * sin(2 * .pi * 4 * t)) * exp(-1.3 * t) * 0.3
                return sweep * 0.7 + Float(warble)
            }
        case .fatality:
            return generate(format: format, durationSec: 1.4) { t, _, _ in
                let root = self.sine(t: t, hz: 110)
                let fifth = self.sine(t: t, hz: 164.81)
                let tritone = self.sine(t: t, hz: 155.56)
                let env = exp(-1.4 * t)
                return Float((root + fifth + tritone) * env * 0.20)
            }
        case .matchStart:
            return generate(format: format, durationSec: 0.45) { t, _, _ in
                return self.sineSweep(t: t, startHz: 300, endHz: 900, duration: 0.45, decay: 3)
            }
        case .matchEnd:
            return generate(format: format, durationSec: 0.45) { t, _, _ in
                return self.sineSweep(t: t, startHz: 900, endHz: 300, duration: 0.45, decay: 3)
            }
        case .victorySting:
            return generate(format: format, durationSec: 1.0) { t, _, _ in
                let f1 = self.sine(t: t, hz: 440) * exp(-3 * t)
                let f2 = self.sine(t: t, hz: 554.37) * exp(-3 * (t - 0.10).asNonNegative)
                let f3 = self.sine(t: t, hz: 659.25) * exp(-3 * (t - 0.20).asNonNegative)
                let f4 = self.sine(t: t, hz: 880) * exp(-3 * (t - 0.30).asNonNegative)
                return Float(0.22 * (f1 + f2 + f3 + f4))
            }
        case .defeatSting:
            return generate(format: format, durationSec: 1.0) { t, _, _ in
                let f1 = self.sine(t: t, hz: 220) * exp(-2.5 * t)
                let f2 = self.sine(t: t, hz: 130.81) * exp(-2.5 * (t - 0.25).asNonNegative)
                return Float(0.30 * (f1 + f2))
            }
        }
    }

    // MARK: - Synthesis helpers

    private func generate(format: AVAudioFormat,
                          durationSec: Double,
                          sample: (Double, Int, Double) -> Float) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(durationSec * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount

        guard let floatData = buffer.floatChannelData else { return nil }
        let channelCount = Int(format.channelCount)

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let s = sample(t, i, sampleRate)
            for c in 0..<channelCount {
                floatData[c][i] = s
            }
        }
        return buffer
    }

    private func sine(t: Double, hz: Double) -> Double {
        sin(2 * .pi * hz * t)
    }

    private func sineSweep(t: Double, startHz: Double, endHz: Double, duration: Double, decay: Double) -> Float {
        let progress = min(1, t / duration)
        let f0 = startHz
        let f1 = endHz
        let phase = 2 * .pi * (f0 * t + (f1 - f0) * t * t / (2 * duration))
        let envelope = exp(-decay * t) * (1 - 0.15 * progress)
        return Float(sin(phase) * envelope * 0.3)
    }
}

private extension Double {
    var asNonNegative: Double { Swift.max(0, self) }
}
