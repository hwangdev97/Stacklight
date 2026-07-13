import Foundation
import os

/// Central logging facade. Every line fans out to up to three sinks:
///
///   1. `LogStore` — the in-app ring buffer behind Settings → Logs.
///      **Warnings and errors land here unconditionally**, so failures are
///      inspectable even when the user never opted into diagnostics.
///   2. `os.Logger` — Console.app, subsystem `app.yellowplus.StackLight`.
///   3. `FileLogHandler` — `~/Library/Logs/StackLight/`, when file logging
///      is enabled.
///
/// Debug/info traffic (per-request HTTP lines, cache hits, backoff notices)
/// stays gated behind the Settings → Advanced → Enable Diagnostics toggle and
/// the verbosity picker, exactly as before — only the severity floor for
/// "always record" changed.
///
/// Designed as an actor so concurrent providers can `await logger.message(...)`
/// without races. The "shared" singleton mirrors RepoBar's pattern.
public actor DiagnosticsLogger {
    public static let shared = DiagnosticsLogger()

    private var enabled = false
    private var fileLoggingEnabled = false
    /// Verbosity floor for the opt-in channels (debug/info). Warnings and
    /// errors ignore it.
    private var minLevel: LogEntry.Level = .info
    private let osLog = Logger(subsystem: "app.yellowplus.StackLight", category: "diagnostics")
    private var fileHandler: FileLogHandler?

    public init() {}

    public func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
    }

    public func setFileLogging(_ enabled: Bool) {
        self.fileLoggingEnabled = enabled
        if enabled, fileHandler == nil {
            fileHandler = FileLogHandler.standard()
        }
    }

    /// Maps the Settings → Advanced verbosity raw value ("debug" / "info" /
    /// "warning") onto the opt-in channel floor.
    public func setVerbosity(_ raw: String) {
        switch raw {
        case "debug": minLevel = .debug
        case "warning": minLevel = .warning
        default: minLevel = .info
        }
    }

    // MARK: - Opt-in channels (gated by the diagnostics toggle)

    /// Chatty per-event detail (ETag hits, backoff notices). Only recorded at
    /// the "Debug (everything)" verbosity.
    public func debug(_ text: String, category: String = "diagnostics") {
        guard enabled, minLevel <= .debug else { return }
        osLog.debug("\(text, privacy: .public)")
        LogStore.post(.debug, category: category, text)
        writeToFile("DEBUG", text, category: category)
    }

    /// Standard diagnostics line (one per HTTP request). Gated by the
    /// diagnostics toggle; the pre-levels call sites all map here.
    public func message(_ text: String, category: String = "diagnostics") {
        guard enabled, minLevel <= .info else { return }
        osLog.info("\(text, privacy: .public)")
        LogStore.post(.info, category: category, text)
        writeToFile("INFO", text, category: category)
    }

    // MARK: - Always-on channels

    /// Degraded-but-working conditions (rate limits, partial per-item
    /// failures). Recorded regardless of the diagnostics toggle.
    public func warning(_ text: String, category: String = "app") {
        osLog.warning("\(text, privacy: .public)")
        LogStore.post(.warning, category: category, text)
        writeToFile("WARN", text, category: category)
    }

    /// Failures. Recorded regardless of the diagnostics toggle so the Logs
    /// pane can answer "what went wrong" after the fact.
    public func error(_ text: String, category: String = "app") {
        osLog.error("\(text, privacy: .public)")
        LogStore.post(.error, category: category, text)
        writeToFile("ERROR", text, category: category)
    }

    // MARK: - Fire-and-forget conveniences

    /// Convenience for cases where the caller may not be on an actor — fires
    /// the message in a Task and forgets it.
    public nonisolated func messageDetached(_ text: String, category: String = "diagnostics") {
        Task { await self.message(text, category: category) }
    }

    public nonisolated func errorDetached(_ text: String, category: String = "app") {
        Task { await self.error(text, category: category) }
    }

    // MARK: - File sink

    private func writeToFile(_ tag: String, _ text: String, category: String) {
        guard fileLoggingEnabled else { return }
        fileHandler?.write("[\(tag)] [\(category)] \(text)")
    }
}
