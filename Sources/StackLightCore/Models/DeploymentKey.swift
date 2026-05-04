import Foundation

/// Stable identifier for a deployment / project that survives app restarts and
/// API changes. Encoded as `"providerID:itemID"` so it round-trips through
/// JSON / UserDefaults without bespoke coding.
///
/// `itemID` is provider-specific:
/// - Vercel / Netlify / Fly.io: the deployment UID
/// - Cloudflare: `<projectName>` (deployments cycle, projects don't)
/// - GitHub Actions: `<owner>/<repo>:<runID>` — but for pinning we usually
///   want the repo, so the helper `init(provider:projectKey:)` exists too
/// - GitHub PRs: `<owner>/<repo>#<prNumber>`
/// - TestFlight / Xcode Cloud: `<appID>` / `<productID>`
public struct DeploymentKey: Hashable, Codable, Sendable {
    public let providerID: String
    public let itemID: String

    public init(providerID: String, itemID: String) {
        self.providerID = providerID
        self.itemID = itemID
    }

    /// Parses `"providerID:itemID"`. Returns `nil` if the format doesn't match.
    public init?(rawValue: String) {
        guard let separator = rawValue.firstIndex(of: ":") else { return nil }
        let provider = String(rawValue[..<separator])
        let itemID = String(rawValue[rawValue.index(after: separator)...])
        guard !provider.isEmpty, !itemID.isEmpty else { return nil }
        self.providerID = provider
        self.itemID = itemID
    }

    public var rawValue: String {
        "\(providerID):\(itemID)"
    }
}

extension Deployment {
    /// Stable key for pin / hide / notification dedupe — uses the deployment
    /// id, which is the closest thing each provider exposes to a stable
    /// identifier. For a "pin the project" UX, callers should use
    /// `DeploymentKey(providerID:itemID:)` with `projectName` instead.
    public var key: DeploymentKey {
        DeploymentKey(providerID: providerID, itemID: id)
    }

    /// Project-level key: pinning a project should keep working even when
    /// individual deployments under it cycle through.
    public var projectKey: DeploymentKey {
        DeploymentKey(providerID: providerID, itemID: projectName)
    }
}
