import Foundation

/// Single source of truth for every user-visible setting in StackLight.
/// Persisted as a versioned envelope (`SettingsEnvelope`) into a single
/// UserDefaults key so we can migrate the schema without per-key chaos.
///
/// Three buckets:
///   1. Application-level fields (poll interval, notifications, diagnostics …)
///      have typed properties so call sites get autocomplete + type safety.
///   2. Per-deployment visibility (pinned / hidden) via `pinnedItems` etc.
///   3. Free-form provider configuration (`providerStrings` / `providerBools`
///      / `providerStringArrays`) so adding a new SettingsField doesn't
///      require a schema change. Provider call sites read these via
///      `string(for:)` / `bool(for:)` / `stringArray(for:)`.
public struct UserSettings: Equatable, Codable, Sendable {
    // MARK: - Visibility (existing)

    public var pinnedItems: Set<String>
    public var hiddenItems: Set<String>
    public var hiddenProviders: Set<String>

    // MARK: - Application-level

    public var pollIntervalSeconds: Double
    public var notificationsEnabled: Bool
    public var diagnosticsEnabled: Bool
    public var fileLoggingEnabled: Bool
    public var loggingVerbosity: String

    // MARK: - Provider config (free-form)

    public var providerStrings: [String: String]
    public var providerBools: [String: Bool]
    public var providerStringArrays: [String: [String]]

    public init(
        pinnedItems: Set<String> = [],
        hiddenItems: Set<String> = [],
        hiddenProviders: Set<String> = [],
        pollIntervalSeconds: Double = 60,
        notificationsEnabled: Bool = true,
        diagnosticsEnabled: Bool = false,
        fileLoggingEnabled: Bool = false,
        loggingVerbosity: String = "info",
        providerStrings: [String: String] = [:],
        providerBools: [String: Bool] = [:],
        providerStringArrays: [String: [String]] = [:]
    ) {
        self.pinnedItems = pinnedItems
        self.hiddenItems = hiddenItems
        self.hiddenProviders = hiddenProviders
        self.pollIntervalSeconds = pollIntervalSeconds
        self.notificationsEnabled = notificationsEnabled
        self.diagnosticsEnabled = diagnosticsEnabled
        self.fileLoggingEnabled = fileLoggingEnabled
        self.loggingVerbosity = loggingVerbosity
        self.providerStrings = providerStrings
        self.providerBools = providerBools
        self.providerStringArrays = providerStringArrays
    }

    // MARK: - Custom decoding so older envelopes stay readable.
    // Each `decodeIfPresent` falls back to the same default as `init(...)`,
    // so a v1 envelope (only had pinned/hidden) decodes cleanly into v2.

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            pinnedItems: try c.decodeIfPresent(Set<String>.self, forKey: .pinnedItems) ?? [],
            hiddenItems: try c.decodeIfPresent(Set<String>.self, forKey: .hiddenItems) ?? [],
            hiddenProviders: try c.decodeIfPresent(Set<String>.self, forKey: .hiddenProviders) ?? [],
            pollIntervalSeconds: try c.decodeIfPresent(Double.self, forKey: .pollIntervalSeconds) ?? 60,
            notificationsEnabled: try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true,
            diagnosticsEnabled: try c.decodeIfPresent(Bool.self, forKey: .diagnosticsEnabled) ?? false,
            fileLoggingEnabled: try c.decodeIfPresent(Bool.self, forKey: .fileLoggingEnabled) ?? false,
            loggingVerbosity: try c.decodeIfPresent(String.self, forKey: .loggingVerbosity) ?? "info",
            providerStrings: try c.decodeIfPresent([String: String].self, forKey: .providerStrings) ?? [:],
            providerBools: try c.decodeIfPresent([String: Bool].self, forKey: .providerBools) ?? [:],
            providerStringArrays: try c.decodeIfPresent([String: [String]].self, forKey: .providerStringArrays) ?? [:]
        )
    }

    // MARK: - Visibility helpers

    public func visibility(for key: DeploymentKey) -> ItemVisibility {
        if pinnedItems.contains(key.rawValue) { return .pinned }
        if hiddenItems.contains(key.rawValue) { return .hidden }
        return .visible
    }

    public mutating func setVisibility(_ visibility: ItemVisibility, for key: DeploymentKey) {
        let raw = key.rawValue
        pinnedItems.remove(raw)
        hiddenItems.remove(raw)
        switch visibility {
        case .pinned: pinnedItems.insert(raw)
        case .hidden: hiddenItems.insert(raw)
        case .visible: break
        }
    }

    // MARK: - Provider config helpers

    public func string(for key: String) -> String? {
        providerStrings[key]
    }

    public mutating func setString(_ value: String?, for key: String) {
        if let value, !value.isEmpty {
            providerStrings[key] = value
        } else {
            providerStrings.removeValue(forKey: key)
        }
    }

    public func bool(for key: String) -> Bool {
        providerBools[key] ?? false
    }

    public mutating func setBool(_ value: Bool, for key: String) {
        providerBools[key] = value
    }

    public func stringArray(for key: String) -> [String] {
        providerStringArrays[key] ?? []
    }

    public mutating func setStringArray(_ value: [String]?, for key: String) {
        if let value, !value.isEmpty {
            providerStringArrays[key] = value
        } else {
            providerStringArrays.removeValue(forKey: key)
        }
    }
}

public enum ItemVisibility: String, CaseIterable, Codable, Sendable {
    case visible
    case pinned
    case hidden

    public var displayName: String {
        switch self {
        case .visible: return "Visible"
        case .pinned: return "Pinned"
        case .hidden: return "Hidden"
        }
    }

    public var systemImage: String {
        switch self {
        case .visible: return "eye"
        case .pinned: return "pin.fill"
        case .hidden: return "eye.slash"
        }
    }
}
