import Foundation

/// Settings facade. Almost every read/write goes through `SettingsStore.shared`
/// — this enum exists for two reasons:
///
/// 1. Provider call sites (and a few iOS / Watch / Widgets call sites) used
///    to do `AppConfig.defaults.string(forKey:)`. The new mechanical form is
///    `AppConfig.string(forKey:)`, which delegates to SettingsStore. Same
///    signature, same call site shape, but the data lives in the envelope.
///
/// 2. `legacyDefaults` is the raw `UserDefaults` instance that historically
///    held everything. It's kept around because (a) `SettingsStore` itself
///    persists its envelope here, and (b) exactly one external touchpoint —
///    the App Group migration — still needs the bare UserDefaults handle.
public enum AppConfig {
    public static let appGroupSuite = SharedStore.suiteName

    /// Underlying UserDefaults that backs the envelope. iOS uses the App
    /// Group suite so the widget extension shares state; macOS falls back to
    /// `.standard`.
    ///
    /// **Avoid using this directly from new code.** Reach for
    /// `SettingsStore.shared` (or these static forwarders) instead so every
    /// write hits the envelope and triggers `objectWillChange`.
    public static var legacyDefaults: UserDefaults {
        #if os(iOS) || os(watchOS)
        return UserDefaults(suiteName: appGroupSuite) ?? .standard
        #else
        return .standard
        #endif
    }

    /// Backwards-compatible alias used by a couple of stragglers (e.g. tests).
    /// New code should not introduce more callers.
    public static var defaults: UserDefaults { legacyDefaults }

    // MARK: - Static forwarders to SettingsStore

    public static func string(forKey key: String) -> String? {
        SettingsStore.shared.string(for: key)
    }

    public static func bool(forKey key: String) -> Bool {
        SettingsStore.shared.bool(for: key)
    }

    public static func stringArray(forKey key: String) -> [String] {
        SettingsStore.shared.stringArray(for: key)
    }

    public static func setValue(_ value: String?, forKey key: String) {
        SettingsStore.shared.setString(value, for: key)
    }

    public static func setValue(_ value: Bool, forKey key: String) {
        SettingsStore.shared.setBool(value, for: key)
    }

    public static func setValue(_ value: [String]?, forKey key: String) {
        SettingsStore.shared.setStringArray(value, for: key)
    }

    public static func removeValue(forKey key: String) {
        SettingsStore.shared.removeValue(for: key)
    }

    // MARK: - Migration helper

    /// One-shot UserDefaults rename. If `newKey` is empty (or missing) and
    /// `oldKey` has a value, copy it over and remove the old entry. Idempotent
    /// — safe to call from every provider `init()` on every app launch.
    ///
    /// Now operates on `SettingsStore` rather than raw UserDefaults. Provider
    /// `init()`s call this to migrate single→multi keys without per-provider
    /// special casing.
    public static func migrateSingleToMulti(oldKey: String, newKey: String) {
        let store = SettingsStore.shared
        let existing = (store.string(for: newKey) ?? "").trimmingCharacters(in: .whitespaces)
        guard existing.isEmpty else { return }
        let legacy = (store.string(for: oldKey) ?? "").trimmingCharacters(in: .whitespaces)
        guard !legacy.isEmpty else { return }
        store.setString(legacy, for: newKey)
        store.removeValue(for: oldKey)
    }
}
