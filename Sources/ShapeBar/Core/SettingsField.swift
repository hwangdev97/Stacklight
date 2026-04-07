import Foundation

struct SettingsField: Identifiable {
    let key: String
    let label: String
    let isSecret: Bool
    let placeholder: String
    let isMultiValue: Bool

    var id: String { key }

    init(key: String, label: String, isSecret: Bool = false, placeholder: String = "", isMultiValue: Bool = false) {
        self.key = key
        self.label = label
        self.isSecret = isSecret
        self.placeholder = placeholder
        self.isMultiValue = isMultiValue
    }
}
