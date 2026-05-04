import Foundation
import os

/// Lightweight opt-in diagnostics channel. When enabled (via Settings →
/// Advanced → Enable Diagnostics) every `RequestRunner` HTTP request and a few
/// other lifecycle events get logged through `os.Logger`. When the file logger
/// is also enabled, the same lines stream into `~/Library/Logs/StackLight/`.
///
/// Designed as an actor so concurrent providers can `await logger.message(...)`
/// without races. The "shared" singleton mirrors RepoBar's pattern.
public actor DiagnosticsLogger {
    public static let shared = DiagnosticsLogger()

    private var enabled = false
    private var fileLoggingEnabled = false
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

    public func message(_ text: String) {
        guard enabled else { return }
        osLog.info("\(text, privacy: .public)")
        if fileLoggingEnabled {
            fileHandler?.write(text)
        }
    }

    /// Convenience for cases where the caller may not be on an actor — fires
    /// the message in a Task and forgets it.
    public nonisolated func messageDetached(_ text: String) {
        Task { await self.message(text) }
    }
}
