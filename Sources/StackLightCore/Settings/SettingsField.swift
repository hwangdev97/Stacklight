import Foundation

public struct SettingsField: Identifiable {
    public enum Kind {
        case text
        case toggle
        /// Dropdown whose options include "All", "main", any branches cached at
        /// `branchesKey`, and a "Custom…" escape that reveals a free-form input.
        case branchPicker(branchesKey: String)
    }

    public let key: String
    public let label: String
    public let isSecret: Bool
    public let placeholder: String
    public let isMultiValue: Bool
    public let hint: String?
    public let kind: Kind

    public var id: String { key }

    public init(
        key: String,
        label: String,
        isSecret: Bool = false,
        placeholder: String = "",
        isMultiValue: Bool = false,
        hint: String? = nil,
        kind: Kind = .text
    ) {
        self.key = key
        self.label = label
        self.isSecret = isSecret
        self.placeholder = placeholder
        self.isMultiValue = isMultiValue
        self.hint = hint
        self.kind = kind
    }
}

extension SettingsField {
    public var isToggle: Bool {
        if case .toggle = kind { return true }
        return false
    }

    public var isBranchPicker: Bool {
        if case .branchPicker = kind { return true }
        return false
    }

    public var isPlainText: Bool {
        if case .text = kind { return true }
        return false
    }
}
