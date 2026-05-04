import Foundation
import SwiftUI

public protocol DeploymentProvider: AnyObject {
    /// Unique identifier, e.g. "vercel", "cloudflare"
    var id: String { get }

    /// Human-readable name, e.g. "Vercel", "Cloudflare Pages"
    var displayName: String { get }

    /// SF Symbol name for this service
    var iconSymbol: String { get }

    /// Asset catalog image name (SVG icon), if available
    var iconAsset: String? { get }

    /// Brand tint used as the backdrop for this provider's icon badge.
    var color: Color { get }

    /// Whether the provider has valid credentials configured
    var isConfigured: Bool { get }

    /// Fetch the latest deployments/builds from this service.
    ///
    /// Top-level `throws` covers whole-provider failures (bad credentials,
    /// network down). For multi-entry providers, per-entry failures travel
    /// inside `DeploymentFetchResult.itemErrors` so one bad entry doesn't
    /// kill the rest of the batch.
    func fetchDeployments() async throws -> DeploymentFetchResult

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
    public var docsURL: URL? { nil }
    public var iconAsset: String? { nil }
    public var dashboardURL: URL? { nil }
    public var color: Color { .blue }
}
