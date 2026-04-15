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

    /// URL to the documentation page for obtaining credentials
    var docsURL: URL? { get }

    /// URL to the provider's web dashboard, shown in the menu bar header as a
    /// quick-jump link. May depend on user configuration (team, repo, app ID),
    /// so implementations can return different URLs based on current settings.
    /// Return `nil` to hide the jump-to-dashboard affordance.
    var dashboardURL: URL? { get }
}

extension DeploymentProvider {
    var docsURL: URL? { nil }
    var dashboardURL: URL? { nil }
}
