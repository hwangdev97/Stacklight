import XCTest
import StackLightCore

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

    func testZeaburSettingsSupportAutoDiscoveryAndFiltering() {
        let fields = ZeaburProvider().settingsFields()
        XCTAssertTrue(fields.contains { $0.key == "zeabur.token" && $0.isSecret })
        XCTAssertTrue(fields.contains { $0.key == "zeabur.ownerId" })
        XCTAssertTrue(fields.contains { $0.key == "zeabur.projectIds" && $0.isMultiValue })
    }

    func testSettingsFieldsAreNonEmpty() {
        let providers: [DeploymentProvider] = [
            VercelProvider(),
            CloudflareProvider(),
            ZeaburProvider(),
            XcodeCloudProvider(),
            TestFlightProvider()
        ]
        for provider in providers {
            XCTAssertFalse(provider.settingsFields().isEmpty, "\(provider.displayName) should have settings fields")
        }
    }
}
