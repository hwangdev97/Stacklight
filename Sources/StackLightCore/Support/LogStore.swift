import Foundation
import Combine

// MARK: - LogEntry

/// One line in the in-app log. Kept deliberately small (value type, four
/// fields) because `LogStore` holds up to `LogStore.capacity` of these in
/// memory for the lifetime of the process.
public struct LogEntry: Identifiable, Equatable, Sendable {
    /// Severity, ordered so `>=` comparisons express "at least this serious".
    public enum Level: Int, Comparable, CaseIterable, Sendable {
        case debug = 0
        case info
        case warning
        case error

        public static func < (lhs: Level, rhs: Level) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        /// Fixed-width tag used in exported/serialized log lines.
        public var tag: String {
            switch self {
            case .debug: return "DEBUG"
            case .info: return "INFO "
            case .warning: return "WARN "
            case .error: return "ERROR"
            }
        }
    }

    public let id: UUID
    public let date: Date
    public let level: Level
    /// Short source tag — a provider ID ("xcodeCloud"), or a subsystem
    /// ("http", "polling", "app"). Drives the category chip in the Logs pane.
    public let category: String
    public let message: String

    public init(id: UUID = UUID(), date: Date = Date(), level: Level, category: String, message: String) {
        self.id = id
        self.date = date
        self.level = level
        self.category = category
        self.message = message
    }
}

// MARK: - LogStore

/// In-memory ring buffer behind the Settings → Logs pane. Errors and warnings
/// are recorded unconditionally (see `DiagnosticsLogger`), so a failure that
/// the UI mangled or that flashed by is still inspectable after the fact —
/// unlike the os.log / file channels, this needs no opt-in and no Console.app.
///
/// `@MainActor` because its only observer is SwiftUI; producers on other
/// actors go through the nonisolated `post`, which stamps the date at the
/// call site and hops to the main actor to append.
@MainActor
public final class LogStore: ObservableObject {
    public static let shared = LogStore()

    /// Oldest entries are dropped past this. 2000 lines ≈ a few polling hours
    /// with diagnostics on, or weeks of errors-only.
    public static let capacity = 2000

    /// Ordered oldest → newest.
    @Published public private(set) var entries: [LogEntry] = []
    /// Error entries currently in `entries`. Maintained incrementally so the
    /// sidebar badge doesn't rescan the buffer on every poll.
    @Published public private(set) var errorCount = 0

    public init() {}

    /// Thread-safe entry point for producers on any actor. The timestamp is
    /// taken here, not when the main-actor hop lands, so ordering reflects
    /// when things actually happened.
    public nonisolated static func post(_ level: LogEntry.Level, category: String, _ message: String) {
        let entry = LogEntry(level: level, category: category, message: message)
        Task { @MainActor in
            shared.append(entry)
        }
    }

    public func append(_ entry: LogEntry) {
        // Unstructured-task hops can land slightly out of order; keep the
        // buffer date-sorted by inserting from the tail (almost always index
        // `endIndex`, so this is O(1) in practice).
        var index = entries.endIndex
        while index > entries.startIndex, entries[index - 1].date > entry.date {
            index -= 1
        }
        entries.insert(entry, at: index)
        if entry.level == .error { errorCount += 1 }

        let overflow = entries.count - Self.capacity
        if overflow > 0 {
            for dropped in entries.prefix(overflow) where dropped.level == .error {
                errorCount -= 1
            }
            entries.removeFirst(overflow)
        }
    }

    public func clear() {
        entries.removeAll()
        errorCount = 0
    }

    // MARK: - Export

    /// Plain-text rendering (one ISO8601-stamped line per entry) for the
    /// Copy / Export buttons in the Logs pane.
    public nonisolated static func exportText(_ entries: [LogEntry]) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return entries
            .map { "[\(formatter.string(from: $0.date))] [\($0.level.tag)] [\($0.category)] \($0.message)" }
            .joined(separator: "\n")
    }
}
