import ArgumentParser
import Foundation
import StackLightCore

struct AIPromptCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ai-prompt",
        abstract: "Print a redacted AI handoff prompt for one provider."
    )

    @Argument(help: "Provider ID (e.g. vercel, cloudflare, githubActions).")
    var providerID: String

    @Option(help: "Current top-level provider error to include.")
    var error: String?

    @Option(help: "Latest Test failure to include.")
    var testFailure: String?

    func run() async throws {
        guard let provider = CLIContext.provider(named: providerID) else {
            exitWithError("unknown provider '\(providerID)'. Try `stacklight providers list`.")
        }

        guard let prompt = AIErrorHandoff.prompt(for: AIErrorHandoffContext(
            providerID: provider.id,
            providerName: provider.displayName,
            isConfigured: provider.isConfigured,
            providerError: error,
            testFailure: testFailure,
            fields: provider.settingsFields().map { fieldRecord(for: $0) }
        )) else {
            exitWithError("no error context supplied. Pass --error or --test-failure.")
        }

        print(prompt)
    }

    private func fieldRecord(for field: SettingsField) -> AIErrorHandoffField {
        AIErrorHandoffField(
            key: field.key,
            label: field.label,
            isSecret: field.isSecret,
            isPresent: isFieldPresent(field),
            isMultiValue: field.isMultiValue,
            kind: kindName(for: field)
        )
    }

    private func isFieldPresent(_ field: SettingsField) -> Bool {
        let raw: String?
        if field.isSecret {
            raw = KeychainManager.read(key: field.key)
        } else if field.isToggle {
            raw = AppConfig.bool(forKey: field.key) ? "1" : ""
        } else {
            raw = AppConfig.string(forKey: field.key)
        }
        return !(raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func kindName(for field: SettingsField) -> String {
        switch field.kind {
        case .text: return "text"
        case .toggle: return "toggle"
        case .branchPicker: return "branch picker"
        }
    }
}
