import Foundation

/// Persisted `[deploymentKey: statusRawValue]` mirror of the last status we
/// surfaced a notification for. Lives in the App Group `UserDefaults` so the
/// foreground app, the iOS background-refresh handler, and post-cold-launch
/// runs all diff against the same source of truth — a status change shown in
/// the foreground will not be re-announced when iOS wakes the app in the
/// background, and vice versa.
public enum NotifiedStateStore {
    public static let key = "deployments.notifiedStates.v1"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: SharedStore.suiteName)
    }

    /// In-process memo of the persisted dict. The notification path runs on
    /// every poll — caching here avoids re-deserializing the whole dictionary
    /// from `UserDefaults` each time, and also lets `write` skip the disk
    /// hit when nothing changed since the last write. Both processes that
    /// touch this store (host app + iOS background handler) live in their
    /// own address spaces, so cross-process staleness is fine: the worst
    /// case is one duplicated notification on a launch race, which the
    /// existing diff already tolerates.
    private static let cacheLock = NSLock()
    private static var cachedStates: [String: String]?

    public static func read() -> [String: String] {
        cacheLock.lock()
        if let cached = cachedStates {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let loaded = (defaults?.dictionary(forKey: key) as? [String: String]) ?? [:]
        cacheLock.lock()
        cachedStates = loaded
        cacheLock.unlock()
        return loaded
    }

    public static func write(_ states: [String: String]) {
        cacheLock.lock()
        let unchanged = (cachedStates == states)
        cachedStates = states
        cacheLock.unlock()

        guard !unchanged else { return }
        defaults?.set(states, forKey: key)
    }

    public static func key(for deployment: Deployment) -> String {
        "\(deployment.providerID):\(deployment.id)"
    }
}
