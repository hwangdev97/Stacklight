import Foundation
import Combine

/// Single source of truth for every persisted user setting. Replaces the
/// previous mix of scattered UserDefaults keys + envelope.
///
/// - **Persistence**: one UserDefaults key holding `SettingsEnvelope` (versioned
///   JSON). On iOS the underlying UserDefaults is the App Group suite so the
///   widget extension reads the same envelope.
/// - **SwiftUI**: conforms to ObservableObject; views observe via `@StateObject`
///   / `@ObservedObject` or use the `@SettingsValue` property wrapper for
///   key-path-style binding.
/// - **CLI / non-SwiftUI**: synchronous `string(for:)` / `setString(_:for:)`
///   etc., plus `mutate { ... }` for atomic edits.
/// - **Cross-process invalidation**: `NotificationCenter` posts
///   `SettingsStore.didChange` after every write. Other processes can listen
///   via Darwin notifications if needed; today the menu/widget rebuild on
///   their own polling cadence.
public final class SettingsStore: ObservableObject, @unchecked Sendable {
    public static let shared = SettingsStore()

    /// Posted on every successful write.
    public static let didChange = Notification.Name("StackLight.SettingsStore.didChange")

    private static let storageKey = "app.yellowplus.stacklight.settings"
    /// Bumped each time the UserSettings schema changes meaningfully. v2
    /// adds application-level fields + free-form provider config to the
    /// previous v1 envelope (which only held pinned/hidden).
    private static let currentVersion = 2

    private let defaults: UserDefaults
    private let lock = NSLock()
    private var _settings: UserSettings

    public var settings: UserSettings {
        lock.lock()
        defer { lock.unlock() }
        return _settings
    }

    public init(defaults: UserDefaults = AppConfig.legacyDefaults) {
        self.defaults = defaults
        self._settings = Self.loadInitial(defaults: defaults)
    }

    // MARK: - Bulk

    /// Atomically read, mutate, and persist. Block runs on the caller's
    /// thread under a lock; `objectWillChange` is published on main.
    public func mutate(_ block: (inout UserSettings) -> Void) {
        lock.lock()
        var copy = _settings
        block(&copy)
        let didChange = copy != _settings
        if didChange {
            _settings = copy
            Self.persist(copy, to: defaults)
        }
        lock.unlock()

        guard didChange else { return }
        publishChange()
    }

    public func reload() {
        lock.lock()
        _settings = Self.loadInitial(defaults: defaults)
        lock.unlock()
        publishChange()
    }

    // MARK: - Application-level typed accessors

    public var pollIntervalSeconds: Double {
        get { settings.pollIntervalSeconds }
        set { mutate { $0.pollIntervalSeconds = newValue } }
    }

    public var notificationsEnabled: Bool {
        get { settings.notificationsEnabled }
        set { mutate { $0.notificationsEnabled = newValue } }
    }

    public var diagnosticsEnabled: Bool {
        get { settings.diagnosticsEnabled }
        set { mutate { $0.diagnosticsEnabled = newValue } }
    }

    public var fileLoggingEnabled: Bool {
        get { settings.fileLoggingEnabled }
        set { mutate { $0.fileLoggingEnabled = newValue } }
    }

    public var loggingVerbosity: String {
        get { settings.loggingVerbosity }
        set { mutate { $0.loggingVerbosity = newValue } }
    }

    // MARK: - Provider config (free-form)

    public func string(for key: String) -> String? {
        settings.string(for: key)
    }

    public func setString(_ value: String?, for key: String) {
        mutate { $0.setString(value, for: key) }
    }

    public func bool(for key: String) -> Bool {
        settings.bool(for: key)
    }

    public func setBool(_ value: Bool, for key: String) {
        mutate { $0.setBool(value, for: key) }
    }

    public func stringArray(for key: String) -> [String] {
        settings.stringArray(for: key)
    }

    public func setStringArray(_ value: [String]?, for key: String) {
        mutate { $0.setStringArray(value, for: key) }
    }

    public func removeValue(for key: String) {
        mutate {
            $0.providerStrings.removeValue(forKey: key)
            $0.providerBools.removeValue(forKey: key)
            $0.providerStringArrays.removeValue(forKey: key)
        }
    }

    // MARK: - Persistence

    private static func persist(_ settings: UserSettings, to defaults: UserDefaults) {
        let envelope = SettingsEnvelope(version: currentVersion, settings: settings)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func loadInitial(defaults: UserDefaults) -> UserSettings {
        if let data = defaults.data(forKey: storageKey),
           let envelope = try? JSONDecoder().decode(SettingsEnvelope.self, from: data) {
            var settings = envelope.settings
            if envelope.version < currentVersion {
                applyMigrations(to: &settings, fromVersion: envelope.version, defaults: defaults)
                persist(settings, to: defaults)
            }
            return settings
        }
        // No envelope yet — could be a brand-new install or a pre-v1 user
        // whose settings live in scattered UserDefaults keys. Run the v0->v2
        // migration which copies known keys over.
        var fresh = UserSettings()
        applyMigrations(to: &fresh, fromVersion: 0, defaults: defaults)
        persist(fresh, to: defaults)
        return fresh
    }

    /// One-time migration from scattered UserDefaults keys into the envelope.
    /// Idempotent: if the source keys are gone we just keep whatever's in
    /// `settings`. Reads from both `.standard` and the App Group suite because
    /// historically `@AppStorage` wrote to `.standard` while providers wrote
    /// to the App Group — this catches both.
    private static func applyMigrations(
        to settings: inout UserSettings,
        fromVersion: Int,
        defaults: UserDefaults
    ) {
        guard fromVersion < currentVersion else { return }

        if fromVersion < 2 {
            // Try the active store first (App Group on iOS, .standard on macOS),
            // then fall back to .standard if a key is only there.
            let sources: [UserDefaults] = {
                if defaults === UserDefaults.standard {
                    return [defaults]
                }
                return [defaults, .standard]
            }()

            // Application-level
            for source in sources {
                if let raw = source.object(forKey: "pollInterval") as? Double, raw > 0 {
                    settings.pollIntervalSeconds = raw
                    break
                }
            }
            for source in sources {
                if let raw = source.object(forKey: "notificationsEnabled") as? Bool {
                    settings.notificationsEnabled = raw
                    break
                }
            }
            for source in sources {
                if let raw = source.object(forKey: "diagnosticsEnabled") as? Bool {
                    settings.diagnosticsEnabled = raw
                    break
                }
            }
            for source in sources {
                if let raw = source.object(forKey: "fileLoggingEnabled") as? Bool {
                    settings.fileLoggingEnabled = raw
                    break
                }
            }
            for source in sources {
                if let raw = source.string(forKey: "loggingVerbosity"), !raw.isEmpty {
                    settings.loggingVerbosity = raw
                    break
                }
            }

            // Provider keys — copy any known keys still in UserDefaults so
            // existing users don't lose their saved Vercel team ID etc.
            // Anything we didn't list here would have been unused anyway.
            for key in legacyProviderStringKeys {
                for source in sources {
                    if let value = source.string(forKey: key), !value.isEmpty {
                        settings.providerStrings[key] = value
                        break
                    }
                }
            }
            for key in legacyProviderBoolKeys {
                for source in sources {
                    if source.object(forKey: key) != nil {
                        settings.providerBools[key] = source.bool(forKey: key)
                        break
                    }
                }
            }
            for key in legacyProviderStringArrayKeys {
                for source in sources {
                    if let value = source.stringArray(forKey: key), !value.isEmpty {
                        settings.providerStringArrays[key] = value
                        break
                    }
                }
            }
        }
    }

    /// Provider-side configuration keys that historically lived in UserDefaults.
    /// Token-bearing keys are omitted on purpose — those stay in Keychain.
    private static let legacyProviderStringKeys: [String] = [
        "vercel.teamId", "vercel.projectNames", "vercel.branchFilter",
        "cloudflare.accountId", "cloudflare.projectNames",
        "github.repos", "github.pr.repos",
        "netlify.siteIds",
        "railway.projectIds",
        "flyio.apps",
        "testflight.appIds",
        "xcodeCloud.productIds"
    ]
    private static let legacyProviderBoolKeys: [String] = [
        "vercel.hideSkippedPreviews"
    ]
    private static let legacyProviderStringArrayKeys: [String] = [
        "vercel.knownBranches"
    ]

    // MARK: - Change publishing

    private func publishChange() {
        let send: () -> Void = {
            self.objectWillChange.send()
            NotificationCenter.default.post(name: Self.didChange, object: nil)
        }
        if Thread.isMainThread {
            send()
        } else {
            DispatchQueue.main.async(execute: send)
        }
    }
}

private struct SettingsEnvelope: Codable {
    let version: Int
    let settings: UserSettings
}
