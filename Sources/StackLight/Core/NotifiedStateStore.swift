import Foundation

/// Persisted `[deploymentKey: statusRawValue]` mirror of the last status we
/// surfaced a notification for. Lives in the App Group `UserDefaults` so the
/// foreground app, the iOS background-refresh handler, and post-cold-launch
/// runs all diff against the same source of truth — a status change shown in
/// the foreground will not be re-announced when iOS wakes the app in the
/// background, and vice versa.
enum NotifiedStateStore {
    static let key = "deployments.notifiedStates.v1"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: SharedStore.suiteName)
    }

    static func read() -> [String: String] {
        (defaults?.dictionary(forKey: key) as? [String: String]) ?? [:]
    }

    static func write(_ states: [String: String]) {
        defaults?.set(states, forKey: key)
    }

    static func key(for deployment: Deployment) -> String {
        "\(deployment.providerID):\(deployment.id)"
    }
}
