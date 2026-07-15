import Foundation

public enum AIErrorHandoffCLI: String, CaseIterable, Sendable {
    case codex
    case claude

    public var displayName: String {
        switch self {
        case .codex: return "Codex"
        case .claude: return "Claude"
        }
    }

    public var executableName: String { rawValue }
}

public struct AIErrorHandoffField: Sendable, Equatable {
    public let key: String
    public let label: String
    public let isSecret: Bool
    public let isPresent: Bool
    public let isMultiValue: Bool
    public let kind: String

    public init(
        key: String,
        label: String,
        isSecret: Bool,
        isPresent: Bool,
        isMultiValue: Bool,
        kind: String
    ) {
        self.key = key
        self.label = label
        self.isSecret = isSecret
        self.isPresent = isPresent
        self.isMultiValue = isMultiValue
        self.kind = kind
    }
}

public struct AIErrorHandoffContext: Sendable, Equatable {
    public let providerID: String
    public let providerName: String
    public let isConfigured: Bool
    public let providerError: String?
    public let testFailure: String?
    public let itemErrors: [String: String]
    public let fields: [AIErrorHandoffField]
    public let generatedAt: Date
    public let appVersion: String?
    public let osVersion: String

    public init(
        providerID: String,
        providerName: String,
        isConfigured: Bool,
        providerError: String? = nil,
        testFailure: String? = nil,
        itemErrors: [String: String] = [:],
        fields: [AIErrorHandoffField] = [],
        generatedAt: Date = Date(),
        appVersion: String? = nil,
        osVersion: String = ProcessInfo.processInfo.operatingSystemVersionString
    ) {
        self.providerID = providerID
        self.providerName = providerName
        self.isConfigured = isConfigured
        self.providerError = providerError.nilIfBlank
        self.testFailure = testFailure.nilIfBlank
        self.itemErrors = itemErrors.filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        self.fields = fields
        self.generatedAt = generatedAt
        self.appVersion = appVersion.nilIfBlank
        self.osVersion = osVersion
    }
}

/// Everything the deployment-failure prompt needs, bundled so the builder is
/// a pure function (and therefore trivially testable). Distinct from
/// `AIErrorHandoffContext`, which describes provider *configuration* errors —
/// this one describes a single failed build/deploy.
public struct DeploymentErrorHandoffContext: Sendable {
    public let deployment: Deployment
    public let providerName: String
    public let details: DeploymentFailureDetails?
    public let generatedAt: Date
    public let appVersion: String?

    public init(
        deployment: Deployment,
        providerName: String,
        details: DeploymentFailureDetails? = nil,
        generatedAt: Date = Date(),
        appVersion: String? = nil
    ) {
        self.deployment = deployment
        self.providerName = providerName
        self.details = details
        self.generatedAt = generatedAt
        self.appVersion = appVersion
    }
}

public enum AIErrorHandoff {
    /// Prompt for handing a failed deployment to a coding agent (Claude Code,
    /// Codex, …). Unlike `prompt(for:)` this never returns nil — even with no
    /// fetched details the deployment metadata alone is a useful handoff.
    public static func deploymentPrompt(for context: DeploymentErrorHandoffContext) -> String {
        let deployment = context.deployment
        var lines: [String] = []

        lines.append("You are an AI coding agent. A deployment/CI build failed; help diagnose and fix it.")
        lines.append("")
        lines.append("Deployment:")
        lines.append("- Provider: \(context.providerName) (\(deployment.providerID))")
        lines.append("- Project: \(deployment.projectName)")
        if let repository = deployment.repository, !repository.isEmpty {
            lines.append("- Repository: \(repository)")
        }
        if let branch = deployment.branch, !branch.isEmpty {
            lines.append("- Branch: \(branch)")
        }
        if let commit = deployment.commitMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
           !commit.isEmpty {
            // Keep the prompt single-line-per-fact; a multi-line commit body
            // would visually bleed into the next bullet.
            let firstLine = commit.split(separator: "\n", omittingEmptySubsequences: true)
                .first.map(String.init) ?? commit
            lines.append("- Commit: \(firstLine)")
        }
        lines.append("- Status: \(deployment.status.displayName)")
        lines.append("- Started: \(SharedFormatters.iso8601Internet.string(from: deployment.createdAt))")
        if let url = deployment.url {
            lines.append("- Build page: \(url.absoluteString)")
        }
        if let logsURL = context.details?.logsURL {
            lines.append("- Full logs: \(logsURL.absoluteString)")
        }
        if let appVersion = context.appVersion {
            lines.append("- Reported by: StackLight \(appVersion) at \(SharedFormatters.iso8601Internet.string(from: context.generatedAt))")
        }
        lines.append("")

        if let summary = context.details?.summary {
            lines.append("Failure summary:")
            lines.append(summary)
            lines.append("")
        }

        if let issues = context.details?.issues, !issues.isEmpty {
            lines.append("Reported issues:")
            for issue in issues {
                var line = "- [\(issue.severity.rawValue)] \(issue.message)"
                if let source = issue.source, !source.isEmpty {
                    line += " (\(source))"
                }
                lines.append(line)
            }
            lines.append("")
        }

        if let excerpt = context.details?.logExcerpt {
            let marker = context.details?.logExcerptTruncated == true
                ? " (tail — earlier lines truncated)"
                : ""
            lines.append("Build log excerpt\(marker):")
            lines.append("```")
            lines.append(excerpt)
            lines.append("```")
            lines.append("")
        }

        if context.details == nil || context.details?.isEmpty == true {
            lines.append("No detailed error output was available from the provider's API — reason it out from the metadata above, and open the build page for the full log if needed.")
            lines.append("")
        }

        lines.append("Please:")
        lines.append("1. Identify the most likely root cause from the output above.")
        lines.append("2. If it's a code problem, point to the file/config to change and propose the minimal fix.")
        lines.append("3. If it's infrastructure-side (quota, credentials, provider outage, flaky step), say so and give the exact remediation or retry steps instead.")
        lines.append("")
        lines.append("Notes: the log excerpt may be truncated to the final lines; do not ask for API tokens or other secrets.")

        return lines.joined(separator: "\n")
    }

    public static func prompt(for context: AIErrorHandoffContext) -> String? {
        guard context.providerError != nil || context.testFailure != nil || !context.itemErrors.isEmpty else {
            return nil
        }

        var lines: [String] = []
        lines.append("You are helping debug a StackLight provider integration error.")
        lines.append("")
        lines.append("Goal: identify the likely cause and give concrete, minimal steps to fix the provider configuration or upstream API issue.")
        lines.append("")
        lines.append("Provider:")
        lines.append("- Name: \(context.providerName)")
        lines.append("- ID: \(context.providerID)")
        lines.append("- Configured: \(context.isConfigured ? "yes" : "no")")
        if let appVersion = context.appVersion {
            lines.append("- App: StackLight \(appVersion)")
        }
        lines.append("- OS: \(context.osVersion)")
        lines.append("- Generated at: \(SharedFormatters.iso8601Internet.string(from: context.generatedAt))")
        lines.append("")

        if let providerError = context.providerError {
            lines.append("Current provider error:")
            lines.append(providerError)
            lines.append("")
        }

        if let testFailure = context.testFailure {
            lines.append("Latest Test failure:")
            lines.append(testFailure)
            lines.append("")
        }

        if !context.itemErrors.isEmpty {
            lines.append("Latest partial item errors:")
            for key in context.itemErrors.keys.sorted() {
                if let value = context.itemErrors[key] {
                    lines.append("- \(key): \(value)")
                }
            }
            lines.append("")
        }

        if !context.fields.isEmpty {
            lines.append("Configuration field status (values redacted):")
            for field in context.fields.sorted(by: { $0.key < $1.key }) {
                let valueState = field.isPresent ? "present" : "missing"
                let secrecy = field.isSecret ? "secret" : "non-secret"
                let multi = field.isMultiValue ? ", multi-value" : ""
                lines.append("- \(field.label) (`\(field.key)`): \(valueState), \(secrecy), \(field.kind)\(multi)")
            }
            lines.append("")
        }

        lines.append("Useful local diagnostic command:")
        lines.append("```sh")
        lines.append("stacklight test \(shellQuoted(context.providerID)) --json")
        lines.append("```")
        lines.append("")
        lines.append("Privacy constraints:")
        lines.append("- Do not ask for API tokens, secrets, or raw credential values.")
        lines.append("- If credentials are relevant, ask the user to verify scopes, expiration, account/team selection, and whether the field is present.")
        lines.append("- Prefer explanations that distinguish bad credentials, missing project/repo/app IDs, permission scope, rate limits, upstream outage, and response-shape changes.")
        lines.append("")
        lines.append("Please provide a short diagnosis, the most likely fixes in order, and any follow-up command the user should run.")

        return lines.joined(separator: "\n")
    }

    public static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
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
