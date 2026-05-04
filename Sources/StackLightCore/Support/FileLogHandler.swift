import Foundation

/// Append-mode file writer for diagnostics. Rolls when the active file passes
/// `maxFileBytes`; keeps `maxFiles - 1` rotated copies as `.1.log`, `.2.log`…
/// Path: `~/Library/Logs/StackLight/diagnostics.log`.
///
/// Not thread-safe by itself; expected to be called from `DiagnosticsLogger`
/// which serializes through its actor.
final class FileLogHandler {
    static func standard() -> FileLogHandler? {
        let fm = FileManager.default
        guard let logsDir = fm.urls(for: .libraryDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("StackLight", isDirectory: true)
        else { return nil }
        do {
            try fm.createDirectory(at: logsDir, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        return FileLogHandler(directory: logsDir)
    }

    private let directory: URL
    private let activeURL: URL
    private let maxFileBytes: Int = 1 * 1024 * 1024
    private let maxFiles: Int = 5
    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    init(directory: URL) {
        self.directory = directory
        self.activeURL = directory.appendingPathComponent("diagnostics.log")
    }

    func write(_ message: String) {
        rotateIfNeeded()
        let line = "[\(dateFormatter.string(from: Date()))] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: activeURL) {
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            // File doesn't exist yet — create it.
            try? data.write(to: activeURL, options: .atomic)
        }
    }

    private func rotateIfNeeded() {
        let attrs = try? FileManager.default.attributesOfItem(atPath: activeURL.path)
        let size = (attrs?[.size] as? Int) ?? 0
        guard size >= maxFileBytes else { return }

        let fm = FileManager.default
        // Drop the oldest, shift everyone down: diagnostics.4.log → .5.log, etc.
        let oldest = directory.appendingPathComponent("diagnostics.\(maxFiles - 1).log")
        try? fm.removeItem(at: oldest)
        for i in stride(from: maxFiles - 2, through: 1, by: -1) {
            let from = directory.appendingPathComponent("diagnostics.\(i).log")
            let to = directory.appendingPathComponent("diagnostics.\(i + 1).log")
            if fm.fileExists(atPath: from.path) {
                try? fm.moveItem(at: from, to: to)
            }
        }
        let firstRotated = directory.appendingPathComponent("diagnostics.1.log")
        try? fm.moveItem(at: activeURL, to: firstRotated)
    }
}
