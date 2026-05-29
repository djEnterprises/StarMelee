import Foundation
import AuthenticationServices
import Combine

/// Sign in with Apple — provides stable cross-device identity.
///
/// **Relationship to other systems:**
/// - **iCloudSyncManager** does the actual cross-platform data sync (via NSUbiquitousKeyValueStore).
///   That just needs the user to be signed into iCloud on the device.
/// - **Sign in with Apple** layers a stable user identifier on top so future features
///   (server-side leaderboards, account-bound IAP entitlements, etc.) have something to bind to.
/// - **GameCenterManager** runs in parallel — Apple ID provides Game Center auth automatically;
///   this manager doesn't replace that.
///
/// **Capability requirement:** "Sign in with Apple" must be enabled in App Store Connect →
/// Identifiers → Capabilities. Until that's done, the auth flow will fail at runtime; the UI
/// stays usable but presents an "unavailable" state.
///
/// **Persistence:** The Apple user ID (an opaque stable string Apple gives us) is stored in
/// UserDefaults via iCloudSyncManager so it survives reinstalls and syncs across devices.
@MainActor
final class SignInWithAppleManager: NSObject, ObservableObject {
    static let shared = SignInWithAppleManager()

    /// Reported state. Drives UI in SettingsView.
    enum State: Equatable {
        case notSignedIn
        case signedIn(userID: String, displayName: String?)
        case signingIn
        case error(String)
    }

    @Published private(set) var state: State = .notSignedIn

    private let userIDKey = "signInWithApple.userID"
    private let displayNameKey = "signInWithApple.displayName"

    private override init() {
        super.init()
        loadPersistedSession()
    }

    // MARK: - Public API

    /// Whether the user is currently signed in.
    var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    /// Current user ID (Apple's opaque stable identifier) if signed in.
    var currentUserID: String? {
        if case .signedIn(let id, _) = state { return id }
        return nil
    }

    /// Begin the Sign in with Apple flow. Wired to `SignInWithAppleButton` (SwiftUI) in
    /// SettingsView so the system handles presenting the sheet.
    func handleAuthorization(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                state = .error("Unexpected credential type")
                return
            }
            // Apple gives us a stable user identifier and (on first sign-in only) name + email.
            let userID = credential.user
            let fullName = credential.fullName
            let displayName: String? = {
                guard let fullName else { return nil }
                let formatter = PersonNameComponentsFormatter()
                let formatted = formatter.string(from: fullName)
                return formatted.isEmpty ? nil : formatted
            }()
            persistSession(userID: userID, displayName: displayName)
            state = .signedIn(userID: userID, displayName: displayName ?? currentDisplayName())

        case .failure(let error):
            if let asError = error as? ASAuthorizationError, asError.code == .canceled {
                // User cancelled — silent return to previous state, no error UI.
                state = isSignedIn ? state : .notSignedIn
            } else {
                state = .error(error.localizedDescription)
            }
        }
    }

    /// Sign the user out — clears local identity. iCloud-synced data is untouched.
    func signOut() {
        iCloudSyncManager.shared.set(nil, forKey: userIDKey)
        iCloudSyncManager.shared.set(nil, forKey: displayNameKey)
        state = .notSignedIn
    }

    /// Check on app launch (or whenever) that the Apple ID credential is still valid.
    /// Apple revokes it if the user signs out of iCloud or uses Settings → Sign in with Apple
    /// → Stop Using to revoke this app. Sets state to `.notSignedIn` if revoked.
    func verifyExistingCredential() {
        guard case .signedIn(let userID, _) = state else { return }
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { [weak self] credentialState, _ in
            Task { @MainActor in
                switch credentialState {
                case .authorized:
                    break   // still valid, no change
                case .revoked, .notFound, .transferred:
                    self?.signOut()
                @unknown default:
                    break
                }
            }
        }
    }

    // MARK: - Persistence (via iCloud sync so identity travels between devices)

    private func loadPersistedSession() {
        guard
            let userIDData = iCloudSyncManager.shared.data(forKey: userIDKey),
            let userID = String(data: userIDData, encoding: .utf8),
            !userID.isEmpty
        else {
            state = .notSignedIn
            return
        }
        state = .signedIn(userID: userID, displayName: currentDisplayName())
    }

    private func persistSession(userID: String, displayName: String?) {
        iCloudSyncManager.shared.set(Data(userID.utf8), forKey: userIDKey)
        if let displayName, let blob = displayName.data(using: .utf8) {
            iCloudSyncManager.shared.set(blob, forKey: displayNameKey)
        }
    }

    private func currentDisplayName() -> String? {
        guard
            let blob = iCloudSyncManager.shared.data(forKey: displayNameKey),
            let str = String(data: blob, encoding: .utf8),
            !str.isEmpty
        else { return nil }
        return str
    }
}
