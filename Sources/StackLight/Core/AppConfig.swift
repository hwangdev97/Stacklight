import Foundation

/// Cross-process `UserDefaults` accessor. On iOS the host app and the widget
/// extension share the `group.app.yellowplus.StackLight` App Group, so both
/// processes see the same provider settings. On macOS the App Group isn't
/// configured; we fall back to `.standard`, which preserves existing behavior
/// for the menu-bar app.
enum AppConfig {
    static let appGroupSuite = SharedStore.suiteName

    static var defaults: UserDefaults {
        #if os(iOS)
        return UserDefaults(suiteName: appGroupSuite) ?? .standard
        #else
        return .standard
        #endif
    }

    /// One-shot UserDefaults rename. If `newKey` is empty (or missing) and
    /// `oldKey` has a value, copy it over and remove the old entry. Idempotent
    /// — safe to call from every provider `init()` on every app launch.
    static func migrateSingleToMulti(oldKey: String, newKey: String) {
        let existing = (defaults.string(forKey: newKey) ?? "").trimmingCharacters(in: .whitespaces)
        guard existing.isEmpty else { return }
        let legacy = (defaults.string(forKey: oldKey) ?? "").trimmingCharacters(in: .whitespaces)
        guard !legacy.isEmpty else { return }
        defaults.set(legacy, forKey: newKey)
        defaults.removeObject(forKey: oldKey)
    }
}
