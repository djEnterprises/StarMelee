import SwiftUI

@main
struct StarMeleeApp: App {
    init() {
        // Non-blocking Game Center authentication. Safe to call even when Game Center is not
        // configured in App Store Connect yet — the manager handles that quietly.
        GameCenterManager.shared.authenticate()

        // Procedural audio pipeline (Section 12). Idle until the first play() call.
        AudioSystem.shared.prepare()

        // App Store version check (no-op until Daniel sets the Apple App ID after first publish).
        // VersionCheckManager.shared.appleAppID = "1234567890"
        Task { _ = await VersionCheckManager.shared.checkForUpdate() }
    }

    var body: some Scene {
        WindowGroup {
            MainMenuView()
                .preferredColorScheme(.dark)
                .statusBarHiddenIfAvailable()
        }
    }
}

private extension View {
    @ViewBuilder
    func statusBarHiddenIfAvailable() -> some View {
        #if os(iOS)
        self.statusBarHidden(true)
            .persistentSystemOverlays(.hidden)
        #else
        self
        #endif
    }
}
