import SwiftUI
import GameKit
#if canImport(UIKit)
import UIKit
#endif

/// Wraps Apple's `GKGameCenterViewController` so SwiftUI can present it as a sheet.
/// Works on iOS, iPadOS, Mac Catalyst, and tvOS — all four ship Game Center.
///
/// Usage (from any SwiftUI screen):
///
///     @State private var showGC = false
///     ...
///     .sheet(isPresented: $showGC) { GameCenterDashboardView() }
struct GameCenterDashboardView: UIViewControllerRepresentable {
    /// Which Game Center pane to open. `.leaderboards` is the most common.
    var initialPane: GKGameCenterViewControllerState = .leaderboards

    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let vc = GKGameCenterViewController(state: initialPane)
        vc.gameCenterDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: GKGameCenterViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, GKGameCenterControllerDelegate {
        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            #if canImport(UIKit)
            gameCenterViewController.dismiss(animated: true)
            #endif
        }
    }
}
