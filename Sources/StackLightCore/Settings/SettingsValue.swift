import SwiftUI

/// Property wrapper for SwiftUI views that want to bind a single
/// `UserSettings` field. Replaces the previous `@AppStorage("X")` pattern —
/// reads and writes go through `SettingsStore.shared`, so changes surface in
/// every observer (menu, widget, CLI) instead of just `UserDefaults`.
///
/// Usage:
/// ```swift
/// @SettingsValue(\.pollIntervalSeconds) var pollInterval: Double
/// @SettingsValue(\.notificationsEnabled) var notifications: Bool
/// ```
@propertyWrapper
public struct SettingsValue<Value: Equatable>: DynamicProperty {
    @ObservedObject private var store = SettingsStore.shared
    private let keyPath: WritableKeyPath<UserSettings, Value>

    public init(_ keyPath: WritableKeyPath<UserSettings, Value>) {
        self.keyPath = keyPath
    }

    public var wrappedValue: Value {
        get { store.settings[keyPath: keyPath] }
        nonmutating set {
            store.mutate { $0[keyPath: keyPath] = newValue }
        }
    }

    public var projectedValue: Binding<Value> {
        Binding(
            get: { store.settings[keyPath: keyPath] },
            set: { newValue in
                store.mutate { $0[keyPath: keyPath] = newValue }
            }
        )
    }
}

/// Free-form provider-key-backed equivalent. Used for fields whose name
/// isn't known at compile time (e.g. dynamically rendered SettingsField).
///
/// Three flavors map onto the three storage buckets in `UserSettings`.
@propertyWrapper
public struct SettingsString: DynamicProperty {
    @ObservedObject private var store = SettingsStore.shared
    private let key: String
    private let defaultValue: String

    public init(_ key: String, fallback defaultValue: String = "") {
        self.key = key
        self.defaultValue = defaultValue
    }

    public var wrappedValue: String {
        get { store.string(for: key) ?? defaultValue }
        nonmutating set { store.setString(newValue, for: key) }
    }

    public var projectedValue: Binding<String> {
        Binding(
            get: { store.string(for: key) ?? defaultValue },
            set: { store.setString($0, for: key) }
        )
    }
}

@propertyWrapper
public struct SettingsBool: DynamicProperty {
    @ObservedObject private var store = SettingsStore.shared
    private let key: String

    public init(_ key: String) {
        self.key = key
    }

    public var wrappedValue: Bool {
        get { store.bool(for: key) }
        nonmutating set { store.setBool(newValue, for: key) }
    }

    public var projectedValue: Binding<Bool> {
        Binding(
            get: { store.bool(for: key) },
            set: { store.setBool($0, for: key) }
        )
    }
}
