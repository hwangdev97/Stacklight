import Foundation

/// A single configurable field, described for an AI assistant that is helping
/// the user set up a provider. Mirrors the shape of `SettingsField` but carries
/// only presentation metadata — never the stored value, so secrets are safe to
/// hand to an external assistant.
public struct ProviderSetupField: Sendable, Equatable {
    public let key: String
    public let label: String
    public let isSecret: Bool
    public let isMultiValue: Bool
    public let isPresent: Bool
    public let kind: String
    public let placeholder: String?
    public let hint: String?

    public init(
        key: String,
        label: String,
        isSecret: Bool,
        isMultiValue: Bool,
        isPresent: Bool,
        kind: String,
        placeholder: String? = nil,
        hint: String? = nil
    ) {
        self.key = key
        self.label = label
        self.isSecret = isSecret
        self.isMultiValue = isMultiValue
        self.isPresent = isPresent
        self.kind = kind
        self.placeholder = placeholder.nilIfBlank
        self.hint = hint.nilIfBlank
    }
}

public struct ProviderSetupContext: Sendable, Equatable {
    public let providerID: String
    public let providerName: String
    public let isConfigured: Bool
    public let docsURL: String?
    public let fields: [ProviderSetupField]

    public init(
        providerID: String,
        providerName: String,
        isConfigured: Bool,
        docsURL: String? = nil,
        fields: [ProviderSetupField] = []
    ) {
        self.providerID = providerID
        self.providerName = providerName
        self.isConfigured = isConfigured
        self.docsURL = docsURL.nilIfBlank
        self.fields = fields
    }
}

/// Builds a copy-paste prompt that turns any AI assistant (Claude, Codex, etc.)
/// into a guided setup helper for a StackLight provider. Unlike
/// `AIErrorHandoff`, this is about *configuring* a provider rather than
/// debugging a failure, so it always returns a prompt.
public enum ProviderSetupPrompt {
    public static func prompt(for context: ProviderSetupContext) -> String {
        var lines: [String] = []

        lines.append("You are helping me configure the \"\(context.providerName)\" provider in StackLight, a macOS menu-bar app that monitors deployments and CI/CD builds.")
        lines.append("")
        lines.append("Goal: walk me through obtaining the credentials this provider needs and the exact value to enter in each field, then remind me to Save and Test.")
        lines.append("")
        lines.append("Provider:")
        lines.append("- Name: \(context.providerName)")
        lines.append("- ID: \(context.providerID)")
        lines.append("- Currently configured: \(context.isConfigured ? "yes" : "no")")
        if let docsURL = context.docsURL {
            lines.append("- Credentials documentation: \(docsURL)")
        }
        lines.append("")

        if context.fields.isEmpty {
            lines.append("This provider has no configurable fields.")
        } else {
            lines.append("Fields I need to fill in (values are entered in StackLight, not here):")
            for field in context.fields {
                let storage = field.isSecret ? "secret, stored in the macOS Keychain" : "non-secret, stored in app preferences"
                let cardinality = field.isMultiValue ? "multi-value (one entry per row)" : "single value"
                let state = field.isPresent ? "currently set" : "currently empty"
                lines.append("- \(field.label) (`\(field.key)`): \(field.kind), \(cardinality), \(storage); \(state)")
                if let placeholder = field.placeholder {
                    lines.append("    Example/format: \(placeholder)")
                }
                if let hint = field.hint {
                    lines.append("    Note: \(hint)")
                }
            }
        }
        lines.append("")

        lines.append("Where I enter these in the app:")
        lines.append("- Open StackLight → Settings → \(context.providerName).")
        lines.append("- Fill in each field above, click Save, then click Test to verify the connection.")
        lines.append("")

        lines.append("Please:")
        lines.append("1. Explain step by step where to find each credential, using the documentation link above when relevant.")
        lines.append("2. Ask me only for the information you actually need; never invent values.")
        lines.append("3. Tell me the precise value to type into each field.")
        lines.append("4. Finish by reminding me to click Save and then Test in StackLight.")
        lines.append("")

        lines.append("Privacy: I enter secrets directly into StackLight, not into this chat. Do not ask me to paste API tokens or private keys here unless I explicitly ask you to help validate one.")

        return lines.joined(separator: "\n")
    }
}

private extension Optional where Wrapped == String {
    var nilIfBlank: String? {
        guard let trimmed = self?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
