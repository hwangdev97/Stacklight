import Foundation

protocol DeploymentProvider: AnyObject {
    /// Unique identifier, e.g. "vercel", "cloudflare"
    var id: String { get }

    /// Human-readable name, e.g. "Vercel", "Cloudflare Pages"
    var displayName: String { get }

    /// SF Symbol name for this service
    var iconSymbol: String { get }

    /// Asset catalog image name (SVG icon), if available
    var iconAsset: String? { get }

    /// Whether the provider has valid credentials configured
    var isConfigured: Bool { get }

    /// Fetch the latest deployments/builds from this service
    func fetchDeployments() async throws -> [Deployment]

    /// Declarative list of settings fields this provider needs
    func settingsFields() -> [SettingsField]

    /// URL to the documentation page for obtaining credentials
    var docsURL: URL? { get }
}

extension DeploymentProvider {
    var docsURL: URL? { nil }
    var iconAsset: String? { nil }
}
