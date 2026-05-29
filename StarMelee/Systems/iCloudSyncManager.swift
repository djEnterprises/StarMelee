import Foundation
import Combine

/// Cross-platform progression backbone — wraps `NSUbiquitousKeyValueStore` (iCloud
/// Key-Value Storage) with a UserDefaults fallback.
///
/// **Why iCloud KVS instead of CloudKit:**
/// - Starfighter's progression data is small (per-ship stats, win streaks, settings, achievements)
/// - KVS is dead-simple, no schemas, no async, no zone management, no quota worries (1 MB total)
/// - Works automatically the moment the user is signed into iCloud on the device
/// - Synced automatically by iOS / iPadOS / macOS / tvOS in the background
///
/// **Setup requirements (already declared in StarMelee.entitlements):**
/// - `com.apple.developer.icloud-container-identifiers` → `iCloud.com.djEnterprises.Starfighter`
/// - `com.apple.developer.icloud-services` → `[CloudKit, NSUbiquitousKeyValueStore]`
/// Daniel: when first ready to ship, enable the iCloud capability in App Store Connect
/// Identifiers → Capabilities. Until enabled, all KVS calls quietly no-op and we fall back
/// to UserDefaults — the local game keeps working.
///
/// **User opt-out:**
/// The `settings.iCloudSync` UserDefaults key (default true) is the master switch. When the
/// player turns it OFF in Settings, this manager stops writing to and reading from iCloud KVS
/// — local UserDefaults becomes the sole source of truth on that device.
@MainActor
final class iCloudSyncManager: ObservableObject {
    static let shared = iCloudSyncManager()

    private let store = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard
    private let syncEnabledKey = "settings.iCloudSync"

    /// True by default. When the user toggles this off, an "Are you sure?" dialog warns about
    /// disabled cross-platform progression. See `SettingsView` for the UI.
    var isEnabled: Bool {
        defaults.object(forKey: syncEnabledKey) as? Bool ?? true
    }

    /// Published flag for SwiftUI views (e.g. the Settings toggle) to bind to. Mirrors
    /// `isEnabled` via `UserDefaults.didChange`.
    @Published private(set) var cloudReady: Bool = false

    /// Notification posted whenever an external device updates a value we have a local
    /// mirror of. Observers (e.g. `LeaderboardStore`) refresh their in-memory state on this.
    static let externalChangeNotification = Notification.Name("StarMelee.iCloudSync.externalChange")

    private init() {
        // Bootstrap iCloud — `synchronize()` triggers a download of any pending remote changes.
        store.synchronize()
        cloudReady = (FileManager.default.ubiquityIdentityToken != nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleExternalChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        // Detect user signing in / out of iCloud on the device.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleIdentityChange),
            name: .NSUbiquityIdentityDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public API (Data)

    /// Read a `Data` blob. Prefers iCloud value when sync is enabled and the cloud has a
    /// non-nil value; otherwise reads local UserDefaults.
    func data(forKey key: String) -> Data? {
        if isEnabled, let cloud = store.data(forKey: key) {
            return cloud
        }
        return defaults.data(forKey: key)
    }

    /// Write a `Data` blob. Always writes locally so the device works offline; also writes
    /// to iCloud KVS when sync is enabled. Calls `synchronize()` to flush the KVS dirty buffer.
    func set(_ value: Data?, forKey key: String) {
        defaults.set(value, forKey: key)
        if isEnabled {
            if let value = value {
                store.set(value, forKey: key)
            } else {
                store.removeObject(forKey: key)
            }
            store.synchronize()
        }
    }

    // MARK: - Public API (Bool / Int / String — convenience for small settings)

    func bool(forKey key: String, default fallback: Bool = false) -> Bool {
        if isEnabled {
            // KVS bool returns false for unset keys; distinguish via object-check.
            if store.object(forKey: key) != nil {
                return store.bool(forKey: key)
            }
        }
        return (defaults.object(forKey: key) as? Bool) ?? fallback
    }

    func setBool(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
        if isEnabled {
            store.set(value, forKey: key)
            store.synchronize()
        }
    }

    // MARK: - Lifecycle hooks

    @objc private func handleExternalChange(_ notification: Notification) {
        // Re-broadcast as a Starfighter-specific notification so observers don't have to
        // import the raw KVS notification name.
        guard isEnabled else { return }
        NotificationCenter.default.post(name: Self.externalChangeNotification, object: nil)
    }

    @objc private func handleIdentityChange() {
        // User signed in/out of iCloud on the device — re-evaluate sync readiness.
        cloudReady = (FileManager.default.ubiquityIdentityToken != nil)
        if cloudReady {
            store.synchronize()
        }
    }

    // MARK: - Migration / diagnostics

    /// One-shot upload of all locally-stored sync-aware keys to iCloud — used when the
    /// user enables iCloud sync after having played locally for a while.
    /// Pass the list of keys the app knows about (the leaderboard store key, settings keys, etc).
    func pushAllLocalToCloud(keys: [String]) {
        guard isEnabled else { return }
        for key in keys {
            if let blob = defaults.data(forKey: key) {
                store.set(blob, forKey: key)
            } else if let boolValue = defaults.object(forKey: key) as? Bool {
                store.set(boolValue, forKey: key)
            }
        }
        store.synchronize()
    }
}
