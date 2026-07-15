import Foundation

/// Rich failure context for a single deployment, fetched on demand (menu row
/// hover, context-menu copy) rather than during the regular poll — log
/// endpoints are much heavier than the list endpoints and only matter for
/// the handful of rows a user actually inspects.
public struct DeploymentFailureDetails: Equatable, Sendable {
    /// One structured problem extracted from the provider's response —
    /// a compile error, a failed pipeline job, a failing build stage.
    public struct Issue: Equatable, Sendable {
        public enum Severity: String, Equatable, Sendable {
            case error
            case warning
            case note
        }

        public let severity: Severity
        public let message: String
        /// Where the issue happened, in whatever shape the provider offers:
        /// `"Sources/App.swift:12"`, `"Job: build · Step: Run tests"`,
        /// `"stage: deploy"`. Nil when the provider gives no location.
        public let source: String?

        public init(severity: Severity, message: String, source: String? = nil) {
            self.severity = severity
            self.message = message
            self.source = source
        }
    }

    /// One-line failure headline, e.g. `"Build failed with 2 errors"` or
    /// `"Deploy stage failed"`. Nil when the provider offers nothing better
    /// than the raw log.
    public let summary: String?
    /// Structured issues, most severe first. Empty when the provider only
    /// exposes an unstructured log.
    public let issues: [Issue]
    /// Tail of the raw build/deploy log, already trimmed via `tailExcerpt`.
    public let logExcerpt: String?
    /// True when `logExcerpt` was cut down from a longer log.
    public let logExcerptTruncated: Bool
    /// Deep link to the full logs in the provider's dashboard, when it is
    /// more specific than `Deployment.url` (falls back to that otherwise).
    public let logsURL: URL?
    public let fetchedAt: Date

    public init(
        summary: String? = nil,
        issues: [Issue] = [],
        logExcerpt: String? = nil,
        logExcerptTruncated: Bool = false,
        logsURL: URL? = nil,
        fetchedAt: Date = Date()
    ) {
        let trimmedSummary = summary?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.summary = (trimmedSummary?.isEmpty ?? true) ? nil : trimmedSummary
        self.issues = issues
        let trimmedLog = logExcerpt?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.logExcerpt = (trimmedLog?.isEmpty ?? true) ? nil : trimmedLog
        self.logExcerptTruncated = logExcerptTruncated
        self.logsURL = logsURL
        self.fetchedAt = fetchedAt
    }

    /// True when the fetch succeeded but yielded nothing displayable — the
    /// UI shows its "no details available" fallback in that case.
    public var isEmpty: Bool {
        summary == nil && issues.isEmpty && logExcerpt == nil
    }

    /// Keeps the last `maxLines` lines of `text`, additionally capped at
    /// `maxCharacters` (whole lines only, so the excerpt never starts
    /// mid-escape-sequence). Build logs bury the interesting part at the
    /// end, so the tail is the right slice to keep. Lines are sanitized for
    /// terminal noise: ANSI escape sequences are stripped and
    /// carriage-return progress updates collapse to their final state.
    public static func tailExcerpt(
        _ text: String,
        maxLines: Int = 60,
        maxCharacters: Int = 6_000
    ) -> (text: String, truncated: Bool) {
        let allLines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { sanitizeLogLine(String($0)) }

        // Drop trailing blank lines so the cap isn't spent on padding.
        var lines = allLines
        while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.removeLast()
        }

        var truncated = false
        if lines.count > maxLines {
            lines = Array(lines.suffix(maxLines))
            truncated = true
        }

        var kept: [String] = []
        var total = 0
        for line in lines.reversed() {
            // +1 for the newline that rejoins the lines.
            let cost = line.count + (kept.isEmpty ? 0 : 1)
            if total + cost > maxCharacters {
                truncated = true
                break
            }
            kept.append(line)
            total += cost
        }

        return (kept.reversed().joined(separator: "\n"), truncated)
    }

    /// Strips ANSI CSI/OSC escape sequences and collapses `\r`-overwritten
    /// progress output ("50%…\r100%") down to the final visible text.
    static func sanitizeLogLine(_ line: String) -> String {
        var cleaned = line
        if cleaned.contains("\u{1B}") {
            cleaned = cleaned.replacingOccurrences(
                of: "\u{1B}\\[[0-9;?]*[ -/]*[@-~]",
                with: "",
                options: .regularExpression
            )
            cleaned = cleaned.replacingOccurrences(
                of: "\u{1B}\\][^\u{07}\u{1B}]*(\u{07}|\u{1B}\\\\)",
                with: "",
                options: .regularExpression
            )
        }
        if cleaned.contains("\r"), let last = cleaned.split(separator: "\r").last {
            cleaned = String(last)
        } else if cleaned == "\r" {
            cleaned = ""
        }
        return cleaned
    }
}

/// Capability protocol: providers that can fetch failure details for one of
/// their deployments adopt this alongside `DeploymentProvider`. Adoption is
/// deliberately opt-in — several upstream APIs (TestFlight review verdicts,
/// Fly.io machine logs) simply don't expose failure logs, and the UI treats
/// those providers as "metadata only".
public protocol FailureDetailsProviding: AnyObject {
    /// Fetch error details for a (typically failed) deployment previously
    /// returned by this provider's `fetchDeployments()`. Throws when the
    /// upstream request fails; returns `.isEmpty == true` details when the
    /// request worked but the provider had nothing useful to say.
    func fetchFailureDetails(for deployment: Deployment) async throws -> DeploymentFailureDetails
}

extension DeploymentProvider {
    /// Convenience cast used by UI/service code.
    public var failureDetailsSource: FailureDetailsProviding? {
        self as? FailureDetailsProviding
    }
}
