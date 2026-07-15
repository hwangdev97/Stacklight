import Foundation

/// On-demand fetcher for `DeploymentFailureDetails` with a small TTL cache
/// and in-flight de-duplication. Hovering the same failed row twice (or
/// hovering it while a context-menu copy is already fetching) must not fan
/// out duplicate requests against log endpoints, which tend to be the most
/// expensive calls a provider offers.
public actor FailureDetailsService {
    public static let shared = FailureDetailsService()

    private struct CacheEntry {
        let details: DeploymentFailureDetails
        let fetchedAt: Date
    }

    private var cache: [String: CacheEntry] = [:]
    private var inFlight: [String: Task<DeploymentFailureDetails, Error>] = [:]
    private let ttl: TimeInterval
    /// Failed builds are immutable, but keep the cache bounded anyway —
    /// a long-running menu bar session shouldn't accumulate log excerpts
    /// for every failure it ever saw.
    private let maxEntries = 50

    public init(ttl: TimeInterval = 600) {
        self.ttl = ttl
    }

    private static func key(for deployment: Deployment) -> String {
        "\(deployment.providerID)|\(deployment.id)"
    }

    /// Returns cached details if present and fresh; otherwise runs (or joins)
    /// a fetch through the provider.
    public func details(
        for deployment: Deployment,
        from source: FailureDetailsProviding
    ) async throws -> DeploymentFailureDetails {
        let key = Self.key(for: deployment)

        if let entry = cache[key], Date().timeIntervalSince(entry.fetchedAt) < ttl {
            return entry.details
        }

        if let running = inFlight[key] {
            return try await running.value
        }

        let task = Task {
            try await source.fetchFailureDetails(for: deployment)
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }

        do {
            let details = try await task.value
            cache[key] = CacheEntry(details: details, fetchedAt: Date())
            trimCacheIfNeeded()
            return details
        } catch {
            await DiagnosticsLogger.shared.error(
                "FAILURE-DETAILS \(deployment.providerID) id=\(deployment.id) error=\(error.localizedDescription)",
                category: "details"
            )
            throw error
        }
    }

    /// Synchronous-ish peek used by copy actions that want whatever is
    /// already known without paying for a fetch.
    public func cached(for deployment: Deployment) -> DeploymentFailureDetails? {
        guard let entry = cache[Self.key(for: deployment)],
              Date().timeIntervalSince(entry.fetchedAt) < ttl else {
            return nil
        }
        return entry.details
    }

    public func clear() {
        cache.removeAll()
        for task in inFlight.values { task.cancel() }
        inFlight.removeAll()
    }

    private func trimCacheIfNeeded() {
        guard cache.count > maxEntries else { return }
        // Drop the oldest entries; ties are irrelevant at this size.
        let sorted = cache.sorted { $0.value.fetchedAt < $1.value.fetchedAt }
        for (key, _) in sorted.prefix(cache.count - maxEntries) {
            cache[key] = nil
        }
    }
}
