import XCTest
@testable import StackLightCore

@MainActor
final class LogStoreTests: XCTestCase {
    func testAppendKeepsDateOrder() {
        let store = LogStore()
        let now = Date()
        store.append(LogEntry(date: now, level: .info, category: "a", message: "first"))
        store.append(LogEntry(date: now.addingTimeInterval(2), level: .info, category: "a", message: "third"))
        // Lands between the two despite being appended last.
        store.append(LogEntry(date: now.addingTimeInterval(1), level: .info, category: "a", message: "second"))

        XCTAssertEqual(store.entries.map(\.message), ["first", "second", "third"])
    }

    func testCapacityTrimDropsOldestAndAdjustsErrorCount() {
        let store = LogStore()
        let base = Date()
        // First entry is an error; it must fall off once capacity overflows
        // and the counter must follow.
        store.append(LogEntry(date: base, level: .error, category: "x", message: "oldest error"))
        XCTAssertEqual(store.errorCount, 1)

        for i in 1...LogStore.capacity {
            store.append(LogEntry(date: base.addingTimeInterval(Double(i)), level: .info, category: "x", message: "entry \(i)"))
        }

        XCTAssertEqual(store.entries.count, LogStore.capacity)
        XCTAssertEqual(store.errorCount, 0)
        XCTAssertEqual(store.entries.first?.message, "entry 1")
    }

    func testClearResetsEverything() {
        let store = LogStore()
        store.append(LogEntry(level: .error, category: "x", message: "boom"))
        store.clear()
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertEqual(store.errorCount, 0)
    }

    func testErrorCountTracksOnlyErrors() {
        let store = LogStore()
        store.append(LogEntry(level: .debug, category: "x", message: "d"))
        store.append(LogEntry(level: .info, category: "x", message: "i"))
        store.append(LogEntry(level: .warning, category: "x", message: "w"))
        store.append(LogEntry(level: .error, category: "x", message: "e"))
        XCTAssertEqual(store.errorCount, 1)
    }

    func testLevelOrdering() {
        XCTAssertLessThan(LogEntry.Level.debug, .info)
        XCTAssertLessThan(LogEntry.Level.info, .warning)
        XCTAssertLessThan(LogEntry.Level.warning, .error)
    }

    func testExportTextFormat() {
        let entry = LogEntry(
            date: Date(timeIntervalSince1970: 0),
            level: .error,
            category: "xcodeCloud",
            message: "Test failed: timeout"
        )
        let text = LogStore.exportText([entry])
        XCTAssertTrue(text.contains("[ERROR]"), text)
        XCTAssertTrue(text.contains("[xcodeCloud]"), text)
        XCTAssertTrue(text.contains("Test failed: timeout"), text)
        XCTAssertTrue(text.contains("1970-01-01T00:00:00"), text)
    }

    func testPostFromOffMainActorLands() async {
        // `post` targets the shared singleton; give it a distinct message and
        // wait for the main-actor hop to land.
        let marker = "off-main post \(UUID().uuidString)"
        await Task.detached {
            LogStore.post(.warning, category: "test", marker)
        }.value

        // The append is an unstructured Task; yield until it shows up.
        for _ in 0..<100 where !LogStore.shared.entries.contains(where: { $0.message == marker }) {
            await Task.yield()
        }
        XCTAssertTrue(LogStore.shared.entries.contains { $0.message == marker && $0.level == .warning })
    }
}
