import SwiftUI

@main
struct StarMeleeApp: App {
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
