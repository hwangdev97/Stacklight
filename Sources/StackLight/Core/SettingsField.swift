import Foundation

struct SettingsField: Identifiable {
    enum Kind {
        case text
        case toggle
        /// Dropdown whose options include "All", "main", any branches cached at
        /// `branchesKey`, and a "Custom…" escape that reveals a free-form input.
        case branchPicker(branchesKey: String)
    }

    let key: String
    let label: String
    let isSecret: Bool
    let placeholder: String
    let isMultiValue: Bool
    let hint: String?
    let kind: Kind

    var id: String { key }

    init(
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
    var isToggle: Bool {
        if case .toggle = kind { return true }
        return false
    }

    var isBranchPicker: Bool {
        if case .branchPicker = kind { return true }
        return false
    }

    var isPlainText: Bool {
        if case .text = kind { return true }
        return false
    }
}
