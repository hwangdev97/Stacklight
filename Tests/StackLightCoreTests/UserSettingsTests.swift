import XCTest
@testable import StackLightCore

final class UserSettingsTests: XCTestCase {
    func testVisibilityDefaultsToVisible() {
        let settings = UserSettings()
        let key = DeploymentKey(providerID: "vercel", itemID: "abc")
        XCTAssertEqual(settings.visibility(for: key), .visible)
    }

    func testPinThenHideMovesBetweenSets() {
        var settings = UserSettings()
        let key = DeploymentKey(providerID: "vercel", itemID: "abc")

        settings.setVisibility(.pinned, for: key)
        XCTAssertEqual(settings.visibility(for: key), .pinned)
        XCTAssertTrue(settings.pinnedItems.contains(key.rawValue))

        settings.setVisibility(.hidden, for: key)
        XCTAssertEqual(settings.visibility(for: key), .hidden)
        XCTAssertFalse(settings.pinnedItems.contains(key.rawValue))
        XCTAssertTrue(settings.hiddenItems.contains(key.rawValue))

        settings.setVisibility(.visible, for: key)
        XCTAssertFalse(settings.pinnedItems.contains(key.rawValue))
        XCTAssertFalse(settings.hiddenItems.contains(key.rawValue))
    }

    func testEnvelopeRoundTrip() throws {
        var original = UserSettings()
        original.setVisibility(.pinned, for: DeploymentKey(providerID: "vercel", itemID: "p1"))
        original.setVisibility(.hidden, for: DeploymentKey(providerID: "github", itemID: "owner/repo"))

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserSettings.self, from: data)

        XCTAssertEqual(decoded, original)
    }
}

final class DeploymentKeyTests: XCTestCase {
    func testRawValueRoundTrip() {
        let key = DeploymentKey(providerID: "githubActions", itemID: "owner/repo:42")
        let parsed = DeploymentKey(rawValue: key.rawValue)
        XCTAssertEqual(parsed, key)
    }

    func testInvalidRawValueReturnsNil() {
        XCTAssertNil(DeploymentKey(rawValue: "no-colon-here"))
        XCTAssertNil(DeploymentKey(rawValue: ":missing-provider"))
        XCTAssertNil(DeploymentKey(rawValue: "missing-item:"))
    }
}
