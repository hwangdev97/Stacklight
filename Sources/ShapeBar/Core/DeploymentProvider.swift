import Foundation

protocol DeploymentProvider: AnyObject {
    /// Unique identifier, e.g. "vercel", "cloudflare"
    var id: String { get }

    /// Human-readable name, e.g. "Vercel", "Cloudflare Pages"
    var displayName: String { get }

    /// SF Symbol name for this service
    var iconSymbol: String { get }

    /// Whether the provider has valid credentials configured
    var isConfigured: Bool { get }

    /// Fetch the latest deployments/builds from this service
    func fetchDeployments() async throws -> [Deployment]

    /// Declarative list of settings fields this provider needs
    func settingsFields() -> [SettingsField]
}
