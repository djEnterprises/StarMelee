import SwiftUI
import AuthenticationServices
#if canImport(GameKit)
import GameKit
#endif

/// Phase 4 owner: see plan Section 16 for the full spec.
/// Adds the **Apple Account** section (Sign in with Apple + iCloud sync + Game Center).
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

    // iCloud Sync — defaults to true. When the user flips it off, the confirmation dialog
    // explains the cross-platform-progression consequence and gives them a way to back out.
    @AppStorage("settings.iCloudSync") private var iCloudSyncEnabled: Bool = true
    @State private var showDisableSyncConfirmation = false

    @StateObject private var signInManager = SignInWithAppleManager.shared

    @State private var showGameCenter = false

    var body: some View {
        Form {
            appleAccountSection

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
        .confirmationDialog(
            "Disable iCloud Sync?",
            isPresented: $showDisableSyncConfirmation,
            titleVisibility: .visible
        ) {
            Button("Disable Sync", role: .destructive) {
                iCloudSyncEnabled = false
            }
            Button("Keep Sync Enabled", role: .cancel) {
                iCloudSyncEnabled = true   // user backed out
            }
        } message: {
            Text("Cross-platform progression will be turned off. Your stats, leaderboard records, and unlocks will no longer sync between iPhone, iPad, Mac, and Apple TV. Local progress on this device is unaffected.")
        }
        #if !os(tvOS)
        .sheet(isPresented: $showGameCenter) {
            GameCenterDashboardView()
                .ignoresSafeArea()
        }
        #endif
        .onAppear {
            signInManager.verifyExistingCredential()
        }
        .onChange(of: iCloudSyncEnabled) { _, nowEnabled in
            if nowEnabled {
                // User just (re-)enabled sync — push whatever they've accumulated locally up to
                // iCloud so a device that played offline doesn't get overwritten by an empty cloud.
                iCloudSyncManager.shared.pushAllLocalToCloud(keys: ["leaderboard.stats.v1"])
            }
        }
    }

    // MARK: - Apple Account section

    @ViewBuilder
    private var appleAccountSection: some View {
        Section("Apple Account") {
            // Sign in with Apple — shows the system button when not signed in; shows account
            // detail with "Sign Out" when signed in.
            appleSignInRow

            // iCloud sync toggle — the key feature. Intercepts the OFF transition with a
            // confirmation dialog explaining the cross-platform progression consequence.
            Toggle(isOn: Binding(
                get: { iCloudSyncEnabled },
                set: { newValue in
                    if newValue == false && iCloudSyncEnabled == true {
                        showDisableSyncConfirmation = true
                    } else {
                        iCloudSyncEnabled = newValue
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud Sync")
                    Text("Keeps your stats and progress in sync across iPhone, iPad, Mac, and Apple TV.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Game Center entry — tvOS deep-links via the system overlay; iOS / iPadOS /
            // Catalyst present the full GKGameCenterViewController sheet.
            #if !os(tvOS)
            Button {
                showGameCenter = true
            } label: {
                LabeledContent("Game Center") {
                    Text("View Leaderboards")
                        .foregroundStyle(.tint)
                }
            }
            #endif
        }
    }

    @ViewBuilder
    private var appleSignInRow: some View {
        switch signInManager.state {
        case .notSignedIn, .error:
            VStack(alignment: .leading, spacing: 6) {
                SignInWithAppleButton(.signIn,
                                      onRequest: { request in
                                          request.requestedScopes = [.fullName]
                                      },
                                      onCompletion: { result in
                                          signInManager.handleAuthorization(result)
                                      })
                .frame(height: 44)
                #if !os(tvOS)
                .signInWithAppleButtonStyle(.whiteOutline)
                #endif

                Text("Sign in to link your progress to your Apple ID and enable cross-device features.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if case .error(let msg) = signInManager.state {
                    Text(msg)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        case .signedIn(_, let displayName):
            HStack {
                Image(systemName: "person.crop.circle.fill.badge.checkmark")
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName ?? "Signed in with Apple")
                        .font(.system(size: 14, weight: .semibold))
                    // Be precise: progression sync is governed by the iCloud Sync toggle below,
                    // not by sign-in itself. Reflect the actual sync state here.
                    Text(iCloudSyncEnabled
                         ? "Apple ID linked · iCloud sync on"
                         : "Apple ID linked · iCloud sync off")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Sign Out") {
                    signInManager.signOut()
                }
                .foregroundStyle(.red)
                .buttonStyle(.borderless)
            }
        case .signingIn:
            HStack {
                ProgressView()
                Text("Signing in…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// tvOS doesn't ship `Slider` or `Stepper`. We fall back to a Picker with 11 discrete
    /// 10%-step values so settings stay adjustable via Apple TV remote / Siri Remote / gamepad.
    @ViewBuilder
    private func slider(_ label: String, value: Binding<Double>, range: ClosedRange<Double> = 0...1) -> some View {
        #if os(tvOS)
        let buckets: [Double] = (0...10).map { range.lowerBound + Double($0) / 10 * (range.upperBound - range.lowerBound) }
        Picker(label, selection: value) {
            ForEach(buckets, id: \.self) { v in
                Text(String(format: "%.0f%%", v * 100)).tag(v)
            }
        }
        #else
        HStack {
            Text(label)
            Slider(value: value, in: range)
            Text(String(format: "%.0f%%", value.wrappedValue * 100))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
        #endif
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
