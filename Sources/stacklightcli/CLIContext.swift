import Foundation
import StackLightCore

/// Bootstrap shared between every command. Reuses the exact Core paths the
/// GUI uses so a `stacklight deployments` invocation hits the same providers,
/// cache, and rate-limit logic that the menu does.
enum CLIContext {
    static func providers() -> [DeploymentProvider] {
        ServiceRegistry.shared.providers
    }

    static func configuredProviders() -> [DeploymentProvider] {
        ServiceRegistry.shared.configuredProviders
    }

    static func provider(named id: String) -> DeploymentProvider? {
        ServiceRegistry.shared.provider(withID: id)
    }

    /// Encodable record used by `providers status` and `providers list`.
    struct ProviderRecord: Encodable {
        let id: String
        let displayName: String
        let configured: Bool
        let dashboardURL: String?
    }

    static func providerRecords() -> [ProviderRecord] {
        providers().map { provider in
            ProviderRecord(
                id: provider.id,
                displayName: provider.displayName,
                configured: provider.isConfigured,
                dashboardURL: provider.dashboardURL?.absoluteString
            )
        }
    }
}

/// Encodable wrapper for `Deployment` so the CLI can spit JSON without
/// dragging the AppKit/SwiftUI side of `Deployment` (it's already Codable in
/// Core).
struct DeploymentRecord: Encodable {
    let id: String
    let providerID: String
    let projectName: String
    let repository: String?
    let status: String
    let url: String?
    let createdAt: Date
    let commitMessage: String?
    let branch: String?

    init(_ deployment: Deployment) {
        self.id = deployment.id
        self.providerID = deployment.providerID
        self.projectName = deployment.projectName
        self.repository = deployment.repository
        self.status = deployment.status.rawValue
        self.url = deployment.url?.absoluteString
        self.createdAt = deployment.createdAt
        self.commitMessage = deployment.commitMessage
        self.branch = deployment.branch
    }
}
