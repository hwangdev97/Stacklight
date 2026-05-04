import ArgumentParser
import Foundation
import StackLightCore

struct CacheCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cache",
        abstract: "Inspect or clear the persistent HTTP response cache.",
        subcommands: [Status.self, Clear.self],
        defaultSubcommand: Status.self
    )

    struct Status: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "status",
            abstract: "Show counts and recent entries from the SQLite cache."
        )

        @Option(name: .long, help: "How many recent entries to include in the listing.")
        var limit: Int = 10

        @OptionGroup
        var output: OutputOptions

        func run() async throws {
            let summary = try PersistentCache.summary(limit: max(0, limit))
            switch output.format {
            case .json:
                try printJSON(summary)
            case .plain:
                print("Cache: \(summary.databasePath)")
                print("Exists: \(summary.exists ? "yes" : "no")")
                print("API responses: \(summary.apiResponseCount)")
                print("Rate limits tracked: \(summary.rateLimitCount)")
                if !summary.latestResponses.isEmpty {
                    print("")
                    print("Recent:")
                    for response in summary.latestResponses {
                        let etag = response.hasETag ? "etag" : "no-etag"
                        let status = response.statusCode.map(String.init) ?? "-"
                        print("  \(status) \(etag) \(response.url)")
                    }
                }
            }
        }
    }

    struct Clear: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "clear",
            abstract: "Wipe the persistent cache and the in-process actor caches."
        )

        @OptionGroup
        var output: OutputOptions

        func run() async throws {
            await RequestRunner.shared.clear()
            let summary = try PersistentCache.clear()
            switch output.format {
            case .json:
                try printJSON(summary)
            case .plain:
                print("Cleared cache: \(summary.databasePath)")
            }
        }
    }
}
