import Foundation

final class ServiceRegistry {
    static let shared = ServiceRegistry()

    private(set) var providers: [DeploymentProvider] = []

    private init() {}

    func register(_ provider: DeploymentProvider) {
        providers.append(provider)
    }

    var configuredProviders: [DeploymentProvider] {
        providers.filter { $0.isConfigured }
    }

    func provider(withID id: String) -> DeploymentProvider? {
        providers.first { $0.id == id }
    }

    func registerBuiltInProviders() {
        register(VercelProvider())
        register(CloudflareProvider())
        register(GitHubActionsProvider())
        register(NetlifyProvider())
        register(RailwayProvider())
        register(FlyioProvider())
        register(XcodeCloudProvider())
        register(TestFlightProvider())
    }
}
