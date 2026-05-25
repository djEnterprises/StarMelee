import Foundation

/// Reusable App Store update reminder (SuperGrok addition, Section 16.7).
///
/// Polls Apple's `itunes.apple.com/lookup` once per day, compares the App Store version
/// to the bundle version, and surfaces a non-blocking notification when an update is
/// available. Stores last-prompted version in UserDefaults so the player isn't nagged
/// repeatedly about the same version.
///
/// Built as a standalone singleton with two-line config so it can drop into every
/// future djEnterprises app.
@MainActor
final class VersionCheckManager {
    static let shared = VersionCheckManager()

    /// Apple ID assigned by App Store Connect. Set this when the app is published.
    var appleAppID: String = ""

    /// User-facing app name for the alert message.
    var appName: String = "Star Melee"

    private let lastCheckKey = "versionCheck.lastCheckDate"
    private let lastPromptedVersionKey = "versionCheck.lastPromptedVersion"

    /// Result of a single check. The UI layer (SwiftUI alert / banner) reads `.updateAvailable`
    /// and presents the prompt itself — keeping this manager free of any UIKit/SwiftUI deps.
    enum Result {
        case skipped(reason: String)        // not enough time passed, or no Apple ID configured
        case current                         // App Store version matches bundle
        case updateAvailable(latest: String, current: String)
        case failed(Error)
    }

    /// Perform an asynchronous lookup. Safe to call from app launch — silent on network failure.
    @discardableResult
    func checkForUpdate(force: Bool = false) async -> Result {
        guard !appleAppID.isEmpty else { return .skipped(reason: "appleAppID unset") }

        if !force, let last = UserDefaults.standard.object(forKey: lastCheckKey) as? Date {
            // Once per day at most.
            if Date().timeIntervalSince(last) < 24 * 60 * 60 {
                return .skipped(reason: "checked within last 24h")
            }
        }
        UserDefaults.standard.set(Date(), forKey: lastCheckKey)

        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(appleAppID)&country=US") else {
            return .skipped(reason: "bad URL")
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let latest = first["version"] as? String,
                  let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            else {
                return .skipped(reason: "unexpected response shape")
            }
            return isNewer(latest, than: current)
                ? .updateAvailable(latest: latest, current: current)
                : .current
        } catch {
            return .failed(error)
        }
    }

    /// Has the player already been prompted about this exact version?
    func hasPromptedFor(version: String) -> Bool {
        UserDefaults.standard.string(forKey: lastPromptedVersionKey) == version
    }

    /// Record that the player saw the prompt for this version.
    func markPrompted(version: String) {
        UserDefaults.standard.set(version, forKey: lastPromptedVersionKey)
    }

    /// Compare "1.2.3" semantic versions. Returns true if `a` is strictly newer than `b`.
    func isNewer(_ a: String, than b: String) -> Bool {
        let ap = a.split(separator: ".").compactMap { Int($0) }
        let bp = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(ap.count, bp.count) {
            let av = i < ap.count ? ap[i] : 0
            let bv = i < bp.count ? bp[i] : 0
            if av > bv { return true }
            if av < bv { return false }
        }
        return false
    }
}
