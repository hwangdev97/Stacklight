import XCTest
@testable import StackLightCore

final class BackoffTrackerTests: XCTestCase {
    func testCooldownActiveBeforeUntil() async {
        let tracker = BackoffTracker()
        let url = URL(string: "https://api.example.com/x")!
        let until = Date().addingTimeInterval(60)

        await tracker.setCooldown(url: url, until: until)

        let isCooling = await tracker.isCoolingDown(url: url)
        XCTAssertTrue(isCooling)
        let cooldown = await tracker.cooldown(for: url)
        XCTAssertEqual(cooldown, until)
    }

    func testCooldownExpiresAfterUntil() async {
        let tracker = BackoffTracker()
        let url = URL(string: "https://api.example.com/y")!
        let pastUntil = Date().addingTimeInterval(-10)

        await tracker.setCooldown(url: url, until: pastUntil)
        let cooldown = await tracker.cooldown(for: url)
        XCTAssertNil(cooldown)
    }

    func testPerURLIsolation() async {
        let tracker = BackoffTracker()
        let hot = URL(string: "https://api.example.com/hot")!
        let cool = URL(string: "https://api.example.com/cool")!

        await tracker.setCooldown(url: hot, until: Date().addingTimeInterval(30))
        let hotCooling = await tracker.isCoolingDown(url: hot)
        let coolCooling = await tracker.isCoolingDown(url: cool)
        XCTAssertTrue(hotCooling)
        XCTAssertFalse(coolCooling)
    }
}
