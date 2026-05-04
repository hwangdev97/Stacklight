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
        original.pollIntervalSeconds = 120
        original.diagnosticsEnabled = true
        original.setString("team_xyz", for: "vercel.teamId")
        original.setBool(true, for: "vercel.hideSkippedPreviews")
        original.setStringArray(["main", "develop"], for: "vercel.knownBranches")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserSettings.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testProviderHelpersIgnoreEmptyValues() {
        var settings = UserSettings()
        settings.setString("", for: "vercel.teamId")
        XCTAssertNil(settings.string(for: "vercel.teamId"))
        XCTAssertTrue(settings.providerStrings.isEmpty)

        settings.setString("team_x", for: "vercel.teamId")
        settings.setString(nil, for: "vercel.teamId")
        XCTAssertNil(settings.string(for: "vercel.teamId"))

        settings.setStringArray([], for: "vercel.knownBranches")
        XCTAssertTrue(settings.stringArray(for: "vercel.knownBranches").isEmpty)
    }

    func testV1EnvelopeDecodesIntoV2WithDefaults() throws {
        // Envelope written by v1 SettingsStore had only pinned/hidden fields;
        // ensure decoding still works and gives sensible defaults for the new
        // v2 fields.
        let v1JSON = """
        {
            "pinnedItems": ["vercel:p1"],
            "hiddenItems": [],
            "hiddenProviders": []
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(UserSettings.self, from: v1JSON)
        XCTAssertEqual(decoded.pinnedItems, ["vercel:p1"])
        XCTAssertEqual(decoded.pollIntervalSeconds, 60)
        XCTAssertEqual(decoded.notificationsEnabled, true)
        XCTAssertEqual(decoded.loggingVerbosity, "info")
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

final class SettingsStoreTests: XCTestCase {
    func testMigrationCopiesScatteredKeysIntoEnvelope() throws {
        // Use an isolated UserDefaults suite so the test doesn't mutate
        // the real app's settings.
        let suite = "StackLight.tests.\(UUID().uuidString)"
        let isolated = UserDefaults(suiteName: suite)!
        defer {
            isolated.removePersistentDomain(forName: suite)
        }

        // Pretend the user has data in scattered keys (pre-v2 world).
        isolated.set(120.0, forKey: "pollInterval")
        isolated.set(false, forKey: "notificationsEnabled")
        isolated.set("team_x", forKey: "vercel.teamId")
        isolated.set(true, forKey: "vercel.hideSkippedPreviews")
        isolated.set(["main", "develop"], forKey: "vercel.knownBranches")

        // Reload — first load triggers v0→v2 migration.
        let store = SettingsStore(defaults: isolated)
        XCTAssertEqual(store.pollIntervalSeconds, 120)
        XCTAssertEqual(store.notificationsEnabled, false)
        XCTAssertEqual(store.string(for: "vercel.teamId"), "team_x")
        XCTAssertEqual(store.bool(for: "vercel.hideSkippedPreviews"), true)
        XCTAssertEqual(store.stringArray(for: "vercel.knownBranches"), ["main", "develop"])
    }

    func testMutateIsAtomic() {
        let suite = "StackLight.tests.\(UUID().uuidString)"
        let isolated = UserDefaults(suiteName: suite)!
        defer { isolated.removePersistentDomain(forName: suite) }

        let store = SettingsStore(defaults: isolated)
        store.mutate { settings in
            settings.pollIntervalSeconds = 90
            settings.diagnosticsEnabled = true
            settings.setString("acct_42", for: "cloudflare.accountId")
        }
        XCTAssertEqual(store.pollIntervalSeconds, 90)
        XCTAssertTrue(store.diagnosticsEnabled)
        XCTAssertEqual(store.string(for: "cloudflare.accountId"), "acct_42")
    }
}
