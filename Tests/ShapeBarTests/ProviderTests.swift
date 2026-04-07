import XCTest
@testable import ShapeBar

final class ProviderTests: XCTestCase {
    func testServiceRegistryRegistersBuiltInProviders() {
        let registry = ServiceRegistry.shared
        registry.registerBuiltInProviders()
        XCTAssertEqual(registry.providers.count >= 4, true)
    }

    func testDeploymentRelativeTime() {
        let deployment = Deployment(
            id: "test-1",
            providerID: "vercel",
            projectName: "my-app",
            status: .success,
            url: URL(string: "https://example.com"),
            createdAt: Date().addingTimeInterval(-120),
            commitMessage: "fix: bug",
            branch: "main"
        )
        XCTAssertFalse(deployment.relativeTime.isEmpty)
    }

    func testDeploymentStatusEmoji() {
        XCTAssertEqual(Deployment.Status.success.emoji, "●")
        XCTAssertEqual(Deployment.Status.failed.emoji, "✕")
        XCTAssertEqual(Deployment.Status.building.emoji, "◐")
    }

    func testVercelProviderNotConfiguredByDefault() {
        let provider = VercelProvider()
        XCTAssertFalse(provider.isConfigured)
        XCTAssertEqual(provider.id, "vercel")
    }

    func testCloudflareProviderNotConfiguredByDefault() {
        let provider = CloudflareProvider()
        XCTAssertFalse(provider.isConfigured)
        XCTAssertEqual(provider.id, "cloudflare")
    }

    func testSettingsFieldsAreNonEmpty() {
        let providers: [DeploymentProvider] = [
            VercelProvider(),
            CloudflareProvider(),
            XcodeCloudProvider(),
            TestFlightProvider()
        ]
        for provider in providers {
            XCTAssertFalse(provider.settingsFields().isEmpty, "\(provider.displayName) should have settings fields")
        }
    }
}
