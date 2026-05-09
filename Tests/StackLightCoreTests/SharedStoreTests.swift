import XCTest
@testable import StackLightCore

final class SharedStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        SharedStore.clear()
    }

    override func tearDown() {
        SharedStore.clear()
        super.tearDown()
    }

    func testReadReturnsNilWhenEmpty() {
        XCTAssertNil(SharedStore.read())
    }

    func testWriteThenReadRoundTrips() {
        let deployments = [
            makeDeployment(id: "1", providerID: "vercel", status: .success),
            makeDeployment(id: "2", providerID: "cloudflare", status: .building)
        ]
        SharedStore.write(deployments: deployments)

        let snapshot = SharedStore.read()
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.deployments.count, 2)
        XCTAssertEqual(snapshot?.deployments.map(\.id), ["1", "2"])
        XCTAssertEqual(snapshot?.deployments.map(\.providerID), ["vercel", "cloudflare"])
        XCTAssertEqual(snapshot?.schemaVersion, SharedStore.schemaVersion)
    }

    func testActiveBuildFlag() {
        SharedStore.write(deployments: [
            makeDeployment(id: "1", providerID: "vercel", status: .success),
            makeDeployment(id: "2", providerID: "vercel", status: .building)
        ])
        XCTAssertEqual(SharedStore.read()?.activeBuild, true)

        SharedStore.write(deployments: [
            makeDeployment(id: "1", providerID: "vercel", status: .success)
        ])
        XCTAssertEqual(SharedStore.read()?.activeBuild, false)
    }

    func testReadRejectsMismatchedSchemaVersion() throws {
        // Hand-craft a snapshot with a version that doesn't match the current
        // build. SharedStore should treat it as missing rather than handing
        // back partially-decoded data that may not match the model layout.
        let payload: [String: Any] = [
            "deployments": [],
            "writtenAt": "2026-01-01T00:00:00Z",
            "activeBuild": false,
            "schemaVersion": SharedStore.schemaVersion + 999
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        let defaults = try XCTUnwrap(UserDefaults(suiteName: SharedStore.suiteName))
        defaults.set(data, forKey: SharedStore.snapshotKey)

        XCTAssertNil(SharedStore.read())
    }

    func testReadIgnoresCorruptPayload() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: SharedStore.suiteName))
        defaults.set(Data("not json".utf8), forKey: SharedStore.snapshotKey)

        XCTAssertNil(SharedStore.read())
    }

    // MARK: Helpers

    private func makeDeployment(
        id: String,
        providerID: String,
        status: Deployment.Status
    ) -> Deployment {
        Deployment(
            id: id,
            providerID: providerID,
            projectName: "project-\(id)",
            status: status,
            url: URL(string: "https://example.com/\(id)"),
            createdAt: Date(timeIntervalSinceReferenceDate: 0),
            commitMessage: "msg \(id)",
            branch: "main"
        )
    }
}
