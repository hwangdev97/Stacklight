import Foundation

/// Versioned envelope persistence for `UserSettings`. Stored in `UserDefaults`
/// under a single key so we can ship schema changes without per-key migration
/// chaos. Mirrors RepoBar's `SettingsStore`.
public final class SettingsStore: @unchecked Sendable {
    public static let shared = SettingsStore()

    private static let storageKey = "app.yellowplus.stacklight.settings"
    private static let currentVersion = 1
    private let defaults: UserDefaults
    private let lock = NSLock()
    private var cached: UserSettings?

    public init(defaults: UserDefaults = AppConfig.defaults) {
        self.defaults = defaults
    }

    public func load() -> UserSettings {
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }

        guard let data = defaults.data(forKey: Self.storageKey) else {
            let initial = UserSettings()
            cached = initial
            return initial
        }
        let decoder = JSONDecoder()
        if let envelope = try? decoder.decode(SettingsEnvelope.self, from: data) {
            var settings = envelope.settings
            if envelope.version < Self.currentVersion {
                Self.applyMigrations(to: &settings, fromVersion: envelope.version)
                save(settings)
            }
            cached = settings
            return settings
        }
        let fallback = UserSettings()
        cached = fallback
        return fallback
    }

    public func save(_ settings: UserSettings) {
        lock.lock()
        cached = settings
        lock.unlock()
        let envelope = SettingsEnvelope(version: Self.currentVersion, settings: settings)
        if let data = try? JSONEncoder().encode(envelope) {
            defaults.set(data, forKey: Self.storageKey)
        }
        NotificationCenter.default.post(name: SettingsStore.didChange, object: nil)
    }

    public func mutate(_ block: (inout UserSettings) -> Void) {
        var settings = load()
        block(&settings)
        save(settings)
    }

    /// Posted on the main thread by `save(_:)`. Listeners (menu builder,
    /// projects settings panel) should rebuild their view of the world.
    public static let didChange = Notification.Name("StackLight.SettingsStore.didChange")

    private static func applyMigrations(to _: inout UserSettings, fromVersion: Int) {
        // No migrations yet — placeholder for when v2 lands.
        guard fromVersion < currentVersion else { return }
    }
}

private struct SettingsEnvelope: Codable {
    let version: Int
    let settings: UserSettings
}
