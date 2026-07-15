import SwiftUI
import StackLightCore

/// UI-facing cache of failure-details fetches, keyed per deployment. The
/// hover card observes this; context-menu copy actions use the async
/// accessors. Actual fetching/caching is `FailureDetailsService` in Core —
/// this store only adapts it into `@Published` state for SwiftUI.
@MainActor
final class FailureDetailsStore: ObservableObject {
    static let shared = FailureDetailsStore()

    enum LoadState: Equatable {
        case loading
        case loaded(DeploymentFailureDetails)
        /// The provider has no failure-details API (TestFlight, Fly.io, …).
        /// The card still renders metadata and copy actions in this state.
        case unsupported
        case failed(String)
    }

    @Published private(set) var states: [String: LoadState] = [:]

    private var tasks: [String: Task<Void, Never>] = [:]

    static func key(for deployment: Deployment) -> String {
        "\(deployment.providerID)|\(deployment.id)"
    }

    func state(for deployment: Deployment) -> LoadState? {
        states[Self.key(for: deployment)]
    }

    func providerDisplayName(for deployment: Deployment) -> String {
        ServiceRegistry.shared.provider(withID: deployment.providerID)?.displayName
            ?? deployment.providerID
    }

    /// Kick off a fetch unless one is running or already succeeded. A prior
    /// `.failed` state retries — hover-away-and-back is the natural retry
    /// gesture for a transient network error.
    func load(_ deployment: Deployment) {
        let key = Self.key(for: deployment)
        switch states[key] {
        case .loading, .loaded, .unsupported:
            return
        case .failed, nil:
            break
        }
        guard tasks[key] == nil else { return }

        guard let provider = ServiceRegistry.shared.provider(withID: deployment.providerID),
              let source = provider.failureDetailsSource else {
            states[key] = .unsupported
            return
        }

        states[key] = .loading
        tasks[key] = Task { [weak self] in
            do {
                let details = try await FailureDetailsService.shared.details(for: deployment, from: source)
                self?.states[key] = .loaded(details)
            } catch is CancellationError {
                self?.states[key] = nil
            } catch {
                let message = (error as? ProviderError)?.userFacingMessage ?? error.localizedDescription
                self?.states[key] = .failed(message)
            }
            self?.tasks[key] = nil
        }
    }

    /// Fetch-if-needed accessor for copy actions. Returns nil when the
    /// provider can't supply details or the fetch fails — callers fall back
    /// to a metadata-only payload.
    func details(for deployment: Deployment) async -> DeploymentFailureDetails? {
        guard let provider = ServiceRegistry.shared.provider(withID: deployment.providerID),
              let source = provider.failureDetailsSource else {
            return nil
        }
        if case .loaded(let details) = state(for: deployment) {
            return details
        }
        let details = try? await FailureDetailsService.shared.details(for: deployment, from: source)
        if let details {
            states[Self.key(for: deployment)] = .loaded(details)
        }
        return details
    }

    // MARK: - Copy payloads

    /// The full agent handoff prompt (metadata + fetched details).
    func agentPrompt(for deployment: Deployment) async -> String {
        let details = await details(for: deployment)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return AIErrorHandoff.deploymentPrompt(for: DeploymentErrorHandoffContext(
            deployment: deployment,
            providerName: providerDisplayName(for: deployment),
            details: details,
            appVersion: version
        ))
    }

    /// Compact human-readable error text (for pasting into an issue/chat
    /// rather than an agent).
    func plainErrorText(for deployment: Deployment) async -> String {
        let details = await details(for: deployment)
        var lines: [String] = []
        lines.append("\(deployment.projectName) — \(providerDisplayName(for: deployment)) \(deployment.status.displayName.lowercased())")
        var meta: [String] = []
        if let branch = deployment.branch, !branch.isEmpty { meta.append("branch \(branch)") }
        if let commit = deployment.commitMessage?.split(separator: "\n").first { meta.append("“\(commit)”") }
        if !meta.isEmpty { lines.append(meta.joined(separator: " · ")) }
        if let summary = details?.summary {
            lines.append("")
            lines.append(summary)
        }
        if let issues = details?.issues, !issues.isEmpty {
            lines.append("")
            for issue in issues {
                lines.append("- [\(issue.severity.rawValue)] \(issue.message)"
                    + (issue.source.map { " (\($0))" } ?? ""))
            }
        }
        if let excerpt = details?.logExcerpt {
            lines.append("")
            lines.append("Log tail:")
            lines.append(excerpt)
        }
        if let url = details?.logsURL ?? deployment.url {
            lines.append("")
            lines.append(url.absoluteString)
        }
        return lines.joined(separator: "\n")
    }
}
