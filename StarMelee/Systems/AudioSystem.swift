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
/// Phase 4 hand-off: when CC0 audio packs are wired in, the public API stays the same — only
/// the buffer source changes (file-loaded `AVAudioPCMBuffer` instead of generated).
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

    // Volume settings — read from UserDefaults on each play.
    private var masterVolume: Float {
        let v = UserDefaults.standard.object(forKey: "settings.masterVolume") as? Double ?? 0.8
        return Float(v)
    }
    private var sfxVolume: Float {
        let v = UserDefaults.standard.object(forKey: "settings.sfxVolume") as? Double ?? 0.9
        return Float(v)
    }

    /// Call once on app launch. Sets up the audio session, generates all sound buffers, and
    /// starts the engine. Safe to call multiple times — no-op after first success.
    func prepare() {
        guard !prepared else { return }
        prepared = true

        configureAudioSession()

        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        // SwiftFloat samples — mono synthesis upmixed by the mixer to whatever the device expects.

        for sound in Sound.allCases {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players[sound] = player
            buffers[sound] = makeBuffer(for: sound, format: format)
        }

        do {
            try engine.start()
            // Start all players in "playing" state so scheduleBuffer fires immediately.
            for (_, player) in players { player.play() }
        } catch {
            // Engine failed — leave system idle. Future play() calls will no-op safely.
            prepared = false
        }
    }

    private func configureAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Non-fatal; engine still attempts to play with whatever default session is active.
        }
        #endif
    }

    // MARK: - Public play API

    /// Trigger a one-shot effect. No-op when:
    ///   - prepare() hasn't been called yet
    ///   - master volume or SFX volume is zero
    ///   - the engine failed to start
    func play(_ sound: Sound) {
        guard prepared else { return }
        guard let player = players[sound], let buffer = buffers[sound] else { return }
        let vol = masterVolume * sfxVolume
        guard vol > 0.001 else { return }
        player.volume = vol
        player.scheduleBuffer(buffer, at: nil, options: [.interrupts], completionHandler: nil)
    }

    // MARK: - Buffer generation

    private func makeBuffer(for sound: Sound, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        switch sound {
        case .primaryFire:
            return generate(format: format, durationSec: 0.10) { t, _, _ in
                // Quick down-sweep — laser pew.
                self.sineSweep(t: t, startHz: 1400, endHz: 500, duration: 0.10, decay: 22)
            }
        case .secondaryFire:
            return generate(format: format, durationSec: 0.22) { t, _, _ in
                // Lower-pitched thump with longer tail — missile launch.
                self.sineSweep(t: t, startHz: 220, endHz: 90, duration: 0.22, decay: 9)
            }
        case .specialFire:
            return generate(format: format, durationSec: 0.40) { t, _, _ in
                // Wider arpeggio — special weapon flare.
                let f1 = self.sine(t: t, hz: 660) * exp(-6 * t)
                let f2 = self.sine(t: t, hz: 990) * exp(-6 * (t - 0.05).asNonNegative)
                let f3 = self.sine(t: t, hz: 1320) * exp(-6 * (t - 0.10).asNonNegative)
                return Float(0.25 * (f1 + f2 + f3))
            }
        case .damageLight:
            return generate(format: format, durationSec: 0.08) { t, _, _ in
                // Short noise tick.
                let n = (Float.random(in: -1...1)) * Float(exp(-20 * t)) * 0.35
                return n
            }
        case .damageHeavy:
            return generate(format: format, durationSec: 0.25) { t, _, _ in
                // Crunchy heavier hit — low sine + noise.
                let lowSine = self.sine(t: t, hz: 110) * exp(-7 * t) * 0.4
                let noise = Double(Float.random(in: -1...1)) * exp(-9 * t) * 0.4
                return Float(lowSine + noise)
            }
        case .destruction:
            return generate(format: format, durationSec: 0.85) { t, _, _ in
                // Layered: low rumble + noise burst + descending sub-sweep.
                let rumble = self.sineSweep(t: t, startHz: 90, endHz: 35, duration: 0.85, decay: 2.2)
                let noise = Float(Double.random(in: -1...1) * exp(-3 * t)) * 0.4
                return rumble + noise
            }
        case .powerUpCollect:
            return generate(format: format, durationSec: 0.25) { t, _, _ in
                // Pleasant rising 3-note chirp.
                let f1 = self.sine(t: t, hz: 600) * exp(-15 * t)
                let f2 = self.sine(t: t, hz: 900) * exp(-15 * (t - 0.05).asNonNegative)
                let f3 = self.sine(t: t, hz: 1200) * exp(-15 * (t - 0.10).asNonNegative)
                return Float(0.30 * (f1 + f2 + f3))
            }
        case .shieldRaise:
            return generate(format: format, durationSec: 0.30) { t, _, _ in
                // Building hum.
                return self.sineSweep(t: t, startHz: 250, endHz: 550, duration: 0.30, decay: 4.5)
            }
        case .shieldLower:
            return generate(format: format, durationSec: 0.30) { t, _, _ in
                // Descending hum.
                return self.sineSweep(t: t, startHz: 550, endHz: 200, duration: 0.30, decay: 4.5)
            }
        case .speedBoostEngage:
            return generate(format: format, durationSec: 0.30) { t, _, _ in
                // Two quick ticks — engine kicking in.
                let f1 = self.sine(t: t, hz: 800) * exp(-30 * t)
                let f2 = self.sine(t: t, hz: 1200) * exp(-30 * (t - 0.06).asNonNegative)
                return Float(0.4 * (f1 + f2))
            }
        case .cloakEngage:
            return generate(format: format, durationSec: 0.45) { t, _, _ in
                // High-freq shimmer fading down — going invisible.
                let env = exp(-3.5 * t)
                let s = self.sine(t: t, hz: 2200 + 600 * sin(2 * .pi * 14 * t))
                return Float(s * env * 0.25)
            }
        case .transporterEngage:
            return generate(format: format, durationSec: 0.7) { t, _, _ in
                // Star-Trek-style shimmer — high oscillation modulated by a slower wave.
                let wob = sin(2 * .pi * 18 * t)
                let s = self.sine(t: t, hz: 3000 + 1200 * wob) * exp(-2.5 * t)
                return Float(s * 0.22)
            }
        case .quantumSingularity:
            return generate(format: format, durationSec: 1.2) { t, _, _ in
                // Deep reality-warp tone + slow sweep down.
                let sweep = self.sineSweep(t: t, startHz: 180, endHz: 35, duration: 1.2, decay: 1.6)
                let warble = self.sine(t: t, hz: 60 + 35 * sin(2 * .pi * 4 * t)) * exp(-1.3 * t) * 0.3
                return sweep * 0.7 + Float(warble)
            }
        case .fatality:
            return generate(format: format, durationSec: 1.4) { t, _, _ in
                // Sustained dark chord — root + fifth + tritone.
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
                // Triumphant ascending arpeggio.
                let f1 = self.sine(t: t, hz: 440) * exp(-3 * t)
                let f2 = self.sine(t: t, hz: 554.37) * exp(-3 * (t - 0.10).asNonNegative)
                let f3 = self.sine(t: t, hz: 659.25) * exp(-3 * (t - 0.20).asNonNegative)
                let f4 = self.sine(t: t, hz: 880) * exp(-3 * (t - 0.30).asNonNegative)
                return Float(0.22 * (f1 + f2 + f3 + f4))
            }
        case .defeatSting:
            return generate(format: format, durationSec: 1.0) { t, _, _ in
                // Slow descending two-note thud.
                let f1 = self.sine(t: t, hz: 220) * exp(-2.5 * t)
                let f2 = self.sine(t: t, hz: 130.81) * exp(-2.5 * (t - 0.25).asNonNegative)
                return Float(0.30 * (f1 + f2))
            }
        }
    }

    // MARK: - Synthesis helpers

    /// Generate a mono PCM buffer of the given duration by calling `sample(t, i, sampleRate)`
    /// for each frame. Returns nil if format is invalid.
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

    /// Pure sine wave at the given frequency, evaluated at time `t` (seconds from buffer start).
    private func sine(t: Double, hz: Double) -> Double {
        sin(2 * .pi * hz * t)
    }

    /// Frequency sweep from start → end Hz over `duration` seconds, with exponential decay.
    /// Uses proper phase integration so the sweep doesn't sound phase-jumpy.
    private func sineSweep(t: Double, startHz: Double, endHz: Double, duration: Double, decay: Double) -> Float {
        // Continuous chirp: phase = 2π ∫ f(τ) dτ = 2π (f0·t + (f1 - f0)·t²/(2·duration))
        let progress = min(1, t / duration)
        let f0 = startHz
        let f1 = endHz
        let phase = 2 * .pi * (f0 * t + (f1 - f0) * t * t / (2 * duration))
        let envelope = exp(-decay * t) * (1 - 0.15 * progress)   // slight extra fade as we sweep
        return Float(sin(phase) * envelope * 0.3)
    }
}

private extension Double {
    /// Clamp negatives to zero — used so envelope offset windows don't go positive before their
    /// scheduled time (e.g. the second arpeggio note shouldn't ring before its onset).
    var asNonNegative: Double { Swift.max(0, self) }
}
