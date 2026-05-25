import SwiftUI

/// Phase 4 owner: see plan Section 16 for the full spec.
/// Phase 1 stub: sections present so navigation works; controls bind to AppStorage so values persist.
struct SettingsView: View {
    @AppStorage("settings.masterVolume") private var masterVolume: Double = 0.8
    @AppStorage("settings.musicVolume") private var musicVolume: Double = 0.7
    @AppStorage("settings.sfxVolume") private var sfxVolume: Double = 0.9
    @AppStorage("settings.hapticIntensity") private var hapticIntensity: String = "medium"
    @AppStorage("settings.aiDifficulty") private var aiDifficulty: String = "captain"
    @AppStorage("settings.matchLengthSeconds") private var matchLengthSeconds: Int = 120
    @AppStorage("settings.buttonOpacity") private var buttonOpacity: Double = 0.7
    @AppStorage("settings.buttonSize") private var buttonSize: Double = 1.0
    @AppStorage("settings.leftHandedMode") private var leftHandedMode: Bool = false
    @AppStorage("settings.reduceMotion") private var reduceMotion: String = "off"

    var body: some View {
        Form {
            Section("Audio") {
                slider("Master", value: $masterVolume)
                slider("Music", value: $musicVolume)
                slider("SFX", value: $sfxVolume)
                Picker("Haptic Intensity", selection: $hapticIntensity) {
                    Text("Off").tag("off")
                    Text("Low").tag("low")
                    Text("Medium").tag("medium")
                    Text("High").tag("high")
                }
            }

            Section("Controls") {
                slider("Button Opacity", value: $buttonOpacity)
                slider("Button Size", value: $buttonSize, range: 0.7...1.4)
                Toggle("Left-handed Mode", isOn: $leftHandedMode)
            }

            Section("Gameplay") {
                Picker("AI Difficulty", selection: $aiDifficulty) {
                    Text("Cadet").tag("cadet")
                    Text("Captain").tag("captain")
                    Text("Admiral").tag("admiral")
                    Text("Legendary").tag("legendary")
                }
                Picker("Match Length", selection: $matchLengthSeconds) {
                    Text("90s").tag(90)
                    Text("120s").tag(120)
                    Text("180s").tag(180)
                    Text("300s").tag(300)
                }
            }

            Section("Accessibility") {
                Picker("Reduce Motion", selection: $reduceMotion) {
                    Text("Off (full effects)").tag("off")
                    Text("Reduced").tag("reduced")
                    Text("Disabled").tag("disabled")
                }
                Text("Scales camera shake, slow-motion, and shockwave effects.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Build", value: appBuild)
                Text("© 2026 djEnterprises")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }

    private func slider(_ label: String, value: Binding<Double>, range: ClosedRange<Double> = 0...1) -> some View {
        HStack {
            Text(label)
            Slider(value: value, in: range)
            Text(String(format: "%.0f%%", value.wrappedValue * 100))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
