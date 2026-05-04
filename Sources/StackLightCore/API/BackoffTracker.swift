import Foundation

/// Tracks per-URL backoff windows so a 429/503 from one endpoint doesn't keep
/// hammering it on every poll cycle. Modeled after RepoBar's BackoffTracker —
/// per-URL keys (not per-provider) so a single bad endpoint can be quarantined
/// while the rest of that provider keeps working.
public actor BackoffTracker {
    private var cooldowns: [String: Date] = [:]

    public init() {}

    public func isCoolingDown(url: URL, now: Date = Date()) -> Bool {
        if let until = cooldowns[url.absoluteString], until > now { return true }
        return false
    }

    public func cooldown(for url: URL, now: Date = Date()) -> Date? {
        if let until = cooldowns[url.absoluteString], until > now { return until }
        return nil
    }

    public func setCooldown(url: URL, until: Date) {
        cooldowns[url.absoluteString] = until
    }

    public func clear() {
        cooldowns.removeAll()
    }

    public func count() -> Int {
        cooldowns.count
    }

    /// Returns a snapshot of all current cooldowns (`url → until`) for
    /// diagnostics / menu visualization.
    public func snapshot(now: Date = Date()) -> [(url: String, until: Date)] {
        cooldowns
            .filter { $0.value > now }
            .map { ($0.key, $0.value) }
            .sorted { $0.until < $1.until }
    }
}
