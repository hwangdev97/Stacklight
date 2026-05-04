import Foundation

public final class ServiceRegistry {
    public static let shared = ServiceRegistry()

    public private(set) var providers: [DeploymentProvider] = []

    private init() {
        registerBuiltInProviders()
    }

    public func register(_ provider: DeploymentProvider) {
        providers.append(provider)
    }

    public var configuredProviders: [DeploymentProvider] {
        providers.filter { $0.isConfigured }
    }

    public func provider(withID id: String) -> DeploymentProvider? {
        providers.first { $0.id == id }
    }

    public func registerBuiltInProviders() {
        guard providers.isEmpty else { return }
        register(VercelProvider())
        register(CloudflareProvider())
        register(GitHubActionsProvider())
        register(GitHubPRProvider())
        register(NetlifyProvider())
        register(RailwayProvider())
        register(FlyioProvider())
        register(XcodeCloudProvider())
        register(TestFlightProvider())
    }
}
