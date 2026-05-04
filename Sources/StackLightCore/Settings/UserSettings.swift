import Foundation

/// Aggregated user preferences serialized as a single envelope into
/// UserDefaults. Mirrors RepoBar's `UserSettings` — versioned envelope
/// pattern so we can migrate forward without breaking existing installs.
///
/// Two distinct stores are layered today:
///   1. Per-key UserDefaults (`pollInterval`, `notificationsEnabled`, every
///      provider field) — historical, preserved as-is.
///   2. The envelope below — pinned/hidden lists and any new structured
///      settings that benefit from versioning.
public struct UserSettings: Equatable, Codable, Sendable {
    public var pinnedItems: Set<String>
    public var hiddenItems: Set<String>
    /// Provider IDs the user wants completely off. Empty = show everything
    /// configured. Distinct from `hiddenItems` (which is item-level).
    public var hiddenProviders: Set<String>

    public init(
        pinnedItems: Set<String> = [],
        hiddenItems: Set<String> = [],
        hiddenProviders: Set<String> = []
    ) {
        self.pinnedItems = pinnedItems
        self.hiddenItems = hiddenItems
        self.hiddenProviders = hiddenProviders
    }

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
