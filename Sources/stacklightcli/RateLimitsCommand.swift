import ArgumentParser
import Foundation
import StackLightCore

struct RateLimitsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rate-limits",
        abstract: "Show currently-tracked rate-limit / cooldown windows."
    )

    @OptionGroup
    var output: OutputOptions

    func run() async throws {
        let backoff = await RequestRunner.shared.backoffSnapshot()
        let metrics = await RequestRunner.shared.metrics()
        let cacheSummary = (try? PersistentCache.summary(limit: 0))

        switch output.format {
        case .json:
            struct Entry: Encodable {
                let url: String
                let until: Date
            }
            struct Payload: Encodable {
                let requests: Int
                let cacheHits: Int
                let activeCooldowns: [Entry]
                let cacheRateLimitCount: Int
            }
            try printJSON(Payload(
                requests: metrics.requests,
                cacheHits: metrics.cacheHits,
                activeCooldowns: backoff.map { Entry(url: $0.url, until: $0.until) },
                cacheRateLimitCount: cacheSummary?.rateLimitCount ?? 0
            ))
        case .plain:
            print("Requests this session: \(metrics.requests)")
            print("Cache hits (304):      \(metrics.cacheHits)")
            print("Active cooldowns:      \(backoff.count)")
            for entry in backoff {
                let remaining = max(0, Int(entry.until.timeIntervalSince(Date())))
                print("  · \(entry.url)  (resumes in ~\(remaining)s)")
            }
            if let cacheSummary, cacheSummary.rateLimitCount > 0 {
                print("Persisted rate-limit rows: \(cacheSummary.rateLimitCount)")
            }
        }
    }
}
