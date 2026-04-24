import XCTest
@testable import StackLight
import AppStoreConnect_Swift_SDK

/// Live integration tests for Xcode Cloud API.
/// Requires valid ASC credentials in Keychain (service: app.yellowplus.StackLight).
/// Run with: swift test --filter XcodeCloudAPITests
final class XcodeCloudAPITests: XCTestCase {

    private var provider: APIProvider?

    override func setUp() {
        super.setUp()
        guard let issuerID = KeychainManager.read(key: "asc.issuerID"),
              let keyID = KeychainManager.read(key: "asc.privateKeyID"),
              let key = KeychainManager.read(key: "asc.privateKey"),
              !issuerID.isEmpty, !keyID.isEmpty, !key.isEmpty else {
            return
        }
        provider = try? APIConfiguration(
            issuerID: issuerID,
            privateKeyID: keyID,
            privateKey: key
        ).map { APIProvider(configuration: $0) }
    }

    // MARK: - Credential Tests

    func testKeychainHasCredentials() {
        let issuerID = KeychainManager.read(key: "asc.issuerID")
        let keyID = KeychainManager.read(key: "asc.privateKeyID")
        let key = KeychainManager.read(key: "asc.privateKey")

        XCTAssertNotNil(issuerID, "asc.issuerID not found in Keychain")
        XCTAssertNotNil(keyID, "asc.privateKeyID not found in Keychain")
        XCTAssertNotNil(key, "asc.privateKey not found in Keychain")

        if let issuerID { XCTAssertFalse(issuerID.isEmpty, "issuerID is empty") }
        if let keyID { XCTAssertFalse(keyID.isEmpty, "keyID is empty") }
        if let key {
            XCTAssertFalse(key.isEmpty, "privateKey is empty")
            XCTAssertTrue(key.contains("BEGIN PRIVATE KEY"), "privateKey doesn't look like a PEM key, got prefix: \(key.prefix(30))")
        }
    }

    func testAPIConfigurationCanBeCreated() {
        guard let issuerID = KeychainManager.read(key: "asc.issuerID"),
              let keyID = KeychainManager.read(key: "asc.privateKeyID"),
              let key = KeychainManager.read(key: "asc.privateKey") else {
            XCTFail("Missing credentials")
            return
        }

        do {
            let config = try APIConfiguration(
                issuerID: issuerID,
                privateKeyID: keyID,
                privateKey: key
            )
            XCTAssertNotNil(config)
        } catch {
            XCTFail("APIConfiguration init failed: \(error)")
        }
    }

    // MARK: - API Tests

    func testListCIProducts() async throws {
        guard let provider else {
            throw XCTSkip("ASC credentials not configured")
        }

        let request = APIEndpoint.v1.ciProducts.get(parameters: .init(limit: 25))
        let response = try await provider.request(request)

        print("[testListCIProducts] Found \(response.data.count) CI products:")
        for product in response.data {
            let name = product.attributes?.name ?? "(no name)"
            let type = product.attributes?.productType?.rawValue ?? "(no type)"
            print("  - \(name) (\(type)) id=\(product.id)")
        }

        XCTAssertGreaterThan(response.data.count, 0, "Expected at least one CI product")
    }

    func testListBuildRunsForFirstProduct() async throws {
        guard let provider else {
            throw XCTSkip("ASC credentials not configured")
        }

        // Get first product
        let productsRequest = APIEndpoint.v1.ciProducts.get(parameters: .init(limit: 1))
        let productsResponse = try await provider.request(productsRequest)

        guard let product = productsResponse.data.first else {
            XCTFail("No CI products found")
            return
        }

        let productName = product.attributes?.name ?? "(unknown)"
        print("[testListBuildRuns] Fetching build runs for: \(productName)")

        // Get build runs
        let runsRequest = APIEndpoint.v1.ciProducts.id(product.id).buildRuns
            .get(parameters: .init(
                sort: [.minusnumber],
                limit: 5
            ))
        let runsResponse = try await provider.request(runsRequest)

        print("[testListBuildRuns] Found \(runsResponse.data.count) build runs:")
        for run in runsResponse.data {
            let attrs = run.attributes
            let progress = attrs?.executionProgress?.rawValue ?? "?"
            let completion = attrs?.completionStatus?.rawValue ?? "?"
            let date = attrs?.createdDate?.description ?? "?"
            let commit = attrs?.sourceCommit?.message?.prefix(50) ?? "no commit"
            print("  - #\(attrs?.number ?? 0) progress=\(progress) completion=\(completion) date=\(date) commit=\(commit)")
        }

        // It's ok if there are zero runs for a product
        print("[testListBuildRuns] Done")
    }

    func testXcodeCloudProviderFetchDeployments() async throws {
        let xcProvider = XcodeCloudProvider()

        guard xcProvider.isConfigured else {
            throw XCTSkip("Xcode Cloud not configured")
        }

        do {
            let result = try await xcProvider.fetchDeployments()
            print("[testFetchDeployments] Got \(result.deployments.count) deployments:")
            for d in result.deployments.prefix(10) {
                print("  - \(d.projectName) | \(d.status.displayName) | \(d.createdAt)")
            }
            for (item, error) in result.itemErrors {
                print("  ! \(item): \(error.localizedDescription)")
            }
        } catch {
            XCTFail("fetchDeployments failed: \(error)")
        }
    }
}

private extension APIConfiguration {
    func map(_ transform: (APIConfiguration) -> APIProvider) -> APIProvider {
        transform(self)
    }
}
